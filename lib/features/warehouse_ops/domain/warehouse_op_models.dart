/// Domain models for the two warehouse documents that share the جرد مخزن
/// screen layout: تسوية مخزن (stock adjustment) and تحويل لمخزن (stock
/// transfer).
///
/// Both documents are deliberately independent from the stocktaking and
/// purchase features: they reuse the read-only product catalogue and the
/// shared widgets, but every document has its own tables, numbering and
/// posting rules.
library;

import 'package:inventory_app/features/stocktaking/domain/stocktaking_models.dart';

/// The product row shown by the lookup dialogs is exactly the same read-only
/// catalogue record used by جرد مخزن, so it is reused instead of duplicated.
typedef WarehouseOpProduct = StocktakingProduct;

/// A warehouse that a schema-supported document can be attached to.
typedef WarehouseOpWarehouse = StocktakingWarehouse;

/// Which warehouse document the shared screen is currently showing.
enum WarehouseOpKind {
  adjustment,
  transfer;

  bool get isTransfer => this == WarehouseOpKind.transfer;

  /// Screen title (right strip + tab).
  String get title => switch (this) {
    WarehouseOpKind.adjustment => 'تسوية مخزن',
    WarehouseOpKind.transfer => 'تحويل لمخزن',
  };

  /// Tab caption shown in the top navigation bar.
  String get tabLabel => '$title | جديد';

  /// Short noun used inside messages: «مستند تسوية» / «مستند تحويل».
  String get documentName => switch (this) {
    WarehouseOpKind.adjustment => 'مستند تسوية',
    WarehouseOpKind.transfer => 'مستند تحويل',
  };

  /// Title used by the print preview.
  String get printTitle => switch (this) {
    WarehouseOpKind.adjustment => 'مستند تسوية مخزن',
    WarehouseOpKind.transfer => 'مستند تحويل مخزن',
  };

  /// File-name prefix used by the Excel export.
  String get exportPrefix => switch (this) {
    WarehouseOpKind.adjustment => 'adjustment',
    WarehouseOpKind.transfer => 'transfer',
  };

  /// Toast shown when the operator clicks the teal title tile.
  String get stripMessage => this == WarehouseOpKind.adjustment
      ? 'أنت الآن في شاشة تسوية المخزن.'
      : 'أنت الآن في شاشة تحويل المخزن.';

  /// Shortcuts-dialog title.
  String get shortcutsTitle => this == WarehouseOpKind.adjustment
      ? 'اختصارات شاشة التسوية'
      : 'اختصارات شاشة التحويل';
}

/// One editable line of the adjustment / transfer table.
///
/// The columns mirror جرد مخزن exactly: the recorded quantity, the entered
/// quantity, the unit price and the line total.
class WarehouseOpLine {
  WarehouseOpLine({
    this.productId,
    required this.code,
    required this.name,
    required this.unit,
    required this.available,
    required this.qty,
    required this.price,
  });

  int? productId;
  String code;
  String name;
  String unit;

  /// Quantity recorded in the inventory before the document.
  int available;

  /// Quantity entered by the operator (adjusted / transferred).
  int qty;
  int price;

  /// qty * price, the value shown in the «الإجمالي» column.
  int get gross => qty * price;

  /// qty - available. For an adjustment this is the change posted to stock.
  int get difference => qty - available;

  WarehouseOpLine clone() => WarehouseOpLine(
    productId: productId,
    code: code,
    name: name,
    unit: unit,
    available: available,
    qty: qty,
    price: price,
  );
}

/// Result of a successful save.
class WarehouseOpSaveResult {
  const WarehouseOpSaveResult({
    required this.sessionId,
    required this.sessionNumber,
    required this.total,
    required this.itemsCount,
    required this.changedCount,
    required this.applied,
  });

  final int sessionId;
  final String sessionNumber;
  final int total;
  final int itemsCount;
  final int changedCount;

  /// Whether the document was posted (stock updated / movements written).
  final bool applied;
}

/// Thrown when the document does not satisfy the business rules.
class WarehouseOpValidationException implements Exception {
  WarehouseOpValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One saved line loaded back into the adjustment / transfer screen.
class WarehouseOpEditLine {
  const WarehouseOpEditLine({
    required this.productId,
    required this.name,
    required this.code,
    required this.unit,
    required this.available,
    required this.qty,
    required this.price,
  });

  final int? productId;
  final String name;
  final String code;
  final String unit;
  final int available;
  final int qty;
  final int price;
}

/// A saved adjustment / transfer document loaded for editing.
class WarehouseOpEditData {
  const WarehouseOpEditData({
    required this.id,
    required this.number,
    required this.warehouseId,
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.date,
    required this.time,
    required this.notes,
    required this.applied,
    required this.lines,
    required this.customFields,
  });

  final int id;
  final String number;
  final int? warehouseId;
  final int? fromWarehouseId;
  final int? toWarehouseId;
  final DateTime? date;
  final String time;
  final String notes;
  final bool applied;
  final List<WarehouseOpEditLine> lines;
  final Map<int, String> customFields;
}
