import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import '../services/api_service.dart';

class TeacherVirtualClassesScreen extends StatefulWidget {
  const TeacherVirtualClassesScreen({Key? key}) : super(key: key);

  @override
  State<TeacherVirtualClassesScreen> createState() => _TeacherVirtualClassesScreenState();
}

class _TeacherVirtualClassesScreenState extends State<TeacherVirtualClassesScreen> {
  bool _isLoading = true;
  List<dynamic> _classes = [];

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getTeacherVirtualClasses();
    if (mounted) {
      setState(() {
        _classes = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteClass(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Class?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to cancel and delete this virtual class?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      )
    );

    if (confirm != true) return;

    final response = await ApiService.deleteVirtualClass(id);
    if (response['success'] == true) {
      _fetchClasses();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class cancelled')));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${response['message']}')));
    }
  }

  Future<void> _openMeeting(String urlString) async {
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

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const CreateVirtualClassSheet(),
    ).then((value) {
      if (value == true) _fetchClasses();
    });
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('EEE, MMM d • h:mm a').format(dt);
    } catch (_) {
      return isoString;
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
                  Icon(Icons.video_call_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No virtual classes scheduled.', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                  Text('Tap + to create a live class!', style: GoogleFonts.poppins(color: Colors.grey.shade500)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _classes.length,
              itemBuilder: (context, index) {
                final cls = _classes[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                'Class ${cls['className']} ${cls['section'] ?? ''}',
                                style: GoogleFonts.poppins(color: Colors.teal.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteClass(cls['id']),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(cls['title'], style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (cls['specialization'] != null && cls['specialization'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(cls['specialization'], style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                          ),
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
                              Icon(Icons.security, size: 16, color: Colors.amber.shade800),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'As the host, click "Security Options" in the meeting to enable Lobby Mode and admit students manually.',
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
                            onPressed: () => _openMeeting(cls['meetingLink']),
                            icon: const Icon(Icons.videocam),
                            label: Text('Start Meeting as Host', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade600,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Create Class', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class CreateVirtualClassSheet extends StatefulWidget {
  const CreateVirtualClassSheet({Key? key}) : super(key: key);

  @override
  State<CreateVirtualClassSheet> createState() => _CreateVirtualClassSheetState();
}

class _CreateVirtualClassSheetState extends State<CreateVirtualClassSheet> {
  final _titleController = TextEditingController();
  final _classNameController = TextEditingController();
  final _sectionController = TextEditingController();
  final _specializationController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal.shade600,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedTime,
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDate = pickedDate;
          _selectedTime = pickedTime;
        });
      }
    }
  }

  Future<void> _createClass() async {
    if (_titleController.text.trim().isEmpty || _classNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and Class are required')));
      return;
    }

    setState(() => _isLoading = true);

    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Auto-Generate secure random Jitsi Link
    final randomString = List.generate(10, (_) => 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'[math.Random().nextInt(62)]).join();
    final uniqueId = '${DateTime.now().millisecondsSinceEpoch}_$randomString';
    final safeClassName = _classNameController.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final meetingLink = 'https://meet.jit.si/Acadence_${safeClassName}_$uniqueId';

    final data = {
      'title': _titleController.text.trim(),
      'className': _classNameController.text.trim(),
      'section': _sectionController.text.trim(),
      'specialization': _specializationController.text.trim(),
      'meetingLink': meetingLink,
      'scheduledTime': scheduledDateTime.toIso8601String(),
    };

    final response = await ApiService.createVirtualClass(data);
    setState(() => _isLoading = false);

    if (response['success'] == true) {
      if (mounted) Navigator.pop(context, true);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${response['message']}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Schedule Virtual Class', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Topic / Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _classNameController,
                        decoration: const InputDecoration(labelText: 'Class (e.g. 11th)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _sectionController,
                        decoration: const InputDecoration(labelText: 'Section (Optional)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _specializationController,
                  decoration: const InputDecoration(labelText: 'Specialization (Optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                Text('Schedule Time', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectDateTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: Colors.teal.shade600),
                        const SizedBox(width: 12),
                        Text(
                          '${DateFormat('MMM d, yyyy').format(_selectedDate)} at ${_selectedTime.format(context)}',
                          style: GoogleFonts.poppins(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.teal.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'We will auto-generate a secure, random meeting link. As the host, enable "Lobby Mode" in the meeting to approve students manually and block outsiders.',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.teal.shade900),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createClass,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : Text('Create Class & Generate Link', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
