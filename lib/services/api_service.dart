import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? endpoint;

  ApiException(this.message, {this.statusCode, this.endpoint});

  @override
  String toString() =>
      'ApiException: $message ${statusCode != null ? '($statusCode)' : ''}';
}

class ApiResponse<T> {
  final T data;
  final bool success;
  final String? message;
  final int statusCode;

  ApiResponse({
    required this.data,
    required this.success,
    this.message,
    required this.statusCode,
  });
}

class ApiService {
  static const String baseUrl = 'http://estcommand.ddns.net:8080/api/v1';
  static const Duration defaultTimeout = Duration(seconds: 30);

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? data,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    try {
      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(uri, headers: headers)
              .timeout(timeout ?? defaultTimeout);
          break;
        case 'POST':
          response = await http
              .post(
                uri,
                headers: headers,
                body: data != null ? jsonEncode(data) : null,
              )
              .timeout(timeout ?? defaultTimeout);
          break;
        case 'PUT':
          response = await http
              .put(
                uri,
                headers: headers,
                body: data != null ? jsonEncode(data) : null,
              )
              .timeout(timeout ?? defaultTimeout);
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers)
              .timeout(timeout ?? defaultTimeout);
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }

      // Log the request and response for debugging
      _logRequest(method, endpoint, data, response);

      return response;
    } catch (e) {
      _logError(method, endpoint, e);
      if (e is ApiException) rethrow;
      throw ApiException('Network error: ${e.toString()}', endpoint: endpoint);
    }
  }

  void _logRequest(
    String method,
    String endpoint,
    Map<String, dynamic>? data,
    http.Response response,
  ) {
    print('=== API SERVICE REQUEST DEBUG ===');
    print('[$method] $endpoint -> ${response.statusCode}');
    print('Full URL: $baseUrl$endpoint');
    if (data != null) {
      print('Request body: ${jsonEncode(data)}');
    }
    print('Response Headers: ${response.headers}');
    if (response.statusCode >= 400) {
      print('Error response: ${response.body}');
    } else {
      print('Success response length: ${response.body.length}');
    }
    print('==================================');
  }

  void _logError(String method, String endpoint, dynamic error) {
    print('ERROR [$method] $endpoint: $error');
  }

  Future<ApiResponse<T>> _processResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) parser,
  ) async {
    final statusCode = response.statusCode;

    try {
      final responseData = jsonDecode(response.body);

      if (statusCode >= 200 && statusCode < 300) {
        return ApiResponse<T>(
          data: parser(responseData),
          success: true,
          statusCode: statusCode,
        );
      } else {
        final message = responseData['message'] ?? 'Request failed';
        throw ApiException(message, statusCode: statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'Failed to parse response: ${e.toString()}',
        statusCode: statusCode,
      );
    }
  }

  // Enhanced HTTP methods with better error handling
  Future<http.Response> get(String endpoint, {Duration? timeout}) async {
    return _makeRequest('GET', endpoint, timeout: timeout);
  }

  Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> data, {
    Duration? timeout,
  }) async {
    return _makeRequest('POST', endpoint, data: data, timeout: timeout);
  }

  Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> data, {
    Duration? timeout,
  }) async {
    return _makeRequest('PUT', endpoint, data: data, timeout: timeout);
  }

  Future<http.Response> delete(String endpoint, {Duration? timeout}) async {
    return _makeRequest('DELETE', endpoint, timeout: timeout);
  }

  // Typed response methods
  Future<ApiResponse<Map<String, dynamic>>> getJson(String endpoint) async {
    final response = await get(endpoint);
    return _processResponse<Map<String, dynamic>>(response, (data) => data);
  }

  Future<ApiResponse<List<dynamic>>> getList(String endpoint) async {
    final response = await get(endpoint);
    return _processResponse<List<dynamic>>(
      response,
      (data) => data['data'] ?? data,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> postJson(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await post(endpoint, data);
    return _processResponse<Map<String, dynamic>>(
      response,
      (responseData) => responseData,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> putJson(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await put(endpoint, data);
    return _processResponse<Map<String, dynamic>>(
      response,
      (responseData) => responseData,
    );
  }

  Future<ApiResponse<bool>> deleteResource(String endpoint) async {
    final response = await delete(endpoint);
    return _processResponse<bool>(response, (data) => true);
  }
}
