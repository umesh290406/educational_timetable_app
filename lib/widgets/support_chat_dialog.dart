import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SupportChatDialog extends StatefulWidget {
  const SupportChatDialog({Key? key}) : super(key: key);

  @override
  State<SupportChatDialog> createState() => _SupportChatDialogState();
}

class _SupportChatDialogState extends State<SupportChatDialog> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      'sender': 'bot',
      'text': 'Hello! I am The Helper. How can I help you today?'
    }
  ];
  int _userMessageCount = 0;

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _messageController.clear();
      _userMessageCount++;
    });

    // Simulate bot typing delay
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        if (_userMessageCount == 1) {
          _messages.add({
            'sender': 'bot',
            'text':
                'Currently, I am processing high volumes of requests. Please email your detailed query to 📧 umesh@gmail.com and our team will get back to you shortly.'
          });
        } else if (_userMessageCount == 2) {
          _messages.add({
            'sender': 'bot',
            'text':
                'If this is an urgent issue, please contact our human support team directly via phone at 📞 8356961200.'
          });
        } else {
          _messages.add({
            'sender': 'bot',
            'text':
                'As mentioned, please use the provided Email or Phone number to get in touch with our team.'
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        height: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.support_agent, color: Colors.teal.shade600),
                    const SizedBox(width: 10),
                    Text('The Helper',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const Divider(),
            // Chat Area
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['sender'] == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser
                            ? Colors.teal.shade500
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 0),
                          bottomRight: Radius.circular(isUser ? 0 : 16),
                        ),
                      ),
                      child: Text(
                        msg['text']!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isUser ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Input Area
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your question...',
                      hintStyle: GoogleFonts.poppins(fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.teal.shade400),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.teal.shade600,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
