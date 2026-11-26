/// Domain models for the جرد مخزن (warehouse stocktaking) screen.
///
/// Kept independent from the purchase models on purpose: the two documents
/// share widgets but never share business rules.
library;

import 'package:safwa/app/models/product_search_item.dart';

/// A product row returned by the stocktaking product search.
class StocktakingProduct implements ProductSearchItem {
  const StocktakingProduct({
    required this.id,
    required this.name,
    required this.code,
    required this.barcode,
    required this.unitName,
    required this.available,
    required this.purchasePrice,
    required this.sellingPrice,
  });

  @override
  final int id;

  @override
  final String name;

  @override
  final String code;

  @override
  final String? barcode;

  @override
  final String unitName;

  /// The quantity currently recorded in the inventory (`products.current_stock`).
  @override
  final int available;

  @override
  final int purchasePrice;

  @override
  final int sellingPrice;
}

/// A warehouse that a stocktaking session can be attached to.
class StocktakingWarehouse {
  const StocktakingWarehouse({required this.id, required this.name});

  final int id;
  final String name;
}

/// One editable line of the stocktaking table.
class StocktakingLine {
  StocktakingLine({
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

  /// Quantity recorded in the inventory before the count.
  int available;

  /// Counted quantity entered by the user.
  int qty;
  int price;

  /// counted * price, the value shown in the «الإجمالي» column.
  int get gross => qty * price;

  /// counted - recorded. Positive means a surplus, negative means a shortage.
  int get difference => qty - available;

  StocktakingLine clone() => StocktakingLine(
    productId: productId,
    code: code,
    name: name,
    unit: unit,
    available: available,
    qty: qty,
    price: price,
  );
}

/// Result of a successful stocktaking save.
class StocktakingSaveResult {
  const StocktakingSaveResult({
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

  /// Whether the counted quantities were written back to the inventory.
  final bool applied;
}

/// Thrown when the stocktaking data does not satisfy the business rules.
class StocktakingValidationException implements Exception {
  StocktakingValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One saved line loaded back into the stocktaking screen.
class StocktakingEditLine {
  const StocktakingEditLine({
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

  /// Quantity recorded in the inventory before this count.
  final int available;
  final int qty;
  final int price;
}

/// A saved stocktaking session loaded for editing.
class StocktakingEditData {
  const StocktakingEditData({
    required this.id,
    required this.number,
    required this.warehouseId,
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
  final DateTime? date;
  final String time;
  final String notes;
  final bool applied;
  final List<StocktakingEditLine> lines;
  final Map<int, String> customFields;
}
