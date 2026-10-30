import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data_service.dart';

class UserAccount {
  final String id;
  final String email;
  final String username;
  String password;
  final String role; // 'admin', 'teacher', 'staff'
  final String displayName;

  UserAccount({
    required this.id,
    required this.email,
    required this.username,
    required this.password,
    required this.role,
    required this.displayName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'username': username,
        'password': password,
        'role': role,
        'displayName': displayName,
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        id: json['id'] as String,
        email: json['email'] as String,
        username: json['username'] as String,
        password: json['password'] as String,
        role: json['role'] as String,
        displayName: json['displayName'] as String,
      );
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _accountsKey = 'auth_accounts_v1';
  static const String _sessionKey = 'auth_current_user_session';
  static const String _pinEnabledKey = 'pin_enabled';

  List<UserAccount> _accounts = [];
  UserAccount? _currentUser;

  UserAccount? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  /// Default accounts seeded on first run
  final List<UserAccount> _defaultAccounts = [
    UserAccount(
      id: 'USR-ADMIN',
      email: 'admin@school.com',
      username: 'admin',
      password: 'admin123',
      role: 'admin',
      displayName: 'Admin Office',
    ),
    UserAccount(
      id: 'USR-TEACHER',
      email: 'teacher@school.com',
      username: 'teacher',
      password: 'teacher123',
      role: 'teacher',
      displayName: 'Mr. Tariq Mehmood (Cl-9)',
    ),
    UserAccount(
      id: 'USR-STAFF',
      email: 'staff@school.com',
      username: 'staff',
      password: 'staff123',
      role: 'staff',
      displayName: 'Authorized Staff',
    ),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final rawAccounts = prefs.getString(_accountsKey);
    if (rawAccounts != null) {
      try {
        final List<dynamic> list = jsonDecode(rawAccounts);
        _accounts = list
            .map((e) => UserAccount.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        _accounts = List.from(_defaultAccounts);
      }
    } else {
      _accounts = List.from(_defaultAccounts);
      await _persistAccounts();
    }

    // Check active session
    final sessionUserId = prefs.getString(_sessionKey);
    if (sessionUserId != null) {
      final user = _accounts.cast<UserAccount?>().firstWhere(
            (a) => a?.id == sessionUserId,
            orElse: () => null,
          );
      if (user != null) {
        _currentUser = user;
        DataService().switchRole(user.role);
      }
    }
    notifyListeners();
  }

  Future<void> _persistAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_accounts.map((a) => a.toJson()).toList());
    await prefs.setString(_accountsKey, jsonStr);
  }

  /// Authenticate with email or username and password
  Future<bool> login(String emailOrUsername, String password) async {
    final cleanInput = emailOrUsername.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (_accounts.isEmpty) {
      await init();
    }

    final match = _accounts.cast<UserAccount?>().firstWhere(
      (a) {
        if (a == null) return false;
        final matchesIdentifier =
            a.email.toLowerCase() == cleanInput || a.username.toLowerCase() == cleanInput;
        final matchesPassword = a.password == cleanPassword;
        return matchesIdentifier && matchesPassword;
      },
      orElse: () => null,
    );

    if (match != null) {
      _currentUser = match;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, match.id);
      DataService().switchRole(match.role);
      notifyListeners();
      return true;
    }

    return false;
  }

  /// End current session
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    notifyListeners();
  }

  /// Reset password for an email or username
  Future<bool> resetPassword(String emailOrUsername, String newPassword) async {
    final cleanInput = emailOrUsername.trim().toLowerCase();
    final idx = _accounts.indexWhere(
      (a) =>
          a.email.toLowerCase() == cleanInput || a.username.toLowerCase() == cleanInput,
    );

    if (idx != -1 && newPassword.trim().isNotEmpty) {
      _accounts[idx].password = newPassword.trim();
      await _persistAccounts();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Change password for current logged-in user
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (_currentUser == null) return false;
    if (_currentUser!.password != oldPassword.trim()) return false;
    return resetPassword(_currentUser!.username, newPassword);
  }

  /// List of registered user accounts (for demo hints)
  List<UserAccount> get accounts => List.unmodifiable(_accounts);
}

