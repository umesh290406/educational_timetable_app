import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/lecture_provider.dart';

// ─── Institute-specific dropdown data ───────────────────────────────────────
const List<String> kSubjects = [
  'CT',
  'DBMS',
  'OS',
  'MDM (MCMP)',
  'OE (FINTECH)',
  'Mini Project',
  'DT',
  'BMD',
  'Session',
];

const List<String> kProfessors = [
  'Prof. Hardiki mam',
  'Prof. Harsha mam',
  'Prof. Avani mam',
  'Prof. Veena mam',
  'Prof. Swati mam',
  'Prof. Shubhangi mam',
  'Prof. Ashwini mam',
  'Prof. Kiran sir',
  'Prof. Richa mam',
  'Prof. Deepali mam',
  'HOD. Dr. Pravin sir',
];

const List<String> kClasses = ['SE'];

const List<String> kSections = ['A', 'B'];

const List<String> kRooms = [
  '201',
  '207',
  '208A',
  '208B',
  '209',
  '210',
  '211',
  '212',
  '218L',
  '219L',
  '220L',
];
// ────────────────────────────────────────────────────────────────────────────

class AddLectureScreen extends StatefulWidget {
  const AddLectureScreen({Key? key}) : super(key: key);

  @override
  State<AddLectureScreen> createState() => _AddLectureScreenState();
}

class _AddLectureScreenState extends State<AddLectureScreen> {
  // Dropdown selections
  String? _selectedSubject;
  String? _selectedProfessor;
  String? _selectedClass;
  String? _selectedSection;
  String? _selectedRoom;
  String _selectedReminder = 'None';

  // Time
  String _startTime = '';
  String _endTime = '';

  final List<String> _reminderOptions = [
    'None',
    'Send Now',
    '10 min before',
    '30 min before',
    '1 hour before',
  ];

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        final formatted = picked.format(context);
        if (isStart) {
          _startTime = formatted;
        } else {
          _endTime = formatted;
        }
      });
    }
  }

  void _createLecture(BuildContext context) async {
    // Validation
    if (_selectedSubject == null ||
        _selectedProfessor == null ||
        _selectedClass == null ||
        _startTime.isEmpty ||
        _endTime.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Time logic check
    try {
      final DateFormat format = DateFormat('h:mm a');
      final DateTime start = format.parse(_startTime);
      final DateTime end = format.parse(_endTime);
      if (end.isBefore(start)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End Time cannot be before Start Time'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('Time parsing warning: $e');
    }

    final lp = Provider.of<LectureProvider>(context, listen: false);

    final response = await lp.createLecture(
      subjectName: _selectedSubject!,
      teacherName: _selectedProfessor!,
      className: _selectedClass!,
      section: _selectedSection ?? '',
      startTime: _startTime,
      endTime: _endTime,
      roomNumber: _selectedRoom ?? '',
    );

    if (response['success'] == true) {
      bool notificationSuccess = true;

      if (_selectedReminder != 'None') {
        try {
          final lectureId = response['lectureId'];
          final now = DateTime.now();
          DateTime? reminderTime;

          final DateFormat format = DateFormat('h:mm a');
          final DateTime pickedTime = format.parse(_startTime);
          final lectureTime = DateTime(
              now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);

          if (_selectedReminder == '10 min before') {
            reminderTime = lectureTime.subtract(const Duration(minutes: 10));
          } else if (_selectedReminder == '30 min before') {
            reminderTime = lectureTime.subtract(const Duration(minutes: 30));
          } else if (_selectedReminder == '1 hour before') {
            reminderTime = lectureTime.subtract(const Duration(hours: 1));
          } else {
            reminderTime = now.add(const Duration(seconds: 2));
          }

          final scheduled = await lp.scheduleNotificationForClass(
            lectureId: lectureId.toString(),
            title: 'Upcoming Lecture: $_selectedSubject',
            message:
                'Lecture starts at $_startTime in Room ${_selectedRoom ?? ''}',
            notificationType: 'reminder',
            className: _selectedClass!,
            section: _selectedSection ?? '',
            scheduledDate: reminderTime.toUtc(),
          );

          notificationSuccess = scheduled;
        } catch (e) {
          debugPrint('Notification error: $e');
          notificationSuccess = false;
        }
      }

      if (mounted) {
        if (!notificationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Lecture created, but reminder scheduling failed. Check connection.'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lecture created successfully! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                lp.error ?? 'Failed to create lecture. Check server connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Reusable dropdown builder ──────────────────────────────────────────────
  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required void Function(T?) onChanged,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            prefixIcon: Icon(icon, color: Colors.teal.shade600, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          hint: Text(
            'Select ${label.replaceAll(' *', '')}',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
          ),
          items: items.map((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                item.toString(),
                style: GoogleFonts.poppins(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ── Time picker tile ───────────────────────────────────────────────────────
  Widget _buildTimePicker(String label, String time, bool isStart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectTime(isStart),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time,
                    color: Colors.teal.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  time.isEmpty ? 'Select time' : time,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: time.isEmpty ? Colors.grey : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade600,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Add New Lecture',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Subject ──────────────────────────────────────────────────
              _buildDropdown<String>(
                label: 'Subject Name',
                icon: Icons.subject,
                value: _selectedSubject,
                items: kSubjects,
                required: true,
                onChanged: (v) => setState(() => _selectedSubject = v),
              ),
              const SizedBox(height: 20),

              // ── Professor ─────────────────────────────────────────────────
              _buildDropdown<String>(
                label: 'Professor Name',
                icon: Icons.person,
                value: _selectedProfessor,
                items: kProfessors,
                required: true,
                onChanged: (v) => setState(() => _selectedProfessor = v),
              ),
              const SizedBox(height: 20),

              // ── Class ─────────────────────────────────────────────────────
              _buildDropdown<String>(
                label: 'Class',
                icon: Icons.class_,
                value: _selectedClass,
                items: kClasses,
                required: true,
                onChanged: (v) => setState(() => _selectedClass = v),
              ),
              const SizedBox(height: 20),

              // ── Section ───────────────────────────────────────────────────
              _buildDropdown<String>(
                label: 'Section',
                icon: Icons.apps,
                value: _selectedSection,
                items: kSections,
                onChanged: (v) => setState(() => _selectedSection = v),
              ),
              const SizedBox(height: 20),

              // ── Start / End Time ──────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                      child:
                          _buildTimePicker('Start Time *', _startTime, true)),
                  const SizedBox(width: 16),
                  Expanded(
                      child:
                          _buildTimePicker('End Time *', _endTime, false)),
                ],
              ),
              const SizedBox(height: 20),

              // ── Room ──────────────────────────────────────────────────────
              _buildDropdown<String>(
                label: 'Room Number',
                icon: Icons.meeting_room,
                value: _selectedRoom,
                items: kRooms,
                onChanged: (v) => setState(() => _selectedRoom = v),
              ),
              const SizedBox(height: 20),

              // ── Notification Reminder ─────────────────────────────────────
              Text(
                'Notification Reminder',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedReminder,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.teal.shade400, width: 2),
                  ),
                  prefixIcon: Icon(Icons.notifications_active,
                      color: Colors.teal.shade600),
                ),
                items: _reminderOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child:
                        Text(value, style: GoogleFonts.poppins(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() => _selectedReminder = newValue!);
                },
              ),
              const SizedBox(height: 30),

              // ── Submit Button ─────────────────────────────────────────────
              Consumer<LectureProvider>(
                builder: (context, lp, _) {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          lp.isLoading ? null : () => _createLecture(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey.shade400,
                      ),
                      child: lp.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Create Lecture',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
