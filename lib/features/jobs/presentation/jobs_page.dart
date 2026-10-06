import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:truust_rider/core/wdgets/app_loader.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/delivery_models.dart';
import '../../../data/repositories/delivery_repository.dart';
import 'job_detail_page.dart';

// ═══════════════════════════════════════════════════════════════
//  JOBS PAGE
//
//  Apple system pattern: blue marks the one action every card
//  offers ("tap to bid"), plus the pickup point and the arrow —
//  all part of the same "do this" affordance. Green stays for
//  online/success status. Weight-category colors (indigo/orange
//  for medium/heavy/bulk) are categorical, same convention as
//  the vehicle-type colors elsewhere in the app.
// ═══════════════════════════════════════════════════════════════

class JobsPage extends StatefulWidget {
  final String userId;
  final bool isVerified;
  const JobsPage({super.key, required this.userId, this.isVerified = true});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  bool _isAvailable = true;

  // Agency-linked riders are vouched for by their agency, so they can go
  // online without Truust's own verification.
  bool _linkedToAgency = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _agentSub;
  Timer? _locationTimer;

  bool get _canGoOnline => widget.isVerified || _linkedToAgency;

  @override
  void initState() {
    super.initState();
    _agentSub = FirebaseFirestore.instance
        .collection('deliveryAgents')
        .doc(widget.userId)
        .snapshots()
        .listen((snap) {
      final linked = snap.data()?['agencyId'] != null;
      if (!mounted) return;
      if (linked != _linkedToAgency) {
        setState(() => _linkedToAgency = linked);
        _syncLocationTracking();
      }
    });
    _syncLocationTracking();
  }

  @override
  void dispose() {
    _agentSub?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  // While online, write the rider's position every minute so jobs can be
  // matched to the nearest riders. Stops when they go offline.
  void _syncLocationTracking() {
    final shouldTrack = _isAvailable && _canGoOnline;
    if (!shouldTrack) {
      _locationTimer?.cancel();
      _locationTimer = null;
      return;
    }
    if (_locationTimer != null) return;
    _writeLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 60), (_) => _writeLocation());
  }

  Future<void> _writeLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await FirebaseFirestore.instance.collection('deliveryAgents').doc(widget.userId).update({
        'lastLocation': {'lat': pos.latitude, 'lng': pos.longitude},
        'lastLocationAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Best-effort — a missed ping shouldn't interrupt the rider.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = context.read<DeliveryRepository>();

    return Scaffold(
      backgroundColor: AppTheme.bg(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Jobs',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: AppTheme.textPrimary(isDark),
                        ),
                      ),
                      Text(
                        'Jobs matching your vehicles',
                        style: TextStyle(fontSize: 12, color: AppTheme.textTertiary(isDark)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Availability toggle — disabled entirely until
                  // verified, so an unverified rider can't flip
                  // online even by mistake.
                  _AvailabilityToggle(
                    isAvailable: _isAvailable,
                    isEnabled: _canGoOnline,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final newValue = !_isAvailable;
                      setState(() => _isAvailable = newValue);
                      _syncLocationTracking();
                      repo.updateAvailability(widget.userId, newValue);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Jobs list
            Expanded(
              child: !_canGoOnline
                  ? _NotVerifiedView(isDark: isDark)
                  : StreamBuilder<List<DeliveryJob>>(
                stream: repo.watchAvailableJobs(widget.userId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: AppLoader());
                  }

                  if (!_isAvailable) {
                    return _OfflineView(
                      isDark: isDark,
                      onGoOnline: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isAvailable = true);
                        _syncLocationTracking();
                        repo.updateAvailability(widget.userId, true);
                      },
                    );
                  }

                  final jobs = snap.data ?? [];

                  if (jobs.isEmpty) {
                    return _EmptyJobs(isDark: isDark);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: jobs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _JobCard(
                      job: jobs[i],
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JobDetailPage(
                            job: jobs[i],
                            agentId: widget.userId,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  JOB CARD
// ─────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  final DeliveryJob job;
  final bool isDark;
  final VoidCallback onTap;

  const _JobCard({required this.job, required this.isDark, required this.onTap});

  Color _weightColor(bool isDark) {
    switch (job.weightCategory) {
      case WeightCategory.light:
        return AppTheme.blueFor(isDark);
      case WeightCategory.medium:
        return AppTheme.carColor;
      case WeightCategory.heavy:
        return AppTheme.pickupColor;
      case WeightCategory.bulk:
        return AppTheme.truckColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final blue = AppTheme.blueFor(isDark);
    final green = AppTheme.greenFor(isDark);
    final weightColor = _weightColor(isDark);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface(isDark),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border(isDark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
                // Weight badge — categorical color, not an action
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: iosTint(weightColor, isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm - 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(job.weightCategory.emoji, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        job.weightCategory.label,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: weightColor),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (job.bidCount > 0)
                  Text(
                    '${job.bidCount} bid${job.bidCount > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textTertiary(isDark)),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Route
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RoutePoint(
                        label: 'Pickup',
                        area: job.pickupArea,
                        color: blue,
                        isDark: isDark,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(width: 1, height: 16, color: AppTheme.border(isDark)),
                      ),
                      _RoutePoint(
                        label: 'Deliver',
                        area: job.destinationArea,
                        color: green,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                // Arrow — part of the "tap to bid" action, flat blue
                // (no gradient — a filled iOS button is one solid color).
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: blue,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Divider(height: 1, color: AppTheme.border(isDark)),
            const SizedBox(height: 10),

            // Item description + weight
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 13, color: AppTheme.textTertiary(isDark)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${job.itemDescription} · ${job.weightKg}kg',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(isDark)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Tap to bid',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: blue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityToggle extends StatelessWidget {
  final bool isAvailable;
  final bool isEnabled;
  final bool isDark;
  final VoidCallback onTap;

  const _AvailabilityToggle({
    required this.isAvailable,
    required this.isEnabled,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final green = AppTheme.greenFor(isDark);
    final trackColor = AppTheme.surface2(isDark);

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.4,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAvailable ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isAvailable ? green : AppTheme.textTertiary(isDark),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 64,
              height: 30,
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border(isDark)),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: isAvailable ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    width: 28,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isAvailable ? green : AppTheme.gray3,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final String label;
  final String area;
  final Color color;
  final bool isDark;

  const _RoutePoint({
    required this.label,
    required this.area,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textTertiary(isDark))),
            Text(
              area,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary(isDark)),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyJobs extends StatelessWidget {
  final bool isDark;
  const _EmptyJobs({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📦', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'No jobs available right now',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary(isDark)),
          ),
          const SizedBox(height: 6),
          Text(
            'New jobs will appear here.\nStay online to be notified.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textTertiary(isDark)),
          ),
        ],
      ),
    );
  }
}

class _NotVerifiedView extends StatelessWidget {
  final bool isDark;
  const _NotVerifiedView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⏳', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Waiting on verification',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary(isDark)),
            ),
            const SizedBox(height: 6),
            Text(
              'Once our team approves your application, available jobs will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textTertiary(isDark)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineView extends StatelessWidget {
  final bool isDark;
  final VoidCallback onGoOnline;
  const _OfflineView({required this.isDark, required this.onGoOnline});

  @override
  Widget build(BuildContext context) {
    final green = AppTheme.greenFor(isDark);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('😴', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'You\'re offline',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary(isDark)),
          ),
          const SizedBox(height: 6),
          Text(
            'Go online to see available jobs',
            style: TextStyle(fontSize: 13, color: AppTheme.textTertiary(isDark)),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onGoOnline,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
              child: const Text(
                'Go Online',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
