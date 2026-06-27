import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/lecture_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  static const String baseUrl = 'https://timetable-backend-soc3.onrender.com';
  static String? _token;

  static final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Bypass-Tunnel-Reminder': 'true',
  };

  static void setToken(String token) {
    _token = token;
    _headers['Authorization'] = 'Bearer $token';
  }

  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token != null) setToken(token);
  }

  static Future<Map<String, dynamic>> login({
    required String emailOrUsername,
    required String password,
    required String role,
  }) async {
    try {
      String? fcmToken;
      if (!kIsWeb) {
        try {
          fcmToken = await FirebaseMessaging.instance.getToken();
        } catch (e) {
          print('Error getting FCM token: $e');
        }
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: _headers,
        body: jsonEncode({
          'email': emailOrUsername.trim(),
          'password': password.trim(),
          'role': role,
          'fcmToken': fcmToken,
        }),
      ).timeout(const Duration(seconds: 60));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['token'];
        setToken(token);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', token);
        
        return {
          'success': true,
          'user': User.fromJson(data['user']),
          'token': token
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed'
        };
      }
    } catch (e) {
      // If server returns error page, it won't be JSON, causing FORMAT EXCEPTION
      return {'success': false, 'message': 'Server is currently restarting. Please try again in 30 seconds. ($e)'};
    }
  }

  static Future<Map<String, dynamic>> register({
    required String emailOrUsername,
    required String name,
    required String password,
    required String role,
    String? className,
    String? section,
    String? specialization,
    String? college,
    String? phone,
  }) async {
    try {

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'identifier': emailOrUsername.trim(),
          'name': name,
          'password': password,
          'role': role,
          'className': className,
          'section': section,
          'specialization': specialization,
          'college': college,
          'phone': phone,
        }),
      ).timeout(const Duration(seconds: 60));


      final data = jsonDecode(response.body);
      if ((response.statusCode == 201 || response.statusCode == 200) && data['success'] == true) {
        final token = data['token'] ?? (data['user'] != null ? data['user']['token'] : null);
        if (token != null) {
          setToken(token);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('authToken', token);
        }
        return {'success': true, 'user': User.fromJson(data['user'])};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/users/me'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> recoverAccount(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/recover'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 60));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<Lecture>> getStudentLectures() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/lectures/student'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((l) => Lecture.fromJson(l)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Lecture>> getTeacherLectures() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/lectures/teacher'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((l) => Lecture.fromJson(l)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createLecture({
    required String subjectName,
    required String teacherName,
    required String className,
    required String section,
    required String startTime,
    required String endTime,
    required String roomNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/lectures/create'),
        headers: _headers,
        body: jsonEncode({
          'subjectName': subjectName,
          'teacherName': teacherName,
          'className': className,
          'section': section,
          'startTime': startTime,
          'endTime': endTime,
          'roomNumber': roomNumber,
        }),
      ).timeout(const Duration(seconds: 60));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> cancelLecture({
    required String lectureId,
    required String reason,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/lectures/$lectureId/cancel'),
        headers: _headers,
        body: jsonEncode({'cancellationReason': reason}),
      ).timeout(const Duration(seconds: 60));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> scheduleNotification({
    required String lectureId,
    required String title,
    required String message,
    required String notificationType,
    required String className,
    required String section,
    required String scheduledAt,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/schedule'),
        headers: _headers,
        body: jsonEncode({
          'lectureId': lectureId,
          'title': title,
          'message': message,
          'notificationType': notificationType,
          'className': className,
          'section': section,
          'scheduledAt': scheduledAt,
        }),
      ).timeout(const Duration(seconds: 60));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<dynamic>> getStudentNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications/student'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getTeacherNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications/teacher'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> markNotificationAsRead(String notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/notifications/$notificationId/read'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false};
    }
  }

  static Future<Map<String, dynamic>> deleteNotification(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/notifications/$id'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false};
    }
  }

  static Future<Map<String, dynamic>> createTimetable({
    required String subjectName,
    required String teacherName,
    required String className,
    required String section,
    required String day,
    required String startTime,
    required String endTime,
    required String roomNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/timetable/create'),
        headers: _headers,
        body: jsonEncode({
          'subjectName': subjectName,
          'teacherName': teacherName,
          'className': className,
          'section': section,
          'day': day,
          'startTime': startTime,
          'endTime': endTime,
          'roomNumber': roomNumber,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false};
    }
  }

  static Future<List<dynamic>> getTimetableByClass(String className) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/timetable/class/$className'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getTeacherTimetable() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/timetable/teacher'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> deleteTimetable(String timetableId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/timetable/$timetableId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false};
    }
  }

  static Future<Map<String, dynamic>> sendNotification({
    required String lectureId,
    required String title,
    required String message,
    required String notificationType,
    required String className,
    required String section,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/schedule'),
        headers: _headers,
        body: jsonEncode({
          'lectureId': lectureId,
          'title': title,
          'message': message,
          'notificationType': notificationType,
          'className': className,
          'section': section,
          'scheduledAt': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 60));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // STUDY MATERIALS / NOTES HUB
  // ==========================================

  static Future<Map<String, dynamic>> uploadStudyMaterial({
    required String title,
    required String description,
    required String className,
    String? section,
    String? specialization,
    required String filePath,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/materials/upload'));
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }

      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['className'] = className;
      if (section != null) request.fields['section'] = section;
      if (specialization != null) request.fields['specialization'] = specialization;

      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      var response = await http.Response.fromStream(streamedResponse);
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<dynamic>> getStudentMaterials(String className, String section, {String? specialization}) async {
    try {
      String url = '$baseUrl/api/materials/student/$className/$section';
      if (specialization != null && specialization.isNotEmpty) {
        url += '?specialization=${Uri.encodeComponent(specialization)}';
      }
      
      final response = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['materials'];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getTeacherMaterials() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/materials/teacher'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['materials'];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> deleteMaterial(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/materials/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // MESSAGING SYSTEM
  // ==========================================

  static Future<List<dynamic>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];
      final response = await http.get(
        Uri.parse('$baseUrl/api/messages/search?query=${Uri.encodeComponent(query)}'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data['users'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getConversations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/messages/conversations'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data['conversations'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getChatHistory(String otherUserId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/messages/$otherUserId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to load messages'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> sendMessage(String receiverId, String content) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/messages/send'),
        headers: _headers,
        body: jsonEncode({
          'receiverId': receiverId,
          'content': content,
        }),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> blockUser(String blockedId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/block'),
        headers: _headers,
        body: jsonEncode({'blockedId': blockedId}),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> unblockUser(String blockedId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/users/block/$blockedId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // VIRTUAL CLASSROOMS
  // ==========================================

  static Future<Map<String, dynamic>> createVirtualClass(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/virtual_classes'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<dynamic>> getTeacherVirtualClasses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/virtual_classes/teacher'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data['classes'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getStudentVirtualClasses(String className, String section, {String? specialization}) async {
    try {
      String url = '$baseUrl/api/virtual_classes/student/$className/$section';
      if (specialization != null && specialization.isNotEmpty) {
        url += '?specialization=${Uri.encodeComponent(specialization)}';
      }
      final response = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data['classes'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> deleteVirtualClass(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/virtual_classes/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // LEAVE MANAGEMENT
  // ==========================================

  static Future<Map<String, dynamic>> applyLeave({
    required String rollNo,
    required String reason,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/leaves'),
        headers: _headers,
        body: jsonEncode({
          'rollNo': rollNo,
          'reason': reason,
          'startDate': startDate,
          'endDate': endDate,
        }),
      ).timeout(const Duration(seconds: 30));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<dynamic>> getStudentLeaves() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/leaves/student'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data['leaves'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getTeacherLeaves(String className, String section, {String? specialization}) async {
    try {
      String url = '$baseUrl/api/leaves/teacher/${Uri.encodeComponent(className)}/${Uri.encodeComponent(section)}';
      if (specialization != null && specialization.isNotEmpty) {
        url += '?specialization=${Uri.encodeComponent(specialization)}';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data['leaves'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> updateLeaveStatus({
    required String id,
    required String status,
    required String comment,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/leaves/$id/status'),
        headers: _headers,
        body: jsonEncode({'status': status, 'comment': comment}),
      ).timeout(const Duration(seconds: 30));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // EXAM SCHEDULES
  // ==========================================

  static Future<Map<String, dynamic>> createExam({
    required String className,
    required String section,
    required String subjectName,
    required String examDate,
    required String startTime,
    required String endTime,
    required String venue,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/exams'),
        headers: _headers,
        body: jsonEncode({
          'className': className,
          'section': section,
          'subjectName': subjectName,
          'examDate': examDate,
          'startTime': startTime,
          'endTime': endTime,
          'venue': venue,
        }),
      ).timeout(const Duration(seconds: 30));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<dynamic>> getExamsForClass(String className, String section) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/exams/${Uri.encodeComponent(className)}/${Uri.encodeComponent(section)}'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data['exams'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> deleteExam(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/exams/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // STUDENT ROSTER
  // ==========================================

  static Future<Map<String, dynamic>> saveStudentToRoster({
    required String rollNo,
    required String name,
    required String className,
    required String section,
    String? address,
    String? contactNo,
    String? parentsNo,
    String? birthday,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/roster'),
        headers: _headers,
        body: jsonEncode({
          'rollNo': rollNo,
          'name': name,
          'className': className,
          'section': section,
          'address': address ?? '',
          'contactNo': contactNo ?? '',
          'parentsNo': parentsNo ?? '',
          'birthday': birthday ?? '',
        }),
      ).timeout(const Duration(seconds: 30));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<dynamic>> getRoster(String className, String section) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/roster/${Uri.encodeComponent(className)}/${Uri.encodeComponent(section)}'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data['students'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> deleteStudentFromRoster(String className, String section, String rollNo) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/roster/${Uri.encodeComponent(className)}/${Uri.encodeComponent(section)}/${Uri.encodeComponent(rollNo)}'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // ATTENDANCE
  // ==========================================

  static Future<Map<String, dynamic>> saveBatchAttendance(List<Map<String, dynamic>> records) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/attendance/batch'),
        headers: _headers,
        body: jsonEncode({'records': records}),
      ).timeout(const Duration(seconds: 60));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<dynamic>> getAttendanceRecords(String className, String section) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/attendance/${Uri.encodeComponent(className)}/${Uri.encodeComponent(section)}'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data['records'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getStudentAttendanceStats(String rollNo, String className, String section) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/attendance/student/${Uri.encodeComponent(rollNo)}/${Uri.encodeComponent(className)}/${Uri.encodeComponent(section)}'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteAttendanceBatch({
    required String className,
    required String section,
    required String subjectName,
    required String date,
  }) async {
    try {
      final request = http.Request('DELETE', Uri.parse('$baseUrl/api/attendance/batch'));
      request.headers.addAll(_headers);
      request.body = jsonEncode({
        'className': className,
        'section': section,
        'subjectName': subjectName,
        'date': date,
      });
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<dynamic>> getAttendanceSessions(String className, String section) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/attendance/sessions/${Uri.encodeComponent(className)}/${Uri.encodeComponent(section)}'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data['sessions'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> updateFcmToken(String fcmToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/fcm-token'),
        headers: _headers,
        body: jsonEncode({'fcmToken': fcmToken}),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
