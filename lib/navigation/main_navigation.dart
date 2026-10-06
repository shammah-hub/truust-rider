import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/services/fcm_service.dart';
import '../core/theme/app_theme.dart';
import '../data/models/delivery_models.dart';
import '../data/repositories/delivery_repository.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/jobs/presentation/jobs_page.dart';
import '../features/active/presentation/active_page.dart';
import '../features/earnings/presentation/earnings_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/rewards/presentation/tier_up_dialog.dart';
import '../features/chat/presentation/fleet_chat_page.dart';

class MainNavigation extends StatefulWidget {
  final String userId;
  final int initialTab;

  const MainNavigation({
    super.key,
    required this.userId,
    this.initialTab = 0,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _currentTab;

  // Tracks the tier we last knew about, so a change while the app
  // is already open triggers the celebration dialog exactly once.
  // Only covers the foreground case — same scope as the app's other
  // foreground-only listeners — the tier-up push notification
  // (already sent by completeDeliveryWithOTP) covers the backgrounded
  // /killed-app case.
  String? _lastKnownTier;
  bool _tierBaselineSet = false;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;

    // Notification taps arrive on RiderFcmService.pendingRoute. Listen for
    // taps while the app is open, and also pick up one that was tapped
    // while the app was closed (it is waiting there with its value set).
    RiderFcmService.pendingRoute.addListener(_onNotificationRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onNotificationRoute());
  }

  @override
  void dispose() {
    RiderFcmService.pendingRoute.removeListener(_onNotificationRoute);
    super.dispose();
  }

  // Tab indexes 0-2 never move: 0 Jobs, 1 Active, 2 Earnings.
  // (The Agency chat tab and Profile come after them.)
  int? _tabForRoute(String route) {
    switch (route) {
      case 'active_delivery':
      case 'active_job':
        return 1;
      case 'job_detail':
      case 'jobs':
        return 0;
      case 'earnings':
      case 'wallet':
        return 2;
      default:
        return null;
    }
  }

  void _onNotificationRoute() {
    final payload = RiderFcmService.pendingRoute.value;
    if (payload == null || !mounted) return;

    // Payload is "route|id". Clear it first so it is only handled once.
    RiderFcmService.pendingRoute.value = null;

    final route = payload.split('|').first;
    final tab = _tabForRoute(route);
    if (tab == null || tab == _currentTab) return;
    setState(() => _currentTab = tab);
  }

  void _handleAgentUpdate(DeliveryAgent? agent, bool isDark) {
    if (agent == null) return;
    final currentTier = agent.tier; // assumes DeliveryAgent exposes `tier`

    if (!_tierBaselineSet) {
      _lastKnownTier = currentTier;
      _tierBaselineSet = true;
      return;
    }

    if (currentTier != _lastKnownTier) {
      _lastKnownTier = currentTier;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showTierUpDialog(context, newTier: currentTier, isDark: isDark);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
          );
        }
      },
      child: StreamBuilder<DeliveryAgent?>(
        stream: context.read<DeliveryRepository>().watchAgent(widget.userId),
        builder: (context, agentSnap) {
          final agent = agentSnap.data;
          _handleAgentUpdate(agent, isDark);
          final isVerified = agent?.isVerified ?? false;

          // Only riders actually linked to an agency get a chat tab —
          // an independent marketplace-only rider has no agencyId and
          // no agency thread to show.
          final hasAgency = agent?.agencyId != null && agent!.agencyId!.isNotEmpty;

          final verifiedPages = [
            JobsPage(userId: widget.userId, isVerified: isVerified),
            ActivePage(userId: widget.userId),
            EarningsPage(userId: widget.userId),
            if (hasAgency)
              FleetChatPage(
                agencyId: agent!.agencyId!,
                riderId: widget.userId,
                agencyName: 'Your Agency',
              ),
            ProfilePage(userId: widget.userId),
          ];

          // If the current tab index is now out of range (e.g. the agency
          // link was just removed while the chat tab was open), fall back
          // to Profile rather than crash on an IndexedStack overrun.
          final safeTab = _currentTab < verifiedPages.length ? _currentTab : verifiedPages.length - 1;

          return Scaffold(
            backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
            extendBody: true, // lets page content show through the frosted bar
            body: SafeArea(
              bottom: false, // bottom inset handled inside the nav bar itself
              child: Column(
                children: [
                  if (!isVerified) _NotVerifiedBanner(isDark: isDark, userId: widget.userId),
                  Expanded(
                    child: IndexedStack(
                      index: safeTab,
                      children: verifiedPages,
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _FrostedNavBar(
              isDark: isDark,
              currentTab: safeTab,
              hasAgency: hasAgency,
              profilePhotoUrl: agent?.profilePhotoUrl,
              agentInitial: agent?.name.isNotEmpty == true
                  ? agent!.name[0].toUpperCase()
                  : '?',
              onTap: _switchTab,
            ),
          );
        },
      ),
    );
  }

  void _switchTab(int index) {
    if (_currentTab == index) return;
    HapticFeedback.selectionClick();
    setState(() => _currentTab = index);
  }
}

class _NotVerifiedBanner extends StatelessWidget {
  final bool isDark;
  final String userId;
  const _NotVerifiedBanner({required this.isDark, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('deliveryAgents').doc(userId).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        // Linked to an agency: the agency vouches for them, so no banner.
        if (data?['agencyId'] != null) return const SizedBox.shrink();

        final message = data?['registeredViaAgency'] == true
            ? 'Waiting for your agency to confirm you. Once they do, you can go online and take their jobs.'
            : 'Not verified yet — our team is reviewing your application. You can browse the app, but can\'t go online or accept jobs until you\'re approved.';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.amber.withOpacity(0.12),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, color: AppTheme.amber, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  FROSTED GLASS NAV BAR
// ─────────────────────────────────────────────────────────────

class _FrostedNavBar extends StatelessWidget {
  final bool isDark;
  final int currentTab;
  final bool hasAgency;
  final String? profilePhotoUrl;
  final String agentInitial;
  final ValueChanged<int> onTap;

  const _FrostedNavBar({
    required this.isDark,
    required this.currentTab,
    required this.hasAgency,
    required this.profilePhotoUrl,
    required this.agentInitial,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Profile always sits last; its index shifts by one when the
    // Agency chat tab is present, same as the page list in MainNavigation.
    final profileIndex = hasAgency ? 4 : 3;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? AppTheme.darkSurface : AppTheme.lightSurface)
                .withOpacity(0.35),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  _NavTab(
                    icon: Icons.work_outline_rounded,
                    activeIcon: Icons.work_rounded,
                    label: 'Jobs',
                    isActive: currentTab == 0,
                    isDark: isDark,
                    onTap: () => onTap(0),
                  ),
                  _NavTab(
                    icon: Icons.delivery_dining_outlined,
                    activeIcon: Icons.delivery_dining_rounded,
                    label: 'Active',
                    isActive: currentTab == 1,
                    isDark: isDark,
                    onTap: () => onTap(1),
                  ),
                  _NavTab(
                    icon: Icons.account_balance_wallet_outlined,
                    activeIcon: Icons.account_balance_wallet_rounded,
                    label: 'Earnings',
                    isActive: currentTab == 2,
                    isDark: isDark,
                    onTap: () => onTap(2),
                  ),
                  if (hasAgency)
                    _NavTab(
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: 'Agency',
                      isActive: currentTab == 3,
                      isDark: isDark,
                      onTap: () => onTap(3),
                    ),
                  _ProfileNavTab(
                    label: 'Profile',
                    isActive: currentTab == profileIndex,
                    isDark: isDark,
                    profilePhotoUrl: profilePhotoUrl,
                    initial: agentInitial,
                    onTap: () => onTap(profileIndex),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor =
    isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 22,
              color: isActive ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                height: 1.0,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileNavTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDark;
  final String? profilePhotoUrl;
  final String initial;
  final VoidCallback onTap;

  const _ProfileNavTab({
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.profilePhotoUrl,
    required this.initial,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor =
    isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? activeColor : Colors.transparent,
                  width: 1.5,
                ),
                image: profilePhotoUrl != null
                    ? DecorationImage(
                  image: NetworkImage(profilePhotoUrl!),
                  fit: BoxFit.cover,
                )
                    : null,
                color: profilePhotoUrl == null
                    ? inactiveColor.withOpacity(0.15)
                    : null,
              ),
              child: profilePhotoUrl == null
                  ? Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                ),
              )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                height: 1.0,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
