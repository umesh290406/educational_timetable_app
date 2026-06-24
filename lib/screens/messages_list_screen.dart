import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({Key? key}) : super(key: key);

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  bool _isLoading = true;
  List<dynamic> _conversations = [];

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getConversations();
    if (mounted) {
      setState(() {
        _conversations = data;
        _isLoading = false;
      });
    }
  }

  void _showSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const UserSearchSheet(),
    ).then((_) => _fetchConversations());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.teal))
        : _conversations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No conversations yet.', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                  Text('Tap the + button to start chatting!', style: GoogleFonts.poppins(color: Colors.grey.shade500)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchConversations,
              color: Colors.teal,
              child: ListView.separated(
                itemCount: _conversations.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = _conversations[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.teal.shade100,
                      foregroundColor: Colors.teal.shade800,
                      child: Text(
                        user['name'].toString().substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    title: Text(user['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${user['role'].toString().toUpperCase()} • @${user['username'] ?? "user"}',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.teal.shade700),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            otherUserId: user['id'],
                            otherUserName: user['name'],
                            otherUserRole: user['role'],
                          ),
                        ),
                      );
                      _fetchConversations();
                    },
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSearchDialog,
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.message),
      ),
    );
  }
}

class UserSearchSheet extends StatefulWidget {
  const UserSearchSheet({Key? key}) : super(key: key);

  @override
  State<UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<UserSearchSheet> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<dynamic> _searchResults = [];

  void _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    final results = await ApiService.searchUsers(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('New Message', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by username, name, or email...',
              hintStyle: GoogleFonts.poppins(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _search,
                color: Colors.teal,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isSearching
              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
              : _searchResults.isEmpty
                ? Center(child: Text('No users found', style: GoogleFonts.poppins(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade50,
                          child: Icon(user['role'] == 'teacher' ? Icons.school : Icons.person, color: Colors.teal),
                        ),
                        title: Text(user['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        subtitle: Text('@${user['username']} • ${user['role']}'),
                        onTap: () {
                          Navigator.pop(context); // close sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                otherUserId: user['id'],
                                otherUserName: user['name'],
                                otherUserRole: user['role'],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
