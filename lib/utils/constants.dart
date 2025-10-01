class AppConstants {
  // API Configuration
  static const String baseUrl = "http://10.0.2.2:8001"; // Use this for Android Emulator
  // static const String baseUrl = 'http://localhost:8001'; // Use this for iOS Simulator
  // static const String baseUrl = 'http://YOUR_IP:8001'; // Use this for Physical Device

  static const String productsEndpoint = '/products';

  // Tax and Discount
  static const double defaultTaxRate = 0.16; // 16% VAT
  static const double defaultDiscountRate = 0.0;

  // Database
  static const String dbName = 'mpepo_kitchen.db';
  static const int dbVersion = 1;

  // Offline Queue
  static const String offlineQueueTable = 'offline_transactions';
  static const String prefsKeyLastSync = 'last_sync_timestamp';
}
