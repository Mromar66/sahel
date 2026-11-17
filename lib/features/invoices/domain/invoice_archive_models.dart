/// Domain models for the الفواتير document archive.
///
/// Every archive tab maps to one real document family in the existing
/// database. The archive never keeps a shadow copy of the data: it reads the
/// same tables that the invoice, purchase, stocktaking and accounts screens
/// write.
library;

/// The ten document families shown in the reference tab bar, in RTL order.
enum ArchiveDocType {
  sale('بيع', 'فاتورة بيع'),
  salesReturn('مرتجع بيع', 'مرتجع بيع'),
  quotation('عرض أسعار', 'عرض سعر'),
  purchase('شراء', 'فاتورة شراء'),
  purchaseReturn('مرتجع شراء', 'مرتجع شراء'),
  receipt('قبض', 'سند قبض'),
  payment('صرف', 'سند صرف'),
  stocktaking('جرد مخزن', 'مستند جرد'),
  transfer('تحويل لمخزن', 'تحويل مخزن'),
  adjustment('تسوية مخزن', 'تسوية مخزن');

  const ArchiveDocType(this.label, this.documentLabel);

  final String label;
  final String documentLabel;

  bool get isSale => this == ArchiveDocType.sale;
  bool get isSalesReturn => this == ArchiveDocType.salesReturn;
  bool get isQuotation => this == ArchiveDocType.quotation;
  bool get isPurchase => this == ArchiveDocType.purchase;
  bool get isPurchaseReturn => this == ArchiveDocType.purchaseReturn;
  bool get isReceipt => this == ArchiveDocType.receipt;
  bool get isPayment => this == ArchiveDocType.payment;
  bool get isStocktaking => this == ArchiveDocType.stocktaking;
  bool get isTransfer => this == ArchiveDocType.transfer;
  bool get isAdjustment => this == ArchiveDocType.adjustment;

  bool get isInvoice =>
      isSale || isSalesReturn || isPurchase || isPurchaseReturn || isQuotation;

  bool get isVoucher => isReceipt || isPayment;

  bool get isStockDocument => isStocktaking || isTransfer || isAdjustment;

  /// A real account relationship exists on invoice and voucher documents.
  bool get hasAccount => isInvoice || isVoucher;

  /// Stock documents store a warehouse directly.
  bool get hasWarehouse => isStocktaking || isTransfer || isAdjustment;

  /// Payment figures are part of the document row.
  bool get hasPayments =>
      isSale || isSalesReturn || isPurchase || isPurchaseReturn || isQuotation;

  /// Only sale/purchase documents have a meaningful paid/partial/unpaid state.
  bool get hasPaymentStatus =>
      isSale || isSalesReturn || isPurchase || isPurchaseReturn;

  /// Cash/credit is recorded for invoices and for receipt/payment vouchers.
  bool get hasPaymentMethod => hasPaymentStatus || isVoucher;

  /// Quotations expose open/converted; stock documents expose applied/draft.
  bool get hasDocumentStatus => isQuotation || isStockDocument;

  /// Only documents that can actually write treasury rows expose the treasury
  /// filter. Vouchers in this application do not create treasury movements.
  bool get hasTreasury =>
      isSale || isSalesReturn || isPurchase || isPurchaseReturn;

  bool get hasItems =>
      isSale ||
      isSalesReturn ||
      isQuotation ||
      isPurchase ||
      isPurchaseReturn ||
      isStocktaking ||
      isTransfer ||
      isAdjustment;

  /// The current schema has no invoice -> sales representative / creator link,
  /// so those filters are displayed but not silently faked.
  bool get hasSalesRep => false;

  bool get hasUser => false;

  String get stockReferenceType => switch (this) {
    ArchiveDocType.sale => 'sales_invoice',
    ArchiveDocType.salesReturn => 'sales_return',
    ArchiveDocType.purchase => 'purchase_invoice',
    ArchiveDocType.purchaseReturn => 'purchase_return',
    ArchiveDocType.stocktaking => 'stocktaking_session',
    ArchiveDocType.transfer => 'stock_transfer',
    ArchiveDocType.adjustment => 'stock_adjustment',
    _ => '',
  };

