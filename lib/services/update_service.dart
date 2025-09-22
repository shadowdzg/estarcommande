import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _lastUpdateCheckKey = 'last_update_check';
  static const String _updateReminderKey = 'update_reminder_count';
  static const int _maxReminderCount = 3;

  /// Reset the last update check time to force immediate check
  static Future<void> resetUpdateCheckTimer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastUpdateCheckKey);
    debugPrint('UpdateService: Update check timer reset');
  }

  /// Check for updates from your custom server (with option to force check)
  static Future<void> checkForServerUpdate(
    BuildContext context, {
    bool forceCheck = false,
  }) async {
    try {
      debugPrint('UpdateService: Update check temporarily disabled');
      return; // Temporarily disable update checks

      debugPrint(
        'UpdateService: Starting update check (forceCheck: $forceCheck)',
      );

      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastUpdateCheckKey) ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      debugPrint(
        'UpdateService: lastCheck: $lastCheck, currentTime: $currentTime, diff: ${currentTime - lastCheck}',
      );

      // Check only once every 24 hours unless forced
      if (!forceCheck && currentTime - lastCheck < 86400000) {
        debugPrint(
          'UpdateService: Skipping update check (last check too recent)',
        );
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

      debugPrint(
        'UpdateService: Current version: $currentVersion+$currentBuildNumber',
      );

      // Use your working server URL
      const serverUrl = 'http://estcommand.ddns.net:8080/api/version';

      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isWindows
          ? 'windows'
          : 'android';

      final requestUrl =
          '$serverUrl?platform=$platform&currentVersion=$currentVersion&buildNumber=$currentBuildNumber';
      debugPrint('UpdateService: Request URL: $requestUrl');

      final response = await http.get(Uri.parse(requestUrl));

      debugPrint('UpdateService: Response status: ${response.statusCode}');
      debugPrint('UpdateService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>?;
        if (data == null) {
          debugPrint('UpdateService: Invalid JSON response');
          return;
        }

        final hasUpdate = data['hasUpdate'] as bool? ?? false;
        final isForceUpdate = data['isForceUpdate'] as bool? ?? false;

        debugPrint(
          'UpdateService: hasUpdate: $hasUpdate, isForceUpdate: $isForceUpdate',
        );

        if (hasUpdate && data['latest'] != null) {
          final latest = data['latest'] as Map<String, dynamic>?;
          if (latest == null) {
            debugPrint('UpdateService: Latest data is null');
            return;
          }

          final latestVersion = latest['version'] as String? ?? 'Unknown';
          final changelog =
              (latest['changelog'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          final updateMessage = changelog.isNotEmpty
              ? changelog.join('\n• ')
              : 'Une nouvelle version de l\'application est disponible.';

          debugPrint(
            'UpdateService: Showing update dialog for version: $latestVersion',
          );

          await _showCustomUpdateDialog(
            context,
            latestVersion,
            updateMessage,
            isForceUpdate,
            downloadUrl: latest['downloadUrl'] as String?,
          );
        } else {
          debugPrint('UpdateService: No update available');
        }

        await prefs.setInt(_lastUpdateCheckKey, currentTime);
      } else {
        debugPrint(
          'UpdateService: Server returned error: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('UpdateService: Error checking for server updates: $e');
      // Optionally show error to user if context is still valid
      try {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erreur de vérification des mises à jour: ${e.toString()}',
              ),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      } catch (contextError) {
        debugPrint('UpdateService: Context error: $contextError');
      }
    }
  }

  /// Show custom server update dialog
  static Future<void> _showCustomUpdateDialog(
    BuildContext context,
    String version,
    String message,
    bool isForced, {
    String? downloadUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final reminderCount = prefs.getInt(_updateReminderKey) ?? 0;

    if (!isForced && reminderCount >= _maxReminderCount) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: !isForced,
      builder: (BuildContext context) {
        return PopScope(
          canPop: !isForced,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  isForced ? Icons.priority_high : Icons.system_update,
                  color: isForced ? Colors.red.shade600 : Colors.blue.shade600,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isForced ? 'Mise à jour requise' : 'Mise à jour disponible',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version $version',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                if (message.isNotEmpty) ...[
                  const Text(
                    'Nouveautés :',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text('• $message', style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isForced ? Colors.red.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isForced
                          ? Colors.red.shade200
                          : Colors.blue.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isForced ? Icons.warning : Icons.info_outline,
                        color: isForced
                            ? Colors.red.shade600
                            : Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isForced
                              ? 'Cette mise à jour est obligatoire pour continuer à utiliser l\'application.'
                              : Platform.isWindows
                              ? 'Télécharger l\'installateur pour mettre à jour automatiquement.'
                              : 'Mettre à jour maintenant pour bénéficier des dernières fonctionnalités.',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (!isForced) ...[
                TextButton(
                  onPressed: () async {
                    await prefs.setInt(_updateReminderKey, reminderCount + 1);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Plus tard'),
                ),
              ],
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (downloadUrl != null) {
                    _downloadUpdate(downloadUrl);
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('Télécharger'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isForced
                      ? Colors.red.shade600
                      : Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Download update from URL
  static Future<void> _downloadUpdate(String downloadUrl) async {
    try {
      final uri = Uri.parse(downloadUrl);

      // For Windows, try to download and execute installer
      if (Platform.isWindows &&
          (downloadUrl.endsWith('.exe') || downloadUrl.endsWith('.msi'))) {
        // For Windows installers, launch directly
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('Could not launch $downloadUrl');
        }
      } else if (Platform.isWindows && downloadUrl.endsWith('.zip')) {
        // For Windows ZIP files, download to downloads folder
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('Could not launch $downloadUrl');
        }
      } else {
        // For Android APK or other files
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('Could not launch $downloadUrl');
        }
      }
    } catch (e) {
      debugPrint('Error downloading update: $e');
    }
  }

  /// Reset reminder count (call when user updates)
  static Future<void> resetReminderCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_updateReminderKey);
  }

  /// Force check for updates (manual trigger)
  static Future<void> manualUpdateCheck(BuildContext context) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

      // Use your working server URL
      const serverUrl = 'http://estcommand.ddns.net:8080/api/version';

      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isWindows
          ? 'windows'
          : 'android';
      final response = await http.get(
        Uri.parse(
          '$serverUrl?platform=$platform&currentVersion=$currentVersion&buildNumber=$currentBuildNumber',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>?;

        if (data == null) {
          // Close loading dialog
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Erreur lors de la vérification des mises à jour'),
                  ],
                ),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        final hasUpdate = data['hasUpdate'] as bool? ?? false;
        final isForceUpdate = data['isForceUpdate'] as bool? ?? false;

        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        if (hasUpdate && data['latest'] != null) {
          final latest = data['latest'] as Map<String, dynamic>?;
          if (latest == null) return;

          final latestVersion = latest['version'] as String? ?? 'Unknown';
          final changelog =
              (latest['changelog'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          final updateMessage = changelog.isNotEmpty
              ? changelog.join('\n• ')
              : 'Une nouvelle version de l\'application est disponible.';

          await _showCustomUpdateDialog(
            context,
            latestVersion,
            updateMessage,
            isForceUpdate,
            downloadUrl: latest['downloadUrl'] as String?,
          );
        } else {
          // Show "up to date" message only if no update is available
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Vous utilisez la dernière version'),
                  ],
                ),
                backgroundColor: Colors.green.shade600,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }

        // Update the last check time
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(_lastUpdateCheckKey, currentTime);
      } else {
        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Erreur lors de la vérification des mises à jour'),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('Erreur lors de la vérification des mises à jour'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Get current app version info
  static Future<Map<String, dynamic>> getAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return {
      'version': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'appName': packageInfo.appName,
      'packageName': packageInfo.packageName,
    };
  }
}
