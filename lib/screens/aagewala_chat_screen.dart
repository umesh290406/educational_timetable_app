import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/lecture_provider.dart';
import '../models/timetable_model.dart';

class AagewalaChatScreen extends StatefulWidget {
  const AagewalaChatScreen({Key? key}) : super(key: key);

  @override
  State<AagewalaChatScreen> createState() => _AagewalaChatScreenState();
}

class _AagewalaChatScreenState extends State<AagewalaChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Welcome message
    _messages.add({
      'sender': 'bot',
      'text': 'Hello! I am Aagewala AI. I am here to assist you with your schedule, reminders, and profile information. How can I help you today?',
      'time': DateTime.now(),
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'sender': 'user',
        'text': text,
        'time': DateTime.now(),
      });
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    // Simulate Bot response after a short delay
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      
      final reply = _getBotResponse(text);
      
      setState(() {
        _isTyping = false;
        _messages.add({
          'sender': 'bot',
          'text': reply,
          'time': DateTime.now(),
        });
      });
      _scrollToBottom();
    });
  }

  String _getBotResponse(String query) {
    query = query.toLowerCase();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final lectureProvider = Provider.of<LectureProvider>(context, listen: false);
    final userName = authProvider.user?.name ?? 'User';
    final userRole = authProvider.user?.role ?? 'student';

    // 1. General Greetings
    if (query.contains('hello') || query.contains('hi') || query.contains('hey') || query.contains('morning') || query.contains('evening')) {
      return 'Hello $userName! I am Aagewala, your AI assistant. How can I assist you with your schedule or academic queries today?';
    }

    // 2. Tomorrow's Schedule
    if (query.contains('tomorrow')) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowDay = DateFormat('EEEE').format(tomorrow);
      
      final tomorrowSchedule = <dynamic>[];
      final tomorrowLectures = lectureProvider.lectures.where((l) {
        return l.lectureDate.year == tomorrow.year &&
               l.lectureDate.month == tomorrow.month &&
               l.lectureDate.day == tomorrow.day;
      }).toList();
      tomorrowSchedule.addAll(tomorrowLectures);
      tomorrowSchedule.addAll(lectureProvider.timetableEntries.where((e) => e.day == tomorrowDay));

      if (tomorrowSchedule.isEmpty) {
        return 'You have no lectures or classes scheduled for tomorrow. Enjoy your free time!';
      }

      final buffer = StringBuffer('Here is your schedule for tomorrow ($tomorrowDay):\n\n');
      for (var i = 0; i < tomorrowSchedule.length; i++) {
        final item = tomorrowSchedule[i];
        final type = item is Timetable ? 'Weekly' : 'One-off';
        buffer.writeln('${i + 1}. *${item.subjectName}* ($type)\n'
            '   ⏰ ${item.startTime} - ${item.endTime}\n'
            '   🚪 Room ${item.roomNumber}\n'
            '   👨‍🏫 Prof. ${item.teacherName}\n');
      }
      return buffer.toString();
    }

    // 3. Today's Lectures / Schedule
    if (query.contains('today') || query.contains('schedule') || query.contains('lecture') || query.contains('class') || query.contains('timetable')) {
      final now = DateTime.now();
      final currentDay = DateFormat('EEEE').format(now);
      
      final todaySchedule = <dynamic>[];
      final todayLectures = lectureProvider.lectures.where((l) {
        return l.lectureDate.year == now.year &&
               l.lectureDate.month == now.month &&
               l.lectureDate.day == now.day;
      }).toList();
      todaySchedule.addAll(todayLectures);
      todaySchedule.addAll(lectureProvider.timetableEntries.where((e) => e.day == currentDay));

      if (todaySchedule.isEmpty) {
        return 'You have a free day today! No lectures or classes scheduled.';
      }

      final buffer = StringBuffer('Here is your schedule for today ($currentDay):\n\n');
      for (var i = 0; i < todaySchedule.length; i++) {
        final item = todaySchedule[i];
        final type = item is Timetable ? 'Weekly' : 'One-off';
        buffer.writeln('${i + 1}. *${item.subjectName}* ($type)\n'
            '   ⏰ ${item.startTime} - ${item.endTime}\n'
            '   🚪 Room ${item.roomNumber}\n'
            '   👨‍🏫 Prof. ${item.teacherName}\n');
      }
      return buffer.toString();
    }

    // 4. How to use Reminders
    if (query.contains('reminder') || query.contains('notification') || query.contains('alarm')) {
      if (userRole == 'teacher') {
        return 'To manage reminders, go to your Dashboard and click on the "clock" icon next to any of your one-off lectures. You can also view and manage existing reminders by tapping the Options menu (three dots) -> "Manage Reminders".';
      } else {
        return 'You will receive automatic push notifications for any new lectures scheduled by your teachers. You can also view all notifications by clicking the Options menu (three dots) -> "Notifications".';
      }
    }

    // 5. How to add Timetable / upload
    if (query.contains('upload') || query.contains('add timetable') || query.contains('create timetable') || query.contains('add lecture')) {
      if (userRole == 'teacher') {
        return 'As a teacher, you have full control over the schedule. To add recurring classes, tap the Options menu in your dashboard and select "Upload Timetable". To add a one-off lecture, click the floating action button (+) on the dashboard.';
      } else {
        return 'Timetables are strictly managed by the teaching staff. If you notice any discrepancies, please reach out to your respective subject teacher or class coordinator.';
      }
    }

    // 6. Profile Info
    if (query.contains('me') || query.contains('my profile') || query.contains('who am i') || query.contains('details')) {
      return 'Your Profile Information:\n'
          'Name: $userName\n'
          'Role: ${userRole.toUpperCase()}\n'
          'Class: ${authProvider.user?.className ?? 'N/A'}\n'
          'Section: ${authProvider.user?.section ?? 'N/A'}\n'
          'Email: ${authProvider.user?.email ?? 'N/A'}';
    }

    // 7. Help / Support
    if (query.contains('help') || query.contains('support') || query.contains('issue')) {
      return 'If you are facing technical issues, please make sure your app is updated to the latest version. For schedule-related queries, please contact your administrative department.';
    }

    // 8. Fallback
    return 'I am Aagewala AI. I can assist you with your daily schedule, profile information, and system functionalities. Feel free to ask about your timetable for today or tomorrow!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 2,
        shadowColor: Colors.teal.shade50,
        backgroundColor: Colors.teal.shade600,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aagewala Assistant',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Always active & smart',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isBot = msg['sender'] == 'bot';
                
                return Align(
                  alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isBot ? Theme.of(context).cardColor : Colors.teal.shade500,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isBot ? const Radius.circular(0) : const Radius.circular(16),
                        bottomRight: isBot ? const Radius.circular(16) : const Radius.circular(0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['text'],
                          style: GoogleFonts.poppins(
                            color: isBot ? Theme.of(context).colorScheme.onSurface : Colors.white,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            DateFormat('hh:mm a').format(msg['time']),
                            style: GoogleFonts.poppins(
                              color: isBot ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5) : Colors.teal.shade100,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.smart_toy, size: 16, color: Colors.teal.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Aagewala is typing...',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          // Input field
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type your question...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        border: InputBorder.none,
                      ),
                      onSubmitted: _handleSendMessage,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.teal.shade600,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: () => _handleSendMessage(_messageController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
