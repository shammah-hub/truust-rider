// ═══════════════════════════════════════════════════════════════
//  ACTIVE PAGE — current deliveries agent is handling
//  Open list (no cards). One delivery is expanded at a time;
//  the rest are short rows that open when tapped.
//
//  Two sources feed this list: Truust marketplace jobs (bid, won,
//  escrow-backed, OTP to unlock) and fleet orders (an agency's own
//  private dispatch — no bidding, no escrow, no OTP).
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:truust_rider/core/wdgets/app_loader.dart';
import '../../../core/services/rider_location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/delivery_models.dart';
import '../../../data/repositories/delivery_repository.dart';
import '../../tracking/fleet_tracking_page.dart';
import '../../tracking/rider_tracking_page.dart';
import 'otp_entry_page.dart';

class ActivePage extends StatefulWidget {
  final String userId;
  const ActivePage({super.key, required this.userId});

  @override
  State<ActivePage> createState() => _ActivePageState();
}

class _ActivePageState extends State<ActivePage> {
  // Streams are created ONCE, not inside build(). Calling repo.watch...()
  // in build() makes a brand-new subscription on every rebuild (tapping a
  // row, theme change, parent rebuild...), which flashes the loader and
  // re-fetches instead of just listening for live changes.
  late Stream<List<DeliveryJob>> _jobsStream;
  late Stream<List<FleetOrder>> _fleetStream;

  @override
  void initState() {
    super.initState();
    _subscribe();
    // Shares the rider's position while they are online or on a delivery (see rider_location_service.dart).
    RiderLocationService.instance.start(widget.userId);
  }

