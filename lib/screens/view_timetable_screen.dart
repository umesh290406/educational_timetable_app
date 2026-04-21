import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lecture_provider.dart';
import '../providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ViewTimetableScreen extends StatefulWidget {
  final String className;
  final String section;

  const ViewTimetableScreen({
    super.key,
    required this.className,
    required this.section,
  });

  @override
  State<ViewTimetableScreen> createState() => _ViewTimetableScreenState();
}

class _ViewTimetableScreenState extends State<ViewTimetableScreen> {
  final List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];

  late String _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = 'Monday';
    _loadTimetable();
  }

  void _loadTimetable() {
    Future.microtask(() {
      Provider.of<LectureProvider>(context, listen: false)
          .getTimetable(widget.className);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        title: Text(
          '📅 Weekly Timetable',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Day selector
          Container(
            color: Colors.teal.shade50,
            padding: EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: days.map((day) {
                  final isSelected = _selectedDay == day;
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedDay = day;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? Colors.teal.shade600
                            : Colors.white,
                        foregroundColor:
                            isSelected ? Colors.white : Colors.teal,
                        side: BorderSide(
                          color: isSelected
                              ? Colors.teal.shade600
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        day.substring(0, 3),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Lectures for selected day
          Expanded(
            child: Consumer<LectureProvider>(
              builder: (context, lectureProvider, _) {
                if (lectureProvider.isLoading) {
                  return Center(child: CircularProgressIndicator());
                }

                // Filter timetable entries by selected day
                final entriesForDay = lectureProvider.timetableEntries
                    .where((entry) => entry.day == _selectedDay)
                    .toList();

                // Sort chronologically (8, 9, 10, 11, 12, 1, 2...)
                entriesForDay.sort((a, b) {
                  int parseTime(String t) {
                    try {
                      t = t.trim();
                      try {
                        final d = DateFormat('h:mm a').parse(t);
                        return d.hour * 60 + d.minute;
                      } catch (_) {}
                      try {
                        final d = DateFormat('H:mm').parse(t);
                        return d.hour * 60 + d.minute;
                      } catch (_) {}
                      
                      final clean = t.replaceAll(RegExp(r'[^0-9:]'), '').trim();
                      final parts = clean.split(':');
                      if (parts.isEmpty || parts[0].isEmpty) return 0;
                      int h = int.parse(parts[0]);
                      int m = parts.length > 1 ? int.parse(parts[1]) : 0;
                      if (h >= 1 && h <= 7 && !t.toLowerCase().contains('am')) h += 12;
                      return h * 60 + m;
                    } catch (_) {
                      return 0;
                    }
                  }
                  return parseTime(a.startTime).compareTo(parseTime(b.startTime));
                });

                if (entriesForDay.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_note,
                          size: 80,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'No lectures on $_selectedDay',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(12),
                  itemCount: entriesForDay.length,
                  itemBuilder: (context, index) {
                    final entry = entriesForDay[index];

                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border(
                            left: BorderSide(
                              color: _getColorForSubject(entry.subjectName),
                              width: 6,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Subject name
                                    Text(
                                      entry.subjectName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 12),

                                    // Teacher
                                    Row(
                                      children: [
                                        Icon(Icons.person,
                                            size: 18, color: Colors.grey),
                                        SizedBox(width: 8),
                                        Text(
                                          entry.teacherName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10),

                                    // Time
                                    Row(
                                      children: [
                                        Icon(Icons.schedule,
                                            size: 18, color: Colors.teal),
                                        SizedBox(width: 8),
                                        Text(
                                          '${entry.startTime} - ${entry.endTime}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10),

                                    // Room
                                    Row(
                                      children: [
                                        Icon(Icons.door_front_door,
                                            size: 18, color: Colors.orange),
                                        SizedBox(width: 8),
                                        Text(
                                          'Room ${entry.roomNumber}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (entry.isCancelled) ...[
                                      SizedBox(height: 12),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '❌ Cancelled',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                if (auth.user?.role == 'teacher') {
                                  return IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _confirmDelete(context, entry.id),
                                  );
                                }
                                return SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Entry'),
        content: Text('Remove this entry from the weekly timetable?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await Provider.of<LectureProvider>(context, listen: false).deleteTimetable(id);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getColorForSubject(String subject) {
    final colors = {
      'Mathematics': Colors.teal,
      'English': Colors.green,
      'Science': Colors.purple,
      'History': Colors.orange,
      'IT': Colors.red,
      'Chemistry': Colors.teal,
    };

    return colors[subject] ?? Colors.teal;
  }
}
