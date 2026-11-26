import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:safwa/app/shell/app_top_bar.dart';
import 'package:safwa/app/widgets/hover_widgets.dart';
import 'package:safwa/features/accounts/data/accounts_repo.dart';
import 'package:safwa/features/accounts/domain/account_record.dart';
import 'package:safwa/features/accounts/presentation/accounts_ui.dart';
import 'package:safwa/features/accounts/presentation/print_preview_dialog.dart';

/// كشف حساب / كشف حساب بالأصناف — replica of the two reference statement
/// screens: green title, account filters, pink balance tile, command sidebar,
/// the green movement grid and (for the normal statement) the items grid below.
class StatementPage extends StatefulWidget {
  const StatementPage({
    super.key,
    required this.accountId,
    this.byItems = false,
  });

  final int accountId;
  final bool byItems;

  @override
  State<StatementPage> createState() => _StatementPageState();
}

class _StatementPageState extends State<StatementPage> {
  final AccountsRepo _repo = AccountsRepo();
  final TextEditingController _accountId = TextEditingController();
  final TextEditingController _accountName = TextEditingController();
  final TextEditingController _fromDate = TextEditingController();
  final TextEditingController _toDate = TextEditingController();

  AccountRecord? _account;
  List<AccountMovement> _movements = const [];
  String _dateFilter = 'اليوم';
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  int _selectedMovement = -1;

  bool get _byItems => widget.byItems;
  String get _title => _byItems ? 'كشف حساب بالأصناف' : 'كشف حساب';

  @override
  void initState() {
    super.initState();
    _accountId.text = '${widget.accountId}';
    _fromDate.text = _fmtDate(_from);
    _toDate.text = _fmtDate(_to);
    _loadAccount(widget.accountId);
  }

  @override
  void dispose() {
    _accountId.dispose();
    _accountName.dispose();
    _fromDate.dispose();
    _toDate.dispose();
    super.dispose();
  }

  void _loadAccount(int id) {
    final account = _repo.accountById(id);
    _account = account;
    _accountName.text = account?.name ?? '';
    _movements = _filterMovements(_repo.movements(id));
  }

  List<AccountMovement> _filterMovements(List<AccountMovement> rows) {
    final from = DateTime(_from.year, _from.month, _from.day);
    final to = DateTime(_to.year, _to.month, _to.day, 23, 59, 59);
    return rows
        .where((m) => !m.date.isBefore(from) && !m.date.isAfter(to))
        .toList();
  }

