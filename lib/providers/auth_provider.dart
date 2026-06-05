import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;

  AuthProvider() {
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      final userData = prefs.getString('userData');

      if (token != null && userData != null) {
        ApiService.setToken(token);
        _user = User.fromJson(jsonDecode(userData));
        _isLoggedIn = true;
        notifyListeners();
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await ApiService.login(
        email: email,
        password: password,
        role: role,
      );

      if (result['success']) {
        _user = result['user'];
        _isLoggedIn = true;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(_user!.toJson()));
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? className,
    String? section,
    String? specialization,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await ApiService.register(
        name: name,
        email: email,
        password: password,
        role: role,
        className: className,
        section: section,
      );

      if (result['success']) {
        final apiUser = result['user'] as User;
        _user = User(
          id: apiUser.id,
          name: apiUser.name,
          email: apiUser.email,
          role: apiUser.role,
          className: apiUser.className,
          section: apiUser.section,
          specialization: specialization,
          token: apiUser.token,
        );
        _isLoggedIn = true;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(_user!.toJson()));
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateUserProfile({
    required String name,
    required String email,
    required String className,
    required String section,
    required String specialization,
  }) async {
    if (_user == null) return;
    
    _user = User(
      id: _user!.id,
      name: name.trim(),
      email: email.trim(),
      role: _user!.role,
      className: className.trim(),
      section: section.trim(),
      specialization: specialization.trim(),
      token: _user!.token,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  Future<void> updateTeacherProfile({
    required String name,
    required String email,
  }) async {
    if (_user == null) return;
    
    _user = User(
      id: _user!.id,
      name: name.trim(),
      email: email.trim(),
      role: _user!.role,
      className: _user!.className,
      section: _user!.section,
      specialization: _user!.specialization,
      token: _user!.token,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authToken');
      await prefs.remove('userData');
      
      final email = _user?.email;
      if (email != null) {
        await prefs.remove('student_roll_no_v1_${email.trim().toLowerCase()}');
        await prefs.remove('teacher_id_no_v1_${email.trim().toLowerCase()}');
      }

      _user = null;
      _isLoggedIn = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authToken');
      await prefs.remove('userData');
      
      _user = null;
      _isLoggedIn = false;
      notifyListeners();
    } catch (e) {
      print('Error: $e');
    }
  }
}