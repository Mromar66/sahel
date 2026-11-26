import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:safwa/app/shell/app_top_bar.dart';
import 'package:safwa/app/widgets/hover_widgets.dart';
import 'package:safwa/app/widgets/document_custom_fields.dart';
import 'package:safwa/core/services/document_custom_fields.dart';
import 'package:safwa/features/accounts/data/accounts_repo.dart';
import 'package:safwa/features/accounts/domain/account_record.dart';
import 'package:safwa/features/accounts/presentation/accounts_ui.dart';
import 'package:safwa/features/accounts/presentation/print_preview_dialog.dart';

/// قبض / صرف — replica of the reference receipt and payment screens: the
/// right brand strip, the right-aligned voucher form, the عام / الفواتير
/// المسددة tabs and the dark bottom action bar.
class ReceiptPaymentPage extends StatefulWidget {
  const ReceiptPaymentPage({
    super.key,
    this.isReceipt = true,
    this.accountId = 0,
    this.editId,
  });

  final bool isReceipt;
  final int accountId;

  /// Opens an existing standalone voucher for editing.
  final int? editId;

  @override
  State<ReceiptPaymentPage> createState() => _ReceiptPaymentPageState();
}

class _ReceiptPaymentPageState extends State<ReceiptPaymentPage> {
  final AccountsRepo _repo = AccountsRepo();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _accountName = TextEditingController();
  final TextEditingController _accountId = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _date = TextEditingController();
  final TextEditingController _time = TextEditingController();
  final TextEditingController _movement = TextEditingController(text: '1');
  final TextEditingController _reference = TextEditingController();

  List<AccountRecord> _accounts = const [];
  List<Map<String, Object?>> _treasuries = const [];
  AccountRecord? _account;
  int? _selectedTreasuryId;
  String _itemLabel = '';
  String _itemKind = '';
  String _treasuryKind = '';
  int _tab = 0;
  bool _isCheck = false;
  bool _autoSettle = false;
  DateTime _voucherDate = DateTime.now();
  TimeOfDay _voucherTime = TimeOfDay.now();
  bool _saving = false;
  Map<int, String> _customFieldValues = {};

  /// True while an existing voucher is open through [ReceiptPaymentPage.editId].
  bool _editing = false;

  bool get _isReceipt => widget.isReceipt;
  String get _title => _isReceipt ? 'قبض' : 'صرف';
  Color get _accent =>
      _isReceipt ? const Color(0xFF43B5DB) : const Color(0xFFE4685A);

  @override
  void initState() {
    super.initState();
    _accounts = _repo.fetchAccounts().where((a) => a.isActive).toList();
    _treasuries = _repo.activeTreasuries();
    if (_treasuries.isNotEmpty) {
      _selectedTreasuryId = (_treasuries.first['id'] as num).toInt();
      _treasuryKind = '${_treasuries.first['name'] ?? ''}';
    }
    _accountId.text = widget.accountId == 0 ? '' : '${widget.accountId}';
    _date.text = _fmtDate(_voucherDate);
    _time.text = _fmtTime(_voucherTime);
    _itemLabel = _isReceipt ? 'بند الإيراد' : 'بند المصروف';
    _resolveAccount();
    _editing = widget.editId != null;
    if (_editing) {
      _loadForEdit(widget.editId!);
    }
  }

  void _loadForEdit(int id) {
    final row = _repo.paymentById(id);
    if (row == null) {
      _editing = false;
      _toast('السند المطلوب غير موجود.');
      return;
    }
    final type = '${row['payment_type'] ?? ''}';
    if (row['reference_id'] != null ||
        type != (_isReceipt ? 'receipt' : 'payment')) {
      _editing = false;
      _toast(
        row['reference_id'] != null
            ? 'هذا السند مرتبط بفاتورة ولا يمكن تعديله من هنا.'
            : 'نوع السند لا يطابق الشاشة المفتوحة.',
      );
      return;
    }
    final parsed = DateTime.tryParse('${row['payment_date'] ?? ''}');
    final treasuryId = _repo.treasuryIdForPayment(id);
    final treasuryRows = _treasuries.where(
      (treasury) => (treasury['id'] as num).toInt() == treasuryId,
    );
    setState(() {
      _editing = true;
      _amount.text = '${(row['amount'] as num?)?.toInt() ?? 0}';
      _accountId.text = '${(row['account_id'] as num?)?.toInt() ?? ''}';
      _notes.text = '${row['description'] ?? ''}';
      _isCheck = '${row['payment_method'] ?? ''}' == 'check';
      if (treasuryRows.isNotEmpty) {
        _selectedTreasuryId = treasuryId;
        _treasuryKind = '${treasuryRows.first['name'] ?? ''}';
      }
      if (parsed != null) {
        _voucherDate = parsed;
        _voucherTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
      }
      _date.text = _fmtDate(_voucherDate);
      _time.text = _fmtTime(_voucherTime);
      _customFieldValues = DocumentCustomFields.values(
        _isReceipt ? 'receipt' : 'payment',
        id,
      );
    });
    _resolveAccount();
    _toast('تم تحميل سند $_title للتعديل.');
  }

