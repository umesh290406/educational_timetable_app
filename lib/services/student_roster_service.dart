import 'dart:convert';
import '../services/api_service.dart';
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
  static Future<List<StudentProfile>> getAllStudents() async {
    // This method is less useful with backend, but kept for compatibility
    // In practice, callers should use getStudentsForClass
    return [];
  }

  static Future<List<StudentProfile>> getStudentsForClass(String className, String section) async {
    final list = await ApiService.getRoster(className, section);
    final filtered = list
        .map((e) => StudentProfile.fromJson(e as Map<String, dynamic>))
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
    await ApiService.saveStudentToRoster(
      rollNo: student.rollNo,
      name: student.name,
      className: student.className,
      section: student.section,
      address: student.address,
      contactNo: student.contactNo,
      parentsNo: student.parentsNo,
      birthday: student.birthday,
    );
  }

  static Future<void> deleteStudent({
    required String className,
    required String section,
    required String rollNo,
  }) async {
    await ApiService.deleteStudentFromRoster(className, section, rollNo);
  }
}
