// ═══════════════════════════════════════════════════════════════
//  ACTIVE PAGE — current deliveries agent is handling
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/delivery_models.dart';
import '../../../data/repositories/delivery_repository.dart';
import '../../tracking/rider_tracking_page.dart';
import 'otp_entry_page.dart';

class ActivePage extends StatelessWidget {
  final String userId;
  const ActivePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = context.read<DeliveryRepository>();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text(
                'Active Deliveries',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<DeliveryJob>>(
                stream: repo.watchActiveJobsForAgent(userId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.blue));
                  }

                  final jobs = snap.data ?? [];

                  if (jobs.isEmpty) {
                    return _EmptyActive(isDark: isDark);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: jobs.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ActiveJobCard(
                      job: jobs[i],
                      agentId: userId,
                      isDark: isDark,
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

class _ActiveJobCard extends StatefulWidget {
  final DeliveryJob job;
  final String agentId;
  final bool isDark;

  const _ActiveJobCard({
    required this.job,
    required this.agentId,
    required this.isDark,
  });

  @override
  State<_ActiveJobCard> createState() => _ActiveJobCardState();
}

class _ActiveJobCardState extends State<_ActiveJobCard> {
  bool _loading = false;
  final _areaCtrl = TextEditingController();

  @override
  void dispose() {
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _markPickedUp() async {
    final photo = await _pickPhoto();
    if (photo == null) return;
    setState(() => _loading = true);
    try {
      await context.read<DeliveryRepository>().markPickedUp(
        jobId: widget.job.id,
        agentId: widget.agentId,
        photo: photo,
      );
      HapticFeedback.heavyImpact();
    } catch (e) {
      _showError('Failed to update status. Try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _markDelivered() async {
    final photo = await _pickPhoto();
    if (photo == null) return;
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
      setState(() => _loading = false);
    }
  }

  Future<void> _updateArea() async {
    final area = _areaCtrl.text.trim();
    if (area.isEmpty) return;
    try {
      await context.read<DeliveryRepository>().updateTrackingArea(
        jobId: widget.job.id,
        agentId: widget.agentId,
        area: area,
      );
      _areaCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Location updated'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ));
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
        builder: (_) => RiderTrackingPage(
          job: widget.job,
          agentId: widget.agentId,
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));
  }

  Color get _statusColor {
    switch (widget.job.status) {
      case DeliveryJobStatus.agreed:
      case DeliveryJobStatus.pickupPending:
        return AppTheme.amber;
      case DeliveryJobStatus.pickedUp:
      case DeliveryJobStatus.inTransit:
        return AppTheme.blue;
      case DeliveryJobStatus.delivered:
        return AppTheme.success;
      default:
        return AppTheme.darkTextTertiary;
    }
  }

  Widget get _mapButton => GestureDetector(
    onTap: _openTracking,
    child: Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.blue.withOpacity(0.3)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_rounded, color: AppTheme.blue, size: 16),
          SizedBox(width: 8),
          Text(
            '🗺️ Open Navigation Map',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.blue,
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final hasDeliveryPhoto =
        job.deliveryPhotoUrl != null && job.deliveryPhotoUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status + amount
          Row(children: [
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                job.status.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _statusColor,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '₦${job.agreedAmount?.toStringAsFixed(0) ?? '0'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.success,
              ),
            ),
          ]),

          const SizedBox(height: 12),

          Text(
            '${job.pickupArea} → ${job.destinationArea}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: widget.isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            job.itemDescription,
            style: TextStyle(
              fontSize: 12,
              color: widget.isDark
                  ? AppTheme.darkTextTertiary
                  : AppTheme.lightTextTertiary,
            ),
          ),

          const SizedBox(height: 14),

          // ── STEP 1: Pick up ───────────────────────────────
          if (job.status == DeliveryJobStatus.pickupPending ||
              job.status == DeliveryJobStatus.agreed) ...[
            _mapButton,
            const SizedBox(height: 8),
            _ActionBtn(
              label: '📸 Take Pickup Photo & Confirm',
              color: AppTheme.amber,
              loading: _loading,
              onTap: _markPickedUp,
            ),
            const SizedBox(height: 6),
            Text(
              'Take a clear photo of the item before leaving the seller.',
              style: TextStyle(
                fontSize: 11,
                color: widget.isDark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.lightTextTertiary,
              ),
            ),

            // ── STEP 2: In transit ────────────────────────────
          ] else if (job.status == DeliveryJobStatus.pickedUp ||
              job.status == DeliveryJobStatus.inTransit) ...[
            _mapButton,
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? AppTheme.darkSurface2
                        : AppTheme.lightSurface2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _areaCtrl,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Update your area (e.g. Yaba)',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: widget.isDark
                            ? AppTheme.darkTextTertiary
                            : AppTheme.lightTextTertiary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _updateArea,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: AppTheme.blue, size: 16),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _ActionBtn(
              label: '📸 Take Delivery Photo & Mark Delivered',
              color: AppTheme.success,
              loading: _loading,
              onTap: _markDelivered,
            ),
            const SizedBox(height: 6),
            Text(
              'Photo proof required before you can enter the delivery code.',
              style: TextStyle(
                fontSize: 11,
                color: widget.isDark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.lightTextTertiary,
              ),
            ),

            // ── STEP 3: Delivered — OTP entry ─────────────────
          ] else if (job.status == DeliveryJobStatus.delivered) ...[
            if (hasDeliveryPhoto) ...[
              GestureDetector(
                onTap: _openOtpEntry,
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.blue.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_open_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Enter Delivery Code',
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
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Ask the buyer for their 4-digit code',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isDark
                        ? AppTheme.darkTextTertiary
                        : AppTheme.lightTextTertiary,
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.error.withOpacity(0.25)),
                ),
                child: const Row(children: [
                  Icon(Icons.photo_camera_outlined,
                      color: AppTheme.error, size: 16),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Upload delivery photo first before entering the code.',
                      style:
                      TextStyle(fontSize: 12, color: AppTheme.error),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              _ActionBtn(
                label: '📸 Upload Delivery Photo',
                color: AppTheme.amber,
                loading: _loading,
                onTap: _markDelivered,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 46,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Center(
          child: loading
              ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: color),
          )
              : Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyActive extends StatelessWidget {
  final bool isDark;
  const _EmptyActive({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🚴', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'No active deliveries',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Accept a job from the Jobs tab to start earning',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppTheme.darkTextTertiary
                  : AppTheme.lightTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
