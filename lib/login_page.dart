import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Add this to pubspec.yaml
import 'purchase_orders_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';
import 'profile_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    final response = await http.post(
      Uri.parse('http://92.222.248.113:3000/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': emailController.text.trim(),
        'password': passwordController.text.trim(),
      }),
    );

    print('Status code: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        final userData = data['user']; // Assuming the user data is here

        if (token != null && token.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);

          final userid = decodeToken(token);
          await prefs.setString('userid', userid);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PurchaseOrdersPage()),
          );
        } else {
          _showError('Access token not found.');
        }
      } catch (e) {
        _showError('Failed to parse response.');
        print('JSON decode error: $e');
      }
    } else {
      _showError('Login failed. Check your credentials.');
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
      backgroundColor: const Color(0xFFEFEFEF), // Soft background
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/my_logo.png', height: 200),
              const SizedBox(height: 20),
              Text(
                "Bienvenue",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: emailController,
                      label: 'Username',
                      icon: Icons.person_outline,
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Username is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      textInputAction:
                          TextInputAction.done, // 👈 enables Enter key to act
                      onFieldSubmitted: (_) => _login(), // 👈 triggers _login
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Login',
                          style: GoogleFonts.poppins(
                            textStyle: const TextStyle(
                              fontSize: 18,
                              color:
                                  Colors.white, // 👈 This works correctly now
                              fontWeight: FontWeight.w500,
                            ),
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
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
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
