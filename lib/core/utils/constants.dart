/// Application constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'نظام المخازن والمحاسبة';
  static const String appVersion = '1.0.0';

  // Database
  static const String databaseName = 'inventory.sqlite';

  // Directories
  static const String databaseFolder = 'database';
  static const String imagesFolder = 'images';
  static const String productImagesFolder = 'images/products';
  static const String backupsFolder = 'backups';
  static const String invoicesFolder = 'invoices';
  static const String logsFolder = 'logs';

  // Currency
  static const String defaultCurrency = 'EGP';
  static const String currencySymbol = 'ج.م';

  // Stock movement types
  static const String movementSale = 'sale';
  static const String movementPurchase = 'purchase';
  static const String movementAdjustment = 'adjustment';
  static const String movementTransferIn = 'transfer_in';
  static const String movementTransferOut = 'transfer_out';
  static const String movementStocktaking = 'stocktaking';
  static const String movementReturn = 'return';

  // Payment types
  static const String paymentReceive = 'receive';
  static const String paymentExpense = 'expense';

  // Payment methods
  static const String paymentMethodCash = 'cash';
  static const String paymentMethodBank = 'bank';
  static const String paymentMethodCheck = 'check';

  // Invoice payment statuses
  static const String statusPaid = 'paid';
  static const String statusPartial = 'partial';
  static const String statusUnpaid = 'unpaid';

  // Account types
  static const String accountTypeAsset = 'asset';
  static const String accountTypeLiability = 'liability';
  static const String accountTypeEquity = 'equity';
  static const String accountTypeRevenue = 'revenue';
  static const String accountTypeExpense = 'expense';

  // Transaction types
  static const String transactionReceive = 'receive';
  static const String transactionExpense = 'expense';
  static const String transactionTransfer = 'transfer';
}

/// Application routes.
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String products = '/products';
  static const String accounts = '/accounts';
  static const String treasury = '/treasury-movement';
  static const String treasuryMovement = '/treasury-movement';
  static const String sales = '/sales';
  static const String invoices = '/invoices';
  static const String salesReturn = '/sales-return';
  static const String purchaseReturn = '/purchase-return';
  static const String quotation = '/quotation';
  static const String purchases = '/purchases';
  static const String stocktaking = '/stocktaking';
  static const String adjustment = '/adjustment';
  static const String transfer = '/transfer';
  static const String warehouse = '/warehouse';
  static const String reports = '/reports';
  static const String dailyMovement = '/daily-movement';
  static const String salesAnalysis = '/sales-analysis';
  static const String settings = '/settings';
  static const String backup = '/backup';
}
