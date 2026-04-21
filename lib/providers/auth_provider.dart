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