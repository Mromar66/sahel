import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;

/// Singleton database connection using sqlite3 directly.
class SqliteDatabase {
  SqliteDatabase._internal();

  /// Creates an isolated connection wrapper for repository tests.
  SqliteDatabase.withDatabase(Database database) : _db = database;

  static final SqliteDatabase _instance = SqliteDatabase._internal();

  factory SqliteDatabase() => _instance;

  Database? _db;
  String? _databaseFilePath;

  Database get db {
    _db ??= _openConnection();
    return _db!;
  }

  void close() {
    _db?.dispose();
    _db = null;
  }

  String get databasePath {
    return _databaseFilePath ??= p.join(
      _getDatabaseFolderSync().path,
      'inventory.sqlite',
    );
  }

  /// Creates a consistent SQLite snapshot using SQLite's online backup API.
  Future<void> backupTo(String targetPath) async {
    final target = sqlite3.open(targetPath);
    try {
      await db.backup(target, nPage: 64).drain<void>();
    } finally {
      target.dispose();
    }
  }

  /// Replace the active file only after the caller has staged and validated it.
  void replaceFromFile(String stagedPath) {
    close();
    final current = File(databasePath);
    final wal = File('$databasePath-wal');
    final shm = File('$databasePath-shm');
    final previous = File('$databasePath.pre-restore');
    final staged = File(stagedPath);
    if (!staged.existsSync()) {
      throw const FileSystemException('ملف الاستعادة المؤقت غير موجود.');
    }
    if (previous.existsSync()) previous.deleteSync();
    if (wal.existsSync()) wal.deleteSync();
    if (shm.existsSync()) shm.deleteSync();
    var movedCurrent = false;
    try {
      if (current.existsSync()) {
        current.renameSync(previous.path);
        movedCurrent = true;
      }
      staged.renameSync(current.path);
      if (previous.existsSync()) previous.deleteSync();
    } catch (_) {
      if (!current.existsSync() && movedCurrent && previous.existsSync()) {
        previous.renameSync(current.path);
      }
      rethrow;
    }
  }

  Database _openConnection() {
    final db = sqlite3.open(databasePath);
    // Keep referential integrity and a short busy timeout so a concurrent
    // backup/read never fails with "database is locked".
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('PRAGMA busy_timeout = 5000');
    db.execute('PRAGMA synchronous = NORMAL');
    _createTables(db);
    return db;
  }

  Directory _getDatabaseFolderSync() {
    final configuredFolder = Platform.environment['SAHEL_DATABASE_DIR']?.trim();
    if (configuredFolder != null && configuredFolder.isNotEmpty) {
      final folder = Directory(configuredFolder);
      folder.createSync(recursive: true);
      return folder;
    }

    // Locate the existing database beside the project instead of relying on
    // the process working directory, which may be a protected folder in a
    // packaged Windows build.
    var directory = File(Platform.resolvedExecutable).parent;
    for (var depth = 0; depth < 8; depth++) {
      final candidate = Directory(p.join(directory.path, 'database'));
      if (candidate.existsSync() &&
          File(p.join(candidate.path, 'inventory.sqlite')).existsSync()) {
        return candidate;
      }
      final parent = directory.parent;
      if (parent.path == directory.path) break;
      directory = parent;
    }

    final localAppData = Platform.environment['LOCALAPPDATA'];
    final dbFolder = Directory(
      p.join(
        localAppData ?? Directory.systemTemp.path,
        'SahlInventory',
        'database',
      ),
    );
    dbFolder.createSync(recursive: true);
    return dbFolder;
  }

