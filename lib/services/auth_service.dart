import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class AuthService {
  // Cache for user info to avoid repeated token parsing
  Map<String, dynamic>? _cachedUserInfo;
  DateTime? _userInfoCacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  // Decode JWT payload
  Map<String, dynamic> decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid JWT');
    }
    final payload = parts[1];
    final normalized = base64.normalize(payload);
    final decoded = utf8.decode(base64.decode(normalized));
    return json.decode(decoded);
  }

  // Get auth token from storage
  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Set auth token in storage
  Future<void> setAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    // Clear cache when token changes
    _clearUserInfoCache();
  }

  // Clear auth token
  Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _clearUserInfoCache();
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getAuthToken();
    if (token == null || token.isEmpty) return false;

    try {
      // Try to decode token to check if it's valid
      decodeJwtPayload(token);
      return true;
    } catch (e) {
      // Invalid token
      await clearAuthToken();
      return false;
    }
  }

  // Get cached user info or fetch if not cached/expired
  Future<Map<String, dynamic>> getCachedUserInfo() async {
    final now = DateTime.now();

    // Return cached info if still valid
    if (_userInfoCacheTime != null &&
        now.difference(_userInfoCacheTime!).compareTo(_cacheTimeout) < 0 &&
        _cachedUserInfo != null) {
      return _cachedUserInfo!;
    }

    // Fetch fresh user info
    final token = await getAuthToken();
    if (token == null) {
      throw const AuthenticationException();
    }

    final payload = decodeJwtPayload(token);
    final userInfo = {
      'id': payload['id'],
      'username': payload['username'],
      'isAdmin': payload['isadmin'] == 1,
      'isSuper': payload['issuper'] == 1,
      'isClient': payload['isclient'] == 1,
      'isDelegue': payload['isDelegue'] == 1,
      'region': payload['region'],
    };

    // Cache the results
    _cachedUserInfo = userInfo;
    _userInfoCacheTime = now;

    return userInfo;
  }

  // Get current user
  Future<User?> getCurrentUser() async {
    try {
      final userInfo = await getCachedUserInfo();
      return User(
        id: userInfo['id'] ?? 0,
        username: userInfo['username'] ?? 'Unknown',
        isAdmin: userInfo['isAdmin'] ?? false,
        isSuper: userInfo['isSuper'] ?? false,
        isClient: userInfo['isClient'] ?? false,
        isDelegue: userInfo['isDelegue'] ?? false,
        region: userInfo['region'],
      );
    } catch (e) {
      return null;
    }
  }

  // Role checking methods
  Future<bool> isAdmin() async {
    try {
      final userInfo = await getCachedUserInfo();
      return userInfo['isAdmin'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isSuper() async {
    try {
      final userInfo = await getCachedUserInfo();
      return userInfo['isSuper'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isClient() async {
    try {
      final userInfo = await getCachedUserInfo();
      return userInfo['isClient'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isDelegue() async {
    try {
      final userInfo = await getCachedUserInfo();
      return userInfo['isDelegue'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getUserRegion() async {
    try {
      final userInfo = await getCachedUserInfo();
      return userInfo['region'] as String?;
    } catch (e) {
      return null;
    }
  }

  // Check if user has admin access
  Future<bool> hasAdminAccess() async {
    final isAdminUser = await isAdmin();
    final isSuperUser = await isSuper();
    return isAdminUser || isSuperUser;
  }

  // Clear user info cache
  void _clearUserInfoCache() {
    _cachedUserInfo = null;
    _userInfoCacheTime = null;
  }

  // Dispose method for cleanup
  void dispose() {
    _clearUserInfoCache();
  }
}

// Exception for authentication errors
class AuthenticationException implements Exception {
  final String message;

  const AuthenticationException([this.message = 'Authentication failed']);

  @override
  String toString() => 'AuthenticationException: $message';
}
