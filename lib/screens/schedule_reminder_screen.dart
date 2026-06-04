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

  // Subject as free text
  final _subjectController = TextEditingController();

  // Chip selections — pre-filled from parent
  String? _selectedClass;
  String? _selectedSection;

  @override
  void initState() {
    super.initState();
    _subjectController.text = widget.lectureName;
    _selectedClass = kClasses.contains(widget.className) ? widget.className : null;
    _selectedSection = kSections.contains(widget.section) ? widget.section : null;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
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
    final subject = _subjectController.text.trim();
    if (subject.isEmpty || _selectedClass == null || _selectedSection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter subject and select class & section'),
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
        title: '⏰ Reminder: $subject',
        body: 'Your class starts at ${widget.startTime}',
        scheduledDate: reminderTime,
        payload: widget.lectureId,
      );

      if (mounted) {
        await Provider.of<LectureProvider>(context, listen: false)
            .scheduleNotificationForClass(
          lectureId: widget.lectureId,
          title: 'Upcoming Lecture: $subject',
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

            // ── Subject TextField ──────────────────────────────────────────
            Text(
              'Subject Name',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subjectController,
              maxLength: 50,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                hintText: 'e.g. DBMS, Mathematics, OS...',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                prefixIcon: Icon(Icons.subject, color: Colors.teal.shade600, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.teal.shade400, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                counterStyle: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),

            // ── Class Chips ────────────────────────────────────────────────
            Text('Class', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: kClasses.map((cls) {
                final isSelected = _selectedClass == cls;
                return ChoiceChip(
                  label: Text(cls),
                  selected: isSelected,
                  selectedColor: Colors.teal.shade600,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSelected ? Colors.white : Colors.teal.shade900,
                  ),
                  onSelected: (_) => setState(() => _selectedClass = cls),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Section Chips ──────────────────────────────────────────────
            Text('Section / Division', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: kSections.map((sec) {
                final isSelected = _selectedSection == sec;
                return ChoiceChip(
                  label: Text('Div $sec'),
                  selected: isSelected,
                  selectedColor: Colors.teal.shade600,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSelected ? Colors.white : Colors.teal.shade900,
                  ),
                  onSelected: (_) => setState(() => _selectedSection = sec),
                );
              }).toList(),
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
            color: isSelected ? Colors.purple.shade400 : Colors.grey.shade400,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? Colors.purple.withOpacity(0.15) : Theme.of(context).cardColor,
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
                          ? Colors.purple.shade300
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
