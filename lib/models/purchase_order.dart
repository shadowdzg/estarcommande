import 'package:flutter/material.dart' show DateTimeRange;
import 'package:json_annotation/json_annotation.dart';

part 'purchase_order.g.dart';

@JsonSerializable()
class PurchaseOrder {
  final int id;
  final String client;
  final String product;
  final int quantity;
  @JsonKey(name: 'prixPercent')
  final double pricePercent;
  final String state;
  final String name;
  final String number;
  final String accepted;
  @JsonKey(name: 'acceptedBy')
  final String acceptedBy;
  final DateTime date;

  // Raw API fields for mapping
  @JsonKey(name: 'operator')
  final String? operator;
  @JsonKey(name: 'amount')
  final int? amount;
  @JsonKey(name: 'pourcentage')
  final String? pourcentage;
  @JsonKey(name: 'isValidated')
  final String? isValidated;
  @JsonKey(name: 'createdAt')
  final String? createdAt;
  @JsonKey(name: 'clients')
  final Map<String, dynamic>? clients;
  @JsonKey(name: 'users')
  final Map<String, dynamic>? users;

  const PurchaseOrder({
    required this.id,
    required this.client,
    required this.product,
    required this.quantity,
    required this.pricePercent,
    required this.state,
    required this.name,
    required this.number,
    required this.accepted,
    required this.acceptedBy,
    required this.date,
    this.operator,
    this.amount,
    this.pourcentage,
    this.isValidated,
    this.createdAt,
    this.clients,
    this.users,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    // Extract client name from different possible structures
    String clientName = 'Unknown';
    if (json['clients'] != null && json['clients'] is Map) {
      clientName = json['clients']['clientName'] ?? 'Unknown';
    } else if (json['client'] != null) {
      if (json['client'] is Map) {
        clientName = json['client']['clientName'] ?? 'Unknown';
      } else if (json['client'] is String) {
        clientName = json['client'];
      }
    }

    // Parse price percentage
    double pricePercent = 0.0;
    if (json['pourcentage'] != null) {
      pricePercent =
          double.tryParse(json['pourcentage'].toString().replaceAll('%', '')) ??
          0.0;
    }

    // Parse date
    DateTime parsedDate = DateTime.now();
    if (json['createdAt'] != null) {
      parsedDate = DateTime.tryParse(json['createdAt']) ?? DateTime.now();
    }

    return PurchaseOrder(
      id: json['id'] ?? 0,
      client: clientName,
      product: json['operator'] ?? 'Unknown',
      quantity: json['amount'] ?? 0,
      pricePercent: pricePercent,
      state: json['isValidated'] ?? 'En Attente',
      name: json['users']?['username'] ?? 'Unknown',
      number: json['number'] ?? 'Unknown',
      accepted: json['accepted'] ?? 'Unknown',
      acceptedBy: json['acceptedBy'] ?? '',
      date: parsedDate,
      operator: json['operator'],
      amount: json['amount'],
      pourcentage: json['pourcentage'],
      isValidated: json['isValidated'],
      createdAt: json['createdAt'],
      clients: json['clients'],
      users: json['users'],
    );
  }

  Map<String, dynamic> toJson() => _$PurchaseOrderToJson(this);

  // Calculated price based on percentage
  double get calculatedPrice {
    return 10000 - (pricePercent / 100 * 10000);
  }

  // Copy with method for updates
  PurchaseOrder copyWith({
    int? id,
    String? client,
    String? product,
    int? quantity,
    double? pricePercent,
    String? state,
    String? name,
    String? number,
    String? accepted,
    String? acceptedBy,
    DateTime? date,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      client: client ?? this.client,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      pricePercent: pricePercent ?? this.pricePercent,
      state: state ?? this.state,
      name: name ?? this.name,
      number: number ?? this.number,
      accepted: accepted ?? this.accepted,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      date: date ?? this.date,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PurchaseOrder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PurchaseOrder(id: $id, client: $client, product: $product, quantity: $quantity)';
  }
}

@JsonSerializable()
class PurchaseOrderResponse {
  final List<PurchaseOrder> data;
  @JsonKey(name: 'totalCount')
  final int totalCount;

  const PurchaseOrderResponse({required this.data, required this.totalCount});

  factory PurchaseOrderResponse.fromJson(Map<String, dynamic> json) {
    final ordersList = (json['data'] ?? []) as List<dynamic>;
    final orders = ordersList
        .map((item) => PurchaseOrder.fromJson(item as Map<String, dynamic>))
        .toList();

    return PurchaseOrderResponse(
      data: orders,
      totalCount: json['totalCount'] ?? orders.length,
    );
  }

  Map<String, dynamic> toJson() => _$PurchaseOrderResponseToJson(this);
}
