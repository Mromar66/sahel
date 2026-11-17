part of 'treasury_movement_page.dart';

enum TreasuryEntryMode { receive, expense }

const List<String> _kExpenseCategories = [
  'مصروفات عامة',
  'رواتب وأجور',
  'إيجار',
  'كهرباء ومياه',
  'صيانة',
  'نقل وشحن',
  'مصروفات إدارية',
  'أخرى',
];

// -----------------------------------------------------------------------------
// Shared dialog helpers.
// -----------------------------------------------------------------------------
Widget _dialogInputBox({required Widget child, double height = 28}) {
  return Container(
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFB8B8B8)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 5),
    alignment: Alignment.centerRight,
    child: child,
  );
}

Widget _dialogTextField(
  TextEditingController controller, {
  bool number = false,
  int maxLines = 1,
}) {
  return _dialogInputBox(
    height: maxLines > 1 ? 54 : 28,
    child: TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : null,
      inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
      maxLines: maxLines,
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 12.5, color: _kInk),
      decoration: const InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 6),
      ),
    ),
  );
}

Widget _dialogDateField(
  BuildContext context,
  TextEditingController controller,
) {
  return _dialogInputBox(
    child: Row(
      textDirection: TextDirection.ltr,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 12, color: _kInk),
            decoration: const InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final initial = _parseDate(controller.text) ?? DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              helpText: 'اختر التاريخ',
              cancelText: 'إلغاء',
              confirmText: 'موافق',
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: ShopColors.green,
                    brightness: Brightness.light,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) controller.text = _dateText(picked);
          },
          child: const SizedBox(
            width: 22,
            child: Icon(
              Icons.calendar_today_outlined,
              size: 13,
              color: Color(0xFF555555),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _dialogTimeField(
  BuildContext context,
  TextEditingController controller,
) {
  return _dialogInputBox(
    child: Row(
      textDirection: TextDirection.ltr,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 12, color: _kInk),
            decoration: const InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final initial = _parseTime(controller.text) ?? DateTime.now();
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                hour: initial.hour,
                minute: initial.minute,
              ),
              helpText: 'اختر الوقت',
              cancelText: 'إلغاء',
              confirmText: 'موافق',
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: ShopColors.green,
                    brightness: Brightness.light,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              controller.text =
                  '${picked.hour.toString().padLeft(2, '0')}:'
                  '${picked.minute.toString().padLeft(2, '0')}';
            }
          },
          child: const SizedBox(
            width: 22,
            child: Icon(Icons.access_time, size: 13, color: Color(0xFF555555)),
          ),
        ),
      ],
    ),
  );
}

Widget _dialogTreasuryDropdown({
  required List<TreasuryAccount> treasuries,
  required int value,
  required ValueChanged<int> onChanged,
}) {
  final safeValue = treasuries.any((treasury) => treasury.id == value)
      ? value
      : treasuries.first.id;
  return _dialogInputBox(
    child: Row(
      textDirection: TextDirection.rtl,
      children: [
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: safeValue,
              isExpanded: true,
              isDense: true,
              icon: const SizedBox.shrink(),
              dropdownColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              style: const TextStyle(fontSize: 12.5, color: _kInk),
              items: treasuries
                  .map(
                    (treasury) => DropdownMenuItem<int>(
                      value: treasury.id,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          treasury.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: _kInk),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (picked) {
                if (picked != null) onChanged(picked);
              },
            ),
          ),
        ),
        const SizedBox(
          width: 17,
          child: Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: Color(0xFF555555),
          ),
        ),
      ],
    ),
  );
}

Widget _dialogStringDropdown({
  required List<String> values,
  required String value,
  required ValueChanged<String> onChanged,
}) {
  final safeValue = values.contains(value) ? value : values.first;
  return _dialogInputBox(
    child: Row(
      textDirection: TextDirection.rtl,
      children: [
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              isDense: true,
              icon: const SizedBox.shrink(),
              dropdownColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              style: const TextStyle(fontSize: 12.5, color: _kInk),
              items: values
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          item,
                          style: const TextStyle(fontSize: 12.5, color: _kInk),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (picked) {
                if (picked != null) onChanged(picked);
              },
            ),
          ),
        ),
        const SizedBox(
          width: 17,
          child: Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: Color(0xFF555555),
          ),
        ),
      ],
    ),
  );
}

