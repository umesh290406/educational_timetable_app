import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class StudentVirtualClassesScreen extends StatefulWidget {
  const StudentVirtualClassesScreen({Key? key}) : super(key: key);

  @override
  State<StudentVirtualClassesScreen> createState() => _StudentVirtualClassesScreenState();
}

class _StudentVirtualClassesScreenState extends State<StudentVirtualClassesScreen> {
  bool _isLoading = true;
  List<dynamic> _classes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchClasses();
    });
  }

  Future<void> _fetchClasses() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    setState(() => _isLoading = true);
    final data = await ApiService.getStudentVirtualClasses(
      user.className ?? '',
      user.section ?? '',
      specialization: user.specialization,
    );
    
    if (mounted) {
      setState(() {
        _classes = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _joinMeeting(String urlString) async {
    try {
      String formattedUrl = urlString.trim();
      if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
        formattedUrl = 'https://$formattedUrl';
      }
      final Uri url = Uri.parse(formattedUrl);
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open meeting link: $urlString')),
        );
      }
    }
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('EEE, MMM d • h:mm a').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  bool _isLiveNow(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final difference = dt.difference(now).inMinutes;
      // Consider "Live Now" if the meeting starts within 15 minutes or started up to 90 minutes ago
      return difference <= 15 && difference >= -90;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Virtual Classrooms', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.teal))
        : _classes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tv_off, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No upcoming virtual classes.', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                  Text('Check back later!', style: GoogleFonts.poppins(color: Colors.grey.shade500)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchClasses,
              color: Colors.teal,
              child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final cls = _classes[index];
                    final isLive = _isLiveNow(cls['scheduledTime']);

                    return Card(
                      elevation: isLive ? 6 : 2,
                      shadowColor: isLive ? Colors.red.withOpacity(0.4) : null,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isLive ? Colors.red.shade300 : Colors.transparent, width: 2)
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.teal.shade100,
                                      child: const Icon(Icons.school, size: 16, color: Colors.teal),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      cls['teacherName'] ?? 'Teacher',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                                    ),
                                  ],
                                ),
                                if (isLive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8, height: 8,
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 6),
                                        Text('LIVE', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                                      ],
                                    ),
                                  )
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(cls['title'], style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Text(_formatDate(cls['scheduledTime']), style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  Icon(Icons.hourglass_empty, size: 16, color: Colors.amber.shade800),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'You will be placed in a waiting room. The teacher must admit you to join.',
                                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _joinMeeting(cls['meetingLink']),
                                icon: const Icon(Icons.videocam),
                                label: Text(isLive ? 'Join Live Class' : 'Open Meeting Link', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isLive ? Colors.red.shade600 : Colors.teal.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ),
    );
  }
}
