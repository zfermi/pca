import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService extends ChangeNotifier {
  final bool enabled;
  SupabaseClient? _supabase;
  String? _familyId;
  String? _deviceId;
  String? _fcmToken;
  Timer? _pollTimer;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final List<Map<String, dynamic>> _recentNotifications = [];

  SupabaseClient get _client => _supabase!;
  List<Map<String, dynamic>> get recentNotifications =>
      List.unmodifiable(_recentNotifications);

  NotificationService({this.enabled = true}) {
    if (enabled) {
      _supabase = Supabase.instance.client;
    }
  }

  void configure({required String familyId, required String deviceId}) {
    _familyId = familyId;
    _deviceId = deviceId;
  }

  Future<void> initialize() async {
    if (!enabled) return;

    await _initLocalNotifications();

    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('NotificationService: permission denied');
      return;
    }

    _fcmToken = await messaging.getToken();
    if (_fcmToken != null) {
      await _saveToken(_fcmToken!);
    }

    messaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      _saveToken(token);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);
  }

  Future<void> _saveToken(String token) async {
    if (!enabled || _familyId == null || _deviceId == null) return;
    try {
      await _client.from('fcm_tokens').upsert({
        'device_id': _deviceId,
        'family_id': _familyId,
        'token': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'device_id');
    } catch (e) {
      debugPrint('NotificationService._saveToken error: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'Parental Control';
    final body = message.notification?.body ?? '';
    _showLocalNotification(title, body);
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'parental_control_alerts',
      'Parental Control Alerts',
      channelDescription: 'Notifications about your child\'s activity',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// Start polling for unprocessed notifications (phone side)
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _pollNotifications(),
    );
    _pollNotifications();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollNotifications() async {
    if (!enabled || _familyId == null || _deviceId == null) return;
    try {
      final data = await _client
          .from('notification_queue')
          .select()
          .eq('family_id', _familyId!)
          .neq('source_device_id', _deviceId!)
          .eq('processed', false)
          .order('created_at', ascending: false)
          .limit(10);

      final notifications = List<Map<String, dynamic>>.from(data);
      if (notifications.isEmpty) return;

      for (final notification in notifications) {
        final title = _notificationTitle(notification['type'] as String?);
        final body = notification['details'] as String? ?? '';
        await _showLocalNotification(title, body);

        _recentNotifications.insert(0, notification);
        if (_recentNotifications.length > 50) {
          _recentNotifications.removeLast();
        }
      }

      // Mark as processed
      final ids = notifications.map((n) => n['id'] as String).toList();
      await _client
          .from('notification_queue')
          .update({'processed': true})
          .inFilter('id', ids);

      notifyListeners();
    } catch (e) {
      debugPrint('NotificationService._pollNotifications error: $e');
    }
  }

  String _notificationTitle(String? type) {
    switch (type) {
      case 'session_started':
        return 'Session Started';
      case 'session_ended':
        return 'Session Ended';
      case 'time_limit_reached':
        return 'Time Limit Reached';
      case 'blocked_app':
        return 'Blocked App Alert';
      default:
        return 'Parental Control Alert';
    }
  }

  /// Called from TV side to notify parent phones about events
  Future<void> sendNotification({
    required String type,
    required String childName,
    String? details,
  }) async {
    if (!enabled || _familyId == null || _deviceId == null) return;
    try {
      await _client.from('notification_queue').insert({
        'family_id': _familyId,
        'source_device_id': _deviceId,
        'type': type,
        'child_name': childName,
        'details': details,
      });
    } catch (e) {
      debugPrint('NotificationService.sendNotification error: $e');
    }
  }

  Future<void> notifySessionStarted(String childName) async {
    await sendNotification(
      type: 'session_started',
      childName: childName,
      details: '$childName started a screen time session',
    );
  }

  Future<void> notifySessionEnded(String childName, int minutesUsed) async {
    await sendNotification(
      type: 'session_ended',
      childName: childName,
      details: '$childName\'s session ended after $minutesUsed minutes',
    );
  }

  Future<void> notifyTimeLimitReached(String childName) async {
    await sendNotification(
      type: 'time_limit_reached',
      childName: childName,
      details: '$childName has reached their daily screen time limit',
    );
  }

  Future<void> notifyBlockedAppAttempt(String childName, String appName) async {
    await sendNotification(
      type: 'blocked_app',
      childName: childName,
      details: '$childName tried to open blocked app: $appName',
    );
  }

  Future<List<Map<String, dynamic>>> fetchNotificationHistory({int limit = 20}) async {
    if (!enabled || _familyId == null) return [];
    try {
      final data = await _client
          .from('notification_queue')
          .select()
          .eq('family_id', _familyId!)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  Future<void> removeToken() async {
    if (!enabled || _deviceId == null) return;
    try {
      await _client.from('fcm_tokens').delete().eq('device_id', _deviceId!);
    } catch (e) {
      debugPrint('NotificationService.removeToken error: $e');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
