import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final int id;
  final String username;
  final String? email;
  final bool isAdmin;
  final bool isSuper;
  final bool isClient;
  final bool isDelegue;
  final String? region;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.username,
    this.email,
    required this.isAdmin,
    required this.isSuper,
    required this.isClient,
    required this.isDelegue,
    this.region,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);

  // Helper methods for role checking
  bool get hasAdminAccess => isAdmin || isSuper;
  bool get canManageOrders => isAdmin || isSuper;
  bool get canViewAllOrders => isAdmin || isSuper || isDelegue;

  UserRole get role {
    if (isAdmin) return UserRole.admin;
    if (isSuper) return UserRole.superuser;
    if (isDelegue) return UserRole.delegue;
    if (isClient) return UserRole.client;
    return UserRole.user;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum UserRole { admin, superuser, delegue, client, user }

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.superuser:
        return 'Super User';
      case UserRole.delegue:
        return 'Delegate';
      case UserRole.client:
        return 'Client';
      case UserRole.user:
        return 'User';
    }
  }

  bool get canManageUsers =>
      this == UserRole.admin || this == UserRole.superuser;
  bool get canViewReports => this != UserRole.user;
}

