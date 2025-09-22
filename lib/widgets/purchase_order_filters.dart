import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/purchase_order_provider.dart' hide PurchaseOrderFilters;
import '../providers/purchase_order_provider.dart' as provider;

class PurchaseOrderFilters extends ConsumerStatefulWidget {
  const PurchaseOrderFilters({super.key});

  @override
  ConsumerState<PurchaseOrderFilters> createState() =>
      _PurchaseOrderFiltersState();
}

class _PurchaseOrderFiltersState extends ConsumerState<PurchaseOrderFilters> {
  final _searchController = TextEditingController();
  String? _selectedState;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Initialize with current filter values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentFilters = ref.read(purchaseOrderFiltersProvider);
      _searchController.text = currentFilters.searchQuery ?? '';
      _selectedState = currentFilters.stateFilter;
      _selectedDateRange = currentFilters.dateRange;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Search field
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by client name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Debounced search
                _debounceSearch(value);
              },
            ),

            const SizedBox(height: 16),

            // State filter dropdown
            DropdownButtonFormField<String>(
              value: _selectedState,
              decoration: const InputDecoration(
                labelText: 'Order Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All Statuses')),
                DropdownMenuItem(
                  value: 'En Attente',
                  child: Text('En Attente'),
                ),
                DropdownMenuItem(value: 'Effectué', child: Text('Effectué')),
                DropdownMenuItem(value: 'Rejeté', child: Text('Rejeté')),
                DropdownMenuItem(
                  value: 'Numéro Incorrecte',
                  child: Text('Numéro Incorrecte'),
                ),
                DropdownMenuItem(
                  value: 'Problème Solde',
                  child: Text('Problème Solde'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedState = value;
                });
                _applyFilters();
              },
            ),

            const SizedBox(height: 16),

            // Date range picker
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _selectedDateRange != null
                          ? '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}'
                          : 'Select Date Range',
                    ),
                  ),
                ),
                if (_selectedDateRange != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedDateRange = null;
                      });
                      _applyFilters();
                    },
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear date range',
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Clear all filters button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _debounceSearch(String query) {
    // Simple debouncing - in a real app you'd use a proper debouncer
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchController.text == query) {
        _applyFilters();
      }
    });
  }

  Future<void> _selectDateRange() async {
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (dateRange != null) {
      setState(() {
        _selectedDateRange = dateRange;
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    ref
        .read(purchaseOrdersProvider.notifier)
        .updateFilters(
          provider.PurchaseOrderFilters(
            searchQuery: _searchController.text.isEmpty
                ? null
                : _searchController.text,
            stateFilter: _selectedState,
            dateRange: _selectedDateRange,
            page: 0, // Reset to first page when filters change
          ),
        );
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _selectedState = null;
      _selectedDateRange = null;
    });
    ref.read(purchaseOrdersProvider.notifier).clearFilters();
  }
}