  @override
  void dispose() {
    for (final controller in [
      _amount,
      _accountName,
      _accountId,
      _notes,
      _date,
      _time,
      _movement,
      _reference,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _resolveAccount() {
    final id = int.tryParse(_accountId.text.trim());
    if (id == null || id == 0) {
      _account = null;
      _accountName.clear();
      return;
    }
    for (final account in _accounts) {
      if (account.id == id) {
        _account = account;
        _accountName.text = account.name;
        return;
      }
    }
    _account = null;
    _accountName.clear();
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

  Future<void> _editCustomFields() async {
    final values = await showDocumentCustomFieldsDialog(
      context,
      initialValues: _customFieldValues,
    );
    if (!mounted || values == null) return;
    setState(() => _customFieldValues = values);
  }

  /// Closes the voucher and returns to the screen it was opened from (the
  /// home page or the accounts list). Falls back to the accounts list when
  /// there is nothing underneath.
  void _close() {
    removeCurrentAppTab(context);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/accounts');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _voucherDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _voucherDate = picked;
      _date.text = _fmtDate(picked);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _voucherTime,
    );
    if (picked == null) return;
    setState(() {
      _voucherTime = picked;
      _time.text = _fmtTime(picked);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      _toast('أدخل مبلغاً أكبر من صفر.');
      return;
    }
    _resolveAccount();
    if (_account == null) {
      _toast('أدخل رقم حساب صحيح.');
      return;
    }
    setState(() => _saving = true);
    try {
      final stamp = DateTime(
        _voucherDate.year,
        _voucherDate.month,
        _voucherDate.day,
        _voucherTime.hour,
        _voucherTime.minute,
      );
      if (_editing && widget.editId != null) {
        await _repo.updatePayment(
          paymentId: widget.editId!,
          accountId: _account!.id!,
          amount: amount,
          isReceipt: _isReceipt,
          method: _isCheck ? 'check' : 'cash',
          date: stamp,
          treasuryId: _selectedTreasuryId,
          checkNumber: _reference.text.trim(),
          description: _notes.text.trim(),
          customFields: _customFieldValues,
        );
        _accounts = _repo.fetchAccounts().where((a) => a.isActive).toList();
        _resolveAccount();
        if (!mounted) return;
        setState(() => _saving = false);
        _toast('تم تحديث سند $_title بمبلغ $amount.');
        return;
      }
      await _repo.insertPayment(
        accountId: _account!.id!,
        amount: amount,
        isReceipt: _isReceipt,
        method: _isCheck ? 'check' : 'cash',
        treasuryId: _selectedTreasuryId,
        checkNumber: _reference.text.trim(),
        date: stamp,
        description: _notes.text.trim(),
        customFields: _customFieldValues,
      );
      _accounts = _repo.fetchAccounts().where((a) => a.isActive).toList();
      _resolveAccount();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _amount.clear();
        _notes.clear();
        _movement.text = '1';
        _customFieldValues = {};
      });
      _toast('تم حفظ سند $_title بمبلغ $amount.');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast(_messageOf(e));
      }
    }
  }

  /// Strips the `Exception: ` prefix so the Arabic message stays clean.
  static String _messageOf(Object error) {
    final text = '$error';
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : 'تعذر حفظ السند.';
  }

  void _newVoucher() {
    setState(() {
      _amount.clear();
      _notes.clear();
      _customFieldValues = {};
      _accountId.clear();
      _accountName.clear();
      _account = null;
      _isCheck = false;
      _tab = 0;
      _editing = false;
      _voucherDate = DateTime.now();
      _voucherTime = TimeOfDay.now();
      _date.text = _fmtDate(_voucherDate);
      _time.text = _fmtTime(_voucherTime);
      _movement.text = '1';
    });
  }

  Future<void> _delete() async {
    final id = widget.editId;
    if (!_editing || id == null) {
      if (_amount.text.trim().isEmpty && _accountId.text.trim().isEmpty) {
        _toast('لا يوجد سند محفوظ لحذفه.');
        return;
      }
      _newVoucher();
      _toast('تم تفريغ بيانات السند غير المحفوظة.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف السند'),
        content: const Text(
          'سيتم حذف السند وحركاته المالية المرتبطة. هل تريد المتابعة؟',
        ),
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
    if (confirmed != true || !mounted) return;
    try {
      await _repo.deletePayment(id);
      if (!mounted) return;
      _newVoucher();
      _toast('تم حذف السند وتحديث الحساب والخزينة.');
    } catch (e) {
      if (mounted) _toast(_messageOf(e));
    }
  }

  void _print() {
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    showDialog<void>(
      context: context,
      builder: (_) => PrintPreviewDialog(
        title: 'سند $_title',
        columns: const [
          'رقم الحركة',
          'التاريخ',
          'الوقت',
          'الحساب',
          'المبلغ',
          'البيان',
        ],
        rows: [
          [
            _movement.text,
            _date.text,
            _time.text,
            _accountName.text,
            '$amount',
            _notes.text,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return withPlainInputs(
      AppShell(
        activeTab: AppTab.accounts,
        extraTabLabel: '$_title | جديد',
        extraTabColor: _accent,
        extraTabTextColor: Colors.white,
        onExtraTabClose: _close,
        hideActiveTab: true,
        extraTabWidth: 210,
        child: Column(
          children: [
            Expanded(
              child: Row(
                textDirection: TextDirection.ltr,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildContent()),
                  SizedBox(width: 127, child: _buildBrandStrip()),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Voucher content.
  // ---------------------------------------------------------------------------
  Widget _buildContent() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 26),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 140,
                height: 38,
                color: _accent,
                alignment: Alignment.center,
                child: Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(right: 16, left: 60),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(width: 430, child: _buildForm()),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 16, left: 60),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(width: 403, child: _buildTabs()),
              ),
            ),
            const SizedBox(height: 1),
            Container(height: 1.2, color: const Color(0xFF2F76E8)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 16, left: 60),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: _tab == 0 ? 405 : null,
                  child: _tab == 0 ? _buildDetails() : _buildSettledInvoices(),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('المبلغ'),
        const SizedBox(height: 4),
        _amountField(),
        const SizedBox(height: 12),
        _label('الحساب'),
        const SizedBox(height: 4),
        Row(
          textDirection: TextDirection.rtl,
          children: [
            SizedBox(
              width: 118,
              height: 30,
              child: Container(
                padding: const EdgeInsets.only(bottom: 2),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF2F76E8), width: 1.4),
                  ),
                ),
                child: TextField(
                  controller: _accountName,
                  readOnly: true,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF1A1A1A),
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _smallField(
              _accountId,
              80,
              center: true,
              readOnly: false,
              onChanged: (_) => setState(_resolveAccount),
            ),
            const SizedBox(width: 4),
            AcctClearX(
              size: 26,
              onTap: () {
                _accountId.clear();
                _accountName.clear();
                setState(() => _account = null);
              },
            ),
            const SizedBox(width: 4),
            Container(
              width: 87,
              height: 28,
              color: _account == null
                  ? const Color(0xFFEDEDED)
                  : const Color(0xFFF4958A),
              alignment: Alignment.center,
              child: Text(
                _account == null ? '' : _balanceText(_account!.balance),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 4),
            HoverBuilder(
              builder: (context, hovered) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final balance = _account?.balance ?? 0;
                  if (_account == null) {
                    _toast('أدخل رقم حساب صحيح أولاً.');
                    return;
                  }
                  _amount.text = '${balance.abs()}';
                  _toast('تم إضافة رصيد الحساب إلى المبلغ.');
                },
                child: Container(
                  width: 93,
                  height: 28,
                  color: hovered ? kHoverYellow : const Color(0xFFEDEDED),
                  alignment: Alignment.center,
                  child: const Text(
                    'أضف الرصيد',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF1A1A1A)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _label(_itemLabel),
        const SizedBox(height: 4),
        _itemDropdown(),
        const SizedBox(height: 8),
        _label('ملاحظات'),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 400,
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFBFBFBF)),
              ),
              child: TextField(
                controller: _notes,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF1A1A1A),
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _editCustomFields,
            icon: const Icon(Icons.tune, size: 16),
            label: Text('حقول إضافية (${_customFieldValues.length})'),
          ),
        ),
      ],
    );
  }

  Widget _amountField() {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 200,
        height: 32,
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2F76E8), width: 2),
                ),
              ),
              child: TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(
                    right: 28,
                    left: 8,
                    top: 7,
                    bottom: 5,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 2,
              top: 3,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFF2F76E8),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '0',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF1A1A1A)),
      ),
    );
  }

  Widget _itemDropdown() {
    final items = _isReceipt
        ? const ['خدمات', 'تركيبات', 'صيانة', 'مبيعات', 'أخرى']
        : const ['إيجارات', 'صيانة', 'فواتير كهرباء', 'شحن', 'أخرى'];
    return Align(
      alignment: Alignment.centerRight,
      child: AcctDropdown(
        value: _itemKind.isEmpty ? null : _itemKind,
        items: items,
        width: 214,
        height: 28,
        hint: _isReceipt
            ? 'خدمات ، تركيبات ، صيانة ... إلخ'
            : 'مثال : إيجارات ، صيانة ، فواتير كهرباء ، شحن .. إلخ',
        fontSize: 11.5,
        onChanged: (value) => setState(() => _itemKind = value ?? ''),
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _SlantTab(
          label: 'عام',
          selected: _tab == 0,
          selectedColor: const Color(0xFF4F8FF7),
          onTap: () => setState(() => _tab = 0),
        ),
        const SizedBox(width: 3),
        _SlantTab(
          label: 'الفواتير المسددة',
          selected: _tab == 1,
          selectedColor: const Color(0xFF4F8FF7),
          onTap: () => setState(() => _tab = 1),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildDetails() {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              textDirection: TextDirection.rtl,
              children: [
                const Text(
                  'الخزينة',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF1A1A1A)),
                ),
                const Spacer(),
                AcctCheckRow(
                  label: 'شيك ؟',
                  value: _isCheck,
                  onChanged: (v) => setState(() => _isCheck = v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              textDirection: TextDirection.rtl,
              children: [
                const Text(
                  'درج النقدية',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AcctDropdown(
                    value: _treasuryKind.isEmpty ? null : _treasuryKind,
                    items: _treasuries
                        .map((treasury) => '${treasury['name'] ?? ''}')
                        .toList(),
                    height: 26,
                    onChanged: (value) => setState(() {
                      _treasuryKind = value ?? '';
                      final selected = _treasuries.where(
                        (treasury) => '${treasury['name'] ?? ''}' == value,
                      );
                      _selectedTreasuryId = selected.isEmpty
                          ? null
                          : (selected.first['id'] as num).toInt();
                    }),
                  ),
                ),
                const SizedBox(width: 3),
                Container(
                  width: 26,
                  height: 26,
                  color: const Color(0xFFEDEDED),
                  child: const Icon(
                    Icons.push_pin,
                    size: 14,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(width: 3),
                AcctClearX(
                  size: 24,
                  onTap: () => setState(() {
                    _selectedTreasuryId = null;
                    _treasuryKind = '';
                  }),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              textDirection: TextDirection.rtl,
              children: [
                const Text(
                  'المرحّ',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 200,
                  height: 26,
                  child: _smallField(_reference, 200),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              textDirection: TextDirection.rtl,
              children: [
                const Text(
                  'التاريخ / الوقت',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 128,
                  height: 26,
                  child: TextField(
                    controller: _date,
                    readOnly: true,
                    onTap: _pickDate,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF1A1A1A),
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: InputBorder.none,
                      suffixIcon: Icon(
                        Icons.calendar_month,
                        size: 14,
                        color: Color(0xFF555555),
                      ),
                      suffixIconConstraints: BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 100,
                  height: 26,
                  child: TextField(
                    controller: _time,
                    readOnly: true,
                    onTap: _pickTime,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF1A1A1A),
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              textDirection: TextDirection.rtl,
              children: [
                const Text(
                  'رقم الحركة',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 200,
                  height: 26,
                  child: TextField(
                    controller: _movement,
                    readOnly: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF1A1A1A),
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Color(0xFFEDEDED),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettledInvoices() {
    // Column widths, right → left: الحركة · تاريخ الفاتورة · رقم الفاتورة ·
    // الرصيد السابق · المسدد · الرصيد التالي.
    const widths = <double>[100, 100, 100, 100, 100, 112];
    const labels = <String>[
      'الحركة',
      'تاريخ الفاتورة',
      'رقم الفاتورة',
      'الرصيد السابق',
      'المسدد',
      'الرصيد التالي',
    ];
    const double tableWidth = 612;
    const Color green = Color(0xFF8DCDE2);
    const Color line = Color(0xFFE2E2E2);

    final header = SizedBox(
      height: 26,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) Container(width: 1, color: Colors.white),
            Container(
              width: widths[i] - (i > 0 ? 1 : 0),
              color: green,
              alignment: Alignment.center,
              child: Text(
                labels[i],
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF248EB2),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    // The body: white rows, the highlighted "المسدد" column and the totals
    // band. The band sits below the (empty) data area as in the reference.
    final body = Stack(
      children: [
        Positioned.fill(child: Container(color: Colors.white)),
        // Highlighted "المسدد" column (right: 4 columns × 100).
        Positioned(
          top: 0,
          bottom: 0,
          right: 400,
          width: 99,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF2CF45), Color(0xFFF2CF45), Colors.white],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        // Vertical column separators.
        for (var i = 1; i < labels.length; i++)
          Positioned(
            top: 0,
            bottom: 0,
            right: widths.take(i).fold<double>(0, (a, b) => a + b),
            child: Container(width: 1, color: line),
          ),
        // Totals band.
        Positioned(
          top: 132,
          left: 0,
          right: 0,
          height: 22,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) Container(width: 1, color: Colors.white),
                Container(
                  width: widths[i] - (i > 0 ? 1 : 0),
                  color: const Color(0xFFE4E4E4),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final table = Container(
      width: tableWidth,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFBFBFBF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          SizedBox(height: 250, child: body),
        ],
      ),
    );

    final sideButtons = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _settleButton('أضف', () => _toast('حدد فاتورة من الجدول ثم اضغط أضف.')),
        const SizedBox(height: 1),
        _settleButton(
          'أضف تلقائي',
          () => _toast('تمت إضافة الفواتير الأقدم ثم الأحدث تلقائياً.'),
        ),
        const SizedBox(height: 1),
        _settleButton('حذف', () => _toast('حدد فاتورة من الجدول لحذفها.')),
      ],
    );

    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [sideButtons, const SizedBox(width: 20), table],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _autoSettle = !_autoSettle),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF9A9A9A)),
                  ),
                  child: _autoSettle
                      ? const Icon(
                          Icons.check,
                          size: 11,
                          color: Color(0xFF2F67C1),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                const Text(
                  'أضف فواتير هذا الحساب الأقدم ثم الأحدث تلقائياً لسدادها',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _settleButton(String label, VoidCallback onTap) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 100,
          height: 40,
          color: hovered ? kHoverYellow : const Color(0xFFE9E9E9),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF1A1A1A)),
          ),
        ),
      ),
    );
  }

  Widget _smallField(
    TextEditingController controller,
    double width, {
    bool center = false,
    bool readOnly = true,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      width: width,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFBFBFBF)),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onChanged: onChanged,
        keyboardType: readOnly ? null : TextInputType.number,
        textAlign: center ? TextAlign.center : TextAlign.right,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF1A1A1A)),
        decoration: const InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Brand strip.
  // ---------------------------------------------------------------------------
  Widget _buildBrandStrip() {
    return Container(
      color: const Color(0xFF43B5DB),
      child: Column(
        children: [
          const SizedBox(height: 14),
          Image.asset(
            'assets/icons/safwa_logo.png',
            width: 78,
            height: 78,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) =>
                const Icon(Icons.shopping_cart, size: 62, color: Colors.white),
          ),
          const Text(
            'Safwa',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 34,
            color: Colors.white,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(Icons.search, size: 17, color: Color(0xFF333333)),
                Text(
                  'K',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF333333),
                  ),
                ),
                Icon(
                  Icons.keyboard_double_arrow_left,
                  size: 17,
                  color: Color(0xFF333333),
                ),
                Icon(
                  Icons.keyboard_double_arrow_right,
                  size: 17,
                  color: Color(0xFF333333),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          HoverBuilder(
            builder: (context, hovered) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _save,
              child: Container(
                width: 104,
                height: 104,
                color: hovered
                    ? const Color(0xFFFFD65C)
                    : const Color(0xFFE6C33C),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, size: 52, color: Color(0xFF2F67C1)),
                    SizedBox(height: 2),
                    Text(
                      'حفظ | إغلاق',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'F12',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 76,
              color: Colors.white,
              padding: const EdgeInsets.only(
                top: 9,
                bottom: 9,
                left: 4,
                right: 6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _brandCheck('طباعة', true, _print),
                  const SizedBox(height: 9),
                  _brandCheck('إغلاق', true, _close),
                  const SizedBox(height: 9),
                  _brandCheck('جديد', false, _newVoucher),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandCheck(String label, bool checked, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF8A8A8A)),
            ),
            child: checked
                ? const Icon(Icons.check, size: 11, color: Color(0xFF2F67C1))
                : null,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom action bar.
  // ---------------------------------------------------------------------------
  Widget _buildFooter() {
    return Container(
      height: 51,
      color: const Color(0xFF3D3D3D),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          const SizedBox(width: 6),
          _barButton(
            label: 'إغلاق',
            icon: Icons.power_settings_new,
            onTap: _close,
            width: 108,
          ),
          const Spacer(),
          _barButton(
            label: 'حذف',
            icon: Icons.close,
            iconColor: const Color(0xFFE05A4B),
            onTap: _delete,
            width: 118,
          ),
          HoverAssetButton(
            asset: 'assets/icons/products/share.png',
            width: 46,
            height: 40,
            onTap: () => _toast('مشاركة السند — استخدم الطباعة أو حفظ صورة.'),
          ),
          _barButton(
            label: 'طباعة',
            shortcut: 'F4',
            icon: Icons.print,
            onTap: _print,
            width: 104,
          ),
          _barButton(
            label: 'جديد',
            shortcut: 'F10',
            icon: Icons.add,
            onTap: _newVoucher,
            width: 104,
          ),
          _barButton(
            label: 'حفظ',
            shortcut: 'F9',
            icon: Icons.check,
            yellow: true,
            onTap: _save,
            width: 130,
          ),
        ],
      ),
    );
  }

  Widget _barButton({
    required String label,
    required VoidCallback onTap,
    required double width,
    IconData? icon,
    String? shortcut,
    Color? iconColor,
    bool yellow = false,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: 40,
          color: hovered
              ? const Color(0xFFFFD65C)
              : (yellow ? const Color(0xFFE6C33C) : const Color(0xFFEDEDED)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 17,
                  color: iconColor ?? const Color(0xFF333333),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              if (shortcut != null) ...[
                const SizedBox(width: 4),
                Text(
                  shortcut,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF555555),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------------------
  String _balanceText(int balance) => balance < 0 ? '${-balance}-' : '$balance';

  String _fmtDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  String _fmtTime(TimeOfDay time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour < 12 ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $suffix';
  }
}

/// Trapezoid tab used for عام / الفواتير المسددة.
class _SlantTab extends StatelessWidget {
  const _SlantTab({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipPath(
          clipper: _TabClipper(),
          child: Container(
            width: 200,
            height: 34,
            color: selected
                ? selectedColor
                : (hovered ? kHoverYellow : const Color(0xFFE3E3E3)),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const inset = 12.0;
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(inset, 0)
      ..lineTo(size.width - inset, 0)
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_TabClipper oldClipper) => false;
}
