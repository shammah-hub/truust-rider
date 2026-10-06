import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:truust_rider/core/theme/app_theme.dart';
import 'package:truust_rider/data/models/delivery_models.dart';
import 'live_route_map.dart';

// ═══════════════════════════════════════════════════════════════
//  RIDER TRACKING PAGE  (marketplace jobs)
//
//  In-app map with pickup + drop-off pins and the route to the next
//  stop. Writes the rider's live GPS to the deliveryJobs doc (every
//  ~15s). Listens to the job's status, so the page moves from
//  "go to pickup" to "go to drop-off" when the rider confirms pickup.
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
  late final DocumentReference<Map<String, dynamic>> _ref;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _ref = FirebaseFirestore.instance
        .collection('deliveryJobs')
        .doc(widget.job.id);
    _stream = _ref.snapshots(); // created once, not in build()
  }

  // Matches "pickedUp", "picked_up", "PICKED_UP" etc. to the enum.
  DeliveryJobStatus _statusFrom(Map<String, dynamic>? data) {
    final raw =
    (data?['status'] as String?)?.replaceAll('_', '').toLowerCase();
    if (raw == null) return widget.job.status;
    for (final s in DeliveryJobStatus.values) {
      if (s.name.toLowerCase() == raw) return s;
    }
    return widget.job.status;
  }

  LatLng? _ll(dynamic lat, dynamic lng) {
    final a = (lat as num?)?.toDouble();
    final b = (lng as num?)?.toDouble();
    if (a == null || b == null || (a == 0 && b == 0)) return null;
    return LatLng(a, b);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final job = widget.job;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final data = snap.data?.data();

        // Wait for the first read so saved coordinates are used if present.
        if (snap.connectionState == ConnectionState.waiting && data == null) {
          return Scaffold(
            backgroundColor: AppTheme.bg(isDark),
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.blueFor(isDark)),
            ),
          );
        }

        final status = _statusFrom(data);
        final isPickupPhase = status == DeliveryJobStatus.agreed ||
            status == DeliveryJobStatus.pickupPending;

        return Scaffold(
          backgroundColor: AppTheme.bg(isDark),
          body: Column(
            children: [
              Expanded(
                child: LiveRouteMap(
                  pickup: RouteStop(
                    address: job.pickupAddress,
                    latLng: _ll(data?['pickupLat'], data?['pickupLng']),
                  ),
                  dropoff: RouteStop(
                    address: job.destination,
                    latLng: _ll(data?['destLat'], data?['destLng']),
                  ),
                  isPickupPhase: isPickupPhase,
                  locationDoc: _ref,
                ),
              ),
              TrackingInfoCard(
                isDark: isDark,
                badge: isPickupPhase ? 'Pickup phase' : 'Delivery phase',
                amount: '₦${job.agreedAmount?.toStringAsFixed(0) ?? '0'}',
                title: job.itemDescription.isNotEmpty
                    ? job.itemDescription
                    : 'Marketplace job',
                pickup: job.pickupAddress,
                dropoff: job.destination,
              ),
            ],
          ),
        );
      },
    );
  }
}
