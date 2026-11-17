import 'package:flutter/foundation.dart';
import 'package:inventory_app/core/database/sqlite_database.dart';
import 'package:inventory_app/core/security/password_hasher.dart';
import 'package:inventory_app/core/security/permission_catalog.dart';

class ProgramUser {
  const ProgramUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isAdmin,
    required this.permissions,
  });

  final int id;
  final String username;
  final String displayName;
  final bool isAdmin;
  final Set<String> permissions;
}

/// Per-launch authentication state. It is intentionally never persisted: the
/// user must authenticate again after the program is closed.
class AuthSession extends ChangeNotifier {
  AuthSession._();

  static final AuthSession instance = AuthSession._();
  final SqliteDatabase _db = SqliteDatabase();
  ProgramUser? _user;
  bool _initialized = false;
  bool _setupRequired = false;
  final Map<String, ({int count, DateTime? lockedUntil})> _failures = {};

  ProgramUser? get user => _user;
  bool get initialized => _initialized;
  bool get setupRequired => _setupRequired;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<void> initialize() async {
    final users = _db.query('SELECT COUNT(*) AS count FROM program_users');
    _setupRequired = ((users.first['count'] as num?)?.toInt() ?? 0) == 0;
    _initialized = true;
    notifyListeners();
  }

  Future<String?> createFirstAdmin({
    required String username,
    required String displayName,
    required String password,
  }) async {
    if (!_initialized) await initialize();
    final count =
        (_db.query('SELECT COUNT(*) AS count FROM program_users').first['count']
                as num?)
            ?.toInt() ??
        0;
    if (count != 0) return 'تم إنشاء حساب مدير بالفعل. سجّل الدخول للمتابعة.';
    final name = username.trim();
    if (name.length < 3) {
      return 'اسم المستخدم يجب أن يتكون من 3 أحرف على الأقل.';
    }
    if (displayName.trim().isEmpty) {
      return 'اكتب اسم المدير الظاهر في البرنامج.';
    }
    if (password.length < 8) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.';
    final derived = await PasswordHasher.hash(password);
    final now = DateTime.now().toIso8601String();
    String? creationError;
    await _db.transaction<void>(() async {
      final count =
          (_db
                      .query('SELECT COUNT(*) AS count FROM program_users')
                      .first['count']
                  as num?)
              ?.toInt() ??
          0;
      if (count != 0) {
        creationError = 'تم إنشاء حساب مدير بالفعل. سجّل الدخول للمتابعة.';
        return;
      }
      _db.insert(
        'INSERT INTO program_users(username,display_name,password_salt,password_hash,is_admin,is_active,sort_order,created_at,updated_at) '
        'VALUES(?,?,?,?,1,1,0,?,?)',
        [name, displayName.trim(), derived.salt, derived.hash, now, now],
      );
    });
    if (creationError != null) return creationError;
    _setupRequired = false;
    notifyListeners();
    return null;
  }

  Future<String?> login(String username, String password) async {
    if (!_initialized) await initialize();
    final key = username.trim().toLowerCase();
    final now = DateTime.now();
    if (_isLockedOut(key, now)) {
      final seconds =
          _failures[key]!.lockedUntil!.difference(now).inSeconds + 1;
      return 'محاولات كثيرة غير صحيحة. حاول بعد $seconds ثانية.';
    }
    final rows = _db.query(
      'SELECT id,username,display_name,password_salt,password_hash,is_admin '
      'FROM program_users WHERE username = ? COLLATE NOCASE AND is_active = 1',
      [username.trim()],
    );
    var valid = false;
    if (rows.isNotEmpty) {
      valid = await PasswordHasher.verify(
        password: password,
        salt: rows.first['password_salt'] as String,
        expectedHash: rows.first['password_hash'] as String,
      );
    }
    if (!valid) {
      _recordFailedAttempt(key, now);
      return 'اسم المستخدم أو كلمة المرور غير صحيحة.';
    }
    _failures.remove(key);
    await _loadUser(rows.first);
    notifyListeners();
    return null;
  }

  Future<bool> verifyAdminPassword(String password) async {
    final current = _user;
    if (current == null || !current.isAdmin) return false;
    final failureKey = 'settings:${current.id}';
    if (_isLockedOut(failureKey, DateTime.now())) return false;
    final rows = _db.query(
      'SELECT password_salt,password_hash FROM program_users '
      'WHERE id=? AND is_admin=1 AND is_active=1',
      [current.id],
    );
    if (rows.isEmpty) return false;
    final valid = await PasswordHasher.verify(
      password: password,
      salt: rows.first['password_salt'] as String,
      expectedHash: rows.first['password_hash'] as String,
    );
    if (valid) {
      _failures.remove(failureKey);
    } else {
      _recordFailedAttempt(failureKey, DateTime.now());
    }
    return valid;
  }

  Future<void> refreshCurrentUser() async {
    final id = _user?.id;
    if (id == null) return;
    final rows = _db.query(
      'SELECT id,username,display_name,is_admin FROM program_users '
      'WHERE id=? AND is_active=1',
      [id],
    );
    if (rows.isEmpty) {
      logout();
      return;
    }
    await _loadUser(rows.first);
    notifyListeners();
  }

  Future<void> _loadUser(Map<String, dynamic> row) async {
    final id = (row['id'] as num).toInt();
    final permissions = _db
        .query(
          'SELECT permission_code FROM program_user_permissions WHERE user_id=?',
          [id],
        )
        .map((r) => '${r['permission_code']}')
        .toSet();
    _user = ProgramUser(
      id: id,
      username: '${row['username'] ?? ''}',
      displayName: '${row['display_name'] ?? ''}',
      isAdmin: ((row['is_admin'] as num?)?.toInt() ?? 0) == 1,
      permissions: permissions,
    );
  }

  bool hasPermission(String code) =>
      isAdmin || (_user?.permissions.contains(code) ?? false);

  bool canOpenLocation(String location) {
    if (!isAuthenticated) return false;
    final path = Uri.tryParse(location)?.path ?? location;
    if (path == '/settings') return isAdmin;
    final permission = permissionForLocation(path);
    return permission != null && hasPermission(permission);
  }

  void logout() {
    _user = null;
    notifyListeners();
  }

  bool _isLockedOut(String key, DateTime now) {
    final lockedUntil = _failures[key]?.lockedUntil;
    return lockedUntil != null && lockedUntil.isAfter(now);
  }

  void _recordFailedAttempt(String key, DateTime now) {
    final attempts = (_failures[key]?.count ?? 0) + 1;
    _failures[key] = (
      count: attempts >= 5 ? 0 : attempts,
      lockedUntil: attempts >= 5 ? now.add(const Duration(minutes: 1)) : null,
    );
  }
}
