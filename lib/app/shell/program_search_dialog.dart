import 'package:flutter/material.dart';
import 'package:safwa/app/shell/app_window_tabs.dart';
import 'package:safwa/core/services/auth_session.dart';
import 'package:safwa/core/utils/constants.dart';

String normalizeProgramSearchText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي')
    .replaceAll('ى', 'ي')
    .trim();

bool matchesProgramSearchText(String candidate, String query) {
  final candidateForms = _programSearchForms(candidate);
  final queryForms = _programSearchForms(query);
  return queryForms.any(
    (term) => term.isEmpty || candidateForms.any((text) => text.contains(term)),
  );
}

Set<String> _programSearchForms(String value) {
  final normalized = normalizeProgramSearchText(value);
  final withoutDefiniteArticles = normalized
      .split(RegExp(r'\s+'))
      .map(
        (word) =>
            word.startsWith('ال') && word.length > 2 ? word.substring(2) : word,
      )
      .join(' ');
  return {normalized, withoutDefiniteArticles};
}

Future<void> openProgramSearch(BuildContext context) async {
  final route = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'إغلاق البحث',
    barrierColor: const Color(0x99000000),
    transitionDuration: const Duration(milliseconds: 190),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const _ProgramSearchDialog(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.025),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
  if (route == null || !context.mounted) return;

  openAppWindowTab(context, route);
}

enum _SearchGroup { program, reports }

class _SearchTarget {
  const _SearchTarget(
    this.label,
    this.route,
    this.group, [
    this.aliases = const [],
  ]);

  final String label;
  final String route;
  final _SearchGroup group;
  final List<String> aliases;
}

class _ProgramSearchDialog extends StatefulWidget {
  const _ProgramSearchDialog();

  @override
  State<_ProgramSearchDialog> createState() => _ProgramSearchDialogState();
}

