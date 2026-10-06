import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'core/services/fcm_service.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/delivery_repository.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/presentation/splash_page.dart';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the native splash on screen until SplashPage has chosen the first
  // real screen and calls FlutterNativeSplash.remove().
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_bgHandler);

  // Not awaited: the app can draw its first frame while these finish.
  // Awaiting them keeps the native splash on screen for no reason.
  FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const TruustDeliveryApp());

  // Safety net: never leave a rider stuck on the splash if something
  // goes wrong during startup.
  Future.delayed(const Duration(seconds: 8), FlutterNativeSplash.remove);

  // Notification setup runs once the first screen is visible. The
  // navigator exists by then, so a tapped notification can still route.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    RiderFcmService.init(_navigatorKey);
  });
}

class TruustDeliveryApp extends StatelessWidget {
  const TruustDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(create: (_) => AuthRepositoryImpl()),
        RepositoryProvider<DeliveryRepository>(create: (_) => DeliveryRepositoryImpl()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => AuthBloc(repository: context.read<AuthRepository>())),
          BlocProvider(create: (_) => ThemeCubit()),
        ],
        child: _AuthListener(
          child: _AppLifecycleWrapper(
            child: BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, themeMode) {
                return MaterialApp(
                  title: 'Truust Delivery',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeMode,
                  navigatorKey: _navigatorKey,
                  home: const SplashPage(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthListener extends StatefulWidget {
  final Widget child;
  const _AuthListener({required this.child});
  @override
  State<_AuthListener> createState() => _AuthListenerState();
}

class _AuthListenerState extends State<_AuthListener> {
  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        RiderFcmService.saveToken();
      } else {
        RiderFcmService.clearToken();
      }
    });
  }
  @override
  Widget build(BuildContext context) => widget.child;
}

// Only reacts to the app process actually being killed (detached) —
// a safety net so a terminated app doesn't leave a rider falsely
// marked "online" forever. Resuming/pausing/going inactive (camera,
// a phone call, briefly switching apps) never touches availability —
// that would silently override a rider's own deliberate toggle choice,
// which is exactly what was happening before (e.g. taking a delivery
// photo opened the camera, backgrounding the app, which force-marked
// them offline, then force-marked them online again on return).
class _AppLifecycleWrapper extends StatefulWidget {
  final Widget child;
  const _AppLifecycleWrapper({required this.child});
  @override
  State<_AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<_AppLifecycleWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      context.read<AuthBloc>().add(SetAvailabilityEvent(false));
    }
  }
  @override
  Widget build(BuildContext context) => widget.child;
}
