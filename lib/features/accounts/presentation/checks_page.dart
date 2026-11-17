import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:inventory_app/app/shell/app_top_bar.dart';
import 'package:inventory_app/app/widgets/hover_widgets.dart';
import 'package:inventory_app/features/accounts/data/accounts_repo.dart';
import 'package:inventory_app/features/accounts/domain/account_record.dart';
import 'package:inventory_app/features/accounts/presentation/accounts_ui.dart';
import 'package:inventory_app/features/accounts/presentation/print_preview_dialog.dart';

/// متابعة سداد الشيكات والأقساط — replica of the reference report screen:
/// the two-column filter block, command sidebar and the green checks grid.
class ChecksPage extends StatefulWidget {
  const ChecksPage({super.key, this.accountId = 0});

  final int accountId;

  @override
  State<ChecksPage> createState() => _ChecksPageState();
}

class _ChecksPageState extends State<ChecksPage> {
  final AccountsRepo _repo = AccountsRepo();
  final TextEditingController _accountId = TextEditingController();
  final TextEditingController _accountName = TextEditingController();
  final TextEditingController _bank = TextEditingController();
  final TextEditingController _checkNumber = TextEditingController();
  final TextEditingController _fromDate = TextEditingController();
  final TextEditingController _toDate = TextEditingController();

  List<AccountCheckRow> _allChecks = const [];
  List<AccountCheckRow> _rows = const [];
  List<AccountRecord> _accounts = const [];

