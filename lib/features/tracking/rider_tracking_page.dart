import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/delivery_models.dart';

// ═══════════════════════════════════════════════════════════════
//  RIDER TRACKING PAGE
//
//  Shows Google Maps with rider's live position.
//  Sends GPS to Firestore every 15 seconds.
//  "Open Navigation" launches Google Maps app with turn-by-turn.
// ═══════════════════════════════════════════════════════════════

class RiderTrackingPage extends StatefulWidget {
  final DeliveryJob job;
  final String agentId;

  const RiderTrackingPage({
    super.key,
    required this.job,
    required this.agentId,
  });

  @override
  State<RiderTrackingPage> createState() => _RiderTrackingPageState();
}

class _RiderTrackingPageState extends State<RiderTrackingPage> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _locationSub;
  Timer? _uploadTimer;

  LatLng? _riderPosition;
  LatLng? _destinationLatLng;
  bool _locationPermissionGranted = false;
  bool _loading = true;
  String? _error;

  bool get _isPickupPhase =>
      widget.job.status == DeliveryJobStatus.agreed ||
          widget.job.status == DeliveryJobStatus.pickupPending;

  String get _destinationAddress =>
      _isPickupPhase ? widget.job.pickupAddress : widget.job.destination;

  String get _destinationLabel =>
      _isPickupPhase ? '📍 Pickup' : '🏠 Deliver here';

  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _uploadTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _requestPermission();
    if (_locationPermissionGranted) await _startTracking();
    _loadDestinationPin();
  }

  Future<void> _requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _error =
        'Location permission denied. Please enable it in phone settings.';
        _loading = false;
      });
      return;
    }
    setState(() => _locationPermissionGranted = true);
  }

  Future<void> _startTracking() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _updateRiderPosition(pos);
      setState(() => _loading = false);
    } catch (_) {
      setState(() => _loading = false);
    }

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen(_updateRiderPosition);

    // Upload to Firestore every 15 seconds
    _uploadTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_riderPosition != null) _uploadLocation(_riderPosition!);
    });
  }

  void _updateRiderPosition(Position pos) {
    final latLng = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _riderPosition = latLng;
      _markers.removeWhere((m) => m.markerId.value == 'rider');
      _markers.add(Marker(
        markerId: const MarkerId('rider'),
        position: latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You are here'),
      ));
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
  }

  Future<void> _uploadLocation(LatLng pos) async {
    try {
      await FirebaseFirestore.instance
          .collection('deliveryJobs')
          .doc(widget.job.id)
          .update({
        'riderLat': pos.latitude,
        'riderLng': pos.longitude,
        'riderLastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _loadDestinationPin() {
    FirebaseFirestore.instance
        .collection('deliveryJobs')
        .doc(widget.job.id)
        .get()
        .then((snap) {
      final data = snap.data();
      if (data == null) return;

      double? lat;
      double? lng;

      if (_isPickupPhase) {
        lat = (data['pickupLat'] as num?)?.toDouble();
        lng = (data['pickupLng'] as num?)?.toDouble();
      } else {
        lat = (data['destLat'] as num?)?.toDouble();
        lng = (data['destLng'] as num?)?.toDouble();
      }

      if (lat != null && lng != null && lat != 0 && lng != 0) {
        final dest = LatLng(lat, lng);
        setState(() {
          _destinationLatLng = dest;
          _markers.removeWhere((m) => m.markerId.value == 'destination');
          _markers.add(Marker(
            markerId: const MarkerId('destination'),
            position: dest,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: _destinationLabel),
          ));
        });
      }
    });
  }

  // ── Launch Google Maps app with turn-by-turn navigation ──────
  Future<void> _openNavigation() async {
    final dest = _destinationLatLng;

    Uri uri;

    if (dest != null && dest.latitude != 0 && dest.longitude != 0) {
      // Use exact coordinates — most accurate
      uri = Uri.parse(
        'google.navigation:q=${dest.latitude},${dest.longitude}&mode=d',
      );
    } else {
      // Fall back to address search
      uri = Uri.parse(
        'google.navigation:q=${Uri.encodeComponent(_destinationAddress)}&mode=d',
      );
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Google Maps not installed — open in browser
        final fallback = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination='
              '${dest != null && dest.latitude != 0 ? '${dest.latitude},${dest.longitude}' : Uri.encodeComponent(_destinationAddress)}'
              '&travelmode=driving',
        );
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not open Google Maps'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────
          if (_loading)
            const Center(
                child: CircularProgressIndicator(color: AppTheme.blue))
          else if (_error != null)
            _ErrorView(error: _error!, isDark: isDark)
          else
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _riderPosition ?? const LatLng(6.5244, 3.3792),
                zoom: 15,
              ),
              onMapCreated: (c) => _mapController = c,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),

          // ── Top bar ─────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPickupPhase ? '📍 Go to Pickup' : '🏠 Go to Delivery',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.darkTextTertiary
                              : AppTheme.lightTextTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _destinationAddress,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),

          // ── Bottom card ─────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _isPickupPhase ? '⏳ Pickup Phase' : '🚀 Delivery Phase',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.blue,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₦${widget.job.agreedAmount?.toStringAsFixed(0) ?? '0'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.success,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 10),

                  Text(
                    widget.job.itemDescription,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.job.pickupArea} → ${widget.job.destinationArea}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkTextTertiary
                          : AppTheme.lightTextTertiary,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Navigate button
                  GestureDetector(
                    onTap: _openNavigation,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.blue.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.navigation_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Open Navigation',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Live indicator ───────────────────────────────
          if (_riderPosition != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: 16,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 8),
                    SizedBox(width: 5),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
            const Icon(Icons.location_off_rounded,
                color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
