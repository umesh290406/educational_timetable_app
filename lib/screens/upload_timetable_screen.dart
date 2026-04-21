import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lecture_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_lecture_screen.dart'; // reuse dropdown constants

class UploadTimetableScreen extends StatefulWidget {
  const UploadTimetableScreen({Key? key}) : super(key: key);

  @override
  State<UploadTimetableScreen> createState() => _UploadTimetableScreenState();
}

class _UploadTimetableScreenState extends State<UploadTimetableScreen> {
  // Dropdowns
  String? _selectedSubject;
  String? _selectedProfessor;
  String? _selectedClass;
  String? _selectedSection;
  String? _selectedRoom;
  String _selectedDay = 'Monday';

  // Time
  String _startTime = '';
  String _endTime = '';

  bool _isUploading = false;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
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

  void _uploadTimetable() async {
    if (_selectedSubject == null ||
        _selectedProfessor == null ||
        _selectedClass == null ||
        _selectedSection == null ||
        _selectedRoom == null ||
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

    setState(() => _isUploading = true);

    final lectureProvider =
        Provider.of<LectureProvider>(context, listen: false);

    final success = await lectureProvider.createTimetable(
      subjectName: _selectedSubject!,
      teacherName: _selectedProfessor!,
      className: _selectedClass!,
      section: _selectedSection!,
      day: _selectedDay,
      startTime: _startTime,
      endTime: _endTime,
      roomNumber: _selectedRoom!,
    );

    setState(() => _isUploading = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Timetable entry added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Reset form for next entry
        setState(() {
          _selectedSubject = null;
          _selectedProfessor = null;
          _selectedClass = null;
          _selectedSection = null;
          _selectedRoom = null;
          _selectedDay = 'Monday';
          _startTime = '';
          _endTime = '';
        });
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pop(context);
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                lectureProvider.error ?? 'Failed to add timetable entry'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Reusable styled dropdown ───────────────────────────────────────────────
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
            fillColor: Colors.grey[50],
            prefixIcon:
                Icon(icon, color: Colors.teal.shade600, size: 20),
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
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 14),
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
          '$label *',
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time,
                    color: Colors.teal.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  time.isEmpty ? 'Tap to pick time' : time,
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
        backgroundColor: Colors.teal.shade600,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Upload Timetable',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Weekly Lecture',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'This entry repeats every week on the selected day.',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 24),

              // ── Subject ────────────────────────────────────────────────
              _buildDropdown<String>(
                label: 'Subject Name',
                icon: Icons.subject,
                value: _selectedSubject,
                items: kSubjects,
                required: true,
                onChanged: (v) => setState(() => _selectedSubject = v),
              ),
              const SizedBox(height: 18),

              // ── Professor ──────────────────────────────────────────────
              _buildDropdown<String>(
                label: 'Professor Name',
                icon: Icons.person,
                value: _selectedProfessor,
                items: kProfessors,
                required: true,
                onChanged: (v) => setState(() => _selectedProfessor = v),
              ),
              const SizedBox(height: 18),

              // ── Class ──────────────────────────────────────────────────
              _buildDropdown<String>(
                label: 'Class',
                icon: Icons.class_,
                value: _selectedClass,
                items: kClasses,
                required: true,
                onChanged: (v) => setState(() => _selectedClass = v),
              ),
              const SizedBox(height: 18),

              // ── Section ────────────────────────────────────────────────
              _buildDropdown<String>(
                label: 'Section',
                icon: Icons.apps,
                value: _selectedSection,
                items: kSections,
                required: true,
                onChanged: (v) => setState(() => _selectedSection = v),
              ),
              const SizedBox(height: 18),

              // ── Day ────────────────────────────────────────────────────
              _buildDropdown<String>(
                label: 'Day',
                icon: Icons.calendar_today,
                value: _selectedDay,
                items: _days,
                required: true,
                onChanged: (v) =>
                    setState(() => _selectedDay = v ?? 'Monday'),
              ),
              const SizedBox(height: 18),

              // ── Start / End Time ───────────────────────────────────────
              Row(
                children: [
                  Expanded(
                      child:
                          _buildTimePicker('Start Time', _startTime, true)),
                  const SizedBox(width: 14),
                  Expanded(
                      child:
                          _buildTimePicker('End Time', _endTime, false)),
                ],
              ),
              const SizedBox(height: 18),

              // ── Room ───────────────────────────────────────────────────
              _buildDropdown<String>(
                label: 'Room Number',
                icon: Icons.meeting_room,
                value: _selectedRoom,
                items: kRooms,
                required: true,
                onChanged: (v) => setState(() => _selectedRoom = v),
              ),
              const SizedBox(height: 32),

              // ── Submit Button ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadTimetable,
                  icon: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.add_circle_outline),
                  label: Text(
                    _isUploading ? 'Adding...' : 'Add to Timetable',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}