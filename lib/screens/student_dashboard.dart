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
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  color: Colors.white,
                ),
                tooltip: themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
                onPressed: () => themeProvider.toggleTheme(),
              );
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

    final nameController = TextEditingController(text: authProvider.user?.name ?? '');
    final emailController = TextEditingController(text: authProvider.user?.email ?? '');
    final classController = TextEditingController(text: authProvider.user?.className ?? '');
    final divisionController = TextEditingController(text: authProvider.user?.section ?? '');
    final rollController = TextEditingController(text: currentRoll);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: classController,
                        decoration: const InputDecoration(
                          labelText: 'Class (e.g. SE)',
                          prefixIcon: Icon(Icons.school),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: divisionController,
                        decoration: const InputDecoration(
                          labelText: 'Division (e.g. A)',
                          prefixIcon: Icon(Icons.class_),
                        ),
                      ),
                    ),
                  ],
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
                final className = classController.text.trim();
                final division = divisionController.text.trim();
                final roll = rollController.text.trim();

                if (name.isEmpty || email.isEmpty || className.isEmpty || division.isEmpty || roll.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All fields are required!'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                // Update details in AuthProvider
                await authProvider.updateUserProfile(
                  name: name,
                  email: email,
                  className: className,
                  section: division,
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
  }
}
