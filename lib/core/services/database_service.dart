import 'package:safwa/core/database/sqlite_database.dart';

/// Singleton service for accessing the application database.
class DatabaseService {
  DatabaseService._internal();

  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  final _db = SqliteDatabase();

  SqliteDatabase get database => _db;

  void close() {
    _db.close();
  }
}
