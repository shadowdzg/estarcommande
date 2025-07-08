import 'package:EstStarCommande/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:excel/excel.dart' as excel;
import 'package:path/path.dart' as p;
import 'package:google_fonts/google_fonts.dart';

// Product class for database integration
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
}

bool sortAscending = true;
String sortColumn = 'date';
String? selectedState;
bool isAdminn = false;
bool isSuserr = false;
bool isclient = false;
bool showActions = false;
bool _isMobileMenuOpen = false;
bool isDropdownOpened = false;
String selectedCrClientName = "";
Map<String, String> CreateClientsMap = {};

enum UserRole { admin, superuser, commercial, user, delegue }

Map<String, dynamic> decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw Exception('Invalid JWT');
  }
  final payload = parts[1];
  final normalized = base64.normalize(payload);
  final decoded = utf8.decode(base64.decode(normalized));
  return json.decode(decoded);
}

isAdmin() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token') ?? '';
  final payload = decodeJwtPayload(token);
  final isAdmin = payload['isadmin'] == 1;
  return isAdmin;
}

isSup() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token') ?? '';
  final payload = decodeJwtPayload(token);
  final isSup = payload['issuper'] == 1;
  return isSup;
}

isClient() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token') ?? '';
  final payload = decodeJwtPayload(token);
  final isSup = payload['isclient'] == 1;
  return isSup;
}

