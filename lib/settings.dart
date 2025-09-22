import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_typeahead/flutter_typeahead.dart'; // For TypeAheadFormField
import 'package:shared_preferences/shared_preferences.dart'; // For SharedPreferences
import 'app_drawer.dart';
import 'services/update_service.dart';

enum UserRole { admin, superuser, commercial, delegue, user }

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({Key? key}) : super(key: key);

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class User {
  final String? username;
  final String? role;
  final String? id; // Add this

  User({this.username, this.role, this.id}); // Update constructor

  factory User.fromJson(Map<String, dynamic> json) {
    // Debug: Print all available fields
    print('User JSON fields: ${json.keys.toList()}');
    print('User JSON data: $json');

    // Determine role based on flags
    String role = 'Client';
    if (json['isAdmin'] == 1) {
      role = 'Admin';
    } else if (json['isSuperUser'] == 1) {
      role = 'Superuser';
    } else if (json['isCommercUser'] == 1) {
      role = 'Commercial';
    } else if (json['isDelegue'] == 1) {
      role = 'Délégué';
    }

    // Try to find user ID from different possible field names
    String userId = '';
    for (String key in [
      'usersID',
      'userID',
      'uuid',
      'user_uuid',
      'userUuid',
      'user_id',
      'userId',
      'ID',
      'id',
    ]) {
      if (json.containsKey(key) && json[key] != null) {
        userId = json[key].toString();
        print('Found user ID in field "$key": $userId');
        break;
      }
    }

    if (userId.isEmpty) {
      print('WARNING: No user ID found in any expected field');
    }

    return User(username: json['username'] ?? '', role: role, id: userId);
  }
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  int _selectedTabIndex = 0;

  final List<String> _tabs = ['Users', 'Clients', 'Products', 'Settings'];

  List<User> _users = [];
  bool _isLoadingUsers = false;
  String _userError = '';

  // WebSocket Settings Variables
  bool _useLocalServer = false;
  bool _enableWebSocket = true;
  bool _isTestingConnection = false;
  String _connectionStatus = 'Unknown';
  bool _isDisposed = false;

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _userError = '';
    });

    try {
      print('=== FETCHING USERS ===');
      final response = await http.get(
        Uri.parse('http://estcommand.ddns.net:8080/api/v1/users'),
      );

      print('Users API Response status: ${response.statusCode}');
      print('Users API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        print('Total users received: ${data.length}');
        if (data.isNotEmpty) {
          print('First user data: ${data.first}');
          print('Available fields in first user: ${data.first.keys.toList()}');
        }

        setState(() {
          _users = data.map((json) => User.fromJson(json)).toList();
          _isLoadingUsers = false;
        });

        print('Users successfully parsed: ${_users.length}');
        for (var user in _users) {
          print('User: ${user.username}, ID: ${user.id}, Role: ${user.role}');
        }
      } else {
        setState(() {
          _isLoadingUsers = false;
          _userError = 'Failed to load users: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('Error fetching users: $e');
      setState(() {
        _isLoadingUsers = false;
        _userError = 'Error: $e';
      });
    }
  }

  // Simulated current user role - Replace this with real data from API later
  final String currentUserRole =
      'admin'; // can be 'admin', 'superuser', 'assistant', 'delegue', 'client'

  bool get _canAddUser => ['admin', 'superuser'].contains(currentUserRole);

  // Client state
  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  bool _isLoadingClients = false;
  String _clientError = '';
  final TextEditingController _clientSearchController = TextEditingController();

  // Product state
  List<Product> _products = [];
  bool _isLoadingProducts = false;
  String _productError = '';

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _fetchUsers();
    _fetchProducts();
    _loadWebSocketSettings();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _clientSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchClients() async {
    setState(() {
      _isLoadingClients = true;
      _clientError = '';
    });

    try {
      final response = await http.get(
        Uri.parse('http://estcommand.ddns.net:8080/api/v1/clients'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _clients = data.map((json) => Client.fromJson(json)).toList();
          _filteredClients = _clients; // Initialize filtered list
          _isLoadingClients = false;
        });
      } else {
        setState(() {
          _isLoadingClients = false;
          _clientError = 'Failed to load clients: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingClients = false;
        _clientError = 'Error: $e';
      });
    }
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _productError = '';
    });

    try {
      final response = await http.get(
        Uri.parse('http://estcommand.ddns.net:8080/api/v1/products'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _products = data.map((json) => Product.fromJson(json)).toList();
          _isLoadingProducts = false;
        });
      } else {
        setState(() {
          _isLoadingProducts = false;
          _productError = 'Failed to load products: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingProducts = false;
        _productError = 'Error: $e';
      });
    }
  }

  void _filterClients(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredClients = _clients;
      } else {
        _filteredClients = _clients.where((client) {
          return (client.clientName?.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ??
                  false) ||
              (client.wilaya?.toLowerCase().contains(query.toLowerCase()) ??
                  false) ||
              (client.clientsID?.toLowerCase().contains(query.toLowerCase()) ??
                  false);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Panel',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              // Reset the update check timer
              await UpdateService.resetUpdateCheckTimer();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Update timer reset'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            tooltip: 'Reset Update Timer',
          ),
          IconButton(
            icon: const Icon(Icons.system_update, color: Colors.white),
            onPressed: () {
              UpdateService.manualUpdateCheck(context);
            },
            tooltip: 'Check for Updates',
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade300, Colors.red.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.red.shade50, Colors.red.shade100],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: BottomNavigationBar(
                  currentIndex: _selectedTabIndex,
                  onTap: (index) => setState(() => _selectedTabIndex = index),
                  items: _tabs
                      .map(
                        (title) => BottomNavigationBarItem(
                          icon: Icon(
                            title == 'Users'
                                ? Icons.people
                                : title == 'Clients'
                                ? Icons.business
                                : title == 'Products'
                                ? Icons.inventory
                                : Icons.settings,
                            color: Colors.red.shade700,
                          ),
                          label: title,
                        ),
                      )
                      .toList(),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedItemColor: Colors.red.shade700,
                  unselectedItemColor: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: _buildTabContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: const AppDrawer(orders: []),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildUserManagement();
      case 1:
        return _buildClientManagement();
      case 2:
        return _buildProductManagement();
      case 3:
        return _buildWebSocketSettings();
      default:
        return const Center(child: Text('Unknown tab'));
    }
  }

  // 🔧 WebSocket Settings Methods
  Future<void> _loadWebSocketSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _useLocalServer = prefs.getBool('use_local_server') ?? false;
    _enableWebSocket =
        prefs.getBool('enable_websocket') ?? false; // Disable by default
    await _testConnection();
    if (mounted && !_isDisposed) setState(() {});
  }

  Future<void> _testConnection() async {
    // Check if widget is disposed before starting
    if (_isDisposed || !mounted) return;

    if (mounted) {
      setState(() {
        _isTestingConnection = true;
        _connectionStatus = 'Testing...';
      });
    }

    try {
      // Get the stored JWT token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      // Check again after async operation
      if (_isDisposed || !mounted) return;

      if (token.isEmpty) {
        _connectionStatus = 'No Auth Token ❌';
        if (mounted && !_isDisposed) {
          setState(() {
            _isTestingConnection = false;
          });
        }
        return;
      }

      final serverHost = _useLocalServer
          ? '192.168.200.34'
          : 'estcommand.ddns.net';

      // Include JWT token in the request
      final response = await http
          .get(
            Uri.parse('http://$serverHost:8080/api/v1/commands?take=1'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: 5));

      // Check again after network request
      if (_isDisposed || !mounted) return;

      if (response.statusCode == 200) {
        _connectionStatus = 'Connected ✅';
      } else if (response.statusCode == 401) {
        _connectionStatus = 'Auth Failed (401) ❌';
      } else {
        _connectionStatus = 'Error ${response.statusCode} ❌';
      }
    } catch (e) {
      // Check again after exception
      if (_isDisposed || !mounted) return;
      _connectionStatus = 'Failed ❌ ($e)';
    }

    if (mounted && !_isDisposed) {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  Widget _buildWebSocketSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Server Selection Card
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.dns, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Server Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  RadioListTile<bool>(
                    title: Text('🏠 Local Server'),
                    subtitle: Text(
                      '192.168.200.34:8080 - Fast, local network only',
                    ),
                    value: true,
                    groupValue: _useLocalServer,
                    onChanged: (value) async {
                      setState(() => _useLocalServer = value!);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('use_local_server', value!);
                      await _testConnection();
                    },
                  ),

                  RadioListTile<bool>(
                    title: Text('🌍 Internet Server'),
                    subtitle: Text(
                      'estcommand.ddns.net:8080 - Accessible from anywhere',
                    ),
                    value: false,
                    groupValue: _useLocalServer,
                    onChanged: (value) async {
                      setState(() => _useLocalServer = value!);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('use_local_server', value!);
                      await _testConnection();
                    },
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // WebSocket Configuration Card
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flash_on, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Real-Time Updates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  SwitchListTile(
                    title: Text('Enable WebSocket'),
                    subtitle: Text(
                      _enableWebSocket
                          ? '⚡ Real-time updates (instant)'
                          : '🔄 Polling updates (5 seconds)',
                    ),
                    value: _enableWebSocket,
                    onChanged: (value) async {
                      setState(() => _enableWebSocket = value);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('enable_websocket', value);
                    },
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Connection Status Card
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wifi, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Connection Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  ListTile(
                    leading: Icon(Icons.computer),
                    title: Text('Current Server'),
                    subtitle: Text(
                      _useLocalServer
                          ? '🏠 Local (192.168.200.34:8080)'
                          : '🌍 Internet (estcommand.ddns.net:8080)',
                    ),
                  ),

                  ListTile(
                    leading: Icon(Icons.signal_wifi_4_bar),
                    title: Text('Connection Status'),
                    subtitle: Text(_connectionStatus),
                    trailing: _isTestingConnection
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: Icon(Icons.refresh),
                            onPressed: _testConnection,
                            tooltip: 'Test Connection',
                          ),
                  ),

                  ListTile(
                    leading: Icon(Icons.update),
                    title: Text('Update Method'),
                    subtitle: Text(
                      _enableWebSocket
                          ? '⚡ WebSocket (Real-time)'
                          : '🔄 Polling (5 seconds)',
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          // Apply Settings Button
          Center(
            child: ElevatedButton.icon(
              icon: Icon(Icons.save),
              label: Text('Apply Settings'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Settings saved! Changes will take effect on next app restart.',
                    ),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🧑 User Management
  Widget _buildUserManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manage Users',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_canAddUser)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add User'),
                        onPressed: () => _showCreateUserDialog(context),
                      ),
                    ),
                  if (_canAddUser) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Users'),
                      onPressed: () => _fetchUsers(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Results counter
        if (!_isLoadingUsers && _userError.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Total: ${_users.length} users',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (_isLoadingUsers)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_userError.isNotEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userError,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else if (_users.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No users found',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _getUserRoleColor(
                                  user.role ?? '',
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                _getUserRoleIcon(user.role ?? ''),
                                color: _getUserRoleColor(user.role ?? ''),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.username ?? 'Unknown User',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${user.id ?? 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getUserRoleColor(
                                  user.role ?? '',
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getUserRoleColor(
                                    user.role ?? '',
                                  ).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                user.role ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getUserRoleColor(user.role ?? ''),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: Colors.blue.shade600,
                                  size: 20,
                                ),
                                onPressed: () => _editUserRole(
                                  user.username ?? '',
                                  user.id ?? '',
                                  user.role ?? '',
                                ),
                                tooltip: 'Edit Role',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.lock_outline,
                                  color: Colors.orange.shade600,
                                  size: 20,
                                ),
                                onPressed: () => _changeUserPassword(
                                  user.username ?? '',
                                  user.id ?? '',
                                ),
                                tooltip: 'Change Password',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // 👥 Client Management
  Widget _buildClientManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manage Clients',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _clientSearchController,
                  onChanged: _filterClients,
                  decoration: InputDecoration(
                    hintText: 'Search clients by name, wilaya, or ID...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                    suffixIcon: _clientSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _clientSearchController.clear();
                              _filterClients('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isLoadingClients)
          const Center(child: CircularProgressIndicator())
        else if (_clientError.isNotEmpty)
          Center(
            child: Text(
              _clientError,
              style: const TextStyle(color: Colors.red),
            ),
          )
        else if (_filteredClients.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    _clientSearchController.text.isNotEmpty
                        ? 'No clients found matching "${_clientSearchController.text}"'
                        : 'No clients found',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredClients.length,
              itemBuilder: (context, index) {
                final client = _filteredClients[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                Icons.business,
                                color: Colors.red.shade600,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    client.clientName ?? 'Unknown Client',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${client.clientsID ?? 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                client.wilaya ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        // Results counter
        if (!_isLoadingClients && _clientError.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _clientSearchController.text.isNotEmpty
                  ? 'Found ${_filteredClients.length} of ${_clients.length} clients'
                  : 'Total: ${_clients.length} clients',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Client'),
                  onPressed: () => _showAddClientDialog(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Client'),
                  onPressed: () => _showEditClientDialog(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Client'),
                  onPressed: () => _showDeleteClientDialog(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 📦 Product Management
  Widget _buildProductManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manage Products',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        // Results counter
        if (!_isLoadingProducts && _productError.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Total: ${_products.length} products',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (_isLoadingProducts)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_productError.isNotEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _productError,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else if (_products.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No products found',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                Icons.inventory_2,
                                color: Colors.green.shade600,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.productName ?? 'Unknown Product',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${product.productID ?? 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.purple.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.percent,
                                    size: 12,
                                    color: Colors.purple.shade700,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${product.initialPrice?.toStringAsFixed(2) ?? '0.00'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      color: Colors.blue.shade600,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _showEditProductDialog(product),
                                    tooltip: 'Edit Product',
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.red.shade600,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _showDeleteProductDialog(product),
                                    tooltip: 'Delete Product',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                  onPressed: () => _showAddProductDialog(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  onPressed: () => _fetchProducts(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 🔧 Dialog: Add User

  Future<void> _createUser({
    required String username,
    required String password,
    int? isadmin,
    int? isCl,
    int? isSu,
    int? isCo,
    int? isDel,
    String? clId,
  }) async {
    final url = Uri.parse(
      'http://estcommand.ddns.net:8080/api/v1/auth/register',
    );
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final Map<String, dynamic> requestBody = {
      'username': username,
      'password': password,
    };

    if (isadmin != null) requestBody['isadmin'] = isadmin;
    if (isSu != null) requestBody['isSuperUser'] = isSu;
    if (isCl != null) requestBody['isclient'] = isCl;
    if (isCo != null) requestBody['isCommercUser'] = isCo;
    if (isDel != null) requestBody['isDelegue'] = isDel;
    if (clId != null) requestBody['clientId'] = clId;

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User "$username" created successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${response.statusCode} - ${response.body}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating user: $e')));
    }
  }

  void _showCreateUserDialog(BuildContext context) {
    final _usernameController = TextEditingController();
    final _passwordController = TextEditingController();
    final _extraInfoController = TextEditingController();
    UserRole? _selectedRole;
    String? selectedCrClientName;
    Map<String, String> CreateClientsMap = {};

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Create User',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Select Role',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Divider(thickness: 1.2),
                      RadioListTile<UserRole>(
                        title: const Text('Admin'),
                        value: UserRole.admin,
                        groupValue: _selectedRole,
                        onChanged: (UserRole? value) {
                          setState(() => _selectedRole = value);
                        },
                      ),
                      RadioListTile<UserRole>(
                        title: const Text('SuperUser'),
                        value: UserRole.superuser,
                        groupValue: _selectedRole,
                        onChanged: (UserRole? value) {
                          setState(() => _selectedRole = value);
                        },
                      ),
                      RadioListTile<UserRole>(
                        title: const Text('Commercial'),
                        value: UserRole.commercial,
                        groupValue: _selectedRole,
                        onChanged: (UserRole? value) {
                          setState(() => _selectedRole = value);
                        },
                      ),
                      RadioListTile<UserRole>(
                        title: const Text('Delegue'),
                        value: UserRole.delegue,
                        groupValue: _selectedRole,
                        onChanged: (UserRole? value) {
                          setState(() => _selectedRole = value);
                        },
                      ),
                      RadioListTile<UserRole>(
                        title: const Text('Client'),
                        value: UserRole.user,
                        groupValue: _selectedRole,
                        onChanged: (UserRole? value) {
                          setState(() => _selectedRole = value);
                        },
                      ),
                      if (_selectedRole == UserRole.user)
                        Column(
                          children: [
                            const SizedBox(height: 12),
                            TypeAheadField<String>(
                              builder: (context, controller, focusNode) {
                                return TextField(
                                  controller: _extraInfoController,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Client',
                                    prefixIcon: Icon(Icons.person),
                                    border: OutlineInputBorder(),
                                  ),
                                );
                              },
                              suggestionsCallback: (pattern) async {
                                if (pattern.isEmpty) return [];
                                try {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  final token =
                                      prefs.getString('auth_token') ?? '';

                                  final response = await http.get(
                                    Uri.parse(
                                      'http://estcommand.ddns.net:8080/api/v1/clients/search?term=$pattern',
                                    ),
                                    headers: {
                                      'Authorization': 'Bearer $token',
                                      'Content-Type': 'application/json',
                                    },
                                  );
                                  if (response.statusCode == 200) {
                                    final List<dynamic> clientsJson =
                                        jsonDecode(response.body);
                                    CreateClientsMap = {
                                      for (var client in clientsJson)
                                        client['clientName']:
                                            client['clientsID'],
                                    };
                                    return CreateClientsMap.keys.toList();
                                  } else {
                                    print(
                                      'Client search failed: ${response.statusCode}',
                                    );
                                    return [];
                                  }
                                } catch (e) {
                                  print('Client search error: $e');
                                  return [];
                                }
                              },
                              itemBuilder: (context, suggestion) =>
                                  ListTile(title: Text(suggestion)),
                              onSelected: (suggestion) {
                                _extraInfoController.text = suggestion;
                                selectedCrClientName = suggestion;
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_selectedRole == UserRole.user &&
                        (_extraInfoController.text.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a client')),
                      );
                      return;
                    }

                    Navigator.pop(context);
                    await _createUser(
                      username: _usernameController.text.trim(),
                      password: _passwordController.text.trim(),
                      isadmin: _selectedRole == UserRole.admin ? 1 : null,
                      isCl: _selectedRole == UserRole.user ? 1 : null,
                      isSu: _selectedRole == UserRole.superuser ? 1 : null,
                      isCo: _selectedRole == UserRole.commercial ? 1 : null,
                      isDel: _selectedRole == UserRole.delegue ? 1 : null,
                      clId: _selectedRole == UserRole.user
                          ? CreateClientsMap[selectedCrClientName]
                          : null,
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddClientDialog() {
    final TextEditingController _clientIdController = TextEditingController();
    final TextEditingController _clientNameController = TextEditingController();
    final TextEditingController _phoneController = TextEditingController();
    final TextEditingController _wilayaController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Client'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _clientIdController,
                decoration: const InputDecoration(
                  labelText: 'Client ID (e.g., C050)',
                ),
              ),
              TextField(
                controller: _clientNameController,
                decoration: const InputDecoration(labelText: 'Client Name'),
              ),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                controller: _wilayaController,
                decoration: const InputDecoration(labelText: 'Wilaya'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final String clientId = _clientIdController.text.trim();
              final String clientName = _clientNameController.text.trim();
              final String phone = _phoneController.text.trim();
              final String wilaya = _wilayaController.text.trim();

              if (clientId.isEmpty || clientName.isEmpty || wilaya.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill required fields')),
                );
                return;
              }

              final url = Uri.parse(
                'http://estcommand.ddns.net:8080/api/v1/clients',
              );
              final body = jsonEncode({
                "clientsID": clientId,
                "clientName": clientName,
                "telephone": phone,
                "wilaya": wilaya,
              });

              try {
                final response = await http.post(
                  url,
                  headers: {'Content-Type': 'application/json'},
                  body: body,
                );

                if (response.statusCode == 201 || response.statusCode == 200) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Client "$clientName" added successfully!'),
                    ),
                  );
                  _fetchClients(); // Refresh list
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to add client: ${response.body}'),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog() {
    final TextEditingController _productNameController =
        TextEditingController();
    final TextEditingController _initialPriceController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _productNameController,
              decoration: const InputDecoration(labelText: 'Product Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _initialPriceController,
              decoration: const InputDecoration(labelText: 'Initial Price'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final String productName = _productNameController.text.trim();
              final String initialPriceStr = _initialPriceController.text
                  .trim();

              if (productName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product name is required')),
                );
                return;
              }

              final url = Uri.parse(
                'http://estcommand.ddns.net:8080/api/v1/products',
              );
              final body = jsonEncode({
                "productName": productName,
                if (initialPriceStr.isNotEmpty)
                  "initialPrice": double.tryParse(initialPriceStr) ?? 0,
              });

              try {
                final response = await http.post(
                  url,
                  headers: {'Content-Type': 'application/json'},
                  body: body,
                );

                if (response.statusCode == 201 || response.statusCode == 200) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Product "$productName" added successfully!',
                      ),
                    ),
                  );
                  _fetchProducts(); // Refresh list
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to add product: ${response.body}'),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditClientDialog(BuildContext context) {
    final TextEditingController _searchController = TextEditingController();
    Client? selectedClient;
    final TextEditingController _clientNameController = TextEditingController();
    final TextEditingController _wilayaController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Client'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TypeAheadField<Client>(
                    builder: (context, controller, focusNode) {
                      return TextField(
                        controller: _searchController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Search Client',
                          prefixIcon: Icon(Icons.search),
                        ),
                      );
                    },
                    suggestionsCallback: (pattern) {
                      return _clients
                          .where(
                            (client) => client.clientName!
                                .toLowerCase()
                                .contains(pattern.toLowerCase()),
                          )
                          .toList();
                    },
                    itemBuilder: (context, Client suggestion) {
                      return ListTile(
                        title: Text(suggestion.clientName ?? ''),
                        subtitle: Text('Wilaya: ${suggestion.wilaya ?? ''}'),
                      );
                    },
                    onSelected: (Client suggestion) {
                      setState(() {
                        selectedClient = suggestion;
                        _searchController.text = suggestion.clientName ?? '';
                        _clientNameController.text =
                            suggestion.clientName ?? '';
                        _wilayaController.text = suggestion.wilaya ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedClient != null) ...[
                    TextField(
                      controller: _clientNameController,
                      decoration: const InputDecoration(
                        labelText: 'Client Name',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _wilayaController,
                      decoration: const InputDecoration(labelText: 'Wilaya'),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedClient == null
                      ? null
                      : () async {
                          // Call your API to update the client here
                          final url = Uri.parse(
                            'http://estcommand.ddns.net:8080/api/v1/clients/${selectedClient!.clientsID}',
                          );
                          final body = jsonEncode({
                            "clientName": _clientNameController.text.trim(),
                            "wilaya": _wilayaController.text.trim(),
                          });
                          try {
                            final response = await http.put(
                              url,
                              headers: {'Content-Type': 'application/json'},
                              body: body,
                            );
                            if (response.statusCode == 200) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Client updated!'),
                                ),
                              );
                              _fetchClients();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed: ${response.body}'),
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteClientDialog(BuildContext context) {
    final TextEditingController _searchController = TextEditingController();
    Client? selectedClient;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Delete Client'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TypeAheadField<Client>(
                    builder: (context, controller, focusNode) {
                      return TextField(
                        controller: _searchController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Search Client',
                          prefixIcon: Icon(Icons.search),
                        ),
                      );
                    },
                    suggestionsCallback: (pattern) {
                      return _clients
                          .where(
                            (client) => client.clientName!
                                .toLowerCase()
                                .contains(pattern.toLowerCase()),
                          )
                          .toList();
                    },
                    itemBuilder: (context, Client suggestion) {
                      return ListTile(
                        title: Text(suggestion.clientName ?? ''),
                        subtitle: Text('Wilaya: ${suggestion.wilaya ?? ''}'),
                      );
                    },
                    onSelected: (Client suggestion) {
                      setState(() {
                        selectedClient = suggestion;
                        _searchController.text = suggestion.clientName ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedClient != null)
                    Text(
                      'Are you sure you want to delete "${selectedClient!.clientName}"?',
                      style: const TextStyle(color: Colors.red),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: selectedClient == null
                      ? null
                      : () async {
                          // Confirm deletion
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm Delete'),
                              content: Text(
                                'Delete "${selectedClient!.clientName}"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('No'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Yes, Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            final url = Uri.parse(
                              'http://estcommand.ddns.net:8080/api/v1/clients/${selectedClient!.clientsID}',
                            );
                            try {
                              final response = await http.delete(url);
                              if (response.statusCode == 200) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Client deleted!'),
                                  ),
                                );
                                _fetchClients();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed: ${response.body}'),
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditProductDialog(Product product) {
    final TextEditingController _productNameController = TextEditingController(
      text: product.productName ?? '',
    );
    final TextEditingController _initialPriceController = TextEditingController(
      text: product.initialPrice?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _productNameController,
              decoration: const InputDecoration(labelText: 'Product Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _initialPriceController,
              decoration: const InputDecoration(labelText: 'Initial Price'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final String productName = _productNameController.text.trim();
              final String initialPriceStr = _initialPriceController.text
                  .trim();

              if (productName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product name is required')),
                );
                return;
              }

              final url = Uri.parse(
                'http://estcommand.ddns.net:8080/api/v1/products/${product.productID}',
              );
              final Map<String, dynamic> updateData = {};

              if (productName != product.productName) {
                updateData['productName'] = productName;
              }
              if (initialPriceStr.isNotEmpty) {
                updateData['initialPrice'] =
                    double.tryParse(initialPriceStr) ?? 0;
              }

              if (updateData.isEmpty) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No changes made')),
                );
                return;
              }

              final body = jsonEncode(updateData);

              try {
                final response = await http.patch(
                  url,
                  headers: {'Content-Type': 'application/json'},
                  body: body,
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Product "$productName" updated successfully!',
                      ),
                    ),
                  );
                  _fetchProducts(); // Refresh list
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to update product: ${response.body}',
                      ),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteProductDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "${product.productName}"?',
          style: const TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // Confirm deletion
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Delete'),
                  content: Text(
                    'Delete "${product.productName}"? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('No'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Yes, Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                final url = Uri.parse(
                  'http://estcommand.ddns.net:8080/api/v1/products/${product.productID}',
                );
                try {
                  final response = await http.delete(url);
                  if (response.statusCode == 200) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Product "${product.productName}" deleted successfully!',
                        ),
                      ),
                    );
                    _fetchProducts(); // Refresh list
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to delete product: ${response.body}',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeUserPassword(String username, String userId) async {
    final TextEditingController _passwordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Password for $username'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Change Password'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token') ?? '';

        final response = await http.put(
          Uri.parse(
            'http://estcommand.ddns.net:8080/api/v1/users/admin/$userId',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'password': _passwordController.text}),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Password changed for $username')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to change password: ${response.statusCode}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editUserRole(
    String username,
    String userId,
    String currentRole,
  ) async {
    UserRole? _selectedRole;

    // Convert current role string to UserRole enum
    switch (currentRole.toLowerCase()) {
      case 'admin':
        _selectedRole = UserRole.admin;
        break;
      case 'superuser':
        _selectedRole = UserRole.superuser;
        break;
      case 'commercial':
        _selectedRole = UserRole.commercial;
        break;
      case 'délégué':
        _selectedRole = UserRole.delegue;
        break;
      default:
        _selectedRole = UserRole.user;
        break;
    }

    final result = await showDialog<UserRole>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit Role for $username'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Current role: $currentRole',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select New Role',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<UserRole>(
                    title: const Text('Admin'),
                    value: UserRole.admin,
                    groupValue: _selectedRole,
                    onChanged: (UserRole? value) {
                      setState(() => _selectedRole = value);
                    },
                  ),
                  RadioListTile<UserRole>(
                    title: const Text('SuperUser'),
                    value: UserRole.superuser,
                    groupValue: _selectedRole,
                    onChanged: (UserRole? value) {
                      setState(() => _selectedRole = value);
                    },
                  ),
                  RadioListTile<UserRole>(
                    title: const Text('Commercial'),
                    value: UserRole.commercial,
                    groupValue: _selectedRole,
                    onChanged: (UserRole? value) {
                      setState(() => _selectedRole = value);
                    },
                  ),
                  RadioListTile<UserRole>(
                    title: const Text('Delegue'),
                    value: UserRole.delegue,
                    groupValue: _selectedRole,
                    onChanged: (UserRole? value) {
                      setState(() => _selectedRole = value);
                    },
                  ),
                  RadioListTile<UserRole>(
                    title: const Text('Client'),
                    value: UserRole.user,
                    groupValue: _selectedRole,
                    onChanged: (UserRole? value) {
                      setState(() => _selectedRole = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selectedRole),
                  child: const Text('Update Role'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      try {
        // Validate that userId is not empty
        if (userId.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: User ID is missing. Cannot update role for $username.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token') ?? '';

        // Use the correct field names - isAdmin with capital A
        Map<String, dynamic> roleData = {
          'isAdmin': result == UserRole.admin ? 1 : 0,
          'isSuperUser': result == UserRole.superuser ? 1 : 0,
          'isCommercUser': result == UserRole.commercial ? 1 : 0,
          'isDelegue': result == UserRole.delegue ? 1 : 0,
          'isclient': result == UserRole.user ? 1 : 0,
        };

        print('Attempting to update user role...');
        print('Username: $username');
        print('User ID: $userId');
        print('Role data: $roleData');

        try {
          final response = await http.put(
            Uri.parse(
              'http://estcommand.ddns.net:8080/api/v1/users/admin/$userId',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(roleData),
          );

          print('PUT response: ${response.statusCode}');
          print('PUT response body: ${response.body}');

          if (response.statusCode == 200 || response.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Role updated for $username')),
            );
            _fetchUsers(); // Refresh the users list
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to update role: ${response.statusCode} - ${response.body}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (e) {
          print('Error updating role: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating role: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getUserRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red.shade600;
      case 'superuser':
        return Colors.purple.shade600;
      case 'commercial':
        return Colors.green.shade600;
      case 'delegue':
        return Colors.blue.shade600;
      case 'client':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getUserRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'superuser':
        return Icons.supervisor_account;
      case 'commercial':
        return Icons.business_center;
      case 'delegue':
        return Icons.assignment_ind;
      case 'client':
        return Icons.person;
      default:
        return Icons.account_circle;
    }
  }
}

// === MODEL ===
class Client {
  final String? clientsID;
  final String? clientName;
  final String? wilaya;

  Client({this.clientsID, this.clientName, this.wilaya});

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      clientsID: json['clientsID']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      wilaya: json['wilaya']?.toString() ?? '',
    );
  }
}

class Product {
  final String? productID;
  final String? productName;
  final String? description;
  final double? initialPrice;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    this.productID,
    this.productName,
    this.description,
    this.initialPrice,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productID: json['productID']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      initialPrice: json['initialPrice'] != null
          ? double.tryParse(json['initialPrice'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productID': productID,
      'productName': productName,
      'description': description,
      'initialPrice': initialPrice,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
