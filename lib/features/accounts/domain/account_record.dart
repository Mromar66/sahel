/// Domain record for a ledger account as shown on the reference
/// "الحسابات" screen.
class AccountRecord {
  const AccountRecord({
    this.id,
    required this.name,
    this.kind = 'customer',
    this.code = '',
    this.taxNumber = '',
    this.categoryId,
    this.categoryName = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.openingBalance = 0,
    this.balance = 0,
    this.balanceDate,
    this.discountPercent = 0,
    this.defaultPrice = 0,
    this.maxDebt = 0,
    this.notes = '',
    this.underReview = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.checksDebit = 0,
    this.checksCredit = 0,
  });

  final int? id;
  final String name;
  final String kind; // customer | supplier | rep | other
  final String code;
  final String taxNumber;
  final int? categoryId;
  final String categoryName;
  final String phone;
  final String email;
  final String address;
  final int openingBalance;
  final int balance;
  final DateTime? balanceDate;
  final int discountPercent;
  final int defaultPrice;
  final int maxDebt;
  final String notes;
  final bool underReview;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int checksDebit;
  final int checksCredit;

  String get kindLabel => kindLabelOf(kind);

  /// Amount owed *to us* (مدين).
  int get debit => balance > 0 ? balance : 0;

  /// Amount owed *by us* (دائن).
  int get credit => balance < 0 ? -balance : 0;

  static String kindLabelOf(String kind) {
    switch (kind) {
      case 'customer':
        return 'عميل';
      case 'supplier':
        return 'مورد';
      case 'rep':
        return 'مندوب بيع';
      default:
        return 'أخرى';
    }
  }
}

/// One movement row in an account statement.
class AccountMovement {
  const AccountMovement({
    required this.date,
    required this.time,
    required this.label,
    this.debit = 0,
    this.credit = 0,
    required this.balanceAfter,
    this.number = '',
    this.notes = '',
    this.invoiceNumber = '',
  });

  final DateTime date;
  final String time;
  final String label;
  final int debit;
  final int credit;
  final int balanceAfter;
  final String number;
  final String notes;
  final String invoiceNumber;
}

/// One row of the "متابعة سداد الشيكات والأقساط" report.
class AccountCheckRow {
  const AccountCheckRow({
    required this.id,
    required this.accountName,
    required this.amount,
    required this.dueDate,
    this.collectedDate,
    this.invoiceDate,
    required this.direction,
    this.receiptNumber = '',
    this.invoiceNumber = '',
    this.bank = '',
    this.checkNumber = '',
    this.collected = false,
  });

  final int id;
  final String accountName;
  final int amount;
  final DateTime dueDate;
  final DateTime? collectedDate;
  final DateTime? invoiceDate;
  final String direction; // in | out
  final String receiptNumber;
  final String invoiceNumber;
  final String bank;
  final String checkNumber;
  final bool collected;
}