  @override
  void didUpdateWidget(covariant ActivePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _subscribe();
      RiderLocationService.instance.start(widget.userId);
      _userChose = false;
      _openKey = null;
    }
  }

  // Tell the location service which deliveries are active, so their live position is written to them.
  void _syncSharing(List<_ActiveEntry> entries) {
    RiderLocationService.instance.setActiveOrders(
      fleetOrderIds: [
        for (final e in entries)
          if (e.fleetOrder != null) e.fleetOrder!.id,
      ],
      jobIds: [
        for (final e in entries)
          if (e.job != null && e.job!.status != DeliveryJobStatus.delivered) e.job!.id,
      ],
    );
  }

  void _subscribe() {
    final repo = context.read<DeliveryRepository>();
    _jobsStream = repo.watchActiveJobsForAgent(widget.userId);
    _fleetStream = repo.watchActiveFleetOrdersForAgent(widget.userId);
  }

  // Which row is open. Until the agent taps a row, we pick one for them:
  // the first delivery already in progress, otherwise the newest one.
  String? _openKey;
  bool _userChose = false;

  String? _resolveOpenKey(List<_ActiveEntry> entries) {
    if (_userChose) {
      if (_openKey == null) return null; // agent collapsed everything
      if (entries.any((e) => e.key == _openKey)) return _openKey;
    }
    for (final e in entries) {
      if (e.inProgress) return e.key;
    }
    return entries.first.key;
  }

  void _toggle(String key, String? currentOpen) {
    HapticFeedback.selectionClick();
    setState(() {
      _userChose = true;
      _openKey = currentOpen == key ? null : key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = widget.userId;

    return Scaffold(
      backgroundColor: AppTheme.bg(isDark),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Text(
                'Active deliveries',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: AppTheme.textPrimary(isDark),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<DeliveryJob>>(
                stream: _jobsStream,
                builder: (context, jobsSnap) {
                  return StreamBuilder<List<FleetOrder>>(
                    stream: _fleetStream,
                    builder: (context, fleetSnap) {
                      if (jobsSnap.hasError) {
                        debugPrint('JOBS STREAM ERROR: ${jobsSnap.error}');
                      }
                      if (fleetSnap.hasError) {
                        debugPrint('FLEET STREAM ERROR: ${fleetSnap.error}');
                      }

                      final loading = !jobsSnap.hasData &&
                          !fleetSnap.hasData &&
                          jobsSnap.connectionState == ConnectionState.waiting &&
                          fleetSnap.connectionState == ConnectionState.waiting;

                      if (loading) {
                        return const Center(child: AppLoader());
                      }

                      final jobs = jobsSnap.data ?? [];
                      final fleetOrders = fleetSnap.data ?? [];

                      final entries = <_ActiveEntry>[
                        ...jobs.map((j) => _ActiveEntry.job(j)),
                        ...fleetOrders.map((f) => _ActiveEntry.fleet(f)),
                      ]..sort((a, b) => b.sortKey.compareTo(a.sortKey));

                      // keep the location service in step with what is active
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _syncSharing(entries);
                      });

                      if (entries.isEmpty) {
                        return _EmptyActive(isDark: isDark);
                      }

                      final openKey = _resolveOpenKey(entries);

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: entries.length,
                        itemBuilder: (_, i) {
                          final entry = entries[i];
                          final expanded = entry.key == openKey;
                          void onToggle() => _toggle(entry.key, openKey);

                          return KeyedSubtree(
                            key: ValueKey(entry.key),
                            child: entry.job != null
                                ? _JobRow(
                              job: entry.job!,
                              agentId: userId,
                              isDark: isDark,
                              expanded: expanded,
                              onToggle: onToggle,
                            )
                                : _FleetRow(
                              order: entry.fleetOrder!,
                              agentId: userId,
                              isDark: isDark,
                              expanded: expanded,
                              onToggle: onToggle,
                            ),
                          );
                        },
                      );
                    },
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

// Unifies a marketplace job and a fleet order into one sortable list.
class _ActiveEntry {
  final DeliveryJob? job;
  final FleetOrder? fleetOrder;

  const _ActiveEntry.job(this.job) : fleetOrder = null;
  const _ActiveEntry.fleet(this.fleetOrder) : job = null;

  String get key => job != null ? 'job:${job!.id}' : 'fleet:${fleetOrder!.id}';

  DateTime get sortKey =>
      job?.createdAt ?? fleetOrder?.createdAt ?? DateTime.now();

  // Past the "waiting to pick up" stage, so the agent is actively on it.
  bool get inProgress {
    if (job != null) {
      return job!.status == DeliveryJobStatus.pickedUp ||
          job!.status == DeliveryJobStatus.inTransit ||
          job!.status == DeliveryJobStatus.delivered;
    }
    return fleetOrder!.status == 'in_transit';
  }
}

// ─────────────────────────────────────────────────────────────
//  MARKETPLACE JOB ROW
// ─────────────────────────────────────────────────────────────

class _JobRow extends StatefulWidget {
  final DeliveryJob job;
  final String agentId;
  final bool isDark;
  final bool expanded;
  final VoidCallback onToggle;

  const _JobRow({
    required this.job,
    required this.agentId,
    required this.isDark,
    required this.expanded,
    required this.onToggle,
  });

  @override
  State<_JobRow> createState() => _JobRowState();
}

class _JobRowState extends State<_JobRow> {
  bool _loading = false;
  final _areaCtrl = TextEditingController();

  @override
  void dispose() {
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _markPickedUp() async {
    final photo = await _pickPhoto();
    if (photo == null || !mounted) return;
    setState(() => _loading = true);
    try {
      await context.read<DeliveryRepository>().markPickedUp(
        jobId: widget.job.id,
        agentId: widget.agentId,
        photo: photo,
      );
      HapticFeedback.heavyImpact();
      if (mounted) _openTracking(); // head to the drop-off with the route
    } catch (e) {
      _showError('Failed to update status. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markDelivered() async {
    final photo = await _pickPhoto();
    if (photo == null || !mounted) return;
    setState(() => _loading = true);
    try {
      await context.read<DeliveryRepository>().markDelivered(
        jobId: widget.job.id,
        agentId: widget.agentId,
        photo: photo,
      );
      HapticFeedback.heavyImpact();
    } catch (e) {
      _showError('Failed to upload photo. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateArea() async {
    final area = _areaCtrl.text.trim();
    if (area.isEmpty) return;
    final isDark = widget.isDark;
    try {
      await context.read<DeliveryRepository>().updateTrackingArea(
        jobId: widget.job.id,
        agentId: widget.agentId,
        area: area,
      );
      _areaCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Location updated'),
          backgroundColor: AppTheme.greenFor(isDark),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {}
  }

  Future<File?> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 40,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  void _openOtpEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpEntryPage(
          job: widget.job,
          orderId: widget.job.orderId.isNotEmpty
              ? widget.job.orderId
              : widget.job.id,
          agentId: widget.agentId,
        ),
      ),
    );
  }

  void _openTracking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RiderTrackingPage(job: widget.job, agentId: widget.agentId),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.redFor(widget.isDark),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Color _statusColor(bool isDark) {
    switch (widget.job.status) {
      case DeliveryJobStatus.agreed:
      case DeliveryJobStatus.pickupPending:
        return AppTheme.orangeFor(isDark);
      case DeliveryJobStatus.pickedUp:
      case DeliveryJobStatus.inTransit:
        return AppTheme.blueFor(isDark);
      case DeliveryJobStatus.delivered:
        return AppTheme.greenFor(isDark);
      default:
        return AppTheme.textTertiary(isDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final job = widget.job;
    final hasDeliveryPhoto =
        job.deliveryPhotoUrl != null && job.deliveryPhotoUrl!.isNotEmpty;
    final blue = AppTheme.blueFor(isDark);
    final red = AppTheme.redFor(isDark);

    final mapButton = _PillButton(
      label: 'Open map',
      icon: Icons.map_outlined,
      color: blue,
      foreground: AppTheme.textPrimary(isDark),
      outlined: true,
      onTap: _openTracking,
    );

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Hint(text: 'Marketplace job', isDark: isDark),
        const SizedBox(height: 14),
        _RouteLine(
          isDark: isDark,
          from: job.pickupArea,
          to: job.destinationArea,
        ),
        if (job.itemDescription.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            job.itemDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppTheme.textTertiary(isDark),
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (job.status == DeliveryJobStatus.pickupPending ||
            job.status == DeliveryJobStatus.agreed) ...[
          _ButtonRow(
            primary: _PillButton(
              label: 'Confirm pickup',
              icon: Icons.photo_camera_outlined,
              color: blue,
              loading: _loading,
              onTap: _markPickedUp,
            ),
            secondary: mapButton,
          ),
          const SizedBox(height: 10),
          _Hint(
              text: 'Take a clear photo of the item before leaving the seller.',
              isDark: isDark),
        ] else if (job.status == DeliveryJobStatus.pickedUp ||
            job.status == DeliveryJobStatus.inTransit) ...[
          _AreaField(
            controller: _areaCtrl,
            isDark: isDark,
            onSend: _updateArea,
          ),
          const SizedBox(height: 12),
          _ButtonRow(
            primary: _PillButton(
              label: 'Mark delivered',
              icon: Icons.photo_camera_outlined,
              color: blue,
              loading: _loading,
              onTap: _markDelivered,
            ),
            secondary: mapButton,
          ),
          const SizedBox(height: 10),
          _Hint(
              text:
              'Photo proof is required before you can enter the delivery code.',
              isDark: isDark),
        ] else if (job.status == DeliveryJobStatus.delivered) ...[
          if (hasDeliveryPhoto) ...[
            _PillButton(
              label: 'Enter delivery code',
              icon: Icons.lock_open_rounded,
              color: blue,
              onTap: _openOtpEntry,
            ),
            const SizedBox(height: 10),
            _Hint(text: 'Ask the buyer for their 4-digit code.', isDark: isDark),
          ] else ...[
            Row(children: [
              Icon(Icons.photo_camera_outlined, color: red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upload your delivery photo before entering the code.',
                  style: TextStyle(fontSize: 12, color: red),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _PillButton(
              label: 'Upload delivery photo',
              icon: Icons.photo_camera_outlined,
              color: blue,
              loading: _loading,
              onTap: _markDelivered,
            ),
          ],
        ],
      ],
    );

    return _RowShell(
      isDark: isDark,
      expanded: widget.expanded,
      onToggle: widget.onToggle,
      statusColor: _statusColor(isDark),
      statusLabel: job.status.label,
      title: '₦${job.agreedAmount?.toStringAsFixed(0) ?? '0'}',
      subtitle: '${job.pickupArea} → ${job.destinationArea}',
      body: body,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  FLEET ORDER ROW — agency's own private dispatch
// ─────────────────────────────────────────────────────────────

class _FleetRow extends StatefulWidget {
  final FleetOrder order;
  final String agentId;
  final bool isDark;
  final bool expanded;
  final VoidCallback onToggle;

  const _FleetRow({
    required this.order,
    required this.agentId,
    required this.isDark,
    required this.expanded,
    required this.onToggle,
  });

  @override
  State<_FleetRow> createState() => _FleetRowState();
}

class _FleetRowState extends State<_FleetRow> {
  bool _loading = false;

  Future<void> _startDelivery() async {
    setState(() => _loading = true);
    try {
      await context.read<DeliveryRepository>().markFleetOrderInTransit(
        orderId: widget.order.id,
        agentId: widget.agentId,
      );
      HapticFeedback.mediumImpact();
      if (mounted) _openTracking(); // start sharing location straight away
    } catch (e) {
      _showError('Failed to update status. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markDelivered() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 40,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (picked == null || !mounted) return;

    setState(() => _loading = true);
    try {
      await context.read<DeliveryRepository>().markFleetOrderDelivered(
        orderId: widget.order.id,
        agentId: widget.agentId,
        photo: File(picked.path),
      );
      HapticFeedback.heavyImpact();
    } catch (e) {
      _showError('Failed to upload photo. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openTracking() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FleetTrackingPage(order: widget.order)),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.redFor(widget.isDark),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final order = widget.order;
    final blue = AppTheme.blueFor(isDark);
    final isAssigned = order.status == 'assigned';
    final hasFee = order.fee > 0;

    final mapButton = _PillButton(
      label: 'Open map',
      icon: Icons.map_outlined,
      color: blue,
      foreground: AppTheme.textPrimary(isDark),
      outlined: true,
      onTap: _openTracking,
    );

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Hint(text: 'Agency delivery', isDark: isDark),
        if (hasFee) ...[
          const SizedBox(height: 4),
          Text(
            order.customerName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(isDark),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _RouteLine(
          isDark: isDark,
          from: order.pickupAddress,
          to: order.dropoffAddress,
        ),
        if (order.extraStops.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '+${order.extraStops.length} more stop${order.extraStops.length > 1 ? "s" : ""}',
            style:
            TextStyle(fontSize: 11, color: AppTheme.textTertiary(isDark)),
          ),
        ],
        const SizedBox(height: 18),
        if (isAssigned) ...[
          _ButtonRow(
            primary: _PillButton(
              label: 'Start delivery',
              icon: Icons.play_arrow_rounded,
              color: blue,
              loading: _loading,
              onTap: _startDelivery,
            ),
            secondary: mapButton,
          ),
        ] else if (order.status == 'in_transit') ...[
          _ButtonRow(
            primary: _PillButton(
              label: 'Mark delivered',
              icon: Icons.photo_camera_outlined,
              color: blue,
              loading: _loading,
              onTap: _markDelivered,
            ),
            secondary: mapButton,
          ),
          const SizedBox(height: 10),
          _Hint(
              text: 'Photo proof helps your agency resolve delivery disputes.',
              isDark: isDark),
        ],
      ],
    );

    return _RowShell(
      isDark: isDark,
      expanded: widget.expanded,
      onToggle: widget.onToggle,
      statusColor: isAssigned ? AppTheme.orangeFor(isDark) : blue,
      statusLabel: isAssigned ? 'Assigned' : 'In transit',
      title: hasFee ? '₦${order.fee.toStringAsFixed(0)}' : order.customerName,
      subtitle: '${order.pickupAddress} → ${order.dropoffAddress}',
      body: body,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED PIECES
// ─────────────────────────────────────────────────────────────

/// One delivery in the list: a flat card (no shadow) with a tappable
/// summary and an expandable body.
class _RowShell extends StatelessWidget {
  final bool isDark;
  final bool expanded;
  final VoidCallback onToggle;
  final Color statusColor;
  final String statusLabel;
  final String title;
  final String subtitle;
  final Widget body;

  const _RowShell({
    required this.isDark,
    required this.expanded,
    required this.onToggle,
    required this.statusColor,
    required this.statusLabel,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppTheme.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: expanded ? 26 : 16,
                            fontWeight: expanded ? FontWeight.w700 : FontWeight.w600,
                            letterSpacing: expanded ? -0.5 : 0,
                            color: AppTheme.textPrimary(isDark),
                          ),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!expanded) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textTertiary(isDark),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusChip(
                    isDark: isDark,
                    color: statusColor,
                    label: statusLabel,
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: AppTheme.textTertiary(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: SizedBox(width: double.infinity, child: body),
            )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Small stadium outline: status dot plus plain text.
class _StatusChip extends StatelessWidget {
  final bool isDark;
  final Color color;
  final String label;

  const _StatusChip({
    required this.isDark,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(color: AppTheme.border(isDark)),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(isDark),
          ),
        ),
      ]),
    );
  }
}

/// Pickup and drop-off stacked in a column, joined by a thin line.
class _RouteLine extends StatelessWidget {
  final bool isDark;
  final String from;
  final String to;

  const _RouteLine({
    required this.isDark,
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    final strong = AppTheme.textPrimary(isDark);
    final soft = AppTheme.textTertiary(isDark);

    final nameStyle = TextStyle(
      fontSize: 15,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: strong,
    );
    final labelStyle = TextStyle(fontSize: 11, height: 1.3, color: soft);

    Widget stop(String label, String name) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: nameStyle,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pickup, with the connecting line running down to the next dot.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 10,
                child: Column(children: [
                  const SizedBox(height: 3),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: strong, width: 1.5),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: soft,
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: stop('Pickup', from),
                ),
              ),
            ],
          ),
        ),
        // Drop-off
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: strong, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: stop('Drop-off', to)),
          ],
        ),
      ],
    );
  }
}

/// Two stadium buttons side by side: the next action (filled) and a
/// secondary one (outlined).
class _ButtonRow extends StatelessWidget {
  final Widget primary;
  final Widget secondary;
  const _ButtonRow({required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: primary),
      const SizedBox(width: 8),
      Expanded(child: secondary),
    ]);
  }
}

/// Stadium button with an iOS "puffy" look: a soft vertical gradient,
/// a glossy highlight along the top, and a defined edge. No drop shadow.
/// Filled for the main action, outlined for secondary.
class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color? foreground; // text/icon colour for the outlined style
  final bool outlined;
  final bool loading;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.foreground,
    this.outlined = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = outlined ? (foreground ?? color) : Colors.white;

    // Body gradient + edge
    final List<Color> gradient;
    final Color edge;
    final double edgeWidth;
    final double sheenTop;
    final double sheenBottom;

    if (outlined) {
      final base = AppTheme.surface(isDark);
      final lowEnd = Color.lerp(
        AppTheme.surface2(isDark),
        isDark ? Colors.white : Colors.black,
        0.06,
      )!;
      gradient = [base, lowEnd];
      edge = fg;
      edgeWidth = 1.6;
      sheenTop = isDark ? 0.14 : 0.85;
      sheenBottom = 0.0;
    } else {
      gradient = [
        Color.lerp(color, Colors.white, 0.22)!,
        color,
        Color.lerp(color, Colors.black, 0.14)!,
      ];
      edge = Color.lerp(color, Colors.black, 0.2)!;
      edgeWidth = 1;
      sheenTop = 0.38;
      sheenBottom = 0.04;
    }

    return SizedBox(
      height: 46,
      width: double.infinity,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient,
            stops: outlined ? null : const [0.0, 0.55, 1.0],
          ),
          shape: StadiumBorder(
            side: BorderSide(color: edge, width: edgeWidth),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: Stack(
            children: [
              // glossy highlight across the top half
              Positioned(
                top: 2,
                left: 10,
                right: 10,
                height: 20,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(sheenTop),
                          Colors.white.withOpacity(sheenBottom),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: loading ? null : onTap,
                    child: Center(
                      child: loading
                          ? const SizedBox(
                          width: 18, height: 18, child: AppLoader())
                          : Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: fg, size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: fg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  final bool isDark;
  const _Hint({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        height: 1.4,
        color: AppTheme.textTertiary(isDark),
      ),
    );
  }
}

class _AreaField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final VoidCallback onSend;

  const _AreaField({
    required this.controller,
    required this.isDark,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: ShapeDecoration(
        color: AppTheme.surface2(isDark),
        shape: const StadiumBorder(),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(isDark)),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: 'Current area, e.g. Yaba',
              hintStyle:
              TextStyle(fontSize: 13, color: AppTheme.textTertiary(isDark)),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        IconButton(
          onPressed: onSend,
          icon: Icon(Icons.arrow_upward_rounded,
              size: 18, color: AppTheme.blueFor(isDark)),
          tooltip: 'Update area',
        ),
      ]),
    );
  }
}

class _EmptyActive extends StatelessWidget {
  final bool isDark;
  const _EmptyActive({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 36, color: AppTheme.textTertiary(isDark)),
            const SizedBox(height: 14),
            Text(
              'No active deliveries',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Accept a job from the Jobs tab, or wait for your agency to assign one.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppTheme.textTertiary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
