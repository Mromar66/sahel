import 'package:safwa/core/database/sqlite_database.dart';
import 'package:safwa/core/security/password_hasher.dart';

class SettingsUser {
  const SettingsUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isAdmin,
    required this.isActive,
    required this.sortOrder,
    required this.permissions,
    required this.roleIds,
  });

  final int id;
  final String username;
  final String displayName;
  final bool isAdmin;
  final bool isActive;
  final int sortOrder;
  final Set<String> permissions;
  final Set<int> roleIds;
}

class SettingsRole {
  const SettingsRole({
    required this.id,
    required this.name,
    required this.description,
    required this.sortOrder,
    required this.permissions,
    required this.userCount,
  });

  final int id;
  final String name;
  final String description;
  final int sortOrder;
  final Set<String> permissions;
  final int userCount;
}

class SettingsRepository {
  SettingsRepository._();
  static final SettingsRepository instance = SettingsRepository._();

  final SqliteDatabase _database = SqliteDatabase();

  String read(String key, [String fallback = '']) {
    final rows = _database.query('SELECT value FROM settings WHERE key=?', [
      key,
    ]);
    return rows.isEmpty ? fallback : '${rows.first['value'] ?? fallback}';
  }

  String readUserPreference(int userId, String key, [String fallback = '']) {
    final rows = _database.query(
      'SELECT preference_value FROM program_user_preferences WHERE user_id=? AND preference_key=?',
      [userId, key],
    );
    return rows.isEmpty
        ? fallback
        : '${rows.first['preference_value'] ?? fallback}';
  }

  Future<void> saveUserPreference(int userId, String key, String value) async {
    _database.execute(
      'INSERT INTO program_user_preferences(user_id,preference_key,preference_value,updated_at) '
      'VALUES(?,?,?,?) ON CONFLICT(user_id,preference_key) DO UPDATE SET '
      'preference_value=excluded.preference_value,updated_at=excluded.updated_at',
      [userId, key, value, DateTime.now().toIso8601String()],
    );
  }

  Map<String, String> readAll(Iterable<String> keys) => {
    for (final key in keys) key: read(key),
  };

  Future<void> save(Map<String, String> values) =>
      _database.transaction(() async {
        final now = DateTime.now().toIso8601String();
        for (final entry in values.entries) {
          _database.execute(
            'INSERT INTO settings(key,value,updated_at) VALUES(?,?,?) '
            'ON CONFLICT(key) DO UPDATE SET value=excluded.value,updated_at=excluded.updated_at',
            [entry.key, entry.value, now],
          );
        }
      });

  List<Map<String, dynamic>> warehouses() => _database.query(
    'SELECT id,name,location,description,is_active,sort_order FROM warehouses '
    'ORDER BY sort_order,id',
  );

