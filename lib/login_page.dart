import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Add this to pubspec.yaml
import 'purchase_orders_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';
import 'profile_page.dart';
import 'services/network_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isServerDown = false;

  // Network and server state
  final NetworkService _networkService = NetworkService();
  ServerConfiguration? _currentServerConfig;
  String _connectivityStatus = 'Checking...';
  bool _isOnline = false;
  bool _showServerOptions = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeNetworkStatus();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _networkService.connectivityStream.listen((_) {
      _checkConnectivityStatus();
    });
  }

  Future<void> _initializeNetworkStatus() async {
    await _checkConnectivityStatus();
    await _getBestServer();
  }

  Future<void> _checkConnectivityStatus() async {
    final isOnline = await _networkService.hasInternetConnectivity();
    final description = await _networkService.getConnectivityDescription();

    if (mounted) {
      setState(() {
        _isOnline = isOnline;
        _connectivityStatus = description;
      });
    }
  }

  Future<void> _getBestServer() async {
    final serverConfig = await _networkService.getBestAvailableServer();
    if (mounted) {
      setState(() {
        _currentServerConfig = serverConfig;
      });
    }
  }

  Future<void> _switchServer(ServerType serverType) async {
    setState(() {
      _isLoading = true;
    });

    await _networkService.setPreferredServerType(serverType);
    await _getBestServer();

    setState(() {
      _isLoading = false;
      _showServerOptions = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Switched to ${_currentServerConfig?.displayName ?? 'server'}',
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isServerDown = false;
    });

    try {
      if (_currentServerConfig == null || !_currentServerConfig!.isAvailable) {
        _showError('No server available. Please check your connection.');
        return;
      }

      final loginUrl = '${_currentServerConfig!.apiBaseUrl}/auth/login';

      final response = await http
          .post(
            Uri.parse(loginUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': emailController.text.trim(),
              'password': passwordController.text.trim(),
            }),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'Timeout - Le serveur met trop de temps à répondre',
              );
            },
          );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body);
          final token = data['access_token'];
          // final userData = data['user']; // Future use for user profile

          if (token != null && token.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_token', token);

            final userid = decodeToken(token);
            await prefs.setString('userid', userid);

            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const PurchaseOrdersPage()),
              );
            }
          } else {
            _showError('Access token not found.');
          }
        } catch (e) {
          _showError('Failed to parse response.');
          print('JSON decode error: $e');
        }
      } else if (response.statusCode == 401) {
        _showError(
          'Identifiants incorrects. Vérifiez votre nom d\'utilisateur et mot de passe.',
        );
      } else if (response.statusCode >= 500) {
        setState(() {
          _isServerDown = true;
        });
        _showError(
          'Le serveur rencontre des difficultés. Veuillez réessayer plus tard.',
        );
      } else {
        _showError(
          'Erreur de connexion (${response.statusCode}). Veuillez réessayer.',
        );
      }
    } catch (e) {
      print('Login error: $e');
      setState(() {
        _isServerDown = true;
      });

      String errorMessage = 'Erreur de connexion';
      if (e.toString().contains('Timeout')) {
        errorMessage =
            'Le serveur met trop de temps à répondre. Veuillez réessayer.';
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        errorMessage = 'Problème de réseau. Vérifiez votre connexion internet.';
      } else {
        errorMessage =
            'Le serveur semble indisponible. Veuillez réessayer plus tard.';
      }

      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 20,
                shadowColor: Colors.black.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          'assets/images/my_logo.png',
                          height: 80,
                          width: 80,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Bienvenue",
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Connectez-vous à votre compte",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Network status and server info
                      _buildNetworkStatusCard(),

                      const SizedBox(height: 24),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: emailController,
                              label: 'Nom d\'utilisateur',
                              icon: Icons.person_outline,
                              keyboardType: TextInputType.text,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Le nom d\'utilisateur est requis';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: passwordController,
                              label: 'Mot de passe',
                              icon: Icons.lock_outline,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _login(),
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return 'Le mot de passe doit contenir au moins 6 caractères';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Server selection button
                            _buildServerSelectionButton(),

                            const SizedBox(height: 16),

                            // Server status indicator
                            if (_isServerDown)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber,
                                      color: Colors.orange.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Serveur temporairement indisponible',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Login button
                            Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isLoading
                                      ? [
                                          Colors.grey.shade400,
                                          Colors.grey.shade500,
                                        ]
                                      : [
                                          const Color(0xFFE57373), // Soft red
                                          const Color(0xFFD32F2F), // Medium red
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (_isLoading ? Colors.grey : Colors.red)
                                            .withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Connexion...',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'Se connecter',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.red.shade600, size: 20),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 2),
          ),
          errorStyle: GoogleFonts.poppins(
            color: Colors.red.shade600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _isOnline ? Icons.wifi : Icons.wifi_off,
                  color: _isOnline ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connectivityStatus,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (_currentServerConfig != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _currentServerConfig!.isAvailable
                        ? Icons.cloud_done
                        : Icons.cloud_off,
                    color: _currentServerConfig!.isAvailable
                        ? Colors.green
                        : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentServerConfig!.isAvailable
                          ? _currentServerConfig!.displayName
                          : 'Server unavailable',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServerSelectionButton() {
    return Container(
      width: double.infinity,
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showServerOptions = !_showServerOptions;
              });
            },
            icon: Icon(
              _showServerOptions ? Icons.expand_less : Icons.expand_more,
              size: 20,
            ),
            label: Text(
              'Server Options',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.grey.shade700,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_showServerOptions) ...[
            const SizedBox(height: 12),
            _buildServerOptionCard(ServerType.online),
            const SizedBox(height: 8),
            _buildServerOptionCard(ServerType.local),
          ],
        ],
      ),
    );
  }

  Widget _buildServerOptionCard(ServerType serverType) {
    final isSelected = _currentServerConfig?.type == serverType;
    final displayName = serverType == ServerType.local
        ? '🏠 Local Server (192.168.200.33)'
        : '🌍 Online Server (estcommand.ddns.net)';
    final description = serverType == ServerType.local
        ? 'Fast, local network only'
        : 'Accessible from anywhere';

    return InkWell(
      onTap: _isLoading ? null : () => _switchServer(serverType),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Colors.blue.shade600 : Colors.grey.shade500,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.blue.shade700
                          : Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  decodeToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      print('Invalid token');
      return;
    }

    final payload = base64Url.normalize(parts[1]);
    final payloadMap = json.decode(utf8.decode(base64Url.decode(payload)));

    print("Decoded token payload: ${payloadMap['sub']}");
    return payloadMap['sub'];
  }
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
    _checkRoleAndNavigate();
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
    final username = payload['username'] ?? 'Unknown';

    if (isAdmin || isSuper) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminPanelPage()),
      );
    } else if (isAssistant || isClient) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ProfilePage(username: username)),
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
