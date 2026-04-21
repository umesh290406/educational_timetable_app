import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lecture_provider.dart';
import '../services/reminder_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'add_lecture_screen.dart'; // reuse dropdown constants

class ScheduleReminderScreen extends StatefulWidget {
  final String lectureId;
  final String lectureName;
  final String startTime;
  final String endTime;
  final String className;
  final String section;

  const ScheduleReminderScreen({
    super.key,
    required this.lectureId,
    required this.lectureName,
    required this.startTime,
    required this.endTime,
    required this.className,
    required this.section,
  });

  @override
  State<ScheduleReminderScreen> createState() =>
      _ScheduleReminderScreenState();
}

class _ScheduleReminderScreenState extends State<ScheduleReminderScreen> {
  String _selectedReminder = '30min';
  bool _isScheduling = false;

  // Dropdowns — pre-filled from parent, but overridable
  late String? _selectedSubject;
  late String? _selectedClass;
  late String? _selectedSection;

  @override
  void initState() {
    super.initState();
    // Pre-fill with values passed from the lecture card
    _selectedSubject =
        kSubjects.contains(widget.lectureName) ? widget.lectureName : null;
    _selectedClass =
        kClasses.contains(widget.className) ? widget.className : null;
    _selectedSection =
        kSections.contains(widget.section) ? widget.section : null;
  }

  Future<DateTime> _parseTime(String timeStr) async {
    try {
      // Try "h:mm a" format first (from time picker)
      final parsed = DateFormat('h:mm a').parse(timeStr);
      final now = DateTime.now();
      var scheduled =
          DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      return scheduled;
    } catch (_) {}

    // Fallback: "HH:mm" format
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final now = DateTime.now();
    var scheduled =
        DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> _scheduleReminder() async {
    // Validate dropdowns
    if (_selectedSubject == null ||
        _selectedClass == null ||
        _selectedSection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select subject, class, and section'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isScheduling = true);

    try {
      final lectureTime = await _parseTime(widget.startTime);
      DateTime reminderTime;

      if (_selectedReminder == '1day') {
        reminderTime = lectureTime.subtract(const Duration(days: 1));
      } else if (_selectedReminder == '1hour') {
        reminderTime = lectureTime.subtract(const Duration(hours: 1));
      } else {
        reminderTime = lectureTime.subtract(const Duration(minutes: 30));
      }

      final now = DateTime.now();
      if (reminderTime.isBefore(now)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reminder time is in the past! Pick a future time.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isScheduling = false);
        return;
      }

      // Schedule local notification for teacher (skipped on web)
      await ReminderService.scheduleNotification(
        id: widget.lectureId.hashCode,
        title: '⏰ Reminder: ${_selectedSubject!}',
        body: 'Your class starts at ${widget.startTime}',
        scheduledDate: reminderTime,
        payload: widget.lectureId,
      );

      // Push notification to all students in the class via backend
      if (mounted) {
        await Provider.of<LectureProvider>(context, listen: false)
            .scheduleNotificationForClass(
          lectureId: widget.lectureId,
          title: 'Upcoming Lecture: ${_selectedSubject!}',
          message:
              'Your lecture starts at ${widget.startTime} | Class: ${_selectedClass!} ${_selectedSection!}',
          notificationType: 'reminder',
          className: _selectedClass!,
          section: _selectedSection!,
          scheduledDate: reminderTime.toUtc(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Reminder set for ${DateFormat('MMM d, h:mm a').format(reminderTime)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isScheduling = false);
  }

  // ── Reusable styled dropdown ───────────────────────────────────────────────
  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
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
            'Select $label',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Schedule Reminder',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Lecture Info Card ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.teal.shade600,
                    Colors.teal.shade400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.book, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.lectureName.isNotEmpty
                              ? widget.lectureName
                              : 'New Reminder',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.startTime.isNotEmpty)
                          Text(
                            '${widget.startTime} – ${widget.endTime}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Subject Dropdown ───────────────────────────────────────────
            _buildDropdown<String>(
              label: 'Subject Name',
              icon: Icons.subject,
              value: _selectedSubject,
              items: kSubjects,
              onChanged: (v) => setState(() => _selectedSubject = v),
            ),
            const SizedBox(height: 16),

            // ── Class & Section Row ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _buildDropdown<String>(
                    label: 'Class',
                    icon: Icons.class_,
                    value: _selectedClass,
                    items: kClasses,
                    onChanged: (v) => setState(() => _selectedClass = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown<String>(
                    label: 'Section',
                    icon: Icons.apps,
                    value: _selectedSection,
                    items: kSections,
                    onChanged: (v) =>
                        setState(() => _selectedSection = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── When to remind ────────────────────────────────────────────
            Text(
              'When should we remind students?',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 14),

            _buildReminderOption(
              title: '📅 1 Day Before',
              subtitle: 'Reminder 24 hours before the lecture',
              value: '1day',
            ),
            const SizedBox(height: 10),
            _buildReminderOption(
              title: '⏰ 1 Hour Before',
              subtitle: 'Reminder 60 minutes before class',
              value: '1hour',
            ),
            const SizedBox(height: 10),
            _buildReminderOption(
              title: '⏱️ 30 Minutes Before',
              subtitle: 'Recommended — 30 minutes before class',
              value: '30min',
            ),
            const SizedBox(height: 36),

            // ── Schedule Button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isScheduling ? null : _scheduleReminder,
                icon: _isScheduling
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.notifications_active),
                label: Text(
                  _isScheduling ? 'Scheduling...' : 'Set Reminder',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
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
    );
  }

  Widget _buildReminderOption({
    required String title,
    required String subtitle,
    required String value,
  }) {
    final isSelected = _selectedReminder == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selectedReminder = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.purple.shade400 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? Colors.purple.shade50 : Colors.white,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _selectedReminder,
              onChanged: (v) => setState(() => _selectedReminder = v ?? '30min'),
              activeColor: Colors.purple,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.purple.shade700
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