  String get customFieldType => switch (this) {
    ArchiveDocType.sale => 'sale',
    ArchiveDocType.salesReturn => 'sales_return',
    ArchiveDocType.purchase => 'purchase',
    ArchiveDocType.purchaseReturn => 'purchase_return',
    ArchiveDocType.quotation => 'quotation',
    ArchiveDocType.receipt => 'receipt',
    ArchiveDocType.payment => 'payment',
    ArchiveDocType.stocktaking => 'stocktaking',
    ArchiveDocType.transfer => 'warehouse_transfer',
    ArchiveDocType.adjustment => 'warehouse_adjustment',
  };

  /// Route used by the تعديل action. `null` for document families that do not
  /// have an editable screen.
  String? get editRoute => switch (this) {
    ArchiveDocType.sale => '/sales',
    ArchiveDocType.salesReturn => '/sales-return',
    ArchiveDocType.quotation => '/quotation',
    ArchiveDocType.purchase => '/purchases',
    ArchiveDocType.purchaseReturn => '/purchase-return',
    ArchiveDocType.receipt => '/accounts/receipt',
    ArchiveDocType.payment => '/accounts/payment',
    ArchiveDocType.stocktaking => '/stocktaking',
    ArchiveDocType.transfer => '/transfer',
    ArchiveDocType.adjustment => '/adjustment',
  };
}

/// A search option loaded from a real lookup table.
class ArchiveOption {
  const ArchiveOption(this.id, this.name);

  final int id;
  final String name;
}

/// A string-valued lookup option (account classification, document status).
class ArchiveStringOption {
  const ArchiveStringOption(this.value, this.name);

  final String value;
  final String name;
}

/// The combined filter state of both search modes.
///
/// General mode uses the reference fields; advanced mode adds amount, exact
/// number, item/barcode, notes and status. All values are combined with AND.
class ArchiveFilters {
  const ArchiveFilters({
    this.fromDate,
    this.toDate,
    this.fromTime,
    this.toTime,
    this.warehouseId,
    this.accountId,
    this.treasuryId,
    this.categoryId,
    this.userId,
    this.salesRepId,
    this.accountType = '',
    this.paymentMethod = 'all',
    this.paymentStatus = 'all',
    this.invoiceNumber = '',
    this.exactNumber = '',
    this.minAmount,
    this.maxAmount,
    this.itemName = '',
    this.itemCode = '',
    this.barcode = '',
    this.partyName = '',
    this.notes = '',
    this.documentStatus = 'all',
  });

  final DateTime? fromDate;
  final DateTime? toDate;

  /// 24-hour `HH:mm` strings from the time pickers.
  final String? fromTime;
  final String? toTime;

  final int? warehouseId;
  final int? accountId;
  final int? treasuryId;
  final int? categoryId;
  final int? userId;
  final int? salesRepId;

  /// Accounts table classification: customer / supplier.
  final String accountType;

  /// all / cash / credit.
  final String paymentMethod;

  /// all / paid / partial / unpaid.
  final String paymentStatus;

  /// Partial invoice / reference number.
  final String invoiceNumber;

  /// Exact number used by advanced search.
  final String exactNumber;

  final int? minAmount;
  final int? maxAmount;
  final String itemName;
  final String itemCode;
  final String barcode;
  final String partyName;
  final String notes;

  /// all / applied / draft / open / converted.
  final String documentStatus;

  bool get hasDateRange => fromDate != null || toDate != null;

  bool get hasTimeRange =>
      (fromTime != null && fromTime!.isNotEmpty) ||
      (toTime != null && toTime!.isNotEmpty);

  /// Returns an Arabic validation message, or null when the range is valid.
  String? validate() {
    if (fromDate != null && toDate != null && fromDate!.isAfter(toDate!)) {
      return 'تاريخ البداية يجب أن يكون قبل تاريخ النهاية.';
    }
    if (fromTime != null &&
        toTime != null &&
        fromTime!.isNotEmpty &&
        toTime!.isNotEmpty &&
        fromTime!.compareTo(toTime!) > 0 &&
        fromDate != null &&
        toDate != null &&
        _sameDay(fromDate!, toDate!)) {
      return 'وقت البداية يجب أن يكون قبل وقت النهاية.';
    }
    if (minAmount != null && maxAmount != null && minAmount! > maxAmount!) {
      return 'أقل مبلغ يجب أن يكون أقل من أكبر مبلغ.';
    }
    if (minAmount != null && minAmount! < 0) {
      return 'أقل مبلغ لا يمكن أن يكون سالباً.';
    }
    return null;
  }

