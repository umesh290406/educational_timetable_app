import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/lecture_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/class_config.dart';

class AddLectureScreen extends StatefulWidget {
  const AddLectureScreen({Key? key}) : super(key: key);

  @override
  State<AddLectureScreen> createState() => _AddLectureScreenState();
}

class _AddLectureScreenState extends State<AddLectureScreen> {
  // Text controllers
  final _subjectController = TextEditingController();
  final _professorController = TextEditingController();
  final _roomController = TextEditingController();

  // Class selection
  String _selectedClass = '11th';
  String _selectedSpecialization = 'Commerce';
  String _selectedSection = 'A';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.user != null) {
        _professorController.text = auth.user!.name;
      }
    });
  }

  // Reminder
  String _selectedReminder = 'Send Now';

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

  @override
  void dispose() {
    _subjectController.dispose();
    _professorController.dispose();
    _roomController.dispose();
    super.dispose();
  }

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
    final subject = _subjectController.text.trim();
    final professor = _professorController.text.trim();
    final room = _roomController.text.trim();

    if (subject.isEmpty || professor.isEmpty || _startTime.isEmpty || _endTime.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill Subject, Professor, Start & End Time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
    final combinedClass = ClassConfig.combineClassAndSpecialization(_selectedClass, _selectedSpecialization);

    final response = await lp.createLecture(
      subjectName: subject,
      teacherName: professor,
      className: combinedClass,
      section: _selectedSection,
      startTime: _startTime,
      endTime: _endTime,
      roomNumber: room,
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
          final lectureTime = DateTime(now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);

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
            title: 'Upcoming Lecture: $subject',
            message: 'Lecture starts at $_startTime in Room $room',
            notificationType: 'reminder',
            className: combinedClass,
            section: _selectedSection,
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
              content: Text('Lecture created, but reminder scheduling failed. Check connection.'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lecture created successfully!'),
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
            content: Text(lp.error ?? 'Failed to create lecture. Check server connection.'),
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLength: 50,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(fontSize: 14, color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
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

  // ── Chip selector row ──────────────────────────────────────────────────────
  Widget _buildChipSelector({
    required String label,
    required List<String> options,
    required String? selected,
    required void Function(String) onSelect,
    bool required = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: options.map((opt) {
            final isSelected = selected == opt;
            return ChoiceChip(
              label: Text(opt),
              selected: isSelected,
              selectedColor: Colors.teal.shade600,
              backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isSelected ? Colors.teal.shade600 : Colors.grey.shade400),
              ),
              labelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.teal.shade900,
              ),
              onSelected: (_) => onSelect(opt),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Time picker tile ───────────────────────────────────────────────────────
  Widget _buildTimePicker(String label, String time, bool isStart) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectTime(isStart),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.teal.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  time.isEmpty ? 'Select time' : time,
                  style: GoogleFonts.poppins(fontSize: 13, color: time.isEmpty ? Colors.grey : theme.colorScheme.onSurface),
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade600,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Add New Lecture',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Subject (TextField) ───────────────────────────────────────
              _buildTextField(
                label: 'Subject Name',
                icon: Icons.subject,
                controller: _subjectController,
                required: true,
              ),
              const SizedBox(height: 20),

              // ── Professor (TextField) ─────────────────────────────────────
              _buildTextField(
                label: 'Professor Name',
                icon: Icons.person,
                controller: _professorController,
                required: true,
              ),
              const SizedBox(height: 20),

              // ── Class Dropdown ───────────────────────────────────
              Text(
                'Class Name *',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedClass,
                    isExpanded: true,
                    items: ClassConfig.classes.map((cls) {
                      return DropdownMenuItem(
                        value: cls,
                        child: Text(cls, style: GoogleFonts.poppins(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedClass = val;
                          final newSpecs = ClassConfig.getSpecializationsForClass(val);
                          _selectedSpecialization = newSpecs.isNotEmpty ? newSpecs[0] : '';
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Specialization Dropdown ───────────────────────────────────
              if (ClassConfig.getSpecializationsForClass(_selectedClass).isNotEmpty) ...[
                Text(
                  'Specialization / Branch *',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSpecialization,
                      isExpanded: true,
                      items: ClassConfig.getSpecializationsForClass(_selectedClass).map((spec) {
                        return DropdownMenuItem(
                          value: spec,
                          child: Text(spec, style: GoogleFonts.poppins(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedSpecialization = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Section Dropdown ─────────────────────────────────────
              Text(
                'Section / Division *',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSection,
                    isExpanded: true,
                    items: ClassConfig.sections.map((sec) {
                      return DropdownMenuItem(
                        value: sec,
                        child: Text('Section $sec', style: GoogleFonts.poppins(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedSection = val;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Start / End Time ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(child: _buildTimePicker('Start Time *', _startTime, true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTimePicker('End Time *', _endTime, false)),
                ],
              ),
              const SizedBox(height: 20),

              // ── Room (TextField) ───────────────────────────────────────────
              _buildTextField(
                label: 'Room Number',
                icon: Icons.meeting_room,
                controller: _roomController,
              ),
              const SizedBox(height: 20),

              // ── Notification Reminder (kept as dropdown) ───────────────────
              Text(
                'Notification Reminder',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedReminder,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.teal.shade400, width: 2)),
                  prefixIcon: Icon(Icons.notifications_active, color: Colors.teal.shade600),
                ),
                items: _reminderOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: GoogleFonts.poppins(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (newValue) => setState(() => _selectedReminder = newValue!),
              ),
              const SizedBox(height: 30),

              // ── Submit ─────────────────────────────────────────────────────
              Consumer<LectureProvider>(
                builder: (context, lp, _) {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: lp.isLoading ? null : () => _createLecture(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: Colors.grey.shade400,
                      ),
                      child: lp.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Create Lecture',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
