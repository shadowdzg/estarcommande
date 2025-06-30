import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_drawer.dart';

class ProfilePage extends StatefulWidget {
  final String username;
  const ProfilePage({super.key, required this.username});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // TODO: Replace with your API call to change password
    await Future.delayed(const Duration(seconds: 1));

    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed!')),
    );
    _passwordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Username: ${widget.username}', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 32),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (v) => v == null || v.length < 6 ? 'Min 6 chars' : null,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loading ? null : _changePassword,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('Change Password'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}