import 'dart:convert';
import '../services/api_service.dart';

class ExamSchedule {
  final String id;
  final String className;
  final String section;
  final String subjectName;
  final String examDate; // YYYY-MM-DD
  final String startTime;
  final String endTime;
  final String venue;

  ExamSchedule({
    required this.id,
    required this.className,
    required this.section,
    required this.subjectName,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.venue,
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
      };

  factory ExamSchedule.fromJson(Map<String, dynamic> json) {
    return ExamSchedule(
      id: json['id'] ?? '',
      className: json['className'] ?? '',
      section: json['section'] ?? '',
      subjectName: json['subjectName'] ?? '',
      examDate: json['examDate'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      venue: json['venue'] ?? '',
    );
  }
}

class ExamService {
  static Future<void> createExam({
    required String className,
    required String section,
    required String subjectName,
    required String examDate,
    required String startTime,
    required String endTime,
    required String venue,
  }) async {
    await ApiService.createExam(
      className: className,
      section: section,
      subjectName: subjectName,
      examDate: examDate,
      startTime: startTime,
      endTime: endTime,
      venue: venue,
    );
  }

  static Future<void> deleteExam(String id) async {
    await ApiService.deleteExam(id);
  }

  static Future<List<ExamSchedule>> getExamsForClass(String className, String section) async {
    final list = await ApiService.getExamsForClass(className, section);
    return list
        .map((e) => ExamSchedule.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.examDate.compareTo(b.examDate));
  }
}
