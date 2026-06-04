import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ExamSchedule {
  final String id;
  final String className;
  final String section;
  final String subjectName;
  final String examDate; // YYYY-MM-DD
  final String startTime;
  final String endTime;
  final String venue;
  final Map<String, String> attendance; // rollNo -> 'Present'/'Absent'/'Not Marked'

  ExamSchedule({
    required this.id,
    required this.className,
    required this.section,
    required this.subjectName,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.venue,
    required this.attendance,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'className': className,
        'section': section,
        'subjectName': subjectName,
        'examDate': examDate,
        'startTime': startTime,
        'endTime': endTime,
        'venue': venue,
        'attendance': attendance,
      };

  factory ExamSchedule.fromJson(Map<String, dynamic> json) {
    // Cast attendance map safely
    final Map<String, String> attMap = {};
    if (json['attendance'] != null) {
      (json['attendance'] as Map<dynamic, dynamic>).forEach((key, value) {
        attMap[key.toString()] = value.toString();
      });
    }

    return ExamSchedule(
      id: json['id'] ?? '',
      className: json['className'] ?? '',
      section: json['section'] ?? '',
      subjectName: json['subjectName'] ?? '',
      examDate: json['examDate'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      venue: json['venue'] ?? '',
      attendance: attMap,
    );
  }

  ExamSchedule copyWith({
    Map<String, String>? attendance,
  }) {
    return ExamSchedule(
      id: id,
      className: className,
      section: section,
      subjectName: subjectName,
      examDate: examDate,
      startTime: startTime,
      endTime: endTime,
      venue: venue,
      attendance: attendance ?? this.attendance,
    );
  }
}

class ExamService {
  static const String _key = 'exam_schedules_v1';

  static Future<List<ExamSchedule>> getAllExams() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((e) => ExamSchedule.fromJson(e)).toList();
  }

  static Future<void> saveAllExams(List<ExamSchedule> exams) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(exams.map((e) => e.toJson()).toList());
    await prefs.setString(_key, data);
  }

  static Future<void> createExam({
    required String className,
    required String section,
    required String subjectName,
    required String examDate,
    required String startTime,
    required String endTime,
    required String venue,
  }) async {
    final exams = await getAllExams();
    final newExam = ExamSchedule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      className: className,
      section: section,
      subjectName: subjectName,
      examDate: examDate,
      startTime: startTime,
      endTime: endTime,
      venue: venue,
      attendance: {},
    );
    exams.add(newExam);
    await saveAllExams(exams);
  }

  static Future<void> deleteExam(String id) async {
    final exams = await getAllExams();
    exams.removeWhere((e) => e.id == id);
    await saveAllExams(exams);
  }

  static Future<List<ExamSchedule>> getExamsForClass(String className, String section) async {
    final exams = await getAllExams();
    return exams
        .where((e) =>
            e.className.toLowerCase() == className.toLowerCase() &&
            e.section.toLowerCase() == section.toLowerCase())
        .toList()
      ..sort((a, b) => a.examDate.compareTo(b.examDate));
  }

  static Future<void> markExamAttendance({
    required String examId,
    required Map<String, String> attendance,
  }) async {
    final exams = await getAllExams();
    final index = exams.indexWhere((e) => e.id == examId);
    if (index != -1) {
      final updatedAttendance = Map<String, String>.from(exams[index].attendance)..addAll(attendance);
      exams[index] = exams[index].copyWith(attendance: updatedAttendance);
      await saveAllExams(exams);
    }
  }
}
