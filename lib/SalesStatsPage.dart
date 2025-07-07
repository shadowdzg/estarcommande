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
  bool isAdmin = false;
  bool isSuperUser = false;

  @override
  void initState() {
    super.initState();
    fetchZoneData();
    _checkAdmin();
    _checkSuperUser();
  }

  Future<void> fetchZoneData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        print('No auth token found');
        return;
      }

      final response = await http.get(
        Uri.parse('http://92.222.248.113:3000/api/v1/zones'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _zoneData = data;
        });
      } else {
        print('Failed to load data: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Erreur lors du chargement des données'),
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
      print('Error fetching data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Erreur de connexion'),
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
              ? 'http://92.222.248.113:3000/api/v1/zones/upload-recouvrement'
              : 'http://92.222.248.113:3000/api/v1/zones/upload-objectifs',
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
    final isNarrow = MediaQuery.of(context).size.width < 500;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Statistiques des ventes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header Card with Toggle
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          isRecouvrement ? Icons.monetization_on : Icons.flag,
                          color: isRecouvrement
                              ? Colors.green.shade600
                              : Colors.blue.shade600,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isRecouvrement ? 'Vue Recouvrement' : 'Vue Objectif',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CupertinoSegmentedControl<bool>(
                        groupValue: isRecouvrement,
                        children: <bool, Widget>{
                          true: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.monetization_on,
                                  size: 20,
                                  color: Colors.green,
                                ),
                                if (!isNarrow) ...[
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Recouvrement',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          false: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.flag,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                                if (!isNarrow) ...[
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Objectif',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
              ),
            ),

            const SizedBox(height: 16),

            // Upload buttons for admin/super users
            if (isAdmin || isSuperUser) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Administration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => uploadExcelFile(true),
                              icon: const Icon(Icons.upload_file, size: 20),
                              label: const Text('Upload Recouvrement'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => uploadExcelFile(false),
                              icon: const Icon(Icons.upload_file, size: 20),
                              label: const Text('Upload Objectif'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Stats List
            Expanded(
              child: _zoneData.isEmpty
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
                  : ListView.builder(
                      itemCount: _zoneData.length,
                      itemBuilder: (context, index) {
                        final zone = _zoneData[index];
                        final taux = isRecouvrement
                            ? double.tryParse(zone['PrRecouv'].toString()) ??
                                  0.0
                            : double.tryParse(zone['PrReaVente'].toString()) ??
                                  0.0;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            (isRecouvrement
                                                    ? Colors.green
                                                    : Colors.blue)
                                                .shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.location_on,
                                        color: isRecouvrement
                                            ? Colors.green.shade600
                                            : Colors.blue.shade600,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            zone['name'] ?? 'Zone sans nom',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Délégué: ${zone['user']?['username'] ?? 'Non assigné'}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getPerformanceColor(
                                          taux,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _getPerformanceColor(
                                            taux,
                                          ).withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        '${(taux * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _getPerformanceColor(taux),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                Text(
                                  isRecouvrement
                                      ? 'Recouvrement: ${zone['Recouv']} / ${zone['SFRecouv']}'
                                      : 'Ventes: ${zone['ventes']} / ${zone['ObjVentes']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: taux.clamp(0.0, 1.0),
                                    minHeight: 8,
                                    backgroundColor: Colors.grey.shade200,
                                    color: _getPerformanceColor(taux),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
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
  print('Admin roles set for testing: $roles');
}
