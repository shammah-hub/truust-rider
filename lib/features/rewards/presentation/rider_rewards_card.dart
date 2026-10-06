import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  RIDER REWARDS WIDGET
//
//  Drop this anywhere — earnings page, profile page, home page.
//  Reads directly from deliveryAgents/{uid} — no extra calls.
//
//  Usage:
//    RiderRewardsCard(userId: currentUserId)
//
//  Place at: lib/features/rewards/presentation/rider_rewards_card.dart
// ═══════════════════════════════════════════════════════════════

// Tier config mirrors cloud function — keep in sync
class _TierInfo {
  final String key;
  final String label;
  final String emoji;
  final List<Color> colors;
  final int minDeliveries;
  final int maxDeliveries;
  final double minRating;

  const _TierInfo({
    required this.key,
    required this.label,
    required this.emoji,
    required this.colors,
    required this.minDeliveries,
    required this.maxDeliveries,
    required this.minRating,
  });
}

const _tiers = [
  _TierInfo(
    key: 'bronze', label: 'Bronze', emoji: '🥉',
    colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
    minDeliveries: 0, maxDeliveries: 20, minRating: 0,
  ),
  _TierInfo(
    key: 'silver', label: 'Silver', emoji: '🥈',
    colors: [Color(0xFF9E9E9E), Color(0xFF616161)],
    minDeliveries: 21, maxDeliveries: 100, minRating: 4.0,
  ),
  _TierInfo(
    key: 'gold', label: 'Gold', emoji: '🥇',
    colors: [Color(0xFFFFB020), Color(0xFFE07800)],
    minDeliveries: 101, maxDeliveries: 299, minRating: 4.5,
  ),
  _TierInfo(
    key: 'elite', label: 'Elite', emoji: '💎',
    colors: [Color(0xFF6C63FF), Color(0xFF1A6BFF)],
    minDeliveries: 300, maxDeliveries: 999999, minRating: 4.8,
  ),
];

_TierInfo _getTierInfo(String key) =>
    _tiers.firstWhere((t) => t.key == key, orElse: () => _tiers.first);