  void _createTables(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        abbreviation TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        product_code TEXT NOT NULL,
        barcode TEXT,
        category_id INTEGER REFERENCES categories(id),
        unit_id INTEGER REFERENCES units(id),
        purchase_price INTEGER NOT NULL,
        selling_price INTEGER NOT NULL,
        selling_price_2 INTEGER NOT NULL DEFAULT 0,
        selling_price_3 INTEGER NOT NULL DEFAULT 0,
        selling_price_4 INTEGER NOT NULL DEFAULT 0,
        current_stock INTEGER DEFAULT 0,
        minimum_stock INTEGER DEFAULT 0,
        code2 TEXT,
        other_codes TEXT,
        discount_percent INTEGER DEFAULT 0,
        last_selling_price INTEGER DEFAULT 0,
        last_qty INTEGER DEFAULT 0,
        reorder_point INTEGER DEFAULT 0,
        economic_qty INTEGER DEFAULT 0,
        is_service INTEGER DEFAULT 0,
        quick_family INTEGER DEFAULT 0,
        image_path TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // Migrations for databases created before the extra product columns.
    final productColumns = db.select("PRAGMA table_info(products)");
    final productColumnNames = productColumns
        .map((c) => c['name'] as String)
        .toSet();
    void addProductColumn(String name, String definition) {
      if (!productColumnNames.contains(name)) {
        db.execute('ALTER TABLE products ADD COLUMN $name $definition');
      }
    }

    addProductColumn('code2', 'TEXT');
    addProductColumn('other_codes', 'TEXT');
    addProductColumn('discount_percent', 'INTEGER DEFAULT 0');
    addProductColumn('last_selling_price', 'INTEGER DEFAULT 0');
    addProductColumn('selling_price_2', 'INTEGER NOT NULL DEFAULT 0');
    addProductColumn('selling_price_3', 'INTEGER NOT NULL DEFAULT 0');
    addProductColumn('selling_price_4', 'INTEGER NOT NULL DEFAULT 0');
    addProductColumn('last_qty', 'INTEGER DEFAULT 0');
    addProductColumn('reorder_point', 'INTEGER DEFAULT 0');
    addProductColumn('economic_qty', 'INTEGER DEFAULT 0');
    addProductColumn('is_service', 'INTEGER DEFAULT 0');
    addProductColumn('quick_family', 'INTEGER DEFAULT 0');

    db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        account_type TEXT NOT NULL,
        balance INTEGER DEFAULT 0,
        description TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // Account columns used by the reference accounts screen.
    final accountColumns = db.select('PRAGMA table_info(accounts)');
    final accountColumnNames = accountColumns
        .map((c) => c['name'] as String)
        .toSet();
    void addAccountColumn(String name, String definition) {
      if (!accountColumnNames.contains(name)) {
        db.execute('ALTER TABLE accounts ADD COLUMN $name $definition');
      }
    }

    addAccountColumn('account_code', 'TEXT');
    addAccountColumn('tax_number', 'TEXT');
    addAccountColumn('category_id', 'INTEGER');
    addAccountColumn('phone', 'TEXT');
    addAccountColumn('email', 'TEXT');
    addAccountColumn('address', 'TEXT');
    addAccountColumn('opening_balance', 'INTEGER DEFAULT 0');
    addAccountColumn('balance_date', 'TEXT');
    addAccountColumn('discount_percent', 'INTEGER DEFAULT 0');
    addAccountColumn('default_price', 'INTEGER DEFAULT 0');
    addAccountColumn('max_debt', 'INTEGER DEFAULT 0');
    addAccountColumn('notes', 'TEXT');
    addAccountColumn('under_review', 'INTEGER DEFAULT 0');

    db.execute('''
      CREATE TABLE IF NOT EXISTS account_checks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        direction TEXT NOT NULL DEFAULT 'in',
        amount INTEGER NOT NULL DEFAULT 0,
        due_date TEXT NOT NULL,
        collected_date TEXT,
        bank TEXT,
        check_number TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    final checkColumns = db
        .select('PRAGMA table_info(account_checks)')
        .map((column) => column['name'] as String)
        .toSet();
    if (!checkColumns.contains('payment_id')) {
      db.execute(
        'ALTER TABLE account_checks ADD COLUMN payment_id INTEGER REFERENCES payments(id)',
      );
    }
    if (!checkColumns.contains('treasury_id')) {
      db.execute('ALTER TABLE account_checks ADD COLUMN treasury_id INTEGER');
    }

    db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        balance INTEGER DEFAULT 0,
        tax_number TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        balance INTEGER DEFAULT 0,
        tax_number TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS warehouses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        location TEXT,
        description TEXT,
        is_active INTEGER DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    final warehouseColumns = db
        .select('PRAGMA table_info(warehouses)')
        .map((c) => c['name'] as String)
        .toSet();
    if (!warehouseColumns.contains('sort_order')) {
      db.execute(
        'ALTER TABLE warehouses ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
      );
      final warehouseRows = db.select('SELECT id FROM warehouses ORDER BY id');
      for (var i = 0; i < warehouseRows.length; i++) {
        db.execute('UPDATE warehouses SET sort_order=? WHERE id=?', [
          i,
          warehouseRows[i]['id'],
        ]);
      }
    }

    db.execute('''
      CREATE TABLE IF NOT EXISTS sales_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL,
        customer_id INTEGER REFERENCES customers(id),
        account_id INTEGER REFERENCES accounts(id),
        sales_rep_account_id INTEGER REFERENCES accounts(id),
        warehouse_id INTEGER REFERENCES warehouses(id),
        invoice_date TEXT NOT NULL,
        subtotal INTEGER NOT NULL,
        discount INTEGER DEFAULT 0,
        tax INTEGER DEFAULT 0,
        total INTEGER NOT NULL,
        paid_amount INTEGER DEFAULT 0,
        remaining_amount INTEGER NOT NULL,
        payment_status TEXT NOT NULL,
        notes TEXT,
        is_return INTEGER DEFAULT 0,
        original_invoice_id INTEGER REFERENCES sales_invoices(id),
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS sales_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL REFERENCES sales_invoices(id),
        product_id INTEGER NOT NULL REFERENCES products(id),
        product_name TEXT NOT NULL,
        product_code TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price INTEGER NOT NULL,
        discount INTEGER DEFAULT 0,
        total INTEGER NOT NULL
      )
    ''');

    // Sales invoices keep the customer account selected on the بيع screen.
    final salesInvoiceColumns = db.select('PRAGMA table_info(sales_invoices)');
    final salesInvoiceColumnNames = salesInvoiceColumns
        .map((c) => c['name'] as String)
        .toSet();
    if (!salesInvoiceColumnNames.contains('account_id')) {
      db.execute(
        'ALTER TABLE sales_invoices ADD COLUMN '
        'account_id INTEGER REFERENCES accounts(id)',
      );
    }
    if (!salesInvoiceColumnNames.contains('warehouse_id')) {
      db.execute(
        'ALTER TABLE sales_invoices ADD COLUMN warehouse_id INTEGER REFERENCES warehouses(id)',
      );
    }
    if (!salesInvoiceColumnNames.contains('sales_rep_account_id')) {
      db.execute(
        'ALTER TABLE sales_invoices ADD COLUMN sales_rep_account_id INTEGER REFERENCES accounts(id)',
      );
    }

    db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL,
        supplier_id INTEGER REFERENCES suppliers(id),
        invoice_date TEXT NOT NULL,
        subtotal INTEGER NOT NULL,
        discount INTEGER DEFAULT 0,
        tax INTEGER DEFAULT 0,
        total INTEGER NOT NULL,
        paid_amount INTEGER DEFAULT 0,
        remaining_amount INTEGER NOT NULL,
        payment_status TEXT NOT NULL,
        notes TEXT,
        is_return INTEGER DEFAULT 0,
        original_invoice_id INTEGER REFERENCES purchase_invoices(id),
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // Purchase invoices keep the supplier account that was selected on the
    // شراء screen. Databases created before this column need the migration.
    final purchaseInvoiceColumns = db.select(
      'PRAGMA table_info(purchase_invoices)',
    );
    final purchaseInvoiceColumnNames = purchaseInvoiceColumns
        .map((c) => c['name'] as String)
        .toSet();
    if (!purchaseInvoiceColumnNames.contains('account_id')) {
      db.execute(
        'ALTER TABLE purchase_invoices ADD COLUMN '
        'account_id INTEGER REFERENCES accounts(id)',
      );
    }

    db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL REFERENCES purchase_invoices(id),
        product_id INTEGER NOT NULL REFERENCES products(id),
        product_name TEXT NOT NULL,
        product_code TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price INTEGER NOT NULL,
        discount INTEGER DEFAULT 0,
        total INTEGER NOT NULL
      )
    ''');

