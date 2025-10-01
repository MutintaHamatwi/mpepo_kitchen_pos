import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'screens/product_list_screen.dart';
import 'screens/newproduct.dart'; // <-- NEW: Import the screen for adding products
import 'services/offline_queue_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Start automatic sync for offline transactions
  OfflineQueueService().startAutoSync();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'Mpepo Kitchen POS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.orange,
          useMaterial3: true,
        ),
        // Replace 'home' with 'initialRoute' and define all routes
        initialRoute: '/',
        routes: {
          '/': (context) => const ProductListScreen(),
          '/new-product': (context) => const NewProductScreen(), // <-- NEW ROUTE
        },
      ),
    );
  }
}

