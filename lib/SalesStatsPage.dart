import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_selector/file_selector.dart';

import 'login_page.dart';
import 'app_drawer.dart';

class SalesStatsPage extends StatefulWidget {
  const SalesStatsPage({super.key});

  @override
  State<SalesStatsPage> createState() => _SalesStatsPageState();
}

class _SalesStatsPageState extends State<SalesStatsPage> {
  bool isRecouvrement = true;
  List<dynamic> _zoneData = [];
  List<dynamic> _filteredZoneData = [];
  List<dynamic> _delegatesList = [];
  bool isAdmin = false;
  bool isSuperUser = false;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _checkSuperUser();
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (!_isLoading) {
      await fetchZoneData();
      await _fetchDelegatesList();
    }
  }

  Future<void> _fetchDelegatesList() async {
    try {
      // Try to fetch all users first, then filter for delegates
      // Following the same pattern as settings.dart - no auth header
      final response = await http
          .get(Uri.parse('http://estcommand.ddns.net:8080/api/v1/users'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Filter users to get only delegates (users with isDelegue = 1)
        final delegates = data.where((user) {
          final isDelegue = user['isDelegue'];
          // Check for numeric 1 (database stores roles as 1/0)
          bool isDelegate = isDelegue == 1;
          return isDelegate;
        }).toList();

        setState(() {
          _delegatesList = delegates;
        });
      } else {
        // If /users endpoint doesn't work, try a different approach
        // Let's try to get delegates from zones endpoint
        await _fetchDelegatesFromZones();
      }
    } catch (e) {
      // Fallback: try to get delegates from zones
      await _fetchDelegatesFromZones();
    }
  }

  // Fallback method: extract delegates from existing zone data
  Future<void> _fetchDelegatesFromZones() async {
    try {
      // Extract unique delegates from the zone data
      final Set<Map<String, dynamic>> uniqueDelegates = {};

      for (var zone in _zoneData) {
        if (zone['user'] != null) {
          uniqueDelegates.add({
            'id': zone['user']['id'],
            'username': zone['user']['username'],
            'email': zone['user']['email'] ?? '',
            'isDelegue': true,
          });
        }
      }

      setState(() {
        _delegatesList = uniqueDelegates.toList();
      });
    } catch (e) {
      // Error extracting delegates from zones
    }
  }

  Future<void> fetchZoneData() async {
    // Prevent multiple simultaneous calls
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Token d\'authentification manquant'),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }

      final response = await http
          .get(
            Uri.parse('http://estcommand.ddns.net:8080/api/v1/zones'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _zoneData = data;
          _filteredZoneData = data; // Initialize filtered data
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Erreur ${response.statusCode}: ${response.body}'),
                ],
              ),
              backgroundColor: Colors.orange.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('Erreur de connexion: ${e.toString()}'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _assignRegionToDelegate(
    String zoneId,
    String delegateId,
    String delegateName,
    String zoneName,
  ) async {
    print('=== DELEGATE ASSIGNMENT START ===');
    print('Zone ID: $zoneId');
    print('Delegate ID: $delegateId');
    print('Delegate Name: $delegateName');
    print('Zone Name: $zoneName');

    // First, let's test if the API endpoint is reachable
    print('Testing API endpoint reachability...');
    try {
      final testResponse = await http
          .get(
            Uri.parse('http://estcommand.ddns.net:8080/api/v1/zones'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));
      print('API endpoint test - Status: ${testResponse.statusCode}');
    } catch (e) {
      print('API endpoint test failed: $e');
    }

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text('Assignation en cours...'),
            ],
          ),
          backgroundColor: Colors.blue.shade600,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        print('ERROR: No auth token found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Token d\'authentification non trouvé'),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }

      print(
        'Making API call to: http://estcommand.ddns.net:8080/api/v1/zones/assign-user/$zoneId',
      );
      print('Request body: ${json.encode({'userID': delegateId})}');

      final response = await http
          .patch(
            Uri.parse(
              'http://estcommand.ddns.net:8080/api/v1/zones/assign-user/$zoneId',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({'userID': delegateId}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('ERROR: API request timed out after 30 seconds');
              throw Exception('Request timeout');
            },
          );

      print('API Response received:');
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('SUCCESS: Assignment successful');
        print('Refreshing zone data...');

        // Refresh zone data to reflect the change
        await fetchZoneData();

        print('Zone data refreshed successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Région "$zoneName" assignée à $delegateName avec succès',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        print('=== DELEGATE ASSIGNMENT SUCCESS ===');
      } else {
        print('ERROR: Assignment failed');
        print('Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Échec de l\'assignation (${response.statusCode}): ${response.body}',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        print('=== DELEGATE ASSIGNMENT FAILED ===');
      }
    } catch (e) {
      print('EXCEPTION: Assignment error');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: ${StackTrace.current}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Erreur lors de l\'assignation: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      print('=== DELEGATE ASSIGNMENT EXCEPTION ===');
    }
  }

  Future<void> _removeRegionFromDelegate(String zoneId, String zoneName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Token d\'authentification non trouvé'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      // Send empty userID to remove the assignment
      final response = await http.patch(
        Uri.parse(
          'http://estcommand.ddns.net:8080/api/v1/zones/assign-user/$zoneId',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'userID': ''}), // Try empty string first
      );

      // If empty string doesn't work, try with null
      if (response.statusCode != 200 && response.statusCode != 201) {
        final response2 = await http.patch(
          Uri.parse(
            'http://estcommand.ddns.net:8080/api/v1/zones/assign-user/$zoneId',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'userID': null}),
        );

        if (response2.statusCode == 200 || response2.statusCode == 201) {
          // Second attempt succeeded
          await fetchZoneData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Délégué retiré de la région "$zoneName" avec succès',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          return;
        } else {
          // Both attempts failed
        }
      } else {
        // First attempt succeeded
        await fetchZoneData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Délégué retiré de la région "$zoneName" avec succès',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      // If we reach here, both attempts failed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Échec du retrait du délégué'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Erreur lors du retrait'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _filterZones(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredZoneData = _zoneData;
      } else {
        _filteredZoneData = _zoneData.where((zone) {
          final name = zone['name']?.toString().toLowerCase() ?? '';
          final delegate =
              zone['user']?['username']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase()) ||
              delegate.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<bool> _isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) return false;
    final payload = _decodeJwtPayload(token);
    return payload['isadmin'] == 1;
  }

  Future<bool> _isSuperUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) return false;
    final payload = _decodeJwtPayload(token);
    return payload['issuper'] == 1;
  }

  Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    final payload = base64Url.normalize(parts[1]);
    return json.decode(utf8.decode(base64Url.decode(payload)));
  }

  void _checkAdmin() async {
    final admin = await _isAdmin();
    setState(() {
      isAdmin = admin;
    });
  }

  void _checkSuperUser() async {
    final superUser = await _isSuperUser();
    setState(() {
      isSuperUser = superUser;
    });
  }

  void _showDelegateAssignmentDialog(Map<String, dynamic> zone) {
    if (!isAdmin) return; // Only admins can assign delegates

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.assignment_ind, color: Colors.blue.shade600, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Assigner Délégué',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zone info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Région: ${zone['name'] ?? 'Sans nom'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (zone['user'] != null)
                              Text(
                                'Délégué actuel: ${zone['user']['username']}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              )
                            else
                              Text(
                                'Aucun délégué assigné',
                                style: TextStyle(
                                  color: Colors.orange.shade600,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Delegates list
                Text(
                  'Sélectionner un délégué:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),

                Flexible(
                  child: _delegatesList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Aucun délégué disponible',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Vérifiez les logs pour plus d\'informations',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await _fetchDelegatesList();
                                  _showDelegateAssignmentDialog(zone);
                                },
                                child: const Text('Réessayer'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _delegatesList.length,
                          itemBuilder: (context, index) {
                            final delegate = _delegatesList[index];

                            // Better comparison logic to handle different ID field names
                            bool isCurrentDelegate = false;
                            if (zone['user'] != null) {
                              final zoneUser = zone['user'];
                              // Try different ID field combinations, prioritizing the correct field names
                              for (String zoneKey in [
                                'userID',
                                'uuid',
                                'user_uuid',
                                'userUuid',
                                'user_id',
                                'userId',
                                'ID',
                                'id',
                              ]) {
                                for (String delKey in [
                                  'userID',
                                  'uuid',
                                  'user_uuid',
                                  'userUuid',
                                  'user_id',
                                  'userId',
                                  'ID',
                                  'id',
                                ]) {
                                  if (zoneUser[zoneKey] != null &&
                                      delegate[delKey] != null &&
                                      zoneUser[zoneKey].toString() ==
                                          delegate[delKey].toString()) {
                                    isCurrentDelegate = true;
                                    break;
                                  }
                                }
                                if (isCurrentDelegate) break;
                              }
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: isCurrentDelegate ? 3 : 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isCurrentDelegate
                                      ? Colors.green.shade300
                                      : Colors.grey.shade300,
                                  width: isCurrentDelegate ? 2 : 1,
                                ),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isCurrentDelegate
                                      ? Colors.green.shade100
                                      : Colors.blue.shade100,
                                  child: Icon(
                                    isCurrentDelegate
                                        ? Icons.check
                                        : Icons.person,
                                    color: isCurrentDelegate
                                        ? Colors.green.shade600
                                        : Colors.blue.shade600,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  delegate['username'] ?? 'Sans nom',
                                  style: TextStyle(
                                    fontWeight: isCurrentDelegate
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: isCurrentDelegate
                                    ? Text(
                                        'Délégué actuel',
                                        style: TextStyle(
                                          color: Colors.green.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      )
                                    : Text(delegate['email'] ?? ''),
                                trailing: isCurrentDelegate
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Colors.green.shade600,
                                      )
                                    : Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.grey.shade400,
                                      ),
                                onTap: () {
                                  Navigator.of(context).pop();

                                  // Debug: Show delegate and zone data
                                  print('=== ID EXTRACTION DEBUG ===');
                                  print('Delegate data: $delegate');
                                  print('Zone data: $zone');
                                  print(
                                    'Delegate keys: ${delegate.keys.toList()}',
                                  );
                                  print('Zone keys: ${zone.keys.toList()}');

                                  // Try to find the appropriate ID field for UUID
                                  // Check various possible UUID field names
                                  String userId = '';
                                  print('Searching for userId in delegate...');
                                  for (String key in [
                                    'userID',
                                    'uuid',
                                    'user_uuid',
                                    'userUuid',
                                    'user_id',
                                    'userId',
                                    'ID',
                                    'id',
                                  ]) {
                                    print(
                                      'Checking delegate key "$key": ${delegate[key]}',
                                    );
                                    if (delegate.containsKey(key) &&
                                        delegate[key] != null &&
                                        delegate[key].toString().isNotEmpty) {
                                      userId = delegate[key].toString();
                                      print(
                                        'Found userId in key "$key": $userId',
                                      );
                                      break;
                                    }
                                  }

                                  // If still empty, try any field that looks like a UUID
                                  if (userId.isEmpty) {
                                    print(
                                      'No userId found in standard keys, searching all delegate keys...',
                                    );
                                    for (String key in delegate.keys) {
                                      String value =
                                          delegate[key]?.toString() ?? '';
                                      print(
                                        'Checking delegate key "$key": "$value"',
                                      );
                                      // UUID pattern: 8-4-4-4-12 characters with hyphens
                                      if (value.length == 36 &&
                                          value.contains('-') &&
                                          RegExp(
                                            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                                            caseSensitive: false,
                                          ).hasMatch(value)) {
                                        userId = value;
                                        print(
                                          'Found UUID-like userId in key "$key": $userId',
                                        );
                                        break;
                                      }
                                    }
                                  }

                                  String zoneId = '';
                                  print('Searching for zoneId in zone...');
                                  for (String key in [
                                    'zoneID',
                                    'uuid',
                                    'zone_uuid',
                                    'zoneUuid',
                                    'zone_id',
                                    'zoneId',
                                    'ID',
                                    'id',
                                  ]) {
                                    print(
                                      'Checking zone key "$key": ${zone[key]}',
                                    );
                                    if (zone.containsKey(key) &&
                                        zone[key] != null) {
                                      zoneId = zone[key].toString();
                                      print(
                                        'Found zoneId in key "$key": $zoneId',
                                      );
                                      break;
                                    }
                                  }

                                  print('Final extracted userId: "$userId"');
                                  print('Final extracted zoneId: "$zoneId"');
                                  print('=== ID EXTRACTION COMPLETE ===');

                                  if (userId.isEmpty || zoneId.isEmpty) {
                                    print(
                                      'ERROR: Missing IDs - userId: "$userId", zoneId: "$zoneId"',
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                              Icons.error_outline,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'IDs manquants - userId: "$userId", zoneId: "$zoneId"',
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: Colors.red.shade600,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  print(
                                    'Proceeding with assignment - userId: "$userId", zoneId: "$zoneId"',
                                  );

                                  // Validate IDs before proceeding
                                  if (userId.length < 3 || zoneId.length < 3) {
                                    print(
                                      'ERROR: IDs too short - userId length: ${userId.length}, zoneId length: ${zoneId.length}',
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'IDs invalides - trop courts',
                                        ),
                                        backgroundColor: Colors.red.shade600,
                                      ),
                                    );
                                    return;
                                  }

                                  _assignRegionToDelegate(
                                    zoneId,
                                    userId,
                                    delegate['username'] ?? 'Délégué',
                                    zone['name'] ?? 'Région',
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            // Remove Delegate button (only show if zone has a delegate)
            if (zone['user'] != null)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();

                  // Get zone ID for removal
                  String zoneId = '';
                  for (String key in [
                    'zoneID',
                    'uuid',
                    'zone_uuid',
                    'zoneUuid',
                    'zone_id',
                    'zoneId',
                    'ID',
                    'id',
                  ]) {
                    if (zone.containsKey(key) && zone[key] != null) {
                      zoneId = zone[key].toString();
                      break;
                    }
                  }

                  if (zoneId.isNotEmpty) {
                    // Show confirmation dialog
                    showDialog(
                      context: context,
                      builder: (BuildContext confirmContext) {
                        return AlertDialog(
                          title: Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: Colors.orange.shade600,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text('Confirmer le retrait'),
                            ],
                          ),
                          content: Text(
                            'Êtes-vous sûr de vouloir retirer le délégué "${zone['user']['username']}" de la région "${zone['name']}" ?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(confirmContext).pop(),
                              child: const Text('Annuler'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(confirmContext).pop();
                                _removeRegionFromDelegate(
                                  zoneId,
                                  zone['name'] ?? 'Région',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retirer'),
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
                icon: Icon(
                  Icons.person_remove,
                  color: Colors.red.shade600,
                  size: 18,
                ),
                label: Text(
                  'Retirer Délégué',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Annuler',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> uploadExcelFile(bool isRecouvrementFile) async {
    final XTypeGroup typeGroup = XTypeGroup(
      label: 'Excel',
      extensions: ['xlsx'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          isRecouvrementFile
              ? 'http://estcommand.ddns.net:8080/api/v1/zones/upload-recouvrement'
              : 'http://estcommand.ddns.net:8080/api/v1/zones/upload-objectifs',
        ),
      );
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        fetchZoneData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Fichier ${isRecouvrementFile ? 'recouvrement' : 'objectif'} uploadé avec succès',
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('Échec de l\'upload du fichier'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final crossAxisCount = isNarrow
        ? 1
        : (MediaQuery.of(context).size.width < 900 ? 2 : 3);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Statistiques des ventes',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.topRight,
              colors: [
                Color(0xFFE57373), // Soft red
                Color(0xFFD32F2F), // Medium red
              ],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('auth_token');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(orders: []),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFEBEE), // Very light red/pink
              Color(0xFFFFCDD2), // Light red/pink
              Color(0xFFEF9A9A), // Soft red
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
          child: Column(
            children: [
              // Compact Header with Toggle
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                  child: Column(
                    children: [
                      isMobile
                          ? Column(
                              children: [
                                // Mobile: Title on top
                                Row(
                                  children: [
                                    Icon(
                                      isRecouvrement
                                          ? Icons.monetization_on
                                          : Icons.flag,
                                      color: isRecouvrement
                                          ? Colors.green.shade600
                                          : Colors.blue.shade600,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isRecouvrement
                                          ? 'Recouvrement'
                                          : 'Objectifs',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Mobile: Toggle below
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: CupertinoSegmentedControl<bool>(
                                    groupValue: isRecouvrement,
                                    children: <bool, Widget>{
                                      true: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.monetization_on,
                                              size: 16,
                                              color: Colors.green,
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Recouv',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      false: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.flag,
                                              size: 16,
                                              color: Colors.blue,
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Obj',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    },
                                    onValueChanged: (val) {
                                      setState(() {
                                        isRecouvrement = val;
                                      });
                                    },
                                    selectedColor: isRecouvrement
                                        ? Colors.green.shade600
                                        : Colors.blue.shade600,
                                    borderColor: Colors.grey.shade300,
                                    pressedColor:
                                        (isRecouvrement
                                                ? Colors.green.shade600
                                                : Colors.blue.shade600)
                                            .withOpacity(0.2),
                                    unselectedColor: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Icon(
                                  isRecouvrement
                                      ? Icons.monetization_on
                                      : Icons.flag,
                                  color: isRecouvrement
                                      ? Colors.green.shade600
                                      : Colors.blue.shade600,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isRecouvrement ? 'Recouvrement' : 'Objectifs',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: CupertinoSegmentedControl<bool>(
                                    groupValue: isRecouvrement,
                                    children: <bool, Widget>{
                                      true: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.monetization_on,
                                              size: 16,
                                              color: Colors.green,
                                            ),
                                            const SizedBox(width: 4),
                                            const Text(
                                              'Recouv',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      false: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.flag,
                                              size: 16,
                                              color: Colors.blue,
                                            ),
                                            const SizedBox(width: 4),
                                            const Text(
                                              'Obj',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    },
                                    onValueChanged: (val) {
                                      setState(() {
                                        isRecouvrement = val;
                                      });
                                    },
                                    selectedColor: isRecouvrement
                                        ? Colors.green.shade600
                                        : Colors.blue.shade600,
                                    borderColor: Colors.grey.shade300,
                                    pressedColor:
                                        (isRecouvrement
                                                ? Colors.green.shade600
                                                : Colors.blue.shade600)
                                            .withOpacity(0.2),
                                    unselectedColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: isMobile ? 8 : 12),

              // Search Bar + Admin Controls
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 8.0 : 12.0),
                  child: isMobile
                      ? Column(
                          children: [
                            // Mobile: Search bar on top
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Rechercher zone ou délégué...',
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.blue.shade400,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                isDense: true,
                              ),
                              onChanged: _filterZones,
                              style: const TextStyle(fontSize: 14),
                            ),
                            // Mobile: Admin controls below search (if admin)
                            if (isAdmin || isSuperUser) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings,
                                    color: Colors.orange.shade600,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => uploadExcelFile(true),
                                      icon: const Icon(
                                        Icons.upload_file,
                                        size: 12,
                                      ),
                                      label: const Text(
                                        'Recouvrement',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        minimumSize: const Size(0, 28),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => uploadExcelFile(false),
                                      icon: const Icon(
                                        Icons.upload_file,
                                        size: 12,
                                      ),
                                      label: const Text(
                                        'Objectif',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        minimumSize: const Size(0, 28),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        )
                      : Row(
                          children: [
                            // Desktop: Search bar
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Rechercher zone ou délégué...',
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Colors.grey.shade600,
                                    size: 20,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.blue.shade400,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  isDense: true,
                                ),
                                onChanged: _filterZones,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),

                            // Desktop: Admin Controls
                            if (isAdmin || isSuperUser) ...[
                              const SizedBox(width: 12),
                              Icon(
                                Icons.admin_panel_settings,
                                color: Colors.orange.shade600,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => uploadExcelFile(true),
                                icon: const Icon(Icons.upload_file, size: 14),
                                label: Text(
                                  isNarrow ? 'Rec' : 'Recouv',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  minimumSize: const Size(0, 32),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                onPressed: () => uploadExcelFile(false),
                                icon: const Icon(Icons.upload_file, size: 14),
                                label: Text(
                                  'Obj',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  minimumSize: const Size(0, 32),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),

              SizedBox(height: isMobile ? 8 : 12),

              // Admin Instructions (only visible to admins)
              if (isAdmin)
                Card(
                  elevation: 1,
                  color: Colors.orange.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.orange.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cliquez sur une région pour assigner un délégué',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (isAdmin) SizedBox(height: isMobile ? 8 : 12),

              // Stats Grid
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.analytics,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chargement des statistiques...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const CircularProgressIndicator(),
                          ],
                        ),
                      )
                    : _filteredZoneData.isEmpty && _zoneData.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Aucune zone trouvée',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Essayez de modifier votre recherche',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _zoneData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _hasError ? Icons.error_outline : Icons.analytics,
                              size: 64,
                              color: _hasError
                                  ? Colors.red.shade400
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _hasError
                                  ? 'Erreur de chargement'
                                  : 'Aucune donnée disponible',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _hasError
                                  ? _errorMessage
                                  : 'Vérifiez votre connexion',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                _initializeData();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: isMobile ? 8 : 12,
                          mainAxisSpacing: isMobile ? 8 : 12,
                          childAspectRatio: isMobile
                              ? 2.4
                              : (isNarrow ? 2.2 : 1.8),
                        ),
                        itemCount: _filteredZoneData.length,
                        itemBuilder: (context, index) {
                          final zone = _filteredZoneData[index];
                          final taux = isRecouvrement
                              ? double.tryParse(zone['PrRecouv'].toString()) ??
                                    0.0
                              : double.tryParse(
                                      zone['PrReaVente'].toString(),
                                    ) ??
                                    0.0;

                          return _buildCompactZoneCard(zone, taux, isMobile);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactZoneCard(
    Map<String, dynamic> zone,
    double taux, [
    bool isMobile = false,
  ]) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
      ),
      child: InkWell(
        onTap: isAdmin ? () => _showDelegateAssignmentDialog(zone) : null,
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
                _getPerformanceColor(taux).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
            border: Border.all(
              color: _getPerformanceColor(taux).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Admin indicator in top-right corner
              if (isAdmin)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.orange.shade300,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with zone name and percentage
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isMobile ? 4 : 6),
                          decoration: BoxDecoration(
                            color: (isRecouvrement ? Colors.green : Colors.blue)
                                .shade50,
                            borderRadius: BorderRadius.circular(
                              isMobile ? 4 : 6,
                            ),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: isRecouvrement
                                ? Colors.green.shade600
                                : Colors.blue.shade600,
                            size: isMobile ? 14 : 16,
                          ),
                        ),
                        SizedBox(width: isMobile ? 6 : 8),
                        Expanded(
                          child: Text(
                            zone['name'] ?? 'Zone sans nom',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: isMobile ? 4 : 6),
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 6 : 8,
                              vertical: isMobile ? 3 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getPerformanceColor(
                                taux,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                isMobile ? 10 : 12,
                              ),
                              border: Border.all(
                                color: _getPerformanceColor(
                                  taux,
                                ).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '${(taux * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                fontWeight: FontWeight.bold,
                                color: _getPerformanceColor(taux),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isMobile ? 8 : 12),

                    // Delegate info
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: isMobile ? 12 : 14,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: isMobile ? 3 : 4),
                        Expanded(
                          child: Text(
                            zone['user']?['username'] ?? 'Non assigné',
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isMobile ? 6 : 8),

                    // Stats info
                    Text(
                      isRecouvrement
                          ? '${zone['Recouv']} / ${zone['SFRecouv']}'
                          : '${zone['ventes']} / ${zone['ObjVentes']}',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: isMobile ? 6 : 8),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(isMobile ? 3 : 4),
                      child: LinearProgressIndicator(
                        value: taux.clamp(0.0, 1.0),
                        minHeight: isMobile ? 5 : 6,
                        backgroundColor: Colors.grey.shade200,
                        color: _getPerformanceColor(taux),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPerformanceColor(double percentage) {
    if (percentage >= 0.8) return Colors.green.shade600;
    if (percentage >= 0.6) return Colors.orange.shade600;
    return Colors.red.shade600;
  }
}

Future<void> setAdminRolesForTesting() async {
  final prefs = await SharedPreferences.getInstance();
  final roles = {
    'isAdmin': true,
    'isSuperUser': false,
    'isCommercUser': false,
    'isclient': false,
  };
  await prefs.setString('roles', jsonEncode(roles));
}
