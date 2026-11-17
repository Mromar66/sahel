import 'package:sqlite3/sqlite3.dart';

import 'package:inventory_app/core/database/sqlite_database.dart';
import 'package:inventory_app/features/reports/domain/purchase_analysis_models.dart';

/// Builds تقرير تحليل المشتريات from the real purchase tables.
///
/// Business rules:
/// - A purchase invoice contributes its lines to «المشتريات». The invoice
///   level discount is allocated across the lines by value and reduces the
///   purchase value, so the report reconciles with the invoice total.
/// - A purchase return contributes to «المرتجعات» and is subtracted from the
///   net quantity/value.
/// - `purchase_invoices.tax` is an invoice addition, not VAT. It is allocated
///   to the lines and shown in the «مصروف» column.
/// - «إجمالي التكلفة» = الصافي + المصروف.
/// - Purchases do not record a warehouse, so the «المخزن» dimension is one
///   honest bucket labelled «غير محدد». Transfers and stock adjustments are
///   never read here.
class PurchaseAnalysisRepository {
  PurchaseAnalysisRepository({Database? database})
    : _database = database ?? SqliteDatabase().db;

  final Database _database;

  Database get _db => _database;

  static const List<String> _monthNames = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  // ---------------------------------------------------------------------------
  // Filter lookups.
  // ---------------------------------------------------------------------------
  List<PurchaseAnalysisOption> getAccounts() =>
      _options('SELECT id, name FROM accounts ORDER BY name COLLATE NOCASE');

  List<PurchaseAnalysisOption> getCategories() =>
      _options('SELECT id, name FROM categories ORDER BY name COLLATE NOCASE');

  List<PurchaseAnalysisOption> getWarehouses() =>
      _options('SELECT id, name FROM warehouses ORDER BY name COLLATE NOCASE');

