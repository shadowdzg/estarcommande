import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/purchase_orders_page_new.dart';
import 'core/service_locator.dart';

/// Simple test app to verify the new architecture works
class TestNewArchitectureApp extends StatelessWidget {
  const TestNewArchitectureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test New Architecture',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const PurchaseOrdersPageNew(),
    );
  }
}

/// Entry point for testing the new architecture
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup dependency injection
  await setupServiceLocator();

  runApp(const ProviderScope(child: TestNewArchitectureApp()));
}
