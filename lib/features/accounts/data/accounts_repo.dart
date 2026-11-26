import 'package:safwa/core/database/sqlite_database.dart';
import 'package:safwa/core/services/document_custom_fields.dart';
import 'package:safwa/features/accounts/domain/account_record.dart';

/// Data access for the accounts module (list, form, statements, checks).
class AccountsRepo {
  AccountsRepo._internal() : _db = SqliteDatabase();

  AccountsRepo.withDatabase(SqliteDatabase database) : _db = database;

  static final AccountsRepo _instance = AccountsRepo._internal();
  factory AccountsRepo() => _instance;

  final SqliteDatabase _db;

  // ---------------------------------------------------------------------------
  // Lookups.
  // ---------------------------------------------------------------------------
  List<Map<String, dynamic>> categories() {
    return _db.query('SELECT id, name FROM categories ORDER BY name');
  }

  // ---------------------------------------------------------------------------
  // Accounts.
  // ---------------------------------------------------------------------------
  List<AccountRecord> fetchAccounts() {
    final rows = _db.query('''
      SELECT a.*, c.name AS category_name
      FROM accounts a
      LEFT JOIN categories c ON c.id = a.category_id
      ORDER BY a.id
    ''');
    final checkTotals = _checkTotalsByAccount();
    return rows.map((r) {
      final id = r['id'] as int;
      final totals = checkTotals[id] ?? const [0, 0];
      return _rowToAccount(r, checksDebit: totals[0], checksCredit: totals[1]);
    }).toList();
  }

  Map<int, List<int>> _checkTotalsByAccount() {
    final result = <int, List<int>>{};
    final rows = _db.query('''
      SELECT account_id,
             SUM(CASE WHEN status <> 'collected' AND direction = 'in' THEN amount ELSE 0 END) AS debit,
             SUM(CASE WHEN status <> 'collected' AND direction = 'out' THEN amount ELSE 0 END) AS credit
      FROM account_checks
      GROUP BY account_id
    ''');
    for (final r in rows) {
      result[r['account_id'] as int] = [
        (r['debit'] as int?) ?? 0,
        (r['credit'] as int?) ?? 0,
      ];
    }
    return result;
  }

  AccountRecord? accountById(int id) {
    final rows = _db.query(
      '''
      SELECT a.*, c.name AS category_name
      FROM accounts a
      LEFT JOIN categories c ON c.id = a.category_id
      WHERE a.id = ?
    ''',
      [id],
    );
    if (rows.isEmpty) return null;
    return _rowToAccount(rows.first);
  }

