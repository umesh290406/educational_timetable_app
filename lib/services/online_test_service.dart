import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/online_test_model.dart';

class OnlineTestService {
  static const String _baseUrl = 'https://timetable-backend-soc3.onrender.com';

  static Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Teacher: create a test
  static Future<Map<String, dynamic>> createTest({
    required String title,
    required String instructions,
    required String className,
    String? section,
    String? specialization,
    required int durationMinutes,
    required List<Map<String, dynamic>> questions,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/tests'),
        headers: headers,
        body: jsonEncode({
          'title': title,
          'instructions': instructions,
          'className': className,
          'section': section,
          'specialization': specialization,
          'durationMinutes': durationMinutes,
          'questions': questions,
        }),
      ).timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Teacher: get their own tests
  static Future<List<OnlineTest>> getTeacherTests() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tests/teacher'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return (data['tests'] as List).map((j) => OnlineTest.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Student: get tests for their class
  static Future<List<OnlineTest>> getTestsForClass(String className, String section, {String? specialization}) async {
    try {
      final headers = await _authHeaders();
      final encodedClass = Uri.encodeComponent(className);
      final encodedSection = Uri.encodeComponent(section);
      final query = specialization != null && specialization.isNotEmpty
          ? '?specialization=${Uri.encodeComponent(specialization)}'
          : '';
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tests/class/$encodedClass/$encodedSection$query'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return (data['tests'] as List).map((j) => OnlineTest.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Get questions for a test
  static Future<Map<String, dynamic>> getTestQuestions(String testId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tests/$testId/questions'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return {
          'success': true,
          'test': OnlineTest.fromJson(data['test']),
          'questions': (data['questions'] as List).map((j) => TestQuestion.fromJson(j)).toList(),
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get attempts for a test (teacher)
  static Future<List<TestAttempt>> getTestAttempts(String testId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tests/$testId/attempts'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return (data['attempts'] as List).map((j) => TestAttempt.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Submit attempt (student)
  static Future<Map<String, dynamic>> submitAttempt({
    required String testId,
    required String studentName,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/tests/$testId/attempt'),
        headers: headers,
        body: jsonEncode({
          'studentName': studentName,
          'answers': answers,
        }),
      ).timeout(const Duration(seconds: 30));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Delete test (teacher)
  static Future<bool> deleteTest(String testId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/tests/$testId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
