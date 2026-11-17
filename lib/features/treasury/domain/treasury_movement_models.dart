/// Domain models for the treasury movement screen (حركة الخزينة).
///
/// The screen works on the existing `treasury_transactions` ledger. Every row
/// still stores a positive `amount`; the direction is carried by
/// `transaction_type` exactly like the legacy invoice flows expect:
/// `receive` increases the treasury balance and `expense` decreases it.
library;

class TreasuryAccount {
  const TreasuryAccount({
    required this.id,
    required this.name,
    required this.openingBalance,
    required this.isActive,
    this.description,
  });

  final int id;
  final String name;
  final int openingBalance;
  final bool isActive;
  final String? description;
}

class TreasuryMovement {
  const TreasuryMovement({
    required this.id,
    required this.transactionNumber,
    required this.treasuryId,
    required this.treasuryName,
    required this.date,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.description,
    this.notes,
    this.category,
    this.referenceId,
    this.referenceType,
    this.isTransfer = false,
    this.transferGroup,
    this.peerTreasuryId,
    this.isSynthetic = false,
    this.incomingAmount,
    this.outgoingAmount,
  });

  final int id;
  final String transactionNumber;
  final int treasuryId;
  final String treasuryName;
  final DateTime date;

  /// `receive`, `expense` or `transfer` (the legacy types).
  final String type;
  final int amount;
  final int balanceAfter;
  final String? description;
  final String? notes;
  final String? category;
  final int? referenceId;
  final String? referenceType;
  final bool isTransfer;
  final String? transferGroup;
  final int? peerTreasuryId;

  /// A previous-balance or totals row injected into the movements grid.
  final bool isSynthetic;

  /// Explicit totals carried by the synthetic totals row. Regular rows derive
  /// their incoming/outgoing value from [type] and [amount].
  final int? incomingAmount;
  final int? outgoingAmount;

  bool get isIncoming => type == 'receive';
  bool get isOutgoing => type == 'expense';
  int get displayIncoming => incomingAmount ?? (isIncoming ? amount : 0);
  int get displayOutgoing => outgoingAmount ?? (isOutgoing ? amount : 0);
  bool get hasReference =>
      referenceId != null &&
      referenceType != null &&
      referenceType != 'manual' &&
      referenceType != 'treasury';

  String get typeLabel {
    if (isTransfer) {
      return isIncoming ? 'تحويل وارد' : 'تحويل صادر';
    }
    if (type == 'receive') return 'قبض';
    if (type == 'expense') return 'صرف';
    return 'حركة';
  }

  String get categoryLabel {
    if (isTransfer) return 'تحويل داخلي';
    if (type == 'receive') {
      switch (referenceType) {
        case 'sales_invoice':
          return 'مبيعات';
        case 'purchase_return':
          return 'مرتجع شراء';
        default:
          return category?.trim().isNotEmpty == true ? category! : 'قبض نقدي';
      }
    }
    if (type == 'expense') {
      if (category?.trim().isNotEmpty == true) return category!;
      switch (referenceType) {
        case 'purchase_invoice':
          return 'سداد مشتريات';
        case 'sales_return':
          return 'مرتجع مبيعات';
        default:
          return 'مصروف نقدي';
      }
    }
    return '-';
  }

  String get referenceLabel => (transferGroup?.trim().isNotEmpty == true)
      ? transferGroup!
      : transactionNumber;

  String get descriptionLabel => (description?.trim().isNotEmpty == true)
      ? description!
      : (notes?.trim().isNotEmpty == true ? notes! : '—');

  TreasuryMovement copyWith({int? balanceAfter}) => TreasuryMovement(
    id: id,
    transactionNumber: transactionNumber,
    treasuryId: treasuryId,
    treasuryName: treasuryName,
    date: date,
    type: type,
    amount: amount,
    balanceAfter: balanceAfter ?? this.balanceAfter,
    description: description,
    notes: notes,
    category: category,
    referenceId: referenceId,
    referenceType: referenceType,
    isTransfer: isTransfer,
    transferGroup: transferGroup,
    peerTreasuryId: peerTreasuryId,
    isSynthetic: isSynthetic,
    incomingAmount: incomingAmount,
    outgoingAmount: outgoingAmount,
  );

