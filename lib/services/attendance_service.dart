import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AttendanceStudent {
  final String rollNo;
  final String name;

  AttendanceStudent({required this.rollNo, required this.name});

  Map<String, dynamic> toJson() => {
        'rollNo': rollNo,
        'name': name,
      };

  factory AttendanceStudent.fromJson(Map<String, dynamic> json) {
    return AttendanceStudent(
      rollNo: json['rollNo']?.toString() ?? '',
      name: json['name'] ?? '',
    );
  }
}

class AttendanceRecord {
  final String id;
  final String rollNo;
  final String studentName;
  final String subjectName;
  final String date; // YYYY-MM-DD
  final String status; // 'Present' or 'Absent'
  final String className;
  final String section;

  AttendanceRecord({
    required this.id,
    required this.rollNo,
    required this.studentName,
    required this.subjectName,
    required this.date,
    required this.status,
    required this.className,
    required this.section,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'rollNo': rollNo,
        'studentName': studentName,
        'subjectName': subjectName,
        'date': date,
        'status': status,
        'className': className,
        'section': section,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] ?? '',
      rollNo: json['rollNo']?.toString() ?? '',
      studentName: json['studentName'] ?? '',
      subjectName: json['subjectName'] ?? '',
      date: json['date'] ?? '',
      status: json['status'] ?? 'Present',
      className: json['className'] ?? '',
      section: json['section'] ?? '',
    );
  }
}

class AttendanceService {
  static const String _studentRollKey = 'student_roll_no_v1';
  static const String _teacherIdKey = 'teacher_id_no_v1';

