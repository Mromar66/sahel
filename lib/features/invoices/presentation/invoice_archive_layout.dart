part of 'invoice_archive_page.dart';

const TextStyle _kFilterLabelStyle = TextStyle(
  fontSize: 10.5,
  color: _kInk,
  height: 1.1,
);
const TextStyle _kFilterValueStyle = TextStyle(
  fontSize: 10.5,
  color: _kInk,
  height: 1.1,
);

extension _InvoiceArchiveLayout on _InvoiceArchivePageState {
  // ---------------------------------------------------------------------------
  // Toolbar: title, hint, cancel.
  // ---------------------------------------------------------------------------
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      child: SizedBox(
        height: 32,
        child: Stack(
          children: [
            Positioned(
              right: 6,
              top: 2,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Text(
                    'الفواتير',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _kGreen,
                      height: 1.05,
                    ),
                  ),
                  if (_loading) ...[
                    const SizedBox(width: 10),
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kGreen,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 2,
              child: HoverBuilder(
                builder: (context, hovered) => Tooltip(
                  message: 'إغلاق الأرشيف (Esc)',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: Container(
                      width: 86,
                      height: 24,
                      decoration: BoxDecoration(
                        color: hovered ? kHoverYellow : _kSoft,
                        border: Border.all(color: const Color(0xFFD7D7D7)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        textDirection: TextDirection.rtl,
                        children: const [
                          Text(
                            'إلغاء',
                            style: TextStyle(fontSize: 11.5, color: _kInk),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.power_settings_new,
                            size: 14,
                            color: Color(0xFF2F2F2F),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: IgnorePointer(
                  child: Text(
                    'اختر نوع المستند ثم حدد الفلاتر واضغط عرض الفواتير أو عرض الأصناف',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF6B6B6B),
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Document tabs.
  // ---------------------------------------------------------------------------
  Widget _buildDocTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Container(
        height: 28,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFB7CFF5))),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (
              var index = 0;
              index < ArchiveDocType.values.length;
              index++
            ) ...[
              if (index > 0) const SizedBox(width: 2),
              Expanded(child: _docTab(ArchiveDocType.values[index])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _docTab(ArchiveDocType type) {
    final active = _type == type;
    return HoverBuilder(
      builder: (context, hovered) => Tooltip(
        message: 'عرض مستندات ${type.label}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _setType(type),
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: active
                  ? _kGreen
                  : hovered
                  ? const Color(0xFFE6F6EC)
                  : const Color(0xFFF2F2F2),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
              border: Border(
                top: BorderSide(
                  color: active
                      ? const Color(0xFF23A846)
                      : const Color(0xFFE1E1E1),
                  width: 2,
                ),
              ),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              type.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.2,
                color: active ? Colors.white : _kInk,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                height: 1.05,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search-mode tabs.
  // ---------------------------------------------------------------------------
  Widget _buildModeTabs() {
    return Padding(
      padding: const EdgeInsets.only(right: 22, top: 2),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          _modeTab(ArchiveSearchMode.general, 'بحث عام'),
          _modeTab(ArchiveSearchMode.advanced, 'بحث متقدم'),
        ],
      ),
    );
  }

  Widget _modeTab(ArchiveSearchMode mode, String label) {
    final active = _mode == mode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _setMode(mode),
      child: Container(
        width: 132,
        height: 24,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0059E8) : const Color(0xFFF7F7F7),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
          border: Border(
            top: BorderSide(
              color: active ? const Color(0xFF004CC7) : const Color(0xFFE1E1E1),
              width: 2,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: active ? Colors.white : _kInk,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filters.
  // ---------------------------------------------------------------------------
  Widget _buildFilters() {
    final advanced = _mode == ArchiveSearchMode.advanced;
    final rows = <List<Widget>>[];

    rows.add([
      _todayGroup(),
      const SizedBox(width: 6),
      _periodCombo(),
      const SizedBox(width: 10),
      _dateTimeGroup(isFrom: false),
      const SizedBox(width: 10),
      _dateTimeGroup(isFrom: true),
      const Spacer(),
      _filterGroup(
        label: 'رقم فاتورة / المرجع',
        labelWidth: 92,
        field: _plainField(
          _invoiceNumber,
          width: 104,
          onChanged: (value) =>
              _filters = _filters.copyWith(invoiceNumber: value),
        ),
        clear: _clearX('مسح رقم الفاتورة / المرجع', () {
          _invoiceNumber.clear();
          _updateFilters(_filters.copyWith(invoiceNumber: ''));
        }),
      ),
      const SizedBox(width: 150),
    ]);

    final typeRow = <Widget>[];
    if (_type.hasWarehouse) {
      typeRow.add(
        _filterGroup(
          label: 'المخزن',
          labelWidth: 46,
          field: _warehouseCombo(),
          clear: _clearX('مسح المخزن', () {
            _updateFilters(_filters.copyWith(warehouseId: null));
          }),
        ),
      );
    }
    if (_type.hasAccount) {
      if (typeRow.isNotEmpty) typeRow.add(const SizedBox(width: 14));
      typeRow.add(
        _filterGroup(
          label: 'الحساب',
          labelWidth: 48,
          field: _accountCombo(),
          clear: _clearX('مسح الحساب', () {
            _updateFilters(_filters.copyWith(accountId: null));
          }),
        ),
      );
      typeRow.add(const SizedBox(width: 14));
      typeRow.add(
        _filterGroup(
          label: 'تصنيف الحساب',
          labelWidth: 82,
          field: _accountTypeCombo(),
          clear: _clearX('مسح تصنيف الحساب', () {
            _updateFilters(_filters.copyWith(accountType: ''));
          }),
        ),
      );
    }
    if (_type.hasDocumentStatus) {
      if (typeRow.isNotEmpty) typeRow.add(const SizedBox(width: 14));
      typeRow.add(
        _filterGroup(
          label: _type.isQuotation ? 'حالة العرض' : 'حالة المستند',
          labelWidth: 76,
          field: _documentStatusCombo(),
        ),
      );
    }
    if (typeRow.isNotEmpty) {
      typeRow.add(const Spacer());
      rows.add(typeRow);
    }

    final paymentRow = <Widget>[];
    if (_type.hasPaymentMethod) {
      paymentRow.add(
        _filterGroup(
          label: 'طريقة السداد',
          labelWidth: 82,
          field: _paymentRadios(),
        ),
      );
    }
    if (_type.hasTreasury) {
      if (paymentRow.isNotEmpty) paymentRow.add(const SizedBox(width: 18));
      paymentRow.add(
        _filterGroup(
          label: 'الخزينة',
          labelWidth: 50,
          field: _treasuryCombo(),
          clear: _clearX('مسح الخزينة', () {
            _updateFilters(_filters.copyWith(treasuryId: null));
          }),
        ),
      );
    }
    if (_type.hasPaymentStatus) {
      if (paymentRow.isNotEmpty) paymentRow.add(const SizedBox(width: 14));
      paymentRow.add(
        _filterGroup(
          label: 'حالة السداد',
          labelWidth: 72,
          field: _paymentStatusCombo(),
        ),
      );
    }
    if (paymentRow.isNotEmpty) {
      paymentRow.add(const Spacer());
      rows.add(paymentRow);
    }

    if (advanced) {
      rows.add([
        _filterGroup(label: 'المبلغ', labelWidth: 42, field: _amountRange()),
        const SizedBox(width: 14),
        _filterGroup(
          label: 'رقم المستند',
          labelWidth: 70,
          field: _plainField(
            _exactNumber,
            width: 104,
            onChanged: (value) =>
                _filters = _filters.copyWith(exactNumber: value),
          ),
          clear: _clearX('مسح الرقم الكامل', () {
            _exactNumber.clear();
            _updateFilters(_filters.copyWith(exactNumber: ''));
          }),
        ),
        if (_type.hasAccount) ...[
          const SizedBox(width: 14),
          _filterGroup(
            label: 'اسم الجهة',
            labelWidth: 62,
            field: _plainField(
              _partyName,
              width: 116,
              onChanged: (value) =>
                  _filters = _filters.copyWith(partyName: value),
            ),
            clear: _clearX('مسح اسم الجهة', () {
              _partyName.clear();
              _updateFilters(_filters.copyWith(partyName: ''));
            }),
          ),
        ],
        const SizedBox(width: 14),
        _filterGroup(
          label: 'ملاحظات',
          labelWidth: 46,
          field: _plainField(
            _notes,
            width: 150,
            onChanged: (value) => _filters = _filters.copyWith(notes: value),
          ),
          clear: _clearX('مسح الملاحظات', () {
            _notes.clear();
            _updateFilters(_filters.copyWith(notes: ''));
          }),
        ),
        const Spacer(),
      ]);
      if (_type.hasItems) {
        rows.add([
          _filterGroup(
            label: 'تصنيف الصنف',
            labelWidth: 76,
            field: _categoryCombo(),
          ),
          const SizedBox(width: 12),
          _filterGroup(
            label: 'الصنف',
            labelWidth: 40,
            field: _plainField(
              _itemName,
              width: 104,
              onChanged: (value) =>
                  _filters = _filters.copyWith(itemName: value),
            ),
            clear: _clearX('مسح اسم الصنف', () {
              _itemName.clear();
              _updateFilters(_filters.copyWith(itemName: ''));
            }),
          ),
          const SizedBox(width: 12),
          _filterGroup(
            label: 'الكود',
            labelWidth: 38,
            field: _plainField(
              _itemCode,
              width: 88,
              onChanged: (value) =>
                  _filters = _filters.copyWith(itemCode: value),
            ),
            clear: _clearX('مسح كود الصنف', () {
              _itemCode.clear();
              _updateFilters(_filters.copyWith(itemCode: ''));
            }),
          ),
          const SizedBox(width: 12),
          _filterGroup(
            label: 'الباركود',
            labelWidth: 50,
            field: _plainField(
              _barcode,
              width: 96,
              onChanged: (value) =>
                  _filters = _filters.copyWith(barcode: value),
            ),
            clear: _clearX('مسح الباركود', () {
              _barcode.clear();
              _updateFilters(_filters.copyWith(barcode: ''));
            }),
          ),
          const Spacer(),
        ]);
      }
    }

    return SizedBox(
      height: rows.length * 27 + 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              _filterRow(rows[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterRow(List<Widget> children) {
    return SizedBox(
      height: 21,
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _filterGroup({
    required String label,
    required Widget field,
    Widget? clear,
    double labelWidth = 78,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: _kFilterLabelStyle,
          ),
        ),
        field,
        if (clear != null) ...[const SizedBox(width: 2), clear],
      ],
    );
  }

  Widget _plainField(
    TextEditingController controller, {
    required double width,
    ValueChanged<String>? onChanged,
    bool readOnly = false,
    VoidCallback? onTap,
    String hint = '',
  }) {
    return Container(
      width: width,
      height: 21,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kBorder),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 5, left: 4),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        onSubmitted: (_) => _loaded ? _search() : null,
        textAlign: TextAlign.right,
        style: _kFilterValueStyle,
        decoration: InputDecoration(
          isCollapsed: true,
          filled: false,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF9A9A9A)),
          contentPadding: const EdgeInsets.only(top: 2),
          constraints: const BoxConstraints(minHeight: 0),
        ),
      ),
    );
  }

  Widget _clearX(String tooltip, VoidCallback onTap) {
    return HoverBuilder(
      builder: (context, hovered) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 22,
            height: 21,
            color: hovered ? const Color(0xFFDCDCDC) : _kSoft,
            alignment: Alignment.center,
            child: const Icon(Icons.close, size: 13, color: Color(0xFF8C8C8C)),
          ),
        ),
      ),
    );
  }

  Widget _smallCheckbox(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: value ? ShopColors.focusBlue : Colors.white,
          border: Border.all(
            color: value ? ShopColors.focusBlue : const Color(0xFF8C8C8C),
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: value
            ? const Icon(Icons.check, size: 11, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _todayGroup() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [
        const Text('اليوم', style: _kFilterLabelStyle),
        const SizedBox(width: 5),
        _smallCheckbox(_today, _toggleToday),
      ],
    );
  }

  Widget _periodCombo() {
    const options = <String, String>{
      'today': 'اليوم',
      'week': 'الأسبوع',
      'month': 'الشهر',
      'year': 'السنة',
      '': 'الكل',
    };
    final value = options.containsKey(_period) ? _period : '';
    return Container(
      width: 62,
      height: 21,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 12,
            color: Color(0xFF6B6B6B),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.zero,
          padding: EdgeInsets.zero,
          style: _kFilterValueStyle,
          items: [
            for (final entry in options.entries)
              DropdownMenuItem<String>(
                value: entry.key,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    entry.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _kFilterValueStyle,
                  ),
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) _applyPeriod(value);
          },
        ),
      ),
    );
  }

  Widget _dateTimeGroup({required bool isFrom}) {
    final dateController = isFrom ? _fromDate : _toDate;
    final timeController = isFrom ? _fromTime : _toTime;
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [
        SizedBox(
          width: 50,
          child: Text(
            isFrom ? 'من التاريخ' : 'إلى التاريخ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: _kFilterLabelStyle,
          ),
        ),
        _pickerField(
          controller: dateController,
          width: 72,
          icon: Icons.calendar_today_outlined,
          tooltip: isFrom ? 'من تاريخ' : 'إلى تاريخ',
          onTap: () => _pickDate(isFrom),
        ),
        const SizedBox(width: 2),
        _clearX('مسح ${isFrom ? 'تاريخ البداية' : 'تاريخ النهاية'}', () {
          _clearDate(isFrom);
        }),
        const SizedBox(width: 2),
        _pickerField(
          controller: timeController,
          width: 62,
          icon: Icons.access_time,
          tooltip: isFrom ? 'من وقت' : 'إلى وقت',
          onTap: () => _pickTime(isFrom),
        ),
        const SizedBox(width: 2),
        _clearX('مسح ${isFrom ? 'وقت البداية' : 'وقت النهاية'}', () {
          _clearTime(isFrom);
        }),
      ],
    );
  }

  Widget _pickerField({
    required TextEditingController controller,
    required double width,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      width: width,
      height: 21,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: true,
              onTap: onTap,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: _kFilterValueStyle.copyWith(fontSize: 9.5),
              decoration: const InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(top: 2),
                constraints: BoxConstraints(minHeight: 0),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Tooltip(
              message: tooltip,
              child: Container(
                width: 16,
                height: 21,
                color: const Color(0xFFF0F0F0),
                alignment: Alignment.center,
                child: Icon(icon, size: 11, color: const Color(0xFF8A8A8A)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warehouseCombo() {
    return _intCombo(
      width: 118,
      value: _filters.warehouseId,
      options: _warehouses,
      emptyMessage: 'لا توجد مخازن مسجلة.',
      unavailableMessage: _type.hasWarehouse
          ? null
          : 'فلتر المخزن غير متاح لهذا النوع: المستند لا يسجل مخزناً.',
      onChanged: (value) =>
          _updateFilters(_filters.copyWith(warehouseId: value)),
    );
  }

  Widget _treasuryCombo() {
    return _intCombo(
      width: 108,
      value: _filters.treasuryId,
      options: _treasuries,
      emptyMessage: 'لا توجد خزائن مسجلة.',
      unavailableMessage: _type.hasTreasury
          ? null
          : 'فلتر الخزينة غير متاح لهذا النوع: المستند لا يسجل حركة خزينة.',
      onChanged: (value) =>
          _updateFilters(_filters.copyWith(treasuryId: value)),
    );
  }

  Widget _categoryCombo() {
    return _intCombo(
      width: 108,
      value: _filters.categoryId,
      options: _categories,
      emptyMessage: 'لا توجد تصنيفات مسجلة.',
      unavailableMessage: _type.hasItems
          ? null
          : 'البحث بالتصنيف غير متاح لهذا النوع: المستند لا يحتوي سطور أصناف.',
      onChanged: (value) =>
          _updateFilters(_filters.copyWith(categoryId: value)),
    );
  }

  Widget _intCombo({
    required double width,
    required int? value,
    required List<ArchiveOption> options,
    required ValueChanged<int?> onChanged,
    required String emptyMessage,
    String? unavailableMessage,
  }) {
    final hasValue = options.any((option) => option.id == value);
    final box = Container(
      width: width,
      height: 21,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: hasValue ? value : null,
          isExpanded: true,
          isDense: true,
          hint: const SizedBox.shrink(),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 12,
            color: Color(0xFF6B6B6B),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.zero,
          padding: EdgeInsets.zero,
          style: _kFilterValueStyle,
          items: [
            for (final option in options)
              DropdownMenuItem<int>(
                value: option.id,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    option.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _kFilterValueStyle,
                  ),
                ),
              ),
          ],
          onChanged: options.isEmpty
              ? null
              : (value) {
                  if (unavailableMessage != null) {
                    _toast(unavailableMessage);
                    return;
                  }
                  onChanged(value);
                },
        ),
      ),
    );
    if (unavailableMessage != null) {
      return Tooltip(message: unavailableMessage, child: box);
    }
    if (options.isNotEmpty) {
      return Tooltip(message: 'اختيار من القائمة', child: box);
    }
    return Tooltip(
      message: emptyMessage,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toast(emptyMessage),
        child: box,
      ),
    );
  }

  Widget _accountCombo() {
    final name = _optionName(_accounts, _filters.accountId);
    return PopupMenuButton<int>(
      tooltip: _type.hasAccount
          ? 'اختيار الحساب'
          : 'فلتر الحساب غير متاح لهذا النوع',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 2),
      color: Colors.white,
      onSelected: (value) {
        if (!_type.hasAccount) {
          _toast('فلتر الحساب غير متاح لهذا النوع: المستند لا يسجل حساباً.');
          return;
        }
        _updateFilters(_filters.copyWith(accountId: value == 0 ? null : value));
      },
      itemBuilder: (context) => [
        const PopupMenuItem<int>(
          value: 0,
          height: 32,
          child: Text(
            'كل الحسابات',
            style: TextStyle(fontSize: 11, color: _kInk),
          ),
        ),
        for (final option in _accounts)
          PopupMenuItem<int>(
            value: option.id,
            height: 32,
            child: Text(
              option.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: _kInk),
            ),
          ),
      ],
      child: Container(
        width: 118,
        height: 21,
        padding: const EdgeInsets.only(right: 5, left: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kBorder),
        ),
        alignment: Alignment.centerRight,
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _kFilterValueStyle,
        ),
      ),
    );
  }

  Widget _accountTypeCombo() {
    final hasValue = _accountTypes.any(
      (option) => option.value == _filters.accountType,
    );
    return Container(
      width: 124,
      height: 21,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: hasValue ? _filters.accountType : '',
          isExpanded: true,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 12,
            color: Color(0xFF6B6B6B),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.zero,
          padding: EdgeInsets.zero,
          style: _kFilterValueStyle,
          items: [
            const DropdownMenuItem<String>(
              value: '',
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('كل التصنيفات', style: _kFilterValueStyle),
              ),
            ),
            for (final option in _accountTypes)
              DropdownMenuItem<String>(
                value: option.value,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    option.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _kFilterValueStyle,
                  ),
                ),
              ),
          ],
          onChanged: (value) {
            if (!_type.hasAccount) {
              _toast(
                'فلتر تصنيف الحساب غير متاح لهذا النوع: '
                'المستند لا يسجل حساباً.',
              );
              return;
            }
            _updateFilters(_filters.copyWith(accountType: value ?? ''));
          },
        ),
      ),
    );
  }

  Widget _paymentStatusCombo() {
    const options = <String, String>{
      'all': 'الكل',
      'paid': 'مدفوع',
      'partial': 'مدفوع جزئياً',
      'unpaid': 'غير مدفوع',
    };
    return Container(
      width: 118,
      height: 21,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.containsKey(_filters.paymentStatus)
              ? _filters.paymentStatus
              : 'all',
          isExpanded: true,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 12,
            color: Color(0xFF6B6B6B),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.zero,
          padding: EdgeInsets.zero,
          style: _kFilterValueStyle,
          items: [
            for (final entry in options.entries)
              DropdownMenuItem<String>(
                value: entry.key,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(entry.value, style: _kFilterValueStyle),
                ),
              ),
          ],
          onChanged: (value) {
            if (!_type.hasPayments) {
              _toast('فلتر حالة السداد غير متاح لهذا النوع.');
              return;
            }
            _updateFilters(_filters.copyWith(paymentStatus: value ?? 'all'));
          },
        ),
      ),
    );
  }

  Widget _documentStatusCombo() {
    final options = _type.isQuotation
        ? const <String, String>{
            'all': 'الكل',
            'open': 'مفتوح',
            'converted': 'محوّل',
          }
        : const <String, String>{
            'all': 'الكل',
            'applied': 'مُرحّل',
            'draft': 'غير مُرحّل',
          };
    return Container(
      width: 118,
      height: 21,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.containsKey(_filters.documentStatus)
              ? _filters.documentStatus
              : 'all',
          isExpanded: true,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 12,
            color: Color(0xFF6B6B6B),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.zero,
          padding: EdgeInsets.zero,
          style: _kFilterValueStyle,
          items: [
            for (final entry in options.entries)
              DropdownMenuItem<String>(
                value: entry.key,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(entry.value, style: _kFilterValueStyle),
                ),
              ),
          ],
          onChanged: (value) {
            _updateFilters(_filters.copyWith(documentStatus: value ?? 'all'));
          },
        ),
      ),
    );
  }

  Widget _amountRange() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [
        _plainField(
          _minAmount,
          width: 62,
          hint: 'من',
          onChanged: (value) => _filters = _filters.copyWith(
            minAmount: int.tryParse(value.trim()),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('—', style: _kFilterLabelStyle),
        ),
        _plainField(
          _maxAmount,
          width: 62,
          hint: 'إلى',
          onChanged: (value) => _filters = _filters.copyWith(
            maxAmount: int.tryParse(value.trim()),
          ),
        ),
      ],
    );
  }

  Widget _paymentRadios() {
    return SizedBox(
      width: 148,
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _radioOption('الكل', 'all'),
          _radioOption('نقدي', 'cash'),
          _radioOption('آجل', 'credit'),
        ],
      ),
    );
  }

  Widget _radioOption(String label, String value) {
    final selected = _filters.paymentMethod == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_type.hasPayments && !_type.isVoucher) {
          _toast('فلتر طريقة السداد غير متاح لهذا النوع.');
          return;
        }
        _updateFilters(_filters.copyWith(paymentMethod: value));
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? ShopColors.focusBlue : Colors.white,
              border: Border.all(
                color: selected
                    ? ShopColors.focusBlue
                    : const Color(0xFF8C8C8C),
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: selected
                ? Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 4),
          Text(label, style: _kFilterLabelStyle),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action row.
  // ---------------------------------------------------------------------------
  Widget _buildActions() {
    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.only(top: 3, right: 8, left: 8),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            const SizedBox(width: 92),
            _actionButton(
              'عرض الفواتير',
              Icons.search,
              _showDocumentResults,
              width: 150,
              background: _kYellow,
            ),
            const SizedBox(width: 10),
            if (_type.hasItems)
              _actionButton(
                'عرض الأصناف',
                Icons.search,
                _showItemResults,
                width: 136,
                background: _kSoft,
              ),
            const Spacer(),
            if (_totalsLine().isNotEmpty)
              Text(
                _totalsLine(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF4A4A4A),
                  height: 1.1,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _totalsLine() {
    if (!_loaded || _error != null) return '';
    if (_documents.isEmpty && _items.isEmpty) return '';
    final buffer = StringBuffer(
      'العدد: $_totalCount  •  الإجمالي: ${_money(_totals.total)}',
    );
    if (_totals.discount != 0) {
      buffer.write('  •  الخصم: ${_money(_totals.discount)}');
    }
    if (_totals.paid != 0) {
      buffer.write('  •  المدفوع: ${_money(_totals.paid)}');
    }
    if (_totals.remaining != 0) {
      buffer.write('  •  المتبقي: ${_money(_totals.remaining)}');
    }
    if (_totals.quantity != 0) {
      buffer.write('  •  الكمية: ${_money(_totals.quantity)}');
    }
    if (_selection.isNotEmpty) {
      buffer.write('  •  محدد: ${_selection.length}');
    }
    return buffer.toString();
  }

  Widget _actionButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    required double width,
    required Color background,
    double iconSize = 17,
    Color? iconColor,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: width,
            height: 30,
            decoration: BoxDecoration(
              color: hovered ? kHoverYellow : background,
              border: Border.all(color: const Color(0xFFD0D0D0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              textDirection: TextDirection.rtl,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: _kInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  size: iconSize,
                  color: iconColor ?? const Color(0xFF2F2F2F),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
