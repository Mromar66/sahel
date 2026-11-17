import 'package:flutter/material.dart';
import 'package:inventory_app/core/security/permission_catalog.dart';
import 'package:inventory_app/features/settings/data/settings_repository.dart';

class SettingsFieldSpec {
  const SettingsFieldSpec(
    this.key,
    this.label, {
    this.numeric = false,
    this.obscure = false,
  });
  final String key;
  final String label;
  final bool numeric;
  final bool obscure;
}

Future<Map<String, String>?> showSettingsEntryDialog(
  BuildContext context, {
  required String title,
  required List<SettingsFieldSpec> fields,
  Map<String, String> initial = const {},
  String? hint,
}) async {
  final controllers = {
    for (final field in fields)
      field.key: TextEditingController(text: initial[field.key] ?? ''),
  };
  try {
    return await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hint != null) ...[
                    Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final field in fields) ...[
                    TextField(
                      controller: controllers[field.key],
                      obscureText: field.obscure,
                      keyboardType: field.numeric
                          ? TextInputType.number
                          : TextInputType.text,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: field.label,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                for (final entry in controllers.entries)
                  entry.key: entry.value.text,
              }),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  } finally {
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }
}

class SettingsUserDraft {
  const SettingsUserDraft({
    required this.username,
    required this.displayName,
    required this.password,
    required this.isAdmin,
    required this.isActive,
    required this.permissions,
  });

  final String username;
  final String displayName;
  final String password;
  final bool isAdmin;
  final bool isActive;
  final Set<String> permissions;
}

Future<SettingsUserDraft?> showSettingsUserDialog(
  BuildContext context, {
  SettingsUser? user,
}) async {
  final username = TextEditingController(text: user?.username ?? '');
  final displayName = TextEditingController(text: user?.displayName ?? '');
  final password = TextEditingController();
  var isAdmin = user?.isAdmin ?? false;
  var isActive = user?.isActive ?? true;
  final permissions = <String>{...?user?.permissions};
  try {
    return await showDialog<SettingsUserDraft>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(user == null ? 'مستخدم جديد' : 'تعديل المستخدم'),
            content: SizedBox(
              width: 610,
              height: 620,
              child: Column(
                children: [
                  TextField(
                    controller: displayName,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم الظاهر',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: username,
                    textAlign: TextAlign.left,
                    decoration: const InputDecoration(labelText: 'اسم الدخول'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: password,
                    obscureText: true,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      labelText: user == null
                          ? 'كلمة المرور (8 أحرف على الأقل)'
                          : 'كلمة مرور جديدة (اتركها فارغة للإبقاء على الحالية)',
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('مدير النظام — جميع الصلاحيات'),
                    value: isAdmin,
                    onChanged: (value) =>
                        setDialogState(() => isAdmin = value ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('مستخدم نشط'),
                    value: isActive,
                    onChanged: (value) =>
                        setDialogState(() => isActive = value ?? false),
                  ),
                  const Divider(height: 12),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'صلاحيات الصفحات',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: AbsorbPointer(
                      absorbing: isAdmin,
                      child: Opacity(
                        opacity: isAdmin ? .45 : 1,
                        child: ListView(
                          children: [
                            for (final group in appPermissionGroups)
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(
                                  group.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                initiallyExpanded: true,
                                children: [
                                  for (final permission in group.permissions)
                                    CheckboxListTile(
                                      contentPadding: const EdgeInsets.only(
                                        right: 8,
                                      ),
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      title: Text(
                                        permission.label,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      value: permissions.contains(
                                        permission.code,
                                      ),
                                      onChanged: (value) => setDialogState(() {
                                        if (value ?? false) {
                                          permissions.add(permission.code);
                                        } else {
                                          permissions.remove(permission.code);
                                        }
                                      }),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
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
                onPressed: () => Navigator.pop(
                  dialogContext,
                  SettingsUserDraft(
                    username: username.text,
                    displayName: displayName.text,
                    password: password.text,
                    isAdmin: isAdmin,
                    isActive: isActive,
                    permissions: permissions,
                  ),
                ),
                child: const Text('حفظ المستخدم'),
              ),
            ],
          ),
        ),
      ),
    );
  } finally {
    username.dispose();
    displayName.dispose();
    password.dispose();
  }
}

Future<bool?> showSettingsConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) => showDialog<bool>(
  context: context,
  builder: (dialogContext) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('تراجع'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('موافق'),
        ),
      ],
    ),
  ),
);
