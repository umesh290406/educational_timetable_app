import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
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
import 'providers/auth_provider.dart';
import 'providers/lecture_provider.dart';
import 'providers/theme_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notifications
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
            title: 'Educational Timetable',
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
              '/view-timetable': (context) => const ViewTimetableScreen(
                    className: 'SE',
                    section: 'A',
                  ),
              '/schedule-reminder': (context) => const ScheduleReminderScreen(
                    lectureId: '',
                    lectureName: '',
                    startTime: '',
                    endTime: '',
                    className: '',
                    section: '',
                  ),
            },
          );
        },
      ),
    );
  }
}