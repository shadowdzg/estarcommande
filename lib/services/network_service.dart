import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum ServerType { local, online }

class NetworkService {
  static const String _localServerUrl = 'http://192.168.200.33:8080';
  static const String _onlineServerUrl = 'http://estcommand.ddns.net:8080';
  static const String _serverTypeKey = 'preferred_server_type';

  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();

  // Get the current connectivity status
  Future<List<ConnectivityResult>> getConnectivityStatus() async {
    return await _connectivity.checkConnectivity();
  }

  // Check if device has internet connectivity
  Future<bool> hasInternetConnectivity() async {
    try {
      final connectivityResults = await getConnectivityStatus();

      // If no connectivity at all, return false
      if (connectivityResults.contains(ConnectivityResult.none) ||
          connectivityResults.isEmpty) {
        return false;
      }

      // Try to ping a reliable service to confirm internet access
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Check if local server is reachable
  Future<bool> isLocalServerReachable() async {
    try {
      final response = await http
          .get(Uri.parse('$_localServerUrl/api/v1'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Check if online server is reachable
  Future<bool> isOnlineServerReachable() async {
    try {
      final response = await http
          .get(Uri.parse('$_onlineServerUrl/api/v1'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Get the preferred server type from SharedPreferences
  Future<ServerType> getPreferredServerType() async {
    final prefs = await SharedPreferences.getInstance();
    final serverTypeString = prefs.getString(_serverTypeKey) ?? 'online';
    return serverTypeString == 'local' ? ServerType.local : ServerType.online;
  }

  // Set the preferred server type
  Future<void> setPreferredServerType(ServerType serverType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _serverTypeKey,
      serverType == ServerType.local ? 'local' : 'online',
    );
  }

  // Get the appropriate server URL based on type
  String getServerUrl(ServerType serverType) {
    return serverType == ServerType.local ? _localServerUrl : _onlineServerUrl;
  }

  // Get the best available server
  Future<ServerConfiguration> getBestAvailableServer() async {
    final preferredType = await getPreferredServerType();
    final hasInternet = await hasInternetConnectivity();

    if (preferredType == ServerType.local) {
      final localReachable = await isLocalServerReachable();
      if (localReachable) {
        return ServerConfiguration(
          type: ServerType.local,
          url: _localServerUrl,
          isAvailable: true,
          description: 'Local server (fast)',
        );
      }

      // Fallback to online if local is not reachable and we have internet
      if (hasInternet) {
        final onlineReachable = await isOnlineServerReachable();
        if (onlineReachable) {
          return ServerConfiguration(
            type: ServerType.online,
            url: _onlineServerUrl,
            isAvailable: true,
            description: 'Online server (fallback)',
          );
        }
      }
    } else {
      // Preferred is online
      if (hasInternet) {
        final onlineReachable = await isOnlineServerReachable();
        if (onlineReachable) {
          return ServerConfiguration(
            type: ServerType.online,
            url: _onlineServerUrl,
            isAvailable: true,
            description: 'Online server',
          );
        }
      }

      // Fallback to local if online is not reachable
      final localReachable = await isLocalServerReachable();
      if (localReachable) {
        return ServerConfiguration(
          type: ServerType.local,
          url: _localServerUrl,
          isAvailable: true,
          description: 'Local server (fallback)',
        );
      }
    }

    // No server is available
    return ServerConfiguration(
      type: preferredType,
      url: getServerUrl(preferredType),
      isAvailable: false,
      description: 'No server available',
    );
  }

  // Get connectivity status description for UI
  Future<String> getConnectivityDescription() async {
    final connectivityResults = await getConnectivityStatus();

    if (connectivityResults.isEmpty ||
        connectivityResults.contains(ConnectivityResult.none)) {
      return 'No Internet Connection';
    }

    if (connectivityResults.contains(ConnectivityResult.wifi)) {
      return 'Connected via WiFi';
    } else if (connectivityResults.contains(ConnectivityResult.mobile)) {
      return 'Connected via Mobile Data';
    } else if (connectivityResults.contains(ConnectivityResult.ethernet)) {
      return 'Connected via Ethernet';
    } else {
      return 'Unknown Connection';
    }
  }

  // Listen to connectivity changes
  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;
}

class ServerConfiguration {
  final ServerType type;
  final String url;
  final bool isAvailable;
  final String description;

  ServerConfiguration({
    required this.type,
    required this.url,
    required this.isAvailable,
    required this.description,
  });

  String get apiBaseUrl => '$url/api/v1';
  String get displayName => type == ServerType.local
      ? '🏠 Local Server (192.168.200.33)'
      : '🌍 Online Server (estcommand.ddns.net)';
}
