import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
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
      print('❌ Failed to initialize notifications: $e');
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

      print('Notification scheduled for: $scheduledDate');
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  // Cancel specific notification
  static Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    try {
      await notificationsPlugin.cancel(id);
      print('Notification cancelled: $id');
    } catch (e) {
      print('Error cancelling notification: $e');
    }
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    try {
      await notificationsPlugin.cancelAll();
      print('All notifications cancelled');
    } catch (e) {
      print('Error cancelling all notifications: $e');
    }
  }
}