  factory TreasuryMovement.previous({
    required DateTime date,
    required int balance,
    required String treasuryName,
  }) => TreasuryMovement(
    id: -1,
    transactionNumber: '',
    treasuryId: -1,
    treasuryName: treasuryName,
    date: date,
    type: 'previous',
    amount: 0,
    balanceAfter: balance,
    isSynthetic: true,
  );

  factory TreasuryMovement.total({
    required DateTime date,
    required int incoming,
    required int outgoing,
    required int balance,
    required String treasuryName,
  }) => TreasuryMovement(
    id: -2,
    transactionNumber: '',
    treasuryId: -2,
    treasuryName: treasuryName,
    date: date,
    type: 'total',
    amount: incoming - outgoing,
    balanceAfter: balance,
    isSynthetic: true,
    incomingAmount: incoming,
    outgoingAmount: outgoing,
  );
}

class TreasurySummaryRow {
  const TreasurySummaryRow({
    required this.treasuryId,
    required this.treasuryName,
    required this.previousBalance,
    required this.incoming,
    required this.outgoing,
    required this.balance,
    this.isTotal = false,
  });

  final int treasuryId;
  final String treasuryName;
  final int previousBalance;
  final int incoming;
  final int outgoing;
  final int balance;
  final bool isTotal;
}

class TreasuryFilters {
  const TreasuryFilters({
    required this.from,
    required this.to,
    this.treasuryId,
    this.numberQuery = '',
    this.notesQuery = '',
  });

  final DateTime from;
  final DateTime to;
  final int? treasuryId;
  final String numberQuery;
  final String notesQuery;

  TreasuryFilters copyWith({
    DateTime? from,
    DateTime? to,
    int? treasuryId,
    String? numberQuery,
    String? notesQuery,
    bool clearTreasury = false,
  }) => TreasuryFilters(
    from: from ?? this.from,
    to: to ?? this.to,
    treasuryId: clearTreasury ? null : (treasuryId ?? this.treasuryId),
    numberQuery: numberQuery ?? this.numberQuery,
    notesQuery: notesQuery ?? this.notesQuery,
  );
}

class TreasuryReport {
  const TreasuryReport({
    required this.summary,
    required this.movements,
    required this.previousBalance,
    required this.incoming,
    required this.outgoing,
    required this.currentBalance,
    required this.filters,
  });

  final List<TreasurySummaryRow> summary;
  final List<TreasuryMovement> movements;
  final int previousBalance;
  final int incoming;
  final int outgoing;
  final int currentBalance;
  final TreasuryFilters filters;

  int get netMovement => incoming - outgoing;

  String get treasuryName {
    if (filters.treasuryId == null) return 'كل الخزائن';
    for (final row in summary) {
      if (row.treasuryId == filters.treasuryId && !row.isTotal) {
        return row.treasuryName;
      }
    }
    return 'الخزينة';
  }
}

class TreasuryMovementInput {
  const TreasuryMovementInput({
    required this.treasuryId,
    required this.date,
    required this.amount,
    required this.description,
    this.notes = '',
    this.category = '',
    this.customFields = const {},
  });

  final int treasuryId;
  final DateTime date;
  final int amount;
  final String description;
  final String notes;
  final String category;
  final Map<int, String> customFields;
}

class TreasuryTransferInput {
  const TreasuryTransferInput({
    required this.sourceTreasuryId,
    required this.destinationTreasuryId,
    required this.date,
    required this.amount,
    required this.description,
    this.customFields = const {},
  });

  final int sourceTreasuryId;
  final int destinationTreasuryId;
  final DateTime date;
  final int amount;
  final String description;
  final Map<int, String> customFields;
}

class TreasuryAnalysisRow {
  const TreasuryAnalysisRow({
    required this.label,
    required this.count,
    required this.amount,
    required this.share,
  });

  final String label;
  final int count;
  final int amount;
  final double share;
}

class TreasuryValidationException implements Exception {
  const TreasuryValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
