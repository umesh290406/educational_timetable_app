import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _key = 'student_leaves_v1';

  static Future<List<LeaveRequest>> getAllLeaves() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((e) => LeaveRequest.fromJson(e)).toList();
  }

  static Future<void> saveAllLeaves(List<LeaveRequest> leaves) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(leaves.map((e) => e.toJson()).toList());
    await prefs.setString(_key, data);
  }

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
    final leaves = await getAllLeaves();
    final newRequest = LeaveRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      studentEmail: studentEmail,
      studentName: studentName,
      rollNo: rollNo,
      className: className,
      section: section,
      reason: reason,
      startDate: startDate,
      endDate: endDate,
      status: 'Pending',
      comment: '',
      appliedAt: DateTime.now().toIso8601String(),
    );
    leaves.add(newRequest);
    await saveAllLeaves(leaves);
  }

  static Future<void> updateLeaveStatus({
    required String id,
    required String status,
    required String comment,
  }) async {
    final leaves = await getAllLeaves();
    final index = leaves.indexWhere((e) => e.id == id);
    if (index != -1) {
      leaves[index] = leaves[index].copyWith(status: status, comment: comment);
      await saveAllLeaves(leaves);
    }
  }

  static Future<List<LeaveRequest>> getLeavesForStudent(String email) async {
    final leaves = await getAllLeaves();
    return leaves.where((e) => e.studentEmail.toLowerCase() == email.toLowerCase()).toList()
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
  }

  static Future<List<LeaveRequest>> getLeavesForTeacher(String className, String section) async {
    final leaves = await getAllLeaves();
    return leaves.where((e) => 
      e.className.toLowerCase() == className.toLowerCase() &&
      e.section.toLowerCase() == section.toLowerCase()
    ).toList()
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
  }
}
