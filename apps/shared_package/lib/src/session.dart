import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Persists the signed-in session on device/web storage.
class SessionStore {
  static const _accessKey = 'neev.access_token';
  static const _refreshKey = 'neev.refresh_token';
  static const _userKey = 'neev.user';

  SharedPreferences? _prefs;
  String? _accessToken;
  String? _refreshToken;
  UserSession? _user;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  UserSession? get user => _user;
  bool get isSignedIn => _accessToken != null && _user != null;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _accessToken = _prefs!.getString(_accessKey);
    _refreshToken = _prefs!.getString(_refreshKey);
    final raw = _prefs!.getString(_userKey);
    if (raw != null) {
      try {
        _user = UserSession.fromJson(
            (jsonDecode(raw) as Map).cast<String, dynamic>());
      } catch (_) {
        _user = null;
      }
    }
  }

  Future<void> save(AuthResult result) async {
    _prefs ??= await SharedPreferences.getInstance();
    _accessToken = result.accessToken;
    _refreshToken = result.refreshToken;
    _user = result.user;
    await _prefs!.setString(_accessKey, result.accessToken);
    await _prefs!.setString(_refreshKey, result.refreshToken);
    await _prefs!.setString(
      _userKey,
      jsonEncode({
        'id': result.user.id,
        'phone': result.user.phone,
        'role': result.user.role,
        'name': result.user.name,
        'captain': {
          'verification_status': result.user.verificationStatus,
          'is_online': result.user.isOnline,
        },
      }),
    );
  }

  Future<void> updateTokens(String access, String refresh) async {
    _prefs ??= await SharedPreferences.getInstance();
    _accessToken = access;
    _refreshToken = refresh;
    await _prefs!.setString(_accessKey, access);
    await _prefs!.setString(_refreshKey, refresh);
  }

  Future<void> updateUser(UserSession user) async {
    _user = user;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(
      _userKey,
      jsonEncode({
        'id': user.id,
        'phone': user.phone,
        'role': user.role,
        'name': user.name,
        'captain': {
          'verification_status': user.verificationStatus,
          'is_online': user.isOnline,
        },
      }),
    );
  }

  Future<void> clear() async {
    _prefs ??= await SharedPreferences.getInstance();
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    await _prefs!.remove(_accessKey);
    await _prefs!.remove(_refreshKey);
    await _prefs!.remove(_userKey);
  }
}
