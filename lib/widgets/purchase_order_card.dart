import 'package:flutter/material.dart';
import '../models/models.dart';

class PurchaseOrderCard extends StatefulWidget {
  final PurchaseOrder order;
  final Function(PurchaseOrder)? onEdit;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const PurchaseOrderCard({
    super.key,
    required this.order,
    this.onEdit,
    this.onAccept,
    this.onReject,
  });

  @override
  State<PurchaseOrderCard> createState() => _PurchaseOrderCardState();
}

class _PurchaseOrderCardState extends State<PurchaseOrderCard> {
  bool _isAccepting = false;
  bool _isRejecting = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.order.client,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.order.product} - ${widget.order.quantity}x',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(widget.order.state),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.order.state,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Number', widget.order.number),
                      _buildInfoRow(
                        'Price',
                        '${widget.order.calculatedPrice.toStringAsFixed(2)} DA',
                      ),
                      _buildInfoRow('Created by', widget.order.name),
                    ],
                  ),
                ),
                if (widget.onAccept != null ||
                    widget.onReject != null ||
                    widget.onEdit != null)
                  Column(
                    children: [
                      if (widget.onAccept != null)
                        IconButton(
                          icon: _isAccepting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.green,
                                  ),
                                )
                              : const Icon(Icons.check, color: Colors.green),
                          onPressed: _isAccepting ? null : _handleAccept,
                          tooltip: 'Accept',
                        ),
                      if (widget.onReject != null)
                        IconButton(
                          icon: _isRejecting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.red,
                                  ),
                                )
                              : const Icon(Icons.close, color: Colors.red),
                          onPressed: _isRejecting ? null : _handleReject,
                          tooltip: 'Reject',
                        ),
                      if (widget.onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => widget.onEdit!(widget.order),
                          tooltip: 'Edit',
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAccept() async {
    if (widget.onAccept == null) return;

    setState(() {
      _isAccepting = true;
    });

    try {
      widget.onAccept!();
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
        });
      }
    }
  }

  Future<void> _handleReject() async {
    if (widget.onReject == null) return;

    setState(() {
      _isRejecting = true;
    });

    try {
      widget.onReject!();
    } finally {
      if (mounted) {
        setState(() {
          _isRejecting = false;
        });
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'en attente':
        return Colors.orange;
      case 'effectué':
        return Colors.green;
      case 'rejeté':
        return Colors.red;
      case 'numéro incorrecte':
        return Colors.purple;
      case 'problème solde':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}
