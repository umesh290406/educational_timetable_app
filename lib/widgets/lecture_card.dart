import 'package:flutter/material.dart';
import '../models/lecture_model.dart';
import '../screens/send_notification_screen.dart';

class LectureCard extends StatelessWidget {
  final Lecture lecture;
  final VoidCallback onCancel;
  final VoidCallback onNotify;
  final VoidCallback? onRemind;

  const LectureCard({
    Key? key,
    required this.lecture,
    required this.onCancel,
    required this.onNotify,
    this.onRemind,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// Lecture Title
            Text(
              lecture.subjectName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            /// Teacher & Class Name
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  lecture.teacherName,
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.school, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  "Class: ${lecture.className}",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// Buttons Row
            Row(
              children: [

                /// Cancel Button
                ElevatedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel),
                  label: const Text("Cancel"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),

                const SizedBox(width: 8),

                /// Notify Button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SendNotificationScreen(
                          lectureId: lecture.id,
                          lectureName: lecture.subjectName,
                          className: lecture.className,
                          section: lecture.section ?? 'A',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications),
                  label: const Text('Notify'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                
                if (onRemind != null) const SizedBox(width: 8),

                if (onRemind != null)
                  ElevatedButton.icon(
                    onPressed: onRemind,
                    icon: const Icon(Icons.schedule),
                    label: const Text('Remind'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}