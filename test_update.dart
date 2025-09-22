import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('=== TESTING UPDATE SYSTEM ===\n');

  // Clear the last update check to force a fresh check
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('last_update_check');
  print('✅ Cleared last update check timestamp');

  // Test the update check
  await testUpdateCheck();
  await testServerResponse();
  await testAppInfo();
}

Future<void> testUpdateCheck() async {
  print('\n--- Testing Update Check Logic ---');

  try {
    // Get app info like the actual service does
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final currentBuildNumber = int.parse(packageInfo.buildNumber);

    print('📱 Current app version: $currentVersion');
    print('🔢 Current build number: $currentBuildNumber');

    // Test the server request
    final response = await http.get(
      Uri.parse('https://star-dz.com/estarcommande/version.php'),
      headers: {'User-Agent': 'EstStarCommande/$currentVersion'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('🌐 Server response: $data');

      final serverVersion = data['version'];
      final serverBuildNumber = data['buildNumber'];

      print('🖥️  Server version: $serverVersion');
      print('🔢 Server build number: $serverBuildNumber');

      // Check the exact logic used in your app
      final hasUpdate = data['hasUpdate'] == true;

      print('🔍 Has update flag: $hasUpdate');

      if (hasUpdate) {
        print('✅ UPDATE IS AVAILABLE!');
        print('📁 Download URL: ${data['downloadUrl']}');
        print('📝 Changelog: ${data['changelog']}');

        // Test if the version comparison logic works
        final parts1 = currentVersion.split('.');
        final parts2 = serverVersion.split('.');

        print('\n--- Version Comparison ---');
        print('Current: ${parts1.join('.')}');
        print('Server:  ${parts2.join('.')}');

        for (int i = 0; i < 3; i++) {
          final current = int.parse(parts1[i]);
          final server = int.parse(parts2[i]);
          print('Part $i: $current vs $server');
          if (server > current) {
            print('  ✅ Server version is newer');
            break;
          } else if (server < current) {
            print('  ❌ Current version is newer');
            break;
          }
        }

        // Also check build numbers
        if (serverBuildNumber > currentBuildNumber) {
          print(
            '✅ Server build number is newer: $serverBuildNumber > $currentBuildNumber',
          );
        } else {
          print(
            '❌ Server build number is not newer: $serverBuildNumber <= $currentBuildNumber',
          );
        }
      } else {
        print('❌ No update available according to server');
      }
    } else {
      print('❌ Server error: ${response.statusCode}');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> testServerResponse() async {
  print('\n--- Testing Raw Server Response ---');

  try {
    final response = await http.get(
      Uri.parse('https://star-dz.com/estarcommande/version.php'),
    );

    print('Status Code: ${response.statusCode}');
    print('Raw Response: ${response.body}');

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        print('Parsed JSON: $data');
      } catch (e) {
        print('JSON parsing error: $e');
      }
    }
  } catch (e) {
    print('Server test error: $e');
  }
}

Future<void> testAppInfo() async {
  print('\n--- Testing App Info ---');

  try {
    final packageInfo = await PackageInfo.fromPlatform();
    print('App Name: ${packageInfo.appName}');
    print('Package Name: ${packageInfo.packageName}');
    print('Version: ${packageInfo.version}');
    print('Build Number: ${packageInfo.buildNumber}');
    print('Build Signature: ${packageInfo.buildSignature}');
  } catch (e) {
    print('App info error: $e');
  }
}
