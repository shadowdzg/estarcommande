import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@JsonSerializable()
class Product {
  @JsonKey(name: 'productID')
  final String? id;
  @JsonKey(name: 'productName')
  final String name;
  final String? description;
  @JsonKey(name: 'initialPrice')
  final double? initialPrice;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Product({
    this.id,
    required this.name,
    this.description,
    this.initialPrice,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  Map<String, dynamic> toJson() => _$ProductToJson(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Product(id: $id, name: $name)';
}

