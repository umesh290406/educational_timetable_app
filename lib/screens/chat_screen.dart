import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String otherUserRole;

  const ChatScreen({
    Key? key,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserRole,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollingTimer;

  bool _isLoading = true;
  List<dynamic> _messages = [];
  bool _isBlocked = false;
  bool _blockedByMe = false;

  @override
  void initState() {
    super.initState();
    _fetchChatHistory();
    // Start short-polling every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchChatHistory(isSilent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchChatHistory({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoading = true);
    final data = await ApiService.getChatHistory(widget.otherUserId);
    if (mounted) {
      setState(() {
        if (data['success'] == true) {
          final newMessages = data['messages'] ?? [];
          // Scroll to bottom if we have new messages
          if (newMessages.length > _messages.length && !isSilent) {
            _scrollToBottom();
          }
          _messages = newMessages;
          _isBlocked = data['isBlocked'] ?? false;
          _blockedByMe = data['blockedByMe'] ?? false;
        }
        if (!isSilent) _isLoading = false;
      });
    }
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isBlocked) return;

    _messageController.clear();
    
    // Optimistic UI update
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.id;
    setState(() {
      _messages.add({
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'senderId': currentUserId,
        'receiverId': widget.otherUserId,
        'content': text,
        'createdAt': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();

    final response = await ApiService.sendMessage(widget.otherUserId, text);
    if (response['success'] != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: ${response['message']}')));
      _fetchChatHistory(isSilent: true); // Revert optimistic update if fail
    }
  }

  Future<void> _toggleBlockStatus() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_blockedByMe ? 'Unblock User?' : 'Block User?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          _blockedByMe 
            ? 'You will be able to send and receive messages from ${widget.otherUserName} again.'
            : 'You will no longer receive messages from ${widget.otherUserName}. They will not be explicitly notified that you blocked them.',
          style: GoogleFonts.poppins()
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(_blockedByMe ? 'Unblock' : 'Block', style: TextStyle(color: _blockedByMe ? Colors.teal : Colors.red)),
          ),
        ],
      )
    );

    if (confirm != true) return;

    final response = _blockedByMe 
      ? await ApiService.unblockUser(widget.otherUserId)
      : await ApiService.blockUser(widget.otherUserId);

    if (response['success'] == true) {
      _fetchChatHistory();
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${response['message']}')));
    }
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthProvider>(context).user?.id;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Icon(widget.otherUserRole == 'teacher' ? Icons.school : Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherUserName, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(widget.otherUserRole.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') {
                _toggleBlockStatus();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(_blockedByMe ? Icons.check_circle_outline : Icons.block, color: _blockedByMe ? Colors.green : Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(_blockedByMe ? 'Unblock User' : 'Block User', style: GoogleFonts.poppins()),
                  ],
                ),
              )
            ],
          )
        ],
      ),
      body: Column(
        children: [
          if (_isBlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.red.shade100,
              child: Text(
                _blockedByMe ? 'You blocked this user.' : 'You cannot reply to this conversation.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.red.shade900, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
              : _messages.isEmpty
                ? Center(child: Text('Say hi to ${widget.otherUserName}! 👋', style: GoogleFonts.poppins(color: Colors.grey)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['senderId'] == currentUserId;
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.teal.shade500 : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMe ? 16 : 0),
                              bottomRight: Radius.circular(isMe ? 0 : 16),
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                            ]
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                msg['content'],
                                style: GoogleFonts.poppins(color: isMe ? Colors.white : Colors.black87, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(msg['createdAt']),
                                style: TextStyle(color: isMe ? Colors.teal.shade100 : Colors.grey.shade500, fontSize: 10),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          if (!_isBlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.grey.shade300, offset: const Offset(0, -1), blurRadius: 4)]
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: GoogleFonts.poppins(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.teal.shade600,
                      radius: 24,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
                        onPressed: _sendMessage,
                      ),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