Widget _dialogError(String message) {
  if (message.isEmpty) return const SizedBox.shrink();
  return Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    color: const Color(0xFFFFEEEE),
    child: Text(message, style: const TextStyle(fontSize: 11.5, color: _kRed)),
  );
}

// -----------------------------------------------------------------------------
// Receive / disbursement dialog.
// -----------------------------------------------------------------------------
class TreasuryMovementEntryDialog extends StatefulWidget {
  const TreasuryMovementEntryDialog({
    super.key,
    required this.mode,
    required this.treasuries,
    required this.initialTreasuryId,
    required this.initialDate,
    this.initialAmount = 0,
    this.initialDescription = '',
    this.initialNotes = '',
    this.initialCategory = '',
    this.initialCustomFields = const {},
    this.editing = false,
  });

  final TreasuryEntryMode mode;
  final List<TreasuryAccount> treasuries;
  final int? initialTreasuryId;
  final DateTime initialDate;
  final int initialAmount;
  final String initialDescription;
  final String initialNotes;
  final String initialCategory;
  final Map<int, String> initialCustomFields;
  final bool editing;

  @override
  State<TreasuryMovementEntryDialog> createState() =>
      _TreasuryMovementEntryDialogState();
}

class _TreasuryMovementEntryDialogState
    extends State<TreasuryMovementEntryDialog> {
  late int _treasuryId;
  late final TextEditingController _date;
  late final TextEditingController _time;
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  late String _category;
  String _error = '';
  late Map<int, String> _customFieldValues = Map.of(widget.initialCustomFields);

  bool get _isReceive => widget.mode == TreasuryEntryMode.receive;

  @override
  void initState() {
    super.initState();
    final initialId = widget.initialTreasuryId;
    _treasuryId =
        initialId != null &&
            widget.treasuries.any((treasury) => treasury.id == initialId)
        ? initialId
        : widget.treasuries.first.id;
    _date = TextEditingController(text: _dateText(widget.initialDate));
    _time = TextEditingController(text: _timeText(widget.initialDate));
    _amount = TextEditingController(
      text: widget.initialAmount > 0 ? '${widget.initialAmount}' : '',
    );
    _description = TextEditingController(text: widget.initialDescription);
    _notes = TextEditingController(text: widget.initialNotes);
    _category = widget.initialCategory.trim();
    if (_category.isEmpty) _category = _kExpenseCategories.first;
  }

  @override
  void dispose() {
    _date.dispose();
    _time.dispose();
    _amount.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = int.tryParse(_amount.text.trim());
    final date = _parseDate(_date.text);
    final time = _parseTime(_time.text);
    if (date == null) {
      setState(() => _error = 'صيغة التاريخ غير صحيحة. استخدم يوم/شهر/سنة.');
      return;
    }
    if (time == null) {
      setState(() => _error = 'صيغة الوقت غير صحيحة. استخدم ساعة:دقيقة.');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'أدخل مبلغاً أكبر من صفر.');
      return;
    }
    if (_description.text.trim().isEmpty) {
      setState(() => _error = 'اكتب بيان الحركة.');
      return;
    }
    Navigator.of(context).pop(
      TreasuryMovementInput(
        treasuryId: _treasuryId,
        date: DateTime(date.year, date.month, date.day, time.hour, time.minute),
        amount: amount,
        description: _description.text.trim(),
        notes: _isReceive ? _notes.text.trim() : '',
        category: _isReceive ? '' : _category,
        customFields: _customFieldValues,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>[
      ..._kExpenseCategories,
      if (!_kExpenseCategories.contains(_category)) _category,
    ];
    return ShopDialogFrame(
      title: _isReceive
          ? (widget.editing ? 'تعديل حركة قبض' : 'قبض — وارد الخزينة')
          : (widget.editing ? 'تعديل حركة صرف' : 'صرف — منصرف الخزينة'),
      width: 470,
      actions: [
        shopDialogButton(label: 'حفظ', primary: true, onTap: _submit),
        shopDialogButton(
          label: 'إلغاء',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            shopFieldLabel('الخزينة'),
            _dialogTreasuryDropdown(
              treasuries: widget.treasuries,
              value: _treasuryId,
              onChanged: (value) => setState(() => _treasuryId = value),
            ),
            const SizedBox(height: 9),
            Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      shopFieldLabel('التاريخ'),
                      _dialogDateField(context, _date),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      shopFieldLabel('الوقت'),
                      _dialogTimeField(context, _time),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            shopFieldLabel('المبلغ'),
            _dialogTextField(_amount, number: true),
            if (!_isReceive) ...[
              const SizedBox(height: 9),
              shopFieldLabel('تصنيف المصروف'),
              _dialogStringDropdown(
                values: categories,
                value: _category,
                onChanged: (value) => setState(() => _category = value),
              ),
            ],
            const SizedBox(height: 9),
            shopFieldLabel(_isReceive ? 'البيان / مصدر القبض' : 'البيان'),
            _dialogTextField(_description),
            if (_isReceive) ...[
              const SizedBox(height: 9),
              shopFieldLabel('ملاحظات'),
              _dialogTextField(_notes, maxLines: 2),
            ],
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final values = await showDocumentCustomFieldsDialog(
                    context,
                    initialValues: _customFieldValues,
                  );
                  if (mounted && values != null) {
                    setState(() => _customFieldValues = values);
                  }
                },
                icon: const Icon(Icons.tune, size: 16),
                label: Text('حقول إضافية (${_customFieldValues.length})'),
              ),
            ),
            _dialogError(_error),
            const SizedBox(height: 4),
            Text(
              _isReceive
                  ? 'سيتم إضافة المبلغ إلى رصيد الخزينة المحددة.'
                  : 'سيتم خصم المبلغ من رصيد الخزينة المحددة.',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF777777)),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Transfer dialog.
// -----------------------------------------------------------------------------
class TreasuryTransferDialog extends StatefulWidget {
  const TreasuryTransferDialog({
    super.key,
    required this.treasuries,
    required this.initialSourceId,
    required this.initialDestinationId,
    required this.initialAmount,
    required this.initialDate,
    required this.initialDescription,
    this.editing = false,
    this.initialCustomFields = const {},
  });

  final List<TreasuryAccount> treasuries;
  final int initialSourceId;
  final int initialDestinationId;
  final int initialAmount;
  final DateTime initialDate;
  final String initialDescription;
  final bool editing;
  final Map<int, String> initialCustomFields;

  @override
  State<TreasuryTransferDialog> createState() => _TreasuryTransferDialogState();
}

class _TreasuryTransferDialogState extends State<TreasuryTransferDialog> {
  late int _sourceId;
  late int _destinationId;
  late final TextEditingController _date;
  late final TextEditingController _time;
  late final TextEditingController _amount;
  late final TextEditingController _description;
  String _error = '';
  late Map<int, String> _customFieldValues = Map.of(widget.initialCustomFields);

  @override
  void initState() {
    super.initState();
    _sourceId = widget.treasuries.any((t) => t.id == widget.initialSourceId)
        ? widget.initialSourceId
        : widget.treasuries.first.id;
    _destinationId =
        widget.treasuries.any((t) => t.id == widget.initialDestinationId) &&
            widget.initialDestinationId != _sourceId
        ? widget.initialDestinationId
        : widget.treasuries.firstWhere((t) => t.id != _sourceId).id;
    _date = TextEditingController(text: _dateText(widget.initialDate));
    _time = TextEditingController(text: _timeText(widget.initialDate));
    _amount = TextEditingController(
      text: widget.initialAmount > 0 ? '${widget.initialAmount}' : '',
    );
    _description = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _date.dispose();
    _time.dispose();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  void _swap() {
    setState(() {
      final old = _sourceId;
      _sourceId = _destinationId;
      _destinationId = old;
    });
  }

  void _submit() {
    final amount = int.tryParse(_amount.text.trim());
    final date = _parseDate(_date.text);
    final time = _parseTime(_time.text);
    if (_sourceId == _destinationId) {
      setState(() => _error = 'اختر خزينة مصدر وخزينة وجهة مختلفتين.');
      return;
    }
    if (date == null) {
      setState(() => _error = 'صيغة التاريخ غير صحيحة.');
      return;
    }
    if (time == null) {
      setState(() => _error = 'صيغة الوقت غير صحيحة.');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'أدخل مبلغاً أكبر من صفر.');
      return;
    }
    if (_description.text.trim().isEmpty) {
      setState(() => _error = 'اكتب بيان التحويل.');
      return;
    }
    Navigator.of(context).pop(
      TreasuryTransferInput(
        sourceTreasuryId: _sourceId,
        destinationTreasuryId: _destinationId,
        date: DateTime(date.year, date.month, date.day, time.hour, time.minute),
        amount: amount,
        description: _description.text.trim(),
        customFields: _customFieldValues,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShopDialogFrame(
      title: widget.editing
          ? 'تعديل التحويل بين الخزائن'
          : 'تحويل من خزينة لأخرى',
      width: 500,
      actions: [
        shopDialogButton(label: 'حفظ', primary: true, onTap: _submit),
        shopDialogButton(
          label: 'إلغاء',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      shopFieldLabel('من خزينة'),
                      _dialogTreasuryDropdown(
                        treasuries: widget.treasuries,
                        value: _sourceId,
                        onChanged: (value) => setState(() {
                          _sourceId = value;
                          if (_destinationId == value) {
                            _destinationId = widget.treasuries
                                .firstWhere((t) => t.id != value)
                                .id;
                          }
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: HoverBuilder(
                    builder: (context, hovered) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _swap,
                      child: Container(
                        width: 30,
                        height: 28,
                        color: hovered ? kHoverYellow : _kSoft,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.swap_horiz,
                          size: 17,
                          color: _kInk,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      shopFieldLabel('إلى خزينة'),
                      _dialogTreasuryDropdown(
                        treasuries: widget.treasuries,
                        value: _destinationId,
                        onChanged: (value) => setState(() {
                          _destinationId = value;
                          if (_sourceId == value) {
                            _sourceId = widget.treasuries
                                .firstWhere((t) => t.id != value)
                                .id;
                          }
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      shopFieldLabel('التاريخ'),
                      _dialogDateField(context, _date),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      shopFieldLabel('الوقت'),
                      _dialogTimeField(context, _time),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            shopFieldLabel('المبلغ'),
            _dialogTextField(_amount, number: true),
            const SizedBox(height: 9),
            shopFieldLabel('البيان'),
            _dialogTextField(_description),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final values = await showDocumentCustomFieldsDialog(
                    context,
                    initialValues: _customFieldValues,
                  );
                  if (mounted && values != null) {
                    setState(() => _customFieldValues = values);
                  }
                },
                icon: const Icon(Icons.tune, size: 16),
                label: Text('حقول إضافية (${_customFieldValues.length})'),
              ),
            ),
            _dialogError(_error),
            const SizedBox(height: 4),
            const Text(
              'التحويل ينقص رصيد الخزينة المصدر ويزيد رصيد الوجهة، '
              'ولا يُحسب إيراداً أو مصروفاً للشركة.',
              style: TextStyle(fontSize: 10.5, color: Color(0xFF777777)),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Daily entry dialog.
// -----------------------------------------------------------------------------
class TreasuryDailyEntryDialog extends StatelessWidget {
  const TreasuryDailyEntryDialog({
    super.key,
    required this.day,
    required this.report,
    required this.treasuries,
    required this.treasuryFilter,
  });

  final DateTime day;
  final TreasuryReport report;
  final List<TreasuryAccount> treasuries;
  final int treasuryFilter;

  @override
  Widget build(BuildContext context) {
    final rows = report.movements
        .where((movement) => !movement.isSynthetic)
        .toList();
    final treasuryName = treasuryFilter == 0
        ? 'كل الخزائن'
        : treasuries
              .firstWhere(
                (treasury) => treasury.id == treasuryFilter,
                orElse: () => const TreasuryAccount(
                  id: 0,
                  name: 'الخزينة',
                  openingBalance: 0,
                  isActive: true,
                ),
              )
              .name;
    return ShopDialogFrame(
      title: 'إدخال حركة الخزينة اليومية — ${_dateText(day)}',
      width: 700,
      actions: [
        shopDialogButton(
          label: 'قبض جديد',
          primary: true,
          onTap: () => Navigator.of(context).pop('receive'),
        ),
        shopDialogButton(
          label: 'صرف جديد',
          color: _kYellow,
          onTap: () => Navigator.of(context).pop('expense'),
        ),
        shopDialogButton(
          label: 'إغلاق',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: SizedBox(
        width: 676,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              textDirection: TextDirection.rtl,
              children: [
                _dayCard('رصيد افتتاحي', report.previousBalance),
                const SizedBox(width: 5),
                _dayCard('وارد اليوم', report.incoming, color: _kPanelGreen),
                const SizedBox(width: 5),
                _dayCard('منصرف اليوم', report.outgoing, color: _kRed),
                const SizedBox(width: 5),
                _dayCard('رصيد الإغلاق', report.currentBalance),
                const Spacer(),
                Text(
                  treasuryName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(height: 24, color: _kGreen),
            Container(
              height: 24,
              color: _kSoft,
              child: Row(
                textDirection: TextDirection.rtl,
                children: const [
                  _DayHeader('الوقت', 2),
                  _DayHeader('الحركة', 2),
                  _DayHeader('البيان', 5),
                  _DayHeader('وارد', 2),
                  _DayHeader('منصرف', 2),
                  _DayHeader('الرصيد', 2),
                ],
              ),
            ),
            SizedBox(
              height: 260,
              child: rows.isEmpty
                  ? Container(
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: const Text(
                        'لا توجد حركات مسجلة في هذا اليوم.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888888),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) =>
                          Container(height: 1, color: const Color(0xFFEDEDED)),
                      itemBuilder: (context, index) {
                        final movement = rows[index];
                        return Container(
                          height: 27,
                          color: index.isOdd
                              ? const Color(0xFFFAFAFA)
                              : Colors.white,
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              _DayCell(_timeText(movement.date), 2),
                              _DayCell(movement.typeLabel, 2),
                              _DayCell(
                                movement.descriptionLabel,
                                5,
                                alignRight: true,
                              ),
                              _DayCell(
                                movement.displayIncoming == 0
                                    ? ''
                                    : _money(movement.displayIncoming),
                                2,
                              ),
                              _DayCell(
                                movement.displayOutgoing == 0
                                    ? ''
                                    : _money(movement.displayOutgoing),
                                2,
                              ),
                              _DayCell(_money(movement.balanceAfter), 2),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Container(
              height: 26,
              color: _kField,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  const _DayCell('', 2),
                  const _DayCell('', 2),
                  const _DayCell('الإجمالي', 5, bold: true, alignRight: true),
                  _DayCell(_money(report.incoming), 2, bold: true),
                  _DayCell(_money(report.outgoing), 2, bold: true),
                  _DayCell(_money(report.currentBalance), 2, bold: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCard(String label, int value, {Color? color}) {
    return Container(
      width: 145,
      height: 44,
      color: color ?? _kField,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              color: color == null ? const Color(0xFF666666) : Colors.white70,
            ),
          ),
          Text(
            _money(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color == null ? _kInk : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label, this.flex);

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: _kInk,
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell(
    this.text,
    this.flex, {
    this.bold = false,
    this.alignRight = false,
  });

  final String text;
  final int flex;
  final bool bold;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Align(
          alignment: alignRight ? Alignment.centerRight : Alignment.center,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: _kInk,
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Expense / receipt analysis dialog.
// -----------------------------------------------------------------------------
class TreasuryAnalysisDialog extends StatelessWidget {
  const TreasuryAnalysisDialog({
    super.key,
    required this.title,
    required this.expenses,
    required this.rows,
    required this.filters,
    required this.treasuryName,
  });

  final String title;
  final bool expenses;
  final List<TreasuryAnalysisRow> rows;
  final TreasuryFilters filters;
  final String treasuryName;

  int get _total => rows.fold<int>(0, (sum, row) => sum + row.amount);

  @override
  Widget build(BuildContext context) {
    return ShopDialogFrame(
      title: title,
      width: 680,
      actions: [
        shopDialogButton(
          label: 'طباعة',
          color: _kYellow,
          onTap: () => _print(context),
        ),
        shopDialogButton(
          label: 'إغلاق',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: SizedBox(
        width: 656,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 210,
                  height: 48,
                  color: expenses ? _kRed : _kPanelGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expenses ? 'إجمالي المصروفات' : 'إجمالي المقبوضات',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        _money(_total),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        treasuryName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'من ${_dateText(filters.from)} ${_timeText(filters.from)} '
                        'إلى ${_dateText(filters.to)} ${_timeText(filters.to)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rows.fold<int>(0, (sum, row) => sum + row.count)} حركة',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(height: 24, color: _kGreen),
            Container(
              height: 24,
              color: _kSoft,
              child: Row(
                textDirection: TextDirection.rtl,
                children: const [
                  _AnalysisHeader('التصنيف', 5, alignRight: true),
                  _AnalysisHeader('عدد الحركات', 2),
                  _AnalysisHeader('المبلغ', 3),
                  _AnalysisHeader('النسبة', 4),
                ],
              ),
            ),
            SizedBox(
              height: 300,
              child: rows.isEmpty
                  ? Container(
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: Text(
                        expenses
                            ? 'لا توجد مصروفات في الفترة المحددة.'
                            : 'لا توجد مقبوضات في الفترة المحددة.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888888),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) =>
                          Container(height: 1, color: const Color(0xFFEDEDED)),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return Container(
                          height: 30,
                          color: index.isOdd
                              ? const Color(0xFFFAFAFA)
                              : Colors.white,
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              _AnalysisCell(row.label, 5, alignRight: true),
                              _AnalysisCell('${row.count}', 2),
                              _AnalysisCell(_money(row.amount), 3),
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  child: Row(
                                    textDirection: TextDirection.rtl,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 8,
                                          color: const Color(0xFFE8E8E8),
                                          alignment: Alignment.centerRight,
                                          child: FractionallySizedBox(
                                            widthFactor: row.share.clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            child: Container(
                                              color: expenses
                                                  ? _kRed
                                                  : _kPanelGreen,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      SizedBox(
                                        width: 40,
                                        child: Text(
                                          '${(row.share * 100).toStringAsFixed(1)}%',
                                          textAlign: TextAlign.left,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: _kInk,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Container(
              height: 28,
              color: _kField,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  const _AnalysisCell(
                    'الإجمالي',
                    5,
                    bold: true,
                    alignRight: true,
                  ),
                  _AnalysisCell(
                    '${rows.fold<int>(0, (sum, row) => sum + row.count)}',
                    2,
                    bold: true,
                  ),
                  _AnalysisCell(_money(_total), 3, bold: true),
                  _AnalysisCell('100%', 4, bold: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _print(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => PrintPreviewDialog(
        title: title,
        columns: const ['التصنيف', 'عدد الحركات', 'المبلغ', 'النسبة'],
        rows: [
          for (final row in rows)
            [
              row.label,
              '${row.count}',
              _money(row.amount),
              '${(row.share * 100).toStringAsFixed(1)}%',
            ],
          [
            'الإجمالي',
            '${rows.fold<int>(0, (sum, row) => sum + row.count)}',
            _money(_total),
            '100%',
          ],
        ],
      ),
    );
  }
}

class _AnalysisHeader extends StatelessWidget {
  const _AnalysisHeader(this.label, this.flex, {this.alignRight = false});

  final String label;
  final int flex;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Align(
          alignment: alignRight ? Alignment.centerRight : Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalysisCell extends StatelessWidget {
  const _AnalysisCell(
    this.text,
    this.flex, {
    this.bold = false,
    this.alignRight = false,
  });

  final String text;
  final int flex;
  final bool bold;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Align(
          alignment: alignRight ? Alignment.centerRight : Alignment.center,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: _kInk,
            ),
          ),
        ),
      ),
    );
  }
}
