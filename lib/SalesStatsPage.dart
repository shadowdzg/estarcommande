import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_selector/file_selector.dart';

import 'purchase_orders_page.dart';
import 'login_page.dart';
import 'settings.dart';
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
        setState(() {
          _zoneData = json.decode(response.body);
        });
      } else {
        print('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload successful')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 500;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Stats'),
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
      drawer: const AppDrawer(), // <-- Use the shared drawer here
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  isRecouvrement ? 'Recouvrement View' : 'Objectif View',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Expanded(
                  child: CupertinoSegmentedControl<bool>(
                    groupValue: isRecouvrement,
                    children: <bool, Widget>{
                      true: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.attach_money,
                              size: 22,
                              color: Colors.green,
                            ),
                            if (!isNarrow) ...[
                              const SizedBox(width: 8),
                              const Text('Recouvrement'),
                            ],
                          ],
                        ),
                      ),
                      false: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.flag,
                              size: 22,
                              color: Colors.blue,
                            ),
                            if (!isNarrow) ...[
                              const SizedBox(width: 8),
                              const Text('Objectif'),
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
                    selectedColor: Theme.of(context).colorScheme.primary,
                    borderColor: Theme.of(context).colorScheme.primary,
                    pressedColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    unselectedColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (isAdmin || isSuperUser) ...[
                  ElevatedButton.icon(
                    onPressed: () => uploadExcelFile(true),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Recouvrement'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => uploadExcelFile(false),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Objectif'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _zoneData.isEmpty
                  ? const Center(child: CircularProgressIndicator())
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
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  zone['name'] ?? 'Unnamed Zone',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Delegue: ${zone['user']?['username'] ?? ''}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isRecouvrement
                                      ? 'Recouvrement: ${zone['Recouv']} / ${zone['SFRecouv']}'
                                      : 'Ventes: ${zone['ventes']} / ${zone['ObjVentes']}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${(taux * 100).toStringAsFixed(1)}%'),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: taux.clamp(0.0, 1.0),
                                  minHeight: 8,
                                  backgroundColor: Colors.grey.shade300,
                                  color: isRecouvrement
                                      ? Colors.green
                                      : Colors.blue,
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
