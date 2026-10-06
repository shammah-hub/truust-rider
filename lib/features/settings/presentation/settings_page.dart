import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:truust_rider/features/settings/presentation/privacy_policy_page.dart';
import 'package:truust_rider/features/settings/presentation/report_problem_page.dart';
import 'package:truust_rider/features/settings/presentation/terms_of_use_page.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/wdgets/retro_toggle.dart';
import '../../../data/models/delivery_models.dart';
import '../../../data/repositories/delivery_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import 'help_center_page.dart';

class SettingsPage extends StatefulWidget {
  final String userId;
  const SettingsPage({super.key, required this.userId});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Local-only preference toggles — wire these to SharedPreferences
  // or a backend field whenever you want them to persist/matter.
  bool _hapticsEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _walletLockEnabled = true;

  Future<void> _changeProfilePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (picked == null) return;

    try {
      await context.read<DeliveryRepository>().updateProfilePhoto(
        widget.userId,
        File(picked.path),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _confirmSignOut(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 32, bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.06),
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: AppTheme.error, size: 22),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: [
                    Text(
                      'Sign out?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "You'll need to sign in again to\naccess your account.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        context.read<AuthBloc>().add(SignOutEvent());
                      },
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_rounded,
                    color: AppTheme.error, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete your account?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This is permanent. Your job history, earnings records, and profile will be removed. This cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Account deletion requested. Our team will process this shortly.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                      backgroundColor: AppTheme.error,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  // TODO: wire to a real deleteAccount Cloud Function
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Delete Account',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = context.read<DeliveryRepository>();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F5F7),
      body: SafeArea(
        child: StreamBuilder<DeliveryAgent?>(
          stream: repo.watchAgent(widget.userId),
          builder: (context, snap) {
            final agent = snap.data;

            return SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ─────────────────────────────────
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurface
                                : AppTheme.lightSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.07),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 15,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.lightTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Mini identity strip ────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                      isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.07)
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _changeProfilePhoto,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppTheme.blue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  image: agent?.profilePhotoUrl != null
                                      ? DecorationImage(
                                    image: NetworkImage(
                                        agent!.profilePhotoUrl!),
                                    fit: BoxFit.cover,
                                  )
                                      : null,
                                ),
                                child: agent?.profilePhotoUrl == null
                                    ? Center(
                                  child: Text(
                                    agent?.name.isNotEmpty == true
                                        ? agent!.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.blue,
                                    ),
                                  ),
                                )
                                    : null,
                              ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppTheme.darkSurface
                                        : AppTheme.lightSurface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.blue,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 9,
                                    color: AppTheme.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                agent?.name ?? 'Loading…',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.lightTextPrimary,
                                ),
                              ),
                              Text(
                                agent?.email ?? '',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? AppTheme.darkTextTertiary
                                      : AppTheme.lightTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  // ── Preferences ─────────────────────────────
                  _SectionLabel(label: 'Preferences', isDark: isDark),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      _ToggleRow(
                        icon: isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        // Indigo — matches the system "Display & Brightness"
                        // slot in real iOS Settings.
                        color: AppTheme.indigoFor(isDark),
                        label: 'Dark Mode',
                        isDark: isDark,
                        value: isDark,
                        onChanged: (_) {
                          HapticFeedback.selectionClick();
                          try {
                            context.read<ThemeCubit>().toggle();
                          } catch (_) {}
                        },
                      ),
                      _RowDivider(isDark: isDark),
                      _ToggleRow(
                        icon: Icons.vibration_rounded,
                        // Orange — matches "Sounds & Haptics".
                        color: AppTheme.orangeFor(isDark),
                        label: 'Haptic Feedback',
                        isDark: isDark,
                        value: _hapticsEnabled,
                        onChanged: (v) {
                          setState(() => _hapticsEnabled = v);
                          if (v) HapticFeedback.selectionClick();
                        },
                      ),
                      _RowDivider(isDark: isDark),
                      _ToggleRow(
                        icon: Icons.notifications_none_rounded,
                        // Red — matches "Notifications".
                        color: AppTheme.redFor(isDark),
                        label: 'Push Notifications',
                        isDark: isDark,
                        value: _pushNotificationsEnabled,
                        isLast: true,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _pushNotificationsEnabled = v);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── Security ────────────────────────────────
                  _SectionLabel(label: 'Security', isDark: isDark),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      _ToggleRow(
                        icon: Icons.lock_outline_rounded,
                        // Green — matches money/security-adjacent rows
                        // (this gates the wallet).
                        color: AppTheme.greenFor(isDark),
                        label: 'Lock Wallet with PIN/Biometrics',
                        isDark: isDark,
                        value: _walletLockEnabled,
                        isLast: true,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _walletLockEnabled = v);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── Support ─────────────────────────────────
                  _SectionLabel(label: 'Support', isDark: isDark),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      _LinkRow(
                        icon: Icons.bug_report_outlined,
                        // Gray — a neutral/utility action, not a status.
                        color: AppTheme.gray,
                        label: 'Report a Problem',
                        isDark: isDark,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportProblemPage(userId: widget.userId),
                          ),
                        ),
                      ),
                      _RowDivider(isDark: isDark),
                      _LinkRow(
                        icon: Icons.description_outlined,
                        color: AppTheme.gray,
                        label: 'Terms of Use',
                        isDark: isDark,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TermsOfUsePage()),
                        ),
                      ),
                      _RowDivider(isDark: isDark),
                      _LinkRow(
                        icon: Icons.privacy_tip_outlined,
                        // Blue — matches "Privacy & Security" in real
                        // iOS Settings.
                        color: AppTheme.blueFor(isDark),
                        label: 'Privacy Policy',
                        isDark: isDark,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                        ),
                      ),
                      _RowDivider(isDark: isDark),
                      _LinkRow(
                        icon: Icons.help_outline_rounded,
                        color: AppTheme.tealFor(isDark),
                        label: 'Help Center',
                        isDark: isDark,
                        isLast: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HelpCenterPage(userId: widget.userId),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── Account actions ─────────────────────────
                  _SectionLabel(label: 'Account', isDark: isDark),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      _LinkRow(
                        icon: Icons.logout_rounded,
                        color: AppTheme.gray,
                        label: 'Sign Out',
                        isDark: isDark,
                        onTap: () => _confirmSignOut(context),
                      ),
                      _RowDivider(isDark: isDark),
                      _LinkRow(
                        icon: Icons.delete_outline_rounded,
                        color: AppTheme.redFor(isDark),
                        label: 'Delete Account',
                        isDark: isDark,
                        isDestructive: true,
                        isLast: true,
                        onTap: () => _confirmDeleteAccount(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  Center(
                    child: Text(
                      'Truust Rider · v1.0.0',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextTertiary
                            : AppTheme.lightTextTertiary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED SUB-WIDGETS
// ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color:
        isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _SettingsCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(children: children),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  final bool isDark;
  const _RowDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      // Inset to start after the icon tile (14 padding + 36 tile + 14 gap),
      // same convention real iOS Settings dividers use.
      indent: 64,
      color: isDark
          ? Colors.white.withOpacity(0.07)
          : Colors.black.withOpacity(0.07),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? sub;
  final bool value;
  final bool isDark;
  final bool isLast;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.color,
    required this.label,
    this.sub,
    required this.value,
    required this.isDark,
    required this.onChanged,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            GlossyIconTile(color: color, icon: icon, size: 36, iconSize: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub!,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.2,
                        color: isDark
                            ? AppTheme.darkTextTertiary
                            : AppTheme.lightTextTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Real iOS switch — solid system green when on, gray track
            // when off, no ON/OFF text (that was a custom "branded"
            // switch; a native-looking Cupertino-style switch reads as
            // authentically Apple, matching everything else on this page).
            AppSegmentedToggle(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.greenFor(isDark),
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool isDark;
  final bool isLast;
  final bool isDestructive;
  final VoidCallback onTap;

  const _LinkRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.isLast = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDestructive
        ? AppTheme.error
        : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            GlossyIconTile(color: color, icon: icon, size: 36, iconSize: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ),
            if (!isDestructive)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.lightTextTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
