import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/main_navigation.dart';

// ═══════════════════════════════════════════════════════════════
//  PENDING VERIFICATION PAGE
//
//  Shown when agent has registered but isVerified == false.
//  Listens in real-time to their Firestore doc — the moment
//  an admin sets isVerified: true, they are automatically
//  routed to the main app. No manual refresh needed.
// ═══════════════════════════════════════════════════════════════

class PendingVerificationPage extends StatefulWidget {
  final String userId;
  const PendingVerificationPage({super.key, required this.userId});

  @override
  State<PendingVerificationPage> createState() =>
      _PendingVerificationPageState();
}

class _PendingVerificationPageState extends State<PendingVerificationPage>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _sub;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the hourglass
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Watch Firestore in real-time — auto-route when verified
    _sub = FirebaseFirestore.instance
        .collection('deliveryAgents')
        .doc(widget.userId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      final isVerified = doc.data()?['isVerified'] == true;
      if (isVerified) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => MainNavigation(userId: widget.userId),
          ),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),

              // Pulsing icon
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.amber.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Text('⏳', style: TextStyle(fontSize: 44)),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'Account Under Review',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Our team is reviewing your application. You\'ll be automatically let in once verified — no need to refresh.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark
                      ? AppTheme.darkTextTertiary
                      : AppTheme.lightTextTertiary,
                ),
              ),

              const SizedBox(height: 36),

              // Steps
              _StepList(isDark: isDark),

              const SizedBox(height: 32),

              // Live indicator
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.green.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.green.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Blinking green dot
                    _BlinkingDot(),
                    const SizedBox(width: 10),
                    const Text(
                      'Listening for verification...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.green,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Estimated time note
              Text(
                'Usually takes less than 24 hours',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppTheme.darkTextTertiary
                      : AppTheme.lightTextTertiary,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STEP LIST
// ─────────────────────────────────────────────────────────────

class _StepList extends StatelessWidget {
  final bool isDark;
  const _StepList({required this.isDark});

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('Application submitted', true),
      ('Team review in progress', false),
      ('Verification complete — start earning', false),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: List.generate(steps.length, (i) {
          final (label, done) = steps[i];
          final isLast = i == steps.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: done
                          ? AppTheme.green.withOpacity(0.15)
                          : (i == 1
                              ? AppTheme.amber.withOpacity(0.15)
                              : (isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.05))),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done
                            ? AppTheme.green.withOpacity(0.4)
                            : (i == 1
                                ? AppTheme.amber.withOpacity(0.4)
                                : Colors.transparent),
                      ),
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check_rounded,
                              color: AppTheme.green, size: 14)
                          : i == 1
                              ? const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.amber,
                                  ),
                                )
                              : Icon(Icons.lock_outline_rounded,
                                  size: 12,
                                  color: isDark
                                      ? AppTheme.darkTextTertiary
                                      : AppTheme.lightTextTertiary),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 1.5,
                      height: 28,
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.08),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          done ? FontWeight.w700 : FontWeight.w500,
                      color: done
                          ? AppTheme.green
                          : (i == 1
                              ? AppTheme.amber
                              : (isDark
                                  ? AppTheme.darkTextTertiary
                                  : AppTheme.lightTextTertiary)),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  BLINKING DOT
// ─────────────────────────────────────────────────────────────

class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppTheme.green,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
