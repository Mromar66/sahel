import 'package:flutter_test/flutter_test.dart';
import 'package:safwa/core/database/sqlite_database.dart';
import 'package:safwa/features/accounts/data/accounts_repo.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database rawDatabase;
  late SqliteDatabase database;
  late AccountsRepo repository;

  setUp(() {
    rawDatabase = sqlite3.openInMemory();
    rawDatabase.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY,
        balance INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT
      );
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payment_number TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        payment_date TEXT NOT NULL,
        amount INTEGER NOT NULL,
        payment_type TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        description TEXT,
        reference_id INTEGER,
        reference_type TEXT,
        created_at TEXT NOT NULL
      );
      CREATE TABLE account_checks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        direction TEXT NOT NULL,
        amount INTEGER NOT NULL,
        due_date TEXT NOT NULL,
        collected_date TEXT,
        bank TEXT,
        check_number TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        notes TEXT,
        created_at TEXT NOT NULL,
        payment_id INTEGER,
        treasury_id INTEGER
      );
      CREATE TABLE expenses (id INTEGER PRIMARY KEY, payment_id INTEGER);
      CREATE TABLE document_custom_values (
        document_type TEXT,
        document_id INTEGER,
        field_id INTEGER,
        value TEXT,
        updated_at TEXT
      );
      CREATE TABLE treasuries (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        opening_balance INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE treasury_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_number TEXT NOT NULL,
        transaction_date TEXT NOT NULL,
        transaction_time TEXT,
        amount INTEGER NOT NULL,
        transaction_type TEXT NOT NULL,
        description TEXT,
        notes TEXT,
        category TEXT,
        reference_id INTEGER,
        reference_type TEXT,
        balance_after INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        treasury_id INTEGER,
        is_transfer INTEGER NOT NULL DEFAULT 0,
        transfer_group TEXT,
        peer_treasury_id INTEGER
      );
      INSERT INTO accounts(id, balance) VALUES (1, 1000);
      INSERT INTO treasuries(id, name, opening_balance) VALUES (1, 'الخزينة', 500);
    ''');
    database = SqliteDatabase.withDatabase(rawDatabase);
    repository = AccountsRepo.withDatabase(database);
  });

  tearDown(() => rawDatabase.dispose());

  test(
    'cash voucher saves, updates, and deletes all ledgers atomically',
    () async {
      final paymentId = await repository.insertPayment(
        accountId: 1,
        amount: 100,
        isReceipt: true,
        method: 'cash',
        treasuryId: 1,
        date: DateTime(2026, 11, 16),
      );
      expect(
        rawDatabase.select('SELECT balance FROM accounts').first['balance'],
        900,
      );
      expect(
        rawDatabase
            .select('SELECT balance_after FROM treasury_transactions')
            .first['balance_after'],
        600,
      );

      await repository.updatePayment(
        paymentId: paymentId,
        accountId: 1,
        amount: 140,
        isReceipt: true,
        method: 'cash',
        treasuryId: 1,
        date: DateTime(2026, 11, 17),
      );
      expect(
        rawDatabase.select('SELECT balance FROM accounts').first['balance'],
        860,
      );
      expect(
        rawDatabase
            .select('SELECT amount FROM treasury_transactions')
            .first['amount'],
        140,
      );
      expect(
        rawDatabase
            .select('SELECT balance_after FROM treasury_transactions')
            .first['balance_after'],
        640,
      );

      await repository.deletePayment(paymentId);
      expect(
        rawDatabase.select('SELECT balance FROM accounts').first['balance'],
        1000,
      );
      expect(
        rawDatabase.select('SELECT COUNT(*) AS n FROM payments').first['n'],
        0,
      );
      expect(
        rawDatabase
            .select('SELECT COUNT(*) AS n FROM treasury_transactions')
            .first['n'],
        0,
      );
    },
  );

  test('check receipt posts to treasury only once when collected', () async {
    final paymentId = await repository.insertPayment(
      accountId: 1,
      amount: 75,
      isReceipt: true,
      method: 'check',
      treasuryId: 1,
      checkNumber: 'CHK-75',
      date: DateTime(2026, 11, 16),
    );
    expect(
      rawDatabase.select('SELECT balance FROM accounts').first['balance'],
      925,
    );
    expect(
      rawDatabase
          .select('SELECT COUNT(*) AS n FROM treasury_transactions')
          .first['n'],
      0,
    );

    final checkId =
        rawDatabase.select(
              'SELECT id FROM account_checks WHERE payment_id = ?',
              [paymentId],
            ).first['id']
            as int;
    await repository.markCheckCollected(checkId);
    await repository.markCheckCollected(checkId);

    expect(
      rawDatabase.select('SELECT balance FROM accounts').first['balance'],
      925,
    );
    expect(
      rawDatabase
          .select('SELECT COUNT(*) AS n FROM treasury_transactions')
          .first['n'],
      1,
    );
    expect(
      rawDatabase
          .select('SELECT balance_after FROM treasury_transactions')
          .first['balance_after'],
      575,
    );

    await repository.deletePayment(paymentId);
    expect(
      rawDatabase.select('SELECT balance FROM accounts').first['balance'],
      1000,
    );
    expect(
      rawDatabase.select('SELECT COUNT(*) AS n FROM account_checks').first['n'],
      0,
    );
    expect(
      rawDatabase
          .select('SELECT COUNT(*) AS n FROM treasury_transactions')
          .first['n'],
      0,
    );
  });
}
