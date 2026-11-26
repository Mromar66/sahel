import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:safwa/core/database/sqlite_database.dart';
import 'package:safwa/core/security/password_hasher.dart';

/// Password-protected local SQLite backups.
///
/// The backup file contains an authenticated AES-GCM envelope. A fresh salt
/// derives the encryption key from the password for each backup, so changing
/// the configured password does not invalidate older backup files.
class BackupService {
  BackupService._internal();

  static final BackupService _instance = BackupService._internal();

  factory BackupService() => _instance;

  static const _extension = '.sahbk';
  static final List<int> _magic = ascii.encode('SAHELBK1');
  final SqliteDatabase _database = SqliteDatabase();
  final AesGcm _cipher = AesGcm.with256bits();

  Future<Directory> getBackupFolder() async {
    final appDir = await getApplicationSupportDirectory();
    final backupFolder = Directory(p.join(appDir.path, 'backups'));
    if (!await backupFolder.exists()) {
      await backupFolder.create(recursive: true);
    }
    return backupFolder;
  }

  Future<File> createEncryptedBackup(String password) async {
    if (password.length < 8) {
      throw const BackupException('كلمة مرور النسخة الاحتياطية غير صحيحة.');
    }
    final folder = await getBackupFolder();
    final stamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final snapshot = File(p.join(folder.path, '.snapshot-$stamp.sqlite'));
    final output = File(p.join(folder.path, 'sahel_backup_$stamp$_extension'));
    try {
      await _database.backupTo(snapshot.path);
      final plaintext = await snapshot.readAsBytes();
      final derivation = await PasswordHasher.hash(password);
      final salt = base64Url.decode(derivation.salt);
      final keyBytes = base64Url.decode(derivation.hash);
      final authenticatedHeader = [..._magic, ...salt];
      final box = await _cipher.encrypt(
        plaintext,
        secretKey: SecretKey(keyBytes),
        nonce: _cipher.newNonce(),
        aad: authenticatedHeader,
      );
      await output.writeAsBytes([
        ...authenticatedHeader,
        ...box.concatenation(),
      ], flush: true);
      return output;
    } on Object catch (error) {
      if (output.existsSync()) await output.delete();
      if (error is BackupException) rethrow;
      throw BackupException('تعذر إنشاء النسخة الاحتياطية: $error');
    } finally {
      if (snapshot.existsSync()) await snapshot.delete();
    }
  }

  Future<void> restoreEncryptedBackup(File backup, String password) async {
    final folder = await getBackupFolder();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final staged = File(p.join(folder.path, '.restore-$stamp.sqlite'));
    try {
      if (!await backup.exists()) {
        throw const BackupException('ملف النسخة الاحتياطية غير موجود.');
      }
      final bytes = await backup.readAsBytes();
      const headerLength = 8 + 16;
      if (bytes.length < headerLength + 12 + 16 ||
          !_startsWith(bytes, _magic)) {
        throw const BackupException('صيغة ملف النسخة الاحتياطية غير معروفة.');
      }
      final salt = bytes.sublist(8, headerLength);
      // Re-derive with the salt stored in the backup, not a newly generated one.
      final keyBytes = await PasswordHasher.deriveKey(password, salt);
      final payload = bytes.sublist(headerLength);
      final box = SecretBox.fromConcatenation(
        payload,
        nonceLength: _cipher.nonceLength,
        macLength: _cipher.macAlgorithm.macLength,
        copy: false,
      );
      List<int> plaintext;
      try {
        plaintext = await _cipher.decrypt(
          box,
          secretKey: SecretKey(keyBytes),
          aad: [..._magic, ...salt],
        );
      } on SecretBoxAuthenticationError {
        throw const BackupException('كلمة مرور النسخة الاحتياطية غير صحيحة.');
      }
      await staged.writeAsBytes(plaintext, flush: true);
      _validateDatabase(staged.path);
      _database.replaceFromFile(staged.path);
    } on BackupException {
      rethrow;
    } on Object catch (error) {
      throw BackupException('تعذر استعادة النسخة الاحتياطية: $error');
    } finally {
      if (staged.existsSync()) await staged.delete();
    }
  }

  Future<List<File>> listBackups() async {
    final backupFolder = await getBackupFolder();
    final files = backupFolder
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith(_extension))
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  Future<void> deleteBackup(File file) async {
    final folder = await getBackupFolder();
    final resolvedFolder = p.normalize(p.absolute(folder.path));
    final resolvedFile = p.normalize(p.absolute(file.path));
    if (p.dirname(resolvedFile) != resolvedFolder ||
        !resolvedFile.toLowerCase().endsWith(_extension)) {
      throw const BackupException('ملف النسخة المحدد غير صالح.');
    }
    if (await file.exists()) await file.delete();
  }

  static bool _startsWith(List<int> bytes, List<int> prefix) {
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  static void _validateDatabase(String path) {
    sqlite.Database? db;
    try {
      db = sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readOnly);
      final result = db
          .select('PRAGMA integrity_check')
          .first['integrity_check'];
      if (result != 'ok') {
        throw const BackupException('ملف النسخة الاحتياطية تالف.');
      }
    } on BackupException {
      rethrow;
    } on Object {
      throw const BackupException(
        'ملف النسخة الاحتياطية ليس قاعدة بيانات صالحة.',
      );
    } finally {
      db?.dispose();
    }
  }
}

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}
