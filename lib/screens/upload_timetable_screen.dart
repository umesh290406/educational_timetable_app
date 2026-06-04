import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lecture_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/class_config.dart';

class UploadTimetableScreen extends StatefulWidget {
  const UploadTimetableScreen({Key? key}) : super(key: key);

  @override
  State<UploadTimetableScreen> createState() => _UploadTimetableScreenState();
}

class _UploadTimetableScreenState extends State<UploadTimetableScreen> {
  // Text controllers
  final _subjectController = TextEditingController();
  final _professorController = TextEditingController();
  final _roomController = TextEditingController();

  // Dropdowns
  String _selectedClass = '11th';
  String _selectedSpecialization = 'Commerce';
  String _selectedSection = 'A';
  String _selectedDay = 'Monday';

  // Time
  String _startTime = '';
  String _endTime = '';

  @override
  void dispose() {
    _subjectController.dispose();
    _professorController.dispose();
    _roomController.dispose();
    super.dispose();
  }

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
    final subject = _subjectController.text.trim();
    final professor = _professorController.text.trim();
    final room = _roomController.text.trim();

    if (subject.isEmpty ||
        professor.isEmpty ||
        room.isEmpty ||
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

    final combinedClass = ClassConfig.combineClassAndSpecialization(_selectedClass, _selectedSpecialization);

    final success = await lectureProvider.createTimetable(
      subjectName: subject,
      teacherName: professor,
      className: combinedClass,
      section: _selectedSection,
      day: _selectedDay,
      startTime: _startTime,
      endTime: _endTime,
      roomNumber: room,
    );

    setState(() => _isUploading = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timetable entry added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Reset form for next entry
        setState(() {
          _subjectController.clear();
          _professorController.clear();
          _roomController.clear();
          _selectedClass = null;
          _selectedSection = null;
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

  // ── Reusable labelled text field ──────────────────────────────────────────
  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLength: 50,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            prefixIcon: Icon(icon, color: Colors.teal.shade600, size: 20),
            hintText: 'Type ${label.replaceAll(' *', '')}...',
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.teal.shade400, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            counterStyle: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
          ),
        ),
      ],
    );
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
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            prefixIcon:
                Icon(icon, color: Colors.teal.shade600, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400),
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
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectTime(isStart),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
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
                    color: time.isEmpty ? Colors.grey : Theme.of(context).colorScheme.onSurface,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
            color: Theme.of(context).cardColor,
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
              _buildTextField(
                label: 'Subject Name',
                icon: Icons.subject,
                controller: _subjectController,
                required: true,
              ),
              const SizedBox(height: 18),

              // ── Professor ──────────────────────────────────────────────
              _buildTextField(
                label: 'Professor Name',
                icon: Icons.person,
                controller: _professorController,
                required: true,
              ),
              const SizedBox(height: 18),

              // ── Class Dropdown ──────────────────────────────────────────────────
              _buildDropdown<String>(
                label: 'Class Name',
                icon: Icons.class_,
                value: _selectedClass,
                items: ClassConfig.classes,
                required: true,
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedClass = v;
                      final newSpecs = ClassConfig.getSpecializationsForClass(v);
                      _selectedSpecialization = newSpecs.isNotEmpty ? newSpecs[0] : '';
                    });
                  }
                },
              ),
              const SizedBox(height: 18),

              // ── Specialization Dropdown ──────────────────────────────────────────
              if (ClassConfig.getSpecializationsForClass(_selectedClass).isNotEmpty) ...[
                _buildDropdown<String>(
                  label: 'Specialization / Branch',
                  icon: Icons.assignment_turned_in,
                  value: _selectedSpecialization,
                  items: ClassConfig.getSpecializationsForClass(_selectedClass),
                  required: true,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedSpecialization = v;
                      });
                    }
                  },
                ),
                const SizedBox(height: 18),
              ],

              // ── Section ────────────────────────────────────────────────
              _buildDropdown<String>(
                label: 'Section',
                icon: Icons.apps,
                value: _selectedSection,
                items: ClassConfig.sections,
                required: true,
                onChanged: (v) => setState(() => _selectedSection = v ?? 'A'),
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
              _buildTextField(
                label: 'Room Number',
                icon: Icons.meeting_room,
                controller: _roomController,
                required: true,
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