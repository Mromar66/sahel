import 'dart:io';

import 'package:flutter/material.dart';
import 'package:safwa/app/theme/app_theme.dart';
import 'package:safwa/core/security/password_hasher.dart';
import 'package:safwa/core/services/auth_session.dart';
import 'package:safwa/core/services/backup_service.dart';
import 'package:safwa/features/settings/data/settings_repository.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final _service = BackupService();
  final _settings = SettingsRepository.instance;
  List<File> _backups = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _loading = true);
    try {
      final files = await _service.listBackups();
      if (mounted) setState(() => _backups = files);
    } catch (error) {
      if (mounted) _message('تعذر قراءة النسخ الاحتياطية: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createBackup() async {
    final salt = _settings.read('settings.backup_salt');
    final expectedHash = _settings.read('settings.backup_hash');
    if (salt.isEmpty || expectedHash.isEmpty) {
      _message(
        'اضبط كلمة مرور النسخ الاحتياطي أولاً من إعداد Safwa ← كلمات السر.',
      );
      return;
    }
    final password = await _askPassword(
      title: 'إنشاء نسخة احتياطية مشفرة',
      prompt: 'أدخل كلمة المرور التي حفظتها في إعداد Safwa.',
    );
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final valid = await PasswordHasher.verify(
        password: password,
        salt: salt,
        expectedHash: expectedHash,
      );
      if (!valid) {
        _message('كلمة مرور النسخ الاحتياطي غير صحيحة.');
        return;
      }
      await _service.createEncryptedBackup(password);
      await _loadBackups();
      if (mounted) _message('تم إنشاء نسخة احتياطية مشفرة بنجاح.');
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استعادة نسخة احتياطية'),
        content: Text(
          'سيتم استبدال بيانات البرنامج الحالية بالنسخة المحددة.\n\n${pBasename(file.path)}',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final password = await _askPassword(
      title: 'كلمة مرور النسخة',
      prompt: 'أدخل كلمة المرور التي استُخدمت عند إنشاء هذه النسخة.',
    );
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.restoreEncryptedBackup(file, password);
      await AuthSession.instance.refreshCurrentUser();
      await _loadBackups();
      if (mounted) _message('تمت استعادة النسخة الاحتياطية.');
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteBackup(File file) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف النسخة الاحتياطية'),
        content: Text('هل تريد حذف «${pBasename(file.path)}»؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (remove != true) return;
    try {
      await _service.deleteBackup(file);
      await _loadBackups();
    } catch (error) {
      if (mounted) _message(error.toString());
    }
  }

  Future<String?> _askPassword({
    required String title,
    required String prompt,
  }) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(prompt),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    onSubmitted: (value) => Navigator.pop(dialogContext, value),
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: const Text('متابعة'),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي والاستعادة'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _busy ? null : _loadBackups,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'إدارة النسخ الاحتياطية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تُنشأ النسخ بتشفير AES-GCM، ولا يمكن فتحها بدون كلمة المرور الخاصة بها.',
                  style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 13),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _createBackup,
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('إنشاء نسخة احتياطية مشفرة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'النسخ الاحتياطية المتاحة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: _backupList()),
              ],
            ),
          ),
          if (_busy)
            ColoredBox(
              color: const Color(0x66000000),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    ),
  );

  Widget _backupList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_backups.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد نسخ احتياطية بعد.',
          style: TextStyle(color: Color(0xFFB0B0B0)),
        ),
      );
    }
    return ListView.separated(
      itemCount: _backups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final file = _backups[index];
        final modified = file.lastModifiedSync().toLocal();
        return Card(
          color: AppTheme.surfaceColor,
          child: ListTile(
            leading: const Icon(Icons.lock_outline, color: Color(0xFF8DCDE2)),
            title: Text(pBasename(file.path), textDirection: TextDirection.ltr),
            subtitle: Text(
              '${modified.toString().substring(0, 16)}  •  ${_formatBytes(file.lengthSync())}',
              style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'استعادة',
                  onPressed: _busy ? null : () => _restoreBackup(file),
                  icon: const Icon(
                    Icons.restore,
                    color: const Color(0xFF8AB4F8),
                  ),
                ),
                IconButton(
                  tooltip: 'حذف',
                  onPressed: _busy ? null : () => _deleteBackup(file),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: const Color(0xFFF28B82),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes بايت';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} ك.ب';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} م.ب';
  }

  static String pBasename(String path) =>
      path.split(Platform.pathSeparator).last;
}