  /// Start of the selected date/time window as an ISO string.
  String get startIso {
    final date = fromDate ?? DateTime(2000, 1, 1);
    final time = _timeParts(fromTime);
    return _iso(DateTime(date.year, date.month, date.day, time.$1, time.$2, 0));
  }

  /// End of the selected date/time window as an ISO string.
  String get endIso {
    final date = toDate ?? DateTime(2100, 12, 31);
    final time = _timeParts(toTime, endOfDay: true);
    return _iso(
      DateTime(date.year, date.month, date.day, time.$1, time.$2, 59, 999),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static (int, int) _timeParts(String? value, {bool endOfDay = false}) {
    if (value == null || value.trim().isEmpty) {
      return endOfDay ? (23, 59) : (0, 0);
    }
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (hour.clamp(0, 23), minute.clamp(0, 59));
  }

  static String _iso(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}'
        'T${two(value.hour)}:${two(value.minute)}:${two(value.second)}'
        '.${value.millisecond.toString().padLeft(3, '0')}';
  }

  ArchiveFilters copyWith({
    Object? fromDate = _unset,
    Object? toDate = _unset,
    Object? fromTime = _unset,
    Object? toTime = _unset,
    Object? warehouseId = _unset,
    Object? accountId = _unset,
    Object? treasuryId = _unset,
    Object? categoryId = _unset,
    Object? userId = _unset,
    Object? salesRepId = _unset,
    String? accountType,
    String? paymentMethod,
    String? paymentStatus,
    String? invoiceNumber,
    String? exactNumber,
    Object? minAmount = _unset,
    Object? maxAmount = _unset,
    String? itemName,
    String? itemCode,
    String? barcode,
    String? partyName,
    String? notes,
    String? documentStatus,
  }) {
    return ArchiveFilters(
      fromDate: identical(fromDate, _unset)
          ? this.fromDate
          : fromDate as DateTime?,
      toDate: identical(toDate, _unset) ? this.toDate : toDate as DateTime?,
      fromTime: identical(fromTime, _unset)
          ? this.fromTime
          : fromTime as String?,
      toTime: identical(toTime, _unset) ? this.toTime : toTime as String?,
      warehouseId: identical(warehouseId, _unset)
          ? this.warehouseId
          : warehouseId as int?,
      accountId: identical(accountId, _unset)
          ? this.accountId
          : accountId as int?,
      treasuryId: identical(treasuryId, _unset)
          ? this.treasuryId
          : treasuryId as int?,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as int?,
      userId: identical(userId, _unset) ? this.userId : userId as int?,
      salesRepId: identical(salesRepId, _unset)
          ? this.salesRepId
          : salesRepId as int?,
      accountType: accountType ?? this.accountType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      exactNumber: exactNumber ?? this.exactNumber,
      minAmount: identical(minAmount, _unset)
          ? this.minAmount
          : minAmount as int?,
      maxAmount: identical(maxAmount, _unset)
          ? this.maxAmount
          : maxAmount as int?,
      itemName: itemName ?? this.itemName,
      itemCode: itemCode ?? this.itemCode,
      barcode: barcode ?? this.barcode,
      partyName: partyName ?? this.partyName,
      notes: notes ?? this.notes,
      documentStatus: documentStatus ?? this.documentStatus,
    );
  }

  static const Object _unset = Object();
}

/// One document row in the archive grid.
class ArchiveDocument {
  const ArchiveDocument({
    required this.type,
    required this.id,
    required this.number,
    required this.date,
    required this.accountId,
    required this.accountName,
    required this.warehouseName,
    required this.total,
    required this.discount,
    required this.tax,
    required this.paid,
    required this.remaining,
    required this.status,
    required this.paymentMethod,
    required this.notes,
    required this.originalNumber,
    required this.itemCount,
    required this.applied,
    required this.createdAt,
  });

  final ArchiveDocType type;
  final int id;
  final String number;
  final DateTime? date;
  final int? accountId;
  final String accountName;
  final String warehouseName;
  final int total;
  final int discount;
  final int tax;
  final int paid;
  final int remaining;
  final String status;
  final String paymentMethod;
  final String notes;
  final String originalNumber;
  final int itemCount;
  final bool applied;
  final DateTime? createdAt;

