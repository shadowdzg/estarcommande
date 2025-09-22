import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import '../models/models.dart';
import '../services/purchase_order_service.dart';

abstract class PurchaseOrderRepository {
  Future<PurchaseOrderResponse> getOrders({
    int page = 0,
    int pageSize = 10,
    String? searchQuery,
    String? stateFilter,
    List<String>? productFilters,
    DateTimeRange? dateRange,
  });

  Future<PurchaseOrder> updateOrder(int orderId, Map<String, dynamic> updates);
  Future<void> acceptOrder(int orderId);
  Future<void> rejectOrder(int orderId);
  Future<PurchaseOrder> createOrder(Map<String, dynamic> orderData);
}

class PurchaseOrderRepositoryImpl implements PurchaseOrderRepository {
  final PurchaseOrderService _service;

  // In-memory cache for better performance
  final Map<String, CachedResponse> _cache = {};
  static const Duration _cacheTimeout = Duration(minutes: 2);
  static const int _maxCacheSize = 20;

  PurchaseOrderRepositoryImpl(this._service);

  @override
  Future<PurchaseOrderResponse> getOrders({
    int page = 0,
    int pageSize = 10,
    String? searchQuery,
    String? stateFilter,
    List<String>? productFilters,
    DateTimeRange? dateRange,
  }) async {
    // Generate cache key
    final cacheKey = _generateCacheKey(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      stateFilter: stateFilter,
      productFilters: productFilters,
      dateRange: dateRange,
    );

    // Check cache first
    final cachedResponse = _cache[cacheKey];
    if (cachedResponse != null && !cachedResponse.isExpired) {
      if (kDebugMode) {
        print('Returning cached orders for page $page');
      }
      return cachedResponse.data;
    }

    try {
      // Fetch from service
      final response = await _service.fetchOrders(
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
        stateFilter: stateFilter,
        productFilters: productFilters,
        dateRange: dateRange,
      );

      // Cache the response
      _cacheResponse(cacheKey, response);

      return response;
    } catch (e) {
      // If we have expired cache, return it as fallback
      if (cachedResponse != null) {
        if (kDebugMode) {
          print('Using expired cache as fallback due to error: $e');
        }
        return cachedResponse.data;
      }
      rethrow;
    }
  }

  @override
  Future<PurchaseOrder> updateOrder(
    int orderId,
    Map<String, dynamic> updates,
  ) async {
    final result = await _service.updateOrder(orderId, updates);

    // Invalidate cache after update
    _invalidateCache();

    return result;
  }

  @override
  Future<void> acceptOrder(int orderId) async {
    await _service.setOrderStatus(orderId, true);

    // Smart cache update: Update the specific order in cache instead of invalidating all
    _updateOrderInCache(orderId, 'Effectué');
  }

  @override
  Future<void> rejectOrder(int orderId) async {
    await _service.setOrderStatus(orderId, false);

    // Smart cache update: Update the specific order in cache instead of invalidating all
    _updateOrderInCache(orderId, 'Rejeté');
  }

  // Smart cache update: Update specific order instead of invalidating entire cache
  void _updateOrderInCache(int orderId, String newState) {
    for (final entry in _cache.entries) {
      final response = entry.value.data;
      final updatedOrders = response.data.map((order) {
        if (order.id == orderId) {
          return order.copyWith(state: newState);
        }
        return order;
      }).toList();

      if (updatedOrders.any((order) => order.id == orderId)) {
        // Update the cached response with new order state
        final updatedResponse = PurchaseOrderResponse(
          data: updatedOrders,
          totalCount: response.totalCount,
        );

        _cache[entry.key] = CachedResponse(
          data: updatedResponse,
          timestamp: entry.value.timestamp, // Keep original timestamp
        );
      }
    }
  }

  @override
  Future<PurchaseOrder> createOrder(Map<String, dynamic> orderData) async {
    final result = await _service.createOrder(orderData);

    // Invalidate cache after creation
    _invalidateCache();

    return result;
  }

  // Cache management methods
  String _generateCacheKey({
    required int page,
    required int pageSize,
    String? searchQuery,
    String? stateFilter,
    List<String>? productFilters,
    DateTimeRange? dateRange,
  }) {
    final buffer = StringBuffer();
    buffer.write('page_$page');
    buffer.write('_size_$pageSize');

    if (searchQuery != null && searchQuery.isNotEmpty) {
      buffer.write('_search_$searchQuery');
    }

    if (stateFilter != null) {
      buffer.write('_state_$stateFilter');
    }

    if (productFilters != null && productFilters.isNotEmpty) {
      buffer.write('_products_${productFilters.join(',')}');
    }

    if (dateRange != null) {
      buffer.write('_date_${dateRange.start}_${dateRange.end}');
    }

    return buffer.toString();
  }

  void _cacheResponse(String key, PurchaseOrderResponse response) {
    // Manage cache size
    if (_cache.length >= _maxCacheSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }

    _cache[key] = CachedResponse(data: response, timestamp: DateTime.now());
  }

  void _invalidateCache() {
    _cache.clear();
  }

  void dispose() {
    _cache.clear();
  }
}

class CachedResponse {
  final PurchaseOrderResponse data;
  final DateTime timestamp;

  CachedResponse({required this.data, required this.timestamp});

  bool get isExpired {
    return DateTime.now().difference(timestamp) >
        PurchaseOrderRepositoryImpl._cacheTimeout;
  }
}
