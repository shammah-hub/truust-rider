import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:truust_rider/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

// ═══════════════════════════════════════════════════════════════
//  LIVE ROUTE MAP  (shared by FleetTrackingPage + RiderTrackingPage)
//
//  - Shows BOTH pickup (green pin) and drop-off (red pin).
//  - Draws the driving route from the rider to the NEXT stop
//    (pickup first, then drop-off) with distance, ETA and the next
//    turn, all inside the app.
//  - If an order only has address text, the addresses are turned
//    into coordinates on the phone.
//  - Sends the rider's live GPS to [locationDoc] at most every 15s,
//    starting from the first fix, and keeps going in the background.
//  - "Open in Google Maps" is now a small optional button.
//
//  Directions API key: run with
//    flutter run --dart-define=MAPS_API_KEY=your_key
//  Without a key the map still works, but draws a straight dashed
//  line instead of the road route.
// ═══════════════════════════════════════════════════════════════

const String kDirectionsApiKey = String.fromEnvironment('MAPS_API_KEY');

class RouteStop {
  final String address;
  final LatLng? latLng; // saved coordinates, if the order has them
  const RouteStop({required this.address, this.latLng});
}

class LiveRouteMap extends StatefulWidget {
  final RouteStop pickup;
  final RouteStop dropoff;
  final bool isPickupPhase;
  final DocumentReference<Map<String, dynamic>> locationDoc;
  final LatLng fallbackCenter;

  const LiveRouteMap({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.isPickupPhase,
    required this.locationDoc,
    this.fallbackCenter = const LatLng(9.0765, 7.3986), // Abuja
  });

  @override
  State<LiveRouteMap> createState() => _LiveRouteMapState();
}

class _LiveRouteMapState extends State<LiveRouteMap> {
  GoogleMapController? _map;
  StreamSubscription<Position>? _sub;

  LatLng? _rider;
  LatLng? _pickupLL;
  LatLng? _dropoffLL;

  bool _loading = true;
  bool _locationOk = false;
  String? _error;

  bool _fitted = false;
  bool _follow = false;

  DateTime _lastUpload = DateTime.fromMillisecondsSinceEpoch(0);

  bool _routing = false;
  LatLng? _lastRouteFrom;
  DateTime _lastRouteAt = DateTime.fromMillisecondsSinceEpoch(0);
  List<LatLng> _line = const [];
  bool _approx = false;
  String? _eta;
  String? _distance;
  String? _instruction;

  LatLng? get _target => widget.isPickupPhase ? _pickupLL : _dropoffLL;
  String get _targetAddress =>
      widget.isPickupPhase ? widget.pickup.address : widget.dropoff.address;

  @override
  void initState() {
    super.initState();
    _pickupLL = widget.pickup.latLng;
    _dropoffLL = widget.dropoff.latLng;
    _init();
  }

  @override
  void didUpdateWidget(covariant LiveRouteMap old) {
    super.didUpdateWidget(old);
    if (old.isPickupPhase != widget.isPickupPhase) {
      setState(() {
        _line = const [];
        _eta = null;
        _distance = null;
        _instruction = null;
      });
      _maybeRoute(force: true);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  // ── Setup ────────────────────────────────────────────────────

  Future<void> _init() async {
    _resolveMissingStops(); // runs alongside GPS, not blocking it
    await _startLocation();
  }

  Future<LatLng?> _geocode(String address) async {
    try {
      final r = await geo.Geocoding().locationFromAddress(address);
      if (r.isNotEmpty) return LatLng(r.first.latitude, r.first.longitude);
    } catch (_) {}
    return null;
  }

  Future<void> _resolveMissingStops() async {
    if (_pickupLL == null) {
      final ll = await _geocode(widget.pickup.address);
      if (!mounted) return;
      if (ll != null) setState(() => _pickupLL = ll);
    }
    if (_dropoffLL == null) {
      final ll = await _geocode(widget.dropoff.address);
      if (!mounted) return;
      if (ll != null) setState(() => _dropoffLL = ll);
    }
    _fitOnce();
    _maybeRoute(force: true);
  }

  LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Delivery in progress',
          notificationText: 'Truust is sharing your live location',
          enableWakeLock: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
        accuracy: LocationAccuracy.high, distanceFilter: 15);
  }

