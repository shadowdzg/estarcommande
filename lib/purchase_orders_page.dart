import 'package:EstStarCommande/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'dart:math' as math;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kDebugMode;
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path/path.dart' as p;
import 'package:google_fonts/google_fonts.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'services/network_service.dart';

// Animation imports

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
bool isDelegatee = false;
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

isDelegue() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token') ?? '';
  final payload = decodeJwtPayload(token);
  final isDelegue = payload['isDelegue'] == 1;
  return isDelegue;
}

isSuper() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token') ?? '';
  final payload = decodeJwtPayload(token);
  final isSuper = payload['issuper'] == 1;
  return isSuper;
}

getUserRegion() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token') ?? '';
  final payload = decodeJwtPayload(token);
  return payload['region']; // Assuming the region is stored in the JWT payload
}

bool isMobile() {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

bool isDesktop() {
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

DateTimeRange? selectedDateRange;

// Separate widget for product search to prevent rebuild issues
// Client Search Widget - Separate from dialog state
class ClientSearchWidget extends StatefulWidget {
  final Function(String clientName, String clientId) onClientSelected;

  const ClientSearchWidget({Key? key, required this.onClientSelected})
    : super(key: key);

  @override
  _ClientSearchWidgetState createState() => _ClientSearchWidgetState();
}

class _ClientSearchWidgetState extends State<ClientSearchWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isDisposed = false;
  Map<String, String> _clientsMap = {};

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<String>(
      controller: _controller,
      focusNode: _focusNode,
      hideOnEmpty: true,
      hideOnError: true,
      hideOnLoading: false,
      retainOnLoading: true,
      autoFlipDirection: false,
      hideKeyboardOnDrag: false,
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Search Client',
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      },
      suggestionsCallback: (pattern) async {
        if (pattern.isEmpty) return [];
        try {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token') ?? '';

          // Use dynamic server selection for client search
          final networkService = NetworkService();
          final serverConfig = await networkService.getBestAvailableServer();
          if (!serverConfig.isAvailable) {
            return [];
          }

          final response = await http.get(
            Uri.parse(
              '${serverConfig.apiBaseUrl}/clients/search?term=$pattern',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200) {
            final List<dynamic> clientsJson = jsonDecode(response.body);
            _clientsMap = {
              for (var client in clientsJson)
                client['clientName']: client['clientsID'],
            };
            return _clientsMap.keys.toList();
          }
          return [];
        } catch (e) {
          return [];
        }
      },
      itemBuilder: (context, String suggestion) => ListTile(
        leading: Icon(Icons.person, color: const Color(0xFFDC2626), size: 20),
        title: Text(suggestion),
        subtitle: Text('ID: ${_clientsMap[suggestion] ?? 'N/A'}'),
      ),
      onSelected: (String suggestion) {
        if (!_isDisposed) {
          // Immediately call callback without any delays
          widget.onClientSelected(suggestion, _clientsMap[suggestion] ?? '');

          // Clear field after a very short delay to avoid focus conflicts
          Timer(Duration(milliseconds: 50), () {
            if (!_isDisposed && mounted) {
              _controller.clear();
            }
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class ProductSearchWidget extends StatefulWidget {
  final List<Product> availableProducts;
  final Function(Product) onProductSelected;

  const ProductSearchWidget({
    Key? key,
    required this.availableProducts,
    required this.onProductSelected,
  }) : super(key: key);

  @override
  _ProductSearchWidgetState createState() => _ProductSearchWidgetState();
}

class _ProductSearchWidgetState extends State<ProductSearchWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isDisposed = false;

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<Product>(
      controller: _controller,
      focusNode: _focusNode,
      hideOnEmpty: true,
      hideOnError: true,
      hideOnLoading: false,
      retainOnLoading: true,
      autoFlipDirection: false,
      hideKeyboardOnDrag: false,
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Add Product',
            prefixIcon: Icon(Icons.inventory_2, color: Colors.grey.shade600),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      },
      suggestionsCallback: (pattern) {
        if (pattern.isEmpty) return [];
        return widget.availableProducts
            .where(
              (p) =>
                  p.productName!.toLowerCase().contains(pattern.toLowerCase()),
            )
            .toList();
      },
      itemBuilder: (context, Product suggestion) => ListTile(
        leading: Icon(
          Icons.inventory_2,
          color: const Color(0xFFDC2626),
          size: 20,
        ),
        title: Text(suggestion.productName ?? ''),
        subtitle: Text(
          'Price: ${suggestion.initialPrice?.toStringAsFixed(2) ?? '0.00'} DA',
        ),
      ),
      onSelected: (Product suggestion) {
        if (!_isDisposed) {
          // Immediately call callback without delays
          widget.onProductSelected(suggestion);

          // Clear field after a very short delay
          Timer(Duration(milliseconds: 50), () {
            if (!_isDisposed && mounted) {
              _controller.clear();
            }
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({Key? key}) : super(key: key);

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();

  int _totalOrdersCount = 0;
  List<Map<String, dynamic>> _currentPageOrders = [];
  String _whatsappNumber = "213770940827"; // Default WhatsApp number

  // Search cache for performance optimization
  List<Map<String, dynamic>> _searchCache = [];
  DateTime? _searchCacheTime;
  bool _isSearchCacheLoaded = false;
  static const Duration _searchCacheExpiry = Duration(
    minutes: 10,
  ); // Cache expires after 10 minutes

  // Local cache for ALL orders - downloaded once and stored locally
  List<Map<String, dynamic>> _allOrdersCache = [];
  bool _isLocalCacheLoaded = false;
  bool _isLoadingCache = false;
  bool _isRefreshingInBackground = false;

  // ✨ Animation Controllers
  late AnimationController _staggeredListController;
  late AnimationController _fabController;
  late AnimationController _searchBarController;
  late AnimationController _rippleController;
  late AnimationController _layoutTransitionController;
  late AnimationController _fadeController;
  late AnimationController _pageTransitionController;
  late AnimationController _textFadeController;
  late AnimationController _newOrderController;

  // Animation instances
  late Animation<double> _searchBarScale;
  late Animation<double> _newOrderScaleAnimation;

  // State for animations
  bool _isSearchFocused = false;
  final List<AnimationController> _cardControllers = [];
  final Map<String, AnimationController> _rippleControllers = {};

  // 🖥️ Windows Desktop-specific animations
  final Map<String, bool> _isHovered = {};
  int _currentColumnCount = 1;

  // Connection status tracking
  bool _isConnected = true;
  String _connectionStatus = 'Connected';

  // Network service for dynamic server selection
  final NetworkService _networkService = NetworkService();

  // Helper method to get the current server's base URL
  Future<String> _getServerBaseUrl() async {
    final serverConfig = await _networkService.getBestAvailableServer();
    return serverConfig.url;
  }

  // Helper method to get the current server's API base URL
  Future<String> _getApiBaseUrl() async {
    final serverConfig = await _networkService.getBestAvailableServer();
    return serverConfig.apiBaseUrl;
  }

  Timer? _connectionCheckTimer;

  // Optimized helper function to parse percentage strings
  static double _parsePercentage(dynamic percentage) {
    if (percentage == null) return 0.0;
    if (percentage is double) return percentage;
    if (percentage is int) return percentage.toDouble();

    String percentStr = percentage.toString();
    if (percentStr.endsWith('%')) {
      percentStr = percentStr.substring(0, percentStr.length - 1);
    }
    return double.tryParse(percentStr) ?? 0.0;
  }

  // Add refresh method for new orders
  Future<void> refreshCache() async {
    print('DEBUG: Refreshing cache for new orders...');
    _isLocalCacheLoaded = false;
    _isLoadingCache = false;
    _allOrdersCache.clear();
    _clearSearchCache(); // Also clear search cache
    await _loadAllOrdersToCache();
  }

  // Clear search cache
  void _clearSearchCache() {
    _searchCache.clear();
    _searchCacheTime = null;
    _isSearchCacheLoaded = false;
    print('DEBUG: Search cache cleared');
  }

  // Check if search cache is valid
  bool _isSearchCacheValid() {
    if (!_isSearchCacheLoaded || _searchCacheTime == null) {
      return false;
    }
    final now = DateTime.now();
    final isValid = now.difference(_searchCacheTime!) < _searchCacheExpiry;
    if (!isValid) {
      print(
        'DEBUG: Search cache expired (${now.difference(_searchCacheTime!).inMinutes} minutes old)',
      );
    }
    return isValid;
  }

  // Load search cache (all orders for searching)
  Future<void> _loadSearchCache() async {
    if (_isSearchCacheValid()) {
      print(
        'DEBUG: Using valid search cache with ${_searchCache.length} orders',
      );
      return;
    }

    print('DEBUG: Loading search cache...');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    // Get user info for proper endpoint
    final userInfo = await _getCachedUserInfo();
    final userIsDelegue = userInfo['isDelegue'] as bool;
    final userRegion = userInfo['region'] as String?;

    // Use NetworkService to get the current server's API base URL
    final apiBaseUrl = await _getApiBaseUrl();

    final String baseUrl;
    if (userIsDelegue && userRegion != null) {
      baseUrl = '$apiBaseUrl/commands/zone/$userRegion';
    } else {
      baseUrl = '$apiBaseUrl/commands';
    }

    // Fetch ALL orders for search cache - same for all users
    final queryParams = {
      'skip': '0',
      'take': '2377', // Get all orders
    };

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

    try {
      print('DEBUG: Fetching all orders for search cache...');
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final ordersList = (data['data'] ?? []) as List<dynamic>;

        // Process orders for search cache
        _searchCache = ordersList.map<Map<String, dynamic>>((item) {
          final clientName = _extractClientName(item);
          return {
            'id': item['id'],
            'client': clientName,
            'product': item['operator'] ?? 'Unknown',
            'quantity': item['amount'] ?? 0,
            'prixPercent':
                double.tryParse(
                  (item['pourcentage'] ?? '0').toString().replaceAll('%', ''),
                ) ??
                0,
            'state': item['isValidated'] ?? 'En Attente',
            'name': item['users']?['username'] ?? 'Unknown',
            'number': item['number'] ?? 'Unknown',
            'accepted': item['accepted'] ?? 'Unknown',
            'acceptedBy': item['acceptedBy'] ?? ' ',
            'date': item['createdAt'] ?? '',
            // Keep original data for advanced filtering
            'ClientsID': item['ClientsID'],
            'newClientID': item['newClientID'],
          };
        }).toList();

        _searchCacheTime = DateTime.now();
        _isSearchCacheLoaded = true;

        print('DEBUG: Search cache loaded with ${_searchCache.length} orders');
      } else {
        print('DEBUG: Failed to load search cache: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Error loading search cache: $e');
    }
  }

  // Add new order to cache instantly (optimistic update)
  void addOrderToCache(Map<String, dynamic> newOrder) {
    print('DEBUG: Adding new order to cache instantly');

    // Add to beginning of cache (newest first)
    _allOrdersCache.insert(0, newOrder);

    // Update total count
    _totalOrdersCount = _allOrdersCache.length;

    // Invalidate search cache since we have new data
    _clearSearchCache();

    // Start new order animation
    _newOrderController.reset();
    _newOrderController.forward();

    // Refresh current view
    if (mounted) {
      setState(() {
        if (searchQuery.isNotEmpty) {
          _performLocalSearch(
            searchQuery: searchQuery,
            page: 0, // Go to first page to see new order
            pageSize: _rowsPerPage,
            stateFilter: selectedState,
            productFilters: productCheckboxes.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList(),
            dateRange: selectedDateRange,
          );
        } else {
          _performLocalBrowsing(
            page: 0, // Go to first page to see new order
            pageSize: _rowsPerPage,
            stateFilter: selectedState,
            productFilters: productCheckboxes.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList(),
            dateRange: selectedDateRange,
          );
        }
        _currentPage = 0; // Reset to first page
      });
    }
  }

  // Update existing order in cache
  void updateOrderInCache(dynamic orderId, Map<String, dynamic> updatedOrder) {
    print('DEBUG: Updating order $orderId in cache');

    final index = _allOrdersCache.indexWhere((order) => order['id'] == orderId);
    if (index != -1) {
      _allOrdersCache[index] = updatedOrder;

      // Refresh current view
      if (mounted) {
        setState(() {
          if (searchQuery.isNotEmpty) {
            _performLocalSearch(
              searchQuery: searchQuery,
              page: _currentPage,
              pageSize: _rowsPerPage,
              stateFilter: selectedState,
              productFilters: productCheckboxes.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList(),
              dateRange: selectedDateRange,
            );
          } else {
            _performLocalBrowsing(
              page: _currentPage,
              pageSize: _rowsPerPage,
              stateFilter: selectedState,
              productFilters: productCheckboxes.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList(),
              dateRange: selectedDateRange,
            );
          }
        });
      }
    }
  }

  // Remove order from cache when deleted
  void removeOrderFromCache(dynamic orderId) {
    print('DEBUG: Removing order $orderId from cache');

    final initialLength = _allOrdersCache.length;
    _allOrdersCache.removeWhere((order) => order['id'] == orderId);
    final newLength = _allOrdersCache.length;

    if (initialLength > newLength) {
      print(
        'DEBUG: Successfully removed order $orderId from cache. Size: $initialLength → $newLength',
      );

      // Refresh current view
      if (mounted) {
        setState(() {
          if (searchQuery.isNotEmpty) {
            _performLocalSearch(
              searchQuery: searchQuery,
              page: _currentPage,
              pageSize: _rowsPerPage,
              stateFilter: selectedState,
              productFilters: productCheckboxes.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList(),
              dateRange: selectedDateRange,
            );
          } else {
            _performLocalBrowsing(
              page: _currentPage,
              pageSize: _rowsPerPage,
              stateFilter: selectedState,
              productFilters: productCheckboxes.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList(),
              dateRange: selectedDateRange,
            );
          }
        });
      }
    } else {
      print('DEBUG: Order $orderId not found in cache for removal');
    }
  }

  // Update order state in cache
  void updateOrderStateInCache(dynamic orderId, String newState) {
    print('DEBUG: Updating order $orderId state to $newState in cache');

    final index = _allOrdersCache.indexWhere((order) => order['id'] == orderId);
    if (index != -1) {
      _allOrdersCache[index]['state'] = newState;
      print('DEBUG: Successfully updated order $orderId state in cache');

      // Refresh current view to show the updated state
      if (mounted) {
        setState(() {
          if (searchQuery.isNotEmpty) {
            _performLocalSearch(
              searchQuery: searchQuery,
              page: _currentPage,
              pageSize: _rowsPerPage,
              stateFilter: selectedState,
              productFilters: productCheckboxes.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList(),
              dateRange: selectedDateRange,
            );
          } else {
            _performLocalBrowsing(
              page: _currentPage,
              pageSize: _rowsPerPage,
              stateFilter: selectedState,
              productFilters: productCheckboxes.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList(),
              dateRange: selectedDateRange,
            );
          }
        });
      }
    } else {
      print('DEBUG: Order $orderId not found in cache for state update');
    }
  }

  // Auto-refresh cache periodically for new orders from other users
  Timer? _cacheRefreshTimer;

  // Socket.IO for real-time updates
  IO.Socket? _socket;
  bool _isSocketConnected = false;

  void _startCacheAutoRefresh() {
    _cacheRefreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      // Periodic database refresh: 2 minutes (optimized for better performance)
      if (mounted) {
        // Don't refresh cache if user is actively searching
        if (searchQuery.isEmpty) {
          // Auto-refreshing from database with filters preserved
          fetchPurchaseOrders(
            page: _currentPage,
            pageSize: _rowsPerPage,
            keepPage: true,
            stateFilter: selectedState,
            productFilters: productCheckboxes.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList(),
            dateRange: selectedDateRange,
          );
        } else {
          print(
            'DEBUG: Skipping cache auto-refresh during active search: "$searchQuery"',
          );
        }
      }
    });
  }

  // Socket.IO real-time communication
  Future<void> _connectWebSocket() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      if (token.isEmpty) {
        print('DEBUG: No auth token for Socket.IO connection');
        return;
      }

      // Superuser uses same Socket.IO as admin - no special handling needed

      // Debug token validity
      try {
        // Check if token is expired by trying to decode it
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalizedPayload = base64Url.normalize(payload);
          final payloadMap = json.decode(
            utf8.decode(base64Url.decode(normalizedPayload)),
          );
          final exp = payloadMap['exp'];
          if (exp != null) {
            final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
            final now = DateTime.now();
            print('DEBUG: Token expires at: $expiryDate');
            print('DEBUG: Current time: $now');
            print(
              'DEBUG: Token is ${now.isAfter(expiryDate) ? 'EXPIRED' : 'VALID'}',
            );

            if (now.isAfter(expiryDate)) {
              print(
                'DEBUG: Token is expired, Socket.IO connection will likely fail with 401/404',
              );
              return;
            }
          }
        }
      } catch (e) {
        print('DEBUG: Could not decode token for validation: $e');
      }

      // Check if WebSocket is enabled in settings
      final isWebSocketEnabled = prefs.getBool('enable_websocket') ?? false;
      if (!isWebSocketEnabled) {
        print('DEBUG: WebSocket disabled in settings, using HTTP polling only');
        return;
      }

      // Use the same server as API calls for consistency
      final serverUrl = await _getServerBaseUrl();

      print('DEBUG: WebSocket enabled: $isWebSocketEnabled');
      print('DEBUG: Connecting to Socket.IO server: $serverUrl');
      print('DEBUG: Auth token length: ${token.length}');

      // Connect to Socket.IO server with JWT authentication (matches API guide)
      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setAuth({
              'token': token, // Server expects 'token' in auth object
            })
            .build(),
      );

      // Connection event handlers
      _socket!.onConnect((_) {
        print('DEBUG: Socket.IO connected successfully');
        _isSocketConnected = true;
        _subscribeToCommands(); // This will now use the correct server events
      });

      _socket!.onDisconnect((_) {
        print('DEBUG: Socket.IO disconnected');
        _isSocketConnected = false;
      });

      _socket!.onConnectError((error) {
        print('DEBUG: Socket.IO connection error: $error');
        _isSocketConnected = false;
        _reconnectWebSocket();
      });

      // Listen for command updates (matches server event name)
      _socket!.on('commandUpdated', (data) {
        print('DEBUG: Received command update: $data');
        _handleCommandUpdate(data);
      });

      // Listen for command data responses (matches server event name)
      _socket!.on('commandsData', (data) {
        print('DEBUG: Received commandsData event');
        _handleCommandsData(data);
      });

      // Listen for subscription confirmations (matches server event name)
      _socket!.on('subscriptionConfirmed', (data) {
        print('DEBUG: Subscription confirmed: $data');
      });

      // Listen for unsubscription confirmations
      _socket!.on('unsubscriptionConfirmed', (data) {
        print('DEBUG: Unsubscription confirmed: $data');
      });

      // Listen for connection errors
      _socket!.on('connect_error', (error) {
        print('DEBUG: Socket.IO connection error: $error');
        if (error.toString().contains('Authentication error')) {
          print('DEBUG: Authentication failed - token may be invalid/expired');
        } else if (error.toString().contains('404')) {
          print(
            'DEBUG: Socket.IO not available on server - falling back to HTTP polling',
          );
          // Could implement HTTP polling fallback here
        }
      });

      // Listen for errors
      _socket!.on('error', (error) {
        print('DEBUG: Socket.IO error: $error');
      });

      // Connect
      _socket!.connect();
    } catch (e) {
      print('DEBUG: Failed to connect Socket.IO: $e');
      _reconnectWebSocket();
    }
  }

  // Subscribe to real-time command updates
  void _subscribeToCommands() {
    if (_socket != null && _isSocketConnected) {
      final filters = {
        'startDate': DateTime.now()
            .subtract(Duration(days: 30))
            .toIso8601String(),
        'endDate': DateTime.now().toIso8601String(),
      };

      final pagination = {
        'skip': 0,
        'take': 100, // Subscribe to latest 100 commands
      };

      _socket!.emit('subscribeToCommands', {
        'filters': filters,
        'pagination': pagination,
      });

      print('DEBUG: Subscribed to real-time command updates');
    }
  }

  // Handle real-time command updates
  void _handleCommandUpdate(dynamic data) {
    try {
      final updateType = data['type'];
      final command = data['command'];

      print('DEBUG: Command update type: $updateType');

      switch (updateType) {
        case 'created':
          _handleOrderCreated(command);
          break;
        case 'updated':
          _handleOrderUpdated(command);
          break;
        case 'deleted':
          _handleOrderDeleted(command);
          break;
        default:
          print('DEBUG: Unknown command update type: $updateType');
      }
    } catch (e) {
      print('DEBUG: Error handling command update: $e');
    }
  }

  // Handle commands data response (matches new API format)
  void _handleCommandsData(dynamic response) {
    try {
      if (response is Map<String, dynamic>) {
        final data = response['data'] as List<dynamic>?;
        final totalCount = response['totalCount'] as int?;

        print('DEBUG: Received ${data?.length ?? 0} commands from Socket.IO');
        print('DEBUG: Total count: ${totalCount ?? 0}');

        if (data != null) {
          // Process the commands data - could be used for initial loading
          // or updating the UI with real-time data
        }
      } else if (response is List) {
        // Fallback for old format
        print(
          'DEBUG: Processing ${response.length} commands from Socket.IO (legacy format)',
        );
      }
    } catch (e) {
      print('DEBUG: Error handling commands data: $e');
    }
  }

  void _handleOrderCreated(Map<String, dynamic> orderData) {
    print('DEBUG: Real-time order created: ${orderData['id']}');

    // Process the new order with correct field mapping
    String clientName = 'Unknown';
    if (orderData['clients'] is Map &&
        orderData['clients']['clientName'] != null) {
      clientName = orderData['clients']['clientName'].toString();
    }

    final newOrder = {
      'id': orderData['id'] ?? 0,
      'client': clientName,
      'product': orderData['operator'] ?? 'Unknown',
      'number': orderData['number'] ?? 'N/A',
      'quantity': orderData['amount'] ?? 0,
      'state': orderData['isValidated'] ?? 'En Attente',
      'name': (orderData['users'] != null && orderData['users'] is Map)
          ? orderData['users']['username'] ?? 'Unknown'
          : orderData['username'] ?? 'Unknown',
      'accepted': orderData['accepted'] ?? true,
      'acceptedBy': orderData['acceptedBy'] ?? ' ',
      'date': orderData['createdAt'] ?? '',
      'prixPercent': _parsePercentage(orderData['pourcentage']),
    };

    // Add to beginning of cache
    _allOrdersCache.insert(0, newOrder);

    // Refresh UI
    if (mounted) {
      setState(() {
        if (searchQuery.isNotEmpty) {
          _performLocalSearch(
            searchQuery: searchQuery,
            page: _currentPage,
            pageSize: _rowsPerPage,
            stateFilter: selectedState,
            productFilters: productCheckboxes.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList(),
            dateRange: selectedDateRange,
          );
        } else {
          _performLocalBrowsing(
            page: _currentPage,
            pageSize: _rowsPerPage,
            stateFilter: selectedState,
            productFilters: productCheckboxes.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList(),
            dateRange: selectedDateRange,
          );
        }
      });
    }

    // Show notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'New order from ${newOrder['name']} - ${newOrder['client']}',
          ),
          backgroundColor: const Color(0xFF1F2937), // Dark grey for success
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleOrderUpdated(Map<String, dynamic> orderData) {
    print('DEBUG: Real-time order updated: ${orderData['id']}');

    final orderId = orderData['id'];
    final newState = orderData['isValidated'] ?? 'En Attente';

    // Update in cache
    final index = _allOrdersCache.indexWhere((order) => order['id'] == orderId);
    if (index != -1) {
      _allOrdersCache[index]['state'] = newState;

      // Refresh UI
      if (mounted) {
        setState(() {
          if (searchQuery.isNotEmpty) {
            _performLocalSearch(
              searchQuery: searchQuery,
              page: _currentPage,
              pageSize: _rowsPerPage,
              stateFilter: selectedState,
              productFilters: productCheckboxes.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList(),
              dateRange: selectedDateRange,
            );
          } else {
            _performLocalBrowsing(
              page: _currentPage,
              pageSize: _rowsPerPage,
              stateFilter: selectedState,
              productFilters: productCheckboxes.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList(),
              dateRange: selectedDateRange,
            );
          }
        });
      }
    }
  }

  void _handleOrderDeleted(Map<String, dynamic> orderData) {
    print('DEBUG: Real-time order deleted: ${orderData['id']}');

    final orderId = orderData['id'];

    // Remove from cache
    final initialLength = _allOrdersCache.length;
    _allOrdersCache.removeWhere((order) => order['id'] == orderId);
    final newLength = _allOrdersCache.length;

    if (initialLength > newLength) {
      // Refresh UI
      if (mounted) {
        setState(() {
          if (searchQuery.isNotEmpty) {
            _performLocalSearch(
              searchQuery: searchQuery,
              page: _currentPage,
              pageSize: _rowsPerPage,
              stateFilter: selectedState,
              productFilters: productCheckboxes.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList(),
              dateRange: selectedDateRange,
            );
          } else {
            _performLocalBrowsing(
              page: _currentPage,
              pageSize: _rowsPerPage,
              stateFilter: selectedState,
              productFilters: productCheckboxes.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList(),
              dateRange: selectedDateRange,
            );
          }
        });
      }
    }
  }

  void _reconnectWebSocket() {
    // Attempt to reconnect after a delay
    Timer(const Duration(seconds: 5), () {
      if (mounted && _socket != null) {
        print('DEBUG: Attempting Socket.IO reconnection...');
        _socket!.connect();
      }
    });
  }

  void _disconnectWebSocket() {
    if (_socket != null) {
      _socket!.emit('unsubscribeFromCommands');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isSocketConnected = false;
      print('DEBUG: Socket.IO disconnected');
    }
  }

  void _sendWebSocketMessage(String type, Map<String, dynamic> payload) {
    if (_socket != null && _isSocketConnected) {
      try {
        // Map old WebSocket events to new Socket.IO events
        switch (type) {
          case 'ORDER_CREATED':
            // Server will automatically broadcast command updates
            print('DEBUG: Command created - server will broadcast update');
            break;
          case 'ORDER_UPDATED':
            // Server will automatically broadcast command updates
            print('DEBUG: Command updated - server will broadcast update');
            break;
          case 'ORDER_DELETED':
            // Server will automatically broadcast command updates
            print('DEBUG: Command deleted - server will broadcast update');
            break;
          default:
            print('DEBUG: Unknown Socket.IO message type: $type');
        }
      } catch (e) {
        print('DEBUG: Failed to send Socket.IO message: $e');
      }
    } else {
      print('DEBUG: Socket.IO not connected, message skipped: $type');
    }
  }

  // Load all orders into local cache - done once at startup
  Future<void> _loadAllOrdersToCache() async {
    if (_isLocalCacheLoaded || _isLoadingCache) return;

    _isLoadingCache = true;
    print('DEBUG: Loading ALL orders to local cache...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      // Get user info
      final userInfo = await _getCachedUserInfo();
      final userIsDelegue = userInfo['isDelegue'] as bool;
      final userRegion = userInfo['region'] as String?;

      // Use NetworkService to get the current server's API base URL
      final apiBaseUrl = await _getApiBaseUrl();

      final String baseUrl;
      if (userIsDelegue && userRegion != null) {
        baseUrl = '$apiBaseUrl/commands/zone/$userRegion';
      } else {
        baseUrl = '$apiBaseUrl/commands';
      }

      List<Map<String, dynamic>> allOrders = [];
      int batchSize = 500; // Larger batches for initial load
      int currentSkip = 0;
      bool hasMoreData = true;

      while (hasMoreData) {
        print(
          'DEBUG: Loading batch: ${currentSkip + 1}-${currentSkip + batchSize}',
        );

        final Map<String, String> queryParams = {
          'skip': currentSkip.toString(),
          'take': batchSize.toString(),
        };

        final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

        final response = await http
            .get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic> orders = data['data'] ?? [];

          if (orders.isEmpty) {
            hasMoreData = false;
            break;
          }

          // Process orders - try multiple possible field names for client
          final processedOrders = orders.map((item) {
            // Try different possible field names for client name
            String clientName = 'Unknown';
            if (item['clientName'] != null &&
                item['clientName'].toString().isNotEmpty) {
              clientName = item['clientName'].toString();
            } else if (item['client'] != null &&
                item['client'].toString().isNotEmpty) {
              clientName = item['client'].toString();
            } else if (item['clients'] != null) {
              if (item['clients'] is Map &&
                  item['clients']['clientName'] != null) {
                clientName = item['clients']['clientName'].toString();
              } else if (item['clients'] is String) {
                clientName = item['clients'].toString();
              }
            } else if (item['number'] != null) {
              // Fallback: use phone number as identifier
              clientName = item['number'].toString();
            }

            // Debug first few orders to see the structure
            print('DEBUG: Order ${item['id']}: ALL FIELDS = $item');
            if (allOrders.length < 3) {
              print(
                'DEBUG: Order ${item['id']}: clientName=${item['clientName']}, clients=${item['clients']}, final=$clientName',
              );
            }

            return {
              'id': item['id'] ?? 0,
              'client': clientName,
              'product': item['operator'] ?? 'Unknown',
              'number': item['number'] ?? 'N/A',
              'quantity':
                  item['amount'] ?? 0, // Use 'amount' field for quantity
              'state': item['isValidated'] ?? 'En Attente',
              'name': (item['users'] != null && item['users'] is Map)
                  ? item['users']['username'] ?? 'Unknown'
                  : item['username'] ?? 'Unknown',
              'accepted': item['accepted'] ?? true,
              'acceptedBy': item['acceptedBy'] ?? ' ',
              'date': item['createdAt'] ?? '',
              'prixPercent': _parsePercentage(
                item['pourcentage'],
              ), // Parse percentage properly
            };
          }).toList();

          allOrders.addAll(processedOrders);

          // Show data immediately after first batch for better UX
          if (currentSkip == 0 && allOrders.isNotEmpty) {
            _allOrdersCache = List.from(allOrders);
            _isLocalCacheLoaded = true;
            print(
              'DEBUG: Showing first ${allOrders.length} orders immediately',
            );
            print(
              'DEBUG: Sample cached order: ${allOrders.first}',
            ); // Debug the cached data structure

            // Trigger UI update with first batch
            if (mounted) {
              setState(() {
                _performLocalBrowsing(page: 0, pageSize: _rowsPerPage);
              });
            }
          }

          // If we got less than batchSize, we've reached the end
          if (orders.length < batchSize) {
            hasMoreData = false;
          }

          currentSkip += batchSize;
        } else {
          print('DEBUG: Error loading cache: ${response.statusCode}');
          hasMoreData = false;
        }
      }

      _allOrdersCache = allOrders;
      _isLocalCacheLoaded = true;

      print(
        'DEBUG: Local cache loaded! ${_allOrdersCache.length} orders cached',
      );

      // Save to persistent cache for next app startup
    } catch (e) {
      print('DEBUG: Error loading local cache: $e');
    } finally {
      _isLoadingCache = false;
    }
  }

  // Fast local search through cached data
  void _performLocalSearch({
    required String searchQuery,
    required int page,
    required int pageSize,
    String? stateFilter,
    List<String>? productFilters,
    DateTimeRange? dateRange,
  }) {
    // Performing local search

    // Filter the cached data
    var filteredOrders = _allOrdersCache.where((order) {
      // Client name search
      if (!order['client'].toLowerCase().contains(searchQuery.toLowerCase())) {
        return false;
      }

      // State filter
      if (stateFilter != null &&
          stateFilter.isNotEmpty &&
          order['state'] != stateFilter) {
        return false;
      }

      // Product filter
      if (productFilters != null && productFilters.isNotEmpty) {
        if (!productFilters.contains(order['product'])) {
          return false;
        }
      }

      // Date range filter
      if (dateRange != null) {
        try {
          final orderDate = DateTime.parse(order['date']);
          if (orderDate.isBefore(dateRange.start) ||
              orderDate.isAfter(dateRange.end)) {
            return false;
          }
        } catch (e) {
          // Skip if date parsing fails
        }
      }

      return true;
    }).toList();

    print('DEBUG: Local search found ${filteredOrders.length} matches');

    // Apply pagination
    final totalCount = filteredOrders.length;
    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, filteredOrders.length);

    final paginatedResults = filteredOrders.sublist(
      startIndex.clamp(0, filteredOrders.length),
      endIndex,
    );

    print(
      'DEBUG: Showing ${paginatedResults.length} results (${startIndex + 1}-$endIndex of $totalCount)',
    );

    if (mounted) {
      setState(() {
        _currentPageOrders = paginatedResults;
        _totalOrdersCount = totalCount;
        _hasActiveFilters = true;
      });
    }
  }

  Future<void> fetchPurchaseOrders({
    int page = 0,
    int pageSize = 10,
    bool keepPage = true,
    String? searchQuery,
    String? stateFilter,
    List<String>? productFilters,
    DateTimeRange? dateRange,
  }) async {
    // Always fetch directly from database - no cache dependency

    // Normal pagination for non-search
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final Map<String, String> queryParams = {};

    // Check if we have active filters
    bool hasActiveFilters =
        stateFilter != null ||
        (productFilters != null && productFilters.isNotEmpty) ||
        dateRange != null;

    // Normal pagination
    final int skip = keepPage ? page * pageSize : 0;
    queryParams['skip'] = skip.toString();
    queryParams['take'] = pageSize.toString();

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

    // Add search query for server-side client search
    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Test different parameter names that might work for client filtering
      // The API may not support client filtering, so we'll rely on client-side filtering
      queryParams['search'] = searchQuery; // Generic search parameter
      queryParams['clientName'] = searchQuery; // Specific client name parameter
      queryParams['client'] = searchQuery; // Alternative client parameter
      print('DEBUG: Will apply server-side client search for: $searchQuery');
      print(
        'DEBUG: Testing multiple search parameters: search, clientName, client',
      );
    }

    // Add product filter (using backend's field name 'operator')
    // Note: Backend only supports single product filter at a time
    if (productFilters != null && productFilters.isNotEmpty) {
      if (productFilters.length == 1) {
        // Single product filter - use API filtering for better performance
        queryParams['operator'] = productFilters.first;
      } else {
        // Multiple products selected - we'll need to make multiple API calls or filter client-side
        // For now, let's not use API filtering and rely on client-side filtering
        // This could be optimized by making multiple API calls and combining results
      }
    }

    // Get cached user info to avoid repeated API calls
    final userInfo = await _getCachedUserInfo();
    final userIsDelegue = userInfo['isDelegue'] as bool;
    final userRegion = userInfo['region'] as String?;

    // Use NetworkService to get the current server's API base URL
    final apiBaseUrl = await _getApiBaseUrl();

    final String baseUrl;
    if (userIsDelegue && userRegion != null) {
      // Use zone-specific endpoint for delegue users
      baseUrl = '$apiBaseUrl/commands/zone/$userRegion';
    } else {
      // Use regular endpoint for admin/superuser/client users
      baseUrl = '$apiBaseUrl/commands';
    }

    // Superuser uses same API as admin - no special pagination needed
    // The only difference is in the UI actions available (validate/not validate only)

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

    // Only log essential info in debug mode
    if (kDebugMode) {
      print('========================================');
      print('FETCH ORDERS CALLED:');
      print('  Page: $page, PageSize: $pageSize');
      print('  Search Query: ${searchQuery ?? "none"}');
      print('  Filters: ${hasActiveFilters ? 'active' : 'none'}');
      print('  URL: $uri');
      print('  Parameters: $queryParams');
      print(
        '  Stack trace: ${StackTrace.current.toString().split('\n').take(3).join('\n')}',
      );
      print('========================================');
    }

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            // Use longer timeout for search requests since they fetch more data
            (searchQuery != null && searchQuery.isNotEmpty)
                ? const Duration(seconds: 30) // Longer timeout for search
                : const Duration(seconds: 10), // Normal timeout
            onTimeout: () {
              throw TimeoutException(
                'Request timeout',
                (searchQuery != null && searchQuery.isNotEmpty)
                    ? const Duration(seconds: 30)
                    : const Duration(seconds: 10),
              );
            },
          );

      // Log response status in debug mode
      if (kDebugMode) {
        print(
          'API Response: ${response.statusCode} (${response.body.length} bytes)',
        );
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Log data info in debug mode
        if (kDebugMode) {
          final ordersList = (data['data'] ?? []) as List<dynamic>;
          print(
            'Parsed ${ordersList.length} orders, total: ${data['totalCount'] ?? 0}',
          );
        }
        if (!mounted) return;

        // Parse orders from response
        List<dynamic> ordersList = (data['data'] ?? []) as List<dynamic>;

        // Client-side filtering fallback if server-side filtering didn't work as expected
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final originalCount = ordersList.length;

          // Debug: Show actual API response structure and sample client names
          if (kDebugMode && ordersList.isNotEmpty) {
            print('DEBUG: Sample API response structure for client search:');
            final sample = ordersList.first;
            print('DEBUG: Full item keys: ${sample.keys.toList()}');
            print('DEBUG: clients field: ${sample['clients']}');
            print('DEBUG: client field: ${sample['client']}');
            print('DEBUG: clientName field: ${sample['clientName']}');
            print(
              'DEBUG: Extracted client name: ${_extractClientName(sample)}',
            );

            // Show a sample of client names to help debug
            print('DEBUG: Sample client names in response:');
            for (int i = 0; i < math.min(10, ordersList.length); i++) {
              final clientName = _extractClientName(ordersList[i]);
              print('DEBUG:   [$i] $clientName');
            }
          }

          ordersList = ordersList.where((order) {
            // Use the same extraction method as the main processing
            final clientName = _extractClientName(order).toLowerCase();
            final searchLower = searchQuery.toLowerCase();

            // Also check other fields that might contain client information
            final clientId = (order['ClientsID']?.toString() ?? '')
                .toLowerCase();
            final newClientId = (order['newClientID']?.toString() ?? '')
                .toLowerCase();

            final matches =
                clientName.contains(searchLower) ||
                clientId.contains(searchLower) ||
                newClientId.contains(searchLower);

            if (kDebugMode && matches) {
              print(
                'DEBUG: Match found - Client: "$clientName", ClientID: "$clientId", NewClientID: "$newClientId" contains "$searchLower"',
              );
            }

            return matches;
          }).toList();

          if (kDebugMode) {
            print(
              'DEBUG: Client-side filter applied. Original: $originalCount, Filtered: ${ordersList.length}',
            );
          }
        }
        final allOrders = ordersList.map<Map<String, dynamic>>((item) {
          // Optimized client name extraction
          final clientName = _extractClientName(item);

          return {
            'id': item['id'],
            'client': clientName,
            'product': item['operator'] ?? 'Unknown',
            'quantity': item['amount'] ?? 0,
            'prixPercent':
                double.tryParse(
                  (item['pourcentage'] ?? '0').toString().replaceAll('%', ''),
                ) ??
                0,
            'state': item['isValidated'] ?? 'En Attente',
            'name': item['users']?['username'] ?? 'Unknown',
            'number': item['number'] ?? 'Unknown',
            'accepted': item['accepted'] ?? 'Unknown',
            'acceptedBy': item['acceptedBy'] ?? ' ',
            'date': item['createdAt'] ?? '',
          };
        }).toList();

        // Apply client-side filtering for client name search and multiple products
        List<Map<String, dynamic>> filteredOrders = allOrders;

        // Store total filtered count for pagination
        int totalFilteredCount = allOrders.length;

        // Apply client-side client name filtering (enhanced for better matching)
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final searchLower = searchQuery.toLowerCase();
          filteredOrders = filteredOrders.where((order) {
            final clientName = (order['client'] ?? '').toString().toLowerCase();
            // Note: At this stage, client IDs are not available in the processed order format
            return clientName.contains(searchLower);
          }).toList();

          // Store the total filtered count before pagination
          totalFilteredCount = filteredOrders.length;

          if (kDebugMode) {
            print(
              'DEBUG: Final client-side filter applied. Total results: $totalFilteredCount',
            );
            if (filteredOrders.isNotEmpty) {
              print(
                'DEBUG: Sample filtered client names: ${filteredOrders.take(3).map((o) => o['client']).toList()}',
              );
            }
          }

          // Paginate the search results for display
          final startIndex = page * pageSize;
          final endIndex = math.min(
            startIndex + pageSize,
            filteredOrders.length,
          );
          final paginatedResults = filteredOrders.sublist(startIndex, endIndex);
          filteredOrders = paginatedResults;

          if (kDebugMode) {
            print(
              'DEBUG: Search pagination applied. Showing ${filteredOrders.length} orders (${startIndex + 1}-${startIndex + filteredOrders.length} of $totalFilteredCount)',
            );
          }
        }

        // Apply client-side product filtering when multiple products are selected
        if (productFilters != null && productFilters.length > 1) {
          print(
            'DEBUG: Applying client-side product filtering for ${productFilters.length} products: $productFilters',
          );
          filteredOrders = filteredOrders.where((order) {
            final orderProduct = order['product'];
            final isIncluded = productFilters.contains(orderProduct);
            if (!isIncluded) {
              print(
                'DEBUG: Client-side filtering out order with product "$orderProduct"',
              );
            }
            return isIncluded;
          }).toList();
          print(
            'DEBUG: After client-side product filtering: ${filteredOrders.length} orders remaining',
          );
        }

        // Handle pagination for search results
        List<Map<String, dynamic>> finalOrders;
        int totalCount;

        // Server-side filtering and pagination handles everything
        finalOrders = filteredOrders;
        totalCount = data['totalCount'] ?? filteredOrders.length;

        // Use filtered count for search results, API count for regular browsing
        final int displayTotalCount =
            (searchQuery != null && searchQuery.isNotEmpty)
            ? totalFilteredCount
            : totalCount;

        print(
          'DEBUG: Server-side results: ${finalOrders.length} orders (total: $displayTotalCount)',
        );

        if (mounted) {
          setState(() {
            _currentPageOrders = finalOrders;
            _totalOrdersCount = displayTotalCount;
          });
        }
      } else if (response.statusCode == 401) {
        // Token expired or invalid - redirect to login
        print('=== AUTHENTICATION ERROR ===');
        print('Token expired or invalid. Redirecting to login...');
        print('=============================');
        if (mounted) {
          // Clear stored token
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token');
          await prefs.remove('userid');

          // Navigate to login page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
        return;
      } else {
        // Handle other error cases
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${response.statusCode} - ${response.body}'),
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching orders: $e')));
      }
    }
  }

  // Deprecated: allOrders is not used for paginated backend data anymore.
  List<Map<String, dynamic>> allOrders = [];

  String searchQuery = '';
  String productQuery = '';
  TextEditingController productSController = TextEditingController();
  TextEditingController searchController = TextEditingController();

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
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // ✨ Initialize Animations
    _initializeAnimations();

    initializeProductCheckboxes(); // Initialize checkboxes
    _loadWhatsAppNumber(); // Load saved WhatsApp number

    // DATABASE-FIRST STRATEGY: Always fetch fresh data from database
    fetchPurchaseOrders(pageSize: _rowsPerPage);

    // Initialize search cache in background for better search performance
    _loadSearchCache();

    _startAutoRefresh();
    _startCacheAutoRefresh(); // Start auto-refresh from database
    _connectWebSocket(); // Connect Socket.IO for real-time updates
    _startConnectionMonitoring(); // Start monitoring connection status
    _checkAdmin();
    _checkSuser();
    _checkClient();
    _checkDelegue();
  }

  // ✨ Initialize Animation Controllers
  void _initializeAnimations() {
    // Staggered list animation
    _staggeredListController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // FAB orbital menu animation
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Search bar morphing animation
    _searchBarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Ripple effect animation
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // 🖥️ Layout transition animation for multi-column
    _layoutTransitionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Page fade-in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Page transition animation for pagination
    _pageTransitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Text fade animation for pagination - optimized duration
    _textFadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // New order animation
    _newOrderController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Initialize animation values
    _searchBarScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _searchBarController, curve: Curves.easeOut),
    );

    _newOrderScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _newOrderController, curve: Curves.elasticOut),
    );

    // Start page fade-in animation
    _fadeController.forward();

    // Initialize page transition controller to full opacity
    _pageTransitionController.forward();

    // Initialize text fade controller to full opacity
    _textFadeController.forward();
  }

  // Removed unused _triggerStaggeredAnimation function

  // ✨ Optimized FadeText widget with caching
  Widget _buildFadeText({
    required String text,
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _textFadeController,
        builder: (context, child) {
          return Transform.scale(
            scale:
                0.8 +
                (0.2 *
                    _textFadeController
                        .value), // Reduced scale for better performance
            child: Opacity(opacity: _textFadeController.value, child: child),
          );
        },
        child: Text(
          text,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        ),
      ),
    );
  }

  // ✨ Optimized staggered animation for list items
  Widget _buildStaggeredListItem({required Widget child, required int index}) {
    // Reduce delay for better performance
    final delay = (index * 50).clamp(0, 300);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)), // Reduced movement
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }

  // ✨ Create animated morphing filter chip
  Widget _buildMorphingFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
    required IconData icon,
    Color? selectedColor,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final scale = 1.0 + (0.1 * value); // Scale up when selected
        final color = isSelected
            ? selectedColor ??
                  Colors
                      .blue
                      .shade600 // Solid color when selected
            : Colors.grey.shade100;
        final textColor = isSelected
            ? Colors
                  .white // Always white text when selected for visibility
            : Colors.grey.shade700;

        return Transform.scale(
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? (selectedColor ?? const Color(0xFFDC2626)).withOpacity(
                        0.8,
                      )
                    : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (selectedColor ?? const Color(0xFFDC2626))
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: textColor),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.check_circle, size: 14, color: textColor),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ✨ Build animated state filter chips
  Widget _buildAnimatedStateFilters() {
    // 🎨 New monochrome color scheme with red accent
    final states = [
      {
        'label': 'Tous',
        'value': null,
        'icon': Icons.all_inclusive,
        'color': const Color(0xFF374151), // Dark grey
      },
      {
        'label': 'En Attente',
        'value': 'En Attente',
        'icon': Icons.hourglass_empty,
        'color': const Color(0xFF6B7280), // Medium grey
      },
      {
        'label': 'Effectué',
        'value': 'Effectué',
        'icon': Icons.check_circle,
        'color': const Color(0xFF1F2937), // Rich black
      },
      {
        'label': 'Rejeté',
        'value': 'Rejeté',
        'icon': Icons.cancel,
        'color': const Color(0xFFDC2626), // Primary red
      },
      {
        'label': 'Numéro Incorrecte',
        'value': 'Numéro Incorrecte',
        'icon': Icons.error,
        'color': const Color(0xFFDC2626), // Primary red
      },
      {
        'label': 'Problème Solde',
        'value': 'Problème Solde',
        'icon': Icons.account_balance_wallet,
        'color': const Color(0xFFDC2626), // Primary red
      },
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: states.asMap().entries.map((entry) {
        final index = entry.key;
        final state = entry.value;
        final isSelected = selectedState == state['value'];

        return _buildHoverEffect(
          hoverKey: 'filter_chip_$index',
          hoverScale: 1.05,
          hoverGlowColor: state['color'] as Color,
          child: _buildMorphingFilterChip(
            label: state['label'] as String,
            isSelected: isSelected,
            icon: state['icon'] as IconData,
            selectedColor: state['color'] as Color,
            onPressed: () {
              setState(() {
                selectedState = selectedState == state['value']
                    ? null
                    : state['value'] as String?;
              });
              _applyFiltersAndRefresh();
            },
          ),
        );
      }).toList(),
    );
  }

  // Removed unused _buildOrbitalFAB function

  // Removed unused _buildShimmerLoadingList function

  // 🖥️ Desktop hover effect wrapper
  Widget _buildHoverEffect({
    required Widget child,
    required String hoverKey,
    double hoverScale = 1.02,
    double hoverElevation = 8.0,
    Color? hoverGlowColor,
  }) {
    if (!isDesktop()) return child; // Only apply on desktop

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered[hoverKey] = true);
      },
      onExit: (_) {
        setState(() => _isHovered[hoverKey] = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..scale(_isHovered[hoverKey] == true ? hoverScale : 1.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isHovered[hoverKey] == true
                ? [
                    BoxShadow(
                      color:
                          hoverGlowColor?.withOpacity(0.3) ??
                          const Color(0xFFDC2626).withOpacity(0.2),
                      blurRadius: hoverElevation,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: child,
        ),
      ),
    );
  }

  // 🖥️ Multi-column layout calculator
  int _calculateColumnCount(double screenWidth) {
    if (screenWidth < 800) return 1;
    if (screenWidth < 1200) return 2;
    return 3;
  }

  // 🖥️ Build responsive multi-column layout
  Widget _buildMultiColumnLayout(List<Map<String, dynamic>> orders) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final newColumnCount = _calculateColumnCount(constraints.maxWidth);

        // Trigger layout transition animation if column count changes
        if (newColumnCount != _currentColumnCount) {
          _currentColumnCount = newColumnCount;
          _layoutTransitionController.reset();
          _layoutTransitionController.forward();
        }

        return AnimatedBuilder(
          animation: _layoutTransitionController,
          builder: (context, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: _buildColumnContent(orders, newColumnCount),
            );
          },
        );
      },
    );
  }

  // 🖥️ Build column content based on count
  Widget _buildColumnContent(
    List<Map<String, dynamic>> orders,
    int columnCount,
  ) {
    if (columnCount == 1) {
      // Single column - use existing list
      return ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final order = orders[index];
          final orderId = order['id'];
          final price = (10000 - ((order['prixPercent'] ?? 0) / 100 * 10000))
              .toDouble();

          return RepaintBoundary(
            key: ValueKey('order_$orderId'),
            child: _buildStaggeredListItem(
              index: index,
              child: _buildHoverEffect(
                hoverKey: 'card_$index',
                child: AnimatedBuilder(
                  animation: _newOrderScaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: index == 0 ? _newOrderScaleAnimation.value : 1.0,
                      child: _buildEnhancedMobileCard(
                        order,
                        index,
                        price,
                        key: ValueKey('order_${orderId}_$index'),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    } else {
      // Multi-column grid
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
        ),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final orderId = order['id'];

          return RepaintBoundary(
            key: ValueKey('grid_order_$orderId'),
            child: _buildStaggeredListItem(
              index: index,
              child: _buildHoverEffect(
                hoverKey: 'grid_card_$index',
                hoverScale: 1.03,
                child: AnimatedBuilder(
                  animation: _newOrderScaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: index == 0 ? _newOrderScaleAnimation.value : 1.0,
                      child: _buildCompactCard(order, index),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    }
  }

  // 🖥️ Build compact card for grid layout
  Widget _buildCompactCard(Map<String, dynamic> order, int index) {
    final price = 10000 - ((order['prixPercent'] ?? 0) / 100 * 10000);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFadeText(
              text: order['client'] ?? 'Client Inconnu',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            _buildFadeText(
              text: order['product'] ?? '',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFadeText(
                  text: '${price.toStringAsFixed(0)} DA',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _stateColor(order['state']),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildFadeText(
                    text: order['state'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🎨 Compact Search & Filter Section
  Widget _buildModernSearchFilterSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar Row
          Row(
            children: [
              // Search Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.search,
                  color: Color(0xFFDC2626),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              // Search Input
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par client...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Filter Products Button
              _buildCompactFilterButton(
                icon: Icons.tune,
                label: 'Produits',
                onPressed: _showProductFilterDialog,
                isActive: productCheckboxes.values.any(
                  (isSelected) => !isSelected,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // State Filter Section
          Row(
            children: [
              // Filter Label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 12,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'État',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // State Filter Chips
              Expanded(child: _buildCompactStateFilterChips()),
            ],
          ),
        ],
      ),
    );
  }

  // 🎨 Compact State Filter Chips
  Widget _buildCompactStateFilterChips() {
    final states = [
      {
        'label': 'Tous',
        'value': null,
        'icon': Icons.all_inclusive,
        'color': Colors.grey,
      },
      {
        'label': 'En Attente',
        'value': 'En Attente',
        'icon': Icons.hourglass_empty,
        'color': Colors.orange,
      },
      {
        'label': 'Effectué',
        'value': 'Effectué',
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
      {
        'label': 'Rejeté',
        'value': 'Rejeté',
        'icon': Icons.cancel,
        'color': Colors.red,
      },
      {
        'label': 'Numéro Incorrecte',
        'value': 'Numéro Incorrecte',
        'icon': Icons.error,
        'color': Colors.red,
      },
      {
        'label': 'Problème Solde',
        'value': 'Problème Solde',
        'icon': Icons.account_balance_wallet,
        'color': Colors.red,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: states.map((state) {
          final isSelected = selectedState == state['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _buildCompactChip(
              label: state['label'] as String,
              icon: state['icon'] as IconData,
              color: state['color'] as Color,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  selectedState = isSelected ? null : state['value'] as String?;
                });
                _applyFiltersAndRefresh();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // 🎨 Compact Filter Chip
  Widget _buildCompactChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? Colors.white : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎨 Compact Filter Button
  Widget _buildCompactFilterButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFDC2626) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0xFFDC2626) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎨 Modern Filter Button
  Widget _buildModernFilterButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFDC2626) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFFDC2626) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎨 Compact Action Buttons Section
  Widget _buildModernActionButtons() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          _buildCompactActionButton(
            icon: Icons.date_range,
            label: 'Date',
            color: const Color(0xFFDC2626),
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
          ),
          if (!isDelegatee)
            _buildCompactActionButton(
              icon: Icons.add,
              label: 'Ajouter',
              color: Colors.green.shade600,
              onPressed: _showAddOrderDialog,
            ),
          _buildCompactActionButton(
            icon: Icons.refresh,
            label: 'Reset',
            color: Colors.orange.shade600,
            onPressed: () {
              setState(() {
                searchQuery = '';
                searchController.clear();
                selectedDateRange = null;
                selectedState = null;
                productCheckboxes.updateAll((key, value) => true);
              });
              _applyFiltersAndRefresh();
            },
          ),
          _buildCompactActionButton(
            icon: Icons.download,
            label: 'Excel',
            color: Colors.teal.shade600,
            onPressed: () => exportAllFilteredOrdersToExcel(),
          ),
          if (isAdminn || isSuserr)
            _buildCompactActionButton(
              icon: Icons.person_add,
              label: 'Utilisateur',
              color: Colors.purple.shade600,
              onPressed: () => _showCreateUserDialog(context),
            ),
        ],
      ),
    );
  }

  // 🎨 Compact Action Button
  Widget _buildCompactActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎨 Product Filter Dialog - Same style as Add Order Dialog
  void _showProductFilterDialog() async {
    List<Product> availableProducts = [];

    // Fetch products from database
    try {
      // Use dynamic server selection for product fetching
      final serverConfig = await _networkService.getBestAvailableServer();
      if (serverConfig.isAvailable) {
        final response = await http.get(
          Uri.parse('${serverConfig.apiBaseUrl}/products'),
        );
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          availableProducts = data
              .map((json) => Product.fromJson(json))
              .toList();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No server available. Please check your connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 40,
                vertical: isMobile ? 24 : 40,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: isMobile ? double.infinity : 600,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient - same as Add Order Dialog
                    Container(
                      padding: EdgeInsets.all(isMobile ? 20 : 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFDC2626),
                            const Color(0xFFB91C1C),
                          ],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.filter_list,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Filtrer par Produits',
                                  style: TextStyle(
                                    fontSize: isMobile ? 20 : 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Sélectionnez les produits à afficher',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Content - Product Selection
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Visual Product Selector - Same as Add Order Dialog
                              _buildVisualProductSelectorForFilter(
                                availableProducts: availableProducts,
                                selectedProducts: productCheckboxes,
                                onProductSelected: (Product product) {
                                  final productName = product.productName ?? '';
                                  setDialogState(() {
                                    productCheckboxes[productName] =
                                        !(productCheckboxes[productName] ??
                                            true);
                                  });
                                },
                              ),

                              SizedBox(height: 16),

                              // Selected Products Summary
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Produits Sélectionnés',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '${productCheckboxes.values.where((selected) => selected).length} sur ${productCheckboxes.length} produits sélectionnés',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
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

                    // Action Buttons - Same style as Add Order Dialog
                    Container(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  setDialogState(() {
                                    productCheckboxes.updateAll(
                                      (key, value) => false,
                                    );
                                  });
                                },
                                child: Text('Désélectionner tout'),
                              ),
                              SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  setDialogState(() {
                                    productCheckboxes.updateAll(
                                      (key, value) => true,
                                    );
                                  });
                                },
                                child: Text('Sélectionner tout'),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Annuler'),
                              ),
                              SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {});
                                  _applyFiltersAndRefresh();
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text('Appliquer'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ✨ Build morphing search bar with animations
  Widget _buildMorphingSearchBar() {
    return AnimatedBuilder(
      animation: _searchBarController,
      builder: (context, child) {
        return Transform.scale(
          scale: _searchBarScale.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_isSearchFocused ? 16 : 8),
              boxShadow: _isSearchFocused
                  ? [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: TextField(
              controller: searchController,
              onTap: () {
                setState(() => _isSearchFocused = true);
                _searchBarController.forward();
              },
              onSubmitted: (value) {
                setState(() => _isSearchFocused = false);
                _searchBarController.reverse();
              },
              onEditingComplete: () {
                setState(() => _isSearchFocused = false);
                _searchBarController.reverse();
              },
              decoration: InputDecoration(
                labelText: _isSearchFocused
                    ? 'Tapez pour rechercher...'
                    : 'Rechercher par client',
                labelStyle: TextStyle(
                  color: _isSearchFocused
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF6B7280),
                ),
                prefixIcon: AnimatedRotation(
                  turns: _isSearchFocused ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _isSearchFocused ? Icons.manage_search : Icons.search,
                    size: _isSearchFocused ? 24 : 18,
                    color: _isSearchFocused
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF6B7280),
                  ),
                ),
                suffixIcon: _isSearchFocused
                    ? AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: const Color(0xFF6B7280),
                          ),
                          onPressed: () {
                            searchController.clear();
                            setState(() => _isSearchFocused = false);
                            _searchBarController.reverse();
                            _onSearchChanged('');
                          },
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    _isSearchFocused ? 16 : 8,
                  ),
                  borderSide: BorderSide(
                    color: _isSearchFocused
                        ? const Color(0xFFDC2626).withOpacity(0.5)
                        : const Color(0xFFE5E7EB),
                    width: _isSearchFocused ? 2 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: const Color(0xFFDC2626),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: _isSearchFocused
                    ? const Color(0xFFFEF2F2) // Light red tint
                    : const Color(0xFFF9FAFB), // Light grey
                contentPadding: EdgeInsets.symmetric(
                  horizontal: _isSearchFocused ? 16 : 12,
                  vertical: _isSearchFocused ? 12 : 8,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    // ✨ Dispose Animation Controllers
    _staggeredListController.dispose();
    _fabController.dispose();
    _searchBarController.dispose();
    _rippleController.dispose();
    _layoutTransitionController.dispose();
    _fadeController.dispose();
    _pageTransitionController.dispose();
    _textFadeController.dispose();
    _newOrderController.dispose();

    // Dispose all card controllers
    for (var controller in _cardControllers) {
      controller.dispose();
    }

    // Dispose all ripple controllers
    for (var controller in _rippleControllers.values) {
      controller.dispose();
    }

    _refreshTimer?.cancel();
    _searchTimer?.cancel();
    _cacheRefreshTimer?.cancel(); // Cancel cache refresh timer
    _connectionCheckTimer?.cancel(); // Cancel connection check timer
    _disconnectWebSocket(); // Disconnect WebSocket
    _clearUserCache(); // Clear user cache
    super.dispose();
  }

  // Clear user cache when user changes
  void _clearUserCache() {
    _cachedIsDelegue = null;
    _cachedUserRegion = null;
    _cachedIsSuper = null;
    _userInfoCacheTime = null;
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

  // Start monitoring connection status
  void _startConnectionMonitoring() {
    _connectionCheckTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _checkConnectionStatus();
    });
    // Check immediately
    _checkConnectionStatus();
  }

  // Check connection status by making a simple API call
  Future<void> _checkConnectionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      if (token.isEmpty) {
        print('DEBUG: Connection Check - No Auth Token');
        _updateConnectionStatus(false, 'No Auth Token');
        return;
      }

      // Use NetworkService to get the best available server
      final networkService = NetworkService();
      final serverConfig = await networkService.getBestAvailableServer();

      if (!serverConfig.isAvailable) {
        print('DEBUG: Connection Check - No server available');
        _updateConnectionStatus(false, 'No server available');
        return;
      }

      final testUrl = '${serverConfig.apiBaseUrl}/commands?take=1';
      print('DEBUG: Connection Check - Testing URL: $testUrl');
      print(
        'DEBUG: Connection Check - Using server: ${serverConfig.displayName}',
      );

      final response = await http
          .get(
            Uri.parse(testUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      print(
        'DEBUG: Connection Check - Response Status: ${response.statusCode}',
      );
      print('DEBUG: Connection Check - Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print(
          'DEBUG: Connection Check - SUCCESS: Connected to ${serverConfig.displayName}',
        );
        _updateConnectionStatus(
          true,
          'Connected to ${serverConfig.type == ServerType.local ? "Local" : "Online"} Server',
        );
      } else if (response.statusCode == 401) {
        print('DEBUG: Connection Check - FAILED: Auth Failed');
        _updateConnectionStatus(false, 'Auth Failed');
      } else {
        print(
          'DEBUG: Connection Check - FAILED: Server Error ${response.statusCode}',
        );
        print('DEBUG: Connection Check - Error Response: ${response.body}');
        _updateConnectionStatus(false, 'Server Error ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Connection Check - EXCEPTION: $e');
      _updateConnectionStatus(false, 'Connection Failed');
    }
  }

  // Update connection status
  void _updateConnectionStatus(bool isConnected, String status) {
    if (mounted) {
      setState(() {
        _isConnected = isConnected;
        _connectionStatus = status;
      });
    }
  }

  // Fast local browsing through cached data
  void _performLocalBrowsing({
    required int page,
    required int pageSize,
    String? stateFilter,
    List<String>? productFilters,
    DateTimeRange? dateRange,
  }) {
    // Performing local browsing

    // Filter the cached data
    var filteredOrders = _allOrdersCache.where((order) {
      // State filter
      if (stateFilter != null &&
          stateFilter.isNotEmpty &&
          order['state'] != stateFilter) {
        return false;
      }

      // Product filter
      if (productFilters != null && productFilters.isNotEmpty) {
        if (!productFilters.contains(order['product'])) {
          return false;
        }
      }

      // Date range filter
      if (dateRange != null) {
        try {
          final orderDate = DateTime.parse(order['date']);
          if (orderDate.isBefore(dateRange.start) ||
              orderDate.isAfter(dateRange.end)) {
            return false;
          }
        } catch (e) {
          // Skip if date parsing fails
        }
      }

      return true;
    }).toList();

    // Apply pagination
    final totalCount = filteredOrders.length;
    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, filteredOrders.length);

    final paginatedResults = filteredOrders.sublist(
      startIndex.clamp(0, filteredOrders.length),
      endIndex,
    );

    print(
      'DEBUG: Local browsing showing ${paginatedResults.length} results (${startIndex + 1}-$endIndex of $totalCount)',
    );

    if (mounted) {
      setState(() {
        _currentPageOrders = paginatedResults;
        _totalOrdersCount = totalCount;
        _hasActiveFilters =
            stateFilter != null ||
            (productFilters != null && productFilters.isNotEmpty) ||
            dateRange != null;
      });
    }
  }

  // Clear cache when filters change
  void _clearCache() {
    _pageCache.clear();
    // Don't clear local cache as it contains all data
  }

  // Helper method to extract client name efficiently
  String _extractClientName(Map<String, dynamic> item) {
    // Check clients object first (most common)
    if (item['clients'] != null && item['clients'] is Map) {
      return item['clients']['clientName'] ?? 'Unknown';
    }

    // Check client field
    if (item['client'] != null) {
      if (item['client'] is Map) {
        return item['client']['clientName'] ?? 'Unknown';
      } else if (item['client'] is String) {
        return item['client'];
      }
    }

    return 'Unknown';
  }

  // Get cached user info or fetch if not cached/expired
  Future<Map<String, dynamic>> _getCachedUserInfo() async {
    final now = DateTime.now();

    // Cache user info for 5 minutes
    if (_userInfoCacheTime != null &&
        now.difference(_userInfoCacheTime!).inMinutes < 5 &&
        _cachedIsDelegue != null) {
      return {
        'isDelegue': _cachedIsDelegue!,
        'region': _cachedUserRegion,
        'isSuper': _cachedIsSuper ?? false,
      };
    }

    // Fetch fresh user info
    final userIsDelegue = await isDelegue() ?? false;
    final userIsSuper = await isSuper() ?? false;
    String? region;

    if (userIsDelegue) {
      region = await getUserRegion();
    }

    // Cache the results
    _cachedIsDelegue = userIsDelegue;
    _cachedUserRegion = region;
    _cachedIsSuper = userIsSuper;
    _userInfoCacheTime = now;

    return {
      'isDelegue': userIsDelegue,
      'region': region,
      'isSuper': userIsSuper,
    };
  }

  // Apply filters and refresh data
  Future<void> _applyFiltersAndRefresh() async {
    // Clear cache since filters are changing
    _clearCache();
    // Get selected products
    final selectedProducts = productCheckboxes.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    // Debug: Print selected products
    print('DEBUG: Selected products: $selectedProducts');

    // If all products are selected or none are selected, don't apply product filter
    final List<String>? productFilters =
        (selectedProducts.isEmpty ||
            selectedProducts.length == productCheckboxes.length)
        ? null
        : selectedProducts;

    // Track if we have active filters
    _hasActiveFilters =
        (searchQuery.isNotEmpty) ||
        (selectedState != null) ||
        (productFilters != null) ||
        (selectedDateRange != null);

    // Debug: Print filter status
    print('DEBUG: ===== APPLYING FILTERS =====');
    print('DEBUG: Search query: "$searchQuery"');
    print('DEBUG: Search query isEmpty: ${searchQuery.isEmpty}');
    print('DEBUG: Search query isNotEmpty: ${searchQuery.isNotEmpty}');
    print('DEBUG: Product filters: $productFilters');
    print('DEBUG: Has active filters: $_hasActiveFilters');
    print(
      'DEBUG: Will pass searchQuery to API: ${searchQuery.isNotEmpty ? searchQuery : null}',
    );

    // Use cache-based search for better performance
    final searchPageSize = _rowsPerPage; // Normal pagination
    print(
      'DEBUG: Using page size: $searchPageSize (search mode: ${searchQuery.isNotEmpty})',
    );

    // Use cache-based search for client search, regular API for other filters
    if (searchQuery.isNotEmpty) {
      await _performCacheBasedSearch(
        searchQuery: searchQuery,
        page: 0,
        pageSize: searchPageSize,
        stateFilter: selectedState,
        productFilters: productFilters,
        dateRange: selectedDateRange,
      );
    } else {
      await fetchPurchaseOrders(
        page: 0, // Reset to first page when applying filters
        pageSize: searchPageSize,
        keepPage: false,
        searchQuery: null,
        stateFilter: selectedState,
        productFilters: productFilters,
        dateRange: selectedDateRange,
      );
    }

    // Reset current page to 0 when filters are applied
    if (mounted) {
      setState(() {
        _currentPage = 0;
      });
    }
  }

  // Perform cache-based search for better performance
  Future<void> _performCacheBasedSearch({
    required String searchQuery,
    required int page,
    required int pageSize,
    String? stateFilter,
    List<String>? productFilters,
    DateTimeRange? dateRange,
  }) async {
    print('DEBUG: ===== CACHE-BASED SEARCH =====');
    print('DEBUG: Search query: "$searchQuery"');
    print('DEBUG: Page: $page, PageSize: $pageSize');

    // Ensure search cache is loaded
    await _loadSearchCache();

    if (!_isSearchCacheValid() || _searchCache.isEmpty) {
      print('DEBUG: Search cache not available, falling back to API search');
      await fetchPurchaseOrders(
        page: page,
        pageSize: 2377, // Fallback to full search
        keepPage: false,
        searchQuery: searchQuery,
        stateFilter: stateFilter,
        productFilters: productFilters,
        dateRange: dateRange,
      );
      return;
    }

    // Perform client-side filtering on cached data
    List<Map<String, dynamic>> filteredResults = List.from(_searchCache);

    // Apply client name filter
    final searchLower = searchQuery.toLowerCase();
    filteredResults = filteredResults.where((order) {
      final clientName = (order['client'] ?? '').toString().toLowerCase();
      final clientId = (order['ClientsID']?.toString() ?? '').toLowerCase();
      final newClientId = (order['newClientID']?.toString() ?? '')
          .toLowerCase();

      return clientName.contains(searchLower) ||
          clientId.contains(searchLower) ||
          newClientId.contains(searchLower);
    }).toList();

    // Apply state filter
    if (stateFilter != null) {
      filteredResults = filteredResults.where((order) {
        return order['state'] == stateFilter;
      }).toList();
    }

    // Apply product filter
    if (productFilters != null && productFilters.isNotEmpty) {
      filteredResults = filteredResults.where((order) {
        return productFilters.contains(order['product']);
      }).toList();
    }

    // Apply date range filter (if needed)
    if (dateRange != null) {
      filteredResults = filteredResults.where((order) {
        try {
          final orderDate = DateTime.parse(order['date']);
          return orderDate.isAfter(
                dateRange.start.subtract(const Duration(days: 1)),
              ) &&
              orderDate.isBefore(dateRange.end.add(const Duration(days: 1)));
        } catch (e) {
          return true; // Include orders with invalid dates
        }
      }).toList();
    }

    final totalFilteredCount = filteredResults.length;

    // Apply pagination
    final startIndex = page * pageSize;
    final endIndex = math.min(startIndex + pageSize, filteredResults.length);
    final paginatedResults = filteredResults.sublist(startIndex, endIndex);

    print(
      'DEBUG: Cache search results: ${paginatedResults.length} orders (${startIndex + 1}-${startIndex + paginatedResults.length} of $totalFilteredCount)',
    );

    // Update UI
    if (mounted) {
      setState(() {
        _currentPageOrders = paginatedResults;
        _totalOrdersCount = totalFilteredCount;
        _isLoading = false;
      });
    }
  }

  // Fetch with current filters (for pagination)
  Future<void> _fetchWithCurrentFilters({required int page}) async {
    final selectedProducts = productCheckboxes.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    // If all products are selected or none are selected, don't apply product filter
    final List<String>? productFilters =
        (selectedProducts.isEmpty ||
            selectedProducts.length == productCheckboxes.length)
        ? null
        : selectedProducts;

    // Update active filters status
    _hasActiveFilters =
        (searchQuery.isNotEmpty) ||
        (selectedState != null) ||
        (productFilters != null) ||
        (selectedDateRange != null);

    // Use cache-based search for client search, regular API for other operations
    if (searchQuery.isNotEmpty) {
      await _performCacheBasedSearch(
        searchQuery: searchQuery,
        page: page,
        pageSize: _rowsPerPage,
        stateFilter: selectedState,
        productFilters: productFilters,
        dateRange: selectedDateRange,
      );
    } else {
      await fetchPurchaseOrders(
        page: page,
        pageSize: _rowsPerPage,
        keepPage: true,
        searchQuery: null,
        stateFilter: selectedState,
        productFilters: productFilters,
        dateRange: selectedDateRange,
      );
    }
  }

  List<Map<String, dynamic>> get filteredOrders {
    // Since filtering is now done on the backend, just return current page orders
    return _currentPageOrders;
  }

  // Fetch ALL filtered orders for export (not just current page)
  Future<List<Map<String, dynamic>>> _fetchAllFilteredOrdersForExport() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final Map<String, String> queryParams = {};

    // Get current filter values
    final selectedProducts = productCheckboxes.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    final List<String>? productFilters =
        (selectedProducts.isEmpty ||
            selectedProducts.length == productCheckboxes.length)
        ? null
        : selectedProducts;

    // IMPORTANT: For export, fetch ALL data (no pagination)
    queryParams['skip'] = '0';
    queryParams['take'] = '10000'; // Large number to get all filtered results

    // Apply current filters
    if (selectedDateRange != null) {
      queryParams['startDate'] = selectedDateRange!.start
          .toIso8601String()
          .split('T')[0];
      queryParams['endDate'] = selectedDateRange!.end.toIso8601String().split(
        'T',
      )[0];
    }

    if (selectedState != null && selectedState!.isNotEmpty) {
      queryParams['isValidated'] = selectedState!;
    }

    // Note: Client search will be applied client-side after fetching data
    // Don't add search parameters to server query since backend doesn't support it

    if (productFilters != null && productFilters.length == 1) {
      queryParams['operator'] = productFilters.first;
    }

    // Get cached user info to determine endpoint
    final userInfo = await _getCachedUserInfo();
    final userIsDelegue = userInfo['isDelegue'] as bool;
    final userRegion = userInfo['region'] as String?;

    // Use NetworkService to get the current server's API base URL
    final apiBaseUrl = await _getApiBaseUrl();

    final String baseUrl;
    if (userIsDelegue && userRegion != null) {
      baseUrl = '$apiBaseUrl/commands/zone/$userRegion';
    } else {
      baseUrl = '$apiBaseUrl/commands';
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 30),
          ); // Longer timeout for large exports

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final ordersList = (data['data'] ?? []) as List<dynamic>;

        final allOrders = ordersList.map<Map<String, dynamic>>((item) {
          final clientName = _extractClientName(item);
          return {
            'id': item['id'],
            'client': clientName,
            'product': item['operator'] ?? 'Unknown',
            'quantity': item['amount'] ?? 0,
            'prixPercent':
                double.tryParse(
                  (item['pourcentage'] ?? '0').toString().replaceAll('%', ''),
                ) ??
                0,
            'state': item['isValidated'] ?? 'En Attente',
            'name': item['users']?['username'] ?? 'Unknown',
            'number': item['number'] ?? 'Unknown',
            'accepted': item['accepted'] ?? 'Unknown',
            'acceptedBy': item['acceptedBy'] ?? ' ',
            'date': item['createdAt'] ?? '',
          };
        }).toList();

        // Apply client-side filtering for export
        List<Map<String, dynamic>> filteredOrders = allOrders;

        // Apply client-side search for client name
        if (searchQuery.isNotEmpty) {
          filteredOrders = filteredOrders.where((order) {
            return order['client'].toLowerCase().contains(
              searchQuery.toLowerCase(),
            );
          }).toList();
        }

        // Apply client-side product filtering when multiple products are selected
        if (productFilters != null && productFilters.length > 1) {
          filteredOrders = filteredOrders.where((order) {
            return productFilters.contains(order['product']);
          }).toList();
        }

        return filteredOrders;
      } else {
        throw Exception('Failed to fetch export data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Export error: $e');
    }
  }

  // Export ALL filtered orders to Excel (with progress indicator)
  Future<void> exportAllFilteredOrdersToExcel() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Fetching all filtered orders for export...'),
          ],
        ),
      ),
    );

    try {
      // Fetch ALL filtered orders
      final allFilteredOrders = await _fetchAllFilteredOrdersForExport();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show confirmation with count
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export to Excel'),
          content: Text(
            'Export ${allFilteredOrders.length} filtered orders to Excel?\n\n'
            'Current filters applied:\n'
            '${_getActiveFiltersDescription()}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Export'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        exportToExcel(allFilteredOrders);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: const Color(0xFFDC2626), // Primary red for errors
        ),
      );
    }
  }

  // Get description of active filters for user confirmation
  String _getActiveFiltersDescription() {
    final List<String> activeFilters = [];

    if (searchQuery.isNotEmpty) {
      activeFilters.add('Search: "$searchQuery"');
    }

    if (selectedState != null) {
      activeFilters.add('Status: $selectedState');
    }

    if (selectedDateRange != null) {
      final start = DateFormat('dd/MM/yyyy').format(selectedDateRange!.start);
      final end = DateFormat('dd/MM/yyyy').format(selectedDateRange!.end);
      activeFilters.add('Date: $start - $end');
    }

    final selectedProducts = productCheckboxes.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedProducts.isNotEmpty &&
        selectedProducts.length != productCheckboxes.length) {
      activeFilters.add('Products: ${selectedProducts.join(', ')}');
    }

    return activeFilters.isEmpty
        ? 'No filters applied (all orders)'
        : activeFilters.join('\n');
  }

  void exportToExcel(List<Map<String, dynamic>> data) async {
    var excelFile = excel.Excel.createExcel();
    final excel.Sheet sheet = excelFile['Sheet1'];

    // Enhanced headers with more information
    List<excel.CellValue?> headers = [
      excel.TextCellValue('ID'),
      excel.TextCellValue('Client'),
      excel.TextCellValue('Product'),
      excel.TextCellValue('Quantity'),
      excel.TextCellValue('Price %'),
      excel.TextCellValue('Calculated Price (DA)'),
      excel.TextCellValue('State'),
      excel.TextCellValue('Created By'),
      excel.TextCellValue('Number'),
      excel.TextCellValue('Accepted'),
      excel.TextCellValue('Accepted By'),
      excel.TextCellValue('Date'),
    ];
    sheet.appendRow(headers);

    for (var item in data) {
      final calculatedPrice =
          10000 - ((item['prixPercent'] ?? 0) / 100 * 10000);

      List<excel.CellValue?> row = [
        excel.TextCellValue(item['id'].toString()),
        excel.TextCellValue(item['client']),
        excel.TextCellValue(item['product']),
        excel.TextCellValue(item['quantity'].toString()),
        excel.TextCellValue('${item['prixPercent']}%'),
        excel.TextCellValue(calculatedPrice.toStringAsFixed(2)),
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
      ).showSnackBar(const SnackBar(content: Text('❌ Failed to save Excel')));
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final path = p.join(dir.path, 'orders_export_$timestamp.xlsx');

    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes);

    // Show success message with count
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${data.length} orders exported to: $path'),
        backgroundColor: const Color(0xFF1F2937), // Dark grey for success
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => OpenFile.open(path),
        ),
      ),
    );
  }

  void _deleteOrder(int index) async {
    final orderId = _currentPageOrders[index]['id'];

    // Safety check for null orderId
    if (orderId == null) {
      print('ERROR: Order ID is null! Cannot delete order.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Cannot delete order - invalid order ID'),
            backgroundColor: const Color(0xFFDC2626), // Primary red for errors
          ),
        );
      }
      return;
    }

    print('DEBUG: Deleting order with ID: $orderId');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    try {
      // Use dynamic server selection for order deletion
      final serverConfig = await _networkService.getBestAvailableServer();
      if (!serverConfig.isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No server available. Please check your connection.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final response = await http.delete(
        Uri.parse('${serverConfig.apiBaseUrl}/commands/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('DEBUG: Delete response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        // ✅ Refresh from database to get current state with filters preserved
        await fetchPurchaseOrders(
          page: _currentPage,
          pageSize: _rowsPerPage,
          keepPage: true,
          stateFilter: selectedState,
          productFilters: productCheckboxes.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList(),
          dateRange: selectedDateRange,
        );

        // 📡 Broadcast deletion to other users via WebSocket
        _sendWebSocketMessage('ORDER_DELETED', {'id': orderId});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order deleted successfully'),
              backgroundColor: const Color(0xFF1F2937), // Dark grey for success
            ),
          );
        }
      } else {
        print('ERROR: Delete failed with status: ${response.statusCode}');
        throw Exception('Failed to delete order: ${response.statusCode}');
      }
    } catch (e) {
      print('ERROR: Delete operation failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
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
    final orderId = _currentPageOrders[index]['id'];

    // Safety check for null orderId
    if (orderId == null) {
      print('ERROR: Order ID is null! Cannot change state.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Cannot update order - invalid order ID'),
            backgroundColor: const Color(0xFFDC2626), // Primary red for errors
          ),
        );
      }
      return;
    }

    print('DEBUG: Changing order $orderId state to: $newState');

    // Show immediate visual feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updating order to: $newState'),
        backgroundColor: _getSnackBarColor(newState),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      print('=== STATE CHANGE DEBUG ===');
      print('Order ID: $orderId');
      print('New State: $newState');
      print(
        'API Endpoint: http://estcommand.ddns.net:8080/api/v1/commands/$orderId',
      );
      print('=========================');

      // Use dynamic server selection for order update
      final serverConfig = await _networkService.getBestAvailableServer();
      if (!serverConfig.isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No server available. Please check your connection.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final response = await http.put(
        Uri.parse('${serverConfig.apiBaseUrl}/commands/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isValidated': newState}),
      );

      print('=== STATE CHANGE RESPONSE ===');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('============================');

      if (response.statusCode == 200) {
        // ✅ Success: Refresh from database to get current state with filters preserved
        await fetchPurchaseOrders(
          page: _currentPage,
          pageSize: _rowsPerPage,
          keepPage: true,
          stateFilter: selectedState,
          productFilters: productCheckboxes.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList(),
          dateRange: selectedDateRange,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order updated to: $newState'),
              backgroundColor: const Color(0xFF1F2937), // Dark grey for success
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Broadcast state change to other users via WebSocket
        _sendWebSocketMessage('ORDER_UPDATED', {
          'id': orderId,
          'isValidated': newState,
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update state: ${response.statusCode}'),
              backgroundColor: const Color(
                0xFFDC2626,
              ), // Primary red for errors
            ),
          );
        }
      }
    } catch (e) {
      print('ERROR: State change failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: const Color(0xFFDC2626), // Primary red for errors
          ),
        );
      }
    }
  }

  // New function for superuser to change accepted status
  void _changeOrderAccepted(int index, bool accepted) async {
    final orderId = _currentPageOrders[index]['id'];

    // Safety check for null orderId
    if (orderId == null) {
      print('ERROR: Order ID is null! Cannot change accepted status.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Cannot update order - invalid order ID'),
            backgroundColor: const Color(0xFFDC2626), // Primary red for errors
          ),
        );
      }
      return;
    }

    print('=== CHANGING ORDER ACCEPTED STATUS ===');
    print('Order ID: $orderId');
    print('New Accepted Status: $accepted');
    print('Order Index: $index');

    // Show immediate visual feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${accepted ? 'Validating' : 'Not validating'} order...'),
        backgroundColor: accepted
            ? const Color(0xFF1F2937)
            : const Color(0xFFDC2626),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      if (token.isEmpty) {
        print('ERROR: No auth token available');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Not authenticated'),
              backgroundColor: const Color(
                0xFFDC2626,
              ), // Primary red for errors
            ),
          );
        }
        return;
      }

      print('=== ACCEPTED STATUS CHANGE DEBUG ===');
      print('Order ID: $orderId');
      print('New Accepted Status: $accepted');
      print(
        'API Endpoint: http://estcommand.ddns.net:8080/api/v1/commands/$orderId',
      );
      print('====================================');

      // Use dynamic server selection for order update
      final serverConfig = await _networkService.getBestAvailableServer();
      if (!serverConfig.isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No server available. Please check your connection.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final response = await http.put(
        Uri.parse('${serverConfig.apiBaseUrl}/commands/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'accepted': accepted}),
      );

      print('=== ACCEPTED STATUS CHANGE RESPONSE ===');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('=======================================');

      if (response.statusCode == 200) {
        // ✅ Success: Refresh from database to get current state with filters preserved
        await fetchPurchaseOrders(
          page: _currentPage,
          pageSize: _rowsPerPage,
          keepPage: true,
          stateFilter: selectedState,
          productFilters: productCheckboxes.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList(),
          dateRange: selectedDateRange,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order ${accepted ? 'validated' : 'not validated'} successfully',
              ),
              backgroundColor: const Color(0xFF1F2937), // Dark grey for success
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Broadcast accepted status change to other users via WebSocket
        _sendWebSocketMessage('ORDER_UPDATED', {
          'id': orderId,
          'accepted': accepted,
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update order: ${response.statusCode}'),
              backgroundColor: const Color(
                0xFFDC2626,
              ), // Primary red for errors
            ),
          );
        }
      }
    } catch (e) {
      print('ERROR: Failed to update order accepted status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: const Color(0xFFDC2626), // Primary red for errors
          ),
        );
      }
    }
  }

  // Helper method to get appropriate snackbar color based on state
  Color _getSnackBarColor(String state) {
    switch (state.toLowerCase()) {
      case 'effectué':
        return const Color(0xFF1F2937); // Dark grey for success
      case 'rejeté':
        return const Color(0xFFDC2626); // Primary red for rejection
      case 'en attente':
        return const Color(0xFF6B7280); // Medium grey for pending
      case 'numéro incorrecte':
        return const Color(0xFFDC2626); // Primary red for errors
      case 'problème solde':
        return const Color(0xFFDC2626); // Primary red for problems
      default:
        return const Color(0xFF374151); // Dark grey default
    }
  }

  Future<void> handleAccept(bool accepted, int id) async {
    // 🎭 VISUAL TRICK: Update UI immediately for smooth UX
    final originalState = _currentPageOrders[id]['state'];
    final newState = accepted ? 'Effectué' : 'Rejeté';

    // Optimistic update: Change UI immediately
    setState(() {
      _currentPageOrders[id]['state'] = newState;
    });

    // Show immediate feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(accepted ? 'Order accepted!' : 'Order rejected!'),
        backgroundColor: accepted
            ? const Color(0xFF1F2937)
            : const Color(0xFFDC2626),
        duration: const Duration(seconds: 1),
      ),
    );

    // Now make API call in background
    try {
      final orderId = _currentPageOrders[id]['id'].toString();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      // Use dynamic server selection for order accept
      final serverConfig = await _networkService.getBestAvailableServer();
      if (!serverConfig.isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No server available. Please check your connection.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final url = Uri.parse(
        '${serverConfig.apiBaseUrl}/commands/accept/$orderId',
      );

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'accepted': accepted}),
      );

      if (response.statusCode != 200) {
        // API failed: Revert the optimistic update
        setState(() {
          _currentPageOrders[id]['state'] = originalState;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order: ${response.statusCode}'),
            backgroundColor: const Color(0xFFDC2626), // Primary red for errors
          ),
        );
      }
      // If successful, keep the optimistic update (no need to refresh)
    } catch (e) {
      // Network error: Revert the optimistic update
      setState(() {
        _currentPageOrders[id]['state'] = originalState;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: const Color(0xFFDC2626), // Primary red for errors
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
              // Pass the order ID directly to avoid null issues
              _updateOrderById(order['id'], {
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

  void _showAddOrderDialog() async {
    final clientController = TextEditingController();
    final numberController = TextEditingController();
    Map<String, String> clientsMap = {};
    String? selectedClientName;

    List<Map<String, dynamic>> selectedProducts = [];
    List<Product> availableProducts = [];

    // Fetch products from database BEFORE showing dialog
    try {
      // Use dynamic server selection instead of hardcoded URL
      final serverConfig = await _networkService.getBestAvailableServer();
      if (serverConfig.isAvailable) {
        final response = await http.get(
          Uri.parse('${serverConfig.apiBaseUrl}/products'),
        );
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          availableProducts = data
              .map((json) => Product.fromJson(json))
              .toList();
        }
      } else {
        // Show error if no server is available
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No server available. Please check your connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Handle error if needed
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
    }

    showDialog(
      context: context,
      builder: (_) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;

        // Responsive dialog width for better desktop experience
        double dialogWidth;
        if (isMobile) {
          dialogWidth = double.infinity;
        } else if (screenWidth < 1024) {
          dialogWidth = 700; // Small desktop
        } else if (screenWidth < 1440) {
          dialogWidth = 850; // Medium desktop
        } else {
          dialogWidth = 950; // Large desktop
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 20, // Reduced from 40 to 20
                vertical: isMobile ? 24 : 40,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Enhanced Header with gradient
                    Container(
                      padding: EdgeInsets.all(isMobile ? 20 : 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFDC2626),
                            const Color(0xFFB91C1C),
                          ],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.add_shopping_cart,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nouvelle Commande',
                                  style: TextStyle(
                                    fontSize: isMobile ? 20 : 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Créer une nouvelle commande client',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Client Search Field (Top)
                                if (!isclient) ...[
                                  selectedClientName != null
                                      ? // Show selected client as a read-only field
                                        Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFF3F4F6,
                                            ), // Light grey
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.green.shade300,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.person,
                                                color: const Color(
                                                  0xFF1F2937,
                                                ), // Dark grey for success
                                                size: 20,
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Selected Client',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .green
                                                            .shade700,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    Text(
                                                      selectedClientName!,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors
                                                            .green
                                                            .shade800,
                                                      ),
                                                    ),
                                                    Text(
                                                      'ID: ${clientsMap[selectedClientName] ?? 'N/A'}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .green
                                                            .shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.edit,
                                                  color: const Color(
                                                    0xFF1F2937,
                                                  ), // Dark grey for success
                                                  size: 18,
                                                ),
                                                onPressed: () {
                                                  setDialogState(() {
                                                    selectedClientName = null;
                                                  });
                                                  clientController.clear();
                                                },
                                              ),
                                            ],
                                          ),
                                        )
                                      : // Show search field when no client is selected
                                        ClientSearchWidget(
                                          onClientSelected:
                                              (
                                                String clientName,
                                                String clientId,
                                              ) {
                                                // Update variables and state immediately
                                                selectedClientName = clientName;
                                                clientsMap[clientName] =
                                                    clientId;

                                                // Immediate state update
                                                setDialogState(() {
                                                  // Client selected - update UI immediately
                                                });
                                              },
                                        ),
                                  SizedBox(height: 16),
                                ],

                                // Products Section (Middle)
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Modern Visual Product Selector
                                      _buildVisualProductSelector(
                                        availableProducts: availableProducts,
                                        onProductSelected: (Product product) {
                                          selectedProducts.add({
                                            'product':
                                                product.productName ?? '',
                                            'productId':
                                                product.productID ?? '',
                                            'quantity': 1,
                                            'unitPrice':
                                                product.initialPrice ?? 0.0,
                                          });
                                          setDialogState(() {});
                                        },
                                      ),

                                      // Selected Products List
                                      if (selectedProducts.isNotEmpty) ...[
                                        SizedBox(height: 16),
                                        Text(
                                          'Selected Products',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        ...selectedProducts.asMap().entries.map((
                                          entry,
                                        ) {
                                          final index = entry.key;
                                          final item = entry.value;
                                          return Container(
                                            margin: EdgeInsets.only(bottom: 12),
                                            padding: EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.grey.shade200,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.05),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              children: [
                                                // Row 1: Product Icon + Name + Delete Button
                                                Row(
                                                  children: [
                                                    // Product Icon
                                                    _getProductIconWidget(
                                                      item['product'],
                                                    ),
                                                    SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        item['product'],
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 15,
                                                          color: Colors
                                                              .grey
                                                              .shade800,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 12),
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.close,
                                                        color: const Color(
                                                          0xFFDC2626,
                                                        ),
                                                        size: 20,
                                                      ),
                                                      style: IconButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red.shade50,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        padding: EdgeInsets.all(
                                                          8,
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        setDialogState(() {
                                                          selectedProducts
                                                              .removeAt(index);
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 12),
                                                // Row 2: Price and Quantity Fields (Wider)
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      flex: isMobile ? 1 : 2,
                                                      child: TextFormField(
                                                        initialValue:
                                                            item['unitPrice']
                                                                .toStringAsFixed(
                                                                  2,
                                                                ),
                                                        keyboardType:
                                                            TextInputType.numberWithOptions(
                                                              decimal: true,
                                                            ),
                                                        enabled: !isclient,
                                                        onChanged: (value) {
                                                          item['unitPrice'] =
                                                              double.tryParse(
                                                                value,
                                                              ) ??
                                                              item['unitPrice'];
                                                        },
                                                        decoration: InputDecoration(
                                                          labelText:
                                                              'Prix Unitaire (DA)',
                                                          prefixIcon: Icon(
                                                            Icons.attach_money,
                                                            size: 20,
                                                          ),
                                                          border: OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          contentPadding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 12,
                                                                vertical: 12,
                                                              ),
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 16),
                                                    Expanded(
                                                      flex: 1,
                                                      child: TextFormField(
                                                        initialValue:
                                                            item['quantity']
                                                                .toString(),
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                        onChanged: (value) {
                                                          item['quantity'] =
                                                              int.tryParse(
                                                                value,
                                                              ) ??
                                                              1;
                                                        },
                                                        decoration: InputDecoration(
                                                          labelText: 'Quantité',
                                                          prefixIcon: Icon(
                                                            Icons
                                                                .inventory_2_outlined,
                                                            size: 20,
                                                          ),
                                                          border: OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          contentPadding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 12,
                                                                vertical: 12,
                                                              ),
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                // Show total price for this item
                                                SizedBox(height: 8),
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Text(
                                                    'Total: ${(item['unitPrice'] * item['quantity']).toStringAsFixed(2)} DA',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: const Color(
                                                        0xFFDC2626,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ],
                                  ),
                                ),

                                SizedBox(height: 16),

                                // Number Field (Bottom)
                                TextFormField(
                                  controller: numberController,
                                  keyboardType: TextInputType.text,
                                  decoration: InputDecoration(
                                    labelText: 'Number',
                                    prefixIcon: Icon(
                                      Icons.numbers,
                                      color: Colors.grey.shade600,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Enhanced Actions Footer
                    Container(
                      padding: EdgeInsets.all(isMobile ? 20 : 24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey.shade400),
                              ),
                              child: Text(
                                'Annuler',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: selectedProducts.isNotEmpty
                                  ? () async {
                                      try {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        final token =
                                            prefs.getString('auth_token') ?? '';
                                        final payload = decodeJwtPayload(token);

                                        if (_formKey.currentState!.validate()) {
                                          if (selectedProducts.isEmpty) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  "Please add at least one product",
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          if (!isclient &&
                                              selectedClientName == null) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  "Please select a client",
                                                ),
                                                backgroundColor: const Color(
                                                  0xFFDC2626,
                                                ), // Primary red for errors
                                              ),
                                            );
                                            return;
                                          }

                                          final clientId =
                                              clientsMap[selectedClientName];

                                          for (var item in selectedProducts) {
                                            final product = item['product'];
                                            final quantity = item['quantity'];
                                            final unitPrice = item['unitPrice'];

                                            if (quantity <= 0) continue;

                                            final orderPayload = {
                                              'operator': product,
                                              'amount': quantity,
                                              'ClientsID': isclient
                                                  ? payload['clid']
                                                  : clientId,
                                              'isValidated': 'En Attente',
                                              'pourcentage': '${unitPrice}%',
                                              'number': numberController.text,
                                            };

                                            // DEBUG: Print order details before sending
                                            print(
                                              '=== ORDER SUBMISSION DEBUG ===',
                                            );
                                            print('Product: $product');
                                            print('Quantity: $quantity');
                                            print('Unit Price: $unitPrice');
                                            print(
                                              'Client ID: ${isclient ? payload['clid'] : clientId}',
                                            );
                                            print(
                                              'Order Number: ${numberController.text}',
                                            );
                                            print(
                                              'Full Order Payload: ${jsonEncode(orderPayload)}',
                                            );
                                            print(
                                              'API Endpoint: http://estcommand.ddns.net:8080/api/v1/commands',
                                            );
                                            print(
                                              'Auth Token: ${token.substring(0, 20)}...',
                                            );
                                            print(
                                              '===============================',
                                            );

                                            // Note: Direct API call without optimistic update for performance

                                            print(
                                              'DEBUG: Creating order via API...',
                                            );

                                            // Use dynamic server selection for order creation
                                            final serverConfig =
                                                await _networkService
                                                    .getBestAvailableServer();
                                            if (!serverConfig.isAvailable) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'No server available. Please check your connection.',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                              return;
                                            }

                                            final response = await http.post(
                                              Uri.parse(
                                                '${serverConfig.apiBaseUrl}/commands',
                                              ),
                                              headers: {
                                                'Content-Type':
                                                    'application/json',
                                                'Authorization':
                                                    'Bearer $token',
                                              },
                                              body: jsonEncode(orderPayload),
                                            );

                                            // DEBUG: Print server response
                                            print(
                                              '=== SERVER RESPONSE DEBUG ===',
                                            );
                                            print(
                                              'Status Code: ${response.statusCode}',
                                            );
                                            print(
                                              'Response Headers: ${response.headers}',
                                            );
                                            print(
                                              'Response Body: ${response.body}',
                                            );
                                            print(
                                              '=============================',
                                            );

                                            if (response.statusCode == 201 ||
                                                response.statusCode == 200) {
                                              print(
                                                'DEBUG: Order creation successful, updating cache with real data',
                                              );

                                              // Parse the real order from server response
                                              try {
                                                final responseData = json
                                                    .decode(response.body);

                                                // 📡 Broadcast new order to other users via WebSocket
                                                _sendWebSocketMessage(
                                                  'ORDER_CREATED',
                                                  responseData,
                                                );
                                                if (responseData['data'] !=
                                                    null) {
                                                  // Refresh from database to show new order with filters preserved
                                                  await fetchPurchaseOrders(
                                                    page: _currentPage,
                                                    pageSize: _rowsPerPage,
                                                    keepPage: true,
                                                    stateFilter: selectedState,
                                                    productFilters:
                                                        productCheckboxes
                                                            .entries
                                                            .where(
                                                              (entry) =>
                                                                  entry.value,
                                                            )
                                                            .map(
                                                              (entry) =>
                                                                  entry.key,
                                                            )
                                                            .toList(),
                                                    dateRange:
                                                        selectedDateRange,
                                                  );
                                                }
                                              } catch (e) {
                                                print(
                                                  'DEBUG: Error parsing server response: $e',
                                                );
                                              }

                                              // Refresh from database to get any other new orders with filters preserved
                                              await fetchPurchaseOrders(
                                                page: _currentPage,
                                                pageSize: _rowsPerPage,
                                                keepPage: true,
                                                stateFilter: selectedState,
                                                productFilters:
                                                    productCheckboxes.entries
                                                        .where(
                                                          (entry) =>
                                                              entry.value,
                                                        )
                                                        .map(
                                                          (entry) => entry.key,
                                                        )
                                                        .toList(),
                                                dateRange: selectedDateRange,
                                              );
                                            } else {
                                              throw Exception(
                                                'Failed to create order: ${response.statusCode} - ${response.body}',
                                              );
                                            }
                                          }

                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  "${selectedProducts.length} Orders created successfully",
                                                ),
                                                backgroundColor: const Color(
                                                  0xFF1F2937,
                                                ), // Dark grey for success
                                              ),
                                            );
                                            Navigator.pop(context);
                                          }
                                        }
                                      } catch (e) {
                                        print('Error creating order: $e');

                                        // Remove any optimistic orders since creation failed
                                        // Note: In case of error, we'll refresh the cache to ensure consistency
                                        print(
                                          'DEBUG: Order creation failed, refreshing from database to ensure consistency',
                                        );
                                        await fetchPurchaseOrders(
                                          page: _currentPage,
                                          pageSize: _rowsPerPage,
                                          keepPage: true,
                                          stateFilter: selectedState,
                                          productFilters: productCheckboxes
                                              .entries
                                              .where((entry) => entry.value)
                                              .map((entry) => entry.key)
                                              .toList(),
                                          dateRange: selectedDateRange,
                                        );

                                        // Refresh UI to remove the failed order
                                        if (mounted) {
                                          setState(() {
                                            if (searchQuery.isNotEmpty) {
                                              _performLocalSearch(
                                                searchQuery: searchQuery,
                                                page: _currentPage,
                                                pageSize: _rowsPerPage,
                                                stateFilter: selectedState,
                                                productFilters:
                                                    productCheckboxes.entries
                                                        .where(
                                                          (entry) =>
                                                              entry.value,
                                                        )
                                                        .map(
                                                          (entry) => entry.key,
                                                        )
                                                        .toList(),
                                                dateRange: selectedDateRange,
                                              );
                                            } else {
                                              _performLocalBrowsing(
                                                page: _currentPage,
                                                pageSize: _rowsPerPage,
                                                stateFilter: selectedState,
                                                productFilters:
                                                    productCheckboxes.entries
                                                        .where(
                                                          (entry) =>
                                                              entry.value,
                                                        )
                                                        .map(
                                                          (entry) => entry.key,
                                                        )
                                                        .toList(),
                                                dateRange: selectedDateRange,
                                              );
                                            }
                                          });

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Error creating order: $e',
                                              ),
                                              backgroundColor: const Color(
                                                0xFFDC2626,
                                              ), // Primary red for errors
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  : null,
                              icon: Icon(Icons.add_shopping_cart, size: 20),
                              label: Text(
                                'Créer Commande (${selectedProducts.length})',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
            );
          },
        );
      },
    );
  }

  // New function that takes order ID directly (safer approach)
  void _updateOrderById(
    dynamic orderId,
    Map<String, dynamic> updatedOrder,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    // Safety check for null orderId
    if (orderId == null) {
      print('ERROR: Order ID is null! Cannot update order.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Cannot update order - invalid order ID'),
            backgroundColor: const Color(0xFFDC2626), // Primary red for errors
          ),
        );
      }
      return;
    }

    print('DEBUG: _updateOrderById called with orderId: $orderId');

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

    // 🔥 PRESERVE VALIDATION STATUS: Editing order details should NOT invalidate the order
    // Only include validation status if explicitly provided in the update
    if (updatedOrder['state'] != null) {
      body['isValidated'] = updatedOrder['state'];
      print(
        'DEBUG: Explicitly setting validation status: ${updatedOrder['state']}',
      );
    }
    // If no state provided, don't send isValidated - let backend preserve current status

    // DEBUG: Print order update details
    print('=== ORDER UPDATE DEBUG ===');
    print('Order ID: $orderId');
    print('Updated Order Data: ${jsonEncode(updatedOrder)}');
    print('Update Payload: ${jsonEncode(body)}');
    print(
      'API Endpoint: http://estcommand.ddns.net:8080/api/v1/commands/$orderId',
    );
    print('Auth Token: ${token.substring(0, 20)}...');
    print('=========================');

    // Use dynamic server selection for order update
    final serverConfig = await _networkService.getBestAvailableServer();
    if (!serverConfig.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No server available. Please check your connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final response = await http.put(
      Uri.parse('${serverConfig.apiBaseUrl}/commands/$orderId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    // DEBUG: Print update response
    print('=== UPDATE RESPONSE DEBUG ===');
    print('Status Code: ${response.statusCode}');
    print('Response Headers: ${response.headers}');
    print('Response Body: ${response.body}');
    print('============================');
    if (response.statusCode == 200) {
      // ✅ SUCCESS: Refresh from database to get current state
      if (mounted) {
        print('DEBUG: ✅ Order update successful, refreshing from database');

        // Refresh data directly from database with filters preserved
        await fetchPurchaseOrders(
          page: _currentPage,
          pageSize: _rowsPerPage,
          keepPage: true,
          stateFilter: selectedState,
          productFilters: productCheckboxes.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList(),
          dateRange: selectedDateRange,
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order updated successfully'),
            backgroundColor: const Color(0xFF1F2937), // Dark grey for success
            duration: Duration(seconds: 2),
          ),
        );

        // Broadcast the update via WebSocket for real-time sync with other users
        _sendWebSocketMessage('ORDER_UPDATED', {
          'orderId': orderId,
          'updatedFields': updatedOrder,
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order: ${response.statusCode}'),
            backgroundColor: const Color(0xFFDC2626), // Primary red for errors
          ),
        );
      }
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

                              // Use dynamic server selection for client search
                              final serverConfig = await _networkService
                                  .getBestAvailableServer();
                              if (!serverConfig.isAvailable) {
                                return [];
                              }

                              final response = await http.get(
                                Uri.parse(
                                  '${serverConfig.apiBaseUrl}/clients/search?term=$pattern',
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
                    final result = await _createUser(
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

                    if (result['success'] == false) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result['message'] ?? 'Failed to create user',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
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

  Future<Map<String, dynamic>> _createUser({
    required String username,
    required String password,
    String? clId,
    int? isadmin,
    int? isCl,
    int? isSu,
    int? isCo,
  }) async {
    // Use dynamic server selection for user registration
    final serverConfig = await _networkService.getBestAvailableServer();
    if (!serverConfig.isAvailable) {
      return {
        'success': false,
        'message': 'No server available. Please check your connection.',
      };
    }

    final url = Uri.parse('${serverConfig.apiBaseUrl}/auth/register');
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
        return {'success': true, 'message': 'User created successfully'};
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${response.statusCode} - ${response.body}'),
          ),
        );
        return {
          'success': false,
          'message': 'Failed: ${response.statusCode} - ${response.body}',
        };
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      return {'success': false, 'message': 'Error: $e'};
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
    isSuserr = await isSuper();
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

  void _checkDelegue() async {
    isDelegatee = await isDelegue() ?? false;
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
            Icon(Icons.settings, color: const Color(0xFFDC2626)),
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
                        color: const Color(0xFFDC2626),
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
              backgroundColor: const Color(0xFFDC2626),
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
    print('DEBUG: ===== CLIENT SEARCH TRIGGERED =====');
    print('DEBUG: _onSearchChanged called with value: "$value"');
    print('DEBUG: Value length: ${value.length}');
    print('DEBUG: Value isEmpty: ${value.isEmpty}');

    final wasSearching = searchQuery.isNotEmpty;
    final isNowSearching = value.isNotEmpty;

    if (mounted) {
      setState(() => searchQuery = value);
      print('DEBUG: searchQuery updated to: "$searchQuery"');
    }

    // Log refresh state changes
    if (wasSearching && !isNowSearching) {
      print('DEBUG: Search cleared - auto-refresh will resume');
    } else if (!wasSearching && isNowSearching) {
      print('DEBUG: Search started - auto-refresh paused');
    }

    // Cancel previous timer
    _searchTimer?.cancel();

    // Start new timer with optimized delay
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        print('DEBUG: ===== SEARCH TIMER FIRED =====');
        print('DEBUG: Search timer triggered for client search: "$value"');
        print('DEBUG: Current searchQuery state: "$searchQuery"');
        print('DEBUG: About to call _applyFiltersAndRefresh()');
        _applyFiltersAndRefresh();
      }
    });
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        // Don't refresh if user is actively searching
        if (searchQuery.isEmpty) {
          _fetchWithCurrentFilters(page: _currentPage);
        } else {
          print(
            'DEBUG: Skipping auto-refresh during active search: "$searchQuery"',
          );
        }
      }
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
  int _rowsPerPage = 10;
  bool _hasActiveFilters = false; // Track if we have active filters
  bool _isLoading = false;
  DateTime? _lastPaginationCall;

  // Cache for pagination data
  final Map<String, Map<String, dynamic>> _pageCache = {};
  static const int _maxCacheSize = 10; // Keep last 10 pages in cache

  // Cache for user info to avoid repeated API calls
  bool? _cachedIsDelegue;
  String? _cachedUserRegion;
  bool? _cachedIsSuper;
  DateTime? _userInfoCacheTime;

  List<Map<String, dynamic>> get paginatedOrders {
    // Since filtering logic is now handled in fetchPurchaseOrders, just return current page orders
    return _currentPageOrders;
  }

  // Generate cache key based on current filters
  String _generateCacheKey(int page) {
    final selectedProducts = productCheckboxes.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    final productFilters =
        (selectedProducts.isEmpty ||
            selectedProducts.length == productCheckboxes.length)
        ? null
        : selectedProducts;

    return 'page_${page}_search_${searchQuery}_state_${selectedState}_products_${productFilters?.join(',') ?? 'all'}_date_${selectedDateRange?.start.toString() ?? 'none'}_${selectedDateRange?.end.toString() ?? 'none'}';
  }

  // Manage cache size
  void _manageCacheSize() {
    if (_pageCache.length > _maxCacheSize) {
      // Remove oldest entries (simple FIFO)
      final keysToRemove = _pageCache.keys
          .take(_pageCache.length - _maxCacheSize)
          .toList();
      for (final key in keysToRemove) {
        _pageCache.remove(key);
      }
    }
  }

  // Optimized pagination method with debouncing, loading states and caching
  Future<void> _changePage(int newPage) async {
    // Debouncing: prevent rapid pagination calls
    final now = DateTime.now();
    if (_lastPaginationCall != null &&
        now.difference(_lastPaginationCall!).inMilliseconds < 300) {
      return;
    }
    _lastPaginationCall = now;

    // Prevent multiple simultaneous calls
    if (_isLoading) return;

    // Start text fade out animation
    _textFadeController.reverse();

    // Wait for fade out to complete
    await Future.delayed(const Duration(milliseconds: 300));

    final cacheKey = _generateCacheKey(newPage);

    // Check cache first
    if (_pageCache.containsKey(cacheKey)) {
      final cachedData = _pageCache[cacheKey]!;
      setState(() {
        _currentPage = newPage;
        _currentPageOrders = List<Map<String, dynamic>>.from(
          cachedData['orders'],
        );
        _totalOrdersCount = cachedData['totalCount'];
      });
      // Start text fade in animation
      _textFadeController.forward();
      return;
    }

    setState(() {
      _isLoading = true;
      _currentPage = newPage;
    });

    try {
      await _fetchWithCurrentFilters(page: newPage);

      // Cache the result
      _pageCache[cacheKey] = {
        'orders': List<Map<String, dynamic>>.from(_currentPageOrders),
        'totalCount': _totalOrdersCount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      _manageCacheSize();
    } catch (e) {
      // Handle error and revert page if needed
      print('Pagination error: $e');
      setState(() {
        _currentPage = _currentPage == newPage ? 0 : _currentPage; // Fallback
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Start text fade in animation after data is loaded
        _textFadeController.forward();
      }
    }
  }

  Widget _buildPaginationControls() {
    final totalPages = (_totalOrdersCount / _rowsPerPage).ceil();

    if (totalPages <= 1) {
      return const SizedBox.shrink(); // Hide pagination if only one page
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
      child: MediaQuery.of(context).size.width > 600
          ? _buildDesktopPagination(totalPages)
          : _buildMobilePagination(totalPages),
    );
  }

  // Desktop pagination - COMPACT version
  Widget _buildDesktopPagination(int totalPages) {
    return Row(
      children: [
        // Compact page info
        Text(
          'Showing ${(_currentPage * _rowsPerPage) + 1}-${((_currentPage + 1) * _rowsPerPage).clamp(0, _totalOrdersCount)} of $_totalOrdersCount',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),

        const Spacer(),

        // Compact navigation controls
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // First page (compact)
            IconButton(
              icon: const Icon(Icons.first_page, size: 18),
              onPressed: (_currentPage > 0 && !_isLoading)
                  ? () => _changePage(0)
                  : null,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'First',
            ),

            // Previous page (compact)
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Icon(Icons.chevron_left, size: 18),
              onPressed: (_currentPage > 0 && !_isLoading)
                  ? () => _changePage(_currentPage - 1)
                  : null,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Previous',
            ),

            // Compact page numbers
            ..._buildCompactPageNumbers(totalPages),

            // Next page (compact)
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Icon(Icons.chevron_right, size: 18),
              onPressed: ((_currentPage + 1) < totalPages && !_isLoading)
                  ? () => _changePage(_currentPage + 1)
                  : null,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Next',
            ),

            // Last page (compact)
            IconButton(
              icon: const Icon(Icons.last_page, size: 18),
              onPressed: ((_currentPage + 1) < totalPages && !_isLoading)
                  ? () => _changePage(totalPages - 1)
                  : null,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Last',
            ),
          ],
        ),

        const Spacer(),

        // Compact page size selector
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Show:',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(width: 4),
            DropdownButton<int>(
              value: _rowsPerPage,
              underline: Container(),
              isDense: true,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              items: const [
                DropdownMenuItem(value: 10, child: Text('10')),
                DropdownMenuItem(value: 25, child: Text('25')),
                DropdownMenuItem(value: 50, child: Text('50')),
                DropdownMenuItem(value: 100, child: Text('100')),
              ],
              onChanged: _isLoading ? null : (value) => _changePageSize(value!),
            ),
          ],
        ),
      ],
    );
  }

  // Mobile pagination - COMPACT version
  Widget _buildMobilePagination(int totalPages) {
    return Row(
      children: [
        // Compact mobile page info
        Text(
          '${_currentPage + 1}/$totalPages',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),

        const Spacer(),

        // Compact mobile navigation
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.first_page, size: 18),
              onPressed: (_currentPage > 0 && !_isLoading)
                  ? () => _changePage(0)
                  : null,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Icon(Icons.chevron_left, size: 20),
              onPressed: (_currentPage > 0 && !_isLoading)
                  ? () => _changePage(_currentPage - 1)
                  : null,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),

            // Current page indicator (compact)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentPage + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),

            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Icon(Icons.chevron_right, size: 20),
              onPressed: ((_currentPage + 1) < totalPages && !_isLoading)
                  ? () => _changePage(_currentPage + 1)
                  : null,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              icon: const Icon(Icons.last_page, size: 18),
              onPressed: ((_currentPage + 1) < totalPages && !_isLoading)
                  ? () => _changePage(totalPages - 1)
                  : null,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),

        const Spacer(),

        // Compact page size (mobile)
        DropdownButton<int>(
          value: _rowsPerPage,
          underline: Container(),
          isDense: true,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
          items: const [
            DropdownMenuItem(value: 10, child: Text('10')),
            DropdownMenuItem(value: 25, child: Text('25')),
            DropdownMenuItem(value: 50, child: Text('50')),
          ],
          onChanged: _isLoading ? null : (value) => _changePageSize(value!),
        ),
      ],
    );
  }

  // Build compact page number buttons for desktop
  List<Widget> _buildCompactPageNumbers(int totalPages) {
    List<Widget> pageButtons = [];

    // Show fewer pages for compact design
    int startPage = (_currentPage - 1).clamp(0, totalPages - 1);
    int endPage = (_currentPage + 1).clamp(0, totalPages - 1);

    // Add page number buttons
    for (int i = startPage; i <= endPage; i++) {
      pageButtons.add(_buildCompactPageButton(i));
    }

    // Add ellipsis and last page if needed
    if (endPage < totalPages - 1) {
      if (endPage < totalPages - 2) {
        pageButtons.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '...',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
        );
      }
      pageButtons.add(_buildCompactPageButton(totalPages - 1));
    }

    return pageButtons;
  }

  // Build compact individual page button
  Widget _buildCompactPageButton(int pageIndex) {
    final isCurrentPage = pageIndex == _currentPage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: isCurrentPage ? Colors.red.shade600 : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: _isLoading ? null : () => _changePage(pageIndex),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              border: isCurrentPage
                  ? null
                  : Border.all(color: Colors.grey.shade400, width: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '${pageIndex + 1}',
                style: TextStyle(
                  color: isCurrentPage ? Colors.white : Colors.grey.shade700,
                  fontWeight: isCurrentPage
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Change page size and refresh
  void _changePageSize(int newPageSize) async {
    setState(() {
      _rowsPerPage = newPageSize;
      _currentPage = 0; // Reset to first page
    });

    // Clear cache since page size changed
    _clearCache();

    await _fetchWithCurrentFilters(page: 0);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFDC2626), // Primary red
        elevation: 0,
        foregroundColor: Colors.white,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        centerTitle: true,
        title: LayoutBuilder(
          builder: (context, constraints) {
            // On mobile (screen width < 600), show only logo
            if (MediaQuery.of(context).size.width < 600) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/my_logo.png',
                    height: 32,
                    width: 32,
                  ),
                  if (_isRefreshingInBackground) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.red.shade400,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            } else {
              // On larger screens, show logo + title
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/my_logo.png',
                    height: 32,
                    width: 32,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Commandes EST STAR',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  if (_isRefreshingInBackground) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.red.shade400,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }
          },
        ),
        actions: [
          // Connection Status Indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _isConnected ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isConnected
                    ? Colors.green.shade200
                    : Colors.red.shade200,
                width: 1,
              ),
            ),
            child: Tooltip(
              message: _connectionStatus,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isConnected ? Icons.wifi : Icons.wifi_off,
                      color: _isConnected
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isConnected ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: _isConnected
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isAdminn || isSuserr)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6), // Light grey
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  FontAwesomeIcons.whatsapp,
                  color: const Color(0xFF1F2937), // Dark grey for success
                  size: 20,
                ),
                tooltip: 'Configuration WhatsApp: $_whatsappNumber',
                onPressed: _showWhatsAppConfigDialog,
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2), // Light red tint
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
      body: FadeTransition(
        opacity: _fadeController,
        child: Container(
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
                            // 🎨 Modern Organized Search & Filter Section
                            _buildModernSearchFilterSection(),
                            const SizedBox(height: 8),
                            // 🎨 Modern Action Buttons Section
                            _buildModernActionButtons(),
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
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: searchController,
                                  decoration: const InputDecoration(
                                    labelText: 'Rechercher par client',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: _onSearchChanged,
                                ),
                              ),
                              const SizedBox(width: 12),
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
                                                      (state) =>
                                                          DropdownMenuItem(
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
                                                () =>
                                                    selectedDateRange = picked,
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
                                            backgroundColor: const Color(
                                              0xFFDC2626,
                                            ),
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
                                        if (!isDelegatee)
                                          ElevatedButton.icon(
                                            onPressed: _showAddOrderDialog,
                                            icon: const Icon(
                                              Icons.add,
                                              size: 16,
                                            ),
                                            label: const Text('Ajouter'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.green.shade600,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              searchQuery = '';
                                              searchController.clear();
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              exportAllFilteredOrdersToExcel(),
                                          icon: const Icon(
                                            Icons.download,
                                            size: 16,
                                          ),
                                          label: const Text('Excel'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.teal.shade600,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                child: FadeTransition(
                  opacity: _pageTransitionController,
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
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: isDesktop()
                                    ? _buildMultiColumnLayout(paginatedOrders)
                                    : ListView.separated(
                                        key: PageStorageKey(
                                          'orders_list_${_currentPage}',
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        itemCount: paginatedOrders.length,
                                        cacheExtent:
                                            1000, // Cache more items for smoother scrolling
                                        separatorBuilder: (context, index) =>
                                            const SizedBox(
                                              height: 8,
                                              child: Divider(
                                                thickness: 0.5,
                                                color: Colors.grey,
                                                indent: 20,
                                                endIndent: 20,
                                              ),
                                            ),
                                        itemBuilder: (context, index) {
                                          final order = paginatedOrders[index];
                                          final price =
                                              10000 -
                                              ((order['prixPercent'] ?? 0) /
                                                  100 *
                                                  10000);

                                          // ✨ Wrap with staggered animation
                                          return _buildStaggeredListItem(
                                            index: index,
                                            child: _buildEnhancedMobileCard(
                                              order,
                                              index,
                                              price.toDouble(),
                                              key: ValueKey(
                                                'order_${order['id']}_${_currentPage}',
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ),
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
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: DataTable(
                                    key: ValueKey(
                                      'data_table_${_currentPage}_${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
                                    ),
                                    columnSpacing: 5,
                                    showCheckboxColumn: false,
                                    columns: [
                                      _buildSortableColumn('Client', 'client'),
                                      _buildSortableColumn(
                                        'Produit',
                                        'product',
                                      ),
                                      _buildSortableColumn(
                                        'Quantité',
                                        'quantity',
                                      ),
                                      _buildSortableColumn(
                                        'PU %',
                                        'prixPercent',
                                      ),
                                      const DataColumn(label: Text('Prix')),
                                      _buildSortableColumn('Numéro ', 'number'),
                                      _buildSortableColumn('Etat C', 'state'),
                                      _buildSortableColumn('Crée Par', 'name'),
                                      _buildSortableColumn(
                                        'Etat Val',
                                        'accepted',
                                      ),
                                      _buildSortableColumn('Date', 'date'),
                                      // Always include Actions column to match cells
                                      const DataColumn(label: Text('Actions')),
                                    ],
                                    rows: paginatedOrders.asMap().entries.map((
                                      entry,
                                    ) {
                                      final realIndex = entry.key;
                                      final order = entry.value;
                                      final calcPrice =
                                          10000 -
                                          ((order['prixPercent'] ?? 0) /
                                              100 *
                                              10000);

                                      return DataRow(
                                        key: ValueKey(
                                          'data_row_${order['id']}_${_currentPage}_${realIndex}',
                                        ),
                                        cells: [
                                          DataCell(Text(order['client'] ?? '')),
                                          DataCell(Text(order['product'])),
                                          DataCell(
                                            Text('${order['quantity']}'),
                                          ),
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
                                                    if (numberToCopy
                                                        .isNotEmpty) {
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
                                                color: _stateColor(
                                                  order['state'],
                                                ),
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
                                            Text(
                                              DateFormat(
                                                'dd/MM/yyyy HH:mm:ss',
                                              ).format(
                                                DateTime.parse(order['date']),
                                              ),
                                            ),
                                          ),
                                          // Always include Actions cell to match columns
                                          DataCell(
                                            (isAdminn || isSuserr)
                                                ? SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    child: Row(
                                                      children: [
                                                        // Admin: Accept Order State (Etat C)
                                                        if (isAdminn) ...[
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.check,
                                                              color:
                                                                  Colors.green,
                                                            ),
                                                            onPressed: () =>
                                                                _changeOrderState(
                                                                  realIndex,
                                                                  'Effectué',
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          // Reject Order State (Etat C)
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
                                                        ],
                                                        // Superuser: Validate Order (Etat Val)
                                                        if (isSuserr) ...[
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.verified,
                                                              color:
                                                                  Colors.blue,
                                                            ),
                                                            onPressed: () =>
                                                                _changeOrderAccepted(
                                                                  realIndex,
                                                                  true,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          // Invalidate Order (Etat Val)
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.block,
                                                              color:
                                                                  Colors.orange,
                                                            ),
                                                            onPressed: () =>
                                                                _changeOrderAccepted(
                                                                  realIndex,
                                                                  false,
                                                                ),
                                                          ),
                                                        ],
                                                        // Additional admin-only buttons
                                                        if (isAdminn) ...[
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons
                                                                  .phone_disabled,
                                                              color: Colors.red,
                                                            ),
                                                            onPressed: () =>
                                                                _changeOrderState(
                                                                  realIndex,
                                                                  'Numéro Incorrecte',
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons
                                                                  .money_off_csred,
                                                              color: Colors.red,
                                                            ),
                                                            onPressed: () =>
                                                                _changeOrderState(
                                                                  realIndex,
                                                                  'Problème Solde',
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons
                                                                  .hourglass_bottom,
                                                              color:
                                                                  Colors.orange,
                                                            ),
                                                            onPressed: () =>
                                                                _changeOrderState(
                                                                  realIndex,
                                                                  'En Attente',
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.edit,
                                                              color:
                                                                  Colors.blue,
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
                                                                FontAwesomeIcons
                                                                    .whatsapp,
                                                                color: Colors
                                                                    .green,
                                                              ),
                                                              onPressed: () =>
                                                                  _sendOrderToWhatsApp(
                                                                    order,
                                                                  ),
                                                            ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.delete,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                            onPressed: () =>
                                                                _confirmDeleteOrder(
                                                                  realIndex,
                                                                ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  )
                                                : const SizedBox.shrink(), // Empty widget for non-admin users
                                          ),
                                        ],
                                      );
                                    }).toList(),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildProductFilter() {
    // Check if any products are deselected (meaning filter is active)
    final selectedProducts = productCheckboxes.entries
        .where((entry) => entry.value)
        .length;
    final totalProducts = productCheckboxes.length;
    final hasActiveFilter =
        selectedProducts < totalProducts && selectedProducts > 0;

    return ElevatedButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => _buildModernProductFilterDialog(),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: hasActiveFilter
            ? Colors.orange.shade50
            : Colors.blue.shade50,
        foregroundColor: hasActiveFilter
            ? Colors.orange.shade700
            : Colors.blue.shade700,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasActiveFilter ? Icons.filter_alt : Icons.filter_list,
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              hasActiveFilter
                  ? "Produits ($selectedProducts/$totalProducts)"
                  : "Filtrer Produits",
              style: TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernProductFilterDialog() {
    TextEditingController searchController = TextEditingController();
    List<String> filteredProducts = productCheckboxes.keys.toList();
    Map<String, bool> tempProductCheckboxes = Map.from(productCheckboxes);

    // Group products by category for better organization
    Map<String, List<String>> productCategories = _groupProductsByCategory(
      filteredProducts,
    );

    return StatefulBuilder(
      builder: (context, setDialogState) {
        void filterSearch(String query) {
          setDialogState(() {
            if (query.isEmpty) {
              filteredProducts = tempProductCheckboxes.keys.toList();
            } else {
              filteredProducts = tempProductCheckboxes.keys
                  .where(
                    (product) =>
                        product.toLowerCase().contains(query.toLowerCase()),
                  )
                  .toList();
            }
          });
        }

        final selectedCount = tempProductCheckboxes.values
            .where((v) => v)
            .length;
        final totalCount = tempProductCheckboxes.length;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                // Header with custom styling
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.tune, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filtrer par Produits',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '$selectedCount sur $totalCount produits sélectionnés',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    onChanged: filterSearch,
                    decoration: InputDecoration(
                      hintText: 'Rechercher dans $totalCount produits...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                filterSearch('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),

                // Quick Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildQuickActionChip(
                        'Tout sélectionner',
                        Icons.check_box,
                        Colors.green,
                        () {
                          setDialogState(() {
                            tempProductCheckboxes.updateAll(
                              (key, value) => true,
                            );
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildQuickActionChip(
                        'Tout déselectionner',
                        Icons.check_box_outline_blank,
                        Colors.red,
                        () {
                          setDialogState(() {
                            tempProductCheckboxes.updateAll(
                              (key, value) => false,
                            );
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildQuickActionChip(
                        'Inverser',
                        Icons.swap_horiz,
                        Colors.blue,
                        () {
                          setDialogState(() {
                            tempProductCheckboxes.updateAll(
                              (key, value) => !value,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Products List with categories
                Expanded(
                  child: searchController.text.isNotEmpty
                      ? _buildSearchResults(
                          filteredProducts,
                          tempProductCheckboxes,
                          setDialogState,
                        )
                      : _buildCategorizedProducts(
                          productCategories,
                          tempProductCheckboxes,
                          setDialogState,
                        ),
                ),

                // Footer Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              productCheckboxes = Map.from(
                                tempProductCheckboxes,
                              );
                            });
                            _applyFiltersAndRefresh();
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text('Appliquer ($selectedCount)'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to group products by category
  Map<String, List<String>> _groupProductsByCategory(List<String> products) {
    Map<String, List<String>> categories = {
      'SEHELLI': [],
      'STORM': [],
      'FLEXY': [],
      'ARSELLI': [],
      'IDOOM': [],
      'Autres': [],
    };

    for (String product in products) {
      String upperProduct = product.toUpperCase();
      if (upperProduct.contains('SEHELLI')) {
        categories['SEHELLI']!.add(product);
      } else if (upperProduct.contains('STORM')) {
        categories['STORM']!.add(product);
      } else if (upperProduct.contains('FLEXY')) {
        categories['FLEXY']!.add(product);
      } else if (upperProduct.contains('ARSELLI')) {
        categories['ARSELLI']!.add(product);
      } else if (upperProduct.contains('IDOOM')) {
        categories['IDOOM']!.add(product);
      } else {
        categories['Autres']!.add(product);
      }
    }

    // Remove empty categories
    categories.removeWhere((key, value) => value.isEmpty);
    return categories;
  }

  // Helper method to build quick action chips
  Widget _buildQuickActionChip(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build search results
  Widget _buildSearchResults(
    List<String> filteredProducts,
    Map<String, bool> tempProductCheckboxes,
    StateSetter setDialogState,
  ) {
    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun produit trouvé',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        final isSelected = tempProductCheckboxes[product] ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withOpacity(0.05) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: CheckboxListTile(
            title: Row(
              children: [
                _getProductIconWidget(product),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    product,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
            value: isSelected,
            onChanged: (value) {
              setDialogState(() {
                tempProductCheckboxes[product] = value!;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            activeColor: _getProductColor(product),
          ),
        );
      },
    );
  }

  // Helper method to build categorized products
  Widget _buildCategorizedProducts(
    Map<String, List<String>> productCategories,
    Map<String, bool> tempProductCheckboxes,
    StateSetter setDialogState,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: productCategories.keys.length,
      itemBuilder: (context, index) {
        final category = productCategories.keys.elementAt(index);
        final products = productCategories[category]!;
        final selectedInCategory = products
            .where((p) => tempProductCheckboxes[p] == true)
            .length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            title: Row(
              children: [
                _getCategoryIconWidget(category),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selectedInCategory == products.length
                        ? Colors.green.withOpacity(0.1)
                        : selectedInCategory > 0
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$selectedInCategory/${products.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selectedInCategory == products.length
                          ? Colors.green[700]
                          : selectedInCategory > 0
                          ? Colors.orange[700]
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            children: products.map((product) {
              final isSelected = tempProductCheckboxes[product] ?? false;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _getProductColor(product).withOpacity(0.05)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CheckboxListTile(
                  title: Row(
                    children: [
                      _getProductIconWidget(product),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          product,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  value: isSelected,
                  onChanged: (value) {
                    setDialogState(() {
                      tempProductCheckboxes[product] = value!;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  activeColor: _getProductColor(product),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Helper method to get product icon widget with custom assets
  Widget _getProductIconWidget(String productName) {
    final upperProduct = productName.toUpperCase();
    String? iconAsset;
    Color iconColor = _getProductColor(productName);

    if (upperProduct.contains('SEHELLI')) {
      iconAsset = 'assets/icons/sehelli.png';
    } else if (upperProduct.contains('STORM')) {
      iconAsset = 'assets/icons/storm.png';
    } else if (upperProduct.contains('FLEXY')) {
      iconAsset = 'assets/icons/flexy.png';
    } else if (upperProduct.contains('ARSELLI')) {
      iconAsset = 'assets/icons/arselli.png';
    } else if (upperProduct.contains('IDOOM')) {
      iconAsset = 'assets/icons/idoom.png';
    }

    return Container(
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: iconAsset != null
          ? Image.asset(
              iconAsset,
              width: 16,
              height: 16,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.inventory_2, size: 16, color: iconColor);
              },
            )
          : Icon(Icons.inventory_2, size: 16, color: iconColor),
    );
  }

  // Helper method to get category icon widget with custom assets
  Widget _getCategoryIconWidget(String category) {
    String? iconAsset;
    Color iconColor;

    switch (category) {
      case 'SEHELLI':
        iconAsset = 'assets/icons/sehelli.png';
        iconColor = Colors.blue;
        break;
      case 'STORM':
        iconAsset = 'assets/icons/storm.png';
        iconColor = Colors.orange;
        break;
      case 'FLEXY':
        iconAsset = 'assets/icons/flexy.png';
        iconColor = Colors.green;
        break;
      case 'ARSELLI':
        iconAsset = 'assets/icons/arselli.png';
        iconColor = Colors.purple;
        break;
      case 'IDOOM':
        iconAsset = 'assets/icons/idoom.png';
        iconColor = Colors.red;
        break;
      default:
        iconAsset = null;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: iconAsset != null
          ? Image.asset(
              iconAsset,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.category, color: iconColor, size: 20);
              },
            )
          : Icon(Icons.category, color: iconColor, size: 20),
    );
  }

  // Helper method to get product color
  Color _getProductColor(String productName) {
    final upperProduct = productName.toUpperCase();
    if (upperProduct.contains('SEHELLI')) return Colors.blue;
    if (upperProduct.contains('STORM')) return Colors.orange;
    if (upperProduct.contains('FLEXY')) return Colors.green;
    if (upperProduct.contains('ARSELLI')) return Colors.purple;
    if (upperProduct.contains('IDOOM')) return Colors.red;
    return Colors.grey;
  }

  // Modern Visual Product Selector for New Order dialog
  Widget _buildVisualProductSelector({
    required List<Product> availableProducts,
    required Function(Product) onProductSelected,
  }) {
    return _VisualProductSelectorWidget(
      availableProducts: availableProducts,
      onProductSelected: onProductSelected,
    );
  }

  // Visual Product Selector for Filter Dialog
  Widget _buildVisualProductSelectorForFilter({
    required List<Product> availableProducts,
    required Map<String, bool> selectedProducts,
    required Function(Product) onProductSelected,
  }) {
    return _VisualProductSelectorForFilterWidget(
      availableProducts: availableProducts,
      selectedProducts: selectedProducts,
      onProductSelected: onProductSelected,
    );
  }

  // Helper method for modern filter cards
  Widget _buildModernFilterCard({
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
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

  Widget _buildEnhancedMobileCard(
    Map<String, dynamic> order,
    int realIndex,
    double price, {
    Key? key,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showOrderDetails(order, realIndex),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with client and state
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildFadeText(
                        text: order['client'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _stateColor(order['state']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _stateColor(order['state']).withOpacity(0.3),
                        ),
                      ),
                      child: _buildFadeText(
                        text: order['state'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _stateColor(order['state']),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Product info
                _buildFadeText(
                  text: order['product'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Quantity and price row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFadeText(
                      text: 'Qty: ${order['quantity'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    _buildFadeText(
                      text: '${price.toStringAsFixed(0)} DA',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Date and actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFadeText(
                      text: _formatDate(order['date']),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (isAdminn || isSuserr)
                      Row(
                        children: [
                          // Validate button (Effectué)
                          IconButton(
                            icon: const Icon(Icons.check, size: 18),
                            onPressed: () =>
                                _changeOrderState(realIndex, 'Effectué'),
                            color: Colors.green,
                          ),
                          // Not Validate button (Rejeté)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                _changeOrderState(realIndex, 'Rejeté'),
                            color: Colors.red,
                          ),
                          // Additional admin-only buttons
                          if (isAdminn) ...[
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _showEditDialog(realIndex),
                              color: Colors.blue,
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _stateColor(String state) {
    switch (state) {
      case 'Effectué':
        return const Color.fromARGB(255, 27, 138, 27); // Green for success
      case 'En Attente':
      case 'En attente':
        return Colors.orange; // Orange/Yellow for pending
      case 'Rejeté':
        return const Color(0xFFDC2626); // Red for rejection
      case 'Numéro Incorrecte':
      case 'Numéro incorrecte':
        return const Color(0xFFDC2626); // Red for errors
      case 'Problème Solde':
      case 'Problème solde':
        return const Color(0xFFDC2626); // Red for problems
      default:
        return const Color(0xFF9CA3AF); // Light grey for unknown
    }
  }

  // Helper method to format date
  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      DateTime dateTime;
      if (date is String) {
        dateTime = DateTime.parse(date);
      } else if (date is DateTime) {
        dateTime = date;
      } else {
        return 'N/A';
      }
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  // Helper method to show order details
  void _showOrderDetails(Map<String, dynamic> order, int realIndex) {
    // This method should be implemented based on your requirements
    // For now, just show a simple dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order Details'),
        content: Text('Order ID: ${order['_id'] ?? 'N/A'}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _VisualProductSelectorWidget extends StatefulWidget {
  final List<Product> availableProducts;
  final Function(Product) onProductSelected;

  const _VisualProductSelectorWidget({
    required this.availableProducts,
    required this.onProductSelected,
  });

  @override
  _VisualProductSelectorWidgetState createState() =>
      _VisualProductSelectorWidgetState();
}

class _VisualProductSelectorWidgetState
    extends State<_VisualProductSelectorWidget> {
  late TextEditingController searchController;
  late List<Product> filteredProducts;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    filteredProducts = widget.availableProducts;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredProducts = widget.availableProducts;
      } else {
        filteredProducts = widget.availableProducts.where((product) {
          return (product.productName ?? '').toLowerCase().contains(
            query.toLowerCase(),
          );
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350, // Increased height for better visibility
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          // Header with search
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.add_shopping_cart,
                      color: Colors.blue[600],
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sélectionner Produits (${widget.availableProducts.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // Search field
                TextField(
                  controller: searchController,
                  onChanged: filterProducts,
                  decoration: InputDecoration(
                    hintText: 'Rechercher produits...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18),
                            onPressed: () {
                              searchController.clear();
                              filterProducts('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          // Visual Product Grid
          Expanded(
            child: _buildProductGrid(
              filteredProducts,
              widget.onProductSelected,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build product grid with categories
  Widget _buildProductGrid(
    List<Product> availableProducts,
    Function(Product) onProductSelected,
  ) {
    // Group products by category
    Map<String, List<Product>> productCategories = {};

    for (Product product in availableProducts) {
      String productName = product.productName ?? '';
      String upperProduct = productName.toUpperCase();
      String category;

      if (upperProduct.contains('SEHELLI')) {
        category = 'SEHELLI';
      } else if (upperProduct.contains('STORM')) {
        category = 'STORM';
      } else if (upperProduct.contains('FLEXY')) {
        category = 'FLEXY';
      } else if (upperProduct.contains('ARSELLI')) {
        category = 'ARSELLI';
      } else if (upperProduct.contains('IDOOM')) {
        category = 'IDOOM';
      } else {
        category = 'Autres';
      }

      if (!productCategories.containsKey(category)) {
        productCategories[category] = [];
      }
      productCategories[category]!.add(product);
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: productCategories.keys.length,
      itemBuilder: (context, index) {
        final category = productCategories.keys.elementAt(index);
        final products = productCategories[category]!;

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ExpansionTile(
            tilePadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            title: Row(
              children: [
                _getCategoryIconWidget(category),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$category (${products.length})',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            children: [
              // Use ListView with proper scrolling
              Container(
                constraints: BoxConstraints(
                  maxHeight: 200, // Fixed max height for better scrolling
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: ClampingScrollPhysics(), // Allow scrolling
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: products.length,
                  itemBuilder: (context, productIndex) {
                    final product = products[productIndex];
                    return Container(
                      margin: EdgeInsets.only(bottom: 4),
                      child: _buildProductCard(product, onProductSelected),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper method to build individual product cards
  Widget _buildProductCard(
    Product product,
    Function(Product) onProductSelected,
  ) {
    final productName = product.productName ?? '';
    final productColor = _getProductColor(productName);

    return InkWell(
      onTap: () => onProductSelected(product),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: productColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: productColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            // Product Icon
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: productColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: _getProductIconWidget(productName),
            ),
            SizedBox(width: 12),
            // Product Info - Using Expanded to prevent overflow
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Product name with proper overflow handling
                  Text(
                    productName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: productColor,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  // Price with proper styling
                  Text(
                    '${product.initialPrice?.toStringAsFixed(2) ?? '0'} DA',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            // Add button with better styling
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: productColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.add_circle_outline,
                color: productColor,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get category icon widget with actual logos
  Widget _getCategoryIconWidget(String category) {
    String logoPath;
    switch (category.toUpperCase()) {
      case 'SEHELLI':
        logoPath = 'assets/icons/sehelli.png';
        break;
      case 'STORM':
        logoPath = 'assets/icons/storm.png';
        break;
      case 'FLEXY':
        logoPath = 'assets/icons/flexy.png';
        break;
      case 'ARSELLI':
        logoPath = 'assets/icons/arselli.png';
        break;
      case 'IDOOM':
        logoPath = 'assets/icons/idoom.png';
        break;
      default:
        logoPath = 'assets/icons/autres.png';
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          logoPath,
          width: 28,
          height: 28,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to icon if image fails to load
            return Icon(Icons.category, color: Colors.grey, size: 18);
          },
        ),
      ),
    );
  }

  // Helper method to get product color based on name
  Color _getProductColor(String productName) {
    String upperProduct = productName.toUpperCase();
    if (upperProduct.contains('SEHELLI')) return Colors.blue;
    if (upperProduct.contains('STORM')) return Colors.red;
    if (upperProduct.contains('FLEXY')) return Colors.orange;
    if (upperProduct.contains('ARSELLI')) return Colors.green;
    if (upperProduct.contains('IDOOM')) return Colors.purple;
    return Colors.grey;
  }

  // Helper method to get product icon widget with actual logos
  Widget _getProductIconWidget(String productName) {
    String upperProduct = productName.toUpperCase();
    String logoPath;

    if (upperProduct.contains('SEHELLI')) {
      logoPath = 'assets/icons/sehelli.png';
    } else if (upperProduct.contains('STORM')) {
      logoPath = 'assets/icons/storm.png';
    } else if (upperProduct.contains('FLEXY')) {
      logoPath = 'assets/icons/flexy.png';
    } else if (upperProduct.contains('ARSELLI')) {
      logoPath = 'assets/icons/arselli.png';
    } else if (upperProduct.contains('IDOOM')) {
      logoPath = 'assets/icons/idoom.png';
    } else {
      logoPath = 'assets/icons/autres.png';
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          logoPath,
          width: 20,
          height: 20,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to icon if image fails to load
            return Icon(Icons.inventory, color: Colors.grey, size: 16);
          },
        ),
      ),
    );
  }
}

// Visual Product Selector for Filter Dialog
class _VisualProductSelectorForFilterWidget extends StatefulWidget {
  final List<Product> availableProducts;
  final Map<String, bool> selectedProducts;
  final Function(Product) onProductSelected;

  const _VisualProductSelectorForFilterWidget({
    required this.availableProducts,
    required this.selectedProducts,
    required this.onProductSelected,
  });

  @override
  _VisualProductSelectorForFilterWidgetState createState() =>
      _VisualProductSelectorForFilterWidgetState();
}

class _VisualProductSelectorForFilterWidgetState
    extends State<_VisualProductSelectorForFilterWidget> {
  late TextEditingController searchController;
  late List<Product> filteredProducts;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    filteredProducts = widget.availableProducts;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredProducts = widget.availableProducts;
      } else {
        filteredProducts = widget.availableProducts.where((product) {
          return (product.productName ?? '').toLowerCase().contains(
            query.toLowerCase(),
          );
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          // Header with search
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      color: const Color(0xFFDC2626),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sélectionner Produits (${widget.availableProducts.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // Search field
                TextField(
                  controller: searchController,
                  onChanged: filterProducts,
                  decoration: InputDecoration(
                    hintText: 'Rechercher produits...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18),
                            onPressed: () {
                              searchController.clear();
                              filterProducts('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          // Visual Product Grid
          Expanded(
            child: _buildProductGridForFilter(
              filteredProducts,
              widget.selectedProducts,
              widget.onProductSelected,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build product grid with selection state
  Widget _buildProductGridForFilter(
    List<Product> availableProducts,
    Map<String, bool> selectedProducts,
    Function(Product) onProductSelected,
  ) {
    // Group products by category
    Map<String, List<Product>> productCategories = {};

    for (Product product in availableProducts) {
      String category = _getProductCategory(product.productName ?? '');
      if (!productCategories.containsKey(category)) {
        productCategories[category] = [];
      }
      productCategories[category]!.add(product);
    }

    return ListView.builder(
      padding: EdgeInsets.all(12),
      itemCount: productCategories.length,
      itemBuilder: (context, categoryIndex) {
        final category = productCategories.keys.elementAt(categoryIndex);
        final products = productCategories[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _getCategoryColor(category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getCategoryColor(category).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(category),
                    color: _getCategoryColor(category),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getCategoryColor(category),
                    ),
                  ),
                ],
              ),
            ),
            // Products grid
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final productName = product.productName ?? '';
                final isSelected = selectedProducts[productName] ?? true;

                return GestureDetector(
                  onTap: () => onProductSelected(product),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? _getCategoryColor(category)
                            : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _getCategoryColor(
                                  category,
                                ).withOpacity(0.2),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Selection indicator
                        Container(
                          width: 4,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _getCategoryColor(category)
                                : Colors.transparent,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Product icon - Same as Add Order Dialog
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _getCategoryColor(category).withOpacity(0.1)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: _getProductIconWidget(productName),
                        ),
                        SizedBox(width: 8),
                        // Product name
                        Expanded(
                          child: Text(
                            productName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.grey[800]
                                  : Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Selection checkmark
                        if (isSelected)
                          Container(
                            margin: EdgeInsets.only(right: 8),
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(category),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 16),
          ],
        );
      },
    );
  }

  String _getProductCategory(String productName) {
    final upperProduct = productName.toUpperCase();
    if (upperProduct.contains('STORM')) return 'STORM';
    if (upperProduct.contains('FLEXY')) return 'FLEXY';
    if (upperProduct.contains('ARSELLI')) return 'ARSELLI';
    if (upperProduct.contains('IDOOM')) return 'IDOOM';
    return 'AUTRES';
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'STORM':
        return Colors.blue;
      case 'FLEXY':
        return Colors.green;
      case 'ARSELLI':
        return Colors.purple;
      case 'IDOOM':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'STORM':
        return Icons.flash_on;
      case 'FLEXY':
        return Icons.wifi;
      case 'ARSELLI':
        return Icons.satellite;
      case 'IDOOM':
        return Icons.router;
      default:
        return Icons.inventory_2;
    }
  }

  // Helper method to get product icon widget with actual logos - Same as Add Order Dialog
  Widget _getProductIconWidget(String productName) {
    String upperProduct = productName.toUpperCase();
    String logoPath;

    if (upperProduct.contains('SEHELLI')) {
      logoPath = 'assets/icons/sehelli.png';
    } else if (upperProduct.contains('STORM')) {
      logoPath = 'assets/icons/storm.png';
    } else if (upperProduct.contains('FLEXY')) {
      logoPath = 'assets/icons/flexy.png';
    } else if (upperProduct.contains('ARSELLI')) {
      logoPath = 'assets/icons/arselli.png';
    } else if (upperProduct.contains('IDOOM')) {
      logoPath = 'assets/icons/idoom.png';
    } else {
      logoPath = 'assets/icons/autres.png';
    }

    return Container(
      width: 20,
      height: 20,
      child: Image.asset(
        logoPath,
        width: 20,
        height: 20,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to icon if image fails to load
          return Icon(Icons.inventory, color: Colors.grey, size: 16);
        },
      ),
    );
  }
}