// ─────────────────────────────────────────────────────────────
class RiderRewardsCard extends StatelessWidget {
  final String userId;
  const RiderRewardsCard({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deliveryAgents')
          .doc(userId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};

        final tierKey            = data['tier'] as String? ?? 'bronze';
        final completedDeliveries = (data['completedDeliveries'] as num?)?.toInt() ?? 0;
        final avgRating          = (data['avgRating'] as num?)?.toDouble() ?? 0.0;
        final referralCount      = (data['referralCount'] as num?)?.toInt() ?? 0;
        final isInLaunchWindow   = data['isInLaunchWindow'] as bool? ?? false;
        final launchEndsAt       = (data['launchWindowEndsAt'] as Timestamp?)?.toDate();
        final launchActive       = isInLaunchWindow &&
            launchEndsAt != null &&
            DateTime.now().isBefore(launchEndsAt);

        final tier     = _getTierInfo(tierKey);
        final tierIndex = _tiers.indexWhere((t) => t.key == tierKey);
        final nextTier  = tierIndex < _tiers.length - 1
            ? _tiers[tierIndex + 1] : null;

        // Progress to next tier
        double progress = 1.0;
        int deliveriesNeeded = 0;
        if (nextTier != null) {
          final rangeStart = tier.minDeliveries;
          final rangeEnd   = nextTier.minDeliveries;
          final inRange    = completedDeliveries - rangeStart;
          final totalRange = rangeEnd - rangeStart;
          progress         = (inRange / totalRange).clamp(0.0, 0.99);
          deliveriesNeeded = (rangeEnd - completedDeliveries).clamp(0, 999);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Main tier card ──────────────────────────
            _TierCard(
              tier:                tier,
              nextTier:            nextTier,
              completedDeliveries: completedDeliveries,
              avgRating:           avgRating,
              progress:            progress,
              deliveriesNeeded:    deliveriesNeeded,
              launchActive:        launchActive,
              launchEndsAt:        launchEndsAt,
              isDark:              isDark,
            ),

            const SizedBox(height: 12),

            // ── Referral card ───────────────────────────
            _ReferralCard(
              userId:        userId,
              referralCount: referralCount,
              isDark:        isDark,
            ),

            const SizedBox(height: 12),

            // ── Perks list ──────────────────────────────
            _PerksCard(tier: tier, isDark: isDark),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TIER CARD
// ═══════════════════════════════════════════════════════════════

class _TierCard extends StatelessWidget {
  final _TierInfo tier;
  final _TierInfo? nextTier;
  final int completedDeliveries;
  final double avgRating;
  final double progress;
  final int deliveriesNeeded;
  final bool launchActive;
  final DateTime? launchEndsAt;
  final bool isDark;

  const _TierCard({
    required this.tier,
    required this.nextTier,
    required this.completedDeliveries,
    required this.avgRating,
    required this.progress,
    required this.deliveriesNeeded,
    required this.launchActive,
    required this.launchEndsAt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            tier.colors[0],
            tier.colors[1],
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color:      tier.colors[0].withOpacity(0.4),
            blurRadius: 20,
            offset:     const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30, right: -30,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -20, left: -20,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(children: [
                  Text(tier.emoji,
                      style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${tier.label} Rider',
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          )),
                      Text('$completedDeliveries deliveries completed',
                          style: TextStyle(
                            color:      Colors.white.withOpacity(0.75),
                            fontSize:   13,
                          )),
                    ],
                  ),
                  const Spacer(),
                  // Rating
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   13,
                            fontWeight: FontWeight.w800,
                          )),
                    ]),
                  ),
                ]),

                const SizedBox(height: 20),

                // Launch window banner
                if (launchActive && launchEndsAt != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(
                          color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Text('🎉', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '0% fee active — ends ${_daysLeft(launchEndsAt!)} days',
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // Progress to next tier
                if (nextTier != null) ...[
                  Row(children: [
                    Text('Progress to ${nextTier!.emoji} ${nextTier!.label}',
                        style: TextStyle(
                          color:      Colors.white.withOpacity(0.8),
                          fontSize:   12,
                          fontWeight: FontWeight.w600,
                        )),
                    const Spacer(),
                    Text('$deliveriesNeeded more deliveries',
                        style: TextStyle(
                          color:      Colors.white.withOpacity(0.7),
                          fontSize:   11,
                        )),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:            progress,
                      backgroundColor:  Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.9)),
                      minHeight: 8,
                    ),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(children: [
                      Text('💎', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Text('You\'ve reached the highest tier!',
                          style: TextStyle(
                            color:      Colors.white,
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                          )),
                    ]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _daysLeft(DateTime end) =>
      end.difference(DateTime.now()).inDays.clamp(0, 999);
}

// ═══════════════════════════════════════════════════════════════
//  REFERRAL CARD
// ═══════════════════════════════════════════════════════════════

class _ReferralCard extends StatelessWidget {
  final String userId;
  final int referralCount;
  final bool isDark;

  const _ReferralCard({
    required this.userId,
    required this.referralCount,
    required this.isDark,
  });

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: userId));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Referral code copied!'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final border = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.07);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('👥', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text('Refer a Rider',
                style: TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                )),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        AppTheme.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$referralCount referred',
                  style: const TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w700,
                    color:      AppTheme.success,
                  )),
            ),
          ]),

          const SizedBox(height: 8),

          Text(
            'Earn ₦1,000 for every rider you refer who completes 5 deliveries.',
            style: TextStyle(
              fontSize: 13,
              height:   1.5,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),

          const SizedBox(height: 12),

          // Referral code box
          GestureDetector(
            onTap: () => _copyCode(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurface2
                    : AppTheme.lightSurface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.blue.withOpacity(0.3),
                ),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(
                    userId,
                    style: TextStyle(
                      fontSize:      13,
                      fontWeight:    FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.copy_rounded,
                    size: 18, color: AppTheme.blue),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PERKS CARD
// ═══════════════════════════════════════════════════════════════

class _PerksCard extends StatelessWidget {
  final _TierInfo tier;
  final bool isDark;

  const _PerksCard({required this.tier, required this.isDark});

  static const _allPerks = [
    (tier: 'bronze', icon: Icons.work_outline_rounded,
    text: 'Standard job feed access'),
    (tier: 'silver', icon: Icons.trending_up_rounded,
    text: 'Priority in job feed'),
    (tier: 'silver', icon: Icons.workspace_premium_outlined,
    text: 'Silver badge on profile & bids'),
    (tier: 'gold',   icon: Icons.verified_rounded,
    text: 'Verified badge on profile'),
    (tier: 'gold',   icon: Icons.rocket_launch_rounded,
    text: 'Top of job feed'),
    (tier: 'elite',  icon: Icons.diamond_outlined,
    text: 'Featured first — always'),
    (tier: 'elite',  icon: Icons.build_circle_outlined,
    text: 'Eligible for repair fund'),
  ];

  static const _tierOrder = ['bronze', 'silver', 'gold', 'elite'];

  bool _isUnlocked(String perkTier) {
    final current = _tierOrder.indexOf(tier.key);
    final perk    = _tierOrder.indexOf(perkTier);
    return current >= perk;
  }

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final border = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.07);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Perks',
              style: TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              )),
          const SizedBox(height: 14),
          ..._allPerks.map((perk) {
            final unlocked = _isUnlocked(perk.tier);
            final perkTier = _getTierInfo(perk.tier);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: unlocked
                        ? tier.colors[0].withOpacity(0.15)
                        : (isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.04)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    unlocked ? perk.icon : Icons.lock_outline_rounded,
                    size:  18,
                    color: unlocked
                        ? tier.colors[0]
                        : (isDark
                        ? AppTheme.darkTextTertiary
                        : AppTheme.lightTextTertiary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(perk.text,
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color: unlocked
                            ? (isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary)
                            : (isDark
                            ? AppTheme.darkTextTertiary
                            : AppTheme.lightTextTertiary),
                      )),
                ),
                if (!unlocked) ...[
                  const SizedBox(width: 8),
                  Text('${perkTier.emoji} ${perkTier.label}',
                      style: TextStyle(
                        fontSize:   10,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.darkTextTertiary
                            : AppTheme.lightTextTertiary,
                      )),
                ] else
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.success, size: 18),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TIER BADGE  — small, for bid cards and profile headers
//
//  Usage: TierBadge(tier: 'gold')
// ═══════════════════════════════════════════════════════════════

class TierBadge extends StatelessWidget {
  final String tier;
  final bool small;

  const TierBadge({super.key, required this.tier, this.small = false});

  @override
  Widget build(BuildContext context) {
    final info = _getTierInfo(tier);
    final size = small ? 11.0 : 12.0;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 8,
          vertical:   small ? 3 : 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: info.colors,
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(small ? 6 : 8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(info.emoji, style: TextStyle(fontSize: small ? 10 : 12)),
        const SizedBox(width: 3),
        Text(info.label,
            style: TextStyle(
              color:         Colors.white,
              fontSize:      size,
              fontWeight:    FontWeight.w800,
              letterSpacing: 0.2,
            )),
      ]),
    );
  }
}
