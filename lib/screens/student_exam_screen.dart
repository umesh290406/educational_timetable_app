import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/exam_service.dart';
import '../providers/auth_provider.dart';
import '../utils/download_helper.dart';
import '../widgets/loading_widget.dart';

class StudentExamScreen extends StatefulWidget {
  const StudentExamScreen({super.key});

  @override
  State<StudentExamScreen> createState() => _StudentExamScreenState();
}

class _StudentExamScreenState extends State<StudentExamScreen> {
  List<ExamSchedule> _exams = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final className = authProvider.user?.className ?? 'SE';
    final section = authProvider.user?.section ?? 'A';

    final exams = await ExamService.getExamsForClass(className, section);
    setState(() {
      _exams = exams;
      _isLoading = false;
    });
  }

  Future<void> _exportTimetable() async {
    if (_exams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No exam schedule to export'), backgroundColor: Colors.orange),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final className = authProvider.user?.className ?? 'SE';
    final section = authProvider.user?.section ?? 'A';

    // Format content as CSV
    final buffer = StringBuffer();
    buffer.writeln('Subject,Date,Start Time,End Time,Venue');
    for (final exam in _exams) {
      buffer.writeln(
        '"${exam.subjectName}","${exam.examDate}","${exam.startTime}","${exam.endTime}","${exam.venue}"',
      );
    }

    final csvContent = buffer.toString();
    final fileName = 'Exam_Schedule_${className}_$section.csv';

    final downloaded = await DownloadHelper.downloadTimetable(
      fileName: fileName,
      content: csvContent,
    );

    if (mounted) {
      if (downloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded exam timetable: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Timetable Copied',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'The exam timetable has been formatted and copied to your clipboard. '
              'You can now paste and share it anywhere.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(color: Colors.teal.shade600, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final className = authProvider.user?.className ?? 'SE';
    final section = authProvider.user?.section ?? 'A';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade600,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exam Schedule',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            Text(
              'Class: $className - Section: $section',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Export Timetable',
            onPressed: _exportTimetable,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading exam schedule...')
          : _exams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No exams scheduled yet',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your teachers haven\'t published any exam schedule.',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.teal.shade600.withOpacity(0.08),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Upcoming Exams (${_exams.length})',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.teal.shade700,
                            ),
                            onPressed: _exportTimetable,
                            icon: const Icon(Icons.download, size: 16),
                            label: Text(
                              'Download Schedule',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2), // Subject
                            1: FlexColumnWidth(2), // Date
                            2: FlexColumnWidth(2), // Timing
                            3: FlexColumnWidth(1.5), // Venue
                          },
                          border: TableBorder.all(
                            color: Colors.grey.shade300,
                            width: 1,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          children: [
                            // Header Row
                            TableRow(
                              decoration: BoxDecoration(
                                color: Colors.teal.shade600.withOpacity(0.12),
                              ),
                              children: [
                                _buildHeaderCell('Subject'),
                                _buildHeaderCell('Date'),
                                _buildHeaderCell('Timing'),
                                _buildHeaderCell('Venue'),
                              ],
                            ),
                            // Data Rows
                            ..._exams.map((exam) {
                              return TableRow(
                                children: [
                                  _buildDataCell(exam.subjectName, isBold: true),
                                  _buildDataCell(exam.examDate),
                                  _buildDataCell('${exam.startTime}\n-\n${exam.endTime}'),
                                  _buildDataCell(exam.venue),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.teal.shade800,
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
