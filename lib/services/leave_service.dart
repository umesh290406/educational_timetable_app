import 'dart:convert';
import '../services/api_service.dart';

class LeaveRequest {
  final String id;
  final String studentEmail;
  final String studentName;
  final String rollNo;
  final String className;
  final String section;
  final String reason;
  final String startDate; // YYYY-MM-DD
  final String endDate;   // YYYY-MM-DD
  final String status;    // 'Pending', 'Approved', 'Rejected'
  final String comment;   // Teacher comment
  final String appliedAt; // ISO Timestamp

  LeaveRequest({
    required this.id,
    required this.studentEmail,
    required this.studentName,
    required this.rollNo,
    required this.className,
    required this.section,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.comment,
    required this.appliedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'studentEmail': studentEmail,
    'studentName': studentName,
    'rollNo': rollNo,
    'className': className,
    'section': section,
    'reason': reason,
    'startDate': startDate,
    'endDate': endDate,
    'status': status,
    'comment': comment,
    'appliedAt': appliedAt,
  };

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'] ?? '',
      studentEmail: json['studentEmail'] ?? '',
      studentName: json['studentName'] ?? '',
      rollNo: json['rollNo']?.toString() ?? '',
      className: json['className'] ?? '',
      section: json['section'] ?? '',
      reason: json['reason'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      status: json['status'] ?? 'Pending',
      comment: json['comment'] ?? '',
      appliedAt: json['appliedAt'] ?? '',
    );
  }

  LeaveRequest copyWith({
    String? status,
    String? comment,
  }) {
    return LeaveRequest(
      id: id,
      studentEmail: studentEmail,
      studentName: studentName,
      rollNo: rollNo,
      className: className,
      section: section,
      reason: reason,
      startDate: startDate,
      endDate: endDate,
      status: status ?? this.status,
      comment: comment ?? this.comment,
      appliedAt: appliedAt,
    );
  }
}

class LeaveService {
  static Future<void> applyLeave({
    required String studentEmail,
    required String studentName,
    required String rollNo,
    required String className,
    required String section,
    required String reason,
    required String startDate,
    required String endDate,
  }) async {
    await ApiService.applyLeave(
      rollNo: rollNo,
      reason: reason,
      startDate: startDate,
      endDate: endDate,
    );
  }

  static Future<void> updateLeaveStatus({
    required String id,
    required String status,
    required String comment,
  }) async {
    await ApiService.updateLeaveStatus(
      id: id,
      status: status,
      comment: comment,
    );
  }

  static Future<List<LeaveRequest>> getLeavesForStudent(String email) async {
    final list = await ApiService.getStudentLeaves();
    return list.map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
  }

  static Future<List<LeaveRequest>> getLeavesForTeacher(String className, String section, {String? specialization}) async {
    final list = await ApiService.getTeacherLeaves(className, section, specialization: specialization);
    return list.map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
  }
}
