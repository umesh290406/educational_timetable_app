import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../main.dart'; // To access navigatorKey

class ReminderService {
  static final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize notifications
  static Future<void> initializeNotifications() async {
    // Local notifications are not supported on Web
    if (kIsWeb) return;

    try {
      // Initialize timezone
      tzdata.initializeTimeZones();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings();

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );

      await notificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            navigatorKey.currentState
                ?.pushNamed('/notifications'); // Go to notifications list
          }
        },
      );

      // Request permission for Android 13+
      await notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      // Notification initialization failed — handled silently
    }
  }

  // Show immediate notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'lecture_reminders_channel',
      'Lecture Reminders',
      channelDescription: 'Reminders for upcoming lectures',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      enableLights: true,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await notificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Schedule notification at specific time
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (kIsWeb) return;

    try {
      // Convert to local timezone
      final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(
        scheduledDate,
        tz.local,
      );

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'lecture_reminders_channel',
        'Lecture Reminders',
        channelDescription: 'Reminders for upcoming lectures',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        enableLights: true,
      );

      const NotificationDetails details =
          NotificationDetails(android: androidDetails);

      await notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );


    } catch (e) {
      // Error scheduling notification — handled silently
    }
  }

  // Cancel specific notification
  static Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    try {
      await notificationsPlugin.cancel(id);

    } catch (e) {
      // Error cancelling notification — handled silently
    }
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    try {
      await notificationsPlugin.cancelAll();

    } catch (e) {
      // Error cancelling notifications — handled silently
    }
  }

  // Sync FCM token
  static Future<void> syncFcmToken() async {
    if (kIsWeb) return;
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('authToken');
        if (token != null) {
          ApiService.setToken(token);
          await ApiService.updateFcmToken(fcmToken);
          print("📱 FCM Token synced successfully via ReminderService: $fcmToken");
        }
      }
    } catch (e) {
      print("❌ Error syncing FCM token in ReminderService: $e");
    }
  }
}