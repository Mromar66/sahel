import 'package:flutter/material.dart';

import 'package:safwa/app/widgets/document_custom_fields.dart';
import 'package:safwa/app/widgets/hover_widgets.dart';
import 'package:safwa/core/services/document_custom_fields.dart';
import 'package:safwa/features/accounts/data/accounts_repo.dart';
import 'package:safwa/features/accounts/domain/account_record.dart';
import 'package:safwa/features/accounts/presentation/accounts_ui.dart';

/// Green account form floating over the accounts list — replica of the
/// reference dialog: name + account nature radios, four green panels
/// (الرصيد الافتتاحي / بيانات الاتصال / أكواد وتصنيفات / فواتير البيع / أخرى)
/// and the حفظ / حفظ + جديد / تراجع buttons.
class AccountFormDialog extends StatefulWidget {
  const AccountFormDialog({
    super.key,
    this.account,
    this.initialKind = 'customer',
  });

  final AccountRecord? account;
  final String initialKind;

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  final AccountsRepo _repo = AccountsRepo();

  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _taxNumber;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _debit;
  late final TextEditingController _credit;
  late final TextEditingController _discount;
  late final TextEditingController _defaultPrice;
  late final TextEditingController _maxDebt;
  late final TextEditingController _notes;

  String _kind = 'customer';
  int? _categoryId;
  DateTime _balanceDate = DateTime.now();
  bool _underReview = false;
  bool _inactive = false;
  bool _saving = false;
  Map<int, String> _customFieldValues = {};
  List<Map<String, dynamic>> _categories = const [];

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _code = TextEditingController(text: a?.code ?? '');
    _taxNumber = TextEditingController(text: a?.taxNumber ?? '');
    _phone = TextEditingController(text: a?.phone ?? '');
    _email = TextEditingController(text: a?.email ?? '');
    _address = TextEditingController(text: a?.address ?? '');
    _debit = TextEditingController(
      text: (a?.balance ?? 0) > 0 ? '${a!.balance}' : '',
    );
    _credit = TextEditingController(
      text: (a?.balance ?? 0) < 0 ? '${-a!.balance}' : '',
    );
    _discount = TextEditingController(text: '${a?.discountPercent ?? 0}');
    _defaultPrice = TextEditingController(
      text: (a?.defaultPrice ?? 0) == 0 ? '' : '${a!.defaultPrice}',
    );
    _maxDebt = TextEditingController(text: '${a?.maxDebt ?? 0}');
    _notes = TextEditingController(text: a?.notes ?? '');
    _kind = a?.kind ?? widget.initialKind;
    _categoryId = a?.categoryId;
    _balanceDate = a?.balanceDate ?? DateTime.now();
    _underReview = a?.underReview ?? false;
    _inactive = a == null ? false : !a.isActive;
    if (a?.id != null) {
      _customFieldValues = DocumentCustomFields.entityValues('account', a!.id!);
    }
    _categories = _repo.categories();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _code,
      _taxNumber,
      _phone,
      _email,
      _address,
      _debit,
      _credit,
      _discount,
      _defaultPrice,
      _maxDebt,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int _number(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  Future<void> _save({bool newAfter = false}) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('أدخل اسم الحساب أولاً.');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final balance = _number(_debit) - _number(_credit);
    final record = AccountRecord(
      id: widget.account?.id,
      name: name,
      kind: _kind,
      code: _code.text.trim(),
      taxNumber: _taxNumber.text.trim(),
      categoryId: _categoryId,
      categoryName: _categoryName(_categoryId),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      openingBalance: balance,
      balance: balance,
      balanceDate: _balanceDate,
      discountPercent: _number(_discount),
      defaultPrice: _number(_defaultPrice),
      maxDebt: _number(_maxDebt),
      notes: _notes.text.trim(),
      underReview: _underReview,
      isActive: !_inactive,
      createdAt: widget.account?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    try {
      int accountId;
      if (record.id == null) {
        accountId = _repo.insertAccount(record);
      } else {
        _repo.updateAccount(record);
        accountId = record.id!;
      }
      DocumentCustomFields.saveEntityValues(
        'account',
        accountId,
        _customFieldValues,
      );
      if (!mounted) return;
      if (newAfter) {
        setState(() {
          _name.clear();
          _code.clear();
          _taxNumber.clear();
          _phone.clear();
          _email.clear();
          _address.clear();
          _debit.clear();
          _credit.clear();
          _discount.text = '0';
          _defaultPrice.clear();
          _maxDebt.text = '0';
          _notes.clear();
          _kind = 'customer';
          _categoryId = null;
          _balanceDate = DateTime.now();
          _underReview = false;
          _inactive = false;
          _customFieldValues = {};
        });
        _toast('تم حفظ الحساب — أدخل الحساب الجديد.');
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) _toast('تعذر حفظ الحساب.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editCustomFields() async {
    final values = await showDocumentCustomFieldsDialog(
      context,
      scope: 'account',
      initialValues: _customFieldValues,
    );
    if (values == null || !mounted) return;
    setState(() => _customFieldValues = values);
  }

  String _categoryName(int? id) {
    for (final c in _categories) {
      if (c['id'] == id) return c['name'] as String;
    }
    return '';
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _balanceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _balanceDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: withPlainInputs(
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: 992,
            height: 630,
            decoration: BoxDecoration(
              color: kAcctGreen,
              border: Border.all(color: const Color(0xFF43B5DB), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 18, 30, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTop(),
                  const SizedBox(height: 14),
                  Expanded(child: _buildPanels()),
                  const SizedBox(height: 12),
                  _buildButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTop() {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 460,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'اسم الحساب',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFD9E8EC)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextField(
                      controller: _name,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: const InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                      ),
                    ),
                    Container(
                      height: 2.5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      color: const Color(0xFF004AC0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'طبيعة الحساب',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _kindRadio('customer', 'عميل'),
              const SizedBox(width: 12),
              _kindRadio('supplier', 'مورد'),
              const SizedBox(width: 12),
              _kindRadio('rep', 'مندوب بيع'),
              const SizedBox(width: 12),
              _kindRadio('other', 'أخرى'),
            ],
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _kindRadio(String value, String label) {
    final selected = _kind == value;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _kind = value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Colors.white),
            ),
            const SizedBox(width: 5),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Colors.white : Colors.transparent,
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              child: selected
                  ? const Center(
                      child: Icon(
                        Icons.check,
                        size: 10,
                        color: Color(0xFF43B5DB),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanels() {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 292,
          child: Column(
            children: [
              SizedBox(height: 142, child: _balancePanel()),
              const SizedBox(height: 8),
              Expanded(child: _contactPanel()),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 258, child: _codesPanel()),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              SizedBox(height: 158, child: _salesPanel()),
              const SizedBox(height: 8),
              Expanded(child: _otherPanel()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: kAcctPanelBody,
        border: Border.all(color: kAcctPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 27,
            color: kAcctPanelHeader,
            alignment: Alignment.center,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _balancePanel() {
    return _panel(
      title: 'رصيد الحساب الافتتاحي',
      child: Column(
        children: [
          _panelRow('عليه / مدين', _debit, numeric: true),
          const SizedBox(height: 7),
          _panelRow('له / دائن', _credit, numeric: true),
          const SizedBox(height: 7),
          _dateRow(),
        ],
      ),
    );
  }

  Widget _dateRow() {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        const Expanded(
          child: Text(
            'تاريخ الرصيد',
            style: TextStyle(fontSize: 12.5, color: Colors.white),
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pickDate,
            child: Container(
              width: 150,
              height: 26,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month,
                    size: 14,
                    color: Color(0xFF43B5DB),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _fmtDate(_balanceDate),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _contactPanel() {
    return _panel(
      title: 'بيانات الاتصال',
      child: Column(
        children: [
          _panelRow('موبايل', _phone),
          const SizedBox(height: 8),
          _panelRow('ايميل', _email),
          const SizedBox(height: 8),
          _panelRow('عنوان', _address),
        ],
      ),
    );
  }

  Widget _codesPanel() {
    return _panel(
      title: 'أكواد وتصنيفات',
      child: Column(
        children: [
          _panelRow('كود الحساب', _code),
          const SizedBox(height: 10),
          _panelRow('الرقم الضريبي', _taxNumber),
          const SizedBox(height: 10),
          Row(
            textDirection: TextDirection.rtl,
            children: [
              const Expanded(
                child: Text(
                  'التصنيف',
                  style: TextStyle(fontSize: 12.5, color: Colors.white),
                ),
              ),
              Container(
                width: 150,
                height: 26,
                color: Colors.white,
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: Color(0xFF555555),
                    ),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _categoryId,
                          isExpanded: true,
                          isDense: true,
                          icon: const SizedBox.shrink(),
                          hint: const Text('', style: TextStyle(fontSize: 12)),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF1A1A1A),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text(
                                'بدون تصنيف',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            ..._categories.map(
                              (c) => DropdownMenuItem<int?>(
                                value: c['id'] as int,
                                child: Text(
                                  c['name'] as String,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _categoryId = v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _salesPanel() {
    return _panel(
      title: 'فواتير البيع',
      child: Column(
        children: [
          _panelRow('نسبة الخصم', _discount, numeric: true),
          const SizedBox(height: 8),
          _panelRow(
            'سعر البيع',
            _defaultPrice,
            numeric: true,
            hint: 'الإفراضي',
          ),
          const SizedBox(height: 8),
          _panelRow('أعلى دين مسموح', _maxDebt, numeric: true),
        ],
      ),
    );
  }

  Widget _otherPanel() {
    return _panel(
      title: 'أخرى',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _greenCheck(
            'ذكرني بمراجعة الحساب',
            _underReview,
            (v) => setState(() => _underReview = v),
          ),
          _greenCheck(
            'حساب غير نشط',
            _inactive,
            (v) => setState(() => _inactive = v),
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'ملاحظات',
              style: TextStyle(fontSize: 12.5, color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: _notes,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF1A1A1A),
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _greenCheck(String label, bool value, ValueChanged<bool> onChanged) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          height: 28,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: value ? Colors.white : Colors.transparent,
                  border: Border.all(color: Colors.white),
                ),
                child: value
                    ? const Icon(
                        Icons.check,
                        size: 11,
                        color: Color(0xFF43B5DB),
                      )
                    : null,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(fontSize: 12.5, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelRow(
    String label,
    TextEditingController controller, {
    bool numeric = false,
    String? hint,
  }) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Colors.white),
          ),
        ),
        Container(
          width: 150,
          height: 26,
          color: Colors.white,
          child: TextField(
            controller: controller,
            keyboardType: numeric ? TextInputType.number : null,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF1A1A1A)),
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8A8A8A),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        TextButton.icon(
          onPressed: _saving ? null : _editCustomFields,
          icon: const Icon(Icons.tune, size: 15),
          label: const Text('حقول إضافية', style: TextStyle(fontSize: 11)),
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFFE8E8E8),
            foregroundColor: Colors.black,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Spacer(),
        _saveButton(
          label: 'حفظ + جديد',
          shortcut: 'CTRL + ENTER',
          yellow: false,
          glyph: Icons.add,
          onTap: _saving ? null : () => _save(newAfter: true),
        ),
        const SizedBox(width: 10),
        _saveButton(
          label: 'حفظ',
          shortcut: 'ENTER',
          yellow: true,
          glyph: Icons.check,
          onTap: _saving ? null : () => _save(),
        ),
        const SizedBox(width: 40),
        _cancelButton(),
        const Spacer(),
      ],
    );
  }

  Widget _saveButton({
    required String label,
    required String shortcut,
    required bool yellow,
    required IconData glyph,
    required VoidCallback? onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HoverBuilder(
          cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
          builder: (context, hovered) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: 138,
              height: 37,
              color: hovered
                  ? kHoverYellow
                  : (yellow ? const Color(0xFFE6C33C) : Colors.white),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    glyph,
                    size: 15,
                    color: yellow || hovered
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFF2F80ED),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          shortcut,
          style: const TextStyle(fontSize: 10, color: Color(0xFF248EB2)),
        ),
      ],
    );
  }

  Widget _cancelButton() {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(false),
        child: Container(
          width: 150,
          height: 37,
          color: hovered ? kHoverYellow : const Color(0xFFD6D6D6),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.power_settings_new,
                size: 15,
                color: Color(0xFF333333),
              ),
              SizedBox(width: 7),
              Text(
                'تراجع',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}
