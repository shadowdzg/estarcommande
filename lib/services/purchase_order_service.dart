import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'api_client.dart' hide AuthenticationException;
import 'auth_service.dart';

class PurchaseOrderService {
  final ApiClient _apiClient;
  final AuthService _authService;

  PurchaseOrderService(this._apiClient, this._authService);

  // Fetch purchase orders with pagination and filters
  Future<PurchaseOrderResponse> fetchOrders({
    int page = 0,
    int pageSize = 10,
    String? searchQuery,
    String? stateFilter,
    List<String>? productFilters,
    DateTimeRange? dateRange,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{
        'skip': (page * pageSize).toString(),
        'take': pageSize.toString(),
      };

      // Add filters
      if (stateFilter != null && stateFilter.isNotEmpty) {
        queryParams['isValidated'] = _mapStateFilter(stateFilter);
      }

      if (productFilters != null && productFilters.length == 1) {
        queryParams['operator'] = productFilters.first;
      }

      if (dateRange != null) {
        queryParams['startDate'] = dateRange.start.toIso8601String().split(
          'T',
        )[0];
        queryParams['endDate'] = dateRange.end.toIso8601String().split('T')[0];
      }

      // Determine endpoint based on user role
      final userInfo = await _authService.getCachedUserInfo();
      final endpoint = _getOrdersEndpoint(userInfo);

      if (kDebugMode) {
        print(
          'Fetching orders: page=$page, filters=${queryParams.length > 2 ? 'active' : 'none'}',
        );
      }

      final response = await _apiClient.get(endpoint, queryParams: queryParams);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (kDebugMode) {
          final ordersList = (data['data'] ?? []) as List<dynamic>;
          print(
            'Parsed ${ordersList.length} orders, total: ${data['totalCount'] ?? 0}',
          );
        }

        var orderResponse = PurchaseOrderResponse.fromJson(data);

        // Apply client-side filters if needed
        orderResponse = _applyClientSideFilters(
          orderResponse,
          searchQuery: searchQuery,
          productFilters: productFilters,
        );

        return orderResponse;
      } else if (response.statusCode == 401) {
        throw const AuthenticationException();
      } else {
        throw ServerException(
          'Failed to fetch orders: ${response.reasonPhrase}',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw const NetworkException('Request timeout');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException('Network error: $e');
    }
  }

  // Update an order
  Future<PurchaseOrder> updateOrder(
    int orderId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _apiClient.put(
        '/commands/$orderId',
        body: updates,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return PurchaseOrder.fromJson(data);
      } else if (response.statusCode == 401) {
        throw const AuthenticationException();
      } else {
        throw ServerException(
          'Failed to update order: ${response.reasonPhrase}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException('Network error: $e');
    }
  }

  // Accept/Reject order
  Future<void> setOrderStatus(int orderId, bool accepted) async {
    try {
      final endpoint = '/commands/accept/$orderId';
      final response = await _apiClient.put(
        endpoint,
        body: {'accepted': accepted},
      );

      if (response.statusCode == 401) {
        throw const AuthenticationException();
      } else if (response.statusCode != 200) {
        throw ServerException(
          'Failed to update order status: ${response.reasonPhrase}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException('Network error: $e');
    }
  }

  // Create new order
  Future<PurchaseOrder> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await _apiClient.post('/orders', body: orderData);

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return PurchaseOrder.fromJson(data);
      } else if (response.statusCode == 401) {
        throw const AuthenticationException();
      } else {
        throw ServerException(
          'Failed to create order: ${response.reasonPhrase}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException('Network error: $e');
    }
  }

  // Helper methods
  String _getOrdersEndpoint(Map<String, dynamic> userInfo) {
    final isDelegue = userInfo['isDelegue'] as bool;
    final region = userInfo['region'] as String?;

    if (isDelegue && region != null) {
      return '/commands/zone/$region';
    }
    return '/commands';
  }

  String _mapStateFilter(String stateFilter) {
    switch (stateFilter) {
      case 'En Attente':
        return 'En Attente';
      case 'Effectué':
        return 'Effectué';
      case 'Rejeté':
        return 'Rejeté';
      case 'Numéro Incorrecte':
        return 'Numéro Incorrecte';
      case 'Problème Solde':
        return 'Problème Solde';
      default:
        return stateFilter;
    }
  }

  PurchaseOrderResponse _applyClientSideFilters(
    PurchaseOrderResponse response, {
    String? searchQuery,
    List<String>? productFilters,
  }) {
    var filteredOrders = response.data;

    // Apply client-side search filter (for client names)
    if (searchQuery != null && searchQuery.isNotEmpty) {
      filteredOrders = filteredOrders.where((order) {
        return order.client.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    // Apply client-side product filtering (for multiple products)
    if (productFilters != null && productFilters.length > 1) {
      filteredOrders = filteredOrders.where((order) {
        return productFilters.contains(order.product);
      }).toList();
    }

    return PurchaseOrderResponse(
      data: filteredOrders,
      totalCount: response.totalCount, // Keep original total count
    );
  }
}
