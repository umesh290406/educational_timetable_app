import 'package:flutter/material.dart';
import '../models/lecture_model.dart';
import '../models/timetable_model.dart';
import '../services/api_service.dart';

class LectureProvider with ChangeNotifier {
  List<Lecture> _lectures = [];
  List<Timetable> _timetableEntries = [];
  List<dynamic> _notifications = [];
  bool _isLoading = false;
  String? _error;

  List<Lecture> get lectures => _lectures;
  List<Timetable> get timetableEntries => _timetableEntries;

  List<dynamic> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> getStudentLectures() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _lectures = await ApiService.getStudentLectures();
    } catch (e) {
      _lectures = [];
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> getTeacherLectures() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _lectures = await ApiService.getTeacherLectures();
    } catch (e) {
      _lectures = [];
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> getStudentNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _notifications = await ApiService.getStudentNotifications();
    } catch (e) {
      _notifications = [];
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final res = await ApiService.markNotificationAsRead(notificationId);
      if (res['success'] == true) {
        // Update local list
        final index = _notifications.indexWhere((n) => n['_id'] == notificationId || n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['isRead'] = true;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> cancelLecture({required String lectureId, required String reason}) async {
    try {
      final res = await ApiService.cancelLecture(lectureId: lectureId, reason: reason);
      if (res['success'] == true) {
        _lectures.removeWhere((l) => l.id == lectureId);
        notifyListeners();
        return true;
      }
      _error = res['message'];
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> sendNotification({
    required String lectureId,
    required String title,
    required String message,
    required String notificationType,
    required String className,
    required String section,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.sendNotification(
        lectureId: lectureId,
        title: title,
        message: message,
        notificationType: notificationType,
        className: className,
        section: section,
      );
      _isLoading = false;
      if (res['success'] == true) {
        notifyListeners();
        return true;
      } else {
        _error = res['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> createLecture({
    required String subjectName,
    required String teacherName,
    required String className,
    required String section,
    required String startTime,
    required String endTime,
    required String roomNumber,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.createLecture(
        subjectName: subjectName,
        teacherName: teacherName,
        className: className,
        section: section,
        startTime: startTime,
        endTime: endTime,
        roomNumber: roomNumber,
      );
      _isLoading = false;
      if (res['success'] == true) {
        notifyListeners();
        return res;
      } else {
        _error = res['message'];
        notifyListeners();
        return res;
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> scheduleNotificationForClass({
    required String lectureId,
    required String title,
    required String message,
    required String notificationType,
    required String className,
    required String section,
    required DateTime scheduledDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.scheduleNotification(
        lectureId: lectureId,
        title: title,
        message: message,
        notificationType: notificationType,
        className: className,
        section: section,
        scheduledAt: scheduledDate.toIso8601String(),
      );
      _isLoading = false;
      if (res['success'] == true) {
        notifyListeners();
        return true;
      } else {
        _error = res['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> createTimetable({
    required String subjectName,
    required String teacherName,
    required String className,
    required String section,
    required String day,
    required String startTime,
    required String endTime,
    required String roomNumber,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.createTimetable(
        subjectName: subjectName,
        teacherName: teacherName,
        className: className,
        section: section,
        day: day,
        startTime: startTime,
        endTime: endTime,
        roomNumber: roomNumber,
      );
      _isLoading = false;
      if (res['success'] == true) {
        notifyListeners();
        return true;
      } else {
        _error = res['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> getTimetable(String className) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiService.getTimetableByClass(className);
      _timetableEntries = data.map((json) => Timetable.fromJson(json)).toList();
    } catch (e) {
      _timetableEntries = [];
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> getTeacherTimetable() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Fetch both recurring entries and one-off lectures
      final timetableData = await ApiService.getTeacherTimetable();
      _timetableEntries = timetableData.map((json) => Timetable.fromJson(json)).toList();
      
      final lectureData = await ApiService.getTeacherLectures();
      _lectures = lectureData; // ApiService already converts to List<Lecture>
      
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }
  Future<void> getTeacherNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _notifications = await ApiService.getTeacherNotifications();
    } catch (e) {
      _notifications = [];
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> deleteNotification(String id) async {
    try {
      final res = await ApiService.deleteNotification(id);
      if (res['success'] == true) {
        _notifications.removeWhere((n) => n['id'] == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTimetable(String timetableId) async {
    try {
      final res = await ApiService.deleteTimetable(timetableId);
      if (res['success'] == true) {
        _timetableEntries.removeWhere((e) => e.id == timetableId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}