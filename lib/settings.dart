import 'package:EstStarCommande/SalesStatsPage.dart';
import 'package:EstStarCommande/purchase_orders_page.dart';
import 'Chatbot.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_typeahead/flutter_typeahead.dart'; // For TypeAheadFormField
import 'package:shared_preferences/shared_preferences.dart'; // For SharedPreferences

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({Key? key}) : super(key: key);

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class User {
  final String? username;
  final String? role;

  User({this.username, this.role});

  factory User.fromJson(Map<String, dynamic> json) {
    // Determine role based on flags
    String role = 'Client';
    if (json['isAdmin'] == 1) {
      role = 'Admin';
    } else if (json['isSuperUser'] == 1) {
      role = 'Superuser';
    } else if (json['isCommercUser'] == 1) {
      role = 'Commercial';
    }

    return User(
      username: json['username'] ?? '',
      role: role,
    );
  }
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  int _selectedTabIndex = 0;

  final List<String> _tabs = [
    'Users',
    'Clients',
    'Products',
  ];

  List<User> _users = [];
  bool _isLoadingUsers = false;
  String _userError = '';

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _userError = '';
    });

    try {
      final response = await http.get(Uri.parse('http://92.222.248.113:3000/api/v1/users'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _users = data.map((json) => User.fromJson(json)).toList();
          _isLoadingUsers = false;
        });
      } else {
        setState(() {
          _isLoadingUsers = false;
          _userError = 'Failed to load users: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingUsers = false;
        _userError = 'Error: $e';
      });
    }
  }

  // Simulated current user role - Replace this with real data from API later
  final String currentUserRole = 'admin'; // can be 'admin', 'superuser', 'assistant', 'delegue', 'client'

  bool get _canAddUser => ['admin', 'superuser'].contains(currentUserRole);
  bool get _canAddClient => ['admin', 'superuser'].contains(currentUserRole);
  bool get _canAddProduct => ['admin', 'superuser'].contains(currentUserRole);

  // Client state
  List<Client> _clients = [];
  bool _isLoadingClients = false;
  String _clientError = '';

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _fetchUsers();
  }

  Future<void> _fetchClients() async {
    setState(() {
      _isLoadingClients = true;
      _clientError = '';
    });

    try {
      final response =
      await http.get(Uri.parse('http://92.222.248.113:3000/api/v1/clients'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _clients = data.map((json) => Client.fromJson(json)).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _buildTabContent(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) => setState(() => _selectedTabIndex = index),
        items: _tabs.map((title) => BottomNavigationBarItem(
          icon: const Icon(Icons.dashboard),
          label: title,
        )).toList(),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('PO Interface'),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PurchaseOrdersPage()),
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
                      builder: (context) => const SalesStatsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminPanelPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bolt_outlined),
              title: const Text('CHAT BOT -Beta '),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ChatBotPage()),
                );
              },
            ),
          ],
        ),
      ),
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
      default:
        return const Center(child: Text('Unknown tab'));
    }
  }

  // 🧑 User Management
  Widget _buildUserManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Manage Users', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (_canAddUser)
          ElevatedButton(
            onPressed: () => _showCreateUserDialog(context), // make sure this exists
            child: const Text('Add User'),
          ),
        const SizedBox(height: 10),
        if (_isLoadingUsers)
          const Center(child: CircularProgressIndicator())
        else if (_userError.isNotEmpty)
          Center(child: Text(_userError, style: const TextStyle(color: Colors.red)))
        else if (_users.isEmpty)
            const Center(child: Text('No users found'))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(user.username ?? ''),
                      subtitle: Text('Role: ${user.role}'),
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
        const Text('Manage Clients', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (_canAddClient)
          ElevatedButton(
            onPressed: () => _showAddClientDialog(),
            child: const Text('Add Client'),
          ),
        const SizedBox(height: 10),
        if (_isLoadingClients)
          const Center(child: CircularProgressIndicator())
        else if (_clientError.isNotEmpty)
          Center(child: Text(_clientError, style: const TextStyle(color: Colors.red)))
        else if (_clients.isEmpty)
            const Center(child: Text('No clients found'))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _clients.length,
                itemBuilder: (context, index) {
                  final client = _clients[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(client.clientName ?? ''),
                      subtitle: Text('Wilaya: ${client.wilaya ?? ''}'),
                      trailing: Text('ID: ${client.clientsID ?? ''}', style: const TextStyle(fontSize: 12)),
                      dense: true,
                    ),
                  );
                },
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
        const Text('Manage Products', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (_canAddProduct)
          ElevatedButton(
            onPressed: () => _showAddProductDialog(),
            child: const Text('Add Product'),
          ),
        const SizedBox(height: 10),
        const Expanded(child: Placeholder(child: Text('Product management goes here'))),
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
    String? clId,
  }) async {
    final url = Uri.parse('http://92.222.248.113:3000/api/v1/auth/register');
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
              content: Text('Failed: ${response.statusCode} - ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating user: $e')),
      );
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
              title: Text('Create User', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                            TypeAheadFormField<String>(
                              textFieldConfiguration: TextFieldConfiguration(
                                controller: _extraInfoController,
                                decoration: InputDecoration(
                                  labelText: 'Client',
                                  prefixIcon: Icon(Icons.person),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              suggestionsCallback: (pattern) async {
                                if (pattern.isEmpty) return [];
                                final response = await http.get(Uri.parse(
                                  'http://92.222.248.113:3000/api/v1/clients/search?term=$pattern',
                                ));
                                if (response.statusCode == 200) {
                                  final List<dynamic> clientsJson = jsonDecode(response.body);
                                  CreateClientsMap = {
                                    for (var client in clientsJson)
                                      client['clientName']: client['clientsID']
                                  };
                                  return CreateClientsMap.keys.toList();
                                } else {
                                  return [];
                                }
                              },
                              itemBuilder: (context, suggestion) =>
                                  ListTile(title: Text(suggestion)),
                              onSuggestionSelected: (suggestion) {
                                _extraInfoController.text = suggestion;
                                selectedCrClientName = suggestion;
                              },
                              validator: (value) => (value == null || value.trim().isEmpty)
                                  ? 'Client is required'
                                  : null,
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
                    if (_selectedRole == UserRole.user && (_extraInfoController.text.isEmpty)) {
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
              TextField(controller: _clientIdController, decoration: const InputDecoration(labelText: 'Client ID (e.g., C050)')),
              TextField(controller: _clientNameController, decoration: const InputDecoration(labelText: 'Client Name')),
              TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: _wilayaController, decoration: const InputDecoration(labelText: 'Wilaya')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: Navigator.of(context).pop, child: const Text('Cancel')),
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

              final url = Uri.parse('http://92.222.248.113:3000/api/v1/clients');
              final body = jsonEncode({
                "clientsID": clientId,
                "clientName": clientName,
                "telephone": phone,
                "wilaya": wilaya
              });

              try {
                final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);

                if (response.statusCode == 201 || response.statusCode == 200) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Client "$clientName" added successfully!')),
                  );
                  _fetchClients(); // Refresh list
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add client: ${response.body}')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }




  void _showAddProductDialog() {
    final TextEditingController _productNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Product'),
        content: TextField(
          controller: _productNameController,
          decoration: const InputDecoration(labelText: 'Product Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              print("API CALL: addProduct(name: ${_productNameController.text})");
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Product "${_productNameController.text}" added')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
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