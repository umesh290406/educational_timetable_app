import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'notifications_screen.dart';
import 'schedule_reminder_screen.dart';
import 'view_timetable_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/lecture_provider.dart';
import '../services/reminder_service.dart';
import '../widgets/lecture_card.dart';
import '../widgets/loading_widget.dart';
import '../widgets/support_chat_dialog.dart';
import '../models/timetable_model.dart';
import '../services/attendance_service.dart';
import '../services/student_roster_service.dart';
import '../utils/class_config.dart';
import 'login_screen.dart';
import '../main.dart'; // for global navigatorKey
import '../providers/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  Timer? _notificationTimer;
  final Set<String> _shownNotificationIds = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final lp = Provider.of<LectureProvider>(context, listen: false);
      
      lp.getStudentNotifications();
      lp.getStudentLectures();
      if (auth.user?.className != null) {
        lp.getTimetable(auth.user!.className!);
      }

      if (auth.user?.email != null) {
        final email = auth.user!.email;
        AttendanceService.getSavedRollNo(email).then((roll) async {
          if (roll != null && roll.isNotEmpty && auth.user?.className != null && auth.user?.section != null) {
            final className = auth.user!.className!;
            final section = auth.user!.section!;
            final name = auth.user!.name;
            await AttendanceService.registerStudent(
              email: email,
              name: name,
              rollNo: roll,
              className: className,
              section: section,
            );
            
            final existingProfiles = await StudentRosterService.getAllStudents();
            final matchIndex = existingProfiles.indexWhere((e) =>
                e.rollNo == roll &&
                e.className.toLowerCase() == className.toLowerCase() &&
                e.section.toLowerCase() == section.toLowerCase());
            
            String address = '';
            String contactNo = '';
            String parentsNo = '';
            String birthday = '';
            if (matchIndex != -1) {
              address = existingProfiles[matchIndex].address;
              contactNo = existingProfiles[matchIndex].contactNo;
              parentsNo = existingProfiles[matchIndex].parentsNo;
              birthday = existingProfiles[matchIndex].birthday;
            }

            await StudentRosterService.saveStudent(
              StudentProfile(
                rollNo: roll,
                name: name,
                className: className,
                section: section,
                address: address,
                contactNo: contactNo,
                parentsNo: parentsNo,
                birthday: birthday,
              ),
            );
          }
        });
      }
    });
    
    // Polling for notifications every 60 seconds (was 10s — too aggressive for battery/bandwidth)
    _notificationTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _checkNewNotifications();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkNewNotifications() async {
    if (!mounted) return;

    final lectureProvider = Provider.of<LectureProvider>(context, listen: false);
    await lectureProvider.getStudentNotifications();

    // Guard again after await — widget may have been disposed
    if (!mounted) return;

    for (final notification in lectureProvider.notifications) {
      final id = notification['id']?.toString() ?? '';
      final isRead = notification['isRead'] == 1 || notification['isRead'] == true;

      if (!isRead && !_shownNotificationIds.contains(id)) {
        // Show local notification (no-op on web)
        await ReminderService.showNotification(
          id: id.hashCode,
          title: notification['title'] ?? 'New Reminder',
          body: notification['message'] ?? 'You have a new lecture reminder.',
          payload: notification['lectureId']?.toString(),
        );

        // Guard after second await
        if (!mounted) return;

        // Use global navigatorKey — safe even if widget is disposed later
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: ListTile(
              leading: const Icon(Icons.notifications_active, color: Colors.white),
              title: Text(
                notification['title'] ?? 'Lecture Reminder',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                notification['message'] ?? '',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            backgroundColor: Colors.teal.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () {
                // Use global navigatorKey — never references disposed widget
                navigatorKey.currentState?.pushNamed('/notifications');
              },
            ),
          ),
        );

        _shownNotificationIds.add(id);
      }
    }
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: theme.cardColor,
          title: Row(
            children: [
              Icon(Icons.contact_support_outlined, color: Colors.teal.shade600, size: 28),
              const SizedBox(width: 10),
              Text(
                'Help Center',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Need assistance? You can reach out to our help center using our automated support bot.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 20),
              // Chatbot Support Card
              Card(
                elevation: 0,
                color: Colors.teal.shade50.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.teal.shade100),
                ),
                child: ListTile(
                  leading: Icon(Icons.support_agent, color: Colors.teal.shade700),
                  title: Text(
                    'The Helper',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Ask our automated bot',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => const SupportChatDialog(),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showHowToUseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: theme.cardColor,
          title: Row(
            children: [
              Icon(Icons.help_outline, color: Colors.teal.shade600, size: 28),
              const SizedBox(width: 10),
              Text(
                'How to Use the App',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  'Welcome to your Timetable Portal! Here is how you can make the most of this app as a Student:',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 16),
                _buildHelpItem(
                  context,
                  icon: Icons.calendar_today,
                  iconColor: Colors.blue,
                  title: 'Today\'s Schedule',
                  description: 'Your homepage lists today\'s active lectures, combining both recurring weekly timetable entries and one-off extra classes scheduled by your teachers.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.auto_awesome,
                  iconColor: Colors.teal,
                  title: 'Aagewala Voice AI Assistant',
                  description: 'Tap the Magic Wand icon! Ask about your schedule, conceptual questions, or use the microphone to talk directly to Aagewala AI!',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.quiz_outlined,
                  iconColor: Colors.deepPurple,
                  title: 'AI Practice Quizzes',
                  description: 'Go to Options -> "AI Practice Quiz". Type any topic and our AI will generate a 5-question multiple-choice quiz for you instantly.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.notifications_active_outlined,
                  iconColor: Colors.amber.shade600,
                  title: 'Targeted Notifications',
                  description: 'You will automatically receive notifications ONLY when a teacher uploads notes or schedules a class that strictly matches your Class, Section, and Specialization.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.video_camera_front_outlined,
                  iconColor: Colors.redAccent,
                  title: 'Virtual Classrooms',
                  description: 'Tap the "Virtual Classes" card on your dashboard to securely access live meeting links (Zoom/Meet) posted by your teachers.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.menu_book_outlined,
                  iconColor: Colors.indigo,
                  title: 'Study Materials',
                  description: 'Tap "Study Materials" on your dashboard to download PDFs and notes specifically uploaded for your class.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.chat_bubble_outline,
                  iconColor: Colors.green.shade600,
                  title: 'Direct Messaging',
                  description: 'Tap the Chat Bubble icon at the top right to message your teachers for doubts, or chat with classmates! You can also block users if needed.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.assignment_turned_in_outlined,
                  iconColor: Colors.green,
                  title: 'Attendance & Leave',
                  description: 'Use the Options menu to track your attendance or apply for leaves directly to your teacher.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.assignment_outlined,
                  iconColor: Colors.red.shade600,
                  title: 'Online Tests & Exams',
                  description: 'Use the Options menu to view scheduled exams and take secure Online Tests posted by your faculty.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Got it!',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelpItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final lectureProvider = Provider.of<LectureProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade600,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${authProvider.user?.username ?? authProvider.user?.name ?? 'Student'}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${authProvider.user?.className ?? 'N/A'} - ${authProvider.user?.section ?? 'N/A'}${authProvider.user?.college != null ? ' | ${authProvider.user!.college}' : ''}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white70,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            tooltip: 'Messages',
            onPressed: () {
              Navigator.pushNamed(context, '/messages');
            },
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            tooltip: 'Aagewala AI Assistant',
            onPressed: () {
              Navigator.pushNamed(context, '/aagewala');
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'Options',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) async {
              switch (value) {
                case 'timetable':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ViewTimetableScreen(
                        className: authProvider.user?.className ?? 'SE',
                        section: authProvider.user?.section ?? 'A',
                      ),
                    ),
                  );
                  break;
                case 'notifications':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                  break;
                case 'attendance':
                  Navigator.pushNamed(context, '/attendance');
                  break;
                case 'leave':
                  Navigator.pushNamed(context, '/student-leave');
                  break;
                case 'exam':
                  Navigator.pushNamed(context, '/student-exam');
                  break;
                case 'tests':
                  Navigator.pushNamed(context, '/student-tests');
                  break;
                case 'ai_quiz':
                  Navigator.pushNamed(context, '/student_ai_quiz');
                  break;
                case 'materials':
                  Navigator.pushNamed(context, '/student_materials');
                  break;
                case 'internships':
                  Navigator.pushNamed(context, '/student_internships');
                  break;
                case 'virtual_classes':
                  Navigator.pushNamed(context, '/student_virtual_classes');
                  break;
                case 'profile':
                  _showEditProfileDialog(context, authProvider);
                  break;
                case 'logout':
                  await authProvider.logout();
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'timetable',
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Weekly Timetable',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'notifications',
                child: Row(
                  children: [
                    Icon(Icons.notifications, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Notifications',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'attendance',
                child: Row(
                  children: [
                    Icon(Icons.assignment_turned_in_outlined, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Attendance Tracking',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.sick_outlined, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Apply for Leave',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'exam',
                child: Row(
                  children: [
                    Icon(Icons.assignment_outlined, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Exam Schedule',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'tests',
                child: Row(
                  children: [
                    Icon(Icons.quiz_outlined, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Online Tests',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'ai_quiz',
                child: Row(
                  children: [
                    Icon(Icons.psychology_outlined, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'AI Practice Quiz',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'materials',
                child: Row(
                  children: [
                    Icon(Icons.library_books_outlined, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Study Materials',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'internships',
                child: Row(
                  children: [
                    Icon(Icons.workspace_premium_outlined, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Career & Internships',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'virtual_classes',
                child: Row(
                  children: [
                    Icon(Icons.videocam_outlined, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Virtual Classrooms',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Edit Profile',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FloatingActionButton(
            heroTag: 'support_staff_student',
            onPressed: () => _showSupportDialog(context),
            backgroundColor: Colors.teal.shade600,
            child: const Icon(Icons.contact_support, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'how_to_use_student',
            onPressed: () => _showHowToUseDialog(context),
            backgroundColor: Colors.teal.shade600,
            child: const Icon(Icons.help_outline, color: Colors.white),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: RefreshIndicator(
        onRefresh: () async {
          final lp = Provider.of<LectureProvider>(context, listen: false);
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await lp.getStudentLectures();
          if (auth.user?.className != null) {
            await lp.getTimetable(auth.user!.className!);
          }
          await lp.getStudentNotifications();
        },
        child: lectureProvider.isLoading
            ? const LoadingWidget(message: 'Loading your schedule...')
            : _buildTodaySchedule(context, lectureProvider),
      ),
    );
  }

  Widget _buildTodaySchedule(BuildContext context, LectureProvider lp) {
    final now = DateTime.now();
    final currentDay = DateFormat('EEEE', 'en_US').format(now);
    
    final todaySchedule = <dynamic>[];
    
    // Filter one-off lectures
    final todayLectures = lp.lectures.where((l) {
      return l.lectureDate.year == now.year &&
             l.lectureDate.month == now.month &&
             l.lectureDate.day == now.day;
    }).toList();
    todaySchedule.addAll(todayLectures);
    
    // Filter recurring timetable entries
    todaySchedule.addAll(lp.timetableEntries.where((e) => e.day == currentDay));

    // Sort chronologically (8, 9, 10, 11, 12, 1, 2...)
    todaySchedule.sort((a, b) {
      int parseTime(String t) {
        try {
          t = t.trim();
          try {
            final d = DateFormat('h:mm a').parse(t);
            return d.hour * 60 + d.minute;
          } catch (_) {}
          try {
            final d = DateFormat('H:mm').parse(t);
            return d.hour * 60 + d.minute;
          } catch (_) {}
          
          final clean = t.replaceAll(RegExp(r'[^0-9:]'), '').trim();
          final parts = clean.split(':');
          if (parts.isEmpty || parts[0].isEmpty) return 0;
          int h = int.parse(parts[0]);
          int m = parts.length > 1 ? int.parse(parts[1]) : 0;
          if (h >= 1 && h <= 7 && !t.toLowerCase().contains('am')) h += 12;
          return h * 60 + m;
        } catch (_) {
          return 0;
        }
      }
      return parseTime(a.startTime).compareTo(parseTime(b.startTime));
    });

    if (todaySchedule.isEmpty) {
      final unreadNotifications = lp.notifications.where((n) {
        return n['isRead'] == 0 || n['isRead'] == false;
      }).toList();

      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          if (unreadNotifications.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.teal.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pending Reminders (${unreadNotifications.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ],
              ),
            ),
            ...unreadNotifications.take(3).map((n) => _buildNotificationSnippet(context, n)).toList(),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/notifications'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('View All Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const Divider(height: 40, indent: 20, endIndent: 20),
          ],
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No classes scheduled for today',
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  unreadNotifications.isEmpty ? 'Enjoy your free time!' : 'Check your reminders above.',
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: todaySchedule.length,
      itemBuilder: (context, index) {
        final item = todaySchedule[index];
        final isTimetableEntry = item is Timetable;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: isTimetableEntry ? Colors.purple.shade50 : Colors.teal.shade50,
              child: Icon(
                isTimetableEntry ? Icons.repeat : Icons.event,
                color: isTimetableEntry ? Colors.purple : Colors.teal,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.subjectName,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isTimetableEntry ? Colors.purple.shade100 : Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isTimetableEntry ? 'Weekly' : 'One-off',
                    style: TextStyle(
                      fontSize: 10,
                      color: isTimetableEntry ? Colors.purple.shade700 : Colors.teal.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${item.startTime} - ${item.endTime}',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.room, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Room ${item.roomNumber}',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationSnippet(BuildContext context, Map<String, dynamic> n) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.teal.shade50,
      elevation: 0,
      child: ListTile(
        onTap: () => Navigator.pushNamed(context, '/notifications'),
        leading: Icon(Icons.info_outline, color: Colors.teal.shade700),
        title: Text(
          n['title'] ?? 'Lecture Reminder',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          n['message'] ?? '',
          style: GoogleFonts.poppins(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.chevron_right, size: 16, color: Colors.teal.shade300),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthProvider authProvider) async {
    final email = authProvider.user?.email ?? '';
    final currentRoll = await AttendanceService.getSavedRollNo(email) ?? '';
    
    if (!mounted) return;

    final initialClassData = ClassConfig.parseClassAndSpecialization(authProvider.user?.className);
    String dialogClass = initialClassData['class'] ?? '11th';
    String dialogSpecialization = initialClassData['specialization'] ?? 'Commerce';
    String dialogSection = authProvider.user?.section ?? 'A';
    String? dialogCollege = authProvider.user?.college ?? '3257 A.P. Shah Institute of Technology';
    String collegeSearchQuery = '';

    final nameController = TextEditingController(text: authProvider.user?.name ?? '');
    final emailController = TextEditingController(text: authProvider.user?.email ?? '');
    final rollController = TextEditingController(text: currentRoll);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final specializations = ClassConfig.getSpecializationsForClass(dialogClass);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.person_outline, color: Colors.teal.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Edit Profile',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rollController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Roll Number',
                        prefixIcon: Icon(Icons.tag),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Class Selection dropdown
                    Text(
                      'Class Name',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: dialogClass,
                          isExpanded: true,
                          items: ClassConfig.classes.map((cls) {
                            return DropdownMenuItem(
                              value: cls,
                              child: Text(cls, style: GoogleFonts.poppins(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                dialogClass = val;
                                final newSpecs = ClassConfig.getSpecializationsForClass(val);
                                dialogSpecialization = newSpecs.isNotEmpty ? newSpecs[0] : '';
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (specializations.isNotEmpty) ...[
                      Text(
                        'Specialization / Branch',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: dialogSpecialization,
                            isExpanded: true,
                            items: specializations.map((spec) {
                              return DropdownMenuItem(
                                value: spec,
                                child: Text(spec, style: GoogleFonts.poppins(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  dialogSpecialization = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Text(
                      'Division (Section)',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: dialogSection,
                          isExpanded: true,
                          items: ClassConfig.sections.map((sec) {
                            return DropdownMenuItem(
                              value: sec,
                              child: Text('Section $sec', style: GoogleFonts.poppins(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                dialogSection = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // College selection
                    Text(
                      'College',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        // Open college bottom sheet selector
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) {
                            return DraggableScrollableSheet(
                              initialChildSize: 0.85,
                              minChildSize: 0.5,
                              maxChildSize: 0.95,
                              builder: (context, scrollController) {
                                return StatefulBuilder(
                                  builder: (context, setModalState) {
                                    final list = ClassConfig.colleges.entries.toList();
                                    final filtered = collegeSearchQuery.isEmpty
                                        ? list
                                        : list.where((entry) => '${entry.key} ${entry.value}'.toLowerCase().contains(collegeSearchQuery.toLowerCase())).toList();
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: theme.scaffoldBackgroundColor,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                      ),
                                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 5,
                                            margin: const EdgeInsets.only(bottom: 16),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[400],
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          Text(
                                            'Select College',
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            onChanged: (val) {
                                              setModalState(() {
                                                collegeSearchQuery = val;
                                              });
                                            },
                                            style: GoogleFonts.poppins(fontSize: 14),
                                            decoration: InputDecoration(
                                              hintText: 'Search college...',
                                              prefixIcon: const Icon(Icons.search, color: Colors.teal),
                                              filled: true,
                                              fillColor: Colors.grey.withOpacity(0.1),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                borderSide: BorderSide.none,
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Expanded(
                                            child: ListView.builder(
                                              controller: scrollController,
                                              itemCount: filtered.length,
                                              itemBuilder: (context, index) {
                                                final collegeEntry = filtered[index];
                                                final collegeText = '${collegeEntry.key} ${collegeEntry.value}';
                                                final isSelected = dialogCollege == collegeText;
                                                return Container(
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? Colors.teal.withOpacity(0.08) : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: isSelected ? Colors.teal : Colors.grey.withOpacity(0.2),
                                                    ),
                                                  ),
                                                  child: ListTile(
                                                    title: Text(
                                                      collegeText,
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 14,
                                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                        color: isSelected ? Colors.teal.shade700 : null,
                                                      ),
                                                    ),
                                                    trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.teal) : null,
                                                    onTap: () {
                                                      setDialogState(() {
                                                        dialogCollege = collegeText;
                                                      });
                                                      Navigator.pop(context);
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                );
                              },
                            );
                          },
                        ).then((_) {
                          collegeSearchQuery = '';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                dialogCollege ?? 'Tap to select your college',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: dialogCollege == null ? Colors.grey.shade600 : theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // Close Edit Profile Dialog
                          _confirmDeleteAccount(context, authProvider);
                        },
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: Text(
                          'Delete Account',
                          style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final email = emailController.text.trim();
                    final roll = rollController.text.trim();

                    if (name.isEmpty || email.isEmpty || roll.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All fields are required!'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    if (dialogCollege == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('College is required!'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    final combinedClass = ClassConfig.combineClassAndSpecialization(dialogClass, dialogSpecialization);

                    // Update details in AuthProvider
                    await authProvider.updateUserProfile(
                      name: name,
                      email: email,
                      className: combinedClass,
                      section: dialogSection,
                      specialization: dialogSpecialization,
                      college: dialogCollege!,
                    );

                    // Update roll number in AttendanceService and register globally
                    await AttendanceService.saveRollNo(
                      email,
                      roll,
                      name: name,
                      className: combinedClass,
                      section: dialogSection,
                    );

                    // Save/Sync detailed student roster
                    final existingProfiles = await StudentRosterService.getAllStudents();
                    final matchIndex = existingProfiles.indexWhere((e) =>
                        e.rollNo == roll &&
                        e.className.toLowerCase() == combinedClass.toLowerCase() &&
                        e.section.toLowerCase() == dialogSection.toLowerCase());
                    
                    String address = '';
                    String contactNo = '';
                    String parentsNo = '';
                    String birthday = '';
                    if (matchIndex != -1) {
                      address = existingProfiles[matchIndex].address;
                      contactNo = existingProfiles[matchIndex].contactNo;
                      parentsNo = existingProfiles[matchIndex].parentsNo;
                      birthday = existingProfiles[matchIndex].birthday;
                    }

                    await StudentRosterService.saveStudent(
                      StudentProfile(
                        rollNo: roll,
                        name: name,
                        className: combinedClass,
                        section: dialogSection,
                        address: address,
                        contactNo: contactNo,
                        parentsNo: parentsNo,
                        birthday: birthday,
                      ),
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Profile updated successfully!',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          ),
                          backgroundColor: Colors.green.shade600,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                  ),
                  child: Text(
                    'Save Changes',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteAccount(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Account?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: Text(
            'Are you sure you want to delete your account? It will be deactivated and permanently deleted in 30 days.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmDeleteAccountSecondTime(context, authProvider);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteAccountSecondTime(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Confirm Account Deletion',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red.shade900),
          ),
          content: Text(
              'WARNING: Are you absolutely sure you want to delete your account?\n\n'
              'Your account will be deactivated immediately and permanently deleted after 30 days. You can recover it by logging back in within this 30-day period.',
              style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final success = await authProvider.deleteAccount();
                if (success) {
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account deleted successfully.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to delete account.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
              child: Text('Yes, Delete', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
