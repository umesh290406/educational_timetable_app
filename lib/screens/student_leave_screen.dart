import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/attendance_service.dart';
import '../services/leave_service.dart';

class StudentLeaveScreen extends StatefulWidget {
  const StudentLeaveScreen({Key? key}) : super(key: key);

  @override
  State<StudentLeaveScreen> createState() => _StudentLeaveScreenState();
}

class _StudentLeaveScreenState extends State<StudentLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _rollController = TextEditingController();

  DateTimeRange? _selectedDateRange;
  String _rollNo = '';
  bool _isLoading = false;
  List<LeaveRequest> _leaves = [];

  @override
  void initState() {
    super.initState();
    _loadStudentDetails();
  }

  Future<void> _loadStudentDetails() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = authProvider.user?.email ?? '';
    final roll = await AttendanceService.getSavedRollNo(email);
    
    if (roll != null && roll.isNotEmpty) {
      setState(() {
        _rollNo = roll;
      });
      await _fetchLeaves();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchLeaves() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = authProvider.user?.email ?? '';
    final list = await LeaveService.getLeavesForStudent(email);
    setState(() {
      _leaves = list;
    });
  }

  Future<void> _saveRollNo() async {
    if (_rollController.text.trim().isEmpty) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    await AttendanceService.saveRollNo(
      user.email,
      _rollController.text.trim(),
      name: user.name,
      className: user.className,
      section: user.section,
    );

    setState(() {
      _rollNo = _rollController.text.trim();
    });
    
    await _fetchLeaves();
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: _selectedDateRange?.start ?? now,
      end: _selectedDateRange?.end ?? now.add(const Duration(days: 2)),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 30)), // Allow applying retroactively up to 30 days
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal.shade600,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Future<void> _submitLeave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select leave dates')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user!;

    await LeaveService.applyLeave(
      studentEmail: user.email,
      studentName: user.name,
      rollNo: _rollNo,
      className: user.className ?? '',
      section: user.section ?? '',
      reason: _reasonController.text.trim(),
      startDate: DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start),
      endDate: DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end),
    );

    _reasonController.clear();
    setState(() {
      _selectedDateRange = null;
    });

    await _fetchLeaves();
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Leave request submitted successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade600,
        title: Text(
          'Apply for Leave',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading && _rollNo.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _rollNo.isEmpty
              ? _buildRollNoInput()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card with Student info
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Student Details',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Name: ${user?.name}',
                                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade800),
                                  ),
                                  Text(
                                    'Roll No: $_rollNo',
                                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Class & Section: ${user?.className} - ${user?.section}',
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade800),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Apply Form Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'New Leave Request',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Date range selector button
                                InkWell(
                                  onTap: _selectDateRange,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today, color: Colors.teal.shade600),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _selectedDateRange == null
                                                ? 'Select Start & End Dates'
                                                : '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)}  -  ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: _selectedDateRange == null ? Colors.grey.shade600 : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.arrow_drop_down),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Reason Input
                                TextFormField(
                                  controller: _reasonController,
                                  decoration: InputDecoration(
                                    labelText: 'Reason for Leave',
                                    hintText: 'Please detail the reason for requesting leave (e.g., medical, family function, etc.)',
                                    alignLabelWithHint: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    labelStyle: GoogleFonts.poppins(),
                                    hintStyle: GoogleFonts.poppins(fontSize: 13),
                                  ),
                                  maxLines: 4,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter a reason';
                                    }
                                    if (value.trim().length < 5) {
                                      return 'Please provide a more detailed reason';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                // Submit Button
                                ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _submitLeave,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.send),
                                  label: Text(
                                    'Submit Request',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // History Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          'Your Leave History',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // History List
                      _leaves.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  'No previous leave requests found.',
                                  style: GoogleFonts.poppins(color: Colors.grey, fontStyle: FontStyle.italic),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _leaves.length,
                              itemBuilder: (context, index) {
                                final req = _leaves[index];
                                final appliedDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(req.appliedAt));
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${DateFormat('MMM dd').format(DateTime.parse(req.startDate))} - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(req.endDate))}',
                                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            _buildStatusBadge(req.status),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Reason: ${req.reason}',
                                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade800),
                                        ),
                                        const SizedBox(height: 8),
                                        if (req.comment.isNotEmpty) ...[
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Teacher Comment:',
                                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal.shade800),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  req.comment,
                                                  style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: Text(
                                            'Applied on: $appliedDate',
                                            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Approved':
        color = Colors.green;
        break;
      case 'Rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRollNoInput() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.badge, size: 64, color: Colors.teal.shade600),
                const SizedBox(height: 16),
                Text(
                  'Student Identity Required',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please enter your Roll Number to apply for leave. This will link your leave to the class records.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _rollController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Roll Number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveRollNo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Save & Proceed',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
