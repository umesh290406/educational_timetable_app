import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'attendance_service.dart';

class StudentProfile {
  final String rollNo;
  final String name;
  final String className;
  final String section;
  final String address;
  final String contactNo;
  final String parentsNo;
  final String birthday;

  StudentProfile({
    required this.rollNo,
    required this.name,
    required this.className,
    required this.section,
    required this.address,
    required this.contactNo,
    required this.parentsNo,
    required this.birthday,
  });

  Map<String, dynamic> toJson() => {
        'rollNo': rollNo,
        'name': name,
        'className': className,
        'section': section,
        'address': address,
        'contactNo': contactNo,
        'parentsNo': parentsNo,
        'birthday': birthday,
      };

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      rollNo: json['rollNo']?.toString() ?? '',
      name: json['name'] ?? '',
      className: json['className'] ?? '',
      section: json['section'] ?? '',
      address: json['address'] ?? '',
      contactNo: json['contactNo']?.toString() ?? '',
      parentsNo: json['parentsNo']?.toString() ?? '',
      birthday: json['birthday'] ?? '',
    );
  }
}

class StudentRosterService {
  static const String _key = 'detailed_student_roster_v1';

  static Future<List<StudentProfile>> getAllStudents() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((e) => StudentProfile.fromJson(e)).toList();
  }

  static Future<void> saveAllStudents(List<StudentProfile> students) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(students.map((e) => e.toJson()).toList());
    await prefs.setString(_key, data);
  }

  static Future<List<StudentProfile>> getStudentsForClass(String className, String section) async {
    final students = await getAllStudents();
    final filtered = students
        .where((e) =>
            e.className.toLowerCase() == className.toLowerCase() &&
            e.section.toLowerCase() == section.toLowerCase())
        .toList();
    
    // Sort by roll number numerically if possible, otherwise alphabetically
    filtered.sort((a, b) {
      final aInt = int.tryParse(a.rollNo);
      final bInt = int.tryParse(b.rollNo);
      if (aInt != null && bInt != null) {
        return aInt.compareTo(bInt);
      }
      return a.rollNo.compareTo(b.rollNo);
    });
    return filtered;
  }

  static Future<void> saveStudent(StudentProfile student) async {
    final students = await getAllStudents();
    
    // Remove if already exists with same roll number, class and section
    students.removeWhere((e) =>
        e.rollNo == student.rollNo &&
        e.className.toLowerCase() == student.className.toLowerCase() &&
        e.section.toLowerCase() == student.section.toLowerCase());

    students.add(student);
    await saveAllStudents(students);

    // Sync with global registry in AttendanceService
    await AttendanceService.registerStudent(
      email: 'student_${student.rollNo}_${student.section.toLowerCase()}@school.com',
      name: student.name,
      rollNo: student.rollNo,
      className: student.className,
      section: student.section,
    );
  }

  static Future<void> deleteStudent({
    required String className,
    required String section,
    required String rollNo,
  }) async {
    final students = await getAllStudents();
    students.removeWhere((e) =>
        e.rollNo == rollNo &&
        e.className.toLowerCase() == className.toLowerCase() &&
        e.section.toLowerCase() == section.toLowerCase());
    await saveAllStudents(students);
  }
}
