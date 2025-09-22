import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/service_locator.dart';
import '../models/models.dart';
import '../repositories/purchase_order_repository.dart';

// Purchase Order Repository Provider
final purchaseOrderRepositoryProvider = Provider<PurchaseOrderRepository>((
  ref,
) {
  return sl<PurchaseOrderRepository>();
});

// Purchase Order Filter State
class PurchaseOrderFilters {
  final String? searchQuery;
  final String? stateFilter;
  final List<String>? productFilters;
  final DateTimeRange? dateRange;
  final int page;
  final int pageSize;

  const PurchaseOrderFilters({
    this.searchQuery,
    this.stateFilter,
    this.productFilters,
    this.dateRange,
    this.page = 0,
    this.pageSize = 10,
  });

  PurchaseOrderFilters copyWith({
    String? searchQuery,
    String? stateFilter,
    List<String>? productFilters,
    DateTimeRange? dateRange,
    int? page,
    int? pageSize,
  }) {
    return PurchaseOrderFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      stateFilter: stateFilter ?? this.stateFilter,
      productFilters: productFilters ?? this.productFilters,
      dateRange: dateRange ?? this.dateRange,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PurchaseOrderFilters &&
        other.searchQuery == searchQuery &&
        other.stateFilter == stateFilter &&
        listEquals(other.productFilters, productFilters) &&
        other.dateRange == dateRange &&
        other.page == page &&
        other.pageSize == pageSize;
  }

  @override
  int get hashCode {
    return Object.hash(
      searchQuery,
      stateFilter,
      productFilters,
      dateRange,
      page,
      pageSize,
    );
  }
}

// Purchase Order Filters Provider
final purchaseOrderFiltersProvider = StateProvider<PurchaseOrderFilters>((ref) {
  return const PurchaseOrderFilters();
});

// Purchase Orders AsyncNotifier
class PurchaseOrdersNotifier extends AsyncNotifier<PurchaseOrderResponse> {
  PurchaseOrderRepository get _repository =>
      ref.read(purchaseOrderRepositoryProvider);

  @override
  Future<PurchaseOrderResponse> build() async {
    final filters = ref.watch(purchaseOrderFiltersProvider);
    return await _fetchOrders(filters);
  }

  Future<PurchaseOrderResponse> _fetchOrders(
    PurchaseOrderFilters filters,
  ) async {
    return await _repository.getOrders(
      page: filters.page,
      pageSize: filters.pageSize,
      searchQuery: filters.searchQuery,
      stateFilter: filters.stateFilter,
      productFilters: filters.productFilters,
      dateRange: filters.dateRange,
    );
  }

  // Refresh orders
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final filters = ref.read(purchaseOrderFiltersProvider);

