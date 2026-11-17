import 'package:inventory_app/core/database/sqlite_database.dart';
import 'package:inventory_app/core/services/document_custom_fields.dart';
import 'package:inventory_app/features/treasury/domain/treasury_movement_models.dart';

/// Data access for the treasury movement screen.
///
/// All money is stored as whole pounds in `treasury_transactions.amount`, the
/// same convention used by the existing purchase / invoice screens. The
/// repository computes balances from the ledger instead of trusting a cached
/// number, so a transfer, edit or delete can never leave the summary cards out
/// of sync with the rows.
class TreasuryMovementRepository {
  TreasuryMovementRepository._internal();

  static final TreasuryMovementRepository _instance =
      TreasuryMovementRepository._internal();

  factory TreasuryMovementRepository() => _instance;

  final _db = SqliteDatabase();

  // ---------------------------------------------------------------------------
  // Lookups.
  // ---------------------------------------------------------------------------
  List<TreasuryAccount> getTreasuries({bool activeOnly = true}) {
    final rows = _db.query(
      'SELECT id, name, opening_balance, description, is_active '
      'FROM treasuries '
      '${activeOnly ? 'WHERE is_active = 1 ' : ''}'
      'ORDER BY id',
    );
    return rows.map(_rowToTreasury).toList();
  }

