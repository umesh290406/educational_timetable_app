import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _recordsKey = 'attendance_records_v1';
  static const String _studentRollKey = 'student_roll_no_v1';

  // Get saved Student Roll Number per email
  static Future<String?> getSavedRollNo(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_studentRollKey}_${email.trim().toLowerCase()}');
  }

  // Register a student globally
  static Future<void> registerStudent({
    required String email,
    required String name,
    required String rollNo,
    required String className,
    required String section,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('global_registered_students') ?? '[]';
    final List<dynamic> jsonList = jsonDecode(data);
    
    // Remove any existing entry with the same email or roll number in the same class/section
    jsonList.removeWhere((e) => 
      e['email']?.toString().toLowerCase() == email.toLowerCase() ||
      (e['rollNo']?.toString() == rollNo && 
       e['className']?.toString().toLowerCase() == className.toLowerCase() &&
       e['section']?.toString().toLowerCase() == section.toLowerCase())
    );
    
    jsonList.add({
      'email': email,
      'name': name,
      'rollNo': rollNo,
      'className': className,
      'section': section,
    });
    
    await prefs.setString('global_registered_students', jsonEncode(jsonList));
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

  // Get student roster matching class and section from global registry
  static Future<List<AttendanceStudent>> getRoster(String className, String section) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('global_registered_students') ?? '[]';
    final List<dynamic> jsonList = jsonDecode(data);
    
    final List<AttendanceStudent> roster = [];
    for (final e in jsonList) {
      if (e['className']?.toString().toLowerCase() == className.toLowerCase() &&
          e['section']?.toString().toLowerCase() == section.toLowerCase()) {
        roster.add(AttendanceStudent(
          rollNo: e['rollNo']?.toString() ?? '',
          name: e['name'] ?? '',
        ));
      }
    }
    
    // Sort roster by roll number
    roster.sort((a, b) {
      final aInt = int.tryParse(a.rollNo) ?? 999;
      final bInt = int.tryParse(b.rollNo) ?? 999;
      return aInt.compareTo(bInt);
    });
    
    return roster;
  }

  // Legacy roster save method (kept for interface compatibility but uses global registry)
  static Future<void> saveRoster(String className, String section, List<AttendanceStudent> roster) async {
    for (final s in roster) {
      await registerStudent(
        email: 'manual_roll_${s.rollNo}@class.com',
        name: s.name,
        rollNo: s.rollNo,
        className: className,
        section: section,
      );
    }
  }

  // Add a student to the roster manually
  static Future<void> addStudentToRoster(String className, String section, AttendanceStudent student) async {
    await registerStudent(
      email: 'manual_roll_${student.rollNo}@class.com',
      name: student.name,
      rollNo: student.rollNo,
      className: className,
      section: section,
    );
  }

  // Fetch all attendance records
  static Future<List<AttendanceRecord>> getAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_recordsKey);
    if (data == null) return [];
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((e) => AttendanceRecord.fromJson(e)).toList();
  }

  // Save all attendance records
  static Future<void> saveAllRecords(List<AttendanceRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(records.map((e) => e.toJson()).toList());
    await prefs.setString(_recordsKey, data);
  }

  // Save a batch of marked attendance records
  static Future<void> saveBatchAttendance(List<AttendanceRecord> newRecords) async {
    final allRecords = await getAllRecords();
    
    for (final newRec in newRecords) {
      // Avoid duplicates for the same student, subject, class, and date
      allRecords.removeWhere((e) =>
          e.rollNo == newRec.rollNo &&
          e.subjectName.toLowerCase() == newRec.subjectName.toLowerCase() &&
          e.className == newRec.className &&
          e.section == newRec.section &&
          e.date == newRec.date);
      allRecords.add(newRec);
    }
    
    await saveAllRecords(allRecords);
  }

  // Get attendance stats for a specific student
  static Future<Map<String, dynamic>> getStudentStats(String rollNo, String className, String section) async {
    final allRecords = await getAllRecords();
    
    // Filter records for this student
    final studentRecords = allRecords.where((e) =>
        e.rollNo.trim() == rollNo.trim() &&
        e.className.toLowerCase() == className.toLowerCase() &&
        e.section.toLowerCase() == section.toLowerCase()).toList();

    if (studentRecords.isEmpty) {
      return {
        'total': 0,
        'attended': 0,
        'missed': 0,
        'percentage': 0.0,
        'subjectStats': <String, Map<String, dynamic>>{},
        'history': <AttendanceRecord>[],
      };
    }

    final attended = studentRecords.where((e) => e.status == 'Present').length;
    final missed = studentRecords.length - attended;
    final percentage = (attended / studentRecords.length) * 100;

    // Subject breakdown
    final subjectStats = <String, Map<String, dynamic>>{};
    for (final rec in studentRecords) {
      if (!subjectStats.containsKey(rec.subjectName)) {
        subjectStats[rec.subjectName] = {'attended': 0, 'total': 0};
      }
      subjectStats[rec.subjectName]!['total'] = (subjectStats[rec.subjectName]!['total'] as int) + 1;
      if (rec.status == 'Present') {
        subjectStats[rec.subjectName]!['attended'] = (subjectStats[rec.subjectName]!['attended'] as int) + 1;
      }
    }

    // Calculate percentages for each subject
    subjectStats.forEach((key, value) {
      final subAttended = value['attended'] as int;
      final subTotal = value['total'] as int;
      value['percentage'] = (subAttended / subTotal) * 100;
    });

    // History sorted chronologically descending
    studentRecords.sort((a, b) => b.date.compareTo(a.date));

    return {
      'total': studentRecords.length,
      'attended': attended,
      'missed': missed,
      'percentage': percentage,
      'subjectStats': subjectStats,
      'history': studentRecords,
    };
  }

  // Delete a specific marked attendance session/batch
  static Future<void> deleteAttendanceBatch({
    required String className,
    required String section,
    required String subjectName,
    required String date,
  }) async {
    final allRecords = await getAllRecords();
    allRecords.removeWhere((e) =>
        e.className.toLowerCase() == className.toLowerCase() &&
        e.section.toLowerCase() == section.toLowerCase() &&
        e.subjectName.toLowerCase() == subjectName.toLowerCase() &&
        e.date == date);
    await saveAllRecords(allRecords);
  }

  // Get all unique marked attendance sessions for a class/section
  static Future<List<Map<String, String>>> getMarkedSessions(String className, String section) async {
    final allRecords = await getAllRecords();
    final Map<String, Map<String, String>> sessions = {};

    for (final rec in allRecords) {
      if (rec.className.toLowerCase() == className.toLowerCase() &&
          rec.section.toLowerCase() == section.toLowerCase()) {
        final key = '${rec.subjectName}_${rec.date}';
        sessions[key] = {
          'subject': rec.subjectName,
          'date': rec.date,
        };
      }
    }
    return sessions.values.toList()..sort((a, b) => b['date']!.compareTo(a['date']!));
  }

  // Generate a complete class report card list for the teacher dashboard
  static Future<List<Map<String, dynamic>>> getClassReport(String className, String section) async {
    final roster = await getRoster(className, section);
    final allRecords = await getAllRecords();
    
    final List<Map<String, dynamic>> report = [];
    
    for (final student in roster) {
      final studentRecords = allRecords.where((e) =>
          e.rollNo.trim() == student.rollNo.trim() &&
          e.className.toLowerCase() == className.toLowerCase() &&
          e.section.toLowerCase() == section.toLowerCase()).toList();

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