  int insertAccount(AccountRecord a) {
    return _db.insert(
      '''
      INSERT INTO accounts
        (name, account_type, balance, description, is_active, created_at, updated_at,
         account_code, tax_number, category_id, phone, email, address,
         opening_balance, balance_date, discount_percent, default_price, max_debt,
         notes, under_review)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        a.name,
        a.kind,
        a.balance,
        a.notes.isEmpty ? null : a.notes,
        a.isActive ? 1 : 0,
        (a.createdAt ?? DateTime.now()).toIso8601String(),
        DateTime.now().toIso8601String(),
        a.code.isEmpty ? null : a.code,
        a.taxNumber.isEmpty ? null : a.taxNumber,
        a.categoryId,
        a.phone.isEmpty ? null : a.phone,
        a.email.isEmpty ? null : a.email,
        a.address.isEmpty ? null : a.address,
        a.openingBalance,
        a.balanceDate?.toIso8601String(),
        a.discountPercent,
        a.defaultPrice,
        a.maxDebt,
        a.notes.isEmpty ? null : a.notes,
        a.underReview ? 1 : 0,
      ],
    );
  }

  void updateAccount(AccountRecord a) {
    _db.execute(
      '''
      UPDATE accounts SET
        name = ?, account_type = ?, balance = ?, description = ?, is_active = ?,
        updated_at = ?, account_code = ?, tax_number = ?, category_id = ?,
        phone = ?, email = ?, address = ?, opening_balance = ?, balance_date = ?,
        discount_percent = ?, default_price = ?, max_debt = ?, notes = ?,
        under_review = ?
      WHERE id = ?
    ''',
      [
        a.name,
        a.kind,
        a.balance,
        a.notes.isEmpty ? null : a.notes,
        a.isActive ? 1 : 0,
        DateTime.now().toIso8601String(),
        a.code.isEmpty ? null : a.code,
        a.taxNumber.isEmpty ? null : a.taxNumber,
        a.categoryId,
        a.phone.isEmpty ? null : a.phone,
        a.email.isEmpty ? null : a.email,
        a.address.isEmpty ? null : a.address,
        a.openingBalance,
        a.balanceDate?.toIso8601String(),
        a.discountPercent,
        a.defaultPrice,
        a.maxDebt,
        a.notes.isEmpty ? null : a.notes,
        a.underReview ? 1 : 0,
        a.id,
      ],
    );
  }

  void softDeleteAccount(int id) {
    _db.execute(
      'UPDATE accounts SET is_active = 0, updated_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }

  AccountRecord _rowToAccount(
    Map<String, dynamic> r, {
    int checksDebit = 0,
    int checksCredit = 0,
  }) {
    DateTime? parse(Object? value) {
      if (value == null) return null;
      return DateTime.tryParse(value as String);
    }

    return AccountRecord(
      id: r['id'] as int?,
      name: (r['name'] as String?) ?? '',
      kind: (r['account_type'] as String?) ?? 'customer',
      code: (r['account_code'] as String?) ?? '',
      taxNumber: (r['tax_number'] as String?) ?? '',
      categoryId: r['category_id'] as int?,
      categoryName: (r['category_name'] as String?) ?? '',
      phone: (r['phone'] as String?) ?? '',
      email: (r['email'] as String?) ?? '',
      address: (r['address'] as String?) ?? '',
      openingBalance: (r['opening_balance'] as int?) ?? 0,
      balance: (r['balance'] as int?) ?? 0,
      balanceDate: parse(r['balance_date']),
      discountPercent: (r['discount_percent'] as int?) ?? 0,
      defaultPrice: (r['default_price'] as int?) ?? 0,
      maxDebt: (r['max_debt'] as int?) ?? 0,
      notes: (r['notes'] as String?) ?? '',
      underReview: ((r['under_review'] as int?) ?? 0) == 1,
      isActive: ((r['is_active'] as int?) ?? 1) == 1,
      createdAt: parse(r['created_at']),
      updatedAt: parse(r['updated_at']),
      checksDebit: checksDebit,
      checksCredit: checksCredit,
    );
  }

  // ---------------------------------------------------------------------------
  // Movements (payments ledger) used by كشف حساب.
  // ---------------------------------------------------------------------------
  List<AccountMovement> movements(int accountId) {
    final rows = _db.query(
      'SELECT * FROM payments WHERE account_id = ? ORDER BY payment_date, id',
      [accountId],
    );
    var running = 0;
    final result = <AccountMovement>[];
    for (final r in rows) {
      final raw =
          DateTime.tryParse((r['payment_date'] as String?) ?? '') ??
          DateTime.now();
      final amount = (r['amount'] as int?) ?? 0;
      final isReceipt =
          ((r['payment_type'] as String?) ?? 'receipt') == 'receipt';
      running += isReceipt ? amount : -amount;
      result.add(
        AccountMovement(
          date: raw,
          time: _time(raw),
          label: isReceipt ? 'قبض' : 'صرف',
          debit: isReceipt ? amount : 0,
          credit: isReceipt ? 0 : amount,
          balanceAfter: running,
          number: (r['payment_number'] as String?) ?? '',
          notes: (r['description'] as String?) ?? '',
        ),
      );
    }
    return result;
  }

  Future<int> insertPayment({
    required int accountId,
    required int amount,
    required bool isReceipt,
    required String method,
    int? treasuryId,
    String checkNumber = '',
    String description = '',
    DateTime? date,
    Map<int, String> customFields = const {},
  }) {
    final number = '${isReceipt ? 'RCV' : 'PAY'}-${_stamp()}';
    final type = isReceipt ? 'receipt' : 'payment';
    final stamp = (date ?? DateTime.now()).toIso8601String();
    return _db.transaction(() async {
      if (amount <= 0) throw Exception('أدخل مبلغاً أكبر من صفر.');
      final isCheck = method == 'check';
      final selectedTreasury = _requireTreasury(treasuryId);
      final id = _db.insert(
        '''
        INSERT INTO payments
          (payment_number, account_id, payment_date, amount, payment_type,
           payment_method, description, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
        [
          number,
          accountId,
          stamp,
          amount,
          type,
          method,
          description.isEmpty ? null : description,
          DateTime.now().toIso8601String(),
        ],
      );
      _db.execute(
        'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
        [
          isReceipt ? -amount : amount,
          DateTime.now().toIso8601String(),
          accountId,
        ],
      );
      if (isCheck) {
        _insertPaymentCheck(
          paymentId: id,
          accountId: accountId,
          amount: amount,
          isReceipt: isReceipt,
          date: DateTime.tryParse(stamp) ?? DateTime.now(),
          checkNumber: checkNumber.isEmpty ? number : checkNumber,
          description: description,
          treasuryId: selectedTreasury,
        );
      } else {
        _upsertTreasuryMovement(
          paymentId: id,
          isReceipt: isReceipt,
          amount: amount,
          date: DateTime.tryParse(stamp) ?? DateTime.now(),
          treasuryId: selectedTreasury,
          description: description,
        );
      }
      _recalculateTreasuryBalances();
      DocumentCustomFields.saveValues(type, id, customFields);
      return id;
    });
  }

  List<Map<String, Object?>> activeTreasuries() => _db.query(
    'SELECT id, name FROM treasuries WHERE is_active = 1 ORDER BY sort_order, id',
  );

  int? treasuryIdForPayment(int paymentId) {
    final rows = _db.query(
      '''
      SELECT COALESCE(
        (SELECT treasury_id FROM treasury_transactions
         WHERE reference_id = ?
           AND reference_type IN ('receipt_voucher', 'payment_voucher')
         ORDER BY id DESC LIMIT 1),
        (SELECT treasury_id FROM account_checks WHERE payment_id = ? LIMIT 1)
      ) AS treasury_id
      ''',
      [paymentId, paymentId],
    );
    return rows.isEmpty ? null : (rows.first['treasury_id'] as num?)?.toInt();
  }

  /// A standalone voucher row for the edit screen.
  Map<String, Object?>? paymentById(int paymentId) {
    final rows = _db.query('SELECT * FROM payments WHERE id = ?', [paymentId]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Update a standalone voucher in place: the id is kept, the account balance
  /// is corrected from the old amount/account to the new ones, and invoice
  /// linked payments are rejected so the invoice totals never drift.
  Future<void> updatePayment({
    required int paymentId,
    required int accountId,
    required int amount,
    required bool isReceipt,
    required String method,
    required DateTime date,
    int? treasuryId,
    String checkNumber = '',
    String description = '',
    Map<int, String> customFields = const {},
  }) {
    final type = isReceipt ? 'receipt' : 'payment';
    return _db.transaction(() async {
      final rows = _db.query(
        'SELECT account_id, amount, payment_type, reference_id, payment_number '
        'FROM payments WHERE id = ?',
        [paymentId],
      );
      if (rows.isEmpty) {
        throw Exception('السند غير موجود.');
      }
      final row = rows.first;
      if (row['reference_id'] != null) {
        throw Exception(
          'لا يمكن تعديل دفعة مرتبطة بفاتورة من شاشة السندات. '
          'عدّل الفاتورة نفسها.',
        );
      }
      final oldType = '${row['payment_type'] ?? ''}';
      if (oldType != type) {
        throw Exception('نوع السند لا يطابق الشاشة المفتوحة.');
      }
      final oldAccountId = (row['account_id'] as num?)?.toInt();
      final oldAmount = (row['amount'] as num?)?.toInt() ?? 0;
      if (amount <= 0) throw Exception('أدخل مبلغاً أكبر من صفر.');
      final now = DateTime.now().toIso8601String();
      if (oldAccountId != null) {
        // Reverse exactly what insertPayment applied through the balance.
        final oldDelta = oldType == 'receipt' ? -oldAmount : oldAmount;
        _db.execute(
          'UPDATE accounts SET balance = balance - ?, updated_at = ? '
          'WHERE id = ?',
          [oldDelta, now, oldAccountId],
        );
      }
      final newDelta = isReceipt ? -amount : amount;
      _db.execute(
        'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
        [newDelta, now, accountId],
      );
      _db.execute(
        '''
        UPDATE payments
        SET account_id = ?, amount = ?, payment_date = ?, payment_method = ?,
            description = ?
        WHERE id = ?
        ''',
        [
          accountId,
          amount,
          date.toIso8601String(),
          method,
          description.isEmpty ? null : description,
          paymentId,
        ],
      );
      final checkRows = _db.query(
        'SELECT id, status, check_number FROM account_checks WHERE payment_id = ? LIMIT 1',
        [paymentId],
      );
      if (method == 'check') {
        final priorCheck = checkRows.isEmpty ? null : checkRows.first;
        final wasCollected = priorCheck?['status'] == 'collected';
        if (priorCheck == null) {
          _insertPaymentCheck(
            paymentId: paymentId,
            accountId: accountId,
            amount: amount,
            isReceipt: isReceipt,
            date: date,
            checkNumber: checkNumber.isEmpty
                ? '${row['payment_number'] ?? paymentId}'
                : checkNumber,
            description: description,
            treasuryId: _requireTreasury(treasuryId),
          );
        } else {
          _db.execute(
            'UPDATE account_checks SET account_id = ?, direction = ?, amount = ?, '
            'due_date = ?, check_number = ?, notes = ?, treasury_id = ? WHERE id = ?',
            [
              accountId,
              isReceipt ? 'in' : 'out',
              amount,
              date.toIso8601String(),
              checkNumber.isEmpty
                  ? '${priorCheck['check_number'] ?? row['payment_number'] ?? paymentId}'
                  : checkNumber,
              description.isEmpty ? null : description,
              _requireTreasury(treasuryId),
              priorCheck['id'],
            ],
          );
        }
        if (wasCollected) {
          _upsertTreasuryMovement(
            paymentId: paymentId,
            isReceipt: isReceipt,
            amount: amount,
            date: date,
            treasuryId: _requireTreasury(treasuryId),
            description: description,
          );
        } else {
          _deleteTreasuryMovement(paymentId);
        }
      } else {
        _db.execute('DELETE FROM account_checks WHERE payment_id = ?', [
          paymentId,
        ]);
        _upsertTreasuryMovement(
          paymentId: paymentId,
          isReceipt: isReceipt,
          amount: amount,
          date: date,
          treasuryId: _requireTreasury(treasuryId),
          description: description,
        );
      }
      _db.execute(
        'DELETE FROM document_custom_values WHERE document_type = ? '
        'AND document_id = ?',
        [type, paymentId],
      );
      DocumentCustomFields.saveValues(type, paymentId, customFields);
      _recalculateTreasuryBalances();
    });
  }

  Future<void> deletePayment(int paymentId) {
    return _db.transaction(() async {
      final rows = _db.query('SELECT * FROM payments WHERE id = ?', [
        paymentId,
      ]);
      if (rows.isEmpty) throw Exception('السند غير موجود.');
      final row = rows.first;
      if (row['reference_id'] != null) {
        throw Exception(
          'لا يمكن حذف سند مرتبط بفاتورة؛ احذف أو عدّل الفاتورة نفسها.',
        );
      }
      final expenseRows = _db.query(
        'SELECT 1 FROM expenses WHERE payment_id = ? LIMIT 1',
        [paymentId],
      );
      if (expenseRows.isNotEmpty) {
        throw Exception('السند مرتبط بمصروف؛ احذف المصروف من شاشته أولاً.');
      }
      final accountId = (row['account_id'] as num?)?.toInt();
      final amount = (row['amount'] as num?)?.toInt() ?? 0;
      final isReceipt = row['payment_type'] == 'receipt';
      if (accountId != null) {
        _db.execute(
          'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
          [
            isReceipt ? amount : -amount,
            DateTime.now().toIso8601String(),
            accountId,
          ],
        );
      }
      _deleteTreasuryMovement(paymentId);
      _db.execute('DELETE FROM account_checks WHERE payment_id = ?', [
        paymentId,
      ]);
      _db.execute(
        'DELETE FROM document_custom_values WHERE document_type = ? AND document_id = ?',
        [isReceipt ? 'receipt' : 'payment', paymentId],
      );
      _db.execute('DELETE FROM payments WHERE id = ?', [paymentId]);
      _recalculateTreasuryBalances();
    });
  }

  int _requireTreasury(int? treasuryId) {
    final rows = treasuryId == null
        ? _db.query(
            'SELECT id FROM treasuries WHERE is_active = 1 ORDER BY sort_order, id LIMIT 1',
          )
        : _db.query(
            'SELECT id FROM treasuries WHERE id = ? AND is_active = 1',
            [treasuryId],
          );
    if (rows.isEmpty) {
      throw Exception('لا توجد خزينة نشطة لحفظ الحركة المالية.');
    }
    return (rows.first['id'] as num).toInt();
  }

  void _insertPaymentCheck({
    required int paymentId,
    required int accountId,
    required int amount,
    required bool isReceipt,
    required DateTime date,
    required String checkNumber,
    required String description,
    required int treasuryId,
  }) {
    _db.insert(
      '''
      INSERT INTO account_checks
        (account_id, direction, amount, due_date, bank, check_number, status,
         notes, created_at, payment_id, treasury_id)
      VALUES (?, ?, ?, ?, NULL, ?, 'pending', ?, ?, ?, ?)
      ''',
      [
        accountId,
        isReceipt ? 'in' : 'out',
        amount,
        date.toIso8601String(),
        checkNumber,
        description.isEmpty ? null : description,
        DateTime.now().toIso8601String(),
        paymentId,
        treasuryId,
      ],
    );
  }

  void _upsertTreasuryMovement({
    required int paymentId,
    required bool isReceipt,
    required int amount,
    required DateTime date,
    required int treasuryId,
    required String description,
  }) {
    final referenceType = isReceipt ? 'receipt_voucher' : 'payment_voucher';
    final type = isReceipt ? 'receive' : 'expense';
    final now = DateTime.now().toIso8601String();
    final time = _time(date);
    final text = description.trim().isEmpty
        ? (isReceipt ? 'سند قبض' : 'سند صرف')
        : description.trim();
    final existing = _db.query(
      'SELECT id FROM treasury_transactions '
      'WHERE reference_id = ? AND reference_type = ? ORDER BY id DESC LIMIT 1',
      [paymentId, referenceType],
    );
    if (existing.isEmpty) {
      _db.insert(
        '''
        INSERT INTO treasury_transactions
          (transaction_number, transaction_date, transaction_time, amount,
           transaction_type, description, notes, category, reference_id,
           reference_type, balance_after, created_at, treasury_id, is_transfer,
           transfer_group, peer_treasury_id)
        VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, 0, ?, ?, 0, NULL, NULL)
        ''',
        [
          '${isReceipt ? 'RCV' : 'PAY'}-$paymentId',
          date.toIso8601String(),
          time,
          amount,
          type,
          text,
          isReceipt ? 'سند قبض' : 'سند صرف',
          paymentId,
          referenceType,
          now,
          treasuryId,
        ],
      );
    } else {
      _db.execute(
        '''
        UPDATE treasury_transactions
        SET transaction_date = ?, transaction_time = ?, amount = ?,
            transaction_type = ?, description = ?, category = ?,
            treasury_id = ?, balance_after = 0
        WHERE id = ?
        ''',
        [
          date.toIso8601String(),
          time,
          amount,
          type,
          text,
          isReceipt ? 'سند قبض' : 'سند صرف',
          treasuryId,
          existing.first['id'],
        ],
      );
    }
  }

  void _deleteTreasuryMovement(int paymentId) {
    _db.execute(
      'DELETE FROM treasury_transactions WHERE reference_id = ? '
      "AND reference_type IN ('receipt_voucher', 'payment_voucher')",
      [paymentId],
    );
  }

  void _recalculateTreasuryBalances() {
    final treasuries = _db.query(
      'SELECT id, opening_balance FROM treasuries ORDER BY id',
    );
    for (final treasury in treasuries) {
      final id = (treasury['id'] as num).toInt();
      var balance = (treasury['opening_balance'] as num?)?.toInt() ?? 0;
      final rows = _db.query(
        'SELECT id, amount, transaction_type FROM treasury_transactions '
        'WHERE treasury_id = ? ORDER BY transaction_date, id',
        [id],
      );
      for (final row in rows) {
        final amount = (row['amount'] as num?)?.toInt() ?? 0;
        balance += row['transaction_type'] == 'receive' ? amount : -amount;
        _db.execute(
          'UPDATE treasury_transactions SET balance_after = ? WHERE id = ?',
          [balance, row['id']],
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Checks and installments.
  // ---------------------------------------------------------------------------
  List<AccountCheckRow> checks() {
    final rows = _db.query('''
      SELECT k.*, a.name AS account_name
      FROM account_checks k
      LEFT JOIN accounts a ON a.id = k.account_id
      ORDER BY k.due_date
    ''');
    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.tryParse(v as String);
    return rows.map((r) {
      return AccountCheckRow(
        id: r['id'] as int,
        accountName: (r['account_name'] as String?) ?? '',
        amount: (r['amount'] as int?) ?? 0,
        dueDate: parse(r['due_date']) ?? DateTime.now(),
        collectedDate: parse(r['collected_date']),
        direction: (r['direction'] as String?) ?? 'in',
        receiptNumber: (r['check_number'] as String?) ?? '',
        bank: (r['bank'] as String?) ?? '',
        checkNumber: (r['check_number'] as String?) ?? '',
        collected: ((r['status'] as String?) ?? 'pending') == 'collected',
      );
    }).toList();
  }

  Future<void> markCheckCollected(int id) {
    return _db.transaction(() async {
      final rows = _db.query('SELECT * FROM account_checks WHERE id = ?', [id]);
      if (rows.isEmpty) throw Exception('الشيك غير موجود.');
      final check = rows.first;
      if (check['status'] == 'collected') {
        return;
      }
      final collectedAt = DateTime.now();
      var paymentId = (check['payment_id'] as num?)?.toInt();
      final isReceipt = check['direction'] != 'out';
      final accountId = (check['account_id'] as num?)?.toInt();
      final amount = (check['amount'] as num?)?.toInt() ?? 0;
      if (accountId == null || amount <= 0) {
        throw Exception('بيانات الشيك أو الحساب غير صحيحة.');
      }
      if (paymentId == null) {
        paymentId = _db.insert(
          '''
          INSERT INTO payments
            (payment_number, account_id, payment_date, amount, payment_type,
             payment_method, description, created_at)
          VALUES (?, ?, ?, ?, ?, 'check', ?, ?)
          ''',
          [
            '${isReceipt ? 'RCV' : 'PAY'}-${_stamp()}',
            accountId,
            collectedAt.toIso8601String(),
            amount,
            isReceipt ? 'receipt' : 'payment',
            'تحصيل شيك ${check['check_number'] ?? ''}',
            collectedAt.toIso8601String(),
          ],
        );
        _db.execute(
          'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
          [
            isReceipt ? -amount : amount,
            collectedAt.toIso8601String(),
            accountId,
          ],
        );
      }
      _upsertTreasuryMovement(
        paymentId: paymentId,
        isReceipt: isReceipt,
        amount: amount,
        date: collectedAt,
        treasuryId: _requireTreasury((check['treasury_id'] as num?)?.toInt()),
        description: 'تحصيل شيك ${check['check_number'] ?? ''}',
      );
      _db.execute(
        'UPDATE account_checks SET payment_id = ?, status = ?, collected_date = ? WHERE id = ?',
        [paymentId, 'collected', collectedAt.toIso8601String(), id],
      );
      _recalculateTreasuryBalances();
    });
  }

  void insertCheck(AccountCheckRow row) {
    _db.insert(
      '''
      INSERT INTO account_checks
        (account_id, direction, amount, due_date, collected_date, bank,
         check_number, status, notes, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        _accountIdByName(row.accountName),
        row.direction,
        row.amount,
        row.dueDate.toIso8601String(),
        row.collectedDate?.toIso8601String(),
        row.bank.isEmpty ? null : row.bank,
        row.checkNumber.isEmpty ? null : row.checkNumber,
        row.collected ? 'collected' : 'pending',
        null,
        DateTime.now().toIso8601String(),
      ],
    );
  }

  int _accountIdByName(String name) {
    final rows = _db.query('SELECT id FROM accounts WHERE name = ? LIMIT 1', [
      name,
    ]);
    if (rows.isEmpty) return 0;
    return rows.first['id'] as int;
  }

  // ---------------------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------------------
  String _stamp() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return '${now.year}$mm$dd$hh$mi$ss';
  }

  String _time(DateTime value) {
    final h = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final m = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $suffix';
  }
}