  TreasuryAccount? getTreasury(int id) {
    final rows = _db.query(
      'SELECT id, name, opening_balance, description, is_active '
      'FROM treasuries WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return _rowToTreasury(rows.first);
  }

  TreasuryAccount _requireTreasury(int id) {
    final treasury = getTreasury(id);
    if (treasury == null || !treasury.isActive) {
      throw const TreasuryValidationException(
        'الخزينة المحددة غير موجودة أو غير نشطة.',
      );
    }
    return treasury;
  }

  TreasuryAccount _rowToTreasury(Map<String, dynamic> row) {
    return TreasuryAccount(
      id: (row['id'] as num).toInt(),
      name: (row['name'] as String?) ?? 'خزينة',
      openingBalance: (row['opening_balance'] as num?)?.toInt() ?? 0,
      description: row['description'] as String?,
      isActive: ((row['is_active'] as num?)?.toInt() ?? 1) == 1,
    );
  }

  // ---------------------------------------------------------------------------
  // Report.
  // ---------------------------------------------------------------------------
  TreasuryReport buildReport(TreasuryFilters filters) {
    if (filters.from.isAfter(filters.to)) {
      throw const TreasuryValidationException(
        'تاريخ البداية يجب أن يكون قبل تاريخ النهاية.',
      );
    }

    final selectedTreasury = filters.treasuryId == null
        ? null
        : getTreasury(filters.treasuryId!);
    final treasuries = filters.treasuryId == null
        ? getTreasuries()
        : <TreasuryAccount>[?selectedTreasury];
    if (treasuries.isEmpty) {
      throw const TreasuryValidationException('لا توجد خزائن نشطة.');
    }

    final fromIso = filters.from.toIso8601String();
    final toIso = filters.to.toIso8601String();

    final summary = <TreasurySummaryRow>[];
    final openingRunning = <int, int>{};
    var totalPrevious = 0;
    var totalIncoming = 0;
    var totalOutgoing = 0;

    for (final treasury in treasuries) {
      final previous =
          treasury.openingBalance + _sumSignedBefore(treasury.id, fromIso);
      final period = _sumPeriod(treasury.id, fromIso, toIso);
      final balance = previous + period.$1 - period.$2;
      openingRunning[treasury.id] = previous;
      totalPrevious += previous;
      totalIncoming += period.$1;
      totalOutgoing += period.$2;
      summary.add(
        TreasurySummaryRow(
          treasuryId: treasury.id,
          treasuryName: treasury.name,
          previousBalance: previous,
          incoming: period.$1,
          outgoing: period.$2,
          balance: balance,
        ),
      );
    }

    final allName = filters.treasuryId == null
        ? 'كل الخزائن'
        : treasuries.first.name;
    summary.add(
      TreasurySummaryRow(
        treasuryId: -1,
        treasuryName: 'الإجمالي',
        previousBalance: totalPrevious,
        incoming: totalIncoming,
        outgoing: totalOutgoing,
        balance: totalPrevious + totalIncoming - totalOutgoing,
        isTotal: true,
      ),
    );

    // Balances are always calculated from every movement in the period so a
    // number/notes filter only hides rows and never changes their balances.
    final periodMovements = _fetchMovements(
      filters.copyWith(numberQuery: '', notesQuery: ''),
    );
    final balancesByMovement = <int, int>{};
    final treasuryRunning = Map<int, int>.from(openingRunning);
    var globalRunning = totalPrevious;
    for (final movement in periodMovements) {
      if (filters.treasuryId == null) {
        // «كل الخزائن» shows one combined running balance across treasuries.
        globalRunning += movement.isIncoming
            ? movement.amount
            : -movement.amount;
        balancesByMovement[movement.id] = globalRunning;
        continue;
      }
      final start =
          treasuryRunning[movement.treasuryId] ??
          movement.balanceAfter -
              (movement.isIncoming ? movement.amount : -movement.amount);
      final after = movement.isIncoming
          ? start + movement.amount
          : start - movement.amount;
      treasuryRunning[movement.treasuryId] = after;
      balancesByMovement[movement.id] = after;
    }

    final withBalances = _fetchMovements(filters)
        .map(
          (movement) => movement.copyWith(
            balanceAfter:
                balancesByMovement[movement.id] ?? movement.balanceAfter,
          ),
        )
        .toList();

    final currentBalance = totalPrevious + totalIncoming - totalOutgoing;
    final movements = <TreasuryMovement>[
      TreasuryMovement.previous(
        date: filters.from,
        balance: totalPrevious,
        treasuryName: allName,
      ),
      ...withBalances,
      TreasuryMovement.total(
        date: filters.to,
        incoming: totalIncoming,
        outgoing: totalOutgoing,
        balance: currentBalance,
        treasuryName: allName,
      ),
    ];

    return TreasuryReport(
      summary: summary,
      movements: movements,
      previousBalance: totalPrevious,
      incoming: totalIncoming,
      outgoing: totalOutgoing,
      currentBalance: currentBalance,
      filters: filters,
    );
  }

  List<TreasuryMovement> _fetchMovements(TreasuryFilters filters) {
    final clauses = <String>[
      't.transaction_date >= ?',
      't.transaction_date <= ?',
    ];
    final params = <Object?>[
      filters.from.toIso8601String(),
      filters.to.toIso8601String(),
    ];

    if (filters.treasuryId != null) {
      clauses.add('t.treasury_id = ?');
      params.add(filters.treasuryId);
    }
    final number = filters.numberQuery.trim();
    if (number.isNotEmpty) {
      final like = '%$number%';
      clauses.add(
        "(t.transaction_number LIKE ? OR COALESCE(t.description, '') LIKE ? "
        "OR COALESCE(t.reference_type, '') LIKE ? "
        "OR COALESCE(t.transfer_group, '') LIKE ?)",
      );
      params.addAll([like, like, like, like]);
    }
    final notes = filters.notesQuery.trim();
    if (notes.isNotEmpty) {
      final like = '%$notes%';
      clauses.add(
        "(COALESCE(t.notes, '') LIKE ? OR COALESCE(t.description, '') LIKE ?)",
      );
      params.addAll([like, like]);
    }

    final rows = _db.query(
      'SELECT t.*, COALESCE(tr.name, \'خزينة\') AS treasury_name '
      'FROM treasury_transactions t '
      'LEFT JOIN treasuries tr ON tr.id = t.treasury_id '
      'WHERE ${clauses.join(' AND ')} '
      'ORDER BY t.transaction_date ASC, t.id ASC',
      params,
    );
    return rows.map(_rowToMovement).toList();
  }

  int _sumSignedBefore(int treasuryId, String beforeIso) {
    final rows = _db.query(
      'SELECT COALESCE(SUM(CASE WHEN transaction_type = \'receive\' '
      'THEN amount ELSE -amount END), 0) AS total '
      'FROM treasury_transactions '
      'WHERE treasury_id = ? AND transaction_date < ?',
      [treasuryId, beforeIso],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  int _sumSignedBeforeExcluding(
    int treasuryId,
    String beforeIso,
    String? excludeGroup,
  ) {
    final rows = _db.query(
      'SELECT COALESCE(SUM(CASE WHEN transaction_type = \'receive\' '
      'THEN amount ELSE -amount END), 0) AS total '
      'FROM treasury_transactions '
      'WHERE treasury_id = ? AND transaction_date < ? '
      'AND (? IS NULL OR COALESCE(transfer_group, \'\') <> ?)',
      [treasuryId, beforeIso, excludeGroup, excludeGroup],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  (int, int) _sumPeriod(int treasuryId, String fromIso, String toIso) {
    final rows = _db.query(
      'SELECT '
      'COALESCE(SUM(CASE WHEN transaction_type = \'receive\' THEN amount '
      'ELSE 0 END), 0) AS incoming, '
      'COALESCE(SUM(CASE WHEN transaction_type = \'expense\' THEN amount '
      'ELSE 0 END), 0) AS outgoing '
      'FROM treasury_transactions '
      'WHERE treasury_id = ? AND transaction_date >= ? '
      'AND transaction_date <= ?',
      [treasuryId, fromIso, toIso],
    );
    final row = rows.first;
    return (
      (row['incoming'] as num?)?.toInt() ?? 0,
      (row['outgoing'] as num?)?.toInt() ?? 0,
    );
  }

  TreasuryMovement _rowToMovement(Map<String, dynamic> row) {
    final rawDate = (row['transaction_date'] as String?) ?? '';
    var date = DateTime.tryParse(rawDate);
    if (date == null) {
      final rawTime = (row['transaction_time'] as String?) ?? '00:00';
      final parts = rawTime.split(':');
      date = DateTime(
        2000,
        1,
        1,
        int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0,
        int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      );
    }
    final type = (row['transaction_type'] as String?) ?? 'expense';
    final isTransfer =
        ((row['is_transfer'] as num?)?.toInt() ?? 0) == 1 || type == 'transfer';
    return TreasuryMovement(
      id: (row['id'] as num).toInt(),
      transactionNumber: (row['transaction_number'] as String?) ?? '',
      treasuryId: (row['treasury_id'] as num?)?.toInt() ?? 0,
      treasuryName: (row['treasury_name'] as String?) ?? 'خزينة',
      date: date,
      type: type,
      amount: (row['amount'] as num?)?.toInt() ?? 0,
      balanceAfter: (row['balance_after'] as num?)?.toInt() ?? 0,
      description: row['description'] as String?,
      notes: row['notes'] as String?,
      category: row['category'] as String?,
      referenceId: (row['reference_id'] as num?)?.toInt(),
      referenceType: row['reference_type'] as String?,
      isTransfer: isTransfer,
      transferGroup: row['transfer_group'] as String?,
      peerTreasuryId: (row['peer_treasury_id'] as num?)?.toInt(),
    );
  }

  TreasuryMovement? getMovement(int id) {
    final rows = _db.query(
      'SELECT t.*, COALESCE(tr.name, \'خزينة\') AS treasury_name '
      'FROM treasury_transactions t '
      'LEFT JOIN treasuries tr ON tr.id = t.treasury_id '
      'WHERE t.id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return _rowToMovement(rows.first);
  }

  List<TreasuryMovement> getTransferGroup(String group) {
    final rows = _db.query(
      'SELECT t.*, COALESCE(tr.name, \'خزينة\') AS treasury_name '
      'FROM treasury_transactions t '
      'LEFT JOIN treasuries tr ON tr.id = t.treasury_id '
      'WHERE t.transfer_group = ? ORDER BY t.id',
      [group],
    );
    return rows.map(_rowToMovement).toList();
  }

  TreasuryAnalysisRow _analysisRow(
    String label,
    int count,
    int amount,
    int total,
  ) => TreasuryAnalysisRow(
    label: label,
    count: count,
    amount: amount,
    share: total <= 0 ? 0 : amount / total,
  );

  List<TreasuryAnalysisRow> analyzeExpenses(TreasuryFilters filters) {
    final movements = _fetchMovements(filters)
        .where((m) => !m.isTransfer && m.isOutgoing)
        .toList();
    return _groupAnalysis(movements, (m) => m.categoryLabel);
  }

  List<TreasuryAnalysisRow> analyzeReceipts(TreasuryFilters filters) {
    final movements = _fetchMovements(filters)
        .where((m) => !m.isTransfer && m.isIncoming)
        .toList();
    return _groupAnalysis(movements, (m) => m.categoryLabel);
  }

  List<TreasuryAnalysisRow> _groupAnalysis(
    List<TreasuryMovement> movements,
    String Function(TreasuryMovement movement) keyOf,
  ) {
    final totals = <String, int>{};
    final counts = <String, int>{};
    var grand = 0;
    for (final movement in movements) {
      final key = keyOf(movement);
      totals[key] = (totals[key] ?? 0) + movement.amount;
      counts[key] = (counts[key] ?? 0) + 1;
      grand += movement.amount;
    }
    final rows =
        totals.entries
            .map(
              (entry) => _analysisRow(
                entry.key,
                counts[entry.key] ?? 0,
                entry.value,
                grand,
              ),
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));
    return rows;
  }

  // ---------------------------------------------------------------------------
  // Add / edit / delete.
  // ---------------------------------------------------------------------------
  Future<int> addReceive(TreasuryMovementInput input) async {
    return _addSimple(input, 'receive', 'REC');
  }

  Future<int> addExpense(TreasuryMovementInput input) async {
    return _addSimple(input, 'expense', 'EXP');
  }

  Future<int> _addSimple(
    TreasuryMovementInput input,
    String type,
    String prefix,
  ) async {
    _validateInput(input);
    _requireTreasury(input.treasuryId);
    _ensureNotDuplicate(
      treasuryId: input.treasuryId,
      type: type,
      amount: input.amount,
      date: input.date,
      description: input.description,
    );
    final number = _nextNumber(prefix);
    final now = DateTime.now().toIso8601String();
    return _db.transaction(() async {
      final id = _db.insert(
        'INSERT INTO treasury_transactions '
        '(transaction_number, transaction_date, transaction_time, amount, '
        'transaction_type, description, notes, category, reference_id, '
        'reference_type, balance_after, created_at, treasury_id, '
        'is_transfer, transfer_group, peer_treasury_id) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, \'manual\', 0, ?, ?, 0, NULL, NULL)',
        [
          number,
          input.date.toIso8601String(),
          _timeText(input.date),
          input.amount,
          type,
          input.description.trim(),
          input.notes.trim(),
          input.category.trim(),
          now,
          input.treasuryId,
        ],
      );
      DocumentCustomFields.saveValues(
        type == 'receive'
            ? DocumentTypes.treasuryReceive
            : DocumentTypes.treasuryExpense,
        id,
        input.customFields,
      );
      _recalculateBalances();
      return id;
    });
  }

  Future<int> addTransfer(TreasuryTransferInput input) async {
    _validateTransfer(input);
    final source = _requireTreasury(input.sourceTreasuryId);
    final destination = _requireTreasury(input.destinationTreasuryId);
    if (source.id == destination.id) {
      throw const TreasuryValidationException(
        'لا يمكن التحويل إلى نفس الخزينة. اختر خزينة مختلفة.',
      );
    }
    final balanceBefore =
        source.openingBalance +
        _sumSignedBefore(source.id, input.date.toIso8601String());
    if (balanceBefore < input.amount) {
      throw TreasuryValidationException(
        'رصيد ${source.name} غير كافٍ للتحويل. المتاح: $balanceBefore.',
      );
    }
    _ensureTransferNotDuplicate(input);
    final group = _nextNumber('TRF');
    final now = DateTime.now().toIso8601String();
    final description = input.description.trim();

    return _db.transaction(() async {
      _db.insert(
        'INSERT INTO treasury_transactions '
        '(transaction_number, transaction_date, transaction_time, amount, '
        'transaction_type, description, notes, category, reference_id, '
        'reference_type, balance_after, created_at, treasury_id, '
        'is_transfer, transfer_group, peer_treasury_id) '
        'VALUES (?, ?, ?, ?, \'expense\', ?, NULL, \'تحويل داخلي\', NULL, '
        '\'treasury\', 0, ?, ?, 1, ?, ?)',
        [
          '$group-O',
          input.date.toIso8601String(),
          _timeText(input.date),
          input.amount,
          'تحويل إلى ${destination.name}: $description',
          now,
          source.id,
          group,
          destination.id,
        ],
      );
      final incomingId = _db.insert(
        'INSERT INTO treasury_transactions '
        '(transaction_number, transaction_date, transaction_time, amount, '
        'transaction_type, description, notes, category, reference_id, '
        'reference_type, balance_after, created_at, treasury_id, '
        'is_transfer, transfer_group, peer_treasury_id) '
        'VALUES (?, ?, ?, ?, \'receive\', ?, NULL, \'تحويل داخلي\', NULL, '
        '\'treasury\', 0, ?, ?, 1, ?, ?)',
        [
          '$group-I',
          input.date.toIso8601String(),
          _timeText(input.date),
          input.amount,
          'تحويل من ${source.name}: $description',
          now,
          destination.id,
          group,
          source.id,
        ],
      );
      DocumentCustomFields.saveValues(
        DocumentTypes.treasuryTransfer,
        incomingId,
        input.customFields,
      );
      _recalculateBalances();
      return incomingId;
    });
  }

  Future<void> updateMovement(int id, TreasuryMovementInput input) async {
    final existing = getMovement(id);
    if (existing == null) {
      throw const TreasuryValidationException('الحركة المحددة غير موجودة.');
    }
    if (existing.isTransfer) {
      throw const TreasuryValidationException(
        'هذه الحركة جزء من تحويل. استخدم «تحويل من خزينة لأخرى» لتعديلها.',
      );
    }
    if (existing.hasReference) {
      throw const TreasuryValidationException(
        'لا يمكن تعديل حركة مرتبطة بفاتورة من هذه الشاشة.',
      );
    }
    _validateInput(input);
    _requireTreasury(input.treasuryId);
    _ensureNotDuplicate(
      treasuryId: input.treasuryId,
      type: existing.type,
      amount: input.amount,
      date: input.date,
      description: input.description,
      excludeId: id,
    );
    await _db.transaction(() async {
      _db.execute(
        'UPDATE treasury_transactions SET transaction_date = ?, '
        'transaction_time = ?, amount = ?, treasury_id = ?, description = ?, '
        'notes = ?, category = ? WHERE id = ?',
        [
          input.date.toIso8601String(),
          _timeText(input.date),
          input.amount,
          input.treasuryId,
          input.description.trim(),
          input.notes.trim(),
          input.category.trim(),
          id,
        ],
      );
      DocumentCustomFields.saveValues(
        existing.isIncoming
            ? DocumentTypes.treasuryReceive
            : DocumentTypes.treasuryExpense,
        id,
        input.customFields,
      );
      _recalculateBalances();
    });
  }

  Future<void> updateTransfer(String group, TreasuryTransferInput input) async {
    _validateTransfer(input);
    final legs = getTransferGroup(group);
    if (legs.length != 2) {
      throw const TreasuryValidationException(
        'لم يتم العثور على طرفي التحويل. حدّث الشاشة ثم حاول مرة أخرى.',
      );
    }
    final source = _requireTreasury(input.sourceTreasuryId);
    final destination = _requireTreasury(input.destinationTreasuryId);
    if (source.id == destination.id) {
      throw const TreasuryValidationException(
        'لا يمكن التحويل إلى نفس الخزينة. اختر خزينة مختلفة.',
      );
    }
    final balanceBefore =
        source.openingBalance +
        _sumSignedBeforeExcluding(
          source.id,
          input.date.toIso8601String(),
          group,
        );
    if (balanceBefore < input.amount) {
      throw TreasuryValidationException(
        'رصيد ${source.name} غير كافٍ للتحويل. المتاح: $balanceBefore.',
      );
    }
    final description = input.description.trim();
    final existingOut = legs.firstWhere((leg) => leg.isOutgoing);
    final existingIn = legs.firstWhere((leg) => leg.isIncoming);

    await _db.transaction(() async {
      _db.execute(
        'UPDATE treasury_transactions SET transaction_date = ?, '
        'transaction_time = ?, amount = ?, treasury_id = ?, description = ?, '
        'category = \'تحويل داخلي\', peer_treasury_id = ?, '
        'transfer_group = ? WHERE id = ?',
        [
          input.date.toIso8601String(),
          _timeText(input.date),
          input.amount,
          source.id,
          'تحويل إلى ${destination.name}: $description',
          destination.id,
          group,
          existingOut.id,
        ],
      );
      _db.execute(
        'UPDATE treasury_transactions SET transaction_date = ?, '
        'transaction_time = ?, amount = ?, treasury_id = ?, description = ?, '
        'category = \'تحويل داخلي\', peer_treasury_id = ?, '
        'transfer_group = ? WHERE id = ?',
        [
          input.date.toIso8601String(),
          _timeText(input.date),
          input.amount,
          destination.id,
          'تحويل من ${source.name}: $description',
          source.id,
          group,
          existingIn.id,
        ],
      );
      DocumentCustomFields.saveValues(
        DocumentTypes.treasuryTransfer,
        existingIn.id,
        input.customFields,
      );
      _recalculateBalances();
    });
  }

  Future<void> deleteMovement(int id) async {
    final existing = getMovement(id);
    if (existing == null) {
      throw const TreasuryValidationException('الحركة المحددة غير موجودة.');
    }
    if (existing.isTransfer && existing.transferGroup != null) {
      await deleteTransferGroup(existing.transferGroup!);
      return;
    }
    if (existing.hasReference) {
      throw const TreasuryValidationException(
        'لا يمكن حذف حركة مرتبطة بفاتورة من هذه الشاشة. '
        'احذف الفاتورة أو ألغِ سدادها من شاشتها.',
      );
    }
    await _db.transaction(() async {
      _db.execute('DELETE FROM treasury_transactions WHERE id = ?', [id]);
      _recalculateBalances();
    });
  }

  Future<void> deleteTransferGroup(String group) async {
    final legs = getTransferGroup(group);
    if (legs.isEmpty) {
      throw const TreasuryValidationException('التحويل المحدد غير موجود.');
    }
    await _db.transaction(() async {
      _db.execute(
        'DELETE FROM treasury_transactions WHERE transfer_group = ?',
        [group],
      );
      _recalculateBalances();
    });
  }

  // ---------------------------------------------------------------------------
  // Validation helpers.
  // ---------------------------------------------------------------------------
  void _validateInput(TreasuryMovementInput input) {
    if (input.amount <= 0) {
      throw const TreasuryValidationException(
        'المبلغ يجب أن يكون أكبر من صفر.',
      );
    }
    if (input.amount > 1000000000) {
      throw const TreasuryValidationException('المبلغ أكبر من الحد المسموح.');
    }
    if (input.description.trim().isEmpty) {
      throw const TreasuryValidationException('اكتب بياناً للحركة.');
    }
    if (input.date.year < 2000 || input.date.year > 2100) {
      throw const TreasuryValidationException('تاريخ الحركة غير صحيح.');
    }
  }

  void _validateTransfer(TreasuryTransferInput input) {
    if (input.amount <= 0) {
      throw const TreasuryValidationException(
        'مبلغ التحويل يجب أن يكون أكبر من صفر.',
      );
    }
    if (input.sourceTreasuryId == input.destinationTreasuryId) {
      throw const TreasuryValidationException(
        'اختر خزينة مصدر وخزينة وجهة مختلفتين.',
      );
    }
    if (input.description.trim().isEmpty) {
      throw const TreasuryValidationException('اكتب بيان التحويل.');
    }
    if (input.date.year < 2000 || input.date.year > 2100) {
      throw const TreasuryValidationException('تاريخ التحويل غير صحيح.');
    }
  }

  void _ensureNotDuplicate({
    required int treasuryId,
    required String type,
    required int amount,
    required DateTime date,
    required String description,
    int? excludeId,
  }) {
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
    );
    final end = start.add(const Duration(minutes: 1));
    final rows = _db.query(
      'SELECT id FROM treasury_transactions '
      'WHERE treasury_id = ? AND transaction_type = ? AND amount = ? '
      'AND transaction_date >= ? AND transaction_date < ? '
      "AND COALESCE(description, '') = ? AND is_transfer = 0 "
      '${excludeId == null ? '' : 'AND id <> ?'} LIMIT 1',
      [
        treasuryId,
        type,
        amount,
        start.toIso8601String(),
        end.toIso8601String(),
        description.trim(),
        ?excludeId,
      ],
    );
    if (rows.isNotEmpty) {
      throw const TreasuryValidationException(
        'توجد حركة مطابقة لنفس الخزينة والمبلغ والوقت. راجع البيانات قبل الحفظ.',
      );
    }
  }

  void _ensureTransferNotDuplicate(TreasuryTransferInput input) {
    final start = DateTime(
      input.date.year,
      input.date.month,
      input.date.day,
      input.date.hour,
      input.date.minute,
    );
    final end = start.add(const Duration(minutes: 1));
    final rows = _db.query(
      'SELECT id FROM treasury_transactions '
      'WHERE treasury_id = ? AND transaction_type = \'expense\' '
      'AND amount = ? AND transaction_date >= ? AND transaction_date < ? '
      'AND is_transfer = 1 LIMIT 1',
      [
        input.sourceTreasuryId,
        input.amount,
        start.toIso8601String(),
        end.toIso8601String(),
      ],
    );
    if (rows.isNotEmpty) {
      throw const TreasuryValidationException(
        'يوجد تحويل مطابق لنفس الخزينة والمبلغ والوقت.',
      );
    }
  }

  String _nextNumber(String prefix) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    var candidate = '$prefix-$stamp';
    var suffix = 0;
    while (_db.query(
      'SELECT id FROM treasury_transactions WHERE transaction_number = ? '
      'LIMIT 1',
      [candidate],
    ).isNotEmpty) {
      suffix++;
      candidate = '$prefix-$stamp-$suffix';
    }
    return candidate;
  }

  String _timeText(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  /// Recomputes `balance_after` for every movement, treasury by treasury.
  void _recalculateBalances() {
    for (final treasury in getTreasuries(activeOnly: false)) {
      var running = treasury.openingBalance;
      final rows = _db.query(
        'SELECT id, amount, transaction_type FROM treasury_transactions '
        'WHERE treasury_id = ? ORDER BY transaction_date ASC, id ASC',
        [treasury.id],
      );
      for (final row in rows) {
        final amount = (row['amount'] as num?)?.toInt() ?? 0;
        if (row['transaction_type'] == 'receive') {
          running += amount;
        } else {
          running -= amount;
        }
        _db.execute(
          'UPDATE treasury_transactions SET balance_after = ? WHERE id = ?',
          [running, row['id']],
        );
      }
    }
  }
}
