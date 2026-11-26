import 'package:flutter/material.dart';
import 'package:safwa/core/security/permission_catalog.dart';
import 'package:safwa/features/settings/data/settings_repository.dart';

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
    required this.roleIds,
  });

  final String username;
  final String displayName;
  final String password;
  final bool isAdmin;
  final bool isActive;
  final Set<String> permissions;
  final Set<int> roleIds;
}

class SettingsRoleDraft {
  const SettingsRoleDraft({
    required this.name,
    required this.description,
    required this.permissions,
  });

  final String name;
  final String description;
  final Set<String> permissions;
}

Future<SettingsRoleDraft?> showSettingsRoleDialog(
  BuildContext context, {
  SettingsRole? role,
}) async {
  final name = TextEditingController(text: role?.name ?? '');
  final description = TextEditingController(text: role?.description ?? '');
  final permissions = <String>{...?role?.permissions};
  try {
    return await showDialog<SettingsRoleDraft>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              role == null ? 'مجموعة صلاحيات جديدة' : 'تعديل مجموعة الصلاحيات',
            ),
            content: SizedBox(
              width: 560,
              height: 580,
              child: Column(
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'اسم المجموعة',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(
                      labelText: 'وصف المجموعة',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('الشاشات المسموح بفتحها'),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final group in appPermissionGroups)
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            initiallyExpanded: true,
                            title: Text(group.title),
                            children: [
                              for (final permission in group.permissions)
                                CheckboxListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  title: Text(permission.label),
                                  value: permissions.contains(permission.code),
                                  onChanged: (value) => setDialogState(() {
                                    if (value == true) {
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
                  SettingsRoleDraft(
                    name: name.text,
                    description: description.text,
                    permissions: permissions,
                  ),
                ),
                child: const Text('حفظ المجموعة'),
              ),
            ],
          ),
        ),
      ),
    );
  } finally {
    name.dispose();
    description.dispose();
  }
}

Future<SettingsUserDraft?> showSettingsUserDialog(
  BuildContext context, {
  SettingsUser? user,
}) async {
  final username = TextEditingController(text: user?.username ?? '');
  final displayName = TextEditingController(text: user?.displayName ?? '');
  final password = TextEditingController();
  final roles = SettingsRepository.instance.roles();
  var isAdmin = user?.isAdmin ?? false;
  var isActive = user?.isActive ?? true;
  final permissions = <String>{...?user?.permissions};
  final roleIds = <int>{...?user?.roleIds};
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
                  if (roles.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'مجموعات الصلاحيات',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    AbsorbPointer(
                      absorbing: isAdmin,
                      child: Opacity(
                        opacity: isAdmin ? .45 : 1,
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 0,
                          children: [
                            for (final role in roles)
                              FilterChip(
                                label: Text(role.name),
                                selected: roleIds.contains(role.id),
                                onSelected: (selected) => setDialogState(() {
                                  if (selected) {
                                    roleIds.add(role.id);
                                  } else {
                                    roleIds.remove(role.id);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                    roleIds: roleIds,
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
