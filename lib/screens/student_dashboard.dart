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
import '../models/timetable_model.dart';
import '../services/attendance_service.dart';
import '../utils/class_config.dart';
import 'login_screen.dart';
import '../main.dart'; // for global navigatorKey
import '../providers/theme_provider.dart';

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
    });
    
    // Polling for notifications every 10 seconds
    _notificationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
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
                  icon: Icons.calendar_month,
                  iconColor: Colors.purple,
                  title: 'Weekly Timetable',
                  description: 'Tap the top-right Options menu (three dots) and select "Weekly Timetable" to view your class\'s full weekly timetable.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.auto_awesome,
                  iconColor: Colors.amber.shade700,
                  title: 'AI Planner & Tutor',
                  description: 'Tap the sparkle icon in the top app bar to open the Gemini AI Planner. Ask queries or upload study materials for instant summaries.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.smart_toy,
                  iconColor: Colors.teal,
                  title: 'Aagewala Assistant',
                  description: 'Tap the robot icon in the top app bar to chat with Aagewala. Ask "What classes do I have today?" or "Show my profile" to get instant answers.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.assignment_turned_in_outlined,
                  iconColor: Colors.green,
                  title: 'Attendance Tracking',
                  description: 'Go to Options -> "Attendance Tracking" to record and review your subject-wise class attendance.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.sick_outlined,
                  iconColor: Colors.orange,
                  title: 'Apply for Leave',
                  description: 'Need leave? Go to Options -> "Apply for Leave" to submit leave requests directly to your teachers.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.assignment_outlined,
                  iconColor: Colors.red.shade600,
                  title: 'Exam Schedule',
                  description: 'Go to Options -> "Exam Schedule" to view your class\'s exam timetable and download it as a CSV file.',
                ),
                _buildHelpItem(
                  context,
                  icon: Icons.person_outline,
                  iconColor: Colors.indigo,
                  title: 'Edit Profile',
                  description: 'Update your name, roll number, class, or division anytime from the Options -> "Edit Profile" menu.',
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
              'Welcome, ${authProvider.user?.name ?? 'Student'}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${authProvider.user?.className ?? 'N/A'} - ${authProvider.user?.section ?? 'N/A'}',
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
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            tooltip: 'AI Planner',
            onPressed: () {
              Navigator.pushNamed(context, '/ai_planner');
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'how_to_use_student',
        onPressed: () => _showHowToUseDialog(context),
        backgroundColor: Colors.teal.shade600,
        child: const Icon(Icons.help_outline, color: Colors.white),
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

                    final combinedClass = ClassConfig.combineClassAndSpecialization(dialogClass, dialogSpecialization);

                    // Update details in AuthProvider
                    await authProvider.updateUserProfile(
                      name: name,
                      email: email,
                      className: combinedClass,
                      section: dialogSection,
                      specialization: dialogSpecialization,
                    );

                    // Update roll number in AttendanceService
                    await AttendanceService.saveRollNo(email, roll);

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
}
