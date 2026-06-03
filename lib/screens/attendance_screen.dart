import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/attendance_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _isTeacher = false;

  // Student State
  String? _studentRollNo;
  bool _isLoadingStudent = true;
  Map<String, dynamic> _studentStats = {};

  // Teacher State
  String _selectedClass = 'SE';
  String _selectedSection = 'A';
  String _selectedSubject = '';
  DateTime _selectedDate = DateTime.now();
  List<AttendanceStudent> _roster = [];
  Map<String, String> _markedStatus = {};
  List<Map<String, String>> _markedSessions = [];
  List<Map<String, dynamic>> _classReport = [];
  bool _isLoadingTeacher = false;

  final TextEditingController _subjectController = TextEditingController();

  static const List<String> _classes = ['11th', '12th', 'FE', 'SE', 'TE', 'BE'];
  static const List<String> _sections = ['A', 'B', 'C', 'D', 'E'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final isTeacher = auth.user?.role == 'teacher';
      setState(() => _isTeacher = isTeacher);
      if (isTeacher) {
        _tabController = TabController(length: 3, vsync: this);
        _loadTeacherData();
      } else {
        _loadStudentData();
      }
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _tabController?.dispose();
    super.dispose();
  }



  // ================= STUDENT LOGIC =================
  Future<void> _loadStudentData() async {
    setState(() => _isLoadingStudent = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = auth.user?.email ?? '';
    final roll = await AttendanceService.getSavedRollNo(email);
    _studentRollNo = roll;
    
    if (roll != null) {
      final className = auth.user?.className ?? 'SE';
      final section = auth.user?.section ?? 'A';
      
      // Proactively sync student registration to teacher roster
      await AttendanceService.registerStudent(
        email: email,
        name: auth.user?.name ?? 'Student',
        rollNo: roll,
        className: className,
        section: section,
      );

      final stats = await AttendanceService.getStudentStats(roll, className, section);
      setState(() {
        _studentStats = stats;
        _isLoadingStudent = false;
      });
    } else {
      setState(() => _isLoadingStudent = false);
    }
  }

  Future<void> _saveStudentRollNo(String roll) async {
    if (roll.trim().isEmpty) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = auth.user?.email ?? '';
    final className = auth.user?.className ?? 'SE';
    final section = auth.user?.section ?? 'A';
    
    await AttendanceService.saveRollNo(
      email,
      roll,
      name: auth.user?.name ?? 'Student',
      className: className,
      section: section,
    );
    _loadStudentData();
  }

  // ================= TEACHER LOGIC =================
  Future<void> _loadTeacherData() async {
    setState(() => _isLoadingTeacher = true);
    final rosterList = await AttendanceService.getRoster(_selectedClass, _selectedSection);
    final sessionsList = await AttendanceService.getMarkedSessions(_selectedClass, _selectedSection);
    final reportList = await AttendanceService.getClassReport(_selectedClass, _selectedSection);

    setState(() {
      _roster = rosterList;
      _markedSessions = sessionsList;
      _classReport = reportList;
      // Initialize marked status as Present by default
      _markedStatus = {for (var s in rosterList) s.rollNo: 'Present'};
      _isLoadingTeacher = false;
    });
  }

  Future<void> _saveAttendance() async {
    setState(() => _isLoadingTeacher = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final records = _roster.map((student) {
      return AttendanceRecord(
        id: '${student.rollNo}_${_selectedSubject}_$dateStr',
        rollNo: student.rollNo,
        studentName: student.name,
        subjectName: _selectedSubject,
        date: dateStr,
        status: _markedStatus[student.rollNo] ?? 'Present',
        className: _selectedClass,
        section: _selectedSection,
      );
    }).toList();

    await AttendanceService.saveBatchAttendance(records);
    await _loadTeacherData(); // Refresh everything
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance marked successfully for $_selectedSubject!',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteSession(String subject, String date) async {
    setState(() => _isLoadingTeacher = true);
    await AttendanceService.deleteAttendanceBatch(
      className: _selectedClass,
      section: _selectedSection,
      subjectName: subject,
      date: date,
    );
    await _loadTeacherData(); // Refresh
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Session $subject ($date) attendance deleted.',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.redAccent.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddStudentDialog() {
    final rollController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Student to Roster',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rollController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Roll Number',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Student Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (rollController.text.trim().isNotEmpty && nameController.text.trim().isNotEmpty) {
                final newStudent = AttendanceStudent(
                  rollNo: rollController.text.trim(),
                  name: nameController.text.trim(),
                );
                await AttendanceService.addStudentToRoster(_selectedClass, _selectedSection, newStudent);
                if (!mounted) return;
                Navigator.pop(context);
                _loadTeacherData();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ================= RENDER INTERFACE =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade600,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Attendance Tracking',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        bottom: _isTeacher && _tabController != null
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.teal.shade100,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: const [
                  Tab(icon: Icon(Icons.check_circle_outline), text: 'Mark'),
                  Tab(icon: Icon(Icons.settings_suggest_outlined), text: 'Advanced Panel'),
                  Tab(icon: Icon(Icons.people_outline), text: 'Roster'),
                ],
              )
            : null,
      ),
      body: _isTeacher ? _buildTeacherView() : _buildStudentView(),
    );
  }

  // ================= VIEW FOR STUDENT =================
  Widget _buildStudentView() {
    if (_isLoadingStudent) {
      return const Center(child: CircularProgressIndicator(color: Colors.teal));
    }

    final auth = Provider.of<AuthProvider>(context);
    final studentClass = auth.user?.className ?? 'SE';
    final studentSection = auth.user?.section ?? 'A';

    if (_studentRollNo == null) {
      final rollController = TextEditingController();
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_ind_outlined, size: 72, color: Colors.teal.shade600),
                  const SizedBox(height: 16),
                  Text(
                    'Setup Roll Number',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please enter your classroom roll number to access your attendance metrics for class $studentClass - Section $studentSection.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: rollController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Enter Roll Number (e.g. 1)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _saveStudentRollNo(rollController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'View Attendance',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final total = _studentStats['total'] as int? ?? 0;
    final attended = _studentStats['attended'] as int? ?? 0;
    final missed = _studentStats['missed'] as int? ?? 0;
    final percentage = _studentStats['percentage'] as double? ?? 0.0;
    final subjectStats = _studentStats['subjectStats'] as Map<String, Map<String, dynamic>>? ?? {};
    final history = _studentStats['history'] as List<AttendanceRecord>? ?? [];

    final isEligible = percentage >= 75.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Roll No and info
          Card(
            color: Colors.teal.shade600,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    radius: 28,
                    child: Text(
                      '#$_studentRollNo',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Class: $studentClass - $studentSection',
                          style: GoogleFonts.poppins(color: Colors.teal.shade100, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Student: ${auth.user?.name ?? 'Name'}',
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz, color: Colors.white),
                    tooltip: 'Change Roll No',
                    onPressed: () {
                      setState(() {
                        _studentRollNo = null; // Reconfigure
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Total Percentage Circular Progress
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: CircularProgressIndicator(
                          value: total == 0 ? 0 : percentage / 100,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.shade100,
                          color: isEligible ? Colors.teal.shade500 : Colors.redAccent,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isEligible ? Colors.teal.shade900 : Colors.redAccent.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEligible ? 'Safe for Exams!' : 'Below Attendance Cutoff!',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isEligible ? Colors.teal.shade800 : Colors.redAccent.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEligible
                              ? 'Your attendance is above the 75% requirement. Keep it up!'
                              : 'Warning: Minimum 75% attendance is required to sit for exams. Attend more classes!',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cards Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Attended',
                  '$attended classes',
                  Icons.check_circle_rounded,
                  Colors.green.shade50,
                  Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Missed',
                  '$missed classes',
                  Icons.cancel_rounded,
                  Colors.red.shade50,
                  Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Subject-wise Breakdown
          Text(
            'Attendance by Subject',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade900),
          ),
          const SizedBox(height: 8),
          subjectStats.isEmpty
              ? _buildEmptyState('No subject attendance data available. Teachers haven\'t marked your attendance yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: subjectStats.length,
                  itemBuilder: (context, index) {
                    final key = subjectStats.keys.elementAt(index);
                    final val = subjectStats[key]!;
                    final subPercent = val['percentage'] as double;
                    final subAttended = val['attended'] as int;
                    final subTotal = val['total'] as int;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  key,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  '$subAttended/$subTotal (${subPercent.toStringAsFixed(0)}%)',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: subPercent >= 75.0 ? Colors.teal : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: subPercent / 100,
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade100,
                                color: subPercent >= 75.0 ? Colors.teal : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 24),

          // History Feed
          Text(
            'Attendance History',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade900),
          ),
          const SizedBox(height: 8),
          history.isEmpty
              ? _buildEmptyState('No past attendance history logged.')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final rec = history[index];
                    final isPresent = rec.status == 'Present';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                          child: Icon(
                            isPresent ? Icons.check : Icons.close,
                            color: isPresent ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(
                          rec.subjectName,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          rec.date,
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPresent ? Colors.green.shade100 : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            rec.status,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color bgColor, Color color) {
    return Card(
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                ),
                Text(
                  count,
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ================= VIEW FOR TEACHER =================
  Widget _buildTeacherView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildTeacherMarkTab(),
        _buildTeacherAdvancedTab(),
        _buildTeacherRosterTab(),
      ],
    );
  }

  Widget _buildTeacherMarkTab() {
    if (_isLoadingTeacher) {
      return const Center(child: CircularProgressIndicator(color: Colors.teal));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class / Section / Subject Filter Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // CLASS chip row
                  Text('Class', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade800)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _classes.map((cls) {
                      final selected = _selectedClass == cls;
                      return ChoiceChip(
                        label: Text(cls),
                        selected: selected,
                        selectedColor: Colors.teal.shade600,
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: selected ? Colors.white : Colors.teal.shade900,
                        ),
                        onSelected: (_) {
                          setState(() => _selectedClass = cls);
                          _loadTeacherData();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // SECTION chip row
                  Text('Section / Division', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade800)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _sections.map((sec) {
                      final selected = _selectedSection == sec;
                      return ChoiceChip(
                        label: Text('Div $sec'),
                        selected: selected,
                        selectedColor: Colors.teal.shade600,
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: selected ? Colors.white : Colors.teal.shade900,
                        ),
                        onSelected: (_) {
                          setState(() => _selectedSection = sec);
                          _loadTeacherData();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // SUBJECT text field
                  Text('Subject Name', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade800)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _subjectController,
                    maxLength: 50,
                    onChanged: (val) => setState(() => _selectedSubject = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'e.g. DBMS, Mathematics, OS...',
                      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.book_outlined, color: Colors.teal),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),

                  // DATE picker row
                  Row(
                    children: [
                      Text('Date:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade800)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setState(() => _selectedDate = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('dd MMM yyyy').format(_selectedDate),
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal.shade900),
                                ),
                                Icon(Icons.calendar_today, size: 16, color: Colors.teal.shade600),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Students Roster marking list
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Student List (${_roster.length})',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade900),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _markedStatus = {for (var s in _roster) s.rollNo: 'Present'};
                  });
                },
                icon: const Icon(Icons.done_all, size: 16, color: Colors.teal),
                label: Text(
                  'Mark All Present',
                  style: GoogleFonts.poppins(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          _roster.isEmpty
              ? _buildEmptyState(
                  'No students found for $_selectedClass - Div $_selectedSection.\n'
                  'Students will appear here automatically once they log in with matching class & division.',
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _roster.length,
                  itemBuilder: (context, index) {
                    final student = _roster[index];
                    final isPresent = _markedStatus[student.rollNo] == 'Present';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade50,
                          child: Text(
                            student.rollNo,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                        ),
                        title: Text(
                          student.name,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          'Roll No: ${student.rollNo}',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ChoiceChip(
                              label: const Text('P'),
                              selected: isPresent,
                              selectedColor: Colors.green.shade100,
                              labelStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPresent ? Colors.green.shade800 : Colors.grey.shade600,
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _markedStatus[student.rollNo] = 'Present');
                              },
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('A'),
                              selected: !isPresent,
                              selectedColor: Colors.red.shade100,
                              labelStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: !isPresent ? Colors.red.shade800 : Colors.grey.shade600,
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _markedStatus[student.rollNo] = 'Absent');
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 24),

          if (_roster.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                if (_selectedSubject.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please enter a subject name before saving!',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      backgroundColor: Colors.orange.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                _saveAttendance();
              },
              icon: const Icon(Icons.save, color: Colors.white),
              label: Text(
                'Save Attendance  ($_selectedClass-$_selectedSection · ${_selectedSubject.isEmpty ? "No Subject" : _selectedSubject})',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedSubject.trim().isEmpty ? Colors.grey : Colors.teal.shade600,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  // ================= NEW ADVANCED CONTROL PANEL FOR TEACHER =================
  Widget _buildTeacherAdvancedTab() {
    if (_isLoadingTeacher) {
      return const Center(child: CircularProgressIndicator(color: Colors.teal));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class Filters header selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active: $_selectedClass - $_selectedSection',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade900),
              ),
              Text(
                'Change class filters in Mark tab',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. CLASS REPORT CARD (STUDENT PERCENTAGES)
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: Colors.teal.shade700, size: 22),
              const SizedBox(width: 8),
              Text(
                'Class Roster Summary Report',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal.shade800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _classReport.isEmpty
              ? _buildEmptyState('No summary reports logged.')
              : Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _classReport.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _classReport[index];
                      final name = item['name'] as String;
                      final roll = item['rollNo'] as String;
                      final totalVal = item['total'] as int;
                      final attendedVal = item['attended'] as int;
                      final percentVal = item['percentage'] as double;
                      final isEligible = percentVal >= 75.0 || totalVal == 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '#$roll - $name',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isEligible ? Colors.teal.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${percentVal.toStringAsFixed(0)}%',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isEligible ? Colors.teal.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Attended: $attendedVal / $totalVal classes',
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                                ),
                                Text(
                                  isEligible ? 'Eligible' : 'Detained Warn!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isEligible ? Colors.teal : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalVal == 0 ? 0.0 : percentVal / 100,
                                minHeight: 4,
                                backgroundColor: Colors.grey.shade100,
                                color: isEligible ? Colors.teal.shade400 : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
          const SizedBox(height: 28),

          // 2. MARKED SESSIONS WITH BULK DELETE
          Row(
            children: [
              Icon(Icons.history_toggle_off, color: Colors.red.shade700, size: 22),
              const SizedBox(width: 8),
              Text(
                'Attendance Logs & Delete Controls',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red.shade800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _markedSessions.isEmpty
              ? _buildEmptyState('No attendance logs marked yet for class $_selectedClass - Section $_selectedSection.')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _markedSessions.length,
                  itemBuilder: (context, index) {
                    final session = _markedSessions[index];
                    final subject = session['subject'] ?? '';
                    final date = session['date'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.shade50,
                          child: Icon(Icons.bookmark_remove, color: Colors.red.shade700),
                        ),
                        title: Text(
                          subject,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          'Marked on: $date',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                          tooltip: 'Delete Attendance Roster Log',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Session Log?'),
                                content: Text(
                                  'Are you sure you want to completely erase the marked attendance history for $subject on $date?\n\nThis cannot be undone!',
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteSession(subject, date);
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text('Confirm Erase'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildTeacherRosterTab() {
    if (_isLoadingTeacher) {
      return const Center(child: CircularProgressIndicator(color: Colors.teal));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Class Roster: $_selectedClass - $_selectedSection',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade900),
              ),
              ElevatedButton.icon(
                onPressed: _showAddStudentDialog,
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: Text(
                  'Add Student',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          _roster.isEmpty
              ? _buildEmptyState('No students configured in this class.')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _roster.length,
                  itemBuilder: (context, index) {
                    final student = _roster[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade100,
                          child: Text(student.rollNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        title: Text(student.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        subtitle: Text('Roll No: ${student.rollNo} | Class: $_selectedClass-$_selectedSection'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.teal),
                          onPressed: () {
                            // Quick Edit Dialog
                            final nameController = TextEditingController(text: student.name);
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text('Edit Student Name'),
                                content: TextField(
                                  controller: nameController,
                                  decoration: InputDecoration(
                                    labelText: 'Name',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (nameController.text.trim().isNotEmpty) {
                                        final edited = AttendanceStudent(rollNo: student.rollNo, name: nameController.text.trim());
                                        await AttendanceService.addStudentToRoster(_selectedClass, _selectedSection, edited);
                                        if (!mounted) return;
                                        Navigator.pop(context);
                                        _loadTeacherData();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