  void _applyFilters() {
    final id = int.tryParse(_accountId.text.trim()) ?? widget.accountId;
    setState(() {
      _loadAccount(id);
      _selectedMovement = -1;
    });
    _toast('تم عرض التقرير — ${_movements.length} حركة.');
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
      _dateFilter = 'فترة مخصصة';
    });
  }

  int get _debitTotal => _movements.fold<int>(0, (sum, m) => sum + m.debit);
  int get _creditTotal => _movements.fold<int>(0, (sum, m) => sum + m.credit);

  int get _balance => _account?.balance ?? 0;

  String get _balanceText {
    final value = _balance;
    return value < 0 ? '${-value}-' : '$value';
  }

  void _printReport() {
    showDialog<void>(
      context: context,
      builder: (_) => PrintPreviewDialog(
        title: _byItems ? 'كشف حساب بالأصناف' : 'كشف حساب',
        columns: _byItems
            ? const [
                'التاريخ',
                'الوقت',
                'الحركة',
                'الصنف',
                'الوحدة',
                'الكمية',
                'السعر',
                'الإجمالي',
                'الفاتورة',
              ]
            : const [
                'التاريخ',
                'الوقت',
                'الحركة',
                'عليه - مدين',
                'له - دائن',
                'الرصيد',
                'رقم الحركة',
                'ملاحظات',
              ],
        rows: _byItems
            ? const []
            : _movements
                  .map(
                    (m) => [
                      _fmtDate(m.date),
                      m.time,
                      m.label,
                      m.debit == 0 ? '' : '${m.debit}',
                      m.credit == 0 ? '' : '${m.credit}',
                      '${m.balanceAfter}',
                      m.number,
                      m.notes,
                    ],
                  )
                  .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return withPlainInputs(
      AppShell(
        activeTab: AppTab.accounts,
        extraTabLabel: '$_title | ${_account?.name ?? ''}',
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
                      child: Column(
                        children: [
                          Expanded(child: _buildMovementTable()),
                          if (!_byItems) ...[
                            const SizedBox(height: 6),
                            SizedBox(height: 212, child: _buildItemsTable()),
                          ],
                        ],
                      ),
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

  // ---------------------------------------------------------------------------
  // Header.
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Container(
      height: 198,
      color: Colors.white,
      child: Stack(
        children: [
          Positioned(
            right: 16,
            top: 8,
            child: Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AcctTitle(_title, fontSize: 25),
                const SizedBox(width: 26),
                HoverBuilder(
                  builder: (context, hovered) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toast(
                      'اختر الحساب من حقل رقم الحساب ثم اضغط عرض التقرير.',
                    ),
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: hovered
                                ? kHoverYellow
                                : const Color(0xFF2F76E8),
                            width: 1.4,
                          ),
                        ),
                      ),
                      child: Text(
                        _account?.name ?? '',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2F67C1),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_byItems)
            Positioned(
              left: 8,
              top: 8,
              child: HoverAssetButton(
                asset: 'assets/icons/products/top_cancel.png',
                width: 126,
                height: 30,
                onTap: () => context.go('/accounts'),
              ),
            ),
          // Account filter row.
          Positioned(
            right: 15,
            top: 52,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                const Text(
                  'الحساب',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(width: 8),
                AcctField(
                  controller: _accountName,
                  width: 168,
                  height: 26,
                  textAlign: TextAlign.right,
                  readOnly: true,
                ),
                const SizedBox(width: 4),
                AcctField(
                  controller: _accountId,
                  width: 56,
                  height: 26,
                  numeric: true,
                  textAlign: TextAlign.center,
                  onChanged: (_) {},
                ),
                const SizedBox(width: 4),
                AcctClearX(
                  onTap: () {
                    _accountId.clear();
                    _accountName.clear();
                  },
                ),
              ],
            ),
          ),
          // Date filter row.
          Positioned(
            right: 15,
            top: 100,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                AcctDropdown(
                  label: 'التاريخ',
                  value: _dateFilter,
                  width: 108,
                  height: 26,
                  items: const [
                    'اليوم',
                    'الأسبوع',
                    'الشهر',
                    'الكل',
                    'فترة مخصصة',
                  ],
                  onChanged: (value) {
                    setState(() {
                      _dateFilter = value ?? 'اليوم';
                      final now = DateTime.now();
                      switch (_dateFilter) {
                        case 'الأسبوع':
                          _from = now.subtract(const Duration(days: 7));
                          break;
                        case 'الشهر':
                          _from = DateTime(now.year, now.month, 1);
                          break;
                        case 'الكل':
                          _from = DateTime(2000);
                          break;
                        default:
                          _from = now;
                      }
                      _to = now;
                      _fromDate.text = _fmtDate(_from);
                      _toDate.text = _fmtDate(_to);
                    });
                  },
                ),
                const SizedBox(width: 24),
                AcctField(
                  label: 'من التاريخ',
                  controller: _fromDate,
                  width: 140,
                  height: 26,
                  readOnly: true,
                  textAlign: TextAlign.center,
                  onTap: () => _pickDate(from: true),
                  suffix: const Icon(
                    Icons.calendar_month,
                    size: 15,
                    color: Color(0xFF555555),
                  ),
                ),
                const SizedBox(width: 24),
                AcctField(
                  label: 'إلى التاريخ',
                  controller: _toDate,
                  width: 140,
                  height: 26,
                  readOnly: true,
                  textAlign: TextAlign.center,
                  onTap: () => _pickDate(from: false),
                  suffix: const Icon(
                    Icons.calendar_month,
                    size: 15,
                    color: Color(0xFF555555),
                  ),
                ),
                const SizedBox(width: 24),
                AcctYellowButton(
                  label: 'عرض التقرير',
                  width: 150,
                  height: 38,
                  onTap: _applyFilters,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_byItems) ...[
          Container(
            height: 58,
            color: const Color(0xFFF8E1DE),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                const Text(
                  'رصيد الحساب',
                  style: TextStyle(fontSize: 12, color: Color(0xFF333333)),
                ),
                const Spacer(),
                Text(
                  _balanceText,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
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
        if (!_byItems) ...[
          Row(
            textDirection: TextDirection.rtl,
            children: [
              AcctTile(
                label: 'طباعة المستند',
                width: 166,
                height: 38,
                onTap: _printReport,
                icon: const Icon(
                  Icons.print,
                  size: 18,
                  color: Color(0xFF333333),
                ),
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
          const SizedBox(height: 12),
        ],
        Row(
          textDirection: TextDirection.rtl,
          children: [
            AcctTile(
              label: 'تعديل الفاتورة',
              width: 106,
              height: 58,
              maxLines: 2,
              fontSize: 12,
              onTap: () => _toast('اختر حركة من الجدول أولاً لتعديل فاتورتها.'),
              icon: const Icon(
                Icons.description,
                size: 19,
                color: Color(0xFFE2A200),
              ),
            ),
            const SizedBox(width: 4),
            AcctTile(
              label: 'حذف الفاتورة',
              width: 106,
              height: 58,
              maxLines: 2,
              fontSize: 12,
              onTap: () => _toast('لا توجد فاتورة محددة للحذف.'),
              icon: const Icon(Icons.close, size: 19, color: Color(0xFFD64A3B)),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Movement table.
  // ---------------------------------------------------------------------------
  static const _wControl = 28.0;
  static const _wDate = 96.0;
  static const _wTime = 84.0;
  static const _wMove = 84.0;
  static const _wMoney = 86.0;
  static const _wBalance = 96.0;
  static const _wNumber = 150.0;

  Widget _buildMovementTable() {
    final rows = _movements;
    final columns = _byItems
        ? const <_Col>[
            _Col('', _wControl),
            _Col('التاريخ', _wDate),
            _Col('الوقت', _wTime),
            _Col('الحركة', _wMove),
            _Col('الصنف', null),
            _Col('الوحدة', 80),
            _Col('كمية', 70),
            _Col('السعر', 80),
            _Col('الإجمالي', 90),
            _Col('الفاتورة', 110),
          ]
        : const <_Col>[
            _Col('', _wControl),
            _Col('التاريخ', _wDate),
            _Col('الوقت', _wTime),
            _Col('الحركة', _wMove),
            _Col('عليه - مدين', _wMoney),
            _Col('له - دائن', _wMoney),
            _Col('الرصيد', _wBalance),
            _Col('رقم الحركة', _wNumber),
            _Col('ملاحظات', null),
          ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFC8C8C8)),
      ),
      child: Column(
        children: [
          _headerRow(columns),
          Container(height: 22, color: kAcctTableGreen),
          Expanded(
            child: rows.isEmpty
                ? _emptyBody(_byItems ? 'لا يوجد بيانات' : 'لا يوجد بيانات')
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    itemBuilder: (context, index) =>
                        _movementRow(rows[index], index),
                  ),
          ),
          _movementFooter(columns),
        ],
      ),
    );
  }

  Widget _headerRow(List<_Col> columns) {
    return Container(
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
    );
  }

  Widget _movementRow(AccountMovement m, int index) {
    final selected = index == _selectedMovement;
    final cells = _byItems
        ? <Widget>[
            _dCell('', _wControl),
            _dCell(_fmtDate(m.date), _wDate),
            _dCell(m.time, _wTime),
            _dCell(m.label, _wMove),
            _dCell(m.label, null),
            _dCell('', 80),
            _dCell('', 70),
            _dCell('', 80),
            _dCell('', 90),
            _dCell(m.number, 110),
          ]
        : <Widget>[
            _dCell('', _wControl),
            _dCell(_fmtDate(m.date), _wDate),
            _dCell(m.time, _wTime),
            _dCell(m.label, _wMove),
            _dCell(m.debit == 0 ? '' : '${m.debit}', _wMoney),
            _dCell(m.credit == 0 ? '' : '${m.credit}', _wMoney),
            _dCell('${m.balanceAfter}', _wBalance),
            _dCell(m.number, _wNumber),
            Expanded(child: _dCell(m.notes, null)),
          ];
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedMovement = index),
        child: Container(
          height: 25,
          color: selected
              ? const Color(0xFF43B5DB)
              : (hovered ? const Color(0xFF8DCDE2) : kAcctTableGreen),
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

  Widget _movementFooter(List<_Col> columns) {
    Widget cell(String text, double? width) {
      return width == null
          ? Expanded(child: _fCell(text))
          : SizedBox(width: width, child: _fCell(text));
    }

    if (_byItems) {
      return Container(
        height: 26,
        color: const Color(0xFFEDEDED),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            for (var i = 0; i < columns.length; i++) ...[
              if (i > 0) _vSep(),
              cell('', columns[i].width),
            ],
          ],
        ),
      );
    }

    return Container(
      height: 26,
      color: const Color(0xFFEDEDED),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          SizedBox(width: _wControl, child: _fCell('')),
          _vSep(),
          SizedBox(width: _wDate, child: _fCell('')),
          _vSep(),
          SizedBox(width: _wTime, child: _fCell('')),
          _vSep(),
          SizedBox(width: _wMove, child: _fCell('')),
          _vSep(),
          SizedBox(
            width: _wMoney,
            child: _fCell('$_debitTotal', green: _debitTotal != 0),
          ),
          _vSep(),
          SizedBox(
            width: _wMoney,
            child: _fCell('$_creditTotal', green: _creditTotal != 0),
          ),
          _vSep(),
          SizedBox(
            width: _wBalance,
            child: _fCell('${_debTotalBalance()}', green: true),
          ),
          _vSep(),
          SizedBox(width: _wNumber, child: _fCell('')),
          _vSep(),
          Expanded(child: _fCell('')),
        ],
      ),
    );
  }

  int _debTotalBalance() {
    if (_movements.isEmpty) return 0;
    return _movements.last.balanceAfter;
  }

  // ---------------------------------------------------------------------------
  // Items table (shown under the normal statement).
  // ---------------------------------------------------------------------------
  Widget _buildItemsTable() {
    const columns = <_Col>[
      _Col('', 28),
      _Col('رقم الصنف', 90),
      _Col('اسم الصنف', null),
      _Col('وحدة', 80),
      _Col('كمية', 70),
      _Col('السعر', 80),
      _Col('الخصم', 80),
      _Col('النهائي', 95),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFC8C8C8)),
      ),
      child: Column(
        children: [
          _headerRow(columns),
          Container(height: 22, color: kAcctTableGreen),
          const Expanded(
            child: Center(
              child: Text(
                'لا يوجد نتائج للبحث',
                style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
              ),
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
                    const Expanded(child: _EmptyCell())
                  else
                    SizedBox(
                      width: columns[i].width,
                      child: const _EmptyCell(),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Small table building blocks.
  // ---------------------------------------------------------------------------
  Widget _emptyBody(String text) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD0D0D0)),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4)],
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
        ),
      ),
    );
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
              const SizedBox(width: 4),
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

  Widget _dCell(String text, double? width) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Color(0xFF248EB2)),
        ),
      ),
    );
    return width == null
        ? Expanded(child: child)
        : SizedBox(width: width, child: child);
  }

  Widget _fCell(String text, {bool green = false}) {
    return Container(
      color: green ? kAcctTableGreen : const Color(0xFFEDEDED),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)),
      ),
    );
  }

  Widget _vSep() => Container(width: 1, color: const Color(0xFFC0C0C0));

  Widget _hSep() => Container(width: 1, color: const Color(0xFFC0C0C0));

  Widget _dSep() => Container(width: 1, color: const Color(0xFF8DCDE2));

  String _fmtDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}

class _Col {
  const _Col(this.label, this.width);
  final String label;
  final double? width;
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();

  @override
  Widget build(BuildContext context) =>
      Container(color: const Color(0xFFEDEDED));
}
