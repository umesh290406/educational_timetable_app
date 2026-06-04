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
import 'add_lecture_screen.dart';
import '../providers/theme_provider.dart';

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
                  icon: Icons.add,
                  iconColor: Colors.teal,
                  title: 'Create One-off Lecture',
                  description: 'Tap the "+" button at the bottom-right of your screen to schedule a new, one-off lecture for any class.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.add_to_queue,
                  iconColor: Colors.blue,
                  title: 'Upload Timetable',
                  description: 'Tap the top-right Options menu (three dots) -> "Upload Timetable" to add recurring weekly classes for your schedule.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.timer_outlined,
                  iconColor: Colors.orange,
                  title: 'Schedule Reminders',
                  description: 'Tap the clock icon next to any of your scheduled one-off lectures to set notifications for students beforehand.',
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
                  title: 'Manage Exam Schedules',
                  description: 'Go to Options -> "Manage Exam Schedules" to schedule exam timetables, assign subjects, set venues, and track student exam attendance.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.smart_toy,
                  iconColor: Colors.indigo,
                  title: 'Aagewala Assistant',
                  description: 'Tap the robot icon in the top app bar to query Aagewala AI about your schedule or profile details.',
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
              'Welcome, ${authProvider.user?.name ?? 'Teacher'}',
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
            icon: const Icon(Icons.smart_toy, color: Colors.white),
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
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: FloatingActionButton(
                heroTag: 'how_to_use_teacher',
                onPressed: () => _showHowToUseDialog(context),
                backgroundColor: Colors.teal.shade600,
                child: const Icon(Icons.help_outline, color: Colors.white),
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

  void _showNotifyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Send Notification'),
          content: const Text(
            'Send a reminder notification to all students in this class?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notification sent to students'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }
}