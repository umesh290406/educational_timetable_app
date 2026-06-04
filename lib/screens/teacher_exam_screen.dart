import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/exam_service.dart';
import '../services/attendance_service.dart';
import '../widgets/loading_widget.dart';

class TeacherExamScreen extends StatefulWidget {
  const TeacherExamScreen({super.key});

  @override
  State<TeacherExamScreen> createState() => _TeacherExamScreenState();
}

class _TeacherExamScreenState extends State<TeacherExamScreen> {
  String _selectedClass = '11th';
  String _selectedSection = 'A';
  List<ExamSchedule> _exams = [];
  bool _isLoading = false;

  final List<String> _classes = ['11th', '12th', 'FE', 'SE', 'TE', 'BE'];
  final List<String> _sections = ['A', 'B', 'C', 'D', 'E'];

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);
    final exams = await ExamService.getExamsForClass(_selectedClass, _selectedSection);
    setState(() {
      _exams = exams;
      _isLoading = false;
    });
  }

  // Show dialog to create a new exam
  void _showAddExamDialog() {
    final formKey = GlobalKey<FormState>();
    final subjectController = TextEditingController();
    final venueController = TextEditingController();
    String dialogClass = _selectedClass;
    String dialogSection = _selectedSection;
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: theme.cardColor,
              title: Text(
                'Schedule New Exam',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Form(
                  key: formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // Class Select
                      Text('Class', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: _classes.map((c) {
                          final isSel = dialogClass == c;
                          return ChoiceChip(
                            label: Text(c, style: GoogleFonts.poppins(fontSize: 12)),
                            selected: isSel,
                            selectedColor: Colors.teal.shade600,
                            labelStyle: TextStyle(color: isSel ? Colors.white : theme.colorScheme.onSurface),
                            onSelected: (val) {
                              if (val) setDialogState(() => dialogClass = c);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Section Select
                      Text('Section', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: _sections.map((s) {
                          final isSel = dialogSection == s;
                          return ChoiceChip(
                            label: Text('Sec $s', style: GoogleFonts.poppins(fontSize: 12)),
                            selected: isSel,
                            selectedColor: Colors.teal.shade600,
                            labelStyle: TextStyle(color: isSel ? Colors.white : theme.colorScheme.onSurface),
                            onSelected: (val) {
                              if (val) setDialogState(() => dialogSection = s);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Subject Name
                      TextFormField(
                        controller: subjectController,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Subject Name',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter subject name' : null,
                      ),
                      const SizedBox(height: 16),

                      // Date Picker Tile
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        leading: Icon(Icons.calendar_month, color: Colors.teal.shade600),
                        title: Text(
                          selectedDate == null ? 'Select Exam Date' : DateFormat('yyyy-MM-dd').format(selectedDate!),
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Start Time
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        leading: Icon(Icons.access_time, color: Colors.teal.shade600),
                        title: Text(
                          startTime == null ? 'Select Start Time' : startTime!.format(context),
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 9, minute: 0),
                          );
                          if (picked != null) {
                            setDialogState(() => startTime = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // End Time
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        leading: Icon(Icons.access_time_filled, color: Colors.teal.shade600),
                        title: Text(
                          endTime == null ? 'Select End Time' : endTime!.format(context),
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 12, minute: 0),
                          );
                          if (picked != null) {
                            setDialogState(() => endTime = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Venue/Room Number
                      TextFormField(
                        controller: venueController,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Exam Venue / Room Number',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter venue/room number' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (selectedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select exam date'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    if (startTime == null || endTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select exam timings'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    await ExamService.createExam(
                      className: dialogClass,
                      section: dialogSection,
                      subjectName: subjectController.text.trim(),
                      examDate: DateFormat('yyyy-MM-dd').format(selectedDate!),
                      startTime: startTime!.format(context),
                      endTime: endTime!.format(context),
                      venue: venueController.text.trim(),
                    );

                    Navigator.pop(context);
                    _loadExams();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Exam schedule published successfully!'), backgroundColor: Colors.green),
                    );
                  },
                  child: Text('Publish', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Open Exam Attendance marking interface
  void _openExamAttendanceSheet(ExamSchedule exam) async {
    setState(() => _isLoading = true);
    final roster = await AttendanceService.getRoster(exam.className, exam.section);
    setState(() => _isLoading = false);

    if (roster.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('No Students Found', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
            'No registered student profiles were found for ${exam.className} - ${exam.section}. '
            'Register student accounts or mark attendance in the standard Attendance screen first to auto-generate the roster.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Ok', style: GoogleFonts.poppins(color: Colors.teal.shade600, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    // Prepare mutable attendance map
    final Map<String, String> tempAttendance = Map<String, String>.from(exam.attendance);
    // Initialize un-marked students as Present
    for (final student in roster) {
      if (!tempAttendance.containsKey(student.rollNo)) {
        tempAttendance[student.rollNo] = 'Present';
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: theme.cardColor,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track Exam Attendance',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${exam.subjectName} (${exam.className} - ${exam.section})',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    // Summary status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatusChip(
                          'P: ${tempAttendance.values.where((v) => v == 'Present').length}',
                          Colors.green,
                        ),
                        _buildStatusChip(
                          'A: ${tempAttendance.values.where((v) => v == 'Absent').length}',
                          Colors.red,
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: ListView.builder(
                        itemCount: roster.length,
                        itemBuilder: (context, idx) {
                          final student = roster[idx];
                          final status = tempAttendance[student.rollNo] ?? 'Present';
                          final isPresent = status == 'Present';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.shade100,
                                child: Text(
                                  student.rollNo,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.teal.shade800,
                                  ),
                                ),
                              ),
                              title: Text(
                                student.name,
                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              trailing: ToggleButtons(
                                borderRadius: BorderRadius.circular(12),
                                constraints: const BoxConstraints(minHeight: 32, minWidth: 60),
                                isSelected: [isPresent, !isPresent],
                                selectedColor: Colors.white,
                                fillColor: isPresent ? Colors.green.shade600 : Colors.red.shade600,
                                children: [
                                  Text('Present', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text('Absent', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                                onPressed: (index) {
                                  setSheetState(() {
                                    tempAttendance[student.rollNo] = index == 0 ? 'Present' : 'Absent';
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    await ExamService.markExamAttendance(
                      examId: exam.id,
                      attendance: tempAttendance,
                    );
                    Navigator.pop(context);
                    _loadExams();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Exam attendance updated!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: Text('Save', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade600,
        title: Text(
          'Manage Exam Schedules',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExamDialog,
        backgroundColor: Colors.teal.shade600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Filter section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade600.withOpacity(0.08),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Class',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedClass,
                            isExpanded: true,
                            items: _classes.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(c, style: GoogleFonts.poppins(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedClass = val);
                                _loadExams();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Section',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSection,
                            isExpanded: true,
                            items: _sections.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text('Sec $s', style: GoogleFonts.poppins(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedSection = val);
                                _loadExams();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const LoadingWidget(message: 'Loading schedules...')
                : _exams.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No scheduled exams found',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap the "+" button below to schedule one.',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _exams.length,
                        itemBuilder: (context, index) {
                          final exam = _exams[index];
                          final totalStudents = exam.attendance.length;
                          final presentStudents = exam.attendance.values.where((v) => v == 'Present').length;

                          return Card(
                            elevation: 2,
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
                                      Expanded(
                                        child: Text(
                                          exam.subjectName,
                                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text('Delete Exam', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                              content: Text('Are you sure you want to delete this exam schedule?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await ExamService.deleteExam(exam.id);
                                            _loadExams();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_month, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 8),
                                      Text(
                                        exam.examDate,
                                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${exam.startTime} - ${exam.endTime}',
                                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Venue: ${exam.venue}',
                                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                  if (totalStudents > 0) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'Attendance: $presentStudents / $totalStudents Present',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade600,
                                      ),
                                    ),
                                  ],
                                  const Divider(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal.shade600,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => _openExamAttendanceSheet(exam),
                                      icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                                      label: Text(
                                        totalStudents > 0 ? 'Update Exam Attendance' : 'Track Student Attendance',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
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
        ],
      ),
    );
  }
}