class _ProgramSearchDialogState extends State<_ProgramSearchDialog> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _searchText = '';
  String? _activeLabel = 'إضافة صنف';

  static const List<_SearchTarget> _targets = [
    _SearchTarget('إضافة صنف', '/products?new=1', _SearchGroup.program, [
      'صنف جديد',
      'منتج',
    ]),
    _SearchTarget(
      'إضافة عميل',
      '/accounts?kind=customer&new=1',
      _SearchGroup.program,
      ['عميل جديد'],
    ),
    _SearchTarget(
      'إضافة مورد',
      '/accounts?kind=supplier&new=1',
      _SearchGroup.program,
      ['مورد جديد'],
    ),
    _SearchTarget(
      'استرجاع نسخة احتياطية',
      AppRoutes.backup,
      _SearchGroup.program,
      ['استعادة نسخة', 'استرجاع بيانات'],
    ),
    _SearchTarget(
      'مراجعة فواتير المبيعات',
      '/invoices?type=sale',
      _SearchGroup.program,
      ['أرشيف المبيعات'],
    ),
    _SearchTarget(
      'مراجعة فواتير المشتريات',
      '/invoices?type=purchase',
      _SearchGroup.program,
      ['أرشيف المشتريات'],
    ),
    _SearchTarget('فاتورة مشتريات', AppRoutes.purchases, _SearchGroup.program, [
      'شراء',
      'مشتريات',
    ]),
    _SearchTarget('فاتورة مبيعات', AppRoutes.sales, _SearchGroup.program, [
      'بيع',
      'مبيعات',
    ]),
    _SearchTarget('استلام نقدية', '/accounts/receipt', _SearchGroup.program, [
      'سند قبض',
      'قبض',
    ]),
    _SearchTarget('دفع نقدية', '/accounts/payment', _SearchGroup.program, [
      'سند صرف',
      'صرف',
    ]),
    _SearchTarget(
      'مراجعة سندات القبض',
      '/invoices?type=receipt',
      _SearchGroup.program,
      ['أرشيف القبض'],
    ),
    _SearchTarget(
      'مراجعة سندات الصرف',
      '/invoices?type=payment',
      _SearchGroup.program,
      ['أرشيف الصرف'],
    ),
    _SearchTarget(
      'المصروفات',
      '/treasury-movement?new=expense',
      _SearchGroup.program,
      ['مصروف'],
    ),
    _SearchTarget(
      'الإيرادات',
      '/treasury-movement?new=receive',
      _SearchGroup.program,
      ['إيراد', 'قبض خزينة'],
    ),
    _SearchTarget('الأصناف', AppRoutes.products, _SearchGroup.program, [
      'البضاعة',
      'المنتجات',
    ]),
    _SearchTarget('الرئيسية', AppRoutes.home, _SearchGroup.program, [
      'الصفحة الرئيسية',
    ]),
    _SearchTarget('العملاء', '/accounts?kind=customer', _SearchGroup.program, [
      'العميل',
      'حساب عميل',
    ]),
    _SearchTarget('الموردون', '/accounts?kind=supplier', _SearchGroup.program, [
      'الموردين',
      'مورد',
    ]),
    _SearchTarget('مرتجع مبيعات', AppRoutes.salesReturn, _SearchGroup.program, [
      'مرتجع بيع',
    ]),
    _SearchTarget(
      'مرتجع مشتريات',
      AppRoutes.purchaseReturn,
      _SearchGroup.program,
      ['مرتجع شراء'],
    ),
    _SearchTarget('المخازن', AppRoutes.warehouse, _SearchGroup.program, [
      'المخزن',
    ]),
    _SearchTarget('حركة الخزينة', AppRoutes.treasury, _SearchGroup.program, [
      'الخزينة',
    ]),
    _SearchTarget(
      'تحويل بين المخازن',
      AppRoutes.transfer,
      _SearchGroup.program,
      ['تحويل مخزن'],
    ),
    _SearchTarget('جرد مخزن', AppRoutes.stocktaking, _SearchGroup.program, [
      'الجرد',
    ]),
    _SearchTarget('تسوية مخزن', AppRoutes.adjustment, _SearchGroup.program, [
      'تسوية',
    ]),
    _SearchTarget('عرض أسعار', AppRoutes.quotation, _SearchGroup.program, [
      'عرض سعر',
      'تسعير',
    ]),
    _SearchTarget('الإعدادات', AppRoutes.settings, _SearchGroup.program, [
      'الضبط',
    ]),
    _SearchTarget('النسخ الاحتياطي', AppRoutes.backup, _SearchGroup.program, [
      'نسخة احتياطية',
    ]),
    _SearchTarget(
      'إجمالي التحصيلات',
      AppRoutes.dailyMovement,
      _SearchGroup.reports,
      ['التحصيلات', 'المقبوضات'],
    ),
    _SearchTarget(
      'إجمالي التحصيلات مرتبة بـ',
      AppRoutes.dailyMovement,
      _SearchGroup.reports,
      ['التحصيلات مرتبة'],
    ),
    _SearchTarget(
      'إجمالي التحصيلات مع',
      AppRoutes.dailyMovement,
      _SearchGroup.reports,
      ['التحصيلات مع'],
    ),
    _SearchTarget(
      'إجمالي المدفوعات',
      AppRoutes.dailyMovement,
      _SearchGroup.reports,
      ['المدفوعات', 'المنصرفات'],
    ),
    _SearchTarget(
      'إجمالي المدفوعات مرتبة بـ',
      AppRoutes.dailyMovement,
      _SearchGroup.reports,
      ['المدفوعات مرتبة'],
    ),
    _SearchTarget(
      'إجمالي المدفوعات مع',
      AppRoutes.dailyMovement,
      _SearchGroup.reports,
      ['المدفوعات مع'],
    ),
    _SearchTarget(
      'حركة التحصيلات',
      AppRoutes.dailyMovement,
      _SearchGroup.reports,
      ['حركة المقبوضات'],
    ),
    _SearchTarget(
      'حركة المدفوعات',
      AppRoutes.dailyMovement,
      _SearchGroup.reports,
      ['حركة المنصرفات'],
    ),
    _SearchTarget(
      'الحركة اليومية',
      AppRoutes.dailyMovement,
      _SearchGroup.reports,
      ['حركة اليوم'],
    ),
    _SearchTarget(
      'تحليل المبيعات',
      AppRoutes.salesAnalysis,
      _SearchGroup.reports,
      ['تحليل البيع'],
    ),
    _SearchTarget(
      'تحليل المشتريات',
      '/purchase-analysis',
      _SearchGroup.reports,
      ['تحليل الشراء'],
    ),
    _SearchTarget('الأرباح والخسائر', '/profit-loss', _SearchGroup.reports, [
      'الأرباح',
      'الخسائر',
    ]),
    _SearchTarget('التقارير', AppRoutes.reports, _SearchGroup.reports, [
      'تقرير',
    ]),
  ];

  List<_SearchTarget> _targetsFor(_SearchGroup group) {
    return _targets.where((target) {
      if (target.group != group ||
          !AuthSession.instance.canOpenLocation(Uri.parse(target.route).path)) {
        return false;
      }
      if (_searchText.trim().isEmpty) return true;
      return matchesProgramSearchText(target.label, _searchText) ||
          target.aliases.any(
            (alias) => matchesProgramSearchText(alias, _searchText),
          );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {
      _searchText = value;
      final all = [
        ..._targetsFor(_SearchGroup.program),
        ..._targetsFor(_SearchGroup.reports),
      ];
      if (!all.any((target) => target.label == _activeLabel)) {
        _activeLabel = all.isEmpty ? null : all.first.label;
      }
    });
  }

  void _activateFirst() {
    if (_searchText.trim().isEmpty) return;
    final results = [
      ..._targetsFor(_SearchGroup.program),
      ..._targetsFor(_SearchGroup.reports),
    ];
    if (results.isEmpty) return;
    final selected = results.where((target) => target.label == _activeLabel);
    _open(selected.isEmpty ? results.first : selected.first);
  }

  void _open(_SearchTarget target) => Navigator.of(context).pop(target.route);

  @override
  Widget build(BuildContext context) {
    final programTargets = _targetsFor(_SearchGroup.program);
    final reportTargets = _targetsFor(_SearchGroup.reports);
    final empty = programTargets.isEmpty && reportTargets.isEmpty;

    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.only(
            top: 154,
            left: 24,
            right: 24,
            bottom: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSearchBox(),
                SizedBox(
                  height: 500,
                  child: empty
                      ? Container(
                          width: double.infinity,
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: const Text(
                            'مفيش نتائج مطابقة',
                            style: TextStyle(fontSize: 13),
                          ),
                        )
                      : Row(
                          textDirection: TextDirection.ltr,
                          children: [
                            const Expanded(
                              flex: 7,
                              child: ColoredBox(color: Colors.white),
                            ),
                            const _SearchDivider(),
                            Expanded(
                              flex: 10,
                              child: _SearchResultColumn(
                                heading: 'التقارير',
                                icon: Icons.bar_chart_rounded,
                                items: reportTargets,
                                activeLabel: _activeLabel,
                                onHover: (target) =>
                                    setState(() => _activeLabel = target.label),
                                onTap: _open,
                              ),
                            ),
                            const _SearchDivider(),
                            Expanded(
                              flex: 9,
                              child: _SearchResultColumn(
                                heading: 'البرنامج',
                                icon: Icons.account_tree_rounded,
                                items: programTargets,
                                activeLabel: _activeLabel,
                                onHover: (target) =>
                                    setState(() => _activeLabel = target.label),
                                onTap: _open,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFC),
        border: Border.all(color: const Color(0xFF4A9DE4), width: 2),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          const SizedBox(width: 12),
          SizedBox(
            width: 36,
            height: 36,
            child: Material(
              color: const Color(0xFF3A9CDD),
              child: IconButton(
                tooltip: 'بحث',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                onPressed: _activateFirst,
                icon: const Icon(Icons.search, color: Colors.white, size: 26),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _query,
              focusNode: _focus,
              autofocus: true,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(color: Color(0xFF333333), fontSize: 15),
              cursorColor: const Color(0xFF168AE3),
              selectionControls: materialTextSelectionControls,
              decoration: const InputDecoration(
                hintText: 'البحث في البرنامج',
                filled: true,
                fillColor: Colors.white,
                hintStyle: TextStyle(color: Color(0xFF6D747B), fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 13,
                ),
              ),
              onChanged: _onQueryChanged,
              onSubmitted: (_) => _activateFirst(),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _SearchDivider extends StatelessWidget {
  const _SearchDivider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 10, child: ColoredBox(color: Color(0xFFEAEAEA)));
}

class _SearchResultColumn extends StatelessWidget {
  const _SearchResultColumn({
    required this.heading,
    required this.icon,
    required this.items,
    required this.activeLabel,
    required this.onHover,
    required this.onTap,
  });

  final String heading;
  final IconData icon;
  final List<_SearchTarget> items;
  final String? activeLabel;
  final ValueChanged<_SearchTarget> onHover;
  final ValueChanged<_SearchTarget> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 35,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  heading,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final target = items[index];
                final selected = target.label == activeLabel;
                return MouseRegion(
                  onEnter: (_) => onHover(target),
                  child: GestureDetector(
                    onTap: () => onTap(target),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      height: 56,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFFFFEFC)
                            : Colors.white,
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFF9700)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Icon(icon, size: 24, color: const Color(0xFF168AE3)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              target.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF111111),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
