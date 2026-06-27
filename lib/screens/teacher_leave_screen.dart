import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/leave_service.dart';
import '../utils/class_config.dart';

class TeacherLeaveScreen extends StatefulWidget {
  const TeacherLeaveScreen({Key? key}) : super(key: key);

  @override
  State<TeacherLeaveScreen> createState() => _TeacherLeaveScreenState();
}

class _TeacherLeaveScreenState extends State<TeacherLeaveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();

  // Filter state
  String _selectedClass = 'TE';
  String _selectedSection = 'A';
  String _selectedSpecialization = '';

  bool _isLoading = false;
  bool _hasFetched = false;
  List<LeaveRequest> _pendingLeaves = [];
  List<LeaveRequest> _resolvedLeaves = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Initialize specialization from default class
    final specs = ClassConfig.getSpecializationsForClass(_selectedClass);
    _selectedSpecialization = specs.isNotEmpty ? specs[0] : '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaves() async {
    setState(() {
      _isLoading = true;
      _hasFetched = true;
    });
    final list = await LeaveService.getLeavesForTeacher(
      _selectedClass,
      _selectedSection,
      specialization: _selectedSpecialization.isNotEmpty ? _selectedSpecialization : null,
    );
    if (mounted) {
      setState(() {
        _pendingLeaves = list.where((e) => e.status == 'Pending').toList();
        _resolvedLeaves = list.where((e) => e.status != 'Pending').toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _processLeave(LeaveRequest request, String newStatus) async {
    _commentController.clear();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '$newStatus Leave Request',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${request.studentName}  •  Roll ${request.rollNo}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal.shade800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Class: ${request.className} - ${request.section}',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dates: ${request.startDate} → ${request.endDate}',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reason: ${request.reason}',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: 'Add Comment (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.comment_outlined),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'Approved' ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(newStatus, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      final res = await LeaveService.updateLeaveStatus(
        id: request.id,
        status: newStatus,
        comment: _commentController.text.trim(),
      );
      await _fetchLeaves();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave request $newStatus successfully!'),
            backgroundColor: newStatus == 'Approved' ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final specs = ClassConfig.getSpecializationsForClass(_selectedClass);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        title: Text(
          'Student Leave Management',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Text(
                'Pending (${_pendingLeaves.length})',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
            Tab(
              child: Text(
                'Records (${_resolvedLeaves.length})',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Filter Panel ─────────────────────────────────────────────────
          Container(
            color: Colors.teal.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter by Class / Division / Branch',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Class dropdown
                    Expanded(
                      child: _buildDropdown(
                        label: 'Class',
                        value: _selectedClass,
                        items: ClassConfig.classes,
                        onChanged: (val) {
                          if (val == null) return;
                          final newSpecs = ClassConfig.getSpecializationsForClass(val);
                          setState(() {
                            _selectedClass = val;
                            _selectedSpecialization = newSpecs.isNotEmpty ? newSpecs[0] : '';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Section dropdown
                    Expanded(
                      child: _buildDropdown(
                        label: 'Section',
                        value: _selectedSection,
                        items: ClassConfig.sections,
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedSection = val);
                        },
                        displayPrefix: 'Div ',
                      ),
                    ),
                  ],
                ),
                if (specs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDropdown(
                    label: 'Branch / Specialization',
                    value: _selectedSpecialization.isNotEmpty && specs.contains(_selectedSpecialization)
                        ? _selectedSpecialization
                        : specs[0],
                    items: specs,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSpecialization = val);
                    },
                    isFullWidth: true,
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _fetchLeaves,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.search, size: 18),
                    label: Text(
                      _isLoading ? 'Loading...' : 'Fetch Leave Requests',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Tab Content ──────────────────────────────────────────────────
          Expanded(
            child: !_hasFetched
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined, size: 72, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'Select class, section & branch\nthen tap "Fetch Leave Requests"',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchLeaves,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPendingTab(),
                        _buildRecordsTab(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String displayPrefix = '',
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          hint: Text(label, style: GoogleFonts.poppins(fontSize: 13)),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                '$displayPrefix$item',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: onChanged,
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
              'No pending leave requests',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            ),
            Text(
              'for $_selectedClass - Div $_selectedSection',
              style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12),
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
        return _buildLeaveCard(req, isPending: true);
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
              'No leave records found',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            ),
            Text(
              'for $_selectedClass - Div $_selectedSection',
              style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12),
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
        return _buildLeaveCard(req, isPending: false);
      },
    );
  }

  Widget _buildLeaveCard(LeaveRequest req, {required bool isPending}) {
    final appliedDate = _safeFormatDate(req.appliedAt, 'MMM dd, yyyy');
    final startFmt = _safeFormatDate(req.startDate, 'MMM dd');
    final endFmt = _safeFormatDate(req.endDate, 'MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: isPending ? 3 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.studentName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.teal.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Roll: ${req.rollNo.isNotEmpty ? req.rollNo : "—"}',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${req.className} - Div ${req.section}',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isPending) _buildStatusBadge(req.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.orange.shade600),
                const SizedBox(width: 6),
                Text(
                  '$startFmt → $endFmt',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    req.reason,
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
            if (!isPending && req.comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your comment:',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal.shade700),
                    ),
                    Text(
                      req.comment,
                      style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Applied: $appliedDate',
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                ),
                if (isPending)
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _processLeave(req, 'Rejected'),
                        icon: const Icon(Icons.close, size: 14),
                        label: Text('Reject', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _processLeave(req, 'Approved'),
                        icon: const Icon(Icons.check, size: 14),
                        label: Text('Approve', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  )
                else
                  _buildStatusBadge(req.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _safeFormatDate(String dateStr, String fmt) {
    try {
      return DateFormat(fmt).format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'Approved':
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case 'Rejected':
        color = Colors.red;
        icon = Icons.cancel_outlined;
        break;
      default:
        color = Colors.orange;
        icon = Icons.hourglass_top_outlined;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
