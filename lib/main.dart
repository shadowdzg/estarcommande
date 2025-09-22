import 'dart:convert';

import 'package:EstStarCommande/purchase_orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'services/update_service.dart';
import 'core/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup dependency injection
  await setupServiceLocator();

  runApp(const ProviderScope(child: MyApp()));
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
  String _loadingMessage = "Initialisation...";
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _loadingMessage = "Vérification de l'authentification...";
        _hasError = false;
      });

      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Show message briefly

      await _checkRoleAndNavigate();

      // Check for updates after navigation
      _checkForUpdates();
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    }
  }

  Future<void> _checkForUpdates() async {
    // Wait a bit to ensure the user has navigated
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      debugPrint('Main: Calling update check...');
      UpdateService.checkForServerUpdate(context);
    }
  }

  Future<void> _checkRoleAndNavigate() async {
    setState(() {
      _loadingMessage = "Chargement des données utilisateur...";
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    if (token.isEmpty) {
      setState(() {
        _loadingMessage = "Redirection vers la connexion...";
      });
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
      return;
    }

    try {
      final payload = decodeJwtPayload(token);
      final isAdmin = payload['isadmin'] == 1;
      final isSuper = payload['issuper'] == 1;
      final isAssistant = payload['isassistant'] == 1;
      final isClient = payload['isclient'] == 1;

      setState(() {
        _loadingMessage = "Préparation de l'interface...";
      });

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
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
    } catch (e) {
      // Token might be invalid, redirect to login
      setState(() {
        _loadingMessage = "Session expirée, redirection...";
      });

      await prefs.remove('auth_token');
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    }
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _loadingMessage = "Nouvelle tentative...";
    });
    _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/my_logo.png',
                    height: 80,
                    width: 80,
                  ),
                ),
                const SizedBox(height: 40),

                // App Title
                const Text(
                  'EST STAR Commande',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 2),
                        blurRadius: 4,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),

                if (_hasError) ...[
                  // Error State
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Problème de connexion',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Le serveur semble indisponible.\nVeuillez réessayer dans quelques instants.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Loading State
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _loadingMessage,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // Version info
                Text(
                  'Version 2.3.6',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