bool isMobile() {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

DateTimeRange? selectedDateRange;

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({Key? key}) : super(key: key);

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  final _formKey = GlobalKey<FormState>();

  int _totalOrdersCount = 0;
  List<Map<String, dynamic>> _currentPageOrders = [];
  String _whatsappNumber = "213770940827"; // Default WhatsApp number

  Future<void> fetchPurchaseOrders({
    int page = 0,
    int pageSize = 10,
    bool keepPage = true,
    String? searchQuery,
    String? stateFilter,
    List<String>? productFilters,
    DateTimeRange? dateRange,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    // Keep current page if requested
    final int skip = keepPage ? page * pageSize : 0;
    final int take = pageSize;

    final Map<String, String> queryParams = {
      'skip': skip.toString(),
      'take': take.toString(),
    };

    // Add date range filters
    if (dateRange != null) {
      queryParams['startDate'] = dateRange.start.toIso8601String().split(
        'T',
      )[0]; // Format: YYYY-MM-DD
      queryParams['endDate'] = dateRange.end.toIso8601String().split('T')[0];
    }

    // Add state filter (using backend's field name)
    if (stateFilter != null && stateFilter.isNotEmpty) {
      // Map frontend state names to backend values if needed
      String backendState = stateFilter;
      switch (stateFilter) {
        case 'En Attente':
          backendState = 'En Attente';
          break;
        case 'Effectué':
          backendState = 'Effectué';
          break;
        case 'Rejeté':
          backendState = 'Rejeté';
          break;
        case 'Numéro Incorrecte':
          backendState = 'Numéro Incorrecte';
          break;
        case 'Problème Solde':
          backendState = 'Problème Solde';
          break;
      }
      queryParams['isValidated'] = backendState;
    }

    // Add product filter (using backend's field name 'operator')
    if (productFilters != null && productFilters.length == 1) {
      // Single product filter - use API filtering
      queryParams['operator'] = productFilters.first;
    }
    // For multiple products, we'll fetch all and filter client-side

    final uri = Uri.parse(
      'http://92.222.248.113:3000/api/v1/commands',
    ).replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (!mounted) return;

        // Parse orders from response
        final ordersList = (data['data'] ?? []) as List<dynamic>;
        final allOrders = ordersList.map<Map<String, dynamic>>((item) {
          return {
            'id': item['id'],
            'client': item['client']?['clientName'] ?? 'Unknown',
            'product': item['operator'] ?? 'Unknown',
            'quantity': item['amount'] ?? 0,
            'prixPercent':
                double.tryParse(
                  (item['pourcentage'] ?? '0').toString().replaceAll('%', ''),
                ) ??
                0,
            'state': item['isValidated'] ?? 'En Attente',
            'name': item['user']?['username'] ?? 'Unknown',
            'number': item['number'] ?? 'Unknown',
            'accepted': item['accepted'] ?? 'Unknown',
            'acceptedBy': item['acceptedBy'] ?? ' ',
            'date': item['createdAt'] ?? '',
          };
        }).toList();

        // Apply client-side search filter (since API doesn't seem to support client name search)
        List<Map<String, dynamic>> filteredOrders = allOrders;
        if (searchQuery != null && searchQuery.isNotEmpty) {
          filteredOrders = allOrders.where((order) {
            return order['client'].toLowerCase().contains(
              searchQuery.toLowerCase(),
            );
          }).toList();
        }

        // If multiple products are selected, apply client-side filtering
        if (productFilters != null && productFilters.length > 1) {
          filteredOrders = filteredOrders.where((order) {
            return productFilters.contains(order['product']);
          }).toList();
        }

        setState(() {
          _currentPageOrders = filteredOrders;
          _totalOrdersCount = data['totalCount'] ?? filteredOrders.length;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching orders: $e')));
    }
  }

  // Deprecated: allOrders is not used for paginated backend data anymore.
  List<Map<String, dynamic>> allOrders = [];

  String searchQuery = '';
  String productQuery = '';
  TextEditingController productSController = TextEditingController();

  // New: Map to hold checkbox states for each product
  Map<String, bool> productCheckboxes = {};

  void initializeProductCheckboxes() {
    final List<String> productList = [
      'SEHELLI STORM PRIMAIRE',
      'SEHELLI FLEXY PRIMAIRE',
      'SEHELLI FLEXY EST',
      'SEHELLI FLEXY CENTRE',
      'SEHELLI FLEXY SUD',
      'SEHELLI FLEXY AUXILIAIRE',
      'STORM STI',
      'STORM',
      'SEHELLI ARSELLI PRIMAIRE',
      'ARSELLI DATA',
      'SEHELLI STORM AUXILLIAIRE',
      'SEHELLI ARSELLI AUXILLIAIRE',
      'FLEXY',
      'ARSELLI',
      'ARSELLI IZI',
      'FLEXY IZI',
      'STORM IZI',
      'telegrame',
      'STORM AUXILLIAIRE',
      'FLEXY AUXILLIAIRE',
      'IDOOM 4G',
      'IDOOM 500',
      'IDOOM 1000',
      'IDOOM 2000',
      'FLEXY  EST',
      'FLEXY SUD',
      'FLEXY CENTRE',
      'FLEXY ',
    ];
    setState(() {
      productCheckboxes = {for (var product in productList) product: true};
    });
  }

  @override
  void initState() {
    super.initState();
    initializeProductCheckboxes(); // Initialize checkboxes
    _loadWhatsAppNumber(); // Load saved WhatsApp number
    fetchPurchaseOrders();
    _startAutoRefresh();
    _checkAdmin();
    _checkSuser();
    _checkClient();
  }

  // Load WhatsApp number from SharedPreferences
  Future<void> _loadWhatsAppNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final savedNumber = prefs.getString('whatsapp_number');
    if (savedNumber != null && savedNumber.isNotEmpty) {
      setState(() {
        _whatsappNumber = savedNumber;
      });
    }
  }

  // Save WhatsApp number to SharedPreferences
  Future<void> _saveWhatsAppNumber(String number) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('whatsapp_number', number);
  }

  // Apply filters and refresh data
  Future<void> _applyFiltersAndRefresh() async {
    // Get selected products
    final selectedProducts = productCheckboxes.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    // If no products are selected, select all products
    final List<String>? productFilters = selectedProducts.isEmpty
        ? null
        : selectedProducts;

    await fetchPurchaseOrders(
      page: 0, // Reset to first page when applying filters
      pageSize: _rowsPerPage,
      keepPage: false,
      searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
      stateFilter: selectedState,
      productFilters: productFilters,
      dateRange: selectedDateRange,
    );

    // Reset current page to 0 when filters are applied
    setState(() {
      _currentPage = 0;
    });
  }

  // Fetch with current filters (for pagination)
  Future<void> _fetchWithCurrentFilters({required int page}) async {
    final selectedProducts = productCheckboxes.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    // If no products are selected, select all products
    final List<String>? productFilters = selectedProducts.isEmpty
        ? null
        : selectedProducts;

    await fetchPurchaseOrders(
      page: page,
      pageSize: _rowsPerPage,
      keepPage: true,
      searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
      stateFilter: selectedState,
      productFilters: productFilters,
      dateRange: selectedDateRange,
    );
  }

  List<Map<String, dynamic>> get filteredOrders {
    // Since filtering is now done on the backend, just return current page orders
    return _currentPageOrders;
  }

  void exportToExcel(List<Map<String, dynamic>> data) async {
    var excelFile = excel.Excel.createExcel();
    final excel.Sheet sheet = excelFile['Sheet1'];
    List<excel.CellValue?> headers = [
      excel.TextCellValue('ID'),
      excel.TextCellValue('Client'),
      excel.TextCellValue('Product'),
      excel.TextCellValue('Qty'),
      excel.TextCellValue('Prix %'),
      excel.TextCellValue('State'),
      excel.TextCellValue('Name'),
      excel.TextCellValue('Number'),
      excel.TextCellValue('Accepted'),
      excel.TextCellValue('Accepted By'),
      excel.TextCellValue('Date'),
    ];
    sheet.appendRow(headers);
    for (var item in data) {
      List<excel.CellValue?> row = [
        excel.TextCellValue(item['id'].toString()),
        excel.TextCellValue(item['client']),
        excel.TextCellValue(item['product']),
        excel.TextCellValue(item['quantity'].toString()),
        excel.TextCellValue(item['prixPercent'].toString()),
        excel.TextCellValue(item['state']),
        excel.TextCellValue(item['name']),
        excel.TextCellValue(item['number']),
        excel.TextCellValue(item['accepted'].toString()),
        excel.TextCellValue(item['acceptedBy'] ?? ''),
        excel.TextCellValue(item['date']),
      ];
      sheet.appendRow(row);
    }
    final fileBytes = excelFile.save();
    if (fileBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Failed to save Excel')));
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'export.xlsx');
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes);
    // Show success message and open the file
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('✅ Excel exported to: $path')));
    // Open the file using the default app associated with .xlsx files
    OpenFile.open(path);
  }

  void _deleteOrder(int index) async {
    final orderId = _currentPageOrders[index]['id'];
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    try {
      final response = await http.delete(
        Uri.parse('http://92.222.248.113:3000/api/v1/commands/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _fetchWithCurrentFilters(page: _currentPage);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order deleted successfully')),
        );
      } else {
        throw Exception('Failed to delete order: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _confirmDeleteOrder(int realIndex) async {
    final orderName = _currentPageOrders[realIndex]['name'] ?? 'this item';
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
            'Are you sure you want to delete the order for "$orderName"? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      _deleteOrder(realIndex);
    }
  }

  void _changeOrderState(int index, String newState) async {
    final orderId = _currentPageOrders[index]['id'].toString();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final url = Uri.parse(
      'http://92.222.248.113:3000/api/v1/commands/$orderId',
    );
    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isValidated': newState}),
      );
      if (response.statusCode == 200) {
        await _fetchWithCurrentFilters(page: _currentPage);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order state updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update state: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> handleAccept(bool accepted, int id) async {
    final orderId = _currentPageOrders[id]['id'].toString();
    final url = Uri.parse(
      'http://92.222.248.113:3000/api/v1/commands/accept/$orderId',
    );
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'accepted': accepted}),
    );
    if (response.statusCode == 200) {
      await _fetchWithCurrentFilters(page: _currentPage);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order updated successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update order: ${response.statusCode}'),
        ),
      );
    }
  }

  void _showEditDialog(int index) {
    final order = _currentPageOrders[index];
    final clientController = TextEditingController(text: order['client'] ?? '');
    final productController = TextEditingController(
      text: order['product'] ?? '',
    );
    final quantityController = TextEditingController(
      text: order['quantity'].toString(),
    );
    final prixPercentController = TextEditingController(
      text: order['prixPercent'].toString(),
    );
    final numberController = TextEditingController(
      text: order['number']?.toString() ?? '',
    );
    final nameController = TextEditingController(text: order['name'] ?? '');
    final dateController = TextEditingController(text: order['date'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Order'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: clientController,
                decoration: const InputDecoration(labelText: 'Client'),
              ),
              TextField(
                controller: productController,
                decoration: const InputDecoration(labelText: 'Product'),
              ),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              TextField(
                controller: numberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'number'),
              ),
              TextField(
                controller: prixPercentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Prix %'),
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: 'Date'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              _updateOrder(index, {
                'client': clientController.text,
                'product': productController.text,
                'quantity':
                    int.tryParse(quantityController.text) ?? order['quantity'],
                'prixPercent':
                    double.tryParse(prixPercentController.text) ??
                    order['prixPercent'],
                'number': numberController.text,
                'state': order['state'],
                'name': nameController.text,
                'date': dateController.text,
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddOrderDialog() {
    final clientController = TextEditingController();
    final numberController = TextEditingController();
    Map<String, String> clientsMap = {};
    String? selectedClientName;

    List<Map<String, dynamic>> selectedProducts = [];
    List<Product> availableProducts = [];

    // Fetch products from database
    Future<void> fetchProducts() async {
      try {
        final response = await http.get(
          Uri.parse('http://92.222.248.113:3000/api/v1/products'),
        );
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          availableProducts = data
              .map((json) => Product.fromJson(json))
              .toList();
        }
      } catch (e) {
        // Handle error if needed
      }
    }

    Widget buildMultiProductInput(BuildContext context) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return FutureBuilder<void>(
            future: fetchProducts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              return Column(
                children: [
                  TypeAheadField<Product>(
                    builder: (context, controller, focusNode) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Search Product',
                          suffixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                    suggestionsCallback: (pattern) => availableProducts
                        .where(
                          (p) => p.productName!.toLowerCase().contains(
                            pattern.toLowerCase(),
                          ),
                        )
                        .toList(),
                    itemBuilder: (context, Product suggestion) => ListTile(
                      title: Text(suggestion.productName ?? ''),
                      subtitle: Text(
                        'Prix: ${suggestion.initialPrice?.toStringAsFixed(2) ?? '0.00'} DA',
                      ),
                    ),
                    onSelected: (Product suggestion) {
                      setStateDialog(() {
                        selectedProducts.add({
                          'product': suggestion.productName ?? '',
                          'productId': suggestion.productID ?? '',
                          'quantity': 1,
                          'unitPrice': suggestion.initialPrice ?? 0.0,
                        });
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  if (selectedProducts.isNotEmpty)
                    Container(
                      height: selectedProducts.length > 5
                          ? 400.0 // Max height for 5 items
                          : selectedProducts.length * 80.0,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: selectedProducts.length,
                        itemBuilder: (context, index) {
                          final item = selectedProducts[index];
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['product'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'Prix BD: ${item['unitPrice'].toStringAsFixed(2)} DA',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      initialValue: item['unitPrice']
                                          .toStringAsFixed(2),
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      enabled:
                                          !isclient, // Read-only for clients
                                      onChanged: (value) {
                                        item['unitPrice'] =
                                            double.tryParse(value) ??
                                            item['unitPrice'];
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'PU',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        fillColor: isclient
                                            ? Colors.grey[100]
                                            : null,
                                        filled: isclient,
                                      ),
                                      style: TextStyle(
                                        color: isclient
                                            ? Colors.grey[600]
                                            : null,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      initialValue: item['quantity'].toString(),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        item['quantity'] =
                                            int.tryParse(value) ?? 1;
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Qty',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(
                                      Icons.remove_circle,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      setStateDialog(() {
                                        selectedProducts.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ), // End of ListView.builder
                    ), // End of Container
                ],
              );
            },
          );
        },
      );
    }

    showDialog(
      context: context,
      builder: (_) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        // Responsive sizing based on screen width
        double dialogWidth;
        double dialogHeight;
        double maxWidth;
        double maxHeight;

        if (screenWidth > 1200) {
          // Large desktop
          dialogWidth = screenWidth * 0.6;
          dialogHeight = screenHeight * 0.65;
          maxWidth = 700;
          maxHeight = 550;
        } else if (screenWidth > 800) {
          // Medium desktop/tablet
          dialogWidth = screenWidth * 0.75;
          dialogHeight = screenHeight * 0.70;
          maxWidth = 600;
          maxHeight = 500;
        } else {
          // Small screens/mobile
          dialogWidth = screenWidth * 0.90;
          dialogHeight = screenHeight * 0.75;
          maxWidth = 500;
          maxHeight = 450;
        }

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
              minWidth: 450,
              minHeight: 350,
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add New Order',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          isclient
                              ? SizedBox()
                              : TypeAheadField<String>(
                                  builder: (context, controller, focusNode) {
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: const InputDecoration(
                                        labelText: 'Client',
                                        prefixIcon: Icon(Icons.person),
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        clientController.text = value;
                                      },
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
                                        clientsMap = {
                                          for (var client in clientsJson)
                                            client['clientName']:
                                                client['clientsID'],
                                        };
                                        return clientsMap.keys.toList();
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
                                  itemBuilder: (context, String suggestion) =>
                                      ListTile(title: Text(suggestion)),
                                  onSelected: (String suggestion) {
                                    clientController.text = suggestion;
                                    selectedClientName = suggestion;
                                  },
                                ),
                          const SizedBox(height: 16),
                          buildMultiProductInput(context),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: numberController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Number',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('auth_token') ?? '';
                        final payload = decodeJwtPayload(token);

                        if (_formKey.currentState!.validate()) {
                          if (selectedProducts.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Please add at least one product",
                                ),
                              ),
                            );
                            return;
                          }

                          final clientId = clientsMap[selectedClientName];

                          for (var item in selectedProducts) {
                            final product = item['product'];
                            final quantity = item['quantity'];
                            final unitPrice = item['unitPrice'];

                            if (quantity <= 0) continue;

                            final response = await http.post(
                              Uri.parse(
                                'http://92.222.248.113:3000/api/v1/commands',
                              ),
                              headers: {
                                'Content-Type': 'application/json',
                                'Authorization': 'Bearer $token',
                              },
                              body: jsonEncode({
                                'operator': product,
                                'amount': quantity,
                                'ClientsID': isclient
                                    ? payload['clid']
                                    : clientId,
                                'isValidated': 'En Attente',
                                'pourcentage':
                                    '${unitPrice}%', // Use initial price as percentage
                                'number': numberController.text,
                              }),
                            );

                            if (response.statusCode == 201 ||
                                response.statusCode == 200) {
                              // Refresh the current page orders instead of modifying local state
                              await _fetchWithCurrentFilters(
                                page: _currentPage,
                              );
                            }
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "${selectedProducts.length} Orders created successfully",
                              ),
                            ),
                          );
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ); // Close Container
      }, // Close builder function
    ); // Close showDialog
  }

  void _updateOrder(int index, Map<String, dynamic> updatedOrder) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final orderId = _currentPageOrders[index]['id'];
    final Map<String, dynamic> body = {};
    if (updatedOrder['product'] != null) {
      body['operator'] = updatedOrder['product'];
    }
    if (updatedOrder['quantity'] != null) {
      body['amount'] = updatedOrder['quantity'];
    }
    if (updatedOrder['number'] != null) {
      body['number'] = updatedOrder['number'];
    }
    if (updatedOrder['prixPercent'] != null) {
      body['pourcentage'] = '${updatedOrder['prixPercent']}%';
    }
    if (updatedOrder['state'] != null) {
      body['isValidated'] = updatedOrder['state'];
    }
    final response = await http.put(
      Uri.parse('http://92.222.248.113:3000/api/v1/commands/$orderId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );
    if (response.statusCode == 200) {
      // Refresh the current page orders instead of modifying local state
      await _fetchWithCurrentFilters(page: _currentPage);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order updated successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update order: ${response.statusCode}'),
        ),
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
              title: Text(
                'Create User',
                style: TextStyle(fontWeight: FontWeight.bold),
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
                      SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Select Role',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Divider(thickness: 1.2),
                      RadioListTile<UserRole>(
                        title: Text('Admin'),
                        value: UserRole.admin,
                        groupValue: _selectedRole,
                        onChanged: (UserRole? value) {
                          setState(() => _selectedRole = value);
                        },
                      ),
                      RadioListTile<UserRole>(
                        title: Text('SuperUser'),
                        value: UserRole.superuser,
                        groupValue: _selectedRole,
                        onChanged: (UserRole? value) {
                          setState(() => _selectedRole = value);
                        },
                      ),
                      RadioListTile<UserRole>(
                        title: Text('Commercial'),
                        value: UserRole.commercial,
                        groupValue: _selectedRole,
                        onChanged: (UserRole? value) {
                          setState(() => _selectedRole = value);
                        },
                      ),
                      RadioListTile<UserRole>(
                        title: Text('Delegue'),
                        value: UserRole.delegue,
                        groupValue: _selectedRole,
                        onChanged: (UserRole? value) {
                          setState(() => _selectedRole = value);
                        },
                      ),
                      RadioListTile<UserRole>(
                        title: Text('Client'),
                        value: UserRole.user,
                        groupValue: _selectedRole,
                        onChanged: (UserRole? value) {
                          setState(() => _selectedRole = value);
                        },
                      ),
                      if (_selectedRole == UserRole.user) ...[
                        SizedBox(height: 12),
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
                              final token = prefs.getString('auth_token') ?? '';

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
                                final List<dynamic> clientsJson = jsonDecode(
                                  response.body,
                                );
                                CreateClientsMap = {
                                  for (var client in clientsJson)
                                    client['clientName']: client['clientsID'],
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
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
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
                  child: Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createUser({
    required String username,
    required String password,
    String? clId,
    int? isadmin,
    int? isCl,
    int? isSu,
    int? isCo,
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
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Add this to your _PurchaseOrdersPageState class
  int findOrderIndexById(String id) {
    return _currentPageOrders.indexWhere(
      (order) => order['id'].toString() == id.toString(),
    );
  }

  void _checkAdmin() async {
    isAdminn = await isAdmin();
    setState(() {});
  }

  void _checkSuser() async {
    isSuserr = await isSup() ?? false;
    setState(() {});
  }

  void _checkClient() async {
    isclient = await isClient() ?? false;
    setState(() {});
  }

  void _showWhatsAppConfigDialog() {
    final controller = TextEditingController(text: _whatsappNumber);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.settings, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            const Text('Configuration WhatsApp'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Numéro WhatsApp',
                hintText: '213770940827',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Format requis:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Code pays + numéro (ex: 213770940827)\nPas d\'espaces ni de caractères spéciaux',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final newNumber = controller.text.trim();
              if (newNumber.isNotEmpty) {
                setState(() {
                  _whatsappNumber = newNumber;
                });
                await _saveWhatsAppNumber(newNumber);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Numéro WhatsApp mis à jour: $newNumber'),
                      ],
                    ),
                    backgroundColor: Colors.green.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.error, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Veuillez entrer un numéro valide'),
                      ],
                    ),
                    backgroundColor: Colors.red.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Sauvegarder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Timer? _refreshTimer;
  Timer? _searchTimer;

  void _onSearchChanged(String value) {
    setState(() => searchQuery = value);

    // Cancel previous timer
    _searchTimer?.cancel();

    // Start new timer
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      _applyFiltersAndRefresh();
    });
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchWithCurrentFilters(page: _currentPage);
    });
  }

  void _sendOrderToWhatsApp(Map<String, dynamic> order) async {
    // Create a detailed and professional message
    String message =
        """
🔔 *NOUVELLE COMMANDE EST STAR* 🔔

📋 *Détails de la commande:*
• Client: ${order['client']}
• Produit: ${order['product']}
• Quantité: ${order['quantity']}
• Prix %: ${order['prixPercent']}%
• Numéro: ${order['number']}
• État: ${order['state']}
• Créé par: ${order['name']}
• Date: ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.parse(order['date']))}

💼 EST STAR - Gestion des Commandes
""";

    String urlEncodedMessage = Uri.encodeComponent(message.trim());
    String whatsappUrl =
        "https://wa.me/$_whatsappNumber/?text=$urlEncodedMessage";

    try {
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Commande envoyée vers WhatsApp ($_whatsappNumber)'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        throw Exception('Impossible de lancer WhatsApp');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Impossible d\'ouvrir WhatsApp. Est-il installé?'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Configurer',
            textColor: Colors.white,
            onPressed: _showWhatsAppConfigDialog,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  int _currentPage = 0;
  final int _rowsPerPage = 10;

  List<Map<String, dynamic>> get paginatedOrders {
    // Since backend already paginates, just return filteredOrders (which is _currentPageOrders filtered)
    return filteredOrders;
  }

  Widget _buildPaginationControls() {
    final totalPages = (_totalOrdersCount / _rowsPerPage).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: _currentPage > 0
                ? () async {
                    setState(() {
                      _currentPage--;
                    });
                    await _fetchWithCurrentFilters(page: _currentPage);
                  }
                : null,
          ),
          Text('Page ${_currentPage + 1} of $totalPages'),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: (_currentPage + 1) < totalPages
                ? () async {
                    setState(() {
                      _currentPage++;
                    });
                    await _fetchWithCurrentFilters(page: _currentPage);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchTimer?.cancel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: Icon(Icons.menu, color: Colors.red.shade700),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/my_logo.png', height: 32, width: 32),
            const SizedBox(width: 8),
            Text(
              'Commandes EST STAR',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
        actions: [
          if (isAdminn || isSuserr)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  FontAwesomeIcons.whatsapp,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                tooltip: 'Configuration WhatsApp: $_whatsappNumber',
                onPressed: _showWhatsAppConfigDialog,
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.logout, color: Colors.red.shade700),
              tooltip: 'Déconnexion',
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('auth_token');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
            ),
          ),
        ],
      ),
      drawer: AppDrawer(
        orders: _currentPageOrders,
      ), // <-- Use the new shared drawer here
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
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 1400) {
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          // Filters Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  decoration: InputDecoration(
                                    labelText: 'Rechercher par client',
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 18,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: _onSearchChanged,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(child: buildProductFilter()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: DropdownButton<String>(
                                      value: selectedState,
                                      hint: const Text("Filtrer par État"),
                                      underline: Container(),
                                      isExpanded: true,
                                      items:
                                          [
                                                'En Attente',
                                                'Effectué',
                                                'Rejeté',
                                                'Numéro Incorrecte',
                                                'Problème Solde',
                                              ]
                                              .map(
                                                (state) => DropdownMenuItem(
                                                  value: state,
                                                  child: Text(state),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (value) {
                                        setState(() => selectedState = value);
                                        _applyFiltersAndRefresh();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Action Buttons
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final picked = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() => selectedDateRange = picked);
                                    _applyFiltersAndRefresh();
                                  }
                                },
                                icon: const Icon(Icons.date_range, size: 14),
                                label: const Text(
                                  'Date',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _showAddOrderDialog,
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text(
                                  'Ajouter',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    searchQuery = '';
                                    selectedDateRange = null;
                                    selectedState = null;
                                    productCheckboxes.updateAll(
                                      (key, value) => true,
                                    );
                                  });
                                  _applyFiltersAndRefresh();
                                },
                                icon: const Icon(Icons.refresh, size: 14),
                                label: const Text(
                                  'Reset',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    exportToExcel(_currentPageOrders),
                                icon: const Icon(Icons.download, size: 14),
                                label: const Text(
                                  'Excel',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              if (isAdminn || isSuserr)
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.person_add, size: 14),
                                  label: const Text(
                                    'Utilisateur',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () =>
                                      _showCreateUserDialog(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Image.asset(
                              'assets/images/my_logo.png',
                              fit: BoxFit.contain,
                              width: 100,
                              height: 100,
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isMobileMenuOpen = !_isMobileMenuOpen;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _isMobileMenuOpen
                                      ? Icons.close
                                      : Icons.filter_list,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Rechercher par client',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: Container(height: 0),
                          secondChild: Card(
                            margin: const EdgeInsets.symmetric(vertical: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: buildProductFilter()),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: DropdownButton<String>(
                                          value: selectedState,
                                          hint: const Text("Filtrer État"),
                                          isExpanded: true,
                                          items:
                                              [
                                                    'En Attente',
                                                    'Effectué',
                                                    'Rejeté',
                                                    'Numéro Incorrecte',
                                                    'Problème Solde',
                                                  ]
                                                  .map(
                                                    (state) => DropdownMenuItem(
                                                      value: state,
                                                      child: Text(state),
                                                    ),
                                                  )
                                                  .toList(),
                                          onChanged: (value) {
                                            setState(
                                              () => selectedState = value,
                                            );
                                            _applyFiltersAndRefresh();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final picked =
                                              await showDateRangePicker(
                                                context: context,
                                                firstDate: DateTime(2020),
                                                lastDate: DateTime(2100),
                                              );
                                          if (picked != null) {
                                            setState(
                                              () => selectedDateRange = picked,
                                            );
                                            _applyFiltersAndRefresh();
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.date_range,
                                          size: 16,
                                        ),
                                        label: const Text('Date'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade600,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: _showAddOrderDialog,
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Ajouter'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.green.shade600,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            searchQuery = '';
                                            selectedDateRange = null;
                                            selectedState = null;
                                            productCheckboxes.updateAll(
                                              (key, value) => true,
                                            );
                                          });
                                          _applyFiltersAndRefresh();
                                        },
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 16,
                                        ),
                                        label: const Text('Reset'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.orange.shade600,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            exportToExcel(_currentPageOrders),
                                        icon: const Icon(
                                          Icons.download,
                                          size: 16,
                                        ),
                                        label: const Text('Excel'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal.shade600,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (isAdminn || isSuserr)
                                        ElevatedButton.icon(
                                          icon: const Icon(
                                            Icons.person_add,
                                            size: 16,
                                          ),
                                          label: const Text('Utilisateur'),
                                          onPressed: () =>
                                              _showCreateUserDialog(context),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.purple.shade600,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          crossFadeState: _isMobileMenuOpen
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 300),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 1000) {
                    return Column(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: paginatedOrders.length,
                              itemBuilder: (context, index) {
                                final order = paginatedOrders[index];
                                final realIndex = index;
                                final price =
                                    10000 -
                                    (order['prixPercent'] / 100 * 10000);

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 4,
                                  ),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white,
                                          Colors.grey.shade50,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Client: ${order['client']}',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Produit: ${order['product']}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          Text(
                                            'Quantité: ${order['quantity']}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                          Text(
                                            'Pourcentage %: ${order['prixPercent']}%',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          Text(
                                            'Prix: ${price.toStringAsFixed(2)}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          Row(
                                            children: <Widget>[
                                              const Text('Numero Telephone: '),
                                              Expanded(
                                                child: Text(
                                                  order['number']?.toString() ??
                                                      '',
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.copy,
                                                  size: 18,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                tooltip: 'Copy number',
                                                onPressed: () {
                                                  final numberToCopy =
                                                      order['number']
                                                          ?.toString() ??
                                                      '';
                                                  if (numberToCopy.isNotEmpty) {
                                                    Clipboard.setData(
                                                      ClipboardData(
                                                        text: numberToCopy,
                                                      ),
                                                    );
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Numéro "$numberToCopy" copié!',
                                                        ),
                                                      ),
                                                    );
                                                  } else {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Rien à copié!.',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                          Text(
                                            'Etat Commande: ${order['state']}',
                                            style: TextStyle(
                                              color: _stateColor(
                                                order['state'],
                                              ),
                                            ),
                                          ),
                                          Text('Crée Par: ${order['name']}'),
                                          Text(
                                            'Etat Val: ${order['accepted'] ?? false ? "Valide" : "Non Valide"}',
                                            style: TextStyle(
                                              color:
                                                  (order['accepted'] ?? false)
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),

                                          Text(
                                            'Accépté: ${order['acceptedBy']}',
                                          ),
                                          Text(
                                            'Date: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.parse(order['date']))}',
                                          ),
                                          const SizedBox(height: 8),
                                          if (isAdminn)
                                            Wrap(
                                              alignment: WrapAlignment.end,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.check,
                                                    color: Colors.green,
                                                  ),
                                                  onPressed: () =>
                                                      _changeOrderState(
                                                        realIndex,
                                                        'Effectué',
                                                      ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.close,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () =>
                                                      _changeOrderState(
                                                        realIndex,
                                                        'Rejeté',
                                                      ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.phone_disabled,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () =>
                                                      _changeOrderState(
                                                        realIndex,
                                                        'Numéro Incorrecte',
                                                      ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.money_off_csred,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () =>
                                                      _changeOrderState(
                                                        realIndex,
                                                        'Probléme Solde',
                                                      ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.hourglass_bottom,
                                                    color: Colors.orange,
                                                  ),
                                                  onPressed: () =>
                                                      _changeOrderState(
                                                        realIndex,
                                                        'En Attente',
                                                      ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    color: Colors.blue,
                                                  ),
                                                  onPressed: () =>
                                                      _showEditDialog(
                                                        realIndex,
                                                      ),
                                                ),
                                                if (order['product'] ==
                                                    'STORM STI')
                                                  IconButton(
                                                    icon: const Icon(
                                                      FontAwesomeIcons.whatsapp,
                                                      color: Colors.green,
                                                    ),
                                                    onPressed: () =>
                                                        _sendOrderToWhatsApp(
                                                          order,
                                                        ),
                                                  ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.black,
                                                  ),
                                                  onPressed: () =>
                                                      _confirmDeleteOrder(
                                                        realIndex,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          if (isSuserr)
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.check,
                                                    color: Colors.green,
                                                  ),
                                                  onPressed: () => handleAccept(
                                                    true,
                                                    realIndex,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.close,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () => handleAccept(
                                                    false,
                                                    realIndex,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    color: Colors.blue,
                                                  ),
                                                  onPressed: () =>
                                                      _showEditDialog(
                                                        realIndex,
                                                      ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }, // End of itemBuilder function
                            ), // End of ListView.builder
                          ), // End of Container
                        ), // End of Expanded
                        _buildPaginationControls(),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: DataTable(
                                columnSpacing: 5,
                                columns: [
                                  _buildSortableColumn('Client', 'client'),
                                  _buildSortableColumn('Produit', 'product'),
                                  _buildSortableColumn('Quantité', 'quantity'),
                                  _buildSortableColumn('PU %', 'prixPercent'),
                                  const DataColumn(label: Text('Prix')),
                                  _buildSortableColumn('Numéro ', 'number'),
                                  _buildSortableColumn('Etat C', 'state'),
                                  _buildSortableColumn('Crée Par', 'name'),
                                  _buildSortableColumn('Etat Val', 'accepted'),
                                  _buildSortableColumn('Accépté', 'acceptedBy'),
                                  _buildSortableColumn('Date', 'date'),
                                  if (isAdminn || isSuserr)
                                    const DataColumn(label: Text('Actions')),
                                ],
                                rows: List.generate(paginatedOrders.length, (
                                  index,
                                ) {
                                  final order = paginatedOrders[index];
                                  final realIndex = index;
                                  final calcPrice =
                                      10000 -
                                      (order['prixPercent'] / 100 * 10000);

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(order['client'] ?? '')),
                                      DataCell(Text(order['product'])),
                                      DataCell(Text('${order['quantity']}')),
                                      DataCell(
                                        Text('${order['prixPercent']}%'),
                                      ),
                                      DataCell(
                                        Text(calcPrice.toStringAsFixed(2)),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                order['number'] ?? '',
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.copy,
                                                size: 18,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () {
                                                final numberToCopy =
                                                    order['number']
                                                        ?.toString() ??
                                                    '';
                                                if (numberToCopy.isNotEmpty) {
                                                  Clipboard.setData(
                                                    ClipboardData(
                                                      text: numberToCopy,
                                                    ),
                                                  );
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Number "$numberToCopy" copied!',
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Nothing to copy.',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          order['state'],
                                          style: TextStyle(
                                            color: _stateColor(order['state']),
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(order['name'])),
                                      DataCell(
                                        (order['accepted'] ?? false)
                                            ? const Text(
                                                "Valide",
                                                style: TextStyle(
                                                  color: Colors.green,
                                                ),
                                              )
                                            : const Text(
                                                "Non Valide",
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                      ),
                                      DataCell(
                                        Text(order['acceptedBy'] ?? " "),
                                      ),
                                      DataCell(
                                        Text(
                                          DateFormat(
                                            'dd/MM/yyyy HH:mm:ss',
                                          ).format(
                                            DateTime.parse(order['date']),
                                          ),
                                        ),
                                      ),
                                      if (isAdminn)
                                        DataCell(
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.check,
                                                    color: Colors.green,
                                                  ),
                                                  onPressed: () =>
                                                      _changeOrderState(
                                                        realIndex,
                                                        'Effectué',
                                                      ),
                                                ),
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.close,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () =>
                                                      _changeOrderState(
                                                        realIndex,
                                                        'Rejeté',
                                                      ),
                                                ),
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.phone_disabled,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () =>
                                                      _changeOrderState(
                                                        realIndex,
                                                        'Numéro Incorrecte',
                                                      ),
                                                ),
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.money_off_csred,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () =>
                                                      _changeOrderState(
                                                        realIndex,
                                                        'Probléme Solde',
                                                      ),
                                                ),
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.hourglass_bottom,
                                                    color: Colors.orange,
                                                  ),
                                                  onPressed: () =>
                                                      _changeOrderState(
                                                        realIndex,
                                                        'En Attente',
                                                      ),
                                                ),
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    color: Colors.blue,
                                                  ),
                                                  onPressed: () =>
                                                      _showEditDialog(
                                                        realIndex,
                                                      ),
                                                ),
                                                if (order['product'] ==
                                                    'STORM STI')
                                                  IconButton(
                                                    icon: const Icon(
                                                      FontAwesomeIcons.whatsapp,
                                                      color: Colors.green,
                                                    ),
                                                    onPressed: () =>
                                                        _sendOrderToWhatsApp(
                                                          order,
                                                        ),
                                                  ),
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.black,
                                                  ),
                                                  onPressed: () =>
                                                      _confirmDeleteOrder(
                                                        realIndex,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      if (isSuserr)
                                        DataCell(
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.check,
                                                  color: Colors.green,
                                                ),
                                                onPressed: () => handleAccept(
                                                  true,
                                                  realIndex,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.close,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () => handleAccept(
                                                  false,
                                                  realIndex,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit,
                                                  color: Colors.blue,
                                                ),
                                                onPressed: () =>
                                                    _showEditDialog(realIndex),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                        _buildPaginationControls(),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProductFilter() {
    return ElevatedButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) {
            TextEditingController searchController = TextEditingController();
            List<String> filteredProducts = productCheckboxes.keys.toList();
            Map<String, bool> tempProductCheckboxes = Map.from(
              productCheckboxes,
            );

            return StatefulBuilder(
              builder: (context, setDialogState) {
                void filterSearch(String query) {
                  setDialogState(() {
                    filteredProducts = tempProductCheckboxes.keys
                        .where(
                          (product) => product.toLowerCase().contains(
                            query.toLowerCase(),
                          ),
                        )
                        .toList();
                  });
                }

                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    width: 400,
                    height: 500,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Sélectionner Produits',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: searchController,
                          onChanged: filterSearch,
                          decoration: InputDecoration(
                            hintText: 'Rechercher produits...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              return CheckboxListTile(
                                title: Text(
                                  product,
                                  style: TextStyle(fontSize: 12),
                                ),
                                value: tempProductCheckboxes[product],
                                onChanged: (value) {
                                  setDialogState(() {
                                    tempProductCheckboxes[product] = value!;
                                  });
                                },
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                dense: true,
                              );
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  tempProductCheckboxes.updateAll(
                                    (key, value) => true,
                                  );
                                });
                              },
                              child: Text('Tout Sélectionner'),
                            ),
                            TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  tempProductCheckboxes.updateAll(
                                    (key, value) => false,
                                  );
                                });
                              },
                              child: Text('Tout Désélectionner'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('Annuler'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  productCheckboxes = Map.from(
                                    tempProductCheckboxes,
                                  );
                                });
                                _applyFiltersAndRefresh();
                                Navigator.of(context).pop();
                              },
                              child: Text('Appliquer'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade700,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_list, size: 18),
          const SizedBox(width: 8),
          Text("Filtrer Produits"),
        ],
      ),
    );
  }

  DataColumn _buildSortableColumn(String label, String key) {
    return DataColumn(
      label: Text(label),
      onSort: (columnIndex, _) {
        setState(() {
          if (sortColumn == key) {
            sortAscending = !sortAscending;
          } else {
            sortColumn = key;
            sortAscending = true;
          }
        });
      },
    );
  }

  Color _stateColor(String state) {
    switch (state) {
      case 'Effectué':
        return Colors.green;
      case 'Rejeté':
        return Colors.red;
      case 'En Attente':
        return Colors.orange;
      case 'Numéro Incorrecte':
        return Colors.red;
      case 'Probléme Solde':
        return Colors.red;
      default:
        return Colors.black;
    }
  }
}