  List<PurchaseAnalysisOption> _options(String sql) {
    final rows = _db.select(sql);
    return [
      for (final row in rows)
        PurchaseAnalysisOption(
          id: (row['id'] as num?)?.toInt() ?? 0,
          name: '${row['name'] ?? ''}',
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Report.
  // ---------------------------------------------------------------------------
  PurchaseAnalysisReport buildReport({
    required PurchaseAnalysisFilters filters,
    required PurchaseAnalysisGroup group,
    required PurchaseAnalysisMode mode,
  }) {
    final periodText = '${_dateText(filters.from)} - ${_dateText(filters.to)}';
    final accountName = _nameOf(filters.accountId, getAccounts());
    final categoryName = _nameOf(filters.categoryId, getCategories());
    final warehouseName = _nameOf(filters.warehouseId, getWarehouses());
    final emptyTotals = const PurchaseAnalysisTotals(
      invoices: 0,
      purchaseQty: 0,
      purchaseTotal: 0,
      returnQty: 0,
      returnTotal: 0,
      netQty: 0,
      netTotal: 0,
      expense: 0,
      totalCost: 0,
    );

    if (group.isUnavailable) {
      return PurchaseAnalysisReport(
        rows: const [],
        totals: emptyTotals,
        filters: filters,
        group: group,
        mode: mode,
        periodText: periodText,
        unavailableReason:
            'لا يوجد جدول مستخدمين في قاعدة البيانات الحالية، لذلك لا يمكن '
            'تجميع المشتريات حسب المستخدم.',
        accountName: accountName,
        categoryName: categoryName,
        warehouseName: warehouseName,
      );
    }

    final lines = <_PurchaseLine>[
      ..._loadPurchases(filters),
      ..._loadReturns(filters),
    ];
    final buckets = <String, _Bucket>{};
    for (final line in lines) {
      final key = _groupKey(line, group, mode);
      buckets.putIfAbsent(key, _Bucket.new).add(line);
    }

    final grandCost = buckets.values.fold<double>(
      0,
      (sum, bucket) => sum + bucket.totalCost,
    );
    var invoices = 0;
    var purchaseQty = 0;
    var returnQty = 0;
    var netQty = 0;
    var purchaseTotal = 0;
    var returnTotal = 0;
    var netTotal = 0;
    var expense = 0;
    var totalCost = 0;
    final invoiceIds = <int>{};
    for (final bucket in buckets.values) {
      invoiceIds.addAll(bucket.invoiceIds);
    }
    invoices = invoiceIds.length;
    for (final bucket in buckets.values) {
      purchaseQty += bucket.purchaseQty;
      returnQty += bucket.returnQty;
      netQty += bucket.netQty;
      purchaseTotal += bucket.purchaseTotal.round();
      returnTotal += bucket.returnTotal.round();
      netTotal += bucket.netTotal.round();
      expense += bucket.expense.round();
      totalCost += bucket.totalCost.round();
    }

    final rows =
        <PurchaseAnalysisRow>[
          for (final entry in buckets.entries)
            PurchaseAnalysisRow(
              label: entry.key,
              subtitle: entry.value.subtitle,
              invoices: entry.value.invoiceIds.length,
              purchaseQty: entry.value.purchaseQty,
              purchaseTotal: entry.value.purchaseTotal.round(),
              returnQty: entry.value.returnQty,
              returnTotal: entry.value.returnTotal.round(),
              netQty: entry.value.netQty,
              netTotal: entry.value.netTotal.round(),
              expense: entry.value.expense.round(),
              totalCost: entry.value.totalCost.round(),
              shareOfTotal: grandCost == 0
                  ? 0
                  : (entry.value.totalCost / grandCost) * 100,
            ),
        ]..sort((a, b) {
          final byCost = b.totalCost.compareTo(a.totalCost);
          return byCost != 0 ? byCost : a.label.compareTo(b.label);
        });

    return PurchaseAnalysisReport(
      rows: rows,
      totals: PurchaseAnalysisTotals(
        invoices: invoices,
        purchaseQty: purchaseQty,
        purchaseTotal: purchaseTotal,
        returnQty: returnQty,
        returnTotal: returnTotal,
        netQty: netQty,
        netTotal: netTotal,
        expense: expense,
        totalCost: totalCost,
      ),
      filters: filters,
      group: group,
      mode: mode,
      periodText: periodText,
      accountName: accountName,
      categoryName: categoryName,
      warehouseName: warehouseName,
    );
  }

  // ---------------------------------------------------------------------------
  // SQL loading.
  // ---------------------------------------------------------------------------
  List<_PurchaseLine> _loadPurchases(PurchaseAnalysisFilters filters) {
    final where = <String>['pi.invoice_date >= ?', 'pi.invoice_date <= ?'];
    final args = <Object?>[
      _startOfDay(filters.from).toIso8601String(),
      _endOfDay(filters.to).toIso8601String(),
    ];
    if (filters.accountId != null) {
      where.add('pi.account_id = ?');
      args.add(filters.accountId);
    }
    if (filters.categoryId != null) {
      where.add('p.category_id = ?');
      args.add(filters.categoryId);
    }

    final rows = _db.select('''
      SELECT pi.id AS invoice_id,
             pi.invoice_number,
             pi.invoice_date,
             pi.subtotal,
             COALESCE(pi.discount, 0) AS invoice_discount,
             COALESCE(pi.tax, 0) AS invoice_addition,
             pi.account_id,
             COALESCE(a.name, '') AS account_name,
             it.product_id,
             it.product_name,
             it.quantity,
             COALESCE(it.discount, 0) AS item_discount,
             it.total AS item_total,
             p.category_id,
             COALESCE(c.name, '') AS category_name
      FROM purchase_invoices pi
      JOIN purchase_items it ON it.invoice_id = pi.id
      LEFT JOIN accounts a ON a.id = pi.account_id
      LEFT JOIN products p ON p.id = it.product_id
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE COALESCE(pi.is_return, 0) = 0
        AND ${where.join(' AND ')}
      ORDER BY pi.invoice_date, pi.id, it.id
      ''', args);
    return rows
        .map((row) => _PurchaseLine.fromRow(row, isReturn: false))
        .toList();
  }

  List<_PurchaseLine> _loadReturns(PurchaseAnalysisFilters filters) {
    final where = <String>['pri.return_date >= ?', 'pri.return_date <= ?'];
    final args = <Object?>[
      _startOfDay(filters.from).toIso8601String(),
      _endOfDay(filters.to).toIso8601String(),
    ];
    if (filters.accountId != null) {
      where.add('pri.account_id = ?');
      args.add(filters.accountId);
    }
    if (filters.categoryId != null) {
      where.add('p.category_id = ?');
      args.add(filters.categoryId);
    }

    final rows = _db.select('''
      SELECT pri.id AS invoice_id,
             pri.return_number AS invoice_number,
             pri.return_date AS invoice_date,
             pri.subtotal,
             COALESCE(pri.discount, 0) AS invoice_discount,
             COALESCE(pri.tax, 0) AS invoice_addition,
             pri.account_id,
             COALESCE(a.name, '') AS account_name,
             it.product_id,
             it.product_name,
             it.quantity,
             COALESCE(it.discount, 0) AS item_discount,
             it.total AS item_total,
             p.category_id,
             COALESCE(c.name, '') AS category_name
      FROM purchase_return_invoices pri
      JOIN purchase_return_items it ON it.return_id = pri.id
      LEFT JOIN accounts a ON a.id = pri.account_id
      LEFT JOIN products p ON p.id = it.product_id
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE ${where.join(' AND ')}
      ORDER BY pri.return_date, pri.id, it.id
      ''', args);
    return rows
        .map((row) => _PurchaseLine.fromRow(row, isReturn: true))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Grouping / formatting.
  // ---------------------------------------------------------------------------
  String _groupKey(
    _PurchaseLine line,
    PurchaseAnalysisGroup group,
    PurchaseAnalysisMode mode,
  ) {
    if (mode == PurchaseAnalysisMode.detailed) {
      return 'فاتورة ${line.invoiceNumber} · ${line.productName}';
    }
    switch (group) {
      case PurchaseAnalysisGroup.warehouse:
        return 'غير محدد';
      case PurchaseAnalysisGroup.account:
        return line.accountName.trim().isEmpty ? 'بدون حساب' : line.accountName;
      case PurchaseAnalysisGroup.product:
        return line.productName.trim().isEmpty
            ? 'صنف #${line.productId}'
            : line.productName;
      case PurchaseAnalysisGroup.month:
        return '${_monthNames[line.date.month - 1]} ${line.date.year}';
      case PurchaseAnalysisGroup.day:
        return _dateText(line.date);
      case PurchaseAnalysisGroup.user:
        return 'غير متوفر';
      case PurchaseAnalysisGroup.category:
        return line.categoryName.trim().isEmpty
            ? 'بدون تصنيف'
            : line.categoryName;
    }
  }

  String _nameOf(int? id, List<PurchaseAnalysisOption> options) {
    if (id == null) return 'الكل';
    for (final option in options) {
      if (option.id == id) return option.name;
    }
    return 'الكل';
  }

  static String _dateText(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}

/// One joined purchase or purchase-return line.
class _PurchaseLine {
  _PurchaseLine({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.date,
    required this.subtotal,
    required this.invoiceDiscount,
    required this.invoiceAddition,
    required this.isReturn,
    required this.accountName,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.itemTotal,
    required this.categoryName,
  });

  factory _PurchaseLine.fromRow(
    Map<String, dynamic> row, {
    required bool isReturn,
  }) {
    final rawDate = '${row['invoice_date'] ?? ''}';
    return _PurchaseLine(
      invoiceId: (row['invoice_id'] as num?)?.toInt() ?? 0,
      invoiceNumber: '${row['invoice_number'] ?? ''}',
      date: DateTime.tryParse(rawDate) ?? DateTime.now(),
      subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0,
      invoiceDiscount: (row['invoice_discount'] as num?)?.toDouble() ?? 0,
      invoiceAddition: (row['invoice_addition'] as num?)?.toDouble() ?? 0,
      isReturn: isReturn,
      accountName: '${row['account_name'] ?? ''}',
      productId: (row['product_id'] as num?)?.toInt() ?? 0,
      productName: '${row['product_name'] ?? ''}',
      quantity: (row['quantity'] as num?)?.toInt() ?? 0,
      itemTotal: (row['item_total'] as num?)?.toDouble() ?? 0,
      categoryName: '${row['category_name'] ?? ''}',
    );
  }

  final int invoiceId;
  final String invoiceNumber;
  final DateTime date;
  final double subtotal;
  final double invoiceDiscount;
  final double invoiceAddition;
  final bool isReturn;
  final String accountName;
  final int productId;
  final String productName;
  final int quantity;
  final double itemTotal;
  final String categoryName;

  double get _sign => isReturn ? -1 : 1;

  /// The line value after its share of the invoice discount, signed.
  double get netValue {
    if (subtotal <= 0) return 0;
    final discountShare = itemTotal * invoiceDiscount / subtotal;
    return _sign * (itemTotal - discountShare);
  }

  /// The line share of the invoice addition, signed.
  double get allocatedAddition {
    if (subtotal <= 0) return 0;
    return _sign * itemTotal * invoiceAddition / subtotal;
  }
}

/// Mutable accumulator for one report row.
class _Bucket {
  final Set<int> invoiceIds = {};
  int purchaseQty = 0;
  int returnQty = 0;
  double purchaseTotal = 0;
  double returnTotal = 0;
  double expense = 0;
  String subtitle = '';

  int get netQty => purchaseQty - returnQty;
  double get netTotal => purchaseTotal - returnTotal;
  double get totalCost => netTotal + expense;

  void add(_PurchaseLine line) {
    invoiceIds.add(line.invoiceId);
    if (line.isReturn) {
      returnQty += line.quantity;
      returnTotal += -line.netValue;
    } else {
      purchaseQty += line.quantity;
      purchaseTotal += line.netValue;
    }
    expense += line.allocatedAddition;
  }
}
