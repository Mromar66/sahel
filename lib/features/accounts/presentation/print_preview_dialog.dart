import 'package:flutter/material.dart';

import 'package:safwa/app/widgets/hover_widgets.dart';
import 'package:safwa/core/services/database_service.dart';
import 'package:safwa/features/accounts/presentation/accounts_ui.dart';

/// "معاينة - بيانات الجدول" window shown from the accounts list print action.
/// Replica of the reference preview window: pale-green title bar, toolbar,
/// white report page with its grid and the page counter at the bottom.
class PrintPreviewDialog extends StatefulWidget {
  const PrintPreviewDialog({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
    this.subtitle,
    this.onPrint,
  });

  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  final String? subtitle;

  /// Optional real print handler. When supplied, the toolbar «طباعة» button
  /// sends the report to the system printer instead of showing a mock toast.
  final Future<void> Function()? onPrint;

  @override
  State<PrintPreviewDialog> createState() => _PrintPreviewDialogState();
}

class _PrintPreviewDialogState extends State<PrintPreviewDialog> {
  final int _page = 1;
  String _projectName = '';
  String _contact = '';
  String _phone = '';
  String _address = '';

  @override
  void initState() {
    super.initState();
    final db = DatabaseService().database.db;
    String setting(String key) {
      final rows = db.select('SELECT value FROM settings WHERE key=?', [key]);
      return rows.isEmpty ? '' : rows.first['value'] as String;
    }

    _projectName = setting('settings.project_name');
    _contact = setting('settings.contact');
    _phone = setting('settings.phone');
    _address = setting('settings.address');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Container(
          width: 940,
          height: 690,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF9A9A9A)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTitleBar(),
              _buildToolbar(),
              Expanded(
                child: Container(
                  color: const Color(0xFFF4F4F4),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(child: _buildReport()),
                  ),
                ),
              ),
              _buildStatusBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      height: 26,
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9FA),
        border: Border(bottom: BorderSide(color: Color(0xFFD9E8EC))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          const Icon(
            Icons.insert_drive_file,
            size: 15,
            color: Color(0xFF43B5DB),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'معاينة - ${widget.title}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF1A1A1A)),
            ),
          ),
          HoverBuilderIcon(
            icon: Icons.close,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 34,
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD))),
      ),
      child: Row(
        children: [
          AcctToolbarButton(
            label: 'إغلاق',
            onTap: () => Navigator.of(context).pop(),
          ),
          AcctToolbarButton(label: 'توقف', enabled: false, onTap: () {}),
          AcctToolbarButton(label: 'التالي', enabled: false, onTap: () {}),
          AcctToolbarButton(label: 'السابق', enabled: false, onTap: () {}),
          AcctToolbarButton(
            label: 'تغيير الحجم  ▾',
            onTap: () => _toast('حجم المعاينة: A4 عرضي.'),
          ),
          AcctToolbarButton(
            label: 'إعدادات الطابعة',
            onTap: () => _toast('إعدادات الطابعة غير متاحة بدون طابعة متصلة.'),
          ),
          AcctToolbarButton(
            label: 'طباعة',
            onTap: () {
              final handler = widget.onPrint;
              if (handler != null) {
                handler();
              } else {
                _toast('تم إرسال التقرير إلى الطابعة.');
              }
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final columns = widget.columns;
    final rows = widget.rows;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_projectName.isNotEmpty) ...[
            Text(
              _projectName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if ([_contact, _phone, _address].any((value) => value.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 3, bottom: 8),
                child: Text(
                  [
                    _contact,
                    _phone,
                    _address,
                  ].where((value) => value.isNotEmpty).join(' | '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
          ],
          if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.subtitle!,
                style: const TextStyle(fontSize: 11, color: Color(0xFF444444)),
              ),
            ),
          ],
          Table(
            border: TableBorder.all(color: const Color(0xFF4A4A4A), width: 0.7),
            columnWidths: {
              for (var i = 0; i < columns.length; i++)
                i: const FlexColumnWidth(),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF2F2F2)),
                children: [
                  for (final column in columns)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 5,
                      ),
                      child: Text(
                        column,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                ],
              ),
              for (final row in rows)
                TableRow(
                  children: [
                    for (var i = 0; i < columns.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          i < row.length ? row[i] : '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        border: Border(top: BorderSide(color: Color(0xFFDDDDDD))),
      ),
      child: Row(
        children: [
          Text(
            'صفحة $_page من 1',
            style: const TextStyle(fontSize: 11, color: Color(0xFF444444)),
          ),
        ],
      ),
    );
  }
}

/// Tiny square toolbar / titlebar button used by the preview chrome.
class HoverBuilderIcon extends StatelessWidget {
  const HoverBuilderIcon({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 26,
          height: 22,
          color: hovered ? kHoverYellow : Colors.transparent,
          child: Icon(icon, size: 14, color: const Color(0xFF444444)),
        ),
      ),
    );
  }
}
