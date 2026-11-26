import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:safwa/app/shell/app_top_bar.dart';
import 'package:safwa/app/widgets/hover_widgets.dart';
import 'package:safwa/core/utils/constants.dart';
import 'package:safwa/features/accounts/data/accounts_repo.dart';
import 'package:safwa/features/accounts/domain/account_record.dart';
import 'package:safwa/features/accounts/presentation/account_form_dialog.dart';
import 'package:safwa/features/accounts/presentation/accounts_ui.dart';
import 'package:safwa/features/accounts/presentation/print_preview_dialog.dart';

/// الحسابات — replica of the reference accounts screen: green title, filter
/// row with the three checkboxes, command sidebar on the left and the grouped
/// accounts grid with its green footer.
class AccountsListPage extends StatefulWidget {
  const AccountsListPage({
    super.key,
    this.initialKind,
    this.openNewOnStart = false,
  });

  final String? initialKind;
  final bool openNewOnStart;

  @override
  State<AccountsListPage> createState() => _AccountsListPageState();
}

class _AccountsListPageState extends State<AccountsListPage> {
  final AccountsRepo _repo = AccountsRepo();
  final TextEditingController _search = TextEditingController();

  List<AccountRecord> _rows = const [];
  List<Map<String, dynamic>> _categories = const [];

  String _searchText = '';
  String _kindFilter = 'جميع الحسابات';
  String _categoryFilter = 'الكل';
  bool _underReviewOnly = false;
  bool _hideZero = false;
  bool _inactiveOnly = false;
  bool _refreshing = false;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    if (widget.initialKind == 'supplier') _kindFilter = 'مورد';
    if (widget.initialKind == 'customer') _kindFilter = 'عميل';
    _reload();
    if (widget.openNewOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openForm();
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload({bool feedback = false}) async {
    if (_refreshing) return;
    if (feedback) setState(() => _refreshing = true);
    final rows = _repo.fetchAccounts();
    final categories = _repo.categories();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _categories = categories;
      _refreshing = false;
      if (_selectedId != null && !rows.any((r) => r.id == _selectedId)) {
        _selectedId = null;
      }
    });
    if (feedback) {
      _toast(
        'تم تحديث قائمة الحسابات — ${rows.where((r) => r.isActive).length} حساب.',
      );
    }
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

