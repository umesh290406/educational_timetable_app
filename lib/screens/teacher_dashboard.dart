import 'package:flutter/material.dart';
import '../models/timetable_model.dart';
import 'view_timetable_screen.dart';
import 'manage_reminders_screen.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'send_notification_screen.dart';
import 'schedule_reminder_screen.dart';
import 'upload_timetable_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/lecture_provider.dart';
import '../widgets/lecture_card.dart';
import '../widgets/loading_widget.dart';
import '../widgets/support_chat_dialog.dart';
import 'add_lecture_screen.dart';
import '../providers/theme_provider.dart';
import '../services/attendance_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/class_config.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({Key? key}) : super(key: key);

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final lp = Provider.of<LectureProvider>(context, listen: false);
      await lp.getTeacherLectures();
      await lp.getTeacherTimetable();
    });
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
                  'Welcome to your Timetable Portal! Here is how you can manage your schedule and interact with students as a Teacher:',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 16),
                _buildHelpItem(
                  context,
                  icon: Icons.add_to_queue,
                  iconColor: Colors.blue,
                  title: 'Upload Timetable',
                  description: 'Tap the top-right Options menu (three dots) -> "Upload Timetable" to add recurring weekly classes for your schedule.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.add,
                  iconColor: Colors.teal,
                  title: 'Create One-off Lecture',
                  description: 'Tap the "+" button at the bottom-right of your screen to schedule a new, one-off lecture for any class.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.video_camera_front_outlined,
                  iconColor: Colors.redAccent,
                  title: 'Virtual Classrooms',
                  description: 'Tap the "Virtual Classes" card on your dashboard to instantly schedule live meeting links (Zoom/Meet) for specific classes.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.menu_book_outlined,
                  iconColor: Colors.indigo,
                  title: 'Study Materials',
                  description: 'Tap the "Study Materials" card to easily upload PDFs or notes specifically for a class, section, and specialization.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.notifications_active_outlined,
                  iconColor: Colors.amber.shade600,
                  title: 'Targeted Notifications Engine',
                  description: 'You do not need to spam! When you create a class or upload notes, our smart engine ONLY notifies students in that exact class/section.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.chat_bubble_outline,
                  iconColor: Colors.green.shade600,
                  title: 'Direct Messaging',
                  description: 'Tap the Chat Bubble icon at the top right to message students directly! You can also block/unblock disruptive users.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.assignment_turned_in_outlined,
                  iconColor: Colors.green,
                  title: 'Attendance Tracking',
                  description: 'Go to Options -> "Attendance Tracking" to mark attendance for a class or view previous records.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.badge_outlined,
                  iconColor: Colors.purple,
                  title: 'Student Leave Management',
                  description: 'Go to Options -> "Student Leave Management" to review, approve, or reject student leave requests.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.assignment_outlined,
                  iconColor: Colors.red.shade600,
                  title: 'Manage Exams & Online Tests',
                  description: 'Go to Options -> "Manage Exam Schedules" to schedule exam timetables, or create secure Online Tests.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.people_alt_outlined,
                  iconColor: Colors.blueAccent,
                  title: 'Student Roster',
                  description: 'Tap the student group icon in the app bar to view, add, or edit detailed student profiles.',
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
              'Welcome, ${authProvider.user?.username ?? authProvider.user?.name ?? 'Teacher'}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Teacher Dashboard',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined, color: Colors.white),
            tooltip: 'Student Roster',
            onPressed: () {
              Navigator.pushNamed(context, '/teacher-roster');
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            tooltip: 'Messages',
            onPressed: () {
              Navigator.pushNamed(context, '/messages');
            },
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            tooltip: 'Aagewala Chat',
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
                case 'upload':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UploadTimetableScreen(),
                    ),
                  );
                  break;
                case 'reminders':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManageRemindersScreen(),
                    ),
                  );
                  break;
                case 'attendance':
                  Navigator.pushNamed(context, '/attendance');
                  break;
                case 'leave':
                  Navigator.pushNamed(context, '/teacher-leave');
                  break;
                case 'exam':
                  Navigator.pushNamed(context, '/teacher-exam');
                  break;
                case 'tests':
                  Navigator.pushNamed(context, '/teacher-tests');
                  break;
                case 'materials':
                  Navigator.pushNamed(context, '/teacher_materials');
                  break;
                case 'virtual_classes':
                  Navigator.pushNamed(context, '/teacher_virtual_classes');
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
                value: 'upload',
                child: Row(
                  children: [
                    Icon(Icons.add_to_queue, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Upload Timetable',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'reminders',
                child: Row(
                  children: [
                    Icon(Icons.notifications_paused_outlined, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Manage Reminders',
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
                    Icon(Icons.badge_outlined, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Student Leave Management',
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
                      'Manage Exam Schedules',
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
                    Icon(Icons.person, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Profile Settings',
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FloatingActionButton(
                    heroTag: 'support_staff_teacher',
                    onPressed: () => _showSupportDialog(context),
                    backgroundColor: Colors.teal.shade600,
                    child: const Icon(Icons.contact_support, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton(
                    heroTag: 'how_to_use_teacher',
                    onPressed: () => _showHowToUseDialog(context),
                    backgroundColor: Colors.teal.shade600,
                    child: const Icon(Icons.help_outline, color: Colors.white),
                  ),
                ],
              ),
            ),
            FloatingActionButton(
              heroTag: 'add_lecture_teacher',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddLectureScreen(),
                  ),
                );
              },
              backgroundColor: Colors.teal.shade600,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: RefreshIndicator(
        onRefresh: () async {
          final lp = Provider.of<LectureProvider>(context, listen: false);
          await lp.getTeacherLectures();
          await lp.getTeacherTimetable();
        },
        child: lectureProvider.isLoading
            ? const LoadingWidget(message: 'Loading your schedule...')
            : _buildScheduleList(context, lectureProvider),
      ),
    );
  }

  Widget _buildScheduleList(BuildContext context, LectureProvider lp) {
    final now = DateTime.now();
    final currentDay = DateFormat('EEEE').format(now);
    
    // Combined list of one-off lectures and today's timetable entries
    final todaySchedule = <dynamic>[];
    
    // Filter one-off lectures for today
    final todayLectures = lp.lectures.where((l) {
      return l.lectureDate.year == now.year &&
             l.lectureDate.month == now.month &&
             l.lectureDate.day == now.day;
    }).toList();
    
    todaySchedule.addAll(todayLectures);
    
    // Filter recurring timetable entries for today's day name (e.g., 'Monday')
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No schedule for today',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddLectureScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: Text(
                'Create One-off Lecture',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: todaySchedule.length,
      itemBuilder: (context, index) {
        final item = todaySchedule[index];
        final isTimetableEntry = item is Timetable;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
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
                const SizedBox(height: 4),
                Text(
                  '${item.startTime} - ${item.endTime} | Room ${item.roomNumber}',
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      item.teacherName,
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Class: ${item.className} (${item.section})',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isTimetableEntry)
                IconButton(
                  icon: const Icon(Icons.timer_outlined, color: Colors.orange),
                  tooltip: 'Schedule Reminder',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScheduleReminderScreen(
                          lectureId: item.id,
                          lectureName: item.subjectName,
                          startTime: item.startTime,
                          endTime: item.endTime,
                          className: item.className,
                          section: item.section ?? '',
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  tooltip: isTimetableEntry ? 'Remove Weekly Entry' : 'Cancel Lecture',
                  onPressed: () {
                    if (isTimetableEntry) {
                      _showTimetableDeleteDialog(context, item.id);
                    } else {
                      _showCancelDialog(context, item.id);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTimetableDeleteDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Weekly Entry'),
        content: const Text('Are you sure you want to remove this weekly timetable entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          ElevatedButton(
            onPressed: () async {
              await Provider.of<LectureProvider>(context, listen: false).deleteTimetable(id);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Remove'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, String lectureId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final reasonController = TextEditingController();
        return AlertDialog(
          title: const Text('Cancel Lecture'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Are you sure you want to cancel this lecture?'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'Cancellation reason',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () async {
                final lectureProvider =
                    Provider.of<LectureProvider>(context, listen: false);
                await lectureProvider.cancelLecture(
                  lectureId: lectureId,
                  reason: reasonController.text,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lecture cancelled successfully'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthProvider authProvider) async {
    final email = authProvider.user?.email ?? '';
    final currentTeacherId = await AttendanceService.getSavedTeacherId(email) ?? '';

    if (!mounted) return;

    String? dialogCollege = authProvider.user?.college ?? '3257 A.P. Shah Institute of Technology';
    String collegeSearchQuery = '';

    final nameController = TextEditingController(text: authProvider.user?.name ?? '');
    final emailController = TextEditingController(text: email);
    final idController = TextEditingController(text: currentTeacherId);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Email Address (Read-only)',
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: idController,
                      decoration: const InputDecoration(
                        labelText: 'Teacher ID',
                        prefixIcon: Icon(Icons.tag),
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
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    final newTeacherId = idController.text.trim();

                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Name cannot be empty'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (dialogCollege == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('College is required'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    await authProvider.updateTeacherProfile(
                      name: newName,
                      email: email,
                      college: dialogCollege!,
                    );
                    await AttendanceService.saveTeacherId(email, newTeacherId);

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Save Changes',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
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