    // مرتجع شراء — its own document tables so the purchase invoice numbering
    // used by the شراء screen is not touched.
    db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_return_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_number TEXT NOT NULL,
        account_id INTEGER REFERENCES accounts(id),
        original_invoice_id INTEGER REFERENCES purchase_invoices(id),
        return_date TEXT NOT NULL,
        subtotal INTEGER NOT NULL,
        discount INTEGER DEFAULT 0,
        tax INTEGER DEFAULT 0,
        total INTEGER NOT NULL,
        refunded_amount INTEGER DEFAULT 0,
        remaining_amount INTEGER NOT NULL,
        payment_status TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL REFERENCES purchase_return_invoices(id),
        product_id INTEGER REFERENCES products(id),
        product_name TEXT NOT NULL,
        product_code TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price INTEGER NOT NULL,
        discount INTEGER DEFAULT 0,
        total INTEGER NOT NULL
      )
    ''');

    // عرض أسعار — saved offers only. They never touch stock or payments.
    db.execute('''
      CREATE TABLE IF NOT EXISTS quotations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quote_number TEXT NOT NULL,
        account_id INTEGER REFERENCES accounts(id),
        quote_date TEXT NOT NULL,
        subtotal INTEGER NOT NULL,
        discount INTEGER DEFAULT 0,
        tax INTEGER DEFAULT 0,
        total INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'open',
        converted_invoice_id INTEGER REFERENCES sales_invoices(id),
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS quotation_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quote_id INTEGER NOT NULL REFERENCES quotations(id),
        product_id INTEGER REFERENCES products(id),
        product_name TEXT NOT NULL,
        product_code TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price INTEGER NOT NULL,
        discount INTEGER DEFAULT 0,
        total INTEGER NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id),
        quantity INTEGER NOT NULL,
        movement_type TEXT NOT NULL,
        reference_id INTEGER,
        reference_type TEXT,
        from_warehouse_id INTEGER REFERENCES warehouses(id),
        to_warehouse_id INTEGER REFERENCES warehouses(id),
        movement_date TEXT NOT NULL,
        notes TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS stocktaking_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_number TEXT NOT NULL,
        warehouse_id INTEGER REFERENCES warehouses(id),
        session_date TEXT NOT NULL,
        total INTEGER NOT NULL DEFAULT 0,
        items_count INTEGER NOT NULL DEFAULT 0,
        applied INTEGER DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS stocktaking_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES stocktaking_sessions(id),
        product_id INTEGER REFERENCES products(id),
        product_name TEXT NOT NULL,
        product_code TEXT NOT NULL,
        unit_name TEXT,
        available_qty INTEGER NOT NULL DEFAULT 0,
        counted_qty INTEGER NOT NULL DEFAULT 0,
        price INTEGER NOT NULL DEFAULT 0,
        total INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // تسوية مخزن — its own document tables, independent from stocktaking.
    db.execute('''
      CREATE TABLE IF NOT EXISTS stock_adjustment_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_number TEXT NOT NULL,
        warehouse_id INTEGER REFERENCES warehouses(id),
        session_date TEXT NOT NULL,
        total INTEGER NOT NULL DEFAULT 0,
        items_count INTEGER NOT NULL DEFAULT 0,
        applied INTEGER DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS stock_adjustment_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES stock_adjustment_sessions(id),
        product_id INTEGER REFERENCES products(id),
        product_name TEXT NOT NULL,
        product_code TEXT NOT NULL,
        unit_name TEXT,
        available_qty INTEGER NOT NULL DEFAULT 0,
        adjusted_qty INTEGER NOT NULL DEFAULT 0,
        difference INTEGER NOT NULL DEFAULT 0,
        price INTEGER NOT NULL DEFAULT 0,
        total INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // تحويل لمخزن — source and destination warehouses on the document.
    db.execute('''
      CREATE TABLE IF NOT EXISTS stock_transfer_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_number TEXT NOT NULL,
        from_warehouse_id INTEGER REFERENCES warehouses(id),
        to_warehouse_id INTEGER REFERENCES warehouses(id),
        session_date TEXT NOT NULL,
        total INTEGER NOT NULL DEFAULT 0,
        items_count INTEGER NOT NULL DEFAULT 0,
        applied INTEGER DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS stock_transfer_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES stock_transfer_sessions(id),
        product_id INTEGER REFERENCES products(id),
        product_name TEXT NOT NULL,
        product_code TEXT NOT NULL,
        unit_name TEXT,
        available_qty INTEGER NOT NULL DEFAULT 0,
        transfer_qty INTEGER NOT NULL DEFAULT 0,
        price INTEGER NOT NULL DEFAULT 0,
        total INTEGER NOT NULL DEFAULT 0
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payment_number TEXT NOT NULL,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        payment_date TEXT NOT NULL,
        amount INTEGER NOT NULL,
        payment_type TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        description TEXT,
        reference_id INTEGER,
        reference_type TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_account_checks_payment_id '
      'ON account_checks(payment_id) WHERE payment_id IS NOT NULL',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_account_checks_treasury_status '
      'ON account_checks(treasury_id, status)',
    );

    db.execute('''
      CREATE TABLE IF NOT EXISTS treasury_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_number TEXT NOT NULL,
        transaction_date TEXT NOT NULL,
        amount INTEGER NOT NULL,
        transaction_type TEXT NOT NULL,
        description TEXT,
        reference_id INTEGER,
        reference_type TEXT,
        balance_after INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expense_number TEXT NOT NULL,
        account_id INTEGER REFERENCES accounts(id),
        expense_date TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        payment_id INTEGER REFERENCES payments(id),
        created_at TEXT NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL,
        description TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS document_custom_fields (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        scope TEXT NOT NULL DEFAULT 'document',
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    final customFieldColumns = db
        .select('PRAGMA table_info(document_custom_fields)')
        .map((c) => c['name'] as String)
        .toSet();
    if (!customFieldColumns.contains('scope')) {
      db.execute(
        "ALTER TABLE document_custom_fields ADD COLUMN scope TEXT NOT NULL DEFAULT 'document'",
      );
    }
    db.execute('''
      CREATE TABLE IF NOT EXISTS document_custom_values (
        document_type TEXT NOT NULL,
        document_id INTEGER NOT NULL,
        field_id INTEGER NOT NULL REFERENCES document_custom_fields(id),
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(document_type, document_id, field_id)
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'other',
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    final paymentMethodCount =
        db.select('SELECT COUNT(*) AS c FROM payment_methods').first['c']
            as int;
    if (paymentMethodCount == 0) {
      final now = DateTime.now().toIso8601String();
      const defaults = [
        ['cash', 'درج النقدية', 'cash'],
        ['card', 'بطاقة ائتمان', 'card'],
        ['bank', 'تحويل بنكي', 'bank'],
        ['credit', 'آجل', 'credit'],
      ];
      for (var i = 0; i < defaults.length; i++) {
        db.execute(
          'INSERT INTO payment_methods(code,name,kind,is_active,sort_order,created_at) VALUES(?,?,?,1,?,?)',
          [...defaults[i], i, now],
        );
      }
    }

    db.execute('''
      CREATE TABLE IF NOT EXISTS currencies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        symbol TEXT NOT NULL,
        country_code TEXT NOT NULL DEFAULT '',
        decimal_places INTEGER NOT NULL DEFAULT 2,
        exchange_rate REAL NOT NULL DEFAULT 1,
        is_primary INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    final currencyCount =
        db.select('SELECT COUNT(*) AS c FROM currencies').first['c'] as int;
    if (currencyCount == 0) {
      final now = DateTime.now().toIso8601String();
      final codeRows = db.select('SELECT value FROM settings WHERE key = ?', [
        'settings.currency',
      ]);
      final countryRows = db.select(
        'SELECT value FROM settings WHERE key = ?',
        ['settings.country'],
      );
      final code = codeRows.isEmpty ? 'EGP' : codeRows.first['value'] as String;
      final country = countryRows.isEmpty
          ? 'EG'
          : countryRows.first['value'] as String;
      db.execute(
        'INSERT INTO currencies(code,name,symbol,country_code,decimal_places,exchange_rate,is_primary,is_active,sort_order,created_at) VALUES(?,?,?,?,2,1,1,1,0,?)',
        [code, 'الجنيه المصري', 'ج.م', country, now],
      );
    }

    db.execute('''
      CREATE TABLE IF NOT EXISTS program_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        is_admin INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS program_user_permissions (
        user_id INTEGER NOT NULL REFERENCES program_users(id) ON DELETE CASCADE,
        permission_code TEXT NOT NULL,
        PRIMARY KEY(user_id, permission_code)
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS program_roles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        description TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS program_role_permissions (
        role_id INTEGER NOT NULL REFERENCES program_roles(id) ON DELETE CASCADE,
        permission_code TEXT NOT NULL,
        PRIMARY KEY(role_id, permission_code)
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS program_user_roles (
        user_id INTEGER NOT NULL REFERENCES program_users(id) ON DELETE CASCADE,
        role_id INTEGER NOT NULL REFERENCES program_roles(id) ON DELETE CASCADE,
        PRIMARY KEY(user_id, role_id)
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS program_login_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES program_users(id) ON DELETE SET NULL,
        username TEXT NOT NULL,
        event_type TEXT NOT NULL,
        event_time TEXT NOT NULL
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS program_user_preferences (
        user_id INTEGER NOT NULL REFERENCES program_users(id) ON DELETE CASCADE,
        preference_key TEXT NOT NULL,
        preference_value TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(user_id, preference_key)
      )
    ''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_program_login_history_user_time '
      'ON program_login_history(user_id,event_time DESC)',
    );
    _seedDefaultProgramRoles(db);
    db.execute('''
      CREATE TABLE IF NOT EXISTS entity_custom_values (
        scope TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        field_id INTEGER NOT NULL REFERENCES document_custom_fields(id),
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(scope, entity_id, field_id)
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS document_custom_line_values (
        document_type TEXT NOT NULL,
        document_id INTEGER NOT NULL,
        line_id INTEGER NOT NULL,
        field_id INTEGER NOT NULL REFERENCES document_custom_fields(id),
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(document_type, document_id, line_id, field_id)
      )
    ''');

    // -------------------------------------------------------------------------
    // Treasury movement support.
    //
    // The original program treated the treasury as a single implicit cash
    // drawer. The movement screen needs named treasuries (so it can filter and
    // transfer between them), an explicit date/time pair, notes and a transfer
    // marker. All of these are additive migrations so existing invoices and
    // the legacy treasury screen keep working unchanged.
    // -------------------------------------------------------------------------
    db.execute('''
      CREATE TABLE IF NOT EXISTS treasuries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        opening_balance INTEGER NOT NULL DEFAULT 0,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    final treasuryColumns = db
        .select('PRAGMA table_info(treasuries)')
        .map((c) => c['name'] as String)
        .toSet();
    if (!treasuryColumns.contains('sort_order')) {
      db.execute(
        'ALTER TABLE treasuries ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
      );
      final treasuryRows = db.select('SELECT id FROM treasuries ORDER BY id');
      for (var i = 0; i < treasuryRows.length; i++) {
        db.execute('UPDATE treasuries SET sort_order=? WHERE id=?', [
          i,
          treasuryRows[i]['id'],
        ]);
      }
    }

    final treasuryTxnColumns = db.select(
      'PRAGMA table_info(treasury_transactions)',
    );
    final treasuryTxnColumnNames = treasuryTxnColumns
        .map((c) => c['name'] as String)
        .toSet();
    void addTreasuryTxnColumn(String name, String definition) {
      if (!treasuryTxnColumnNames.contains(name)) {
        db.execute(
          'ALTER TABLE treasury_transactions ADD COLUMN $name $definition',
        );
      }
    }

    addTreasuryTxnColumn('treasury_id', 'INTEGER');
    addTreasuryTxnColumn('notes', 'TEXT');
    addTreasuryTxnColumn('transaction_time', 'TEXT');
    addTreasuryTxnColumn('category', 'TEXT');
    addTreasuryTxnColumn('is_transfer', 'INTEGER NOT NULL DEFAULT 0');
    addTreasuryTxnColumn('transfer_group', 'TEXT');
    addTreasuryTxnColumn('peer_treasury_id', 'INTEGER');

    final treasuryCount =
        db.select('SELECT COUNT(*) AS c FROM treasuries').first['c'] as int;
    if (treasuryCount == 0) {
      final seededAt = DateTime.now().toIso8601String();
      db.execute(
        'INSERT INTO treasuries '
        '(name, opening_balance, description, is_active, created_at) '
        'VALUES (?, ?, ?, 1, ?)',
        ['درج النقدية', 50000, 'الخزينة الافتراضية', seededAt],
      );
      db.execute(
        'INSERT INTO treasuries '
        '(name, opening_balance, description, is_active, created_at) '
        'VALUES (?, ?, ?, 1, ?)',
        ['خزينة الفرع', 15000, 'خزينة فرعية', seededAt],
      );
    }

    final defaultTreasuryRow = db.select(
      'SELECT id FROM treasuries ORDER BY id LIMIT 1',
    );
    if (defaultTreasuryRow.isNotEmpty) {
      final defaultTreasuryId = defaultTreasuryRow.first['id'] as int;
      db.execute(
        'UPDATE treasury_transactions SET treasury_id = ? '
        'WHERE treasury_id IS NULL',
        [defaultTreasuryId],
      );
    }

    // Fill the separate time column for rows created before this migration.
    for (final row in db.select(
      'SELECT id, transaction_date FROM treasury_transactions '
      "WHERE transaction_time IS NULL OR transaction_time = ''",
    )) {
      final raw = (row['transaction_date'] as String?) ?? '';
      var time = '00:00';
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        time =
            '${parsed.hour.toString().padLeft(2, '0')}:'
            '${parsed.minute.toString().padLeft(2, '0')}';
      } else if (raw.length >= 16) {
        time = raw.substring(11, 16);
      }
      db.execute(
        'UPDATE treasury_transactions SET transaction_time = ? WHERE id = ?',
        [time, row['id']],
      );
    }

    // Recalculate the historical running balance once, now that every row
    // belongs to a treasury with its own opening balance. Later inserts keep
    // this column in sync through the movement repository.
    const treasuryBackfillKey = 'treasury_movement_backfill_v1';
    final treasuryBackfillDone = db.select(
      'SELECT key FROM settings WHERE key = ?',
      [treasuryBackfillKey],
    );
    if (treasuryBackfillDone.isEmpty) {
      for (final treasury in db.select(
        'SELECT id, opening_balance FROM treasuries ORDER BY id',
      )) {
        var running = treasury['opening_balance'] as int;
        final rows = db.select(
          'SELECT id, amount, transaction_type FROM treasury_transactions '
          'WHERE treasury_id = ? ORDER BY transaction_date ASC, id ASC',
          [treasury['id']],
        );
        for (final row in rows) {
          final amount = row['amount'] as int;
          if (row['transaction_type'] == 'receive') {
            running += amount;
          } else {
            running -= amount;
          }
          db.execute(
            'UPDATE treasury_transactions SET balance_after = ? WHERE id = ?',
            [running, row['id']],
          );
        }
      }
      final backfilledAt = DateTime.now().toIso8601String();
      db.execute(
        'INSERT INTO settings (key, value, description, updated_at) '
        'VALUES (?, ?, ?, ?)',
        [
          treasuryBackfillKey,
          '1',
          'Backfilled treasury opening balances and running balances',
          backfilledAt,
        ],
      );
    }

    // Historical cost snapshot for every sold line. Reports must not read the
    // product's current purchase price, because editing a product would then
    // rewrite the profit of old invoices.
    final salesItemColumns = db.select('PRAGMA table_info(sales_items)');
    final salesItemColumnNames = salesItemColumns
        .map((c) => c['name'] as String)
        .toSet();
    if (!salesItemColumnNames.contains('unit_cost')) {
      db.execute(
        'ALTER TABLE sales_items ADD COLUMN '
        'unit_cost INTEGER NOT NULL DEFAULT 0',
      );
    }

    // Backfill legacy lines once. Sales use the product cost that was stored
    // when the invoice was written; returns reverse the weighted cost of the
    // original sale line, falling back to the current purchase price only when
    // the original line is unavailable.
    const salesCostBackfillKey = 'sales_items_unit_cost_backfill_v1';
    final salesCostBackfillDone = db.select(
      'SELECT key FROM settings WHERE key = ?',
      [salesCostBackfillKey],
    );
    if (salesCostBackfillDone.isEmpty) {
      db.execute('''
        UPDATE sales_items
        SET unit_cost = COALESCE((
          SELECT p.purchase_price FROM products p
          WHERE p.id = sales_items.product_id
        ), 0)
        WHERE unit_cost = 0
          AND invoice_id IN (
            SELECT id FROM sales_invoices WHERE COALESCE(is_return, 0) = 0
          )
        ''');
      db.execute('''
        UPDATE sales_items
        SET unit_cost = COALESCE((
          SELECT CASE WHEN COALESCE(SUM(src.quantity), 0) > 0
            THEN CAST(ROUND(
              1.0 * SUM(src.quantity * src.unit_cost) / SUM(src.quantity)
            ) AS INTEGER)
          END
          FROM sales_items src
          JOIN sales_invoices rinv ON rinv.id = sales_items.invoice_id
          WHERE rinv.is_return = 1
            AND src.invoice_id = rinv.original_invoice_id
            AND src.product_id = sales_items.product_id
        ), (
          SELECT p.purchase_price FROM products p
          WHERE p.id = sales_items.product_id
        ), 0)
        WHERE unit_cost = 0
          AND invoice_id IN (
            SELECT id FROM sales_invoices WHERE COALESCE(is_return, 0) = 1
          )
        ''');
      db.execute(
        'INSERT INTO settings (key, value, description, updated_at) '
        'VALUES (?, ?, ?, ?)',
        [
          salesCostBackfillKey,
          '1',
          'Backfilled historical unit costs for sales and sales returns',
          DateTime.now().toIso8601String(),
        ],
      );
    }

    // Indexes used by the invoice / payment / stock queries.
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_invoices_account '
      'ON purchase_invoices(account_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_items_invoice '
      'ON purchase_items(invoice_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_items_product '
      'ON purchase_items(product_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_invoices_account '
      'ON sales_invoices(account_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_invoices_return '
      'ON sales_invoices(is_return, original_invoice_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_items_invoice '
      'ON sales_items(invoice_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_items_product '
      'ON sales_items(product_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_returns_original '
      'ON purchase_return_invoices(original_invoice_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_return_items_return '
      'ON purchase_return_items(return_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_return_items_product '
      'ON purchase_return_items(product_id)',
    );
    db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_purchase_returns_number '
      'ON purchase_return_invoices(return_number)',
    );
    db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_quotations_number '
      'ON quotations(quote_number)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quotation_items_quote '
      'ON quotation_items(quote_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quotation_items_product '
      'ON quotation_items(product_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_reference '
      'ON payments(reference_type, reference_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_treasury_reference '
      'ON treasury_transactions(reference_type, reference_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_treasury_treasury_date '
      'ON treasury_transactions(treasury_id, transaction_date)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_treasury_transfer_group '
      'ON treasury_transactions(transfer_group)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_product '
      'ON stock_movements(product_id)',
    );
    db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_purchase_invoices_number '
      'ON purchase_invoices(invoice_number)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stocktaking_items_session '
      'ON stocktaking_items(session_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stocktaking_items_product '
      'ON stocktaking_items(product_id)',
    );
    db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_stocktaking_sessions_number '
      'ON stocktaking_sessions(session_number)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_adjustment_items_session '
      'ON stock_adjustment_items(session_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_adjustment_items_product '
      'ON stock_adjustment_items(product_id)',
    );
    db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_adjustment_sessions_number '
      'ON stock_adjustment_sessions(session_number)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transfer_items_session '
      'ON stock_transfer_items(session_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transfer_items_product '
      'ON stock_transfer_items(product_id)',
    );
    db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_transfer_sessions_number '
      'ON stock_transfer_sessions(session_number)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_reference '
      'ON stock_movements(reference_type, reference_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_code '
      'ON products(product_code)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_barcode '
      'ON products(barcode)',
    );
  }

  void _seedDefaultProgramRoles(Database db) {
    if ((db.select('SELECT COUNT(*) AS count FROM program_roles').first['count']
                as num?)
            ?.toInt() !=
        0) {
      return;
    }
    const templates = <(String, String, List<String>)>[
      (
        'مبيعات',
        'مستخدم فواتير البيع والعملاء.',
        [
          'products',
          'accounts',
          'sales',
          'sales_return',
          'quotation',
          'invoices',
        ],
      ),
      (
        'مشتريات',
        'مستخدم فواتير الشراء والموردين.',
        ['products', 'accounts', 'purchases', 'purchase_return', 'invoices'],
      ),
      (
        'أمين مخزن',
        'إدارة الأصناف والجرد والتسويات والتحويلات.',
        ['products', 'warehouse', 'stocktaking', 'adjustment', 'transfer'],
      ),
      (
        'محاسب',
        'مستخدم الحسابات والخزينة والتقارير المالية.',
        [
          'accounts',
          'receipts',
          'payments',
          'treasury',
          'reports',
          'daily_movement',
          'statements',
          'checks',
        ],
      ),
    ];
    final now = DateTime.now().toIso8601String();
    var order = 0;
    for (final template in templates) {
      db.execute(
        'INSERT INTO program_roles(name,description,sort_order,created_at) VALUES(?,?,?,?)',
        [template.$1, template.$2, order++, now],
      );
      final roleId = db.lastInsertRowId;
      for (final code in template.$3) {
        db.execute(
          'INSERT INTO program_role_permissions(role_id,permission_code) VALUES(?,?)',
          [roleId, code],
        );
      }
    }
  }

  /// Execute a query and return rows as List of Maps.
  List<Map<String, dynamic>> query(String sql, [List<Object?>? params]) {
    final result = db.select(sql, params ?? []);
    return result.toList();
  }

  /// Execute an insert/update/delete and return the number of affected rows.
  void execute(String sql, [List<Object?>? params]) {
    db.execute(sql, params ?? []);
  }

  /// Execute an insert and return the last inserted row ID.
  int insert(String sql, [List<Object?>? params]) {
    db.execute(sql, params ?? []);
    // sqlite3 package doesn't directly expose lastInsertRowId in a simple way,
    // so we query it separately.
    final result = db.select('SELECT last_insert_rowid() AS id');
    return result.first['id'] as int;
  }

  /// Run [body] inside a single SQLite transaction. Any thrown error rolls the
  /// whole batch back, so a failed purchase never leaves half-written rows.
  Future<T> transaction<T>(Future<T> Function() body) async {
    final database = db;
    database.execute('BEGIN IMMEDIATE');
    try {
      final result = await body();
      database.execute('COMMIT');
      return result;
    } catch (_) {
      try {
        database.execute('ROLLBACK');
      } catch (_) {
        // The transaction may already be closed by SQLite itself.
      }
      rethrow;
    }
  }
}