  List<AccountRecord> get _filtered {
    Iterable<AccountRecord> result = _rows;
    if (!_inactiveOnly) {
      result = result.where((r) => r.isActive);
    } else {
      result = result.where((r) => !r.isActive);
    }
    if (_hideZero) {
      result = result.where((r) => r.balance != 0 || r.checksDebit != 0);
    }
    if (_underReviewOnly) {
      result = result.where((r) => r.underReview);
    }
    if (_kindFilter != 'جميع الحسابات') {
      result = result.where((r) => r.kindLabel == _kindFilter);
    }
    if (_categoryFilter != 'الكل' && _categoryFilter.isNotEmpty) {
      result = result.where((r) => r.categoryName == _categoryFilter);
    }
    final query = _searchText.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((r) {
        return r.name.toLowerCase().contains(query) ||
            r.code.toLowerCase().contains(query) ||
            r.phone.toLowerCase().contains(query);
      });
    }
    return result.toList();
  }

  AccountRecord? get _selected {
    for (final row in _filtered) {
      if (row.id == _selectedId) return row;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Actions.
  // ---------------------------------------------------------------------------
  Future<void> _openForm({AccountRecord? account}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountFormDialog(
        account: account,
        initialKind: widget.initialKind ?? 'customer',
      ),
    );
    if (saved == true) await _reload();
  }

  Future<void> _openEdit() async {
    final account = _selected;
    if (account == null) {
      _toast('اختر حساباً من الجدول أولاً.');
      return;
    }
    await _openForm(account: account);
  }

  Future<void> _deleteSelected() async {
    final account = _selected;
    if (account == null) {
      _toast('اختر حساباً من الجدول أولاً.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (dialogContext) => _DeleteAccountDialog(name: account.name),
    );
    if (confirmed == true) {
      _repo.softDeleteAccount(account.id!);
      setState(() => _selectedId = null);
      await _reload();
      if (mounted) _toast('تم حذف الحساب "${account.name}".');
    }
  }

  void _openStatement({required bool items}) {
    final account = _selected;
    if (account == null) {
      _toast('اختر حساباً من الجدول أولاً.');
      return;
    }
    context.go('/accounts/${items ? 'items' : 'statement'}?id=${account.id}');
  }

  void _openChecks() {
    final account = _selected;
    final id = account?.id ?? 0;
    context.go('/accounts/checks?id=$id');
  }

  void _printList() {
    final rows = _filtered;
    showDialog<void>(
      context: context,
      builder: (_) => PrintPreviewDialog(
        title: 'قائمة الحسابات',
        columns: const [
          'رقم الحساب',
          'اسم الحساب',
          'طبيعة الحساب',
          'التصنيف',
          'كود الحساب',
        ],
        rows: rows
            .map(
              (r) => [
                '${r.id ?? ''}',
                r.name,
                r.kindLabel,
                r.categoryName,
                r.code,
              ],
            )
            .toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI.
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return withPlainInputs(
      AppShell(
        activeTab: AppTab.accounts,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  textDirection: TextDirection.ltr,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 286,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _buildSidebar(),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildTable(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 150,
      color: Colors.white,
      child: Stack(
        children: [
          const Positioned(right: 16, top: 10, child: AcctTitle('الحسابات')),
          Positioned(
            left: 8,
            top: 8,
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                HoverAssetButton(
                  asset: 'assets/icons/products/top_cancel.png',
                  width: 126,
                  height: 30,
                  onTap: () => context.go(AppRoutes.home),
                ),
                const SizedBox(width: 7),
                HoverAssetButton(
                  asset: 'assets/icons/products/top_refresh.png',
                  width: 126,
                  height: 30,
                  onTap: () => _reload(feedback: true),
                ),
              ],
            ),
          ),
          Positioned(
            right: 15,
            top: 48,
            child: AcctField(
              label: 'بحث عن',
              controller: _search,
              width: 196,
              height: 26,
              onChanged: (v) => setState(() => _searchText = v),
            ),
          ),
          Positioned(
            right: 226,
            top: 48,
            child: AcctDropdown(
              label: 'طبيعة الحساب',
              value: _kindFilter,
              width: 112,
              height: 26,
              items: const [
                'جميع الحسابات',
                'عميل',
                'مورد',
                'مندوب بيع',
                'أخرى',
              ],
              onChanged: (v) =>
                  setState(() => _kindFilter = v ?? 'جميع الحسابات'),
            ),
          ),
          Positioned(
            right: 350,
            top: 48,
            child: AcctDropdown(
              label: 'التصنيف',
              value: _categoryFilter,
              width: 112,
              height: 26,
              hint: '',
              items: ['الكل', ..._categories.map((c) => c['name'] as String)],
              onChanged: (v) => setState(() => _categoryFilter = v ?? 'الكل'),
            ),
          ),
          Positioned(
            right: 470,
            top: 70,
            child: AcctClearX(
              onTap: () {
                _search.clear();
                setState(() {
                  _searchText = '';
                  _kindFilter = 'جميع الحسابات';
                  _categoryFilter = 'الكل';
                  _underReviewOnly = false;
                  _hideZero = false;
                  _inactiveOnly = false;
                  _selectedId = null;
                });
              },
            ),
          ),
          Positioned(
            right: 15,
            top: 112,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                AcctCheckRow(
                  label: 'إظهار الحسابات تحت المراجعة فقط',
                  value: _underReviewOnly,
                  onChanged: (v) => setState(() => _underReviewOnly = v),
                ),
                const SizedBox(width: 26),
                AcctCheckRow(
                  label: 'إخفاء الأرصدة الصفرية',
                  value: _hideZero,
                  onChanged: (v) => setState(() => _hideZero = v),
                ),
                const SizedBox(width: 26),
                AcctCheckRow(
                  label: 'إظهار الحسابات الغير نشطة فقط',
                  value: _inactiveOnly,
                  onChanged: (v) => setState(() => _inactiveOnly = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sidebar.
  // ---------------------------------------------------------------------------
  Widget _buildSidebar() {
    final selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          textDirection: TextDirection.rtl,
          children: [
            HoverAssetButton(
              asset: 'assets/icons/products/crud_new.png',
              width: 86,
              height: 80,
              onTap: () => _openForm(),
            ),
            const SizedBox(width: 6),
            HoverAssetButton(
              asset: 'assets/icons/products/crud_edit.png',
              width: 86,
              height: 80,
              onTap: _openEdit,
            ),
            const SizedBox(width: 6),
            HoverAssetButton(
              asset: 'assets/icons/products/crud_delete.png',
              width: 86,
              height: 80,
              onTap: _deleteSelected,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          textDirection: TextDirection.rtl,
          children: [
            AcctMoneyTile(
              label: 'صرف',
              onTap: () =>
                  context.push('/accounts/payment?id=${selected?.id ?? 0}'),
            ),
            const SizedBox(width: 6),
            AcctMoneyTile(
              label: 'قبض',
              onTap: () =>
                  context.push('/accounts/receipt?id=${selected?.id ?? 0}'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          textDirection: TextDirection.rtl,
          children: [
            AcctTile(
              label: 'طباعة قائمة الحسابات',
              width: 216,
              height: 38,
              onTap: _printList,
              icon: const Icon(Icons.print, size: 18, color: Color(0xFF333333)),
            ),
            const SizedBox(width: 5),
            HoverAssetButton(
              asset: 'assets/icons/products/share.png',
              width: 49,
              height: 38,
              onTap: () {
                _toast('مشاركة قائمة الحسابات — استخدم الطباعة أو حفظ صورة.');
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        AcctTile(
          label: 'كشف حساب',
          width: 270,
          height: 34,
          onTap: () => _openStatement(items: false),
          icon: const Icon(
            Icons.description,
            size: 16,
            color: Color(0xFFE2A200),
          ),
        ),
        const SizedBox(height: 8),
        AcctTile(
          label: 'كشف حساب بالأصناف',
          width: 270,
          height: 34,
          onTap: () => _openStatement(items: true),
          icon: const Icon(
            Icons.description,
            size: 16,
            color: Color(0xFFE2A200),
          ),
        ),
        const SizedBox(height: 8),
        AcctTile(
          label: 'الشيكات والأقساط',
          width: 270,
          height: 34,
          onTap: _openChecks,
          icon: const Icon(
            Icons.description,
            size: 16,
            color: Color(0xFF43B5DB),
          ),
        ),
        const SizedBox(height: 8),
        AcctTile(
          label: 'أرصدة الحسابات بتاريخ سابق',
          width: 270,
          height: 34,
          enabled: false,
          icon: const Icon(
            Icons.description,
            size: 16,
            color: Color(0xFFC9C9C9),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Table.
  // ---------------------------------------------------------------------------
  static const _wControl = 30.0;
  static const _wId = 70.0;
  static const _wName = 210.0;
  static const _wMoney = 96.0;
  static const _wKind = 92.0;
  static const _wCategory = 92.0;
  static const _wCode = 100.0;

  List<AccountRecord> get _visible => _filtered;

  Widget _buildTable() {
    final rows = _visible;
    return Column(
      children: [
        _buildTableHeader(),
        if (_visible.isEmpty) Container(height: 22, color: kAcctTableGreen),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFD0D0D0)),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: const [
                        BoxShadow(color: Color(0x22000000), blurRadius: 4),
                      ],
                    ),
                    child: const Text(
                      'لا يوجد بيانات',
                      style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  itemBuilder: (context, index) =>
                      _buildRow(rows[index], index),
                ),
        ),
        _buildFooter(rows),
        const SizedBox(height: 2),
        _buildPager(rows.length),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 40,
      color: const Color(0xFFEDEDED),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _hCell('', _wControl, full: true),
          _vSep(),
          _hCell('رقم الحساب', _wId, full: true),
          _vSep(),
          _hCell('اسم الحساب', _wName, full: true),
          _vSep(),
          _groupColumn('الرصيد الحالي'),
          _vSep(),
          _groupColumn('شبكات وأقساط'),
          _vSep(),
          _hCell('طبيعة الحساب', _wKind, full: true),
          _vSep(),
          _hCell('التصنيف', _wCategory, full: true),
          _vSep(),
          _hCell('كود الحساب', _wCode, full: true),
        ],
      ),
    );
  }

  Widget _groupColumn(String title) {
    return SizedBox(
      width: _wMoney * 2,
      child: Column(
        children: [
          Container(
            height: 18,
            alignment: Alignment.center,
            child: Text(
              title,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)),
            ),
          ),
          Container(height: 1, color: const Color(0xFFC0C0C0)),
          Expanded(
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                _hCell('عليه - مدين', _wMoney, full: true, fontSize: 11.5),
                _vSep(),
                _hCell('له  - دائن', _wMoney, full: true, fontSize: 11.5),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hCell(
    String text,
    double width, {
    bool full = false,
    double fontSize = 12,
  }) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: full ? Alignment.center : Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _vSep() => Container(width: 1, color: const Color(0xFFC0C0C0));

  Widget _buildRow(AccountRecord row, int index) {
    final selected = row.id == _selectedId;
    final zebra = index.isEven ? Colors.white : const Color(0xFFF2F2F2);
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedId = row.id),
        onDoubleTap: () => _openForm(account: row),
        child: Container(
          height: 26,
          color: selected
              ? const Color(0xFF43B5DB)
              : (hovered ? const Color(0xFF8DCDE2) : zebra),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              SizedBox(
                width: _wControl,
                child: Center(
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF7A7A7A)),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check,
                            size: 11,
                            color: Color(0xFF1A1A1A),
                          )
                        : null,
                  ),
                ),
              ),
              _dSep(),
              _dCell('${row.id ?? ''}', _wId),
              _dSep(),
              _dCell(row.name, _wName),
              _dSep(),
              _dCell(row.debit == 0 ? '' : '${row.debit}', _wMoney),
              _dSep(),
              _dCell(row.credit == 0 ? '' : '${row.credit}', _wMoney),
              _dSep(),
              _dCell(row.checksDebit == 0 ? '' : '${row.checksDebit}', _wMoney),
              _dSep(),
              _dCell(
                row.checksCredit == 0 ? '' : '${row.checksCredit}',
                _wMoney,
              ),
              _dSep(),
              _dCell(row.kindLabel, _wKind),
              _dSep(),
              _dCell(row.categoryName, _wCategory),
              _dSep(),
              _dCell(row.code, _wCode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dSep() => Container(width: 1, color: const Color(0xFFD6D6D6));

  Widget _dCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF1A1A1A)),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(List<AccountRecord> rows) {
    final debit = rows.fold<int>(0, (sum, r) => sum + r.debit);
    final credit = rows.fold<int>(0, (sum, r) => sum + r.credit);
    final checksDebit = rows.fold<int>(0, (sum, r) => sum + r.checksDebit);
    final checksCredit = rows.fold<int>(0, (sum, r) => sum + r.checksCredit);
    Widget cell(String text, double width, {bool green = false}) {
      return SizedBox(
        width: width,
        child: Container(
          color: green ? kAcctTableGreen : const Color(0xFFEDEDED),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.centerRight,
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF1A1A1A)),
          ),
        ),
      );
    }

    return Container(
      height: 26,
      color: const Color(0xFFEDEDED),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          cell('', _wControl),
          _vSep(),
          cell('', _wId),
          _vSep(),
          cell('', _wName),
          _vSep(),
          cell(debit == 0 ? '0' : '$debit', _wMoney, green: true),
          _vSep(),
          cell(credit == 0 ? '0' : '$credit', _wMoney, green: credit != 0),
          _vSep(),
          cell(
            checksDebit == 0 ? '0' : '$checksDebit',
            _wMoney,
            green: checksDebit != 0,
          ),
          _vSep(),
          cell(
            checksCredit == 0 ? '0' : '$checksCredit',
            _wMoney,
            green: checksCredit != 0,
          ),
          _vSep(),
          cell('', _wKind),
          _vSep(),
          cell('', _wCategory),
          _vSep(),
          cell('', _wCode),
        ],
      ),
    );
  }

  Widget _buildPager(int count) {
    return Container(
      height: 22,
      color: const Color(0xFFEDEDED),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          const SizedBox(width: 8),
          Text(
            count == 0 ? '0' : '1',
            style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)),
          ),
          const Spacer(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Red "هل أنت متأكد؟" dialog.
// -----------------------------------------------------------------------------
class _DeleteAccountDialog extends StatelessWidget {
  const _DeleteAccountDialog({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 750,
          height: 210,
          decoration: BoxDecoration(
            color: const Color(0xFFF48579),
            border: Border.all(color: const Color(0xFFD96053), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.centerRight,
                child: const Text(
                  'Safwa Business Management',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 30,
                      color: Color(0xFF1A1A1A),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'هل أنت متأكد؟',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    _dialogButton(
                      context,
                      label: 'لا',
                      icon: Icons.close,
                      yellow: false,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 64),
                    _dialogButton(
                      context,
                      label: 'نعم',
                      icon: Icons.check,
                      yellow: true,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool yellow,
    required VoidCallback onTap,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 172,
          height: 46,
          color: yellow
              ? (hovered ? const Color(0xFFFFD65C) : const Color(0xFFF5C73D))
              : (hovered ? kHoverYellow : const Color(0xFFEDEDED)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 20, color: const Color(0xFF1A1A1A)),
            ],
          ),
        ),
      ),
    );
  }
}