  String get dateText => date == null
      ? ''
      : '${date!.day.toString().padLeft(2, '0')}/'
            '${date!.month.toString().padLeft(2, '0')}/${date!.year}';

  String get timeText {
    if (date == null) return '';
    final hour = date!.hour % 12 == 0 ? 12 : date!.hour % 12;
    return '${hour.toString().padLeft(2, '0')}:'
        '${date!.minute.toString().padLeft(2, '0')} '
        '${date!.hour < 12 ? 'AM' : 'PM'}';
  }

  String get paymentStatusLabel => switch (status) {
    'paid' => 'مدفوع',
    'partial' => 'مدفوع جزئياً',
    'unpaid' => 'غير مدفوع',
    'open' => 'مفتوح',
    'converted' => 'محوّل',
    'applied' => 'مُرحّل',
    'draft' => 'غير مُرحّل',
    _ => status,
  };

  String get paymentMethodLabel => switch (paymentMethod) {
    'cash' => 'نقدي',
    'card' => 'بطاقة',
    'bank' => 'تحويل بنكي',
    'check' => 'شيك',
    'credit' => 'آجل',
    _ => '',
  };
}

/// One line item row in the عرض الأصناف grid.
class ArchiveItem {
  const ArchiveItem({
    required this.type,
    required this.documentId,
    required this.documentNumber,
    required this.date,
    required this.accountName,
    required this.warehouseName,
    required this.itemName,
    required this.itemCode,
    required this.barcode,
    required this.unitName,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.lineTotal,
    required this.extraLabel,
    required this.extraValue,
    required this.notes,
  });

  final ArchiveDocType type;
  final int documentId;
  final String documentNumber;
  final DateTime? date;
  final String accountName;
  final String warehouseName;
  final String itemName;
  final String itemCode;
  final String barcode;
  final String unitName;
  final int quantity;
  final int unitPrice;
  final int discount;
  final int lineTotal;
  final String extraLabel;
  final String extraValue;
  final String notes;

  String get dateText => date == null
      ? ''
      : '${date!.day.toString().padLeft(2, '0')}/'
            '${date!.month.toString().padLeft(2, '0')}/${date!.year}';
}

/// Aggregates shown under the grid and used by report printing.
class ArchiveTotals {
  const ArchiveTotals({
    this.count = 0,
    this.total = 0,
    this.discount = 0,
    this.tax = 0,
    this.paid = 0,
    this.remaining = 0,
    this.quantity = 0,
  });

  final int count;
  final int total;
  final int discount;
  final int tax;
  final int paid;
  final int remaining;
  final int quantity;
}

/// One page of document results.
class ArchiveDocumentPage {
  const ArchiveDocumentPage({
    required this.rows,
    required this.totalCount,
    required this.totals,
    required this.hasMore,
  });

  final List<ArchiveDocument> rows;
  final int totalCount;
  final ArchiveTotals totals;
  final bool hasMore;
}

/// One page of item results.
class ArchiveItemPage {
  const ArchiveItemPage({
    required this.rows,
    required this.totalCount,
    required this.totals,
    required this.hasMore,
  });

  final List<ArchiveItem> rows;
  final int totalCount;
  final ArchiveTotals totals;
  final bool hasMore;
}

/// Sortable document columns. `label` sorts by account / notes / number.
enum ArchiveSortField { date, number, account, total, paid, remaining, status }

/// Sortable item columns.
enum ArchiveItemSortField { date, number, item, quantity, total }

class ArchiveSort {
  const ArchiveSort({
    this.field = ArchiveSortField.date,
    this.ascending = false,
  });

  final ArchiveSortField field;
  final bool ascending;
}

class ArchiveItemSort {
  const ArchiveItemSort({
    this.field = ArchiveItemSortField.date,
    this.ascending = false,
  });

  final ArchiveItemSortField field;
  final bool ascending;
}

/// Loaded document header + lines used by printing and the document viewer.
class ArchiveDocumentDetail {
  const ArchiveDocumentDetail({
    required this.type,
    required this.header,
    required this.items,
  });

  final ArchiveDocType type;
  final Map<String, Object?> header;
  final List<Map<String, Object?>> items;
}

/// Arabic error raised by the archive business rules.
class ArchiveException implements Exception {
  ArchiveException(this.message);

  final String message;

  @override
  String toString() => message;
}
