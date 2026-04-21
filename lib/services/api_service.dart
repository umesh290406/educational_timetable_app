import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/lecture_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5001';
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
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: _headers,
        body: jsonEncode({
          'email': email.trim(),
          'password': password.trim(),
          'role': role,
        }),
      ).timeout(const Duration(seconds: 15));

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
    required String name,
    required String email,
    required String password,
    required String role,
    String? className,
    String? section,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          'className': className,
          'section': section,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        return {'success': true, 'user': User.fromJson(data['user'])};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<List<Lecture>> getStudentLectures() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/lectures/student'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

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
      ).timeout(const Duration(seconds: 15));

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
      ).timeout(const Duration(seconds: 15));

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
      ).timeout(const Duration(seconds: 15));
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
      ).timeout(const Duration(seconds: 15));
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
      ).timeout(const Duration(seconds: 15));
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
      ).timeout(const Duration(seconds: 15));
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
      ).timeout(const Duration(seconds: 15));
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
      ).timeout(const Duration(seconds: 15));
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
      ).timeout(const Duration(seconds: 15));
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
      ).timeout(const Duration(seconds: 15));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
