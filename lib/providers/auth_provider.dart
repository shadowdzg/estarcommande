import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/service_locator.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return sl<AuthService>();
});

// Current User Provider
final currentUserProvider = FutureProvider<User?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getCurrentUser();
});

// Authentication Status Provider
final authStatusProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.isAuthenticated();
});

// User Role Providers
final isAdminProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.isAdmin();
});

final isSuperProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.isSuper();
});

final isClientProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.isClient();
});

final isDelegueProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.isDelegue();
});

final hasAdminAccessProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.hasAdminAccess();
});

// User Region Provider
final userRegionProvider = FutureProvider<String?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getUserRegion();
});

// Combined User Info Provider (for caching)
final userInfoProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getCachedUserInfo();
});

