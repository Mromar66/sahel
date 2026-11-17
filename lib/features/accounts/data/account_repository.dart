import 'package:inventory_app/core/database/sqlite_database.dart';
import 'package:inventory_app/features/accounts/domain/account_entity.dart';

class AccountRepository {
  AccountRepository._internal();
  static final AccountRepository _instance = AccountRepository._internal();
  factory AccountRepository() => _instance;

  final _db = SqliteDatabase();

  Future<List<AccountEntity>> getAllAccounts() async {
    final rows = _db.query('SELECT * FROM accounts WHERE is_active = 1');
    return rows.map((r) => _rowToAccount(r)).toList();
  }

  Future<AccountEntity?> getAccountById(int id) async {
    final rows = _db.query('SELECT * FROM accounts WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _rowToAccount(rows.first);
  }

  Future<int> insertAccount(AccountEntity account) async {
    return _db.insert(
      '''INSERT INTO accounts (name, account_type, balance, description, is_active, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)''',
      [
        account.name,
        account.accountType,
        account.balance,
        account.description,
        account.isActive ? 1 : 0,
        account.createdAt?.toIso8601String(),
        account.updatedAt?.toIso8601String(),
      ],
    );
  }

  Future<void> updateAccount(AccountEntity account) async {
    _db.execute(
      '''UPDATE accounts SET name = ?, account_type = ?, balance = ?, description = ?, is_active = ?, updated_at = ? WHERE id = ?''',
      [
        account.name,
        account.accountType,
        account.balance,
        account.description,
        account.isActive ? 1 : 0,
        account.updatedAt?.toIso8601String(),
        account.id,
      ],
    );
  }

  Future<void> deleteAccount(int id) async {
    _db.execute('UPDATE accounts SET is_active = 0 WHERE id = ?', [id]);
  }

  Future<void> updateBalance(int id, int newBalance) async {
    _db.execute(
      'UPDATE accounts SET balance = ?, updated_at = ? WHERE id = ?',
      [newBalance, DateTime.now().toIso8601String(), id],
    );
  }

  AccountEntity _rowToAccount(Map<String, dynamic> r) {
    return AccountEntity(
      id: r['id'] as int?,
      name: r['name'] as String? ?? '',
      accountType: r['account_type'] as String? ?? '',
      balance: r['balance'] as int? ?? 0,
      description: r['description'] as String?,
      isActive: (r['is_active'] as int? ?? 1) == 1,
      createdAt: r['created_at'] != null
          ? DateTime.parse(r['created_at'])
          : null,
      updatedAt: r['updated_at'] != null
          ? DateTime.parse(r['updated_at'])
          : null,
    );
  }
}
