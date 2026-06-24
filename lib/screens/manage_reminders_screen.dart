import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/lecture_provider.dart';
import '../widgets/loading_widget.dart';

class ManageRemindersScreen extends StatefulWidget {
  const ManageRemindersScreen({Key? key}) : super(key: key);

  @override
  State<ManageRemindersScreen> createState() => _ManageRemindersScreenState();
}

class _ManageRemindersScreenState extends State<ManageRemindersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<LectureProvider>(context, listen: false).getTeacherNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LectureProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Active Reminders', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal.shade600,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await lp.getTeacherNotifications();
        },
        child: lp.isLoading
            ? const LoadingWidget(message: 'Fetching reminders...')
            : lp.notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer_off_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('No active reminders', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: lp.notifications.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final n = lp.notifications[index];
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.shade50,
                            child: const Icon(Icons.timer, color: Colors.orange),
                          ),
                          title: Text(n['title'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n['message'] ?? '', style: GoogleFonts.poppins(fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('Scheduled: ${n['scheduledAt']}', style: GoogleFonts.poppins(fontSize: 10, color: Colors.teal)),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _confirmDelete(context, n['id']),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Reminder'),
          content: const Text('Are you sure you want to stop this reminder timer? Students will not receive the notification.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () async {
                final lp = Provider.of<LectureProvider>(context, listen: false);
                final success = await lp.deleteNotification(id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Reminder cancelled' : 'Failed to cancel'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Yes, Stop'),
            ),
          ],
        );
      },
    );
  }
}
