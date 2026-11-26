import 'package:flutter/material.dart';

import 'package:safwa/core/services/document_custom_fields.dart';

Future<Map<int, String>?> showDocumentCustomFieldsDialog(
  BuildContext context, {
  required Map<int, String> initialValues,
  String scope = 'document',
}) async {
  final definitions = DocumentCustomFields.definitions(scope: scope);
  if (definitions.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الحقول الإضافية'),
        content: const Text(
          'أضف حقولاً من تبويب «حقول إضافية» في إعداد Safwa أولاً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
    return null;
  }
  return showDialog<Map<int, String>>(
    context: context,
    builder: (context) => _DocumentCustomFieldsDialog(
      definitions: definitions,
      initialValues: initialValues,
    ),
  );
}

class _DocumentCustomFieldsDialog extends StatefulWidget {
  const _DocumentCustomFieldsDialog({
    required this.definitions,
    required this.initialValues,
  });

  final List<Map<String, Object?>> definitions;
  final Map<int, String> initialValues;

  @override
  State<_DocumentCustomFieldsDialog> createState() =>
      _DocumentCustomFieldsDialogState();
}

class _DocumentCustomFieldsDialogState
    extends State<_DocumentCustomFieldsDialog> {
  late final Map<int, TextEditingController> _controllers = {
    for (final field in widget.definitions)
      field['id'] as int: TextEditingController(
        text: widget.initialValues[field['id'] as int] ?? '',
      ),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('الحقول الإضافية للمستند'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in widget.definitions) ...[
              TextField(
                controller: _controllers[field['id'] as int],
                decoration: InputDecoration(labelText: field['name'] as String),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _controllers.map((id, controller) => MapEntry(id, controller.text)),
        ),
        child: const Text('حفظ'),
      ),
    ],
  );
}
