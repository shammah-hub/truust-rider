import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ═══════════════════════════════════════════════════════════════
//  FCM SERVICE — TRUUST RIDER APP
//
//  Saves the token to deliveryAgents/{uid}.
//
//  1. main.dart calls RiderFcmService.init(navigatorKey) AFTER runApp
//     (it is no longer awaited, so it can't hold up the first screen).
//  2. Call RiderFcmService.saveToken() after rider signs in, and again
//     right after registration finishes.
//  3. When a notification is tapped, the route is published on
//     RiderFcmService.pendingRoute. MainNavigation listens to it and
//     switches tab (see the note at the bottom of this file).
//
//  Place at: lib/core/services/fcm_service.dart  (rider app)
// ═══════════════════════════════════════════════════════════════

class RiderFcmService {
  RiderFcmService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _db        = FirebaseFirestore.instance;

  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'truust_rider_high_importance';
  static const _channelName = 'Truust Rider Notifications';

  /// Latest notification route the rider tapped, as "route|id"
  /// (for example "active_delivery|abc123"). It keeps its value until
  /// something clears it, so a screen that mounts after a cold-start
  /// tap can still read it.
  static final ValueNotifier<String?> pendingRoute = ValueNotifier<String?>(null);

  static bool _initialised = false;

  // ── Init ────────────────────────────────────────────────────
  // Order matters: register the listeners first, and ask for the
  // permission last. The permission prompt waits for the rider to tap,
  // and nothing should be stuck behind that.
  //
  // The background handler is registered once, in main.dart. It used
  // to be registered a second time here, which replaced the one in main.
  static Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialised) return;
    _initialised = true;

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS:     DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) _handleRoute(details.payload!);
      },
    );
    await _createNotificationChannel();

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_routeFromMessage);
    _messaging.onTokenRefresh.listen(_updateToken);

    // App opened from a tap while it was fully closed.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _routeFromMessage(initial);

    // Last: may show a system dialog and wait for the rider to answer.
    await _messaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );
  }

  // ── Save token to deliveryAgents collection ──────────────────
  static Future<void> saveToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final docRef = _db.collection('deliveryAgents').doc(uid);
      final doc = await docRef.get();
      if (!doc.exists) return; // not registered yet; call saveToken() again after registering

      final token = await _messaging.getToken();
      if (token == null) return;

      await docRef.update({'fcmToken': token});
    } catch (e) {
      debugPrint('Rider FCM saveToken error: $e');
    }
  }

  // ── Clear token on logout ────────────────────────────────────
  // Call this BEFORE signing out. After sign-out there is no current
  // user, so there is no uid to clear the token for.
  static Future<void> clearToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('deliveryAgents').doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (_) {}
  }

  // update(), not set(merge): this must never create a half-empty
  // deliveryAgents doc for someone who hasn't registered.
  static Future<void> _updateToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('deliveryAgents').doc(uid).update({'fcmToken': token});
    } catch (_) {}
  }

  static Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
      playSound:  true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority:   Priority.high,
          showWhen:   true,
          icon:       '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _encodePayload(message.data),
    );
  }

  static void _routeFromMessage(RemoteMessage message) {
    _handleRoute(_encodePayload(message.data));
  }

  static String _encodePayload(Map<String, dynamic> data) {
    final route = data['route'] as String? ?? '';
    final id    = data['jobId']  as String?
        ?? data['orderId'] as String?
        ?? '';
    return '$route|$id';
  }

  // The app has no named routes, so the old Navigator.pushNamed calls
  // ('/earnings', '/active-job', ...) had nothing to open, and the
  // backend's route names ("active_delivery", "job_detail") weren't
  // handled at all. Now the tap is published for MainNavigation to act on.
  static void _handleRoute(String payload) {
    if (payload.startsWith('|') || payload.isEmpty) return; // no route in the message
    // Re-assigning the same text wouldn't notify listeners, so clear first.
    pendingRoute.value = null;
    pendingRoute.value = payload;
  }
}

// ───────────────────────────────────────────────────────────────
//  Routes the backend sends (functions/modules/delivery.js):
//    active_delivery   -> Active tab   (bid accepted, escrow locked, fleet order assigned)
//    job_detail        -> Jobs tab     (new job, bid countered)
//    jobs              -> Jobs tab     (bid not selected)
//    earnings          -> Earnings tab (payment received, tier up)
//
//  In MainNavigation, listen to RiderFcmService.pendingRoute, switch to
//  the matching tab, then set pendingRoute.value = null. Send me
//  main_navigation.dart and I'll wire that part.
// ───────────────────────────────────────────────────────────────
