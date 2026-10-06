import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truust_rider/core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  RIDER ONBOARDING
//
//  Same iOS pattern as the rest of the app now: a neutral
//  surface (not a full-bleed colored gradient), one glossy icon
//  tile in that page's accent color, bold title, plain-language
//  subtitle. This is closer to how Apple's own first-run screens
//  read (Health, Fitness, "What's New") than the saturated
//  gradient-hero look, which is what was reading as busy/childish.
//
//  Shown once on first install. Stores 'rider_onboarded' in
//  shared_preferences. Call RiderOnboarding.shouldShow() before
//  routing in splash page.
//
//  pubspec.yaml:
//    shared_preferences: ^2.2.2
//
//  Place at: lib/features/auth/presentation/onboarding_page.dart
// ═══════════════════════════════════════════════════════════════

class RiderOnboarding extends StatefulWidget {
  final VoidCallback onDone;
  const RiderOnboarding({super.key, required this.onDone});

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('rider_onboarded') ?? false);
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rider_onboarded', true);
  }

  @override
  State<RiderOnboarding> createState() => _RiderOnboardingState();
}

class _RiderOnboardingState extends State<RiderOnboarding>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _page = 0;

  late List<AnimationController> _fadeCtrl;
  late List<AnimationController> _slideCtrl;

  static final List<_OnboardData> _pages = [
    _OnboardData(
      icon: Icons.electric_moped_rounded,
      color: AppTheme.iosBlue,
      title: 'Ride & earn',
      subtitle:
      'Accept delivery jobs near you and earn on your own schedule. No boss, no fixed hours.',
      badge: 'Your time, your rules',
    ),
    _OnboardData(
      icon: Icons.inventory_2_outlined,
      color: AppTheme.iosIndigo,
      title: 'Pick up & deliver',
      subtitle:
      'Collect items from sellers, deliver to buyers. Every step is tracked live on the map.',
      badge: 'Real-time tracking',
    ),
    _OnboardData(
      icon: Icons.lock_outline_rounded,
      color: AppTheme.iosGreen,
      title: 'OTP confirms delivery',
      subtitle:
      'The buyer shows you a 4-digit code. Enter it to confirm delivery and release your earnings instantly.',
      badge: 'Secure payments',
    ),
    _OnboardData(
      icon: Icons.account_balance_wallet_outlined,
      color: AppTheme.iosOrange,
      title: 'Instant wallet',
      subtitle:
      'Earnings land in your wallet the moment delivery is confirmed. Withdraw to your bank anytime.',
      badge: 'Paid instantly',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = List.generate(
      _pages.length,
          (_) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 450)),
    );
    _slideCtrl = List.generate(
      _pages.length,
          (_) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 420)),
    );
    _animatePage(0);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in _fadeCtrl) c.dispose();
    for (final c in _slideCtrl) c.dispose();
    super.dispose();
  }

  void _animatePage(int index) {
    _fadeCtrl[index].forward(from: 0);
    _slideCtrl[index].forward(from: 0);
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_page < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _skip() {
    HapticFeedback.lightImpact();
    _finish();
  }

  Future<void> _finish() async {
    await RiderOnboarding.markDone();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.bg(isDark),
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar: page dots + Skip ──────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 20, 0),
                child: Row(
                  children: [
                    Row(
                      children: List.generate(_pages.length, (i) {
                        final active = i == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          margin: const EdgeInsets.only(right: 6),
                          width: active ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active ? _pages[_page].color : AppTheme.gray4,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                    const Spacer(),
                    if (_page < _pages.length - 1)
                      TextButton(
                        onPressed: _skip,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary(isDark),
                        ),
                        child: const Text('Skip',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                  ],
                ),
              ),

              // ── Pages ──────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: (i) {
                    setState(() => _page = i);
                    _animatePage(i);
                  },
                  itemCount: _pages.length,
                  itemBuilder: (_, i) => _OnboardPage(
                    data: _pages[i],
                    fadeAnim: _fadeCtrl[i],
                    slideAnim: _slideCtrl[i],
                    isDark: isDark,
                  ),
                ),
              ),

              // ── Bottom CTA ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pages[_page].color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      _page == _pages.length - 1 ? 'Get started' : 'Continue',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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

// ═══════════════════════════════════════════════════════════════
//  SINGLE PAGE
// ═══════════════════════════════════════════════════════════════

class _OnboardPage extends StatelessWidget {
  final _OnboardData data;
  final AnimationController fadeAnim;
  final AnimationController slideAnim;
  final bool isDark;

  const _OnboardPage({
    required this.data,
    required this.fadeAnim,
    required this.slideAnim,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: fadeAnim, curve: Curves.easeOut);
    final slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: slideAnim, curve: Curves.easeOutCubic));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Badge — plain tinted capsule, no border/blur games
          FadeTransition(
            opacity: fade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: iosTint(data.color, isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Text(
                data.badge.toUpperCase(),
                style: TextStyle(
                  color: data.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Glossy icon tile — the "app icon" moment, not an emoji
          FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: GlossyIconTile(
                color: data.color,
                icon: data.icon,
                size: 108,
                iconSize: 48,
              ),
            ),
          ),

          const SizedBox(height: 40),

          SlideTransition(
            position: slide,
            child: FadeTransition(
              opacity: fade,
              child: Text(
                data.title,
                style: TextStyle(
                  color: AppTheme.textPrimary(isDark),
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          FadeTransition(
            opacity: fade,
            child: Text(
              data.subtitle,
              style: TextStyle(
                color: AppTheme.textSecondary(isDark),
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  DATA MODEL
// ═══════════════════════════════════════════════════════════════

class _OnboardData {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String badge;

  const _OnboardData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.badge,
  });
}