  String _reportType = 'الكل';
  String _paymentState = 'غير مسدد';
  int? _selectedId;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fromDate.text = _fmtDate(_from);
    _toDate.text = _fmtDate(_to);
    _accountId.text = widget.accountId == 0 ? '' : '${widget.accountId}';
    _load();
  }

  @override
  void dispose() {
    _accountId.dispose();
    _accountName.dispose();
    _bank.dispose();
    _checkNumber.dispose();
    _fromDate.dispose();
    _toDate.dispose();
    super.dispose();
  }

  void _load() {
    _allChecks = _repo.checks();
    _accounts = _repo.fetchAccounts().where((a) => a.isActive).toList();
    final id = int.tryParse(_accountId.text.trim());
    if (id != null) {
      for (final account in _accounts) {
        if (account.id == id) _accountName.text = account.name;
      }
    }
    _applyFilter();
  }

  void _applyFilter() {
    Iterable<AccountCheckRow> rows = _allChecks;
    if (_paymentState == 'مسدد') {
      rows = rows.where((r) => r.collected);
    } else if (_paymentState == 'غير مسدد') {
      rows = rows.where((r) => !r.collected);
    }
    if (_reportType == 'شيكات') {
      rows = rows.where((r) => r.checkNumber.isNotEmpty);
    } else if (_reportType == 'أقساط') {
      rows = rows.where((r) => r.checkNumber.isEmpty);
    }
    final id = int.tryParse(_accountId.text.trim());
    if (id != null && id > 0) {
      AccountRecord? account;
      for (final candidate in _accounts) {
        if (candidate.id == id) {
          account = candidate;
          break;
        }
      }
      if (account != null) {
        rows = rows.where((r) => r.accountName == account!.name);
      }
    }
    if (_bank.text.trim().isNotEmpty) {
      final q = _bank.text.trim();
      rows = rows.where((r) => r.bank.contains(q));
    }
    if (_checkNumber.text.trim().isNotEmpty) {
      final q = _checkNumber.text.trim();
      rows = rows.where((r) => r.checkNumber.contains(q));
    }
    rows = rows.where(
      (r) =>
          !r.dueDate.isBefore(DateTime(_from.year, _from.month, _from.day)) &&
          !r.dueDate.isAfter(DateTime(_to.year, _to.month, _to.day, 23, 59)),
    );
    setState(() => _rows = rows.toList());
  }

  void _viewReport() {
    _load();
    _toast('تم عرض التقرير — ${_rows.length} سطر.');
  }

  Future<void> _collectSelected() async {
    if (_selectedId == null) {
      _toast('اختر شيكاً أو قسطاً من الجدول أولاً.');
      return;
    }
    try {
      await _repo.markCheckCollected(_selectedId!);
      if (!mounted) return;
      setState(() => _selectedId = null);
      _load();
      _toast('تم تحصيل الشيك وتسجيل حركة الخزينة والحساب.');
    } catch (e) {
      if (mounted) _toast('$e'.replaceFirst('Exception: ', ''));
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

  void _printReport() {
    showDialog<void>(
      context: context,
      builder: (_) => PrintPreviewDialog(
        title: 'متابعة سداد الشيكات والأقساط',
        columns: const [
          'القيمة',
          'تاريخ الإستحقاق',
          'تاريخ التحصيل',
          'تاريخ الفاتورة',
          'الحركة',
          'رقم قبض / صرف',
          'رقم الفاتورة',
          'الحساب',
        ],
        rows: _rows
            .map(
              (r) => [
                '${r.amount}',
                _fmtDate(r.dueDate),
                r.collectedDate == null ? '' : _fmtDate(r.collectedDate!),
                r.invoiceDate == null ? '' : _fmtDate(r.invoiceDate!),
                r.direction == 'in' ? 'قبض' : 'صرف',
                r.receiptNumber,
                r.invoiceNumber,
                r.accountName,
              ],
            )
            .toList(),
      ),
    );
  }

  Future<void> _pickDate({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
        _fromDate.text = _fmtDate(picked);
      } else {
        _to = picked;
        _toDate.text = _fmtDate(picked);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return withPlainInputs(
      AppShell(
        activeTab: AppTab.accounts,
        extraTabLabel: 'متابعة سداد الشيكات والأقساط',
        onExtraTabClose: () => context.go('/accounts'),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Row(
                textDirection: TextDirection.ltr,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 226,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildSidebar(),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 8),
                      child: _buildTable(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 266,
      color: Colors.white,
      child: Stack(
        children: [
          const Positioned(
            right: 16,
            top: 8,
            child: AcctTitle('متابعة سداد الشيكات والأقساط', fontSize: 24),
          ),
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
                  onTap: () => context.go('/accounts'),
                ),
                const SizedBox(width: 7),
                AcctButton(
                  label: '؟',
                  width: 44,
                  height: 30,
                  onTap: () => _toast(
                    'حدد نوع التقرير والحالة والتاريخ ثم اضغط عرض التقرير.',
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 175,
            top: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _filterPair(
                      'نوع التقرير',
                      AcctDropdown(
                        value: _reportType,
                        width: 176,
                        height: 27,
                        items: const ['الكل', 'شيكات', 'أقساط'],
                        onChanged: (v) =>
                            setState(() => _reportType = v ?? 'الكل'),
                      ),
                    ),
                    const SizedBox(width: 44),
                    _filterPair(
                      'حالة السداد',
                      AcctDropdown(
                        value: _paymentState,
                        width: 176,
                        height: 27,
                        items: const ['الكل', 'مسدد', 'غير مسدد'],
                        onChanged: (v) =>
                            setState(() => _paymentState = v ?? 'الكل'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _filterPair(
                      'التاريخ',
                      AcctField(
                        controller: _fromDate,
                        width: 176,
                        height: 27,
                        readOnly: true,
                        textAlign: TextAlign.right,
                        onTap: () => _pickDate(from: true),
                        suffix: const Icon(
                          Icons.calendar_month,
                          size: 14,
                          color: Color(0xFF555555),
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                    _filterPair(
                      'إلى التاريخ',
                      AcctField(
                        controller: _toDate,
                        width: 176,
                        height: 27,
                        readOnly: true,
                        textAlign: TextAlign.right,
                        onTap: () => _pickDate(from: false),
                        suffix: const Icon(
                          Icons.calendar_month,
                          size: 14,
                          color: Color(0xFF555555),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _filterPair(
                      'الحساب',
                      SizedBox(
                        width: 176,
                        child: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Expanded(
                              child: AcctField(
                                controller: _accountName,
                                width: 176,
                                height: 27,
                                readOnly: true,
                              ),
                            ),
                            const SizedBox(width: 3),
                            SizedBox(
                              width: 52,
                              child: AcctField(
                                controller: _accountId,
                                width: 52,
                                height: 27,
                                numeric: true,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 3),
                            AcctClearX(
                              size: 26,
                              onTap: () {
                                _accountId.clear();
                                _accountName.clear();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                    _filterPair(
                      'تصنيف الحساب',
                      AcctDropdown(
                        value: null,
                        width: 176,
                        height: 27,
                        hint: '',
                        items: const [],
                        onChanged: (_) {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _filterPair(
                      'البنك',
                      AcctField(controller: _bank, width: 176, height: 27),
                    ),
                    const SizedBox(width: 44),
                    _filterPair(
                      'رقم الشيك',
                      AcctField(
                        controller: _checkNumber,
                        width: 176,
                        height: 27,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AcctYellowButton(
                  label: 'عرض التقرير',
                  width: 200,
                  height: 38,
                  onTap: _viewReport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPair(String label, Widget field) {
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF1A1A1A)),
          ),
        ),
        const SizedBox(width: 8),
        field,
      ],
    );
  }

  Widget _buildSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AcctTile(
          label: 'عرض',
          height: 46,
          onTap: _viewReport,
          icon: const Icon(
            Icons.description,
            size: 20,
            color: Color(0xFFE2A200),
          ),
        ),
        const SizedBox(height: 6),
        AcctTile(
          label: 'تحصيل',
          height: 46,
          onTap: _collectSelected,
          icon: const _MoneyDot(),
        ),
        const SizedBox(height: 6),
        AcctTile(
          label: 'إغلاق',
          height: 46,
          onTap: () => context.go('/accounts'),
          icon: const _PowerDot(),
        ),
        const SizedBox(height: 12),
        Row(
          textDirection: TextDirection.rtl,
          children: [
            AcctTile(
              label: 'طباعة التقرير',
              width: 166,
              height: 38,
              onTap: _printReport,
              icon: const Icon(Icons.print, size: 18, color: Color(0xFF333333)),
            ),
            const SizedBox(width: 4),
            HoverAssetButton(
              asset: 'assets/icons/products/share.png',
              width: 48,
              height: 38,
              onTap: () =>
                  _toast('مشاركة التقرير — استخدم الطباعة أو حفظ صورة.'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          textDirection: TextDirection.rtl,
          children: [
            AcctTile(
              label: 'طباعة المستند',
              width: 166,
              height: 38,
              onTap: _printReport,
              icon: const Icon(Icons.print, size: 18, color: Color(0xFF333333)),
            ),
            const SizedBox(width: 4),
            HoverAssetButton(
              asset: 'assets/icons/products/share.png',
              width: 48,
              height: 38,
              onTap: () =>
                  _toast('مشاركة المستند — استخدم الطباعة أو حفظ صورة.'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTable() {
    const columns = <_CheckCol>[
      _CheckCol('', 28),
      _CheckCol('القيمة', 96),
      _CheckCol('تاريخ الإستحقاق', 108),
      _CheckCol('تاريخ التحصيل', 108),
      _CheckCol('تاريخ الفاتورة', 108),
      _CheckCol('الحركة', 82),
      _CheckCol('رقم قبض / صرف', 118),
      _CheckCol('رقم الفاتورة', 108),
      _CheckCol('الحساب', null),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFC8C8C8)),
      ),
      child: Column(
        children: [
          Container(
            height: 27,
            color: const Color(0xFFEDEDED),
            child: Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < columns.length; i++) ...[
                  if (i > 0) _hSep(),
                  if (columns[i].width == null)
                    Expanded(child: _hCell(columns[i].label))
                  else
                    SizedBox(
                      width: columns[i].width,
                      child: _hCell(columns[i].label),
                    ),
                ],
              ],
            ),
          ),
          Container(height: 22, color: kAcctTableGreen),
          Expanded(
            child: _rows.isEmpty
                ? Container(
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFD0D0D0)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x22000000), blurRadius: 4),
                        ],
                      ),
                      child: const Text(
                        'لا يوجد بيانات ، حدد خيارات البحث ثم اضغط عرض التقرير',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF555555),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _rows.length,
                    itemBuilder: (context, index) => _row(_rows[index]),
                  ),
          ),
          Container(
            height: 26,
            color: const Color(0xFFEDEDED),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                for (var i = 0; i < columns.length; i++) ...[
                  if (i > 0) _vSep(),
                  if (columns[i].width == null)
                    const Expanded(child: _FooterCell())
                  else
                    SizedBox(
                      width: columns[i].width,
                      child: _FooterCell(
                        green: i == 1,
                        text: i == 1
                            ? '${_rows.fold<int>(0, (sum, r) => sum + r.amount)}'
                            : '',
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(AccountCheckRow row) {
    final selected = row.id == _selectedId;
    final cells = <Widget>[
      _dCell('', 28),
      _dCell('${row.amount}', 96),
      _dCell(_fmtDate(row.dueDate), 108),
      _dCell(
        row.collectedDate == null ? '' : _fmtDate(row.collectedDate!),
        108,
      ),
      _dCell(row.invoiceDate == null ? '' : _fmtDate(row.invoiceDate!), 108),
      _dCell(row.direction == 'in' ? 'قبض' : 'صرف', 82),
      _dCell(row.receiptNumber, 118),
      _dCell(row.invoiceNumber, 108),
      _dCell(row.accountName, null),
    ];
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedId = row.id),
        child: Container(
          height: 26,
          color: selected
              ? const Color(0xFF1DBE48)
              : (hovered ? const Color(0xFF42DE6C) : kAcctTableGreen),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              for (var i = 0; i < cells.length; i++) ...[
                if (i > 0) _dSep(),
                cells[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _dCell(String text, double? width) {
    final child = Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Color(0xFF0F3F1C)),
      ),
    );
    return width == null
        ? Expanded(child: child)
        : SizedBox(width: width, child: child);
  }

  Widget _hCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF1A1A1A)),
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(width: 3),
              const Icon(
                Icons.arrow_drop_down,
                size: 13,
                color: Color(0xFF777777),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _vSep() => Container(width: 1, color: const Color(0xFFC0C0C0));

  Widget _hSep() => Container(width: 1, color: const Color(0xFFC0C0C0));

  Widget _dSep() => Container(width: 1, color: const Color(0xFF9AD9AB));

  String _fmtDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}

class _CheckCol {
  const _CheckCol(this.label, this.width);
  final String label;
  final double? width;
}

class _FooterCell extends StatelessWidget {
  const _FooterCell({this.text = '', this.green = false});

  final String text;
  final bool green;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: green ? kAcctTableGreen : const Color(0xFFEDEDED),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)),
      ),
    );
  }
}

/// Green "$" disc used by the تحصيل command.
class _MoneyDot extends StatelessWidget {
  const _MoneyDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Color(0xFF2FBF55),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        '\$',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

/// Small red power disc used by the إغلاق command.
class _PowerDot extends StatelessWidget {
  const _PowerDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Color(0xFFE05A4B),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.power_settings_new,
        size: 13,
        color: Colors.white,
      ),
    );
  }
}
