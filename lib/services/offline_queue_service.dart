import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/transaction.dart';
import '../utils/constants.dart';
import 'api_service.dart';

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  Database? _database;
  final ApiService _apiService = ApiService();

  // Initialize database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE ${AppConstants.offlineQueueTable} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id TEXT,
            items TEXT,
            subtotal REAL,
            tax REAL,
            discount REAL,
            total REAL,
            timestamp TEXT,
            is_synced INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  // Add transaction to offline queue
  Future<int> addToQueue(Transaction transaction) async {
    final db = await database;
    return await db.insert(
      AppConstants.offlineQueueTable,
      {
        'transaction_id': transaction.id,
        'items': transaction.items.toString(),
        'subtotal': transaction.subtotal,
        'tax': transaction.tax,
        'discount': transaction.discount,
        'total': transaction.total,
        'timestamp': transaction.timestamp.toIso8601String(),
        'is_synced': 0,
      },
    );
  }

  // Get all unsynced transactions
  Future<List<Map<String, dynamic>>> getUnsyncedTransactions() async {
    final db = await database;
    return await db.query(
      AppConstants.offlineQueueTable,
      where: 'is_synced = ?',
      whereArgs: [0],
    );
  }

  // Mark transaction as synced
  Future<int> markAsSynced(int id) async {
    final db = await database;
    return await db.update(
      AppConstants.offlineQueueTable,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Check connectivity and sync
  Future<void> syncTransactions() async {
    final connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      print('No internet connection. Skipping sync.');
      return;
    }

    final unsyncedTransactions = await getUnsyncedTransactions();

    for (var transaction in unsyncedTransactions) {
      try {
        final success = await _apiService.submitTransaction({
          'items': transaction['items'],
          'subtotal': transaction['subtotal'],
          'tax': transaction['tax'],
          'discount': transaction['discount'],
          'total': transaction['total'],
          'timestamp': transaction['timestamp'],
        });

        if (success) {
          await markAsSynced(transaction['id'] as int);
          print('Transaction ${transaction['id']} synced successfully');
        }
      } catch (e) {
        print('Error syncing transaction ${transaction['id']}: $e');
      }
    }
  }

  // Automatic retry mechanism - call this periodically
  Future<void> startAutoSync() async {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        syncTransactions();
      }
    });
  }

  // Get queue count
  Future<int> getQueueCount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${AppConstants.offlineQueueTable} WHERE is_synced = 0'
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