  Future<void> _startLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _error = 'Location permission denied. Please enable it in phone settings.';
        _loading = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _locationOk = true);

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _onPosition(pos);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);

    _sub = Geolocator.getPositionStream(locationSettings: _settings())
        .listen(_onPosition);
  }

  // ── Live position ────────────────────────────────────────────

  void _onPosition(Position p) {
    if (!mounted) return;
    final ll = LatLng(p.latitude, p.longitude);
    setState(() {
      _rider = ll;
      _loading = false;
    });
    _maybeUpload(ll);
    _maybeRoute();
    if (_follow) {
      _map?.animateCamera(CameraUpdate.newLatLng(ll));
    } else {
      _fitOnce();
    }
  }

  // At most one write per 15s, starting with the very first fix.
  void _maybeUpload(LatLng ll) {
    final now = DateTime.now();
    if (now.difference(_lastUpload) < const Duration(seconds: 15)) return;
    _lastUpload = now;
    widget.locationDoc.update({
      'riderLat': ll.latitude,
      'riderLng': ll.longitude,
      'riderLastSeen': FieldValue.serverTimestamp(),
    }).catchError((_) {}); // best-effort; the next ping fixes any gap
  }

  // ── Route ────────────────────────────────────────────────────

  Future<void> _maybeRoute({bool force = false}) async {
    final from = _rider;
    final to = _target;
    if (from == null || to == null || _routing) return;

    final movedFar = _lastRouteFrom == null ||
        Geolocator.distanceBetween(_lastRouteFrom!.latitude,
            _lastRouteFrom!.longitude, from.latitude, from.longitude) >
            150;
    final age = DateTime.now().difference(_lastRouteAt);
    if (!force && !(movedFar && age > const Duration(seconds: 20))) return;

    _routing = true;
    _lastRouteFrom = from;
    _lastRouteAt = DateTime.now();

    try {
      if (kDirectionsApiKey.isEmpty) throw StateError('no key');

      final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
        'origin': '${from.latitude},${from.longitude}',
        'destination': '${to.latitude},${to.longitude}',
        'mode': 'driving',
        'key': kDirectionsApiKey,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['status'] != 'OK') throw StateError('directions ${j['status']}');

      final route = (j['routes'] as List).first as Map<String, dynamic>;
      final leg = (route['legs'] as List).first as Map<String, dynamic>;
      final steps = (leg['steps'] as List?) ?? const [];

      String? instruction;
      if (steps.isNotEmpty) {
        final s = steps.first as Map<String, dynamic>;
        final text = (s['html_instructions'] as String? ?? '')
            .replaceAll(RegExp(r'<[^>]*>'), ' ')
            .replaceAll('&nbsp;', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final d = (s['distance'] as Map?)?['text'];
        if (text.isNotEmpty) instruction = d != null ? '$text · $d' : text;
      }

      if (!mounted) return;
      setState(() {
        _line = _decodePolyline(route['overview_polyline']['points'] as String);
        _approx = false;
        _eta = (leg['duration'] as Map)['text'] as String?;
        _distance = (leg['distance'] as Map)['text'] as String?;
        _instruction = instruction;
      });
    } catch (e) {
      debugPrint('ROUTE ERROR: $e');
      if (!mounted) return;
      final d = Geolocator.distanceBetween(
          from.latitude, from.longitude, to.latitude, to.longitude);
      setState(() {
        _line = [from, to];
        _approx = true;
        _eta = null;
        _instruction = null;
        _distance = '${(d / 1000).toStringAsFixed(1)} km away';
      });
    } finally {
      _routing = false;
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  // ── Camera ───────────────────────────────────────────────────

  List<LatLng> get _allPoints => <LatLng>[
    if (_rider != null) _rider!,
    if (_pickupLL != null) _pickupLL!,
    if (_dropoffLL != null) _dropoffLL!,
  ];

  void _fitOnce() {
    if (_fitted || _map == null || _allPoints.length < 2) return;
    _fitted = true;
    _fitAll();
  }

  Future<void> _fitAll() async {
    final pts = _allPoints;
    if (_map == null || pts.isEmpty) return;
    try {
      if (pts.length == 1) {
        await _map!.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 15));
        return;
      }
      double minLat = pts.first.latitude, maxLat = pts.first.latitude;
      double minLng = pts.first.longitude, maxLng = pts.first.longitude;
      for (final p in pts) {
        minLat = math.min(minLat, p.latitude);
        maxLat = math.max(maxLat, p.latitude);
        minLng = math.min(minLng, p.longitude);
        maxLng = math.max(maxLng, p.longitude);
      }
      await _map!.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        90,
      ));
    } catch (_) {}
  }

  void _recenter() {
    final r = _rider;
    if (r == null) return;
    setState(() => _follow = true);
    _map?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: r, zoom: 17),
    ));
  }

  void _showAll() {
    setState(() => _follow = false);
    _fitAll();
  }

  // ── Optional hand-off to the Google Maps app ────────────────

  Future<void> _openInGoogleMaps() async {
    final t = _target;
    final dest = t != null
        ? '${t.latitude},${t.longitude}'
        : Uri.encodeComponent(_targetAddress);
    try {
      final native = Uri.parse('google.navigation:q=$dest&mode=d');
      if (await canLaunchUrl(native)) {
        await launchUrl(native);
      } else {
        await launchUrl(
          Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Could not open Google Maps'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // ── UI ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blue = AppTheme.blueFor(isDark);
    final green = AppTheme.greenFor(isDark);
    final top = MediaQuery.of(context).padding.top + 12;

    final markers = <Marker>{
      if (_pickupLL != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLL!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      if (_dropoffLL != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: _dropoffLL!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Drop-off'),
        ),
    };

    final polylines = <Polyline>{
      if (_line.length >= 2)
        Polyline(
          polylineId: const PolylineId('route'),
          points: _line,
          width: 5,
          color: blue,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          patterns: _approx
              ? [PatternItem.dash(18), PatternItem.gap(10)]
              : const [],
        ),
    };

    return Stack(
      children: [
        if (_error != null)
          _ErrorView(error: _error!, isDark: isDark)
        else
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _rider ?? _target ?? widget.fallbackCenter,
              zoom: 14,
            ),
            onMapCreated: (c) {
              _map = c;
              _fitOnce();
            },
            markers: markers,
            polylines: polylines,
            myLocationEnabled: _locationOk,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

        if (_loading && _error == null)
          Center(child: CircularProgressIndicator(color: blue)),

        // Top: back + where to + next turn
        Positioned(
          top: top,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _MapButton(
                  isDark: isDark,
                  icon: Icons.arrow_back_ios_new_rounded,
                  tooltip: 'Back',
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Panel(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isPickupPhase ? 'Go to pickup' : 'Go to drop-off',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textTertiary(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _targetAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary(isDark),
                          ),
                        ),
                        if (_instruction != null) ...[
                          const SizedBox(height: 8),
                          Row(children: [
                            Icon(Icons.turn_right_rounded, size: 18, color: blue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _instruction!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.3,
                                  color: AppTheme.textPrimary(isDark),
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Wrap(spacing: 8, runSpacing: 6, children: [
                  if (_eta != null || _distance != null)
                    _Chip(
                      isDark: isDark,
                      text: [if (_eta != null) _eta!, if (_distance != null) _distance!]
                          .join(' · '),
                    ),
                  if (_rider != null)
                    _Chip(isDark: isDark, text: 'Live', dot: green),
                ]),
              ),
            ],
          ),
        ),

        // Right: map controls
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _MapButton(
              isDark: isDark,
              icon: Icons.open_in_new_rounded,
              tooltip: 'Open in Google Maps',
              onTap: _openInGoogleMaps,
            ),
            const SizedBox(height: 10),
            _MapButton(
              isDark: isDark,
              icon: Icons.zoom_out_map_rounded,
              tooltip: 'Show pickup and drop-off',
              onTap: _showAll,
            ),
            const SizedBox(height: 10),
            _MapButton(
              isDark: isDark,
              icon: Icons.my_location_rounded,
              tooltip: 'Follow me',
              active: _follow,
              onTap: _recenter,
            ),
          ]),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Bottom info card, shared by both tracking pages
// ─────────────────────────────────────────────────────────────

class TrackingInfoCard extends StatelessWidget {
  final bool isDark;
  final String badge;
  final String? amount;
  final String title;
  final String pickup;
  final String dropoff;
  final String? note;

  const TrackingInfoCard({
    super.key,
    required this.isDark,
    required this.badge,
    this.amount,
    required this.title,
    required this.pickup,
    required this.dropoff,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final strong = AppTheme.textPrimary(isDark);
    final soft = AppTheme.textTertiary(isDark);

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 64,
          child: Text(label, style: TextStyle(fontSize: 12, color: soft)),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: strong),
          ),
        ),
      ]),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: AppTheme.surface(isDark),
        border: Border(top: BorderSide(color: AppTheme.border(isDark))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: ShapeDecoration(
                shape: StadiumBorder(
                    side: BorderSide(color: AppTheme.border(isDark))),
              ),
              child: Text(badge,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: strong)),
            ),
            const Spacer(),
            if (amount != null)
              Text(amount!,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: strong)),
          ]),
          const SizedBox(height: 12),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: strong)),
          line('Pickup', pickup),
          line('Drop-off', dropoff),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(note!, style: TextStyle(fontSize: 11, color: soft)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Small pieces (flat, no shadows)
// ─────────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _Panel({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm + 4),
        border: Border.all(color: AppTheme.border(isDark)),
      ),
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  final bool isDark;
  final String text;
  final Color? dot;
  const _Chip({required this.isDark, required this.text, this.dot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: ShapeDecoration(
        color: AppTheme.surface(isDark),
        shape: StadiumBorder(side: BorderSide(color: AppTheme.border(isDark))),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot != null) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary(isDark))),
      ]),
    );
  }
}

class _MapButton extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _MapButton({
    required this.isDark,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppTheme.surface(isDark),
        shape: CircleBorder(
          side: BorderSide(
            color: active ? AppTheme.blueFor(isDark) : AppTheme.border(isDark),
            width: active ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 18,
              color: active
                  ? AppTheme.blueFor(isDark)
                  : AppTheme.textPrimary(isDark),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final bool isDark;
  const _ErrorView({required this.error, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded,
                color: AppTheme.redFor(isDark), size: 48),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary(isDark)),
            ),
          ],
        ),
      ),
    );
  }
}
