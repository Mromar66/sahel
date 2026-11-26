import 'package:sqlite3/sqlite3.dart';

import 'package:safwa/core/database/sqlite_database.dart';
import 'package:safwa/features/reports/domain/sales_analysis_models.dart';

/// Builds تقرير تحليل المبيعات from the real sales tables.
///
/// Business rules (see README of the report):
/// - Only `sales_invoices` rows in the selected date range are used; a return
///   (`is_return = 1`) is subtracted from the quantities, sales, cost and
///   discounts of its product/group.
/// - «الإجمالي» is the line total after the line discount, with the invoice
///   level discount allocated proportionally across the invoice lines. Tax is
///   excluded from sales/profit because it is not revenue.
/// - «التكلفة» uses the historical cost snapshot stored on the sales line
///   (`sales_items.unit_cost`), taken from the product purchase price at the
///   moment of sale. Old rows fall back to the current purchase price.
/// - «الربح» = الإجمالي − التكلفة.
/// - Percentages are computed from each row's aggregates; the grand-total
///   percentages are computed from the footer aggregates, never by adding the
///   row percentages.
class SalesAnalysisRepository {
  SalesAnalysisRepository({Database? database})
    : _db = database ?? SqliteDatabase().db;

  final Database _db;

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

  static const List<String> _weekdayNames = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  // ---------------------------------------------------------------------------
  // Filter lookups.
  // ---------------------------------------------------------------------------
  List<SalesAnalysisOption> getAccounts() {
    final rows = _db.select(
      'SELECT id, name FROM accounts WHERE is_active = 1 ORDER BY name',
    );
    return _options(rows, 'حساب');
  }

  List<SalesAnalysisOption> getCategories() {
    final rows = _db.select('SELECT id, name FROM categories ORDER BY name');
    return _options(rows, 'تصنيف');
  }

  List<SalesAnalysisOption> getWarehouses() {
    final rows = _db.select(
      'SELECT id, name FROM warehouses WHERE is_active = 1 ORDER BY id',
    );
    return _options(rows, 'مخزن');
  }

  /// The reference screen has a user filter, but the current database has no
  /// users table. Returning an empty list keeps the control honest instead of
  /// inventing records.
  List<SalesAnalysisOption> getUsers() => const [];

  /// Same as [getUsers]: no sales-representative field exists in the schema.
  List<SalesAnalysisOption> getSalesReps() => const [];

