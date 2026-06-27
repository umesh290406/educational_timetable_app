import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
// SplashScreen removed — unused dead code
import 'screens/welcome_screen.dart';
import 'services/reminder_service.dart';
import 'screens/login_screen.dart';
import 'screens/student_dashboard.dart';
import 'screens/teacher_dashboard.dart';
import 'screens/notifications_screen.dart';
import 'screens/schedule_reminder_screen.dart';
import 'screens/upload_timetable_screen.dart';
import 'screens/view_timetable_screen.dart';
import 'screens/aagewala_chat_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/ai_planner_screen.dart';
import 'screens/student_leave_screen.dart';
import 'screens/teacher_leave_screen.dart';
import 'screens/student_exam_screen.dart';
import 'screens/teacher_exam_screen.dart';
import 'screens/teacher_roster_screen.dart';
import 'screens/register_screen.dart';
import 'screens/teacher_online_tests_screen.dart';
import 'screens/student_online_tests_screen.dart';
import 'screens/student_ai_quiz_screen.dart';
import 'screens/teacher_upload_material_screen.dart';
import 'screens/student_materials_screen.dart';
import 'screens/student_internships_screen.dart';
import 'screens/messages_list_screen.dart';
import 'screens/teacher_virtual_classes_screen.dart';
import 'screens/student_virtual_classes_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/lecture_provider.dart';
import 'providers/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!kIsWeb) {
    await Firebase.initializeApp();
    print("Handling a background message: ${message.messageId}");
  }
}

Future<void> _syncFcmToken() async {
  if (kIsWeb) return;
  try {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      if (token != null) {
        ApiService.setToken(token);
        await ApiService.updateFcmToken(fcmToken);
        print("📱 FCM Token synced: $fcmToken");
      }
    }
  } catch (e) {
    print("❌ Error syncing FCM token: $e");
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (Only on supported platforms / if configured)
  try {
    if (kIsWeb) {
      // For Web, if FirebaseOptions are missing, this will fail. We catch it.
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Request FCM permissions on mobile
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Listen for foreground messages and show notification tray popups
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          ReminderService.showNotification(
            id: notification.hashCode,
            title: notification.title ?? 'New Alert',
            body: notification.body ?? '',
          );
        }
      });

      // Listen for notification clicks when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        navigatorKey.currentState?.pushNamed('/notifications');
      });

      // Check if app was opened via notification click from terminated state
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            navigatorKey.currentState?.pushNamed('/notifications');
          });
        }
      });

      // Sync FCM token with database
      _syncFcmToken();
    }
  } catch (e) {
    print("Firebase initialization failed (likely Web without config): $e");
  }

  // Initialize local notifications
  await ReminderService.initializeNotifications();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LectureProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Acadence',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.light,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.teal.shade300,
                primary: Colors.teal.shade400,
                brightness: Brightness.light,
              ),
              textTheme: GoogleFonts.poppinsTextTheme(),
            ),
            home: const WelcomeScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/student': (context) => const StudentDashboard(),
              '/teacher': (context) => const TeacherDashboard(),
              '/notifications': (context) => const NotificationsScreen(),
              '/upload-timetable': (context) => const UploadTimetableScreen(),
              '/aagewala': (context) => const AagewalaChatScreen(),
              '/attendance': (context) => const AttendanceScreen(),
              '/ai_planner': (context) => const AiPlannerScreen(),
              '/student-leave': (context) => const StudentLeaveScreen(),
              '/teacher-leave': (context) => const TeacherLeaveScreen(),
              '/student-exam': (context) => const StudentExamScreen(),
              '/teacher-exam': (context) => const TeacherExamScreen(),
              '/teacher-roster': (context) => const TeacherRosterScreen(),
              '/teacher-tests': (context) => const TeacherOnlineTestsScreen(),
              '/student-tests': (context) => const StudentOnlineTestsScreen(),
              '/student_ai_quiz': (context) => const StudentAiQuizScreen(),
              '/teacher_materials': (context) => const TeacherUploadMaterialScreen(),
              '/student_materials': (context) => const StudentMaterialsScreen(),
              '/student_internships': (context) => const StudentInternshipsScreen(),
              '/messages': (context) => const MessagesListScreen(),
              '/teacher_virtual_classes': (context) => const TeacherVirtualClassesScreen(),
              '/student_virtual_classes': (context) => const StudentVirtualClassesScreen(),
              // These screens require dynamic parameters — navigate via
              // Navigator.push() with constructor args instead of named routes.
            },
          );
        },
      ),
    );
  }
}