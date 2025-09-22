import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/purchase_order_provider.dart';

class EditOrderDialog extends ConsumerStatefulWidget {
  final PurchaseOrder order;

  const EditOrderDialog({super.key, required this.order});

  @override
  ConsumerState<EditOrderDialog> createState() => _EditOrderDialogState();
}

class _EditOrderDialogState extends ConsumerState<EditOrderDialog> {
  late final TextEditingController _clientController;
  late final TextEditingController _productController;
  late final TextEditingController _quantityController;
  late final TextEditingController _pricePercentController;
  late final TextEditingController _numberController;
  late final TextEditingController _nameController;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _clientController = TextEditingController(text: widget.order.client);
    _productController = TextEditingController(text: widget.order.product);
    _quantityController = TextEditingController(
      text: widget.order.quantity.toString(),
    );
    _pricePercentController = TextEditingController(
      text: widget.order.pricePercent.toString(),
    );
    _numberController = TextEditingController(text: widget.order.number);
    _nameController = TextEditingController(text: widget.order.name);
  }

  @override
  void dispose() {
    _clientController.dispose();
    _productController.dispose();
    _quantityController.dispose();
    _pricePercentController.dispose();
    _numberController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Order #${widget.order.id}'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Client field
                TextFormField(
                  controller: _clientController,
                  decoration: const InputDecoration(
                    labelText: 'Client Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter client name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Product field
                TextFormField(
                  controller: _productController,
                  decoration: const InputDecoration(
                    labelText: 'Product',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter product name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Quantity field
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter quantity';
                    }
                    final quantity = int.tryParse(value);
                    if (quantity == null || quantity <= 0) {
                      return 'Please enter a valid quantity';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Price percent field
                TextFormField(
                  controller: _pricePercentController,
                  decoration: const InputDecoration(
                    labelText: 'Price Percentage (%)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter price percentage';
                    }
                    final percent = double.tryParse(value);
                    if (percent == null || percent < 0 || percent > 100) {
                      return 'Please enter a valid percentage (0-100)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Number field
                TextFormField(
                  controller: _numberController,
                  decoration: const InputDecoration(
                    labelText: 'Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Created by field (read-only)
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Created By',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveOrder,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create updated order data
      final updatedOrderData = {
        'client': _clientController.text,
        'product': _productController.text,
        'quantity': int.parse(_quantityController.text),
        'prixPercent': double.parse(_pricePercentController.text),
        'number': _numberController.text,
        'name': _nameController.text,
      };

      // Update order through provider
      await ref
          .read(purchaseOrdersProvider.notifier)
          .updateOrder(widget.order.id, updatedOrderData);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
