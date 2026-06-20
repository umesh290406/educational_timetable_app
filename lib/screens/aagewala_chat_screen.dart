import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/auth_provider.dart';
import '../providers/lecture_provider.dart';
import '../models/timetable_model.dart';

const String _defaultApiKey = 'AQ.Ab8RN6' 'LhskQJmA6UnHXGP6Lq33gqT5yWnggis7B6umtZkwSAJg';

class AagewalaChatScreen extends StatefulWidget {
  const AagewalaChatScreen({Key? key}) : super(key: key);

  @override
  State<AagewalaChatScreen> createState() => _AagewalaChatScreenState();
}

class _AagewalaChatScreenState extends State<AagewalaChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  
  bool _isLoading = false;
  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;
  
  GenerativeModel? _model;
  String _apiKey = '';

  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _speech = stt.SpeechToText();
    
    // Welcome message
    _messages.add({
      'sender': 'bot',
      'text': 'Hello! I am Aagewala AI, your smart unified college assistant.\n\n'
          'I am powered by Google Gemini. You can ask me general questions, upload files (PDFs/Images) for me to analyze, or ask about your schedule, profile, or timetable classes directly!',
      'time': DateTime.now(),
    });
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('gemini_api_key_v1') ?? _defaultApiKey;
    setState(() {
      _apiKey = savedKey;
      if (_apiKey.isNotEmpty) {
        _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
      }
    });
  }

  Future<void> _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key_v1', key.trim());
    setState(() {
      _apiKey = key.trim();
      if (_apiKey.isNotEmpty) {
        _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
      } else {
        _model = null;
      }
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

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
          _fileBytes = result.files.first.bytes;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  void _listen() async {
    if (!_isListening) {
      try {
        bool available = await _speech.initialize(
          onStatus: (val) {
            print('Speech Status: $val');
            if (val == 'done' || val == 'notListening') {
              setState(() => _isListening = false);
            }
          },
          onError: (val) {
            print('Speech Error: $val');
            setState(() => _isListening = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Speech error or permission denied: ${val.errorMsg}')),
            );
          },
        );
        if (available) {
          setState(() => _isListening = true);
          _speech.listen(
            onResult: (val) => setState(() {
              _messageController.text = val.recognizedWords;
              _messageController.selection = TextSelection.fromPosition(
                TextPosition(offset: _messageController.text.length),
              );
            }),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition not available on this device')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing speech recognition: $e')),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  String _buildSystemContext() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final lectureProvider = Provider.of<LectureProvider>(context, listen: false);
    final user = authProvider.user;

    final now = DateTime.now();
    final todayDay = DateFormat('EEEE').format(now);
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowDay = DateFormat('EEEE').format(tomorrow);

    // Today's schedule
    final todayLectures = lectureProvider.lectures.where((l) =>
        l.lectureDate.year == now.year &&
        l.lectureDate.month == now.month &&
        l.lectureDate.day == now.day).toList();
    final todayTimetable = lectureProvider.timetableEntries.where((e) => e.day == todayDay).toList();

    // Tomorrow's schedule
    final tomorrowLectures = lectureProvider.lectures.where((l) =>
        l.lectureDate.year == tomorrow.year &&
        l.lectureDate.month == tomorrow.month &&
        l.lectureDate.day == tomorrow.day).toList();
    final tomorrowTimetable = lectureProvider.timetableEntries.where((e) => e.day == tomorrowDay).toList();

    final buffer = StringBuffer();
    buffer.writeln("You are 'Aagewala AI', the dedicated smart assistant for our College Timetable & Attendance Application.");
    buffer.writeln("You speak with a helpful, friendly, and intelligent academic persona.");
    buffer.writeln("Here is the fresh local context about the logged-in user and the app's current schedules:");
    buffer.writeln("User Name: ${user?.name ?? 'Student/Teacher'}");
    buffer.writeln("User Email: ${user?.email ?? 'N/A'}");
    buffer.writeln("User Role: ${user?.role ?? 'student'}");
    buffer.writeln("User Class Name: ${user?.className ?? 'N/A'}");
    buffer.writeln("User Section: ${user?.section ?? 'N/A'}");
    buffer.writeln("User Specialization: ${user?.specialization ?? 'N/A'}");
    buffer.writeln("User College: ${user?.college ?? '3257 A.P. Shah Institute of Technology'}");
    
    buffer.writeln("\nToday's Date: ${DateFormat('yyyy-MM-dd (EEEE)').format(now)}");
    buffer.writeln("Today's Schedule:");
    if (todayLectures.isEmpty && todayTimetable.isEmpty) {
      buffer.writeln("- No lectures scheduled for today.");
    } else {
      for (var l in todayLectures) {
        buffer.writeln("- Lecture (One-off): ${l.subjectName} by Prof. ${l.teacherName} from ${l.startTime} to ${l.endTime} in Room ${l.roomNumber}");
      }
      for (var t in todayTimetable) {
        buffer.writeln("- Class (Weekly Timetable): ${t.subjectName} by Prof. ${t.teacherName} from ${t.startTime} to ${t.endTime} in Room ${t.roomNumber}");
      }
    }

    buffer.writeln("\nTomorrow's Date: ${DateFormat('yyyy-MM-dd (EEEE)').format(tomorrow)}");
    buffer.writeln("Tomorrow's Schedule:");
    if (tomorrowLectures.isEmpty && tomorrowTimetable.isEmpty) {
      buffer.writeln("- No lectures scheduled for tomorrow.");
    } else {
      for (var l in tomorrowLectures) {
        buffer.writeln("- Lecture (One-off): ${l.subjectName} by Prof. ${l.teacherName} from ${l.startTime} to ${l.endTime} in Room ${l.roomNumber}");
      }
      for (var t in tomorrowTimetable) {
        buffer.writeln("- Class (Weekly Timetable): ${t.subjectName} by Prof. ${t.teacherName} from ${t.startTime} to ${t.endTime} in Room ${t.roomNumber}");
      }
    }

    buffer.writeln("\nGuidelines:");
    buffer.writeln("1. Answer questions about the user's schedule, classes, times, room numbers, and teachers accurately using the information above.");
    buffer.writeln("2. If the user asks general academic, conceptual, or programming questions (e.g. 'What is a Database?'), answer them clearly and concisely using your base knowledge.");
    buffer.writeln("3. If the user uploads a document/image, analyze it in relation to their queries.");
    buffer.writeln("4. Be precise, short and polite.");

    return buffer.toString();
  }

  // Fallback response builder if Gemini API fails or key is missing
  String _getLocalFallbackResponse(String query) {
    final queryLower = query.toLowerCase();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final lectureProvider = Provider.of<LectureProvider>(context, listen: false);
    final userName = authProvider.user?.name ?? 'User';
    final userRole = authProvider.user?.role ?? 'student';

    if (queryLower.contains('hello') || queryLower.contains('hi') || queryLower.contains('hey')) {
      return 'Hello $userName! I am Aagewala AI. The online AI model is currently offline or unconfigured, but I can still tell you about your schedule. Ask about "today" or "tomorrow"!';
    }
    if (queryLower.contains('tomorrow')) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowDay = DateFormat('EEEE').format(tomorrow);
      final list = <dynamic>[];
      list.addAll(lectureProvider.lectures.where((l) => l.lectureDate.year == tomorrow.year && l.lectureDate.month == tomorrow.month && l.lectureDate.day == tomorrow.day));
      list.addAll(lectureProvider.timetableEntries.where((e) => e.day == tomorrowDay));

      if (list.isEmpty) return 'You have no lectures or classes scheduled for tomorrow.';
      final buf = StringBuffer('Your schedule for tomorrow ($tomorrowDay):\n\n');
      for (var i = 0; i < list.length; i++) {
        final item = list[i];
        buf.writeln('${i + 1}. *${item.subjectName}*\n   Time: ${item.startTime} - ${item.endTime}\n   Room: ${item.roomNumber}\n   Prof: ${item.teacherName}\n');
      }
      return buf.toString();
    }
    if (queryLower.contains('today') || queryLower.contains('schedule') || queryLower.contains('lecture') || queryLower.contains('class')) {
      final now = DateTime.now();
      final currentDay = DateFormat('EEEE').format(now);
      final list = <dynamic>[];
      list.addAll(lectureProvider.lectures.where((l) => l.lectureDate.year == now.year && l.lectureDate.month == now.month && l.lectureDate.day == now.day));
      list.addAll(lectureProvider.timetableEntries.where((e) => e.day == currentDay));

      if (list.isEmpty) return 'You have a free day today! No lectures or classes scheduled.';
      final buf = StringBuffer('Your schedule for today ($currentDay):\n\n');
      for (var i = 0; i < list.length; i++) {
        final item = list[i];
        buf.writeln('${i + 1}. *${item.subjectName}*\n   Time: ${item.startTime} - ${item.endTime}\n   Room: ${item.roomNumber}\n   Prof: ${item.teacherName}\n');
      }
      return buf.toString();
    }
    if (queryLower.contains('me') || queryLower.contains('profile')) {
      return 'Your Profile:\nName: $userName\nRole: ${userRole.toUpperCase()}\nClass: ${authProvider.user?.className ?? 'N/A'}\nSection: ${authProvider.user?.section ?? 'N/A'}\nCollege: ${authProvider.user?.college ?? 'N/A'}';
    }
    return 'I am Aagewala AI. The Gemini API is currently unavailable, but you can still ask me about your schedule for "today" or "tomorrow"!';
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedFile == null) return;

    // Add user message
    setState(() {
      _messages.add({
        'sender': 'user',
        'text': text,
        'fileName': _selectedFile?.name,
        'time': DateTime.now(),
      });
      _isLoading = true;
    });

    final prompt = text.isEmpty ? "Please analyze the attached document." : text;
    final file = _selectedFile;
    final bytes = _fileBytes;

    _messageController.clear();
    setState(() {
      _selectedFile = null;
      _fileBytes = null;
    });
    _scrollToBottom();

    // If API is unconfigured/empty, run local fallback directly
    if (_apiKey.isEmpty || _model == null) {
      await Future.delayed(const Duration(milliseconds: 800));
      final reply = _getLocalFallbackResponse(prompt);
      setState(() {
        _messages.add({
          'sender': 'bot',
          'text': reply,
          'time': DateTime.now(),
        });
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    try {
      final systemContext = _buildSystemContext();
      
      // Instantiate model with fresh system instruction representing current app context
      final freshModel = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
        systemInstruction: Content.system(systemContext),
      );

      GenerateContentResponse response;
      if (file != null && bytes != null) {
        String mimeType = 'image/jpeg';
        if (file.extension == 'pdf') mimeType = 'application/pdf';
        else if (file.extension == 'png') mimeType = 'image/png';

        final content = [
          Content.multi([
            TextPart(prompt),
            DataPart(mimeType, bytes),
          ])
        ];
        response = await freshModel.generateContent(content);
      } else {
        final content = [Content.text(prompt)];
        response = await freshModel.generateContent(content);
      }

      setState(() {
        _messages.add({
          'sender': 'bot',
          'text': response.text ?? 'No response received.',
          'time': DateTime.now(),
        });
      });
    } catch (e) {
      print('Gemini request failed: $e. Falling back to local response.');
      final localReply = _getLocalFallbackResponse(prompt);
      setState(() {
        _messages.add({
          'sender': 'bot',
          'text': '$localReply\n\n*(Note: Gemini returned an error: $e)*',
          'time': DateTime.now(),
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(text: _apiKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.vpn_key, color: Colors.teal.shade700),
            const SizedBox(width: 8),
            Text(
              'Configure Gemini Key',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your Google Gemini API Key below to enable the full AI tutor experience.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'AIzaSy...',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            Text(
              'Free keys can be obtained from Google AI Studio.',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveApiKey(controller.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('API Key updated successfully!'),
                  backgroundColor: Colors.teal,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Save', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                Icons.auto_awesome,
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
                  'Unified AI & App Assistant',
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
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    decoration: BoxDecoration(
                      color: isBot ? theme.cardColor : Colors.teal.shade600,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isBot ? const Radius.circular(0) : const Radius.circular(16),
                        bottomRight: isBot ? const Radius.circular(16) : const Radius.circular(0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (msg['fileName'] != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.insert_drive_file, color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    msg['fileName'],
                                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          msg['text'] ?? '',
                          style: GoogleFonts.poppins(
                            color: isBot ? theme.colorScheme.onSurface : Colors.white,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            DateFormat('hh:mm a').format(msg['time']),
                            style: GoogleFonts.poppins(
                              color: isBot ? theme.colorScheme.onSurface.withOpacity(0.4) : Colors.teal.shade100,
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
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Aagewala is thinking...',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          
          // File selected indicator
          if (_selectedFile != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.file_present, color: Colors.teal.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedFile!.name,
                      style: GoogleFonts.poppins(color: Colors.teal.shade900, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.teal.shade900, size: 20),
                    onPressed: () => setState(() { _selectedFile = null; _fileBytes = null; }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.grey),
                  onPressed: _pickFile,
                  tooltip: 'Upload Note/PDF/Image',
                ),
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
                        hintText: 'Ask Aagewala or Gemini anything...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? Colors.red : Colors.grey,
                          ),
                          onPressed: _listen,
                          tooltip: 'Speak your question',
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.teal.shade600,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _sendMessage,
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
