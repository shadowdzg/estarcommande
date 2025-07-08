import 'dart:convert';

import 'package:EstStarCommande/purchase_orders_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'services/update_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Air Time',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: const EntryPoint(),
    );
  }
}

Map<String, dynamic> decodeJwtPayload(String token) {
  if (token.isEmpty) return {};
  final parts = token.split('.');
  if (parts.length != 3) return {};
  final payload = base64Url.normalize(parts[1]);
  final payloadMap = json.decode(utf8.decode(base64Url.decode(payload)));
  return payloadMap;
}

class EntryPoint extends StatefulWidget {
  const EntryPoint({super.key});

  @override
  State<EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<EntryPoint> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRoleAndNavigate();
      // Check for updates after navigation
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    // Wait a bit to ensure the user has navigated
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      UpdateService.checkForServerUpdate(context);
    }
  }

  Future<void> _checkRoleAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    final payload = decodeJwtPayload(token);
    final isAdmin = payload['isadmin'] == 1;
    final isSuper = payload['issuper'] == 1;
    final isAssistant = payload['isassistant'] == 1;
    final isClient = payload['isclient'] == 1;

    if (isAdmin || isSuper) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PurchaseOrdersPage()),
      );
    } else if (isAssistant || isClient) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PurchaseOrdersPage()),
      );
    } else {
      // fallback to login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
