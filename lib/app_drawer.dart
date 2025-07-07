import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'purchase_orders_page.dart';
import 'SalesStatsPage.dart';
import 'settings.dart';
import 'profile_page.dart';
import 'Chatbot.dart';
import 'login_page.dart';
import 'dart:convert';

Map<String, dynamic> decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return {};
  final payload = base64.normalize(parts[1]);
  final decoded = utf8.decode(base64.decode(payload));
  return json.decode(decoded);
}

class AppDrawer extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  const AppDrawer({super.key, required this.orders});

  Future<Map<String, dynamic>> _getPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return decodeJwtPayload(token);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getPayload(),
      builder: (context, snapshot) {
        final payload = snapshot.data ?? {};
        final isAdmin = payload['isadmin'] == 1;
        final isSuper = payload['issuper'] == 1;

        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.blue),
                child: Text(
                  'Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.shopping_cart),
                title: const Text('PO Interface'),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PurchaseOrdersPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Sales Stats'),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SalesStatsPage(),
                    ),
                  );
                },
              ),
              if (isAdmin || isSuper)
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminPanelPage(),
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('auth_token') ?? '';
                  final payload = decodeJwtPayload(token);
                  final username = payload['username'] ?? '';
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfilePage(username: username),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bolt),
                title: const Text('ChatBot'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatBotPage(orders: orders),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('auth_token');
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