    try {
      final orders = await _fetchOrders(filters);
      state = AsyncValue.data(orders);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  // Update filters and refresh
  Future<void> updateFilters(PurchaseOrderFilters newFilters) async {
    ref.read(purchaseOrderFiltersProvider.notifier).state = newFilters;
    await refresh();
  }

  // Go to specific page
  Future<void> goToPage(int page) async {
    final currentFilters = ref.read(purchaseOrderFiltersProvider);
    final newFilters = currentFilters.copyWith(page: page);
    await updateFilters(newFilters);
  }

  // Update search query
  Future<void> updateSearchQuery(String? query) async {
    final currentFilters = ref.read(purchaseOrderFiltersProvider);
    final newFilters = currentFilters.copyWith(
      searchQuery: query,
      page: 0, // Reset to first page
    );
    await updateFilters(newFilters);
  }

  // Update state filter
  Future<void> updateStateFilter(String? stateFilter) async {
    final currentFilters = ref.read(purchaseOrderFiltersProvider);
    final newFilters = currentFilters.copyWith(
      stateFilter: stateFilter,
      page: 0, // Reset to first page
    );
    await updateFilters(newFilters);
  }

  // Update product filters
  Future<void> updateProductFilters(List<String>? productFilters) async {
    final currentFilters = ref.read(purchaseOrderFiltersProvider);
    final newFilters = currentFilters.copyWith(
      productFilters: productFilters,
      page: 0, // Reset to first page
    );
    await updateFilters(newFilters);
  }

  // Update date range
  Future<void> updateDateRange(DateTimeRange? dateRange) async {
    final currentFilters = ref.read(purchaseOrderFiltersProvider);
    final newFilters = currentFilters.copyWith(
      dateRange: dateRange,
      page: 0, // Reset to first page
    );
    await updateFilters(newFilters);
  }

  // Clear all filters
  Future<void> clearFilters() async {
    await updateFilters(const PurchaseOrderFilters());
  }

  // Update order
  Future<void> updateOrder(int orderId, Map<String, dynamic> updates) async {
    try {
      await _repository.updateOrder(orderId, updates);
      await refresh(); // Refresh the list after update
    } catch (error) {
      // Handle error - could emit error state or show notification
      rethrow;
    }
  }

  // Accept order with optimistic update
  Future<void> acceptOrder(int orderId) async {
    // Optimistic update: Update UI immediately
    _updateOrderStateOptimistically(orderId, 'Effectué');

    try {
      await _repository.acceptOrder(orderId);
      // Success: The optimistic update was correct, no need to refresh
    } catch (error) {
      // Error: Revert the optimistic update
      await refresh();
      rethrow;
    }
  }

  // Reject order with optimistic update
  Future<void> rejectOrder(int orderId) async {
    // Optimistic update: Update UI immediately
    _updateOrderStateOptimistically(orderId, 'Rejeté');

    try {
      await _repository.rejectOrder(orderId);
      // Success: The optimistic update was correct, no need to refresh
    } catch (error) {
      // Error: Revert the optimistic update
      await refresh();
      rethrow;
    }
  }

  // Helper method for optimistic updates
  void _updateOrderStateOptimistically(int orderId, String newState) {
    state.whenData((response) {
      final updatedOrders = response.data.map((order) {
        if (order.id == orderId) {
          return order.copyWith(state: newState);
        }
        return order;
      }).toList();

      final updatedResponse = PurchaseOrderResponse(
        data: updatedOrders,
        totalCount: response.totalCount,
      );

      state = AsyncValue.data(updatedResponse);
    });
  }

  // Create order
  Future<void> createOrder(Map<String, dynamic> orderData) async {
    try {
      await _repository.createOrder(orderData);
      await refresh(); // Refresh the list after creation
    } catch (error) {
      rethrow;
    }
  }
}

// Purchase Orders Provider
final purchaseOrdersProvider =
    AsyncNotifierProvider<PurchaseOrdersNotifier, PurchaseOrderResponse>(() {
      return PurchaseOrdersNotifier();
    });

// Loading state provider for pagination
final paginationLoadingProvider = StateProvider<bool>((ref) => false);

// Helper provider for current page orders
final currentPageOrdersProvider = Provider<List<PurchaseOrder>>((ref) {
  final ordersAsync = ref.watch(purchaseOrdersProvider);
  return ordersAsync.when(
    data: (response) => response.data,
    loading: () => [],
    error: (_, __) => [],
  );
});

// Helper provider for total count
final totalOrdersCountProvider = Provider<int>((ref) {
  final ordersAsync = ref.watch(purchaseOrdersProvider);
  return ordersAsync.when(
    data: (response) => response.totalCount,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// Helper provider for total pages
final totalPagesProvider = Provider<int>((ref) {
  final totalCount = ref.watch(totalOrdersCountProvider);
  final filters = ref.watch(purchaseOrderFiltersProvider);
  return (totalCount / filters.pageSize).ceil();
});

// Helper provider for current page number
final currentPageProvider = Provider<int>((ref) {
  final filters = ref.watch(purchaseOrderFiltersProvider);
  return filters.page;
});
