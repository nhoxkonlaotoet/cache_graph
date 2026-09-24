import 'package:sqflite/sqflite.dart';

/// Connection owned exclusively by the API-cache module.
class ApiCacheDatabase {
  ApiCacheDatabase._();

  static Database? _database;

  static Database? get database => _database;
  static bool get isAvailable => _database != null;

  static void attach(Database database) {
    _database = database;
  }

  static Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }
}
