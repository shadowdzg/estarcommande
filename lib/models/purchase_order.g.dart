// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PurchaseOrder _$PurchaseOrderFromJson(Map<String, dynamic> json) =>
    PurchaseOrder(
      id: (json['id'] as num).toInt(),
      client: json['client'] as String,
      product: json['product'] as String,
      quantity: (json['quantity'] as num).toInt(),
      pricePercent: (json['prixPercent'] as num).toDouble(),
      state: json['state'] as String,
      name: json['name'] as String,
      number: json['number'] as String,
      accepted: json['accepted'] as String,
      acceptedBy: json['acceptedBy'] as String,
      date: DateTime.parse(json['date'] as String),
      operator: json['operator'] as String?,
      amount: (json['amount'] as num?)?.toInt(),
      pourcentage: json['pourcentage'] as String?,
      isValidated: json['isValidated'] as String?,
      createdAt: json['createdAt'] as String?,
      clients: json['clients'] as Map<String, dynamic>?,
      users: json['users'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$PurchaseOrderToJson(PurchaseOrder instance) =>
    <String, dynamic>{
      'id': instance.id,
      'client': instance.client,
      'product': instance.product,
      'quantity': instance.quantity,
      'prixPercent': instance.pricePercent,
      'state': instance.state,
      'name': instance.name,
      'number': instance.number,
      'accepted': instance.accepted,
      'acceptedBy': instance.acceptedBy,
      'date': instance.date.toIso8601String(),
      'operator': instance.operator,
      'amount': instance.amount,
      'pourcentage': instance.pourcentage,
      'isValidated': instance.isValidated,
      'createdAt': instance.createdAt,
      'clients': instance.clients,
      'users': instance.users,
    };

PurchaseOrderResponse _$PurchaseOrderResponseFromJson(
  Map<String, dynamic> json,
) => PurchaseOrderResponse(
  data: (json['data'] as List<dynamic>)
      .map((e) => PurchaseOrder.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalCount: (json['totalCount'] as num).toInt(),
);

Map<String, dynamic> _$PurchaseOrderResponseToJson(
  PurchaseOrderResponse instance,
) => <String, dynamic>{
  'data': instance.data,
  'totalCount': instance.totalCount,
};