  List<SalesAnalysisOption> _options(
    List<Map<String, dynamic>> rows,
    String fallback,
  ) {
    return rows
        .map(
          (row) => SalesAnalysisOption(
            id: (row['id'] as num).toInt(),
            name: (row['name'] as String?) ?? fallback,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Report.
  // ---------------------------------------------------------------------------
  SalesAnalysisReport buildReport({
    required SalesAnalysisFilters filters,
    required SalesAnalysisGroup group,
    required SalesAnalysisMode mode,
  }) {
    if (filters.from.isAfter(filters.to)) {
      throw const SalesAnalysisException(
        'تاريخ البداية يجب أن يكون قبل تاريخ النهاية.',
      );
    }

    final unavailableReason = group.isUnavailable
        ? 'لا يمكن تجميع هذا التقرير: قاعدة البيانات الحالية لا تحتوي على '
              'جدول ${group == SalesAnalysisGroup.user ? 'للمستخدمين' : 'لمندوبي البيع'}.'
        : null;

    final accountName = _nameOf(filters.accountId, getAccounts());
    final categoryName = _nameOf(filters.categoryId, getCategories());
    final warehouseName = _nameOf(filters.warehouseId, getWarehouses());

    final periodText =
        'من ${_dateText(filters.from)} إلى ${_dateText(filters.to)}';

    if (unavailableReason != null) {
      return SalesAnalysisReport(
        rows: const [],
        totals: const SalesAnalysisTotals(
          invoices: 0,
          currentQty: 0,
          qty: 0,
          total: 0,
          cost: 0,
          profit: 0,
          discount: 0,
          profitToProfit: 0,
          totalToSales: 0,
        ),
        filters: filters,
        group: group,
        mode: mode,
        periodText: periodText,
        unavailableReason: unavailableReason,
        accountName: accountName,
        categoryName: categoryName,
        warehouseName: warehouseName,
        paymentName: _paymentLabel(filters.paymentMethod),
      );
    }

    final lines = _loadLines(filters);
    final warehouseByInvoice = _warehouseByInvoice();
    final totals = _ReportAccumulator();
    final groups = <String, _ReportAccumulator>{};

    for (final line in lines) {
      final key = _groupKey(line, group, mode, warehouseByInvoice);
      final accumulator = groups.putIfAbsent(key, _ReportAccumulator.new);
      accumulator.add(line);
      totals.add(line);
    }

    final grandSales = totals.netTotal;
    final grandProfit = totals.profit;

    final rows = <SalesAnalysisRow>[];
    for (final entry in groups.entries) {
      final acc = entry.value;
      final total = acc.total;
      final cost = acc.cost;
      final profit = acc.profit;
      rows.add(
        SalesAnalysisRow(
          label: entry.key,
          subtitle: mode == SalesAnalysisMode.detailed ? acc.subtitle : '',
          invoices: acc.invoiceIds.length,
          currentQty: acc.currentQty,
          qty: acc.qty,
          total: total,
          cost: cost,
          profit: profit,
          discount: acc.discountRounded,
          profitToTotal: _percent(profit, total),
          profitToCost: _percent(profit, cost),
          totalToSales: grandSales == 0 ? 0 : total / grandSales * 100,
          profitToProfit: grandProfit == 0 ? 0 : profit / grandProfit * 100,
        ),
      );
    }

    rows.sort((a, b) => b.total.compareTo(a.total));

    return SalesAnalysisReport(
      rows: rows,
      totals: SalesAnalysisTotals(
        invoices: totals.invoiceIds.length,
        currentQty: totals.currentQty,
        qty: totals.qty,
        total: totals.total,
        cost: totals.cost,
        profit: totals.profit,
        discount: totals.discountRounded,
        profitToProfit: grandProfit == 0 ? 0 : 100,
        totalToSales: grandSales == 0 ? 0 : 100,
      ),
      filters: filters,
      group: group,
      mode: mode,
      periodText: periodText,
      accountName: accountName,
      categoryName: categoryName,
      warehouseName: warehouseName,
      paymentName: _paymentLabel(filters.paymentMethod),
    );
  }

  // ---------------------------------------------------------------------------
  // SQL loading.
  // ---------------------------------------------------------------------------
  List<_AnalysisLine> _loadLines(SalesAnalysisFilters filters) {
    final where = <String>['si.invoice_date >= ?', 'si.invoice_date <= ?'];
    final args = <Object?>[
      _startOfDay(filters.from).toIso8601String(),
      _endOfDay(filters.to).toIso8601String(),
    ];

    if (filters.accountId != null) {
      where.add('si.account_id = ?');
      args.add(filters.accountId);
    }
    if (filters.categoryId != null) {
      where.add('p.category_id = ?');
      args.add(filters.categoryId);
    }
    if (filters.warehouseId != null) {
      where.add(
        'COALESCE('
        '(SELECT CASE WHEN si.is_return = 1 THEN sm.to_warehouse_id '
        'ELSE sm.from_warehouse_id END FROM stock_movements sm '
        'WHERE sm.reference_id = si.id '
        "AND sm.reference_type = CASE WHEN si.is_return = 1 "
        "THEN 'sales_return' ELSE 'sales_invoice' END "
        'ORDER BY sm.id LIMIT 1), '
        '(SELECT sm_original.from_warehouse_id FROM stock_movements sm_original '
        'WHERE si.is_return = 1 AND sm_original.reference_id = si.original_invoice_id '
        "AND sm_original.reference_type = 'sales_invoice' "
        'ORDER BY sm_original.id LIMIT 1), '
        '(SELECT id FROM warehouses WHERE is_active = 1 ORDER BY id LIMIT 1)) = ?',
      );
      args.add(filters.warehouseId);
    }
    if (filters.paymentMethod == SalesAnalysisFilters.paymentCash) {
      where.add(
        'COALESCE((SELECT o.remaining_amount FROM sales_invoices o '
        'WHERE o.id = si.original_invoice_id), si.remaining_amount) <= 0',
      );
    } else if (filters.paymentMethod == SalesAnalysisFilters.paymentCredit) {
      where.add(
        'COALESCE((SELECT o.remaining_amount FROM sales_invoices o '
        'WHERE o.id = si.original_invoice_id), si.remaining_amount) > 0',
      );
    }

    final rows = _db.select('''
      SELECT si.id AS invoice_id,
             si.invoice_number,
             si.invoice_date,
             si.subtotal,
             COALESCE(si.discount, 0) AS invoice_discount,
             COALESCE(si.tax, 0) AS invoice_tax,
             si.total AS invoice_total,
             COALESCE(si.is_return, 0) AS is_return,
             si.original_invoice_id,
             si.account_id,
             COALESCE(a.name, '') AS account_name,
             it.id AS item_id,
             it.product_id,
             it.product_name,
             it.quantity,
             it.unit_price,
             COALESCE(it.discount, 0) AS item_discount,
             it.total AS item_total,
             COALESCE(p.current_stock, 0) AS current_stock,
             COALESCE(it.unit_cost, p.purchase_price, 0) AS unit_cost,
             p.category_id,
             COALESCE(c.name, '') AS category_name
      FROM sales_invoices si
      JOIN sales_items it ON it.invoice_id = si.id
      LEFT JOIN accounts a ON a.id = si.account_id
      LEFT JOIN products p ON p.id = it.product_id
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE ${where.join(' AND ')}
      ORDER BY si.invoice_date, si.id, it.id
      ''', args);

    return rows.map(_AnalysisLine.fromRow).toList();
  }

  /// Legacy sales without a location use the default warehouse. Returns use
  /// their destination, then the original sale location for legacy rows.
  Map<int, String> _warehouseByInvoice() {
    final rows = _db.select('''
      SELECT si.id AS reference_id,
             COALESCE(w_sale.name, w_return.name, w_original.name,
               (SELECT name FROM warehouses WHERE is_active = 1 ORDER BY id LIMIT 1)
             ) AS name
      FROM sales_invoices si
      LEFT JOIN stock_movements sm
        ON sm.reference_id = si.id
        AND sm.reference_type = CASE WHEN si.is_return = 1
          THEN 'sales_return' ELSE 'sales_invoice' END
      LEFT JOIN warehouses w_sale ON w_sale.id = sm.from_warehouse_id
      LEFT JOIN warehouses w_return ON w_return.id = sm.to_warehouse_id
      LEFT JOIN stock_movements sm_original
        ON si.is_return = 1
        AND sm_original.reference_id = si.original_invoice_id
        AND sm_original.reference_type = 'sales_invoice'
      LEFT JOIN warehouses w_original
        ON w_original.id = sm_original.from_warehouse_id
      ORDER BY si.id, sm.id
      ''');
    final result = <int, String>{};
    for (final row in rows) {
      final id = (row['reference_id'] as num?)?.toInt();
      if (id == null || result.containsKey(id)) continue;
      result[id] = '${row['name'] ?? ''}';
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Grouping / formatting.
  // ---------------------------------------------------------------------------
  String _groupKey(
    _AnalysisLine line,
    SalesAnalysisGroup group,
    SalesAnalysisMode mode,
    Map<int, String> warehouseByInvoice,
  ) {
    if (mode == SalesAnalysisMode.detailed) {
      return 'فاتورة ${line.invoiceNumber} · ${line.productName}';
    }
    switch (group) {
      case SalesAnalysisGroup.warehouse:
        final name = warehouseByInvoice[line.invoiceId];
        return (name == null || name.trim().isEmpty) ? 'غير محدد' : name;
      case SalesAnalysisGroup.account:
        return line.accountName.trim().isEmpty ? 'بدون حساب' : line.accountName;
      case SalesAnalysisGroup.product:
        return line.productName.trim().isEmpty
            ? 'صنف #${line.productId}'
            : line.productName;
      case SalesAnalysisGroup.category:
        return line.categoryName.trim().isEmpty
            ? 'بدون تصنيف'
            : line.categoryName;
      case SalesAnalysisGroup.month:
        return '${_monthNames[line.date.month - 1]} ${line.date.year}';
      case SalesAnalysisGroup.day:
        return _dateText(line.date);
      case SalesAnalysisGroup.year:
        return '${line.date.year}';
      case SalesAnalysisGroup.time:
        return '${line.date.hour.toString().padLeft(2, '0')}:00';
      case SalesAnalysisGroup.weekday:
        return _weekdayNames[line.date.weekday - 1];
      case SalesAnalysisGroup.user:
      case SalesAnalysisGroup.salesRep:
        return 'غير متوفر';
    }
  }

  static double _percent(num numerator, num denominator) {
    if (denominator == 0) return 0;
    final value = numerator / denominator * 100;
    return value == 0 ? 0 : value;
  }

  static String _dateText(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  static String _paymentLabel(String value) {
    switch (value) {
      case SalesAnalysisFilters.paymentCash:
        return 'نقدي';
      case SalesAnalysisFilters.paymentCredit:
        return 'أجل';
      default:
        return 'الكل';
    }
  }

  String _nameOf(int? id, List<SalesAnalysisOption> options) {
    if (id == null) return 'الكل';
    for (final option in options) {
      if (option.id == id) return option.name;
    }
    return 'الكل';
  }
}

/// One joined sales line, with its invoice and product context.
class _AnalysisLine {
  _AnalysisLine({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.date,
    required this.subtotal,
    required this.invoiceDiscount,
    required this.invoiceTax,
    required this.invoiceTotal,
    required this.isReturn,
    required this.accountName,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.itemDiscount,
    required this.itemTotal,
    required this.currentStock,
    required this.unitCost,
    required this.categoryName,
  });

  factory _AnalysisLine.fromRow(Map<String, dynamic> row) {
    final rawDate = '${row['invoice_date'] ?? ''}';
    return _AnalysisLine(
      invoiceId: (row['invoice_id'] as num?)?.toInt() ?? 0,
      invoiceNumber: '${row['invoice_number'] ?? ''}',
      date: DateTime.tryParse(rawDate) ?? DateTime.now(),
      subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0,
      invoiceDiscount: (row['invoice_discount'] as num?)?.toDouble() ?? 0,
      invoiceTax: (row['invoice_tax'] as num?)?.toDouble() ?? 0,
      invoiceTotal: (row['invoice_total'] as num?)?.toDouble() ?? 0,
      isReturn: ((row['is_return'] as num?)?.toInt() ?? 0) == 1,
      accountName: '${row['account_name'] ?? ''}',
      productId: (row['product_id'] as num?)?.toInt() ?? 0,
      productName: '${row['product_name'] ?? ''}',
      quantity: (row['quantity'] as num?)?.toInt() ?? 0,
      itemDiscount: (row['item_discount'] as num?)?.toDouble() ?? 0,
      itemTotal: (row['item_total'] as num?)?.toDouble() ?? 0,
      currentStock: (row['current_stock'] as num?)?.toInt() ?? 0,
      unitCost: (row['unit_cost'] as num?)?.toInt() ?? 0,
      categoryName: '${row['category_name'] ?? ''}',
    );
  }

  final int invoiceId;
  final String invoiceNumber;
  final DateTime date;
  final double subtotal;
  final double invoiceDiscount;
  final double invoiceTax;
  final double invoiceTotal;
  final bool isReturn;
  final String accountName;
  final int productId;
  final String productName;
  final int quantity;
  final double itemDiscount;
  final double itemTotal;
  final int currentStock;
  final int unitCost;
  final String categoryName;

  /// Signed quantity, net of returns.
  int get netQty => isReturn ? -quantity : quantity;

  /// Line total after the proportional share of the invoice-level discount;
  /// tax is excluded. Returns are negative.
  double get netSales {
    final sign = isReturn ? -1 : 1;
    if (subtotal <= 0) return 0;
    final revenue = invoiceTotal - invoiceTax;
    return sign * itemTotal * (revenue / subtotal);
  }

  /// Line discount plus the proportional share of the invoice discount.
  double get netDiscount {
    final sign = isReturn ? -1 : 1;
    final invoiceShare = subtotal <= 0
        ? 0.0
        : itemTotal * invoiceDiscount / subtotal;
    return sign * (itemDiscount + invoiceShare);
  }

  int get netCost => netQty * unitCost;
}

/// Mutable group accumulator.
class _ReportAccumulator {
  final Set<int> invoiceIds = {};
  final Map<int, int> productStocks = {};
  int qty = 0;
  double _netSales = 0;
  double _rawCost = 0;
  double _rawDiscount = 0;
  String subtitle = '';

  void add(_AnalysisLine line) {
    invoiceIds.add(line.invoiceId);
    productStocks[line.productId] = line.currentStock;
    qty += line.netQty;
    _netSales += line.netSales;
    _rawCost += line.netCost;
    _rawDiscount += line.netDiscount;
    if (subtitle.isEmpty) {
      subtitle =
          '${_formatDate(line.date)} · ${line.invoiceNumber} · ${line.accountName}';
    }
  }

  double get netTotal => _netSales;

  int get total => _netSales.round();
  int get cost => _rawCost.round();

  int get profit => (_netSales - _rawCost).round();

  int get currentQty =>
      productStocks.values.fold<int>(0, (sum, value) => sum + value);

  int get discountRounded => _rawDiscount.round();

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  String toString() => 'invoices: ${invoiceIds.length}, total: $total';
}
