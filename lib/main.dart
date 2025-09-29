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
        // 🎨 New monochrome theme with red accent
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFDC2626), // Primary red
          onPrimary: Colors.white,
          secondary: Color(0xFF1F2937), // Dark grey
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF1F2937),
          background: Color(0xFFF9FAFB), // Light grey background
          onBackground: Color(0xFF1F2937),
          error: Color(0xFFDC2626),
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FAFB), // Light grey
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFDC2626), // Primary red
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
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
              Color(0xFFF9FAFB), // Light grey
              Color(0xFFE5E7EB), // Medium grey
              Color(0xFFD1D5DB), // Darker grey
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
                    color: Colors.black, // Black text
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
                          color: Color(0xFFDC2626), // Primary red
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Problème de connexion',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
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
                            backgroundColor: const Color(0xFFDC2626),
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFDC2626),
                          ),
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
