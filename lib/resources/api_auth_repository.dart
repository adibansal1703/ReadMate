import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiUser {
  final String id;
  final String email;
  final String username;
  final String? displayName;
  final int yearlyGoal;

  ApiUser({
    required this.id,
    required this.email,
    required this.username,
    this.displayName,
    this.yearlyGoal = 0,
  });

  factory ApiUser.fromJSON(Map<String, dynamic> json) {
    return ApiUser(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      yearlyGoal: json['yearly_goal'] is int ? json['yearly_goal'] as int : 0,
    );
  }
}

class UnverifiedUserException implements Exception {
  final String email;
  final String message;
  UnverifiedUserException(this.email, [this.message = 'Email address is not verified yet.']);

  @override
  String toString() => message;
}

class ApiAuthRepository {

  static String customHostUrl = '';

  static String get baseUrl {
    if (customHostUrl.isNotEmpty) {
      return customHostUrl.endsWith('/api') ? customHostUrl : '$customHostUrl/api';
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.129.68.226:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  static Future<void> setCustomHostUrl(String url) async {
    customHostUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_host_url', customHostUrl);
  }

  static String? _authToken;
  static ApiUser? _currentUser;

  ApiUser? get currentUser => _currentUser;
  String? get authToken => _authToken;

  final StreamController<ApiUser?> _authStateController = StreamController<ApiUser?>.broadcast();
  Stream<ApiUser?> get authStateChanges => _authStateController.stream;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    customHostUrl = prefs.getString('custom_host_url') ?? '';
    _authToken = prefs.getString('auth_token');

    if (_authToken != null) {
      try {
        final res = await http.get(
          Uri.parse('$baseUrl/auth/me'),
          headers: {'Authorization': 'Bearer $_authToken'},
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          _currentUser = ApiUser.fromJSON(data['user']);
          _authStateController.add(_currentUser);
          debugPrint('[API_AUTH] Session restored for user: ${_currentUser?.username}');
        } else {
          await signOut();
        }
      } catch (e) {
        debugPrint('[API_AUTH] Session restore check failed: $e');
      }
    }
  }

  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      debugPrint('[API_AUTH] Sending signup request to: $baseUrl/auth/signup');
      final res = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'username': username,
        }),
      ).timeout(const Duration(seconds: 6), onTimeout: () {
        throw TimeoutException('Connection to backend server ($baseUrl) timed out. Please check if "npm start" is running.');
      });

      final data = jsonDecode(res.body);

      if (res.statusCode == 201 || res.statusCode == 200) {
        return {
          'is_verified': data['is_verified'] == true,
          'email': data['email'] ?? email,
        };
      } else {
        throw data['error'] ?? 'Signup failed.';
      }
    } catch (e) {
      debugPrint('[API_AUTH] Signup error: $e');
      rethrow;
    }
  }

  Future<void> resendVerificationCode(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/resend-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 6));

      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        throw data['error'] ?? 'Failed to resend confirmation link.';
      }
    } catch (e) {
      debugPrint('[API_AUTH] Resend code error: $e');
      rethrow;
    }
  }

  Future<ApiUser> signIn({
    required String identifier,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 6), onTimeout: () {
        throw TimeoutException('Connection to backend server ($baseUrl) timed out. Please check if "npm start" is running.');
      });

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        _authToken = data['token'];
        _currentUser = ApiUser.fromJSON(data['user']);

        final prefs = await SharedPreferences.getInstance();
        if (_authToken != null) await prefs.setString('auth_token', _authToken!);

        _authStateController.add(_currentUser);
        return _currentUser!;
      } else if (res.statusCode == 403 || data['is_verified'] == false) {
        throw UnverifiedUserException(data['email'] ?? identifier, data['error'] ?? 'Please verify your email before logging in.');
      } else {
        throw data['error'] ?? 'Invalid login credentials.';
      }
    } catch (e) {
      debugPrint('[API_AUTH] Login error: $e');
      rethrow;
    }
  }

  Future<ApiUser> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
        }),
      ).timeout(const Duration(seconds: 6));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        _authToken = data['token'];
        _currentUser = ApiUser.fromJSON(data['user']);

        final prefs = await SharedPreferences.getInstance();
        if (_authToken != null) await prefs.setString('auth_token', _authToken!);

        _authStateController.add(_currentUser);
        return _currentUser!;
      } else {
        throw data['error'] ?? 'Verification failed.';
      }
    } catch (e) {
      debugPrint('[API_AUTH] Verify email error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    _authToken = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _authStateController.add(null);
  }

  Future<void> resetPasswordForEmail(String email) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    ).timeout(const Duration(seconds: 6));

    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw data['error'] ?? 'Failed to send password reset email.';
    }
  }

  Future<void> updatePassword(String newPassword) async {
    if (_authToken == null) throw 'Not logged in.';

    final res = await http.put(
      Uri.parse('$baseUrl/auth/password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_authToken',
      },
      body: jsonEncode({'password': newPassword}),
    ).timeout(const Duration(seconds: 6));

    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw data['error'] ?? 'Failed to update password.';
    }
  }

  Future<void> deleteCurrentUser(String password) async {
    if (_authToken == null) throw 'Not logged in.';

    final res = await http.delete(
      Uri.parse('$baseUrl/auth/account'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_authToken',
      },
      body: jsonEncode({'password': password}),
    ).timeout(const Duration(seconds: 6));

    if (res.statusCode == 200) {
      await signOut();
    } else {
      final data = jsonDecode(res.body);
      throw data['error'] ?? 'Error deleting account.';
    }
  }

  Future<bool> isEmailRegistered(String email) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/auth/check-email?email=${Uri.encodeComponent(email)}'),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['registered'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isUsernameAvailable(String username) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/auth/check-username?username=${Uri.encodeComponent(username)}'),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['available'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
