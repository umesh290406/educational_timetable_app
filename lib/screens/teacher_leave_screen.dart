import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/leave_service.dart';

class TeacherLeaveScreen extends StatefulWidget {
  const TeacherLeaveScreen({Key? key}) : super(key: key);

  @override
  State<TeacherLeaveScreen> createState() => _TeacherLeaveScreenState();
}

class _TeacherLeaveScreenState extends State<TeacherLeaveScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  
  bool _isLoading = false;
  List<LeaveRequest> _pendingLeaves = [];
  List<LeaveRequest> _resolvedLeaves = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchLeaves();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaves() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user != null) {
      final className = user.className ?? 'SE';
      final section = user.section ?? 'A';
      
      final list = await LeaveService.getLeavesForTeacher(className, section);
      
      setState(() {
        _pendingLeaves = list.where((e) => e.status == 'Pending').toList();
        _resolvedLeaves = list.where((e) => e.status != 'Pending').toList();
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _processLeave(LeaveRequest request, String newStatus) async {
    _commentController.clear();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '$newStatus Request',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leave details:',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              'Student: ${request.studentName} (Roll ${request.rollNo})\nDates: ${request.startDate} to ${request.endDate}\nReason: ${request.reason}',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: 'Add Comments (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'Approved' ? Colors.green : Colors.red,
            ),
            child: Text(newStatus),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      await LeaveService.updateLeaveStatus(
        id: request.id,
        status: newStatus,
        comment: _commentController.text.trim(),
      );
      await _fetchLeaves();
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Leave request $newStatus successfully!'),
          backgroundColor: newStatus == 'Approved' ? Colors.green : Colors.red,
        ),
      );
    }
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
          'Student Leave Management',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              child: Text(
                'Pending (${_pendingLeaves.length})',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            Tab(
              child: Text(
                'Leave Records (${_resolvedLeaves.length})',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLeaves,
        child: _isLoading && _pendingLeaves.isEmpty && _resolvedLeaves.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Class display badge
                  Container(
                    width: double.infinity,
                    color: Colors.teal.shade50,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Showing leave requests for Class: ${user?.className ?? "SE"} - Section: ${user?.section ?? "A"}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPendingTab(),
                        _buildRecordsTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPendingTab() {
    if (_pendingLeaves.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No pending leave requests!',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pendingLeaves.length,
      itemBuilder: (context, index) {
        final req = _pendingLeaves[index];
        final appliedDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(req.appliedAt));
        final dateText = '${DateFormat('MMM dd').format(DateTime.parse(req.startDate))} - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(req.endDate))}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      req.studentName,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade800),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Roll ${req.rollNo}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      dateText,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Reason: ${req.reason}',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 12),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Applied: $appliedDate',
                      style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _processLeave(req, 'Rejected'),
                      icon: const Icon(Icons.close, size: 16),
                      label: Text('Reject', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _processLeave(req, 'Approved'),
                      icon: const Icon(Icons.check, size: 16),
                      label: Text('Approve', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecordsTab() {
    if (_resolvedLeaves.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No leave records found.',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _resolvedLeaves.length,
      itemBuilder: (context, index) {
        final req = _resolvedLeaves[index];
        final appliedDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(req.appliedAt));
        final dateText = '${DateFormat('MMM dd').format(DateTime.parse(req.startDate))} - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(req.endDate))}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      req.studentName,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade800),
                    ),
                    _buildStatusBadge(req.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Roll ${req.rollNo} | $dateText',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reason: ${req.reason}',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade800),
                ),
                if (req.comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your comment:',
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
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    'Applied: $appliedDate',
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
}
