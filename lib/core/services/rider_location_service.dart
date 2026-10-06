import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:geolocator/geolocator.dart';

// ═══════════════════════════════════════════════════════════════
//  RIDER LOCATION SERVICE
//
//  Shares the rider's position so the agency can see every rider on
//  its dashboard map, whichever screen the rider is on:
//
//    • while the rider is ONLINE (deliveryAgents/{id}.isAvailable)
//        -> writes deliveryAgents/{id}.lastLocation + lastLocationAt
//    • while they have an ACTIVE DELIVERY
//        -> also writes riderLat / riderLng / riderLastSeen onto each
//           active fleetOrders / deliveryJobs doc
//
//  It stops by itself when the rider goes offline and has nothing
//  active. It watches the agent's own doc, so there is nothing to
//  wire to the online toggle.
//
//  Usage:
//    RiderLocationService.instance.start(userId);          // once after login
//    RiderLocationService.instance.setActiveOrders(...);   // from the Active page
//    RiderLocationService.instance.stop();                 // on logout
//
//  Android needs the FOREGROUND_SERVICE and FOREGROUND_SERVICE_LOCATION
//  permissions; iOS needs Background Modes -> Location updates.
// ═══════════════════════════════════════════════════════════════

class RiderLocationService {
  RiderLocationService._();
  static final RiderLocationService instance = RiderLocationService._();

  String? _agentId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _agentSub;
  StreamSubscription<Position>? _posSub;

  bool _online = false;
  bool _starting = false;
  bool _permissionDenied = false;
  List<String> _fleetIds = const [];
  List<String> _jobIds = const [];
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _hasActive => _fleetIds.isNotEmpty || _jobIds.isNotEmpty;
  bool get _shouldShare => _agentId != null && (_online || _hasActive);

  /// Begin watching this rider. Safe to call again with the same id.
  void start(String agentId) {
    if (_agentId == agentId) return;
    stop();
    _agentId = agentId;
    _permissionDenied = false;
    _agentSub = FirebaseFirestore.instance
        .collection('deliveryAgents')
        .doc(agentId)
        .snapshots()
        .listen((snap) {
      _online = snap.data()?['isAvailable'] == true;
      _evaluate();
    }, onError: (e) => debugPrint('LOCATION SERVICE: agent watch failed: $e'));
  }

  /// Tell the service which deliveries are active right now.
  void setActiveOrders({required List<String> fleetOrderIds, required List<String> jobIds}) {
    _fleetIds = fleetOrderIds;
    _jobIds = jobIds;
    _evaluate();
  }

  /// Call on logout.
  void stop() {
    _agentSub?.cancel();
    _agentSub = null;
    _stopStreaming();
    _agentId = null;
    _online = false;
    _fleetIds = const [];
    _jobIds = const [];
  }

  void _evaluate() {
    if (_shouldShare) {
      _ensureStreaming();
    } else {
      _stopStreaming();
    }
  }

  void _stopStreaming() {
    _posSub?.cancel();
    _posSub = null;
  }

  LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Truust rider',
          notificationText: 'Sharing your location with your agency',
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
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15);
  }

  Future<void> _ensureStreaming() async {
    if (_posSub != null || _starting || _permissionDenied) return;
    _starting = true;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _permissionDenied = true; // don't keep asking on every change
        return;
      }
      if (!_shouldShare) return;

      try {
        final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        _push(p, force: true);
      } catch (_) {}

      if (_shouldShare && _posSub == null) {
        _posSub = Geolocator.getPositionStream(locationSettings: _settings()).listen(_push);
      }
    } catch (e) {
      debugPrint('LOCATION SERVICE: could not start: $e');
    } finally {
      _starting = false;
    }
  }

  void _push(Position p, {bool force = false}) {
    final id = _agentId;
    if (id == null) return;

    // Every 15s on a delivery, every 60s when just online.
    final gap = _hasActive ? const Duration(seconds: 15) : const Duration(seconds: 60);
    final now = DateTime.now();
    if (!force && now.difference(_lastPush) < gap) return;
    _lastPush = now;

    final db = FirebaseFirestore.instance;

    // where the rider is, for the agency's fleet view
    db.collection('deliveryAgents').doc(id).update({
      'lastLocation': {'lat': p.latitude, 'lng': p.longitude},
      'lastLocationAt': FieldValue.serverTimestamp(),
    }).catchError((e) {
      debugPrint('LOCATION UPLOAD FAILED (deliveryAgents/$id): $e');
    });

    // live position on each active delivery, for the dashboard + the customer's tracking page
    final orderData = {
      'riderLat': p.latitude,
      'riderLng': p.longitude,
      'riderLastSeen': FieldValue.serverTimestamp(),
    };
    for (final oid in _fleetIds) {
      db.collection('fleetOrders').doc(oid).update(orderData).catchError((e) {
        debugPrint('LOCATION UPLOAD FAILED (fleetOrders/$oid): $e');
      });
    }
    for (final jid in _jobIds) {
      db.collection('deliveryJobs').doc(jid).update(orderData).catchError((e) {
        debugPrint('LOCATION UPLOAD FAILED (deliveryJobs/$jid): $e');
      });
    }
  }
}
