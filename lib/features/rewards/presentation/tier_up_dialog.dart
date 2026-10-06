import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  TIER UP DIALOG
//
//  Purely celebratory — never shown alongside or tied to any
//  specific rating a buyer gave. Ratings feed the tier system in
//  aggregate, but a rider should never be able to trace a tier
//  change (or a lack of one) back to a specific delivery/buyer —
//  same reasoning as why per-delivery ratings are never surfaced.
// ═══════════════════════════════════════════════════════════════

const Map<String, ({String label, String emoji})> _tierDisplay = {
  'bronze': (label: 'Bronze', emoji: '🥉'),
  'silver': (label: 'Silver', emoji: '🥈'),
  'gold': (label: 'Gold', emoji: '🥇'),
  'elite': (label: 'Elite', emoji: '💎'),
};

Future<void> showTierUpDialog(
    BuildContext context, {
      required String newTier,
      required bool isDark,
    }) async {
  HapticFeedback.heavyImpact();
  final display = _tierDisplay[newTier] ?? (label: newTier, emoji: '🏆');

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tier up',
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(display.emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'You reached ${display.label} tier!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep up the great work — new perks are now unlocked.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'Awesome!',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    transitionBuilder: (_, anim, __, child) => ScaleTransition(
      scale: Tween<double>(begin: 0.85, end: 1.0)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
      child: FadeTransition(opacity: anim, child: child),
    ),
  );
}
