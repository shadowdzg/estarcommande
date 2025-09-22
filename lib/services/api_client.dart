import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String _baseUrl = 'http://estcommand.ddns.net:8080/api/v1';
  static const Duration _defaultTimeout = Duration(seconds: 10);

  late final http.Client _client;
  String? _authToken;

  ApiClient() {
    _client = http.Client();
  }

  // Initialize with auth token
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
  }

  // Get headers with auth token
  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  // Generic GET request
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final finalUri = queryParams != null
        ? uri.replace(queryParameters: queryParams)
        : uri;

    return await _client
        .get(finalUri, headers: _headers)
        .timeout(_defaultTimeout);
  }

  // Generic POST request
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');

    return await _client
        .post(
          uri,
          headers: _headers,
          body: body != null ? json.encode(body) : null,
        )
        .timeout(_defaultTimeout);
  }

  // Generic PUT request
  Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');

    return await _client
        .put(
          uri,
          headers: _headers,
          body: body != null ? json.encode(body) : null,
        )
        .timeout(_defaultTimeout);
  }

  // Generic DELETE request
  Future<http.Response> delete(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');

    return await _client
        .delete(uri, headers: _headers)
        .timeout(_defaultTimeout);
  }

  // Update auth token
  Future<void> setAuthToken(String token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Clear auth token
  Future<void> clearAuthToken() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Dispose of the client
  void dispose() {
    _client.close();
  }
}

// API Exception classes
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  const ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException extends ApiException {
  const NetworkException(String message) : super(message);
}

class AuthenticationException extends ApiException {
  const AuthenticationException()
    : super('Authentication failed', statusCode: 401);
}

class ServerException extends ApiException {
  const ServerException(String message, int statusCode)
    : super(message, statusCode: statusCode);
}
