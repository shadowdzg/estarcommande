// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: (json['id'] as num).toInt(),
  username: json['username'] as String,
  email: json['email'] as String?,
  isAdmin: json['isAdmin'] as bool,
  isSuper: json['isSuper'] as bool,
  isClient: json['isClient'] as bool,
  isDelegue: json['isDelegue'] as bool,
  region: json['region'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'email': instance.email,
  'isAdmin': instance.isAdmin,
  'isSuper': instance.isSuper,
  'isClient': instance.isClient,
  'isDelegue': instance.isDelegue,
  'region': instance.region,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
