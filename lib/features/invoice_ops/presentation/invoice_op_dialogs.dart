part of 'invoice_op_page.dart';

// -----------------------------------------------------------------------------
// Account picker.
// -----------------------------------------------------------------------------
class _InvoiceAccountPickerDialog extends StatefulWidget {
  const _InvoiceAccountPickerDialog({
    required this.accounts,
    required this.title,
    this.selected,
  });

  final List<InvoiceAccount> accounts;
  final String title;
  final InvoiceAccount? selected;

  @override
  State<_InvoiceAccountPickerDialog> createState() =>
      _InvoiceAccountPickerDialogState();
}

class _InvoiceAccountPickerDialogState
    extends State<_InvoiceAccountPickerDialog> {
  final _query = TextEditingController();
  late List<InvoiceAccount> _visible = widget.accounts;

  @override
  void initState() {
    super.initState();
    _query.addListener(_filter);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _filter() {
    final key = _query.text.trim().toLowerCase();
    setState(() {
      _visible = key.isEmpty
          ? widget.accounts
          : widget.accounts
                .where((a) => a.name.toLowerCase().contains(key))
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShopDialogFrame(
      title: widget.title,
      width: 480,
      actions: [
        shopDialogButton(
          label: 'بدون حساب',
          onTap: () => Navigator.of(context)
              .pop(const InvoiceAccount(id: 0, name: '', balance: 0, type: '')),
        ),
        shopDialogButton(
          label: 'إغلاق',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: SizedBox(
        height: 370,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            shopTextBox(_query),
            const SizedBox(height: 8),
            Expanded(
              child: _visible.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد حسابات مطابقة.',
                        style: TextStyle(fontSize: 12.5, color: _kInk),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCCCCCC)),
                      ),
                      child: ListView.builder(
                        itemExtent: 30,
                        itemCount: _visible.length,
                        itemBuilder: (context, index) {
                          final account = _visible[index];
                          final active = widget.selected?.id == account.id;
                          return HoverBuilder(
                            builder: (context, hovered) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.of(context).pop(account),
                              child: Container(
                                color: hovered
                                    ? kHoverYellow
                                    : (active
                                          ? _kRowSelected
                                          : (index.isEven
                                                ? Colors.white
                                                : const Color(0xFFF2F2F2))),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Row(
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        account.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: _kInk,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      account.type.isEmpty
                                          ? '${account.balance}'
                                          : '${account.type} · ${account.balance}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF666666),
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
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Payment dialog (F11).
// -----------------------------------------------------------------------------
class _InvoicePaymentDialog extends StatefulWidget {
  const _InvoicePaymentDialog({
    required this.accountId,
    required this.total,
    required this.remaining,
    required this.accountName,
    required this.initialMethod,
    required this.treasuries,
    required this.selectedTreasuryId,
    required this.title,
    required this.amountLabel,
    required this.confirmLabel,
  });

  final int accountId;
  final int total;
  final int remaining;
  final String accountName;
  final String initialMethod;
  final List<InvoiceTreasury> treasuries;
  final int? selectedTreasuryId;
  final String title;
  final String amountLabel;
  final String confirmLabel;

  @override
  State<_InvoicePaymentDialog> createState() => _InvoicePaymentDialogState();
}

class _InvoicePaymentDialogState extends State<_InvoicePaymentDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: '${widget.remaining}',
  );
  late String _method = widget.initialMethod;
  late final List<Map<String, Object?>> _methods;
  late int? _treasuryId =
      widget.selectedTreasuryId ??
      (widget.treasuries.isEmpty ? null : widget.treasuries.first.id);

  @override
  void initState() {
    super.initState();
    _methods = DatabaseService().database.db
        .select(
          'SELECT code,name FROM payment_methods WHERE is_active=1 ORDER BY sort_order,id',
        )
        .map((row) => Map<String, Object?>.from(row))
        .toList();
    if (_methods.isNotEmpty &&
        !_methods.any((method) => method['code'] == _method)) {
      _method = _methods.first['code'] as String;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_amount.text.trim());
    if (value == null || value <= 0) {
      _error('أدخل مبلغاً صحيحاً أكبر من صفر.');
      return;
    }
    if (value > widget.remaining) {
      _error('المبلغ أكبر من المتبقي (${widget.remaining}).');
      return;
    }
    Navigator.of(context).pop(
      InvoicePaymentInput(
        accountId: widget.accountId,
        amount: value,
        method: _method,
        treasuryId: _treasuryId,
      ),
    );
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12.5)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShopDialogFrame(
      title: widget.title,
      width: 440,
      actions: [
        shopDialogButton(
          label: widget.confirmLabel,
          primary: true,
          onTap: _submit,
        ),
        shopDialogButton(
          label: 'إلغاء',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(child: _summaryBox('الحساب', widget.accountName)),
              const SizedBox(width: 8),
              Expanded(child: _summaryBox('الإجمالي', '${widget.total}')),
              const SizedBox(width: 8),
              Expanded(child: _summaryBox('المتبقي', '${widget.remaining}')),
            ],
          ),
          const SizedBox(height: 12),
          shopFieldLabel(widget.amountLabel),
          shopTextBox(_amount, align: TextAlign.center),
          const SizedBox(height: 12),
          shopFieldLabel('طريقة السداد'),
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFB8B8B8)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _method,
                isExpanded: true,
                isDense: true,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 12.5, color: _kInk),
                items: _methods
                    .map(
                      (method) => DropdownMenuItem<String>(
                        value: method['code'] as String,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            method['name'] as String,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: _kInk,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _method = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('الخزينة', style: const TextStyle(fontSize: 12, color: _kInk)),
          const SizedBox(height: 5),
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFB8B8B8)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: widget.treasuries.any((item) => item.id == _treasuryId)
                    ? _treasuryId
                    : null,
                hint: const Text('اختار الخزينة'),
                isExpanded: true,
                isDense: true,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 12.5, color: _kInk),
                items: widget.treasuries
                    .map(
                      (item) => DropdownMenuItem<int>(
                        value: item.id,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(item.name),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _treasuryId = value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(String label, String value) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF666666)),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Original invoice picker used by the two return screens.
// -----------------------------------------------------------------------------
class _InvoicePickerDialog extends StatefulWidget {
  const _InvoicePickerDialog({required this.title, required this.loader});

  final String title;
  final Future<List<OriginalInvoiceSummary>> Function(String term) loader;

  @override
  State<_InvoicePickerDialog> createState() => _InvoicePickerDialogState();
}

class _InvoicePickerDialogState extends State<_InvoicePickerDialog> {
  final _query = TextEditingController();
  List<OriginalInvoiceSummary> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _query.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _query.removeListener(_load);
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.loader(_query.text);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShopDialogFrame(
      title: widget.title,
      width: 620,
      actions: [
        shopDialogButton(
          label: 'إغلاق',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            shopTextBox(_query),
            const SizedBox(height: 8),
            Container(
              height: 26,
              color: _kSoft,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: const Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: Text(
                      'الرقم',
                      style: TextStyle(fontSize: 11, color: _kInk),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      'التاريخ',
                      style: TextStyle(fontSize: 11, color: _kInk),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: Text(
                      'الحساب',
                      style: TextStyle(fontSize: 11, color: _kInk),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      'الإجمالي',
                      style: TextStyle(fontSize: 11, color: _kInk),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: _loading
                  ? const Center(
                      child: Text(
                        'جارٍ التحميل...',
                        style: TextStyle(fontSize: 12),
                      ),
                    )
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontSize: 12, color: _kInk),
                      ),
                    )
                  : _rows.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد فواتير مطابقة.',
                        style: TextStyle(fontSize: 12.5, color: _kInk),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCCCCCC)),
                      ),
                      child: ListView.builder(
                        itemExtent: 30,
                        itemCount: _rows.length,
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          return HoverBuilder(
                            builder: (context, hovered) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.of(context).pop(row),
                              child: Container(
                                color: hovered
                                    ? kHoverYellow
                                    : (index.isEven
                                          ? Colors.white
                                          : const Color(0xFFF2F2F2)),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Row(
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        row.number,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _kInk,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        row.date.length >= 10
                                            ? row.date.substring(0, 10)
                                            : row.date,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF666666),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 150,
                                      child: Text(
                                        row.partyName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: _kInk,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        '${row.total}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: _kInk,
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
            ),
          ],
        ),
      ),
    );
  }
}
