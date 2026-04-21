import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lecture_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Load notifications when screen opens
    Future.delayed(Duration.zero, () {
      Provider.of<LectureProvider>(context, listen: false)
          .getStudentNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        title: Text(
          '🔔 Notifications',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<LectureProvider>(
        builder: (context, lectureProvider, _) {
          // Show loading
          if (lectureProvider.isLoading) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          // Show empty state
          if (lectureProvider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'No notifications yet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'You will see notifications here',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            );
          }

          // Show notifications list
          // Show notifications list
          return RefreshIndicator(
            onRefresh: () async {
              await lectureProvider.getStudentNotifications();
            },
            child: ListView.builder(
              itemCount: lectureProvider.notifications.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final notification = lectureProvider.notifications[index];
                final bool isRead = notification['isRead'] == 1 || notification['isRead'] == true;
                final String id = notification['id']?.toString() ?? '';

                return Card(
                  elevation: isRead ? 0 : 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isRead
                            ? Colors.grey.shade300
                            : Colors.teal.shade300,
                        width: isRead ? 0.5 : 2,
                      ),
                    ),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRead
                              ? Colors.grey.shade200
                              : Colors.teal.shade100,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.notifications,
                            color: isRead
                                ? Colors.grey
                                : Colors.teal,
                            size: 28,
                          ),
                        ),
                      ),
                      title: Text(
                        notification['title'] ?? 'Lecture Reminder',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isRead
                              ? Colors.grey.shade600
                              : Colors.black,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            notification['message'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Type: ${notification['notificationType'] ?? 'N/A'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'New',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.teal.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Icon(
                        isRead
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: isRead
                            ? Colors.green
                            : Colors.orange,
                      ),
                      onTap: () {
                        // Mark as read when tapped
                        if (!isRead) {
                          lectureProvider.markNotificationAsRead(id);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
