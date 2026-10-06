import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:truust_rider/core/wdgets/app_loader.dart';
import 'package:truust_rider/data/models/delivery_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../data/repositories/delivery_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../settings/presentation/settings_page.dart';

// ═══════════════════════════════════════════════════════════════
//  PROFILE PAGE
//
//  Apple system pattern: blue is reserved for the one tappable
//  action on this screen (the edit/save button) — nothing else
//  is blue. Verified/pending stays green/orange (status, not
//  action). Everything else — cards, dividers, labels — stays
//  neutral black/white/gray, same as before.
// ═══════════════════════════════════════════════════════════════

class ProfilePage extends StatefulWidget {
  final String userId;
  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final updates = <String, dynamic>{};
      if (_nameCtrl.text.trim().isNotEmpty) {
        updates['name'] = _nameCtrl.text.trim();
      }
      if (_cityCtrl.text.trim().isNotEmpty) {
        updates['city'] = _cityCtrl.text.trim();
      }
      if (_phoneCtrl.text.trim().isNotEmpty) {
        updates['phone'] = _phoneCtrl.text.trim();
      }
      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('deliveryAgents')
            .doc(widget.userId)
            .update(updates);
      }
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Profile updated',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            backgroundColor: AppTheme.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blue = AppTheme.blueFor(isDark);
    final repo = context.read<DeliveryRepository>();

    return Scaffold(
      backgroundColor: AppTheme.bg(isDark),
      body: SafeArea(
        child: StreamBuilder(
          stream: repo.watchAgent(widget.userId),
          builder: (context, agentSnap) {
            final agent = agentSnap.data;

            if (agent != null &&
                _nameCtrl.text.isEmpty &&
                _cityCtrl.text.isEmpty) {
              _nameCtrl.text = agent.name;
              _cityCtrl.text = agent.city ?? '';
              _phoneCtrl.text = agent.phone ?? '';
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('deliveryJobs')
                  .where('agentId', isEqualTo: widget.userId)
                  .where('status', isEqualTo: 'completed')
                  .snapshots(),
              builder: (context, jobsSnap) {
                final completedJobs = jobsSnap.data?.docs ?? [];
                final totalDeliveries = completedJobs.length;

                double totalEarnings = 0;
                for (final doc in completedJobs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final fee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
                  totalEarnings += fee * 0.9;
                }

                return SingleChildScrollView(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ───────────────────────────────
                      Row(
                        children: [
                          Text(
                            'Profile',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: AppTheme.textPrimary(isDark),
                            ),
                          ),
                          const Spacer(),
                          // Edit/Save is the one action on this screen —
                          // it's the only thing that turns blue.
                          _IconBtn(
                            isDark: isDark,
                            icon: _isEditing
                                ? Icons.check_rounded
                                : Icons.edit_rounded,
                            isActive: _isEditing,
                            isLoading: _isSaving,
                            onTap: () {
                              if (_isEditing) {
                                _saveProfile();
                              } else {
                                setState(() => _isEditing = true);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          _IconBtn(
                            isDark: isDark,
                            icon: Icons.settings_outlined,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SettingsPage(userId: widget.userId),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── Identity card — neutral surface, not blue.
                      //    The old gradient card made the whole header
                      //    read as "the action," competing with the
                      //    edit button. This is just information.
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.surface(isDark),
                          borderRadius:
                          BorderRadius.circular(AppTheme.radiusLg),
                          border: Border.all(color: AppTheme.border(isDark)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppTheme.surface2(isDark),
                                shape: BoxShape.circle,
                                border:
                                Border.all(color: AppTheme.border(isDark)),
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
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary(isDark),
                                  ),
                                ),
                              )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    agent?.name ?? 'Loading…',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                      color: AppTheme.textPrimary(isDark),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _StatusPill(
                                    isDark: isDark,
                                    verified: agent?.isVerified == true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Stats row — one meaning-color each ────
                      Row(
                        children: [
                          _StatTile(
                            label: 'Deliveries',
                            value: '$totalDeliveries',
                            icon: Icons.local_shipping_rounded,
                            color: AppTheme.indigoFor(isDark),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 10),
                          _StatTile(
                            label: 'Rating',
                            value: agent?.rating != null
                                ? agent!.rating!.toStringAsFixed(1)
                                : '—',
                            icon: Icons.star_rounded,
                            color: AppTheme.orangeFor(isDark),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 10),
                          _StatTile(
                            label: 'Earned',
                            value: '₦${_fmt(totalEarnings)}',
                            icon: Icons.account_balance_wallet_rounded,
                            color: AppTheme.greenFor(isDark),
                            isDark: isDark,
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── Personal Info ─────────────────────────
                      _SectionLabel(label: 'Personal Info', isDark: isDark),
                      const SizedBox(height: 10),

                      _InfoCard(
                        isDark: isDark,
                        children: [
                          _InfoRow(
                            label: 'Full Name',
                            controller: _nameCtrl,
                            icon: Icons.person_rounded,
                            isEditing: _isEditing,
                            isDark: isDark,
                          ),
                          _Divider(isDark: isDark),
                          _InfoRow(
                            label: 'City',
                            controller: _cityCtrl,
                            icon: Icons.location_city_rounded,
                            isEditing: _isEditing,
                            isDark: isDark,
                          ),
                          _Divider(isDark: isDark),
                          _InfoRow(
                            label: 'Phone',
                            controller: _phoneCtrl,
                            icon: Icons.phone_rounded,
                            isEditing: _isEditing,
                            isDark: isDark,
                            keyboardType: TextInputType.phone,
                            isLast: true,
                          ),
                        ],
                      ),

                      if (_isEditing) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => setState(() => _isEditing = false),
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.surface(isDark),
                              borderRadius: BorderRadius.circular(14),
                              border:
                              Border.all(color: AppTheme.border(isDark)),
                            ),
                            child: Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary(isDark),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // ── Vehicles ───────────────────────────────
                      if (agent?.vehicles.isNotEmpty == true) ...[
                        const SizedBox(height: 28),
                        _SectionLabel(label: 'My Vehicles', isDark: isDark),
                        const SizedBox(height: 10),
                        _InfoCard(
                          isDark: isDark,
                          children: [
                            ...agent!.vehicles.asMap().entries.map((entry) {
                              final i = entry.key;
                              final v = entry.value;
                              final isLast = i == agent.vehicles.length - 1;
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface2(isDark),
                                          borderRadius:
                                          BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            v.type.emoji,
                                            style:
                                            const TextStyle(fontSize: 20),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              v.plate,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                                color:
                                                AppTheme.textPrimary(isDark),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${v.type.label} · ${v.type.weightRange}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textTertiary(
                                                    isDark),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Verified/Pending is status, not
                                      // action — stays green/orange.
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: iosTint(
                                            v.isVerified
                                                ? AppTheme.greenFor(isDark)
                                                : AppTheme.orangeFor(isDark),
                                            isDark ? 0.22 : 0.12,
                                          ),
                                          borderRadius:
                                          BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          v.isVerified ? 'Verified' : 'Pending',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: v.isVerified
                                                ? AppTheme.greenFor(isDark)
                                                : AppTheme.orangeFor(isDark),
                                          ),
                                        ),
                                      ),
                                    ]),
                                  ),
                                  if (!isLast) _Divider(isDark: isDark),
                                ],
                              );
                            }),
                          ],
                        ),
                      ],
                      const SizedBox(height: 36),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _fmt(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k';
    return amount.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────

/// Verified / Pending Verification pill for the identity card.
/// Status, not action — green or orange, never blue.
class _StatusPill extends StatelessWidget {
  final bool isDark;
  final bool verified;
  const _StatusPill({required this.isDark, required this.verified});

  @override
  Widget build(BuildContext context) {
    final color =
    verified ? AppTheme.greenFor(isDark) : AppTheme.orangeFor(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: iosTint(color, isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.check_circle_rounded : Icons.access_time_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'Verified agent' : 'Pending verification',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grouped card container — replaces individual bordered boxes
class _InfoCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _InfoCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(isDark)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

/// A thin hairline divider inside cards
class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 52,
      endIndent: 0,
      color: AppTheme.border(isDark),
    );
  }
}

/// Single info row inside the grouped card. The leading icon turns
/// green while editing — "this field is live," not "tap this" —
/// blue is reserved for the header's edit/save button only.
class _InfoRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool isEditing;
  final bool isDark;
  final TextInputType keyboardType;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.controller,
    required this.icon,
    required this.isEditing,
    required this.isDark,
    this.keyboardType = TextInputType.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: isEditing
                ? AppTheme.greenFor(isDark)
                : AppTheme.textTertiary(isDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isEditing
                ? TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary(isDark),
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: label,
                hintStyle:
                TextStyle(color: AppTheme.textTertiary(isDark)),
                contentPadding:
                const EdgeInsets.symmetric(vertical: 16),
              ),
            )
                : Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textTertiary(isDark),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    controller.text.isNotEmpty ? controller.text : '—',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(isDark),
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
        color: AppTheme.textTertiary(isDark),
      ),
    );
  }
}

/// Stat card — same glossy-tile language as the dashboard's stat
/// cards, one meaning-color per stat (indigo/orange/green), no blue.
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border(isDark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlossyIconTile(color: color, icon: icon, size: 30, iconSize: 15),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppTheme.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppTheme.textTertiary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top-right icon button. `isActive` means "this is the current
/// action" (Save mode) — that's the only state that turns blue.
class _IconBtn extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final bool isLoading;

  const _IconBtn({
    required this.isDark,
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final blue = AppTheme.blueFor(isDark);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isActive ? blue : AppTheme.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: isActive ? null : Border.all(color: AppTheme.border(isDark)),
        ),
        child: isLoading
            ? const Center(
          child: SizedBox(width: 15, height: 15, child: AppLoader()),
        )
            : Icon(
          icon,
          size: 17,
          color: isActive ? Colors.white : AppTheme.textSecondary(isDark),
        ),
      ),
    );
  }
}
