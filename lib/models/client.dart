import 'package:json_annotation/json_annotation.dart';

part 'client.g.dart';

@JsonSerializable()
class Client {
  final int? id;
  @JsonKey(name: 'clientName')
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Client({
    this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.createdAt,
    this.updatedAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) => _$ClientFromJson(json);

  Map<String, dynamic> toJson() => _$ClientToJson(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Client && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Client(id: $id, name: $name)';
}

