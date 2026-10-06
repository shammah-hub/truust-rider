import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:truust_rider/features/auth/presentation/pending_verification_page.dart';

import '../../../core/theme/app_theme.dart';
import '../../../navigation/main_navigation.dart';
import '../bloc/auth_bloc.dart';
import 'agent_setup_page.dart';
import 'login_page.dart';

/// Startup router. There is no splash UI in Flutter any more.
///
/// The native splash (the one logo) stays on screen, held by
/// FlutterNativeSplash.preserve() in main.dart, while this page checks who
/// is signed in. As soon as the right screen is ready it is shown with no
/// transition and the native splash is removed. So the rider sees one logo,
/// then straight into the dashboard, never a blank screen or a second logo.
///
/// The class keeps the name SplashPage so main.dart and anything else that
/// navigates here doesn't need to change.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // Check auth right after the first frame (no artificial delay).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthBloc>().add(CheckAuthEvent());
    });
  }

  // Verified riders are the common case, so use the locally cached doc when
  // it already says "verified" and the dashboard opens instantly. In every
  // other case (not found, not verified yet) ask the server, so a rider who
  // was just approved never gets stuck on the pending screen.
  Future<DocumentSnapshot<Map<String, dynamic>>> _loadAgent(
      String userId) async {
    final ref =
    FirebaseFirestore.instance.collection('deliveryAgents').doc(userId);
    try {
      final cached = await ref.get(const GetOptions(source: Source.cache));
      if (cached.exists && cached.data()?['isVerified'] == true) return cached;
    } catch (_) {}
    return ref.get();
  }

  // Show the next screen instantly (no slide) and take the native splash
  // down once that screen has drawn its first frame.
  void _goTo(Widget next) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => next,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    WidgetsBinding.instance
        .addPostFrameCallback((_) => FlutterNativeSplash.remove());
  }

  Future<void> _routeAuthenticated(String userId) async {
    try {
      final doc = await _loadAgent(userId);
      if (!mounted) return;

      if (!doc.exists) {
        // Never registered as agent -> setup
        _goTo(AgentSetupPage(userId: userId));
      } else if (doc.data()?['isVerified'] == true) {
        // Registered and verified -> dashboard
        _goTo(MainNavigation(userId: userId));
      } else {
        // Registered but not yet verified -> pending screen
        _goTo(PendingVerificationPage(userId: userId));
      }
    } catch (_) {
      _goTo(const LoginPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            _routeAuthenticated(state.user.uid);
          } else if (state is AuthUnauthenticated) {
            _goTo(const LoginPage());
          }
        },
        // Nothing drawn here on purpose: the native splash is covering it.
        child: const SizedBox.expand(),
      ),
    );
  }
}
