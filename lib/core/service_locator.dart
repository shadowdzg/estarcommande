import 'package:get_it/get_it.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/purchase_order_service.dart';
import '../repositories/purchase_order_repository.dart';

final GetIt sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Core services
  sl.registerLazySingleton<ApiClient>(() => ApiClient());
  sl.registerLazySingleton<AuthService>(() => AuthService());

  // Business logic services
  sl.registerLazySingleton<PurchaseOrderService>(
    () => PurchaseOrderService(sl<ApiClient>(), sl<AuthService>()),
  );

  // Repositories
  sl.registerLazySingleton<PurchaseOrderRepository>(
    () => PurchaseOrderRepositoryImpl(sl<PurchaseOrderService>()),
  );

  // Initialize API client
  await sl<ApiClient>().initialize();
}

