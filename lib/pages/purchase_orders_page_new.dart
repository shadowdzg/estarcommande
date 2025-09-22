import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../providers/purchase_order_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/purchase_order_card.dart';
import '../widgets/purchase_order_filters.dart' as filters;
import '../widgets/pagination_controls.dart';
import '../widgets/edit_order_dialog.dart';

class PurchaseOrdersPageNew extends ConsumerWidget {
  const PurchaseOrdersPageNew({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch authentication state
    final authAsync = ref.watch(authStatusProvider);
    final hasAdminAccess = ref.watch(hasAdminAccessProvider);

    return authAsync.when(
      data: (isAuthenticated) {
        if (!isAuthenticated) {
          // Redirect to login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/login');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
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
          ),
          body: Column(
            children: [
              // Filters section
              filters.PurchaseOrderFilters(),

              // Orders list
              Expanded(child: PurchaseOrdersList()),

              // Pagination controls
              PaginationControls(),
            ],
          ),
          floatingActionButton: hasAdminAccess.when(
            data: (hasAccess) => hasAccess
                ? FloatingActionButton(
                    onPressed: () => _showAddOrderDialog(context, ref),
                    child: const Icon(Icons.add),
                  )
                : null,
            loading: () => null,
            error: (_, __) => null,
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              ElevatedButton(
                onPressed: () => ref.refresh(authStatusProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddOrderDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Order'),
        content: const Text('Add order form would go here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Create order using provider
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class PurchaseOrdersList extends ConsumerWidget {
  const PurchaseOrdersList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(purchaseOrdersProvider);

    return ordersAsync.when(
      data: (response) {
        if (response.data.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No orders found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(purchaseOrdersProvider.notifier).refresh();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: response.data.length,
            itemBuilder: (context, index) {
              final order = response.data[index];
              return PurchaseOrderCard(
                key: ValueKey(order.id),
                order: order,
                onEdit: (orderToEdit) => _showEditDialog(context, orderToEdit),
                onAccept: () => _showConfirmationDialog(
                  context,
                  'Accept Order',
                  'Are you sure you want to accept this order?',
                  () => _handleOrderAccept(ref, order.id),
                ),
                onReject: () => _showConfirmationDialog(
                  context,
                  'Reject Order',
                  'Are you sure you want to reject this order?',
                  () => _handleOrderReject(ref, order.id),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading orders: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(purchaseOrdersProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, PurchaseOrder order) {
    showDialog(
      context: context,
      builder: (context) => EditOrderDialog(order: order),
    );
  }

  void _showConfirmationDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleOrderAccept(WidgetRef ref, int orderId) async {
    try {
      await ref.read(purchaseOrdersProvider.notifier).acceptOrder(orderId);
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          const SnackBar(
            content: Text('Order accepted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleOrderReject(WidgetRef ref, int orderId) async {
    try {
      await ref.read(purchaseOrdersProvider.notifier).rejectOrder(orderId);
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          const SnackBar(
            content: Text('Order rejected successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
