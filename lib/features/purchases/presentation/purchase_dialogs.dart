part of 'purchases_page.dart';

// -----------------------------------------------------------------------------
// Account picker.
// -----------------------------------------------------------------------------
class _AccountPickerDialog extends StatefulWidget {
  const _AccountPickerDialog({required this.accounts, this.selected});

  final List<PurchaseAccount> accounts;
  final PurchaseAccount? selected;

  @override
  State<_AccountPickerDialog> createState() => _AccountPickerDialogState();
}

class _AccountPickerDialogState extends State<_AccountPickerDialog> {
  final _query = TextEditingController();
  late List<PurchaseAccount> _visible = widget.accounts;

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
      title: 'اختيار حساب المورد',
      width: 480,
      actions: [
        shopDialogButton(
          label: 'بدون حساب',
          onTap: () => Navigator.of(
            context,
          ).pop(const PurchaseAccount(id: 0, name: '', balance: 0, type: '')),
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
class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.accountId,
    required this.total,
    required this.remaining,
    required this.accountName,
    required this.initialMethod,
    required this.treasury,
  });

  final int accountId;
  final int total;
  final int remaining;
  final String accountName;
  final String initialMethod;
  final String treasury;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: '${widget.remaining}',
  );
  late String _method = widget.initialMethod;
  late List<Map<String, Object?>> _methods;

  @override
  void initState() {
    super.initState();
    _methods = DatabaseService().database.db
        .select(
          'SELECT code,name FROM payment_methods WHERE is_active=1 ORDER BY sort_order,id',
        )
        .map((row) => Map<String, Object?>.from(row))
        .toList();
    if (_methods.isEmpty) {
      _methods = [
        {'code': 'cash', 'name': 'نقدي'},
      ];
    }
    if (!_methods.any((method) => method['code'] == _method)) {
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
      _error('أدخل مبلغ سداد صحيحاً أكبر من صفر.');
      return;
    }
    if (value > widget.remaining) {
      _error('المبلغ أكبر من المتبقي (${widget.remaining}).');
      return;
    }
    Navigator.of(context).pop(
      PurchasePaymentInput(
        accountId: widget.accountId,
        amount: value,
        method: _method,
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
      title: 'سداد فاتورة الشراء',
      width: 440,
      actions: [
        shopDialogButton(label: 'تأكيد السداد', primary: true, onTap: _submit),
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
          shopFieldLabel('قيمة السداد'),
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
          Text(
            'الخزينة: ${widget.treasury}',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(String label, String value) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
        ],
      ),
    );
  }
}