  Future<void> saveWarehouse({
    int? id,
    required String name,
    required String location,
    required String description,
    required bool active,
  }) => _database.transaction(() async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const SettingsValidationException('اكتب اسم المخزن.');
    }
    final duplicate = _database.query(
      'SELECT id FROM warehouses WHERE name=? COLLATE NOCASE AND id<>COALESCE(?, -1)',
      [clean, id],
    );
    if (duplicate.isNotEmpty) {
      throw const SettingsValidationException('اسم المخزن مستخدم بالفعل.');
    }
    final now = DateTime.now().toIso8601String();
    if (id == null) {
      final rows = _database.query(
        'SELECT COALESCE(MAX(sort_order),-1)+1 AS n FROM warehouses',
      );
      _database.insert(
        'INSERT INTO warehouses(name,location,description,is_active,sort_order,created_at) VALUES(?,?,?,?,?,?)',
        [
          clean,
          _nullable(location),
          _nullable(description),
          active ? 1 : 0,
          rows.first['n'],
          now,
        ],
      );
    } else {
      _database.execute(
        'UPDATE warehouses SET name=?,location=?,description=?,is_active=? WHERE id=?',
        [
          clean,
          _nullable(location),
          _nullable(description),
          active ? 1 : 0,
          id,
        ],
      );
    }
  });

  Future<void> deleteWarehouse(int id) => _database.transaction(() async {
    final references = _database.query(
      'SELECT '
      '(SELECT COUNT(*) FROM stock_movements WHERE from_warehouse_id=? OR to_warehouse_id=?) + '
      '(SELECT COUNT(*) FROM stocktaking_sessions WHERE warehouse_id=?) + '
      '(SELECT COUNT(*) FROM stock_adjustment_sessions WHERE warehouse_id=?) + '
      '(SELECT COUNT(*) FROM stock_transfer_sessions WHERE from_warehouse_id=? OR to_warehouse_id=?) AS n',
      [id, id, id, id, id, id],
    );
    if (((references.first['n'] as num?)?.toInt() ?? 0) > 0) {
      _database.execute('UPDATE warehouses SET is_active=0 WHERE id=?', [id]);
      return;
    }
    _database.execute('DELETE FROM warehouses WHERE id=?', [id]);
  });

  Future<void> moveWarehouse(int id, int direction) =>
      _database.transaction(() async {
        final rows = warehouses();
        final index = rows.indexWhere((row) => row['id'] == id);
        final target = index + direction;
        if (index < 0 || target < 0 || target >= rows.length) return;
        _swapOrder('warehouses', rows[index], rows[target]);
      });

  List<Map<String, dynamic>> treasuries() => _database.query(
    'SELECT id,name,opening_balance,description,is_active,sort_order FROM treasuries ORDER BY sort_order,id',
  );

  Future<void> saveTreasury({
    int? id,
    required String name,
    required int openingBalance,
    required String description,
    required bool active,
  }) => _database.transaction(() async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const SettingsValidationException('اكتب اسم الخزينة.');
    }
    if (openingBalance < 0) {
      throw const SettingsValidationException(
        'الرصيد الافتتاحي لا يمكن أن يكون سالباً.',
      );
    }
    final now = DateTime.now().toIso8601String();
    if (id == null) {
      final order = _database
          .query('SELECT COALESCE(MAX(sort_order),-1)+1 AS n FROM treasuries')
          .first['n'];
      _database.execute(
        'INSERT INTO treasuries(name,opening_balance,description,is_active,sort_order,created_at) VALUES(?,?,?,?,?,?)',
        [
          clean,
          openingBalance,
          _nullable(description),
          active ? 1 : 0,
          order,
          now,
        ],
      );
    } else {
      _database.execute(
        'UPDATE treasuries SET name=?,opening_balance=?,description=?,is_active=? WHERE id=?',
        [clean, openingBalance, _nullable(description), active ? 1 : 0, id],
      );
    }
  });

  Future<void> deleteTreasury(int id) => _database.transaction(() async {
    final references = _database.query(
      'SELECT COUNT(*) AS n FROM treasury_transactions WHERE treasury_id=? OR peer_treasury_id=?',
      [id, id],
    );
    if (((references.first['n'] as num?)?.toInt() ?? 0) > 0) {
      _database.execute('UPDATE treasuries SET is_active=0 WHERE id=?', [id]);
      return;
    }
    final activeCount = _database.query(
      'SELECT COUNT(*) AS n FROM treasuries WHERE is_active=1',
    );
    if (((activeCount.first['n'] as num?)?.toInt() ?? 0) <= 1) {
      throw const SettingsValidationException(
        'يجب الاحتفاظ بخزينة نشطة واحدة على الأقل.',
      );
    }
    _database.execute('DELETE FROM treasuries WHERE id=?', [id]);
  });

  Future<void> moveTreasury(int id, int direction) =>
      _database.transaction(() async {
        final rows = treasuries();
        final index = rows.indexWhere((row) => row['id'] == id);
        final target = index + direction;
        if (index < 0 || target < 0 || target >= rows.length) return;
        _swapOrder('treasuries', rows[index], rows[target]);
      });

  List<Map<String, dynamic>> paymentMethods() => _database.query(
    'SELECT id,code,name,kind,is_active,sort_order FROM payment_methods ORDER BY sort_order,id',
  );

  Future<void> savePaymentMethod({
    int? id,
    required String code,
    required String name,
    required String kind,
    required bool active,
  }) => _database.transaction(() async {
    final cleanCode = code.trim().toLowerCase();
    final cleanName = name.trim();
    if (cleanCode.isEmpty || cleanName.isEmpty) {
      throw const SettingsValidationException('أدخل كود وطريقة السداد.');
    }
    final duplicate = _database.query(
      'SELECT id FROM payment_methods WHERE code=? AND id<>COALESCE(?, -1)',
      [cleanCode, id],
    );
    if (duplicate.isNotEmpty) {
      throw const SettingsValidationException(
        'كود طريقة السداد مستخدم بالفعل.',
      );
    }
    final now = DateTime.now().toIso8601String();
    if (id == null) {
      final rows = _database.query(
        'SELECT COALESCE(MAX(sort_order),-1)+1 AS n FROM payment_methods',
      );
      _database.execute(
        'INSERT INTO payment_methods(code,name,kind,is_active,sort_order,created_at,updated_at) VALUES(?,?,?,?,?,?,?)',
        [cleanCode, cleanName, kind, active ? 1 : 0, rows.first['n'], now, now],
      );
    } else {
      _database.execute(
        'UPDATE payment_methods SET code=?,name=?,kind=?,is_active=?,updated_at=? WHERE id=?',
        [cleanCode, cleanName, kind, active ? 1 : 0, now, id],
      );
    }
  });

  Future<void> deletePaymentMethod(int id) => _database.transaction(() async {
    final rows = _database.query(
      'SELECT code FROM payment_methods WHERE id=?',
      [id],
    );
    if (rows.isEmpty) return;
    final code = '${rows.first['code']}';
    final references = _database.query(
      'SELECT COUNT(*) AS n FROM payments WHERE payment_method=?',
      [code],
    );
    if (((references.first['n'] as num?)?.toInt() ?? 0) > 0) {
      _database.execute('UPDATE payment_methods SET is_active=0 WHERE id=?', [
        id,
      ]);
      return;
    }
    final activeCount = _database.query(
      'SELECT COUNT(*) AS n FROM payment_methods WHERE is_active=1',
    );
    if (((activeCount.first['n'] as num?)?.toInt() ?? 0) <= 1) {
      throw const SettingsValidationException(
        'يجب الاحتفاظ بطريقة سداد نشطة واحدة على الأقل.',
      );
    }
    _database.execute('DELETE FROM payment_methods WHERE id=?', [id]);
  });

  Future<void> movePaymentMethod(int id, int direction) =>
      _database.transaction(() async {
        final rows = paymentMethods();
        final index = rows.indexWhere((row) => row['id'] == id);
        final target = index + direction;
        if (index < 0 || target < 0 || target >= rows.length) return;
        _swapOrder('payment_methods', rows[index], rows[target]);
      });

  List<Map<String, dynamic>> currencies() => _database.query(
    'SELECT id,code,name,symbol,country_code,decimal_places,exchange_rate,is_primary,is_active,sort_order '
    'FROM currencies ORDER BY sort_order,id',
  );

  Future<void> saveCurrency({
    int? id,
    required String code,
    required String name,
    required String symbol,
    required String country,
    required int decimalPlaces,
    required double exchangeRate,
    required bool primary,
    required bool active,
  }) => _database.transaction(() async {
    final currencyCode = code.trim().toUpperCase();
    if (currencyCode.length < 3 ||
        currencyCode.length > 5 ||
        name.trim().isEmpty ||
        symbol.trim().isEmpty) {
      throw const SettingsValidationException(
        'أدخل كود العملة واسمها ورمزها بشكل صحيح.',
      );
    }
    if (exchangeRate <= 0 || decimalPlaces < 0 || decimalPlaces > 4) {
      throw const SettingsValidationException(
        'سعر الصرف أو عدد الخانات العشرية غير صحيح.',
      );
    }
    final duplicate = _database.query(
      'SELECT id FROM currencies WHERE code=? AND id<>COALESCE(?, -1)',
      [currencyCode, id],
    );
    if (duplicate.isNotEmpty) {
      throw const SettingsValidationException('كود العملة مستخدم بالفعل.');
    }
    final now = DateTime.now().toIso8601String();
    if (primary) _database.execute('UPDATE currencies SET is_primary=0');
    if (id == null) {
      final order = _database
          .query('SELECT COALESCE(MAX(sort_order),-1)+1 AS n FROM currencies')
          .first['n'];
      _database.execute(
        'INSERT INTO currencies(code,name,symbol,country_code,decimal_places,exchange_rate,is_primary,is_active,sort_order,created_at,updated_at) '
        'VALUES(?,?,?,?,?,?,?,?,?,?,?)',
        [
          currencyCode,
          name.trim(),
          symbol.trim(),
          country.trim().toUpperCase(),
          decimalPlaces,
          exchangeRate,
          primary ? 1 : 0,
          active ? 1 : 0,
          order,
          now,
          now,
        ],
      );
    } else {
      _database.execute(
        'UPDATE currencies SET code=?,name=?,symbol=?,country_code=?,decimal_places=?,exchange_rate=?,is_primary=?,is_active=?,updated_at=? WHERE id=?',
        [
          currencyCode,
          name.trim(),
          symbol.trim(),
          country.trim().toUpperCase(),
          decimalPlaces,
          exchangeRate,
          primary ? 1 : 0,
          active ? 1 : 0,
          now,
          id,
        ],
      );
    }
    if (primary) {
      await _saveWithinTransaction({
        'settings.currency': currencyCode,
        'settings.currency_symbol': symbol.trim(),
        'settings.country': country.trim().toUpperCase(),
      }, now);
    }
  });

  Future<void> setPrimaryCurrency(int id) => _database.transaction(() async {
    final rows = _database.query(
      'SELECT code,symbol,country_code FROM currencies WHERE id=? AND is_active=1',
      [id],
    );
    if (rows.isEmpty) {
      throw const SettingsValidationException(
        'العملة المحددة غير موجودة أو غير نشطة.',
      );
    }
    _database.execute('UPDATE currencies SET is_primary=0');
    _database.execute('UPDATE currencies SET is_primary=1 WHERE id=?', [id]);
    await _saveWithinTransaction({
      'settings.currency': '${rows.first['code']}',
      'settings.currency_symbol': '${rows.first['symbol']}',
      'settings.country': '${rows.first['country_code']}',
    }, DateTime.now().toIso8601String());
  });

  List<SettingsUser> users() {
    final rows = _database.query(
      'SELECT id,username,display_name,is_admin,is_active,sort_order FROM program_users ORDER BY sort_order,id',
    );
    return [
      for (final row in rows)
        SettingsUser(
          id: (row['id'] as num).toInt(),
          username: '${row['username'] ?? ''}',
          displayName: '${row['display_name'] ?? ''}',
          isAdmin: ((row['is_admin'] as num?)?.toInt() ?? 0) == 1,
          isActive: ((row['is_active'] as num?)?.toInt() ?? 1) == 1,
          sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
          permissions: _database
              .query(
                'SELECT permission_code FROM program_user_permissions WHERE user_id=?',
                [row['id']],
              )
              .map((p) => '${p['permission_code']}')
              .toSet(),
          roleIds: _database
              .query('SELECT role_id FROM program_user_roles WHERE user_id=?', [
                row['id'],
              ])
              .map((r) => (r['role_id'] as num).toInt())
              .toSet(),
        ),
    ];
  }

  List<SettingsRole> roles() {
    final rows = _database.query(
      'SELECT id,name,description,sort_order FROM program_roles ORDER BY sort_order,id',
    );
    return [
      for (final row in rows)
        SettingsRole(
          id: (row['id'] as num).toInt(),
          name: '${row['name'] ?? ''}',
          description: '${row['description'] ?? ''}',
          sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
          permissions: _database
              .query(
                'SELECT permission_code FROM program_role_permissions WHERE role_id=?',
                [row['id']],
              )
              .map((p) => '${p['permission_code']}')
              .toSet(),
          userCount:
              (_database.query(
                        'SELECT COUNT(*) AS count FROM program_user_roles WHERE role_id=?',
                        [row['id']],
                      ).first['count']
                      as num?)
                  ?.toInt() ??
              0,
        ),
    ];
  }

  Future<void> saveRole({
    int? id,
    required String name,
    required String description,
    required Set<String> permissions,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const SettingsValidationException('اكتب اسم مجموعة الصلاحيات.');
    }
    final duplicates = _database.query(
      'SELECT id FROM program_roles WHERE name=? COLLATE NOCASE AND id<>COALESCE(?, -1)',
      [cleanName, id],
    );
    if (duplicates.isNotEmpty) {
      throw const SettingsValidationException(
        'اسم مجموعة الصلاحيات مستخدم بالفعل.',
      );
    }
    await _database.transaction(() async {
      final now = DateTime.now().toIso8601String();
      var roleId = id;
      if (id == null) {
        final order = _database
            .query(
              'SELECT COALESCE(MAX(sort_order),-1)+1 AS n FROM program_roles',
            )
            .first['n'];
        roleId = _database.insert(
          'INSERT INTO program_roles(name,description,sort_order,created_at,updated_at) VALUES(?,?,?,?,?)',
          [cleanName, description.trim(), order, now, now],
        );
      } else {
        _database.execute(
          'UPDATE program_roles SET name=?,description=?,updated_at=? WHERE id=?',
          [cleanName, description.trim(), now, id],
        );
      }
      _database.execute(
        'DELETE FROM program_role_permissions WHERE role_id=?',
        [roleId],
      );
      for (final code in permissions) {
        _database.execute(
          'INSERT INTO program_role_permissions(role_id,permission_code) VALUES(?,?)',
          [roleId, code],
        );
      }
    });
  }

  Future<void> deleteRole(int id) => _database.transaction(() async {
    _database.execute('DELETE FROM program_user_roles WHERE role_id=?', [id]);
    _database.execute('DELETE FROM program_roles WHERE id=?', [id]);
  });

  Future<void> saveUser({
    int? id,
    required String username,
    required String displayName,
    String? password,
    required bool isAdmin,
    required bool isActive,
    required Set<String> permissions,
    Set<int> roleIds = const {},
  }) async {
    final cleanUsername = username.trim();
    final cleanDisplay = displayName.trim();
    if (cleanUsername.length < 3 || cleanDisplay.isEmpty) {
      throw const SettingsValidationException(
        'أدخل اسم مستخدم (3 أحرف على الأقل) والاسم الظاهر.',
      );
    }
    if (id == null && (password == null || password.length < 8)) {
      throw const SettingsValidationException(
        'كلمة المرور يجب أن تكون 8 أحرف على الأقل.',
      );
    }
    if (password != null && password.isNotEmpty && password.length < 8) {
      throw const SettingsValidationException(
        'كلمة المرور الجديدة يجب أن تكون 8 أحرف على الأقل.',
      );
    }
    if (id != null && (!isAdmin || !isActive)) {
      final existing = _database.query(
        'SELECT is_admin FROM program_users WHERE id=?',
        [id],
      );
      if (existing.isNotEmpty &&
          ((existing.first['is_admin'] as num?)?.toInt() ?? 0) == 1) {
        final otherAdmins = _database.query(
          'SELECT COUNT(*) AS n FROM program_users '
          'WHERE id<>? AND is_admin=1 AND is_active=1',
          [id],
        );
        if (((otherAdmins.first['n'] as num?)?.toInt() ?? 0) == 0) {
          throw const SettingsValidationException(
            'لا يمكن تعطيل آخر مدير نشط في البرنامج.',
          );
        }
      }
    }
    final duplicate = _database.query(
      'SELECT id FROM program_users WHERE username=? COLLATE NOCASE AND id<>COALESCE(?, -1)',
      [cleanUsername, id],
    );
    if (duplicate.isNotEmpty) {
      throw const SettingsValidationException('اسم المستخدم مستخدم بالفعل.');
    }
    final hash = password == null || password.isEmpty
        ? null
        : await PasswordHasher.hash(password);
    await _database.transaction(() async {
      final now = DateTime.now().toIso8601String();
      var userId = id;
      if (id == null) {
        final order = _database
            .query(
              'SELECT COALESCE(MAX(sort_order),-1)+1 AS n FROM program_users',
            )
            .first['n'];
        userId = _database.insert(
          'INSERT INTO program_users(username,display_name,password_salt,password_hash,is_admin,is_active,sort_order,created_at,updated_at) '
          'VALUES(?,?,?,?,?,?,?,?,?)',
          [
            cleanUsername,
            cleanDisplay,
            hash!.salt,
            hash.hash,
            isAdmin ? 1 : 0,
            isActive ? 1 : 0,
            order,
            now,
            now,
          ],
        );
      } else {
        if (hash == null) {
          _database.execute(
            'UPDATE program_users SET username=?,display_name=?,is_admin=?,is_active=?,updated_at=? WHERE id=?',
            [
              cleanUsername,
              cleanDisplay,
              isAdmin ? 1 : 0,
              isActive ? 1 : 0,
              now,
              id,
            ],
          );
        } else {
          _database.execute(
            'UPDATE program_users SET username=?,display_name=?,password_salt=?,password_hash=?,is_admin=?,is_active=?,updated_at=? WHERE id=?',
            [
              cleanUsername,
              cleanDisplay,
              hash.salt,
              hash.hash,
              isAdmin ? 1 : 0,
              isActive ? 1 : 0,
              now,
              id,
            ],
          );
        }
      }
      _database.execute(
        'DELETE FROM program_user_permissions WHERE user_id=?',
        [userId],
      );
      if (!isAdmin) {
        for (final code in permissions) {
          _database.execute(
            'INSERT INTO program_user_permissions(user_id,permission_code) VALUES(?,?)',
            [userId, code],
          );
        }
        for (final roleId in roleIds) {
          _database.execute(
            'INSERT INTO program_user_roles(user_id,role_id) VALUES(?,?)',
            [userId, roleId],
          );
        }
      }
    });
  }

  Future<void> deleteUser(int id) => _database.transaction(() async {
    final user = _database.query(
      'SELECT is_admin FROM program_users WHERE id=?',
      [id],
    );
    if (user.isEmpty) return;
    if (((user.first['is_admin'] as num?)?.toInt() ?? 0) == 1) {
      final admins = _database.query(
        'SELECT COUNT(*) AS n FROM program_users WHERE is_admin=1 AND is_active=1 AND id<>?',
        [id],
      );
      if (((admins.first['n'] as num?)?.toInt() ?? 0) == 0) {
        throw const SettingsValidationException(
          'لا يمكن تعطيل آخر مدير نشط في البرنامج.',
        );
      }
    }
    _database.execute(
      'UPDATE program_users SET is_active=0,updated_at=? WHERE id=?',
      [DateTime.now().toIso8601String(), id],
    );
  });

  Future<void> moveUser(int id, int direction) =>
      _database.transaction(() async {
        final rows = users();
        final index = rows.indexWhere((row) => row.id == id);
        final target = index + direction;
        if (index < 0 || target < 0 || target >= rows.length) return;
        final a = rows[index];
        final b = rows[target];
        _database.execute('UPDATE program_users SET sort_order=? WHERE id=?', [
          b.sortOrder,
          a.id,
        ]);
        _database.execute('UPDATE program_users SET sort_order=? WHERE id=?', [
          a.sortOrder,
          b.id,
        ]);
      });

  List<Map<String, dynamic>> fieldDefinitions(String scope) => _database.query(
    'SELECT id,name,scope,is_active,sort_order FROM document_custom_fields WHERE scope=? ORDER BY sort_order,id',
    [scope],
  );

  Future<void> saveField({
    int? id,
    required String name,
    required String scope,
  }) => _database.transaction(() async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const SettingsValidationException('اكتب اسم الحقل.');
    }
    final now = DateTime.now().toIso8601String();
    if (id == null) {
      final order = _database.query(
        'SELECT COALESCE(MAX(sort_order),-1)+1 AS n FROM document_custom_fields WHERE scope=?',
        [scope],
      ).first['n'];
      _database.execute(
        'INSERT INTO document_custom_fields(name,scope,is_active,sort_order,created_at,updated_at) VALUES(?,?,1,?,?,?)',
        [clean, scope, order, now, now],
      );
    } else {
      _database.execute(
        'UPDATE document_custom_fields SET name=?,scope=?,updated_at=? WHERE id=?',
        [clean, scope, now, id],
      );
    }
  });

  Future<void> deleteField(int id) => _database.transaction(() async {
    _database.execute(
      'UPDATE document_custom_fields SET is_active=0,updated_at=? WHERE id=?',
      [DateTime.now().toIso8601String(), id],
    );
  });

  Map<int, String> entityValues(String scope, int entityId) => {
    for (final row in _database.query(
      'SELECT field_id,value FROM entity_custom_values WHERE scope=? AND entity_id=?',
      [scope, entityId],
    ))
      (row['field_id'] as num).toInt(): '${row['value'] ?? ''}',
  };

  Future<void> saveEntityValues(
    String scope,
    int entityId,
    Map<int, String> values,
  ) => _database.transaction(() async {
    final now = DateTime.now().toIso8601String();
    for (final entry in values.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) {
        _database.execute(
          'DELETE FROM entity_custom_values WHERE scope=? AND entity_id=? AND field_id=?',
          [scope, entityId, entry.key],
        );
      } else {
        _database.execute(
          'INSERT INTO entity_custom_values(scope,entity_id,field_id,value,updated_at) VALUES(?,?,?,?,?) '
          'ON CONFLICT(scope,entity_id,field_id) DO UPDATE SET value=excluded.value,updated_at=excluded.updated_at',
          [scope, entityId, entry.key, value, now],
        );
      }
    }
  });

  Future<void> _saveWithinTransaction(
    Map<String, String> values,
    String now,
  ) async {
    for (final entry in values.entries) {
      _database.execute(
        'INSERT INTO settings(key,value,updated_at) VALUES(?,?,?) '
        'ON CONFLICT(key) DO UPDATE SET value=excluded.value,updated_at=excluded.updated_at',
        [entry.key, entry.value, now],
      );
    }
  }

  void _swapOrder(
    String table,
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    _database.execute('UPDATE $table SET sort_order=? WHERE id=?', [
      second['sort_order'],
      first['id'],
    ]);
    _database.execute('UPDATE $table SET sort_order=? WHERE id=?', [
      first['sort_order'],
      second['id'],
    ]);
  }

  static String? _nullable(String value) =>
      value.trim().isEmpty ? null : value.trim();
}

class SettingsValidationException implements Exception {
  const SettingsValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}
