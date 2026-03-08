import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/jobs/presentation/jobs_page.dart';
import '../features/active/presentation/active_page.dart';
import '../features/earnings/presentation/earnings_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/auth/presentation/login_page.dart';

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

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pages = [
      JobsPage(userId: widget.userId),
      ActivePage(userId: widget.userId),
      EarningsPage(userId: widget.userId),
      ProfilePage(userId: widget.userId),
    ];

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
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        body: IndexedStack(
          index: _currentTab,
          children: pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.06),
              ),
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  _NavTab(
                    icon: Icons.work_outline_rounded,
                    activeIcon: Icons.work_rounded,
                    label: 'Jobs',
                    isActive: _currentTab == 0,
                    isDark: isDark,
                    onTap: () => _switchTab(0),
                  ),
                  _NavTab(
                    icon: Icons.delivery_dining_outlined,
                    activeIcon: Icons.delivery_dining_rounded,
                    label: 'Active',
                    isActive: _currentTab == 1,
                    isDark: isDark,
                    onTap: () => _switchTab(1),
                  ),
                  _NavTab(
                    icon: Icons.account_balance_wallet_outlined,
                    activeIcon: Icons.account_balance_wallet_rounded,
                    label: 'Earnings',
                    isActive: _currentTab == 2,
                    isDark: isDark,
                    onTap: () => _switchTab(2),
                  ),
                  _NavTab(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Profile',
                    isActive: _currentTab == 3,
                    isDark: isDark,
                    onTap: () => _switchTab(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _switchTab(int index) {
    if (_currentTab == index) return;
    HapticFeedback.selectionClick();
    setState(() => _currentTab = index);
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 44 : 0,
              height: isActive ? 32 : 0,
              decoration: isActive
                  ? BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              )
                  : null,
              child: Icon(
                isActive ? activeIcon : icon,
                size: 20,
                color: isActive
                    ? Colors.white
                    : (isDark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.lightTextTertiary),
              ),
            ),
            if (!isActive) ...[
              Icon(
                icon,
                size: 20,
                color: isDark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.lightTextTertiary,
              ),
            ],
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? AppTheme.blue
                    : (isDark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.lightTextTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
