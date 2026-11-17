import 'package:flutter/material.dart';
import 'package:inventory_app/core/database/sqlite_database.dart';
import 'package:inventory_app/core/security/password_hasher.dart';

/// When the optional row deletion password is configured, require it before
/// removing an item from an invoice. Empty configuration preserves the
/// existing delete behavior.
Future<bool> verifyInvoiceLineDeletePassword(BuildContext context) async {
  final db = SqliteDatabase();
  final saltRows = db.query('SELECT value FROM settings WHERE key=?', [
    'settings.line_delete_salt',
  ]);
  final hashRows = db.query('SELECT value FROM settings WHERE key=?', [
    'settings.line_delete_hash',
  ]);
  if (saltRows.isEmpty ||
      hashRows.isEmpty ||
      '${hashRows.first['value']}'.isEmpty) {
    return true;
  }
  final controller = TextEditingController();
  try {
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد حذف الصنف'),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            textAlign: TextAlign.right,
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
            decoration: const InputDecoration(
              labelText: 'كلمة مرور المستخدم المسؤول',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تراجع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('موافق'),
            ),
          ],
        ),
      ),
    );
    if (password == null) return false;
    final valid = await PasswordHasher.verify(
      password: password,
      salt: '${saltRows.first['value']}',
      expectedHash: '${hashRows.first['value']}',
    );
    if (!valid && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور غير صحيحة. لم يتم حذف الصنف.'),
        ),
      );
    }
    return valid;
  } finally {
    controller.dispose();
  }
}
