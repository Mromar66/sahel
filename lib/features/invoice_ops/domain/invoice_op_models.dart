/// Domain models shared by the four invoice operations that reuse the
/// new-purchase screen: sale, sales return, purchase return and quotation.
library;

import 'package:safwa/app/models/product_search_item.dart';

/// Which operation an [InvoiceOpPage] is running.
enum InvoiceOpKind {
  sale,
  salesReturn,
  purchaseReturn,
  quotation;

  bool get isSale => this == InvoiceOpKind.sale;
  bool get isSalesReturn => this == InvoiceOpKind.salesReturn;
  bool get isPurchaseReturn => this == InvoiceOpKind.purchaseReturn;
  bool get isQuotation => this == InvoiceOpKind.quotation;
  bool get isReturn => isSalesReturn || isPurchaseReturn;

  /// Returns load an existing invoice before the quantities are entered.
  bool get needsOriginalInvoice => isReturn;

  /// Quotations never move stock.
  bool get affectsStock => !isQuotation;

  /// Quotations never record payments.
  bool get recordsPayments => !isQuotation;

  /// Sales sides (sale, sales return, quotation) use the selling price.
  bool get usesSellingPrice => !isPurchaseReturn;
}

/// A product row returned by the product search.
class InvoiceProduct implements ProductSearchItem {
  const InvoiceProduct({
    required this.id,
    required this.name,
    required this.code,
    required this.barcode,
    required this.unitName,
    required this.available,
    required this.purchasePrice,
    required this.sellingPrice,
    this.imagePath,
    this.sellingPrice2 = 0,
    this.sellingPrice3 = 0,
    this.sellingPrice4 = 0,
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
  final int sellingPrice2;
  final int sellingPrice3;
  final int sellingPrice4;
  final String? imagePath;
}

class InvoiceWarehouse {
  const InvoiceWarehouse({required this.id, required this.name});

  final int id;
  final String name;
}

class InvoiceTreasury {
  const InvoiceTreasury({required this.id, required this.name});

  final int id;
  final String name;
}

/// An account that can be attached to an invoice. Customer and supplier
/// accounts both live in the existing `accounts` table.
class InvoiceAccount {
  const InvoiceAccount({
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

/// One editable line of the invoice table.
class InvoiceLine {
  InvoiceLine({
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

  InvoiceLine clone() => InvoiceLine(
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
class InvoicePaymentInput {
  const InvoicePaymentInput({
    required this.accountId,
    required this.amount,
    required this.method,
    this.treasuryId,
  });

  final int accountId;
  final int amount;

  /// One of cash / card / bank / credit.
  final String method;
  final int? treasuryId;
}

/// Result of a successful save.
class InvoiceSaveResult {
  const InvoiceSaveResult({
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

/// A saved invoice that a return document can be built from.
class OriginalInvoiceSummary {
  const OriginalInvoiceSummary({
    required this.id,
    required this.number,
    required this.date,
    required this.partyName,
    required this.total,
  });

  final int id;
  final String number;
  final String date;
  final String partyName;
  final int total;
}

/// One line of a saved invoice, with the quantity still returnable.
class OriginalInvoiceLine {
  const OriginalInvoiceLine({
    required this.productId,
    required this.name,
    required this.code,
    required this.unit,
    required this.quantity,
    required this.returnedQuantity,
    required this.available,
    required this.unitPrice,
    required this.discount,
  });

  final int productId;
  final String name;
  final String code;
  final String unit;
  final int quantity;
  final int returnedQuantity;

  /// Stock on hand (purchase return) or remaining quantity (sales return).
  final int available;
  final int unitPrice;
  final int discount;

  int get returnable => quantity - returnedQuantity;
}

/// A saved invoice loaded for a return document.
class OriginalInvoiceData {
  const OriginalInvoiceData({
    required this.id,
    required this.number,
    required this.accountId,
    required this.accountName,
    required this.notes,
    required this.lines,
  });

  final int id;
  final String number;
  final int? accountId;
  final String accountName;
  final String notes;
  final List<OriginalInvoiceLine> lines;
}

/// Thrown when the invoice data does not satisfy the business rules.
class InvoiceValidationException implements Exception {
  InvoiceValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One saved line loaded back into the invoice screen for editing.
class InvoiceEditLine {
  const InvoiceEditLine({
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

/// A saved document loaded back into the invoice screen. Keeps the original
/// id, date and number so editing updates the same row instead of creating a
/// copy.
class InvoiceEditData {
  const InvoiceEditData({
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
    required this.originalInvoiceId,
    required this.lines,
    required this.customFields,
    this.warehouseId,
    this.salesRepresentativeId,
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
  final int? originalInvoiceId;
  final List<InvoiceEditLine> lines;
  final Map<int, String> customFields;
  final int? warehouseId;
  final int? salesRepresentativeId;
}
