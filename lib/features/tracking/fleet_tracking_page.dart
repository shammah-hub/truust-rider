import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:truust_rider/core/theme/app_theme.dart';
import 'package:truust_rider/data/models/delivery_models.dart';
import 'live_route_map.dart';

// ═══════════════════════════════════════════════════════════════
//  FLEET ORDER TRACKING PAGE
//
//  In-app map with pickup + drop-off pins and the route to the next
//  stop. Writes the rider's live GPS to the fleetOrders doc (every
//  ~15s) so the agency dashboard and the customer link see it.
//  Listens to the order's status, so tapping "Start delivery" flips
//  this page from "go to pickup" to "go to drop-off" by itself.
// ═══════════════════════════════════════════════════════════════

class FleetTrackingPage extends StatefulWidget {
  final FleetOrder order;

  const FleetTrackingPage({super.key, required this.order});

  @override
  State<FleetTrackingPage> createState() => _FleetTrackingPageState();
}

class _FleetTrackingPageState extends State<FleetTrackingPage> {
  late final DocumentReference<Map<String, dynamic>> _ref;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _ref = FirebaseFirestore.instance
        .collection('fleetOrders')
        .doc(widget.order.id);
    _stream = _ref.snapshots(); // created once, not in build()
  }

  LatLng? _ll(double? lat, double? lng) {
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final order = widget.order;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final status =
            (snap.data?.data()?['status'] as String?) ?? order.status;
        final isPickupPhase = status == 'assigned';
        final stops = order.extraStops.length;

        return Scaffold(
          backgroundColor: AppTheme.bg(isDark),
          body: Column(
            children: [
              Expanded(
                child: LiveRouteMap(
                  pickup: RouteStop(
                    address: order.pickupAddress,
                    latLng: _ll(order.pickupLat, order.pickupLng),
                  ),
                  dropoff: RouteStop(
                    address: order.dropoffAddress,
                    latLng: _ll(order.dropoffLat, order.dropoffLng),
                  ),
                  isPickupPhase: isPickupPhase,
                  locationDoc: _ref,
                ),
              ),
              TrackingInfoCard(
                isDark: isDark,
                badge: isPickupPhase ? 'Agency delivery · Assigned' : 'Agency delivery · In transit',
                amount: order.fee > 0 ? '₦${order.fee.toStringAsFixed(0)}' : null,
                title: order.customerName,
                pickup: order.pickupAddress,
                dropoff: order.dropoffAddress,
                note: stops > 0 ? '+$stops more stop${stops > 1 ? "s" : ""}' : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
