import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_typeahead/flutter_typeahead.dart'; // For TypeAheadFormField
import 'package:shared_preferences/shared_preferences.dart'; // For SharedPreferences
import 'app_drawer.dart';

enum UserRole { admin, superuser, commercial, delegue, user }

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

    return User(username: json['username'] ?? '', role: role);
  }
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  int _selectedTabIndex = 0;

  final List<String> _tabs = ['Users', 'Clients', 'Products'];

  List<User> _users = [];
  bool _isLoadingUsers = false;
  String _userError = '';

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _userError = '';
    });

    try {
      final response = await http.get(
        Uri.parse('http://92.222.248.113:3000/api/v1/users'),
      );
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
  final String currentUserRole =
      'admin'; // can be 'admin', 'superuser', 'assistant', 'delegue', 'client'

  bool get _canAddUser => ['admin', 'superuser'].contains(currentUserRole);

  // Client state
  List<Client> _clients = [];
  bool _isLoadingClients = false;
  String _clientError = '';

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
  }

  Future<void> _fetchClients() async {
    setState(() {
      _isLoadingClients = true;
      _clientError = '';
    });

    try {
      final response = await http.get(
        Uri.parse('http://92.222.248.113:3000/api/v1/clients'),
      );
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

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _productError = '';
    });

    try {
      final response = await http.get(
        Uri.parse('http://92.222.248.113:3000/api/v1/products'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _buildTabContent(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) => setState(() => _selectedTabIndex = index),
        items: _tabs
            .map(
              (title) => BottomNavigationBarItem(
                icon: const Icon(Icons.dashboard),
                label: title,
              ),
            )
            .toList(),
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
      default:
        return const Center(child: Text('Unknown tab'));
    }
  }

  // 🧑 User Management
  Widget _buildUserManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manage Users',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (_canAddUser)
          ElevatedButton(
            onPressed: () =>
                _showCreateUserDialog(context), // make sure this exists
            child: const Text('Add User'),
          ),
        const SizedBox(height: 10),
        if (_isLoadingUsers)
          const Center(child: CircularProgressIndicator())
        else if (_userError.isNotEmpty)
          Center(
            child: Text(_userError, style: const TextStyle(color: Colors.red)),
          )
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
        const Text(
          'Manage Clients',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        const SizedBox(height: 10),
        if (_isLoadingClients)
          const Center(child: CircularProgressIndicator())
        else if (_clientError.isNotEmpty)
          Center(
            child: Text(
              _clientError,
              style: const TextStyle(color: Colors.red),
            ),
          )
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
                    trailing: Text(
                      'ID: ${client.clientsID ?? ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    dense: true,
                  ),
                );
              },
            ),
          ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.delete),
                label: const Text('Delete Client'),
                onPressed: () => _showDeleteClientDialog(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // 📦 Product Management
  Widget _buildProductManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manage Products',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (_isLoadingProducts)
          const Center(child: CircularProgressIndicator())
        else if (_productError.isNotEmpty)
          Center(
            child: Text(
              _productError,
              style: const TextStyle(color: Colors.red),
            ),
          )
        else if (_products.isEmpty)
          const Center(child: Text('No products found'))
        else
          Expanded(
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(product.productName ?? ''),
                    subtitle: Text(
                      'Price: ${product.initialPrice?.toStringAsFixed(2) ?? '0.00'}%',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditProductDialog(product),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _showDeleteProductDialog(product),
                        ),
                      ],
                    ),
                    dense: true,
                  ),
                );
              },
            ),
          ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                onPressed: () => _fetchProducts(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
                                      'http://92.222.248.113:3000/api/v1/clients/search?term=$pattern',
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
                'http://92.222.248.113:3000/api/v1/clients',
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
                'http://92.222.248.113:3000/api/v1/products',
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
                            'http://92.222.248.113:3000/api/v1/clients/${selectedClient!.clientsID}',
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
                              'http://92.222.248.113:3000/api/v1/clients/${selectedClient!.clientsID}',
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
                'http://92.222.248.113:3000/api/v1/products/${product.productID}',
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
                  'http://92.222.248.113:3000/api/v1/products/${product.productID}',
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
