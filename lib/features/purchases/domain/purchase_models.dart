/// Domain models for the شراء (new purchase) screen.
library;

import 'package:safwa/app/models/product_search_item.dart';

/// A product row returned by the purchase product search.
class PurchaseProduct implements ProductSearchItem {
  const PurchaseProduct({
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

  @override
  final int available;

  @override
  final int purchasePrice;

  @override
  final int sellingPrice;
}

/// An account that can be attached to a purchase invoice.
class PurchaseAccount {
  const PurchaseAccount({
    required this.id,
    required this.name,
    required this.balance,
    required this.type,
  });

  final int id;
  final String name;
  final int balance;
  final String type;
}

/// One editable line of the purchase table.
class PurchaseLine {
  PurchaseLine({
    this.productId,
    required this.code,
    required this.name,
    required this.unit,
    required this.available,
    required this.qty,
    required this.price,
    this.discount = 0,
    this.customFields = const {},
  });

  int? productId;
  String code;
  String name;
  String unit;
  int available;
  int qty;
  int price;
  int discount;
  Map<int, String> customFields;

  /// qty * price, the value shown in the «الإجمالي» column.
  int get gross => qty * price;

  /// gross - line discount, the value shown in the «النهائي» column.
  int get net {
    final value = gross - discount;
    return value < 0 ? 0 : value;
  }

  PurchaseLine clone() => PurchaseLine(
    productId: productId,
    code: code,
    name: name,
    unit: unit,
    available: available,
    qty: qty,
    price: price,
    discount: discount,
    customFields: Map<int, String>.from(customFields),
  );
}

/// A payment captured by the F11 dialog before the invoice is saved.
class PurchasePaymentInput {
  const PurchasePaymentInput({
    required this.accountId,
    required this.amount,
    required this.method,
  });

  final int accountId;
  final int amount;

  /// One of cash / card / bank / credit.
  final String method;
}

/// Result of a successful save.
class PurchaseSaveResult {
  const PurchaseSaveResult({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.total,
    required this.paid,
    required this.remaining,
  });

  final int invoiceId;
  final String invoiceNumber;
  final int total;
  final int paid;
  final int remaining;
}

/// Thrown when the purchase data does not satisfy the business rules.
class PurchaseValidationException implements Exception {
  PurchaseValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A saved purchase line loaded back into the purchase screen.
class PurchaseEditLine {
  const PurchaseEditLine({
    required this.productId,
    required this.name,
    required this.code,
    required this.unit,
    required this.available,
    required this.qty,
    required this.price,
    required this.discount,
    this.customFields = const {},
  });

  final int? productId;
  final String name;
  final String code;
  final String unit;
  final int available;
  final int qty;
  final int price;
  final int discount;
  final Map<int, String> customFields;
}

/// A saved purchase invoice loaded for editing. The id is kept so saving
/// updates the existing invoice instead of creating a copy.
class PurchaseEditData {
  const PurchaseEditData({
    required this.id,
    required this.number,
    required this.accountId,
    required this.accountName,
    required this.date,
    required this.time,
    required this.discount,
    required this.tax,
    required this.paid,
    required this.notes,
    required this.lines,
    required this.customFields,
  });

  final int id;
  final String number;
  final int? accountId;
  final String? accountName;
  final DateTime? date;
  final String time;
  final int discount;
  final int tax;
  final int paid;
  final String notes;
  final List<PurchaseEditLine> lines;
  final Map<int, String> customFields;
}