  // Get saved Teacher ID per email (local preference — not migrated)
  static Future<String?> getSavedTeacherId(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_teacherIdKey}_${email.trim().toLowerCase()}');
  }

  // Save Teacher ID per email (local preference — not migrated)
  static Future<void> saveTeacherId(String email, String teacherId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_teacherIdKey}_${email.trim().toLowerCase()}', teacherId.trim());
  }

  // Get saved Student Roll Number per email (local preference — not migrated)
  static Future<String?> getSavedRollNo(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_studentRollKey}_${email.trim().toLowerCase()}');
  }

  // Register a student globally (now saves to backend roster)
  static Future<void> registerStudent({
    required String email,
    required String name,
    required String rollNo,
    required String className,
    required String section,
  }) async {
    await ApiService.saveStudentToRoster(
      rollNo: rollNo,
      name: name,
      className: className,
      section: section,
    );
  }

  // Save Student Roll Number per email and register globally
  static Future<void> saveRollNo(String email, String rollNo, {String? name, String? className, String? section}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_studentRollKey}_${email.trim().toLowerCase()}', rollNo.trim());
    
    if (name != null && className != null && section != null) {
      await registerStudent(
        email: email,
        name: name,
        rollNo: rollNo,
        className: className,
        section: section,
      );
    }
  }

  // Get student roster matching class and section from backend
  static Future<List<AttendanceStudent>> getRoster(String className, String section) async {
    final list = await ApiService.getRoster(className, section);
    final List<AttendanceStudent> roster = list.map((e) {
      final map = e as Map<String, dynamic>;
      return AttendanceStudent(
        rollNo: map['rollNo']?.toString() ?? '',
        name: map['name'] ?? '',
      );
    }).toList();
    
    // Sort roster by roll number
    roster.sort((a, b) {
      final aInt = int.tryParse(a.rollNo) ?? 999;
      final bInt = int.tryParse(b.rollNo) ?? 999;
      return aInt.compareTo(bInt);
    });
    
    return roster;
  }

  // Legacy roster save method (kept for interface compatibility)
  static Future<void> saveRoster(String className, String section, List<AttendanceStudent> roster) async {
    for (final s in roster) {
      await ApiService.saveStudentToRoster(
        rollNo: s.rollNo,
        name: s.name,
        className: className,
        section: section,
      );
    }
  }

  // Add a student to the roster manually
  static Future<void> addStudentToRoster(String className, String section, AttendanceStudent student) async {
    await ApiService.saveStudentToRoster(
      rollNo: student.rollNo,
      name: student.name,
      className: className,
      section: section,
    );
  }

  // Save a batch of marked attendance records
  static Future<void> saveBatchAttendance(List<AttendanceRecord> newRecords) async {
    final records = newRecords.map((r) => {
      'rollNo': r.rollNo,
      'studentName': r.studentName,
      'subjectName': r.subjectName,
      'date': r.date,
      'status': r.status,
      'className': r.className,
      'section': r.section,
    }).toList();
    
    await ApiService.saveBatchAttendance(records);
  }

  // Get attendance stats for a specific student
  static Future<Map<String, dynamic>> getStudentStats(String rollNo, String className, String section) async {
    final result = await ApiService.getStudentAttendanceStats(rollNo, className, section);
    
    if (result['success'] != true) {
      return {
        'total': 0,
        'attended': 0,
        'missed': 0,
        'percentage': 0.0,
        'subjectStats': <String, Map<String, dynamic>>{},
        'history': <AttendanceRecord>[],
      };
    }

    final records = (result['records'] as List<dynamic>? ?? [])
        .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
        .toList();

    // Convert subjectStats from backend format
    final rawSubjectStats = result['subjectStats'] as Map<String, dynamic>? ?? {};
    final subjectStats = <String, Map<String, dynamic>>{};
    rawSubjectStats.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        subjectStats[key] = {
          'attended': value['attended'] ?? 0,
          'total': value['total'] ?? 0,
          'percentage': (value['percentage'] as num?)?.toDouble() ?? 0.0,
        };
      }
    });

    return {
      'total': result['total'] ?? 0,
      'attended': result['attended'] ?? 0,
      'missed': result['missed'] ?? 0,
      'percentage': (result['percentage'] as num?)?.toDouble() ?? 0.0,
      'subjectStats': subjectStats,
      'history': records,
    };
  }

  // Delete a specific marked attendance session/batch
  static Future<void> deleteAttendanceBatch({
    required String className,
    required String section,
    required String subjectName,
    required String date,
  }) async {
    await ApiService.deleteAttendanceBatch(
      className: className,
      section: section,
      subjectName: subjectName,
      date: date,
    );
  }

  // Get all unique marked attendance sessions for a class/section
  static Future<List<Map<String, String>>> getMarkedSessions(String className, String section) async {
    final list = await ApiService.getAttendanceSessions(className, section);
    return list.map((e) {
      final map = e as Map<String, dynamic>;
      return {
        'subject': map['subject']?.toString() ?? '',
        'date': map['date']?.toString() ?? '',
      };
    }).toList();
  }

  // Generate a complete class report card list for the teacher dashboard
  static Future<List<Map<String, dynamic>>> getClassReport(String className, String section) async {
    final roster = await getRoster(className, section);
    final recordsList = await ApiService.getAttendanceRecords(className, section);
    final allRecords = recordsList
        .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    
    final List<Map<String, dynamic>> report = [];
    
    for (final student in roster) {
      final studentRecords = allRecords.where((e) =>
          e.rollNo.trim() == student.rollNo.trim()).toList();

      if (studentRecords.isEmpty) {
        report.add({
          'rollNo': student.rollNo,
          'name': student.name,
          'total': 0,
          'attended': 0,
          'percentage': 0.0,
        });
      } else {
        final attended = studentRecords.where((e) => e.status == 'Present').length;
        final percentage = (attended / studentRecords.length) * 100;
        report.add({
          'rollNo': student.rollNo,
          'name': student.name,
          'total': studentRecords.length,
          'attended': attended,
          'percentage': percentage,
        });
      }
    }

    // Sort student records by roll number
    report.sort((a, b) {
      final aInt = int.tryParse(a['rollNo']?.toString() ?? '') ?? 999;
      final bInt = int.tryParse(b['rollNo']?.toString() ?? '') ?? 999;
      return aInt.compareTo(bInt);
    });
    
    return report;
  }
}
