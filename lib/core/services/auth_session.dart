import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:safwa/app/theme/app_theme.dart';
import 'package:safwa/core/database/sqlite_database.dart';
import 'package:safwa/core/security/password_hasher.dart';
import 'package:safwa/core/security/permission_catalog.dart';
import 'package:safwa/core/services/system_session_id.dart';

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

/// Authentication state persists for the current Windows logon session.
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
    _ensureSessionTable();
    final users = _db.query('SELECT COUNT(*) AS count FROM program_users');
    _setupRequired = ((users.first['count'] as num?)?.toInt() ?? 0) == 0;
    if (!_setupRequired) await _restoreSession();
    _initialized = true;
    notifyListeners();
  }

  void _ensureSessionTable() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS program_auth_sessions (
        singleton INTEGER PRIMARY KEY CHECK(singleton = 1),
        user_id INTEGER NOT NULL REFERENCES program_users(id) ON DELETE CASCADE,
        system_session_id TEXT NOT NULL,
        boot_time_ms INTEGER NOT NULL,
        saved_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _restoreSession() async {
    final currentSystemSession = currentSystemSessionId();
    final currentBootTime = currentSystemBootTimeMs();
    if (currentSystemSession == null || currentBootTime == null) {
      _db.execute('DELETE FROM program_auth_sessions');
      return;
    }
    final sessions = _db.query(
      'SELECT user_id,system_session_id,boot_time_ms '
      'FROM program_auth_sessions WHERE singleton=1',
    );
    if (sessions.isEmpty) return;
    final savedBootTime = (sessions.first['boot_time_ms'] as num).toInt();
    if (sessions.first['system_session_id'] != currentSystemSession ||
        (savedBootTime - currentBootTime).abs() > 3000) {
      _db.execute('DELETE FROM program_auth_sessions');
      return;
    }
    final userId = (sessions.first['user_id'] as num).toInt();
    final users = _db.query(
      'SELECT id,username,display_name,is_admin FROM program_users '
      'WHERE id=? AND is_active=1',
      [userId],
    );
    if (users.isEmpty) {
      _db.execute('DELETE FROM program_auth_sessions');
      return;
    }
    await _loadUser(users.first);
    _recordAuthEvent(
      userId: userId,
      username: '${users.first['username'] ?? ''}',
      eventType: 'session_restored',
    );
  }

  void _persistSession() {
    _ensureSessionTable();
    final current = _user;
    final systemSessionId = currentSystemSessionId();
    final bootTime = currentSystemBootTimeMs();
    if (current == null || systemSessionId == null || bootTime == null) {
      _db.execute('DELETE FROM program_auth_sessions');
      return;
    }
    _db.execute(
      'INSERT INTO program_auth_sessions(singleton,user_id,system_session_id,boot_time_ms,saved_at) '
      'VALUES(1,?,?,?,?) ON CONFLICT(singleton) DO UPDATE SET '
      'user_id=excluded.user_id,system_session_id=excluded.system_session_id,'
      'boot_time_ms=excluded.boot_time_ms,saved_at=excluded.saved_at',
      [current.id, systemSessionId, bootTime, DateTime.now().toIso8601String()],
    );
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
      _recordAuthEvent(
        userId: rows.isEmpty ? null : (rows.first['id'] as num).toInt(),
        username: username.trim(),
        eventType: 'login_failed',
      );
      return 'اسم المستخدم أو كلمة المرور غير صحيحة.';
    }
    _failures.remove(key);
    _recordAuthEvent(
      userId: (rows.first['id'] as num).toInt(),
      username: '${rows.first['username'] ?? username.trim()}',
      eventType: 'login_success',
    );
    await _loadUser(rows.first);
    _persistSession();
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

  Future<String?> changeCurrentPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = _user;
    if (current == null) return 'سجّل الدخول تاني قبل ما تغيّر كلمة السر.';
    if (newPassword.length < 8) {
      return 'كلمة السر الجديدة لازم تكون ٨ أحرف على الأقل.';
    }
    final failureKey = 'password:${current.id}';
    final now = DateTime.now();
    if (_isLockedOut(failureKey, now)) {
      final seconds =
          _failures[failureKey]!.lockedUntil!.difference(now).inSeconds + 1;
      return 'محاولات كتير غلط. جرّب بعد $seconds ثانية.';
    }
    final rows = _db.query(
      'SELECT password_salt,password_hash FROM program_users '
      'WHERE id=? AND is_active=1',
      [current.id],
    );
    if (rows.isEmpty) return 'الحساب مش نشط.';
    final valid = await PasswordHasher.verify(
      password: currentPassword,
      salt: rows.first['password_salt'] as String,
      expectedHash: rows.first['password_hash'] as String,
    );
    if (!valid) {
      _recordFailedAttempt(failureKey, now);
      return 'كلمة السر الحالية مش صحيحة.';
    }
    if (currentPassword == newPassword) {
      return 'اختار كلمة سر جديدة مختلفة عن الحالية.';
    }
    final derived = await PasswordHasher.hash(newPassword);
    _db.execute(
      'UPDATE program_users SET password_salt=?,password_hash=?,updated_at=? '
      'WHERE id=? AND is_active=1',
      [
        derived.salt,
        derived.hash,
        DateTime.now().toIso8601String(),
        current.id,
      ],
    );
    _failures.remove(failureKey);
    return null;
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
    permissions.addAll(
      _db
          .query(
            'SELECT DISTINCT rp.permission_code FROM program_role_permissions rp '
            'JOIN program_user_roles ur ON ur.role_id=rp.role_id '
            'JOIN program_roles r ON r.id=ur.role_id '
            'WHERE ur.user_id=?',
            [id],
          )
          .map((r) => '${r['permission_code']}'),
    );
    _user = ProgramUser(
      id: id,
      username: '${row['username'] ?? ''}',
      displayName: '${row['display_name'] ?? ''}',
      isAdmin: ((row['is_admin'] as num?)?.toInt() ?? 0) == 1,
      permissions: permissions,
    );
    final themePreference = currentUserPreference('theme', 'dark');
    AppThemeController.mode.value = themePreference == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  bool hasPermission(String code) =>
      isAdmin || (_user?.permissions.contains(code) ?? false);

  bool canOpenLocation(String location) {
    if (!isAuthenticated) return false;
    final path = Uri.tryParse(location)?.path ?? location;
    if (path == '/user-dashboard') return isAuthenticated;
    if (path == '/settings') return isAdmin;
    final permission = permissionForLocation(path);
    return permission != null && hasPermission(permission);
  }

  void logout() {
    final current = _user;
    if (current != null) {
      _recordAuthEvent(
        userId: current.id,
        username: current.username,
        eventType: 'logout',
      );
    }
    _user = null;
    _ensureSessionTable();
    _db.execute('DELETE FROM program_auth_sessions');
    notifyListeners();
  }

  List<Map<String, dynamic>> loginHistoryForCurrentUser({int limit = 100}) {
    final id = _user?.id;
    if (id == null) return const [];
    final safeLimit = limit.clamp(1, 500);
    return _db.query(
      'SELECT id,username,event_type,event_time FROM program_login_history '
      'WHERE user_id=? ORDER BY id DESC LIMIT $safeLimit',
      [id],
    );
  }

  String currentUserPreference(String key, [String fallback = '']) {
    final id = _user?.id;
    if (id == null) return fallback;
    final rows = _db.query(
      'SELECT preference_value FROM program_user_preferences WHERE user_id=? AND preference_key=?',
      [id, key],
    );
    return rows.isEmpty
        ? fallback
        : '${rows.first['preference_value'] ?? fallback}';
  }

  Future<void> saveCurrentUserPreference(String key, String value) async {
    final id = _user?.id;
    if (id == null) return;
    _db.execute(
      'INSERT INTO program_user_preferences(user_id,preference_key,preference_value,updated_at) '
      'VALUES(?,?,?,?) ON CONFLICT(user_id,preference_key) DO UPDATE SET '
      'preference_value=excluded.preference_value,updated_at=excluded.updated_at',
      [id, key, value, DateTime.now().toIso8601String()],
    );
  }

  void _recordAuthEvent({
    required String username,
    required String eventType,
    int? userId,
  }) {
    _db.insert(
      'INSERT INTO program_login_history(user_id,username,event_type,event_time) VALUES(?,?,?,?)',
      [userId, username, eventType, DateTime.now().toIso8601String()],
    );
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
