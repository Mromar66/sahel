part of 'invoice_op_page.dart';

/// Layout widgets for the شراء screen. Kept in an extension so the state class
/// stays readable while all pieces still share the same private state.
extension _InvoiceOpLayout on _InvoiceOpPageState {
  Widget _buildSalesToolbar() {
    final ribbonActions = switch (_salesTab) {
      0 => <Widget>[
        _salesToolbarButton(Icons.add, 'جديد', _newInvoice),
        _salesToolbarButton(Icons.delete_outline, 'حذف', _deleteInvoice),
        _salesToolbarButton(Icons.search, 'بحث', _browseSalesInvoices),
        _salesToolbarButton(
          Icons.first_page,
          'السابق',
          () => _navigateSalesInvoice(-1),
        ),
        _salesToolbarButton(
          Icons.last_page,
          'التالي',
          () => _navigateSalesInvoice(1),
        ),
        _salesToolbarButton(Icons.save_outlined, 'حفظ', () => _save()),
        _salesToolbarButton(Icons.print_outlined, 'طباعة', _print),
        _salesToolbarButton(
          Icons.content_copy,
          'نسخ الفاتورة',
          _copyCurrentSalesInvoice,
        ),
        _salesToolbarButton(
          Icons.file_upload_outlined,
          'استيراد Excel',
          _importSalesCsv,
        ),
        _salesToolbarButton(
          Icons.file_download_outlined,
          'تصدير Excel',
          _exportExcel,
        ),
        _salesToolbarButton(Icons.sync, 'تحديث البيانات', _refreshSalesLookups),
        _salesToolbarButton(Icons.list_alt, 'اختيار الحقول', _editCustomFields),
        _salesToolbarButton(
          Icons.price_change_outlined,
          'تعديل الأسعار',
          _editPrices,
        ),
        _salesToolbarButton(Icons.qr_code_2, 'طباعة باركود', _printBarcode),
        _salesToolbarButton(Icons.share_outlined, 'مشاركة', _share),
        _salesToolbarButton(Icons.tune, 'إعدادات', _showSettings),
        _salesToolbarButton(
          Icons.keyboard_outlined,
          'اختصارات',
          _showShortcuts,
        ),
        _salesToolbarButton(Icons.close, 'إغلاق', _close),
      ],
      1 => <Widget>[
        _salesToolbarButton(Icons.preview_outlined, 'معاينة الفاتورة', _print),
        _salesToolbarButton(Icons.print_outlined, 'حفظ وطباعة', _saveAndPrint),
        _salesToolbarButton(Icons.list_alt, 'اختيار الحقول', _editCustomFields),
      ],
      _ => <Widget>[
        _salesToolbarButton(Icons.tune, 'إعدادات الشاشة', _showSettings),
        _salesToolbarButton(Icons.sync, 'تحديث البيانات', _refreshSalesLookups),
      ],
    };
    return Container(
      height: 62,
      color: const Color(0xFFF0F2F5),
      child: Column(
        children: [
          SizedBox(
            height: 26,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                _salesTabButton('عام', 0, () => _rebuild(() => _salesTab = 0)),
                _salesTabButton(
                  'تنسيق الفاتورة',
                  1,
                  () => _rebuild(() => _salesTab = 1),
                ),
                _salesTabButton(
                  'الخصائص',
                  2,
                  () => _rebuild(() => _salesTab = 2),
                ),
                const Spacer(),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFBFC6D0)),
          SizedBox(
            height: 35,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  for (
                    var index = 0;
                    index < ribbonActions.length;
                    index++
                  ) ...[
                    if (const {2, 5, 7, 10, 12, 15}.contains(index))
                      Container(
                        width: 1,
                        height: 21,
                        color: const Color(0xFFD0D4DA),
                      ),
                    ribbonActions[index],
                  ],
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesTabButton(String label, int index, VoidCallback onTap) {
    final active = _salesTab == index;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 25,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? Colors.white : const Color(0xFFDCE2EA),
          border: Border(
            top: BorderSide(
              color: active ? _kBlue : Colors.transparent,
              width: 2,
            ),
            left: const BorderSide(color: Color(0xFFD0D4DA)),
            right: const BorderSide(color: Color(0xFFD0D4DA)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: _kInk),
        ),
      ),
    );
  }

  Widget _salesToolbarButton(IconData icon, String label, VoidCallback onTap) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 68,
          height: 34,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: Color(0xFFD9DDE3))),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: _kBlue),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9.5, color: _kInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesSidebar({required bool collapsed}) {
    if (collapsed) {
      return Container(
        width: 40,
        color: const Color(0xFFF0F2F5),
        alignment: Alignment.topCenter,
        child: IconButton(
          tooltip: 'فتح القائمة الجانبية',
          onPressed: () => _rebuild(() => _salesSidebarCollapsed = false),
          icon: const Icon(Icons.chevron_right, size: 22, color: _kBlue),
        ),
      );
    }

    return SizedBox(
      width: 236,
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Expanded(child: _buildSalesActionPanel()),
          SizedBox(
            width: 18,
            child: Tooltip(
              message: 'طي القائمة الجانبية',
              child: Material(
                color: const Color(0xFFE8EBF0),
                child: InkWell(
                  onTap: () => _rebuild(() => _salesSidebarCollapsed = true),
                  child: const Center(
                    child: Icon(Icons.chevron_left, size: 18, color: _kBlue),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesActionPanel() {
    return Container(
      color: const Color(0xFFF7F8FA),
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                IconButton(
                  tooltip: 'طي القائمة الجانبية',
                  onPressed: () =>
                      _rebuild(() => _salesSidebarCollapsed = true),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 28,
                  ),
                  icon: const Icon(Icons.chevron_left, size: 18, color: _kInk),
                ),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 0, 4),
              child: Column(
                children: [
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      _salesMiniAction(
                        Icons.category_outlined,
                        'الأقسام',
                        _showCategories,
                      ),
                      const SizedBox(width: 4),
                      _salesMiniAction(
                        Icons.person_outline,
                        'العميل',
                        _pickAccount,
                      ),
                      const SizedBox(width: 4),
                      _salesMiniAction(
                        Icons.inventory_2_outlined,
                        'الأصناف',
                        _showQuickList,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const _SalesPanelCaption('الأصناف'),
                  _salesPanelAction(
                    'إضافة صنف جديد',
                    Icons.add_circle_outline,
                    const Color(0xFF188038),
                    () => openAppWindowTab(
                      context,
                      '${AppRoutes.products}?new=1',
                    ),
                  ),
                  _salesPanelAction(
                    'تعديل أسعار الصنف',
                    Icons.edit,
                    const Color(0xFF4285F4),
                    _editPrices,
                  ),
                  _salesPanelAction(
                    'طباعة باركود الصنف',
                    Icons.print,
                    const Color(0xFF6B6B6B),
                    _printBarcode,
                  ),
                  const SizedBox(height: 7),
                  const _SalesPanelCaption('الفاتورة'),
                  _salesPanelAction(
                    'إضافة سريعة',
                    Icons.bolt,
                    const Color(0xFF4285F4),
                    _showQuickList,
                  ),
                  _salesPanelAction(
                    'كوبون الخصم',
                    Icons.discount_outlined,
                    const Color(0xFF4285F4),
                    _showCouponDiscount,
                  ),
                  const SizedBox(height: 7),
                  const _SalesPanelCaption('أخرى'),
                  _salesPanelAction(
                    'الآلة الحاسبة',
                    Icons.calculate_outlined,
                    const Color(0xFF656565),
                    _showCalculator,
                  ),
                  _salesPanelAction(
                    'صور الصنف',
                    Icons.image_outlined,
                    const Color(0xFF34A853),
                    _showSelectedProductImage,
                  ),
                  _salesPanelAction(
                    'حقول إضافية',
                    Icons.add_box_outlined,
                    const Color(0xFF4285F4),
                    _editCustomFields,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      _salesMiniAction(
                        Icons.numbers,
                        'الكمية',
                        () => _tableKey.currentState?.editSelected(
                          _tbl.quantityColumn,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _salesMiniAction(Icons.more_horiz, 'السطر', _lineOptions),
                      const SizedBox(width: 4),
                      _salesMiniAction(
                        Icons.delete_outline,
                        'حذف',
                        () => _removeSelected(ask: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesMiniAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 34,
            color: _kBlue,
            child: Icon(icon, size: 19, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _salesPanelAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 50,
          color: color,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(icon, size: 22, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11.5, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesTotalsAndActions({double height = 238}) {
    final actionGap = height < 100 ? 2.0 : 5.0;
    final actionHeight = math
        .min(34.0, math.max(0.0, height - 9 - actionGap - 1))
        .toDouble();
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFDAE3F0))),
      ),
      padding: const EdgeInsets.fromLTRB(8, 5, 12, 4),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, content) {
                final compact = content.maxWidth < 780;
                return Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    SizedBox(
                      width: math.min(430.0, content.maxWidth * .55).toDouble(),
                      child: SingleChildScrollView(
                        child: _buildSalesPaymentFields(compact: compact),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: SizedBox()),
                    SizedBox(
                      width: compact ? 60 : 82,
                      child: Center(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _grandTotal,
                          builder: (context, total, _) => Text(
                            '$total',
                            style: TextStyle(
                              fontSize: compact ? 32 : 48,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF262626),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: compact ? 145 : 180,
                      child: SingleChildScrollView(child: _buildSalesSummary()),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: actionGap),
          SizedBox(
            height: actionHeight,
            child: Padding(
              padding: const EdgeInsets.only(right: 68),
              child: LayoutBuilder(
                builder: (context, constraints) => FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    textDirection: TextDirection.rtl,
                    children: [
                      _salesBottomButton(
                        'حفظ وجديد',
                        const Color(0xFF188038),
                        () => _save(resetAfter: true),
                        width: 130,
                      ),
                      const SizedBox(width: 6),
                      _salesSavePrintSplitButton(),
                      const SizedBox(width: 6),
                      _salesBottomButton(
                        'حفظ وإغلاق',
                        const Color(0xFF367CEA),
                        _saveAndClose,
                        width: 130,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesPaymentFields({bool compact = false}) {
    final treasuryNames = _treasuries.isEmpty
        ? const ['درج النقدية']
        : _treasuries.map((item) => item.name).toList();
    if (compact) {
      Widget compactField(String label, Widget control) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: SizedBox(
          height: 25,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: _kInk),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(child: control),
            ],
          ),
        ),
      );

      final paymentMethod = _salesDropdown<int>(
        value: _payTab,
        items: List.generate(
          _kPayTabs.length,
          (index) => (index, _kPayTabs[index]),
        ),
        onChanged: (value) => _rebuild(() => _payTab = value),
      );
      final treasury = _salesDropdown<String>(
        value: treasuryNames.contains(_treasury)
            ? _treasury
            : treasuryNames.first,
        items: treasuryNames.map((name) => (name, name)).toList(),
        onChanged: _selectSalesTreasury,
      );
      final account = InkWell(
        onTap: _pickAccount,
        child: Container(
          height: 25,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8))),
          ),
          child: Text(
            _selectedAccount?.name ?? 'اختيار العميل',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: _kInk),
          ),
        ),
      );
      final paid = InkWell(
        onTap: _openPayment,
        child: Container(
          height: 25,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8))),
          ),
          child: Text(
            '${_pendingPayment?.amount ?? _paid}',
            style: const TextStyle(fontSize: 11, color: _kInk),
          ),
        ),
      );
      final remaining = Container(
        height: 25,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8))),
        ),
        child: Text(
          '${(_grandTotal.value - (_pendingPayment?.amount ?? _paid)).clamp(0, 1 << 30)}',
          style: const TextStyle(fontSize: 11, color: _kInk),
        ),
      );
      return Column(
        children: [
          compactField('طريقة الدفع', paymentMethod),
          compactField('الخزينة', treasury),
          compactField('الحساب', account),
          compactField('المدفوع', paid),
          compactField('المتبقي', remaining),
          TextField(
            controller: _notes,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'ملاحظات',
              border: UnderlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 11, color: _kInk),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _openPayment,
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text('سداد F11'),
            ),
          ),
        ],
      );
    }

    final paymentMethod = _salesDropdown<int>(
      value: _payTab,
      items: List.generate(
        _kPayTabs.length,
        (index) => (index, _kPayTabs[index]),
      ),
      onChanged: (value) => _rebuild(() => _payTab = value),
    );
    final paymentType = _salesDropdown<String>(
      value: treasuryNames.contains(_treasury)
          ? _treasury
          : treasuryNames.first,
      items: treasuryNames.map((name) => (name, name)).toList(),
      onChanged: _selectSalesTreasury,
    );
    final account = InkWell(
      onTap: _pickAccount,
      child: Container(
        height: 22,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8))),
        ),
        child: Text(
          _selectedAccount?.name ?? 'اختيار العميل',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, color: _kInk),
        ),
      ),
    );
    final amount = InkWell(
      onTap: _openPayment,
      child: Container(
        height: 22,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8))),
        ),
        child: Text(
          '${_pendingPayment?.amount ?? _paid}',
          style: const TextStyle(fontSize: 10.5, color: _kInk),
        ),
      ),
    );
    final discount = Container(
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8))),
      ),
      child: TextField(
        controller: _discVal,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10.5, color: _kInk),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
    final remaining = Container(
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8))),
      ),
      child: Text(
        '${(_grandTotal.value - (_pendingPayment?.amount ?? _paid)).clamp(0, 1 << 30)}',
        style: const TextStyle(fontSize: 10.5, color: _kInk),
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(child: _salesStackedField('طريقة الدفع', paymentMethod)),
              const SizedBox(width: 6),
              Expanded(child: _salesStackedField('النوع', paymentType)),
              const SizedBox(width: 6),
              Expanded(child: _salesStackedField('اسم الحساب', account)),
              const SizedBox(width: 6),
              Expanded(child: _salesStackedField('المبلغ', amount)),
            ],
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 40,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              SizedBox(width: 90, child: _salesStackedField('الخصم', discount)),
              const SizedBox(width: 6),
              SizedBox(
                width: 100,
                child: _salesStackedField('المتبقي', remaining),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'سداد F11',
                onPressed: _openPayment,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
                icon: const Icon(
                  Icons.payments_outlined,
                  size: 19,
                  color: _kBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _salesStackedField(String label, Widget control) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 16,
          child: Text(
            label,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF666666)),
          ),
        ),
        const SizedBox(height: 1),
        Expanded(child: control),
      ],
    );
  }

  Widget _salesDropdown<T>({
    required T value,
    required List<(T, String)> items,
    required ValueChanged<T> onChanged,
  }) {
    final valid = items.any((item) => item.$1 == value);
    return Container(
      height: 25,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8))),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: valid ? value : null,
          isExpanded: true,
          isDense: true,
          iconSize: 15,
          dropdownColor: Colors.white,
          style: const TextStyle(fontSize: 10.5, color: _kInk),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item.$1,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (selected) {
            if (selected != null) onChanged(selected);
          },
        ),
      ),
    );
  }

  Widget _buildSalesSummary() {
    return AnimatedBuilder(
      animation: _tbl,
      builder: (context, _) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _salesSummaryRow('الإجمالي', '${_tbl.grossTotal}'),
          _salesSummaryRow(
            'الخصم',
            '${_tbl.discountTotal + _discountAmount(_tbl.netTotal)}',
          ),
          _salesSummaryRow(
            'الإضافة / الضريبة',
            '${_additionAmount(_tbl.netTotal)}',
          ),
          _salesSummaryRow('المطلوب', '${_grandTotal.value}', bold: true),
          _salesSummaryRow('المدفوع', '${_pendingPayment?.amount ?? _paid}'),
          _salesSummaryRow(
            'الباقي',
            '${(_grandTotal.value - (_pendingPayment?.amount ?? _paid)).clamp(0, 1 << 30)}',
            color: const Color(0xFFD74747),
          ),
        ],
      ),
    );
  }

  Widget _salesSummaryRow(
    String label,
    String value, {
    bool bold = false,
    Color color = _kInk,
  }) {
    return SizedBox(
      height: 24,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          SizedBox(
            width: 75,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 10.5, color: color),
            ),
          ),
          Expanded(
            child: Container(
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFB8C7D8))),
              ),
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesBottomButton(
    String label,
    Color color,
    VoidCallback onTap, {
    double width = 130,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        height: 34,
        color: color,
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: Colors.white),
        ),
      ),
    );
  }

  Widget _salesSavePrintSplitButton() {
    const color = Color(0xFF367CEA);
    return SizedBox(
      height: 34,
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisSize: MainAxisSize.min,
        children: [
          _salesBottomButton('حفظ وطباعة', color, _saveAndPrint, width: 108),
          const SizedBox(width: 1),
          PopupMenuButton<String>(
            tooltip: 'خيارات الطباعة والإرسال',
            position: PopupMenuPosition.over,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 0),
            onSelected: (value) {
              switch (value) {
                case 'print':
                  _saveAndPrint();
                  break;
                case 'preview':
                  _print();
                  break;
                case 'email':
                  _sendInvoice('email');
                  break;
                case 'whatsapp':
                  _sendInvoice('whatsapp');
                  break;
                case 'journal':
                  _printJournal();
                  break;
              }
            },
            itemBuilder: (context) => [
              _salesMenuItem('print', Icons.print_outlined, 'طباعة'),
              _salesMenuItem('preview', Icons.preview_outlined, 'معاينة'),
              const PopupMenuDivider(height: 1),
              _salesMenuItem(
                'email',
                Icons.email_outlined,
                'حفظ وإرسال بالبريد',
              ),
              _salesMenuItem(
                'whatsapp',
                Icons.chat_outlined,
                'حفظ وإرسال واتساب',
                iconColor: const Color(0xFF25A45A),
              ),
              const PopupMenuDivider(height: 1),
              _salesMenuItem(
                'journal',
                Icons.receipt_long_outlined,
                'طباعة القيد',
                shortcut: 'Ctrl+M',
              ),
            ],
            child: Container(
              width: 20,
              height: 34,
              color: color,
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _salesMenuItem(
    String value,
    IconData icon,
    String label, {
    String? shortcut,
    Color iconColor = _kBlue,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        width: 210,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, color: _kInk),
              ),
            ),
            if (shortcut != null) ...[
              const SizedBox(width: 10),
              Text(
                shortcut,
                style: const TextStyle(fontSize: 9, color: Color(0xFF666666)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _warehouseSelector({bool showStatus = false, bool stacked = false}) {
    final options = _warehouses;
    final selected = options
        .where((item) => item.id == _selectedWarehouseId)
        .firstOrNull;
    final dropdown = Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8))),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selected?.id,
          hint: const Align(
            alignment: Alignment.centerRight,
            child: Text('المخزن الرئيسي', style: TextStyle(fontSize: 10.5)),
          ),
          isExpanded: true,
          isDense: true,
          iconSize: 15,
          style: const TextStyle(fontSize: 10.5, color: _kInk),
          items: options
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
          onChanged: (value) {
            if (value != null) _selectSalesWarehouse(value);
          },
        ),
      ),
    );
    if (stacked) {
      return SizedBox(
        height: 38,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              flex: 3,
              child: _salesStackedField('اسم المخزن', dropdown),
            ),
            if (showStatus) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _salesStackedField(
                  'الحالة',
                  Container(
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFB8B8B8)),
                      ),
                    ),
                    child: const Text(
                      'جديدة',
                      style: TextStyle(fontSize: 10.5, color: _kInk),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return SizedBox(
      height: 23,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          _rowLabel('المخزن', 58),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 23,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _kField,
                border: Border.all(color: const Color(0xFFB8B8B8)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selected?.id,
                  hint: const Text(
                    'اختار المخزن',
                    style: TextStyle(fontSize: 11, color: _kInk),
                  ),
                  isExpanded: true,
                  isDense: true,
                  style: const TextStyle(fontSize: 11, color: _kInk),
                  items: options
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
                  onChanged: (value) {
                    if (value != null) _selectSalesWarehouse(value);
                  },
                ),
              ),
            ),
          ),
          if (showStatus) ...[
            const SizedBox(width: 5),
            _rowLabel('الحالة', 42),
            const SizedBox(width: 4),
            Container(
              width: 48,
              height: 23,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8))),
              ),
              child: const Text(
                'جديدة',
                style: TextStyle(fontSize: 10.5, color: _kInk),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _salesRepresentativeSelector({bool stacked = false}) {
    final selected = _salesRepresentatives
        .where((item) => item.id == _selectedSalesRepresentative?.id)
        .firstOrNull;
    final dropdown = Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8))),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: selected?.id,
          hint: const Align(
            alignment: Alignment.centerRight,
            child: Text('بدون مندوب', style: TextStyle(fontSize: 10.5)),
          ),
          isExpanded: true,
          isDense: true,
          iconSize: 15,
          style: const TextStyle(fontSize: 10.5, color: _kInk),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('بدون مندوب'),
              ),
            ),
            ..._salesRepresentatives.map(
              (item) => DropdownMenuItem<int?>(
                value: item.id,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(item.name),
                ),
              ),
            ),
          ],
          onChanged: (value) => _rebuild(() {
            _selectedSalesRepresentative = value == null
                ? null
                : _salesRepresentatives
                      .where((item) => item.id == value)
                      .firstOrNull;
          }),
        ),
      ),
    );
    if (stacked) {
      return SizedBox(
        height: 38,
        child: _salesStackedField('مندوب البيع', dropdown),
      );
    }
    return SizedBox(
      height: 23,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          _rowLabel('مندوب البيع', 58),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 23,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _kField,
                border: Border.all(color: const Color(0xFFB8B8B8)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: selected?.id,
                  hint: const Text(
                    'بدون مندوب',
                    style: TextStyle(fontSize: 11, color: _kInk),
                  ),
                  isExpanded: true,
                  isDense: true,
                  style: const TextStyle(fontSize: 11, color: _kInk),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('بدون مندوب'),
                      ),
                    ),
                    ..._salesRepresentatives.map(
                      (item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(item.name),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => _rebuild(() {
                    _selectedSalesRepresentative = value == null
                        ? null
                        : _salesRepresentatives
                              .where((item) => item.id == value)
                              .firstOrNull;
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top block: sales uses the same horizontal bands as the reference screen.
  // ---------------------------------------------------------------------------
  Widget _buildTopBlock({double salesHeight = 200}) {
    if (_kind.isSale) {
      const designWidth = 1005.0;
      const designHeight = 220.0;
      return LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: double.infinity,
          height: salesHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topRight,
            child: SizedBox(
              width: math.max(designWidth, constraints.maxWidth).toDouble(),
              height: designHeight,
              child: Stack(
                children: [
                  Positioned.fill(child: _buildSalesTopContent()),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 52,
                    child: Center(
                      child: Container(
                        width: 247,
                        height: 35,
                        alignment: Alignment.center,
                        color: const Color(0xFF00A5E8),
                        child: const Text(
                          'مبيعات',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final content = Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: SizedBox(width: 322, child: _buildRightColumn()),
        ),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: SizedBox(width: 207, child: _buildMiddleColumn()),
        ),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: SizedBox(width: 149, height: 127, child: _buildInvoicePanel()),
        ),
        const Expanded(child: SizedBox()),
      ],
    );

    return SizedBox(height: 136, child: content);
  }

  Widget _buildSalesTopContent() {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 45,
          child: _buildSalesHeaderRow(),
        ),
        Positioned(
          left: 0,
          top: 57,
          width: 420,
          height: 40,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              _salesMetaField('الوقت', _time, ltr: true),
              const SizedBox(width: 6),
              _salesMetaField('الرقم', _invoiceNo),
              const SizedBox(width: 6),
              _salesMetaField('التاريخ', _date, flex: 2),
            ],
          ),
        ),
        Positioned(
          right: 0,
          top: 100,
          width: 322,
          height: 118,
          child: _buildSalesFieldsColumn(showStatus: true),
        ),
        Positioned(
          left: 0,
          bottom: 18,
          width: 420,
          height: 44,
          child: _buildSalesEntryRow(),
        ),
      ],
    );
  }

  Widget _buildSalesEntryRow() {
    Widget inputCell(String label, Widget input, {double? width}) {
      return SizedBox(
        width: width,
        height: 42,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 16,
              child: Text(
                label,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9.5, color: Color(0xFF666666)),
              ),
            ),
            Expanded(child: input),
          ],
        ),
      );
    }

    Widget underlined(Widget child) => Container(
      height: 26,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8))),
      ),
      child: child,
    );

    void changeQuantity(int delta) {
      final current = int.tryParse(_addQty.text.trim()) ?? 1;
      _addQty.text = '${math.max(1, current + delta)}';
      _addQty.selection = TextSelection.collapsed(offset: _addQty.text.length);
    }

    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        inputCell(
          'العملة',
          underlined(
            const Center(
              child: Text(
                'EGP',
                style: TextStyle(fontSize: 10.5, color: _kInk),
              ),
            ),
          ),
          width: 68,
        ),
        const SizedBox(width: 5),
        inputCell(
          'المعامل',
          underlined(
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addQty,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10.5, color: _kInk),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => changeQuantity(1),
                      child: const Icon(Icons.arrow_drop_up, size: 11),
                    ),
                    InkWell(
                      onTap: () => changeQuantity(-1),
                      child: const Icon(Icons.arrow_drop_down, size: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          width: 82,
        ),
        const SizedBox(width: 5),
        inputCell(
          'الضريبة (VAT)',
          underlined(
            Row(
              children: [
                IconButton(
                  tooltip: 'مسح الضريبة',
                  onPressed: () {
                    _addPct.clear();
                    _addVal.clear();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 18,
                    height: 24,
                  ),
                  icon: const Icon(Icons.close, size: 13, color: _kRed),
                ),
                Expanded(
                  child: TextField(
                    controller: _addPct,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10.5, color: _kInk),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    '%',
                    style: TextStyle(fontSize: 10, color: _kInk),
                  ),
                ),
              ],
            ),
          ),
          width: 126,
        ),
        const SizedBox(width: 5),
        const SizedBox(width: 3),
        SizedBox(
          width: 24,
          height: 26,
          child: Tooltip(
            message: 'إضافة الصنف',
            child: InkWell(
              onTap: () => _submitSearch(_search.text),
              child: const Icon(Icons.add_box, size: 17, color: _kBlue),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesHeaderRow() {
    Widget valueField(Widget child) => Container(
      height: 24,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8))),
      ),
      child: child,
    );

    return Row(
      textDirection: TextDirection.rtl,
      children: [
        _salesHeaderField(
          'الاسم',
          InkWell(
            onTap: _pickAccount,
            child: valueField(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedAccount?.name ?? 'اختيار العميل',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: _kInk),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16, color: _kBlue),
                    const Icon(Icons.badge_outlined, size: 14, color: _kBlue),
                  ],
                ),
              ),
            ),
          ),
          flex: 2,
        ),
        _salesHeaderField(
          'الرقم',
          valueField(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Row(
                children: [
                  const Icon(Icons.info, size: 13, color: _kBlue),
                  Expanded(
                    child: Text(
                      '${_selectedAccount?.id ?? ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: _kInk),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _salesHeaderField(
          'التعامل',
          valueField(
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: _salesDropdown<int>(
                    value: _payTab,
                    items: List.generate(
                      _kPayTabs.length,
                      (index) => (index, _kPayTabs[index]),
                    ),
                    onChanged: (value) => _rebuild(() => _payTab = value),
                  ),
                ),
                const Icon(
                  Icons.monetization_on_outlined,
                  size: 14,
                  color: _kBlue,
                ),
              ],
            ),
          ),
        ),
        _salesHeaderField(
          'السعر',
          valueField(
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: _salesDropdown<int>(
                    value: _selectedPriceLevel,
                    items: List.generate(
                      _priceListNames.length,
                      (index) => (index, _priceListNames[index]),
                    ),
                    onChanged: (value) =>
                        _rebuild(() => _selectedPriceLevel = value),
                  ),
                ),
                const Icon(Icons.circle_outlined, size: 14, color: _kBlue),
              ],
            ),
          ),
        ),
        _salesHeaderField(
          'طريقة العرض',
          valueField(
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Simple', style: TextStyle(fontSize: 10.5, color: _kInk)),
                Icon(Icons.arrow_drop_down, size: 16, color: _kBlue),
              ],
            ),
          ),
          flex: 2,
        ),
        _salesHeaderField(
          'رقم المرجع #',
          valueField(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: Text(
                      '${_sourceQuoteId ?? ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10.5, color: _kInk),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 15, color: _kInk),
                  const Icon(Icons.more_horiz, size: 14, color: _kInk),
                  const Icon(Icons.check, size: 14, color: _kBlue),
                ],
              ),
            ),
          ),
        ),
        _salesHeaderField(
          'اسم الفرع',
          valueField(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Expanded(
                    child: Text(
                      'الفرع الرئيسي',
                      style: TextStyle(fontSize: 10.5, color: _kInk),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16, color: _kInk),
                  const Icon(Icons.search, size: 14, color: _kBlue),
                ],
              ),
            ),
          ),
          flex: 2,
        ),
      ],
    );
  }

  Widget _salesHeaderField(String label, Widget control, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 9.5, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 1),
            Expanded(child: control),
          ],
        ),
      ),
    );
  }

  Widget _salesMetaField(
    String label,
    TextEditingController controller, {
    bool ltr = false,
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8))),
              ),
              child: TextField(
                controller: controller,
                textAlign: ltr ? TextAlign.left : TextAlign.right,
                textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
                style: const TextStyle(fontSize: 11.5, color: _kInk),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesFieldsColumn({bool showStatus = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _warehouseSelector(showStatus: showStatus, stacked: true),
        const SizedBox(height: 2),
        _salesRepresentativeSelector(stacked: true),
        const SizedBox(height: 2),
        SizedBox(
          height: 38,
          child: _salesStackedField(
            'ملاحظات',
            Container(
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8))),
              ),
              child: TextField(
                controller: _notes,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, color: _kInk),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoicePanel() {
    return Container(
      decoration: BoxDecoration(
        color: _kind.isSale ? Colors.white : _kPanelGreen,
        border: _kind.isSale
            ? Border.all(color: const Color(0xFFD0D4DA))
            : null,
      ),
      child: Column(
        children: [
          const SizedBox(height: 3),
          SizedBox(
            height: 19,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'رقم',
                        style: TextStyle(fontSize: 12, color: _kInk),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 92,
                  decoration: _kind.isSale
                      ? const BoxDecoration(
                          color: Color(0xFFF8FAFD),
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFB8B8B8)),
                          ),
                        )
                      : const BoxDecoration(color: _kGreen),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _invoiceNo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _kInk,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 23,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(child: _dateField()),
                  const SizedBox(width: 3),
                  SizedBox(width: 52, child: _timeField()),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_kind.isSale)
                  const Text(
                    'الحالة',
                    style: TextStyle(fontSize: 10, color: _kInk),
                  )
                else
                  ValueListenableBuilder<int>(
                    valueListenable: _grandTotal,
                    builder: (context, total, _) => Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: _kInk,
                      ),
                    ),
                  ),
                if (_kind.isSale)
                  const Text(
                    'جديدة',
                    style: TextStyle(fontSize: 11, color: _kInk),
                  ),
                if (_kind.needsOriginalInvoice) ...[
                  const SizedBox(height: 2),
                  HoverBuilder(
                    builder: (context, hovered) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _loadOriginalInvoice,
                      child: Container(
                        width: 96,
                        height: 18,
                        color: hovered ? kHoverYellow : Colors.white,
                        alignment: Alignment.center,
                        child: Text(
                          _originalInvoiceId == null
                              ? 'تحميل فاتورة'
                              : 'تغيير الفاتورة',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: _kInk,
                          ),
                        ),
                      ),
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

  Widget _borderField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF8D8D8D)),
      ),
      child: child,
    );
  }

  Widget _dateField() {
    return _borderField(
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Expanded(
            child: Center(
              child: TextField(
                controller: _date,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 11, color: _kInk),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(left: 3),
                  constraints: BoxConstraints(minHeight: 0),
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 16,
            child: Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeField() {
    return _borderField(
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Expanded(
            child: Center(
              child: TextField(
                controller: _time,
                textAlign: TextAlign.left,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 10.5, color: _kInk),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(left: 2),
                  constraints: BoxConstraints(minHeight: 0),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 13,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.arrow_drop_up, size: 9, color: Color(0xFF555555)),
                Icon(Icons.arrow_drop_down, size: 9, color: Color(0xFF555555)),
              ],
            ),
          ),
          const SizedBox(width: 1),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Right column: search row, supplier bar, account / notes fields.
  // ---------------------------------------------------------------------------
  Widget _buildRightColumn() {
    return Column(
      children: [
        _buildSearchRow(),
        const SizedBox(height: 2),
        _buildAccountRow(),
        Container(height: 1, color: _kFocusBlue),
        SizedBox(height: _kind.isSale ? 144 : 57, child: _buildFieldsColumn()),
      ],
    );
  }

  Widget _buildSearchRow() {
    return SizedBox(
      height: 27,
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _productSearchField()),
          const SizedBox(width: 4),
          _blankBox(41, _kField, _showCategories),
          const SizedBox(width: 4),
          _blankBox(44, _kYellow, _showQuickList),
          const SizedBox(width: 4),
          _inquiryButton(),
        ],
      ),
    );
  }

  Widget _productSearchField() => ProductSearchField<InvoiceProduct>(
    key: _searchKey,
    controller: _search,
    focusNode: _searchFocus,
    lookup: (code) => _repo.findByBarcode(
      code,
      warehouseId: _kind.isSale ? _selectedWarehouseId : null,
    ),
    search: (term) => _repo.searchProducts(
      term,
      warehouseId: _kind.isSale ? _selectedWarehouseId : null,
    ),
    onAdd: _onSearchPicked,
    onMessage: _toast,
    onSubmit: _submitSearch,
  );

  Widget _buildAccountRow() {
    if (_kind.isSale) {
      return SizedBox(
        height: 27,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            _rowLabel('الاسم', 58),
            const SizedBox(width: 6),
            Expanded(
              child: InkWell(
                onTap: _pickAccount,
                child: Container(
                  height: 23,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF4285F4)),
                    ),
                  ),
                  child: Text(
                    _selectedAccount?.name ?? 'اختيار العميل',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: _kInk),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 37,
      child: HoverBuilder(
        builder: (context, hovered) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _pickAccount,
          child: Container(
            height: 37,
            color: hovered ? const Color(0xFF1A73E8) : const Color(0xFF4285F4),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              _selectedAccount?.name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Middle column: quick chips, stock counters and payment tabs.
  // ---------------------------------------------------------------------------
  Widget _buildMiddleColumn() {
    return Column(
      children: [
        SizedBox(
          height: 27,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              const Spacer(),
              _chipButton(
                width: 58,
                chip: '2',
                label: 'الكمية',
                onTap: () =>
                    _tableKey.currentState?.editSelected(_tbl.quantityColumn),
              ),
              const SizedBox(width: 5),
              _chipButton(
                width: 82,
                chip: '3',
                label: _kind.priceLabel,
                onTap: () =>
                    _tableKey.currentState?.editSelected(_tbl.priceColumn),
              ),
              const SizedBox(width: 5),
              _chipButton(
                width: 44,
                chip: '4',
                label: 'أضف',
                onTap: () => _submitSearch(_search.text),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 37,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              const Spacer(),
              AnimatedBuilder(
                animation: _tbl,
                builder: (context, _) => _greenBox(
                  width: 56,
                  value:
                      '${_tbl.selectedIndex >= 0 ? _tbl.selectedIndex + 1 : 1}',
                  onTap: () {
                    if (_tbl.lines.isNotEmpty) {
                      _tbl.select(0);
                    }
                  },
                ),
              ),
              const SizedBox(width: 5),
              AnimatedBuilder(
                animation: _tbl,
                builder: (context, _) => _greenBox(
                  width: 82,
                  value:
                      '${_tbl.selectedIndex >= 0 ? _tbl.lines[_tbl.selectedIndex].qty : 0}',
                  onTap: () =>
                      _tableKey.currentState?.editSelected(_tbl.quantityColumn),
                ),
              ),
              const SizedBox(width: 7),
              _checkTile(),
            ],
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 57,
          child: Column(
            children: [
              const SizedBox(height: 6),
              SizedBox(
                height: 51,
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    _payTabCell(0),
                    _payTabGap(),
                    _payTabCell(1),
                    _payTabGap(),
                    _payTabCell(2),
                    _payTabGap(),
                    _payTabCell(3),
                    const SizedBox(width: 2),
                    _pinButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _payTabGap() => Container(width: 1, color: Colors.white);

  Widget _payTabCell(int index, {double height = 51}) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _rebuild(() => _payTab = index),
        child: Container(
          width: 46,
          height: height,
          decoration: BoxDecoration(
            color: _kind.isSale
                ? (_payTab == index
                      ? const Color(0xFFDCE9FF)
                      : (hovered ? const Color(0xFFF1F3F4) : Colors.white))
                : (_payTab == index
                      ? _kBlue
                      : (hovered ? kHoverYellow : _kSoft)),
            border: const Border(bottom: BorderSide(color: _kBlue, width: 2)),
          ),
          alignment: Alignment.center,
          child: Text(
            _kPayTabs[index],
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontSize: 9.2, color: _kInk, height: 1.1),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldsColumn() {
    return Column(
      children: [
        const SizedBox(height: 5),
        SizedBox(
          height: 21,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              _rowLabel('الحساب', 58),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 21,
                  decoration: BoxDecoration(
                    color: _kField,
                    border: Border.all(color: const Color(0xFFB8B8B8)),
                  ),
                  child: TextField(
                    controller: _account,
                    readOnly: true,
                    showCursor: false,
                    onTap: _pickAccount,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11.5, color: _kInk),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedBuilder(
                animation: _tbl,
                builder: (context, _) =>
                    _softInfo(21, 22, '${_tbl.lines.length}'),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<int>(
                valueListenable: _grandTotal,
                builder: (context, total, _) => _softInfo(21, 52, '$total'),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<int>(
                valueListenable: _paidNotifier,
                builder: (context, paid, _) => _softInfo(21, 52, '$paid'),
              ),
            ],
          ),
        ),
        if (_kind == InvoiceOpKind.sale ||
            _kind == InvoiceOpKind.quotation) ...[
          const SizedBox(height: 5),
          _priceListSelector(),
        ],
        if (_kind.isSale) ...[
          const SizedBox(height: 5),
          _warehouseSelector(),
          const SizedBox(height: 5),
          _salesRepresentativeSelector(),
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: 23,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              _rowLabel('ملاحظات', 58),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _kField,
                    border: Border.all(color: const Color(0xFFB8B8B8)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: TextField(
                    controller: _notes,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: _kInk),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!_kind.isSale)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _editCustomFields,
              icon: const Icon(Icons.add_box_outlined, size: 16),
              label: Text('حقول إضافية (${_customFieldValues.length})'),
              style: TextButton.styleFrom(
                foregroundColor: _kBlue,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );
  }

  Widget _priceListSelector() => SizedBox(
    height: 23,
    child: Row(
      textDirection: TextDirection.rtl,
      children: [
        _rowLabel('قائمة السعر', 58),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 23,
            decoration: BoxDecoration(
              color: _kField,
              border: Border.all(color: const Color(0xFFB8B8B8)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedPriceLevel,
                isExpanded: true,
                isDense: true,
                alignment: AlignmentDirectional.centerEnd,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 11.5, color: _kInk),
                items: List.generate(
                  _priceListNames.length,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text(_priceListNames[index]),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) {
                    _rebuild(() => _selectedPriceLevel = value);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        const Text(
          'يؤثر على الأصناف التي ستُضاف',
          style: TextStyle(fontSize: 10, color: Color(0xFF666666)),
        ),
      ],
    ),
  );

  Widget _softInfo(double height, double width, String value) {
    return Container(
      width: width,
      height: height,
      color: _kField,
      alignment: Alignment.center,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10.5, color: _kInk),
      ),
    );
  }

  Widget _inquiryButton() {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _inquiry,
        child: Container(
          width: 70,
          height: 27,
          color: hovered ? kHoverYellow : _kYellow,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              const SizedBox(width: 2),
              Container(
                width: 19,
                height: 19,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '؟',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              const Expanded(
                child: Text(
                  'استعلام',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: _kInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blankBox(double width, Color color, VoidCallback onTap) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: 27,
          color: hovered ? kHoverYellow : color,
        ),
      ),
    );
  }

  Widget _chipButton({
    required double width,
    double height = 27,
    required String chip,
    required String label,
    required VoidCallback onTap,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          color: hovered ? kHoverYellow : Colors.white,
          padding: const EdgeInsets.only(right: 2),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 23,
                height: height - 2,
                color: _kYellow,
                alignment: Alignment.center,
                child: Text(
                  chip,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: _kInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkTile({double height = 37}) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openPayment,
        child: Container(
          width: 57,
          height: height,
          color: hovered ? kHoverYellow : _kYellow,
          alignment: Alignment.center,
          child: const Icon(Icons.check, size: 26, color: Color(0xFF43B5DB)),
        ),
      ),
    );
  }

  Widget _greenBox({
    required double width,
    double height = 37,
    required String value,
    required VoidCallback onTap,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          color: _kind.isSale ? null : (hovered ? kHoverYellow : _kGreen),
          decoration: _kind.isSale
              ? const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: _kBlue)),
                )
              : null,
          alignment: Alignment.center,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: _kInk,
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowLabel(String text, double width) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(text, style: const TextStyle(fontSize: 12, color: _kInk)),
      ),
    );
  }

  Widget _pinButton() {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _rebuild(() => _pinPayment = !_pinPayment),
        child: Container(
          width: 18,
          height: 20,
          color: (hovered || _pinPayment) ? kHoverYellow : _kSoft,
          child: Icon(
            Icons.push_pin,
            size: 13,
            color: _pinPayment ? _kRed : const Color(0xFF111111),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Table + left command rail.
  // ---------------------------------------------------------------------------
  Widget _buildTableArea() {
    if (_kind.isSale) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 8, 6),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: _kLine)),
          child: SharedDataGrid<InvoiceLine>(
            key: _tableKey,
            controller: _tbl,
            onMessage: _toast,
            onEditFinished: _pageFocus.requestFocus,
            salesStyle: true,
            newRowChild: _productSearchField(),
            newRowColumn: 1,
            newRowAtEnd: true,
            footerCellText: (column) => switch (column) {
              2 => '${_tbl.qtyTotal}',
              5 => '${_tbl.grossTotal}',
              6 => '${_tbl.discountTotal}',
              7 => '${_tbl.netTotal}',
              _ => '',
            },
          ),
        ),
      );
    }
    return Row(
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(width: 8),
        SizedBox(width: 62, child: _buildRail()),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: _kLine)),
              child: SharedDataGrid<InvoiceLine>(
                key: _tableKey,
                controller: _tbl,
                onMessage: _toast,
                onEditFinished: _pageFocus.requestFocus,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRail() {
    return ShopCommandRail(
      onQty: () => _tableKey.currentState?.editSelected(_tbl.quantityColumn),
      onPrice: () => _tableKey.currentState?.editSelected(_tbl.priceColumn),
      onMore: _lineOptions,
      onDelete: () => _removeSelected(ask: true),
      onDown: () => _moveSelection(1),
      onUp: () => _moveSelection(-1),
    );
  }

  // ---------------------------------------------------------------------------
  // Green totals bar.
  // ---------------------------------------------------------------------------
  static const double _barLabelH = 23;
  static const double _barGapH = 4;
  static const double _barControlH = 23;
  static const TextStyle _barLabelStyle = TextStyle(fontSize: 12, color: _kInk);

  Widget _buildTotalsBar() {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: _kGreen,
        border: Border(
          top: BorderSide(color: _kPanelGreen, width: 5),
          bottom: BorderSide(color: _kPanelGreen, width: 5),
          right: BorderSide(color: _kPanelGreen, width: 5),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          _barPinnedGroup(
            label: 'الخزينة',
            child: _barDropdown(
              width: 96,
              value: _treasury,
              items: const ['درج النقدية', 'البنك', 'الشيكات'],
              onChanged: (v) => _rebuild(() => _treasury = v),
              boxedCaret: true,
            ),
          ),
          _barDivider(),
          _barAddSection(),
          _barDivider(),
          _barDiscountSection(),
          const SizedBox(width: 4),
          _barFekkaButton(),
          const SizedBox(width: 4),
          Expanded(child: Container(color: _kPanelGreen)),
        ],
      ),
    );
  }

  Widget _barDivider() {
    return Container(width: 5, color: _kPanelGreen);
  }

  Widget _barPercent() {
    return const SizedBox(
      width: 20,
      child: Center(
        child: Text('%', style: TextStyle(fontSize: 11.5, color: _kInk)),
      ),
    );
  }

  Widget _barPinnedGroup({required String label, required Widget child}) {
    return SizedBox(
      width: 110,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: _barLabelH,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.right,
                      style: _barLabelStyle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  HoverBuilder(
                    builder: (context, hovered) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _toast('تثبيت $label.'),
                      child: Container(
                        width: 23,
                        height: 23,
                        color: hovered ? kHoverYellow : Colors.white,
                        alignment: Alignment.center,
                        child: Transform.rotate(
                          angle: 0.785,
                          child: const Icon(
                            Icons.push_pin,
                            size: 14,
                            color: Color(0xFF111111),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _barGapH),
            child,
          ],
        ),
      ),
    );
  }

  Widget _barAddSection() {
    return SizedBox(
      width: 256,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: _barLabelH,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  SizedBox(
                    width: 137,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Text('إضافة', style: _barLabelStyle),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text('نوع الإضافة', style: _barLabelStyle),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _barGapH),
            SizedBox(
              height: _barControlH,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  _barField(_addPct, 40),
                  _barPercent(),
                  _barField(_addVal, 73),
                  const SizedBox(width: 4),
                  _barTypeDropdown(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barDiscountSection() {
    return SizedBox(
      width: 137,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: _barLabelH,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 7),
                child: Text('خصم', style: _barLabelStyle),
              ),
            ),
          ),
          const SizedBox(height: _barGapH),
          SizedBox(
            height: _barControlH,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                const SizedBox(width: 4),
                _barField(_discPct, 40),
                _barPercent(),
                _barField(_discVal, 73),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barFekkaButton() {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _discountFekka,
        child: Container(
          width: 55,
          height: 50,
          color: hovered ? kHoverYellow : _kSoft,
          alignment: Alignment.center,
          child: const Text(
            'خصم الفكة',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: _kInk, height: 1.3),
          ),
        ),
      ),
    );
  }

  Widget _barTypeDropdown() {
    return Container(
      width: 109,
      height: _barControlH,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF8D8D8D)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _addKind,
                isExpanded: true,
                isDense: true,
                icon: const SizedBox.shrink(),
                dropdownColor: Colors.white,
                padding: const EdgeInsets.only(right: 6),
                style: const TextStyle(fontSize: 12, color: _kInk),
                items: const ['نسبة', 'مبلغ']
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            e,
                            style: const TextStyle(fontSize: 12, color: _kInk),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  _rebuild(() => _addKind = v);
                  _recompute();
                },
              ),
            ),
          ),
          const SizedBox(
            width: 16,
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

  Widget _barDropdown({
    required double width,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    bool boxedCaret = false,
  }) {
    return Container(
      width: width,
      height: _barControlH,
      decoration: const BoxDecoration(
        color: Color(0xFFFDFDFD),
        border: Border(
          top: BorderSide(color: Color(0xFFD2D2D2)),
          bottom: BorderSide(color: Color(0xFFBCBCBC)),
          left: BorderSide(color: Color(0xFFD2D2D2)),
          right: BorderSide(color: Color(0xFFD2D2D2)),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                isDense: true,
                icon: const SizedBox.shrink(),
                dropdownColor: Colors.white,
                alignment: AlignmentDirectional.centerEnd,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                style: const TextStyle(fontSize: 12, color: _kInk),
                items: items
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            e,
                            style: const TextStyle(fontSize: 12, color: _kInk),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
          Container(
            width: 16,
            height: _barControlH,
            decoration: boxedCaret
                ? const BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFD2D2D2))),
                  )
                : null,
            child: const Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barField(TextEditingController controller, double width) {
    return Container(
      width: width,
      height: _barControlH,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFECECEC)),
          bottom: BorderSide(color: Color(0xFF838383)),
          left: BorderSide(color: Color(0xFFE0E0E0)),
          right: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 11.5, color: _kInk),
        decoration: const InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Right brand strip.
  // ---------------------------------------------------------------------------
  Widget _buildRightStrip() {
    return Container(
      width: 136,
      color: _kField,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          Container(
            height: 119,
            width: 120,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/icons/safwa_logo.png',
              width: 120,
              height: 119,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                color: const Color(0xFF43B5DB),
                child: const Icon(
                  Icons.shopping_cart,
                  size: 62,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          HoverBuilder(
            builder: (context, hovered) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toast('أنت الآن في شاشة ${_kind.screenName}.'),
              child: Container(
                width: 120,
                height: 60,
                color: hovered ? kHoverYellow : _kRed,
                alignment: Alignment.center,
                child: Text(
                  _kind.brandLabel,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: hovered ? _kInk : Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 120,
            height: 29,
            color: _kSoft,
            child: Row(
              children: [
                Expanded(
                  child: _stripIcon(
                    Icons.keyboard_double_arrow_right,
                    () => _tbl.nudgeAllWidths(10),
                  ),
                ),
                Container(width: 2, color: Colors.white),
                Expanded(
                  child: _stripIcon(
                    Icons.keyboard_double_arrow_left,
                    () => _tbl.nudgeAllWidths(-10),
                  ),
                ),
                Container(width: 2, color: Colors.white),
                Expanded(child: _stripIconText('K', _showShortcuts)),
                Container(width: 2, color: Colors.white),
                Expanded(
                  child: _stripIcon(Icons.search, () {
                    _searchFocus.requestFocus();
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          HoverBuilder(
            builder: (context, hovered) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _save(resetAfter: true),
              child: Container(
                width: 120,
                height: 115,
                color: hovered ? const Color(0xFFFFD65C) : _kYellow,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(
                      height: 48,
                      child: OverflowBox(
                        maxHeight: 91,
                        child: Icon(
                          Icons.check,
                          size: 91,
                          color: Color(0xFF2F76E8),
                        ),
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'حفظ | جديد',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: _kInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'F12',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: _kInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: HoverBuilder(
              builder: (context, hovered) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openPayment,
                child: Container(
                  width: 120,
                  color: hovered ? kHoverYellow : _kSoft,
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Icon(
                        _kind.isQuotation
                            ? Icons.swap_horiz
                            : Icons.account_balance_wallet,
                        size: 44,
                        color: const Color(0xFF111111),
                      ),
                      Text(
                        _kind.paymentTileLabel,
                        style: const TextStyle(fontSize: 11.5, color: _kInk),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: const Alignment(0.35, 0),
                        child: Container(
                          width: 33,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF2B2B2B),
                              width: 2,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsets.only(left: 2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2B2B2B),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(height: 1, color: _kField),
        ],
      ),
    );
  }

  Widget _stripIcon(IconData icon, VoidCallback onTap) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: hovered ? kHoverYellow : Colors.transparent,
          child: Icon(icon, size: 17, color: const Color(0xFF222222)),
        ),
      ),
    );
  }

  Widget _stripIconText(String text, VoidCallback onTap) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: hovered ? kHoverYellow : Colors.transparent,
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF222222),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Footer.
  // ---------------------------------------------------------------------------
  Widget _buildFooter() {
    return ShopFooterBar(
      actions: ShopFooterActions(
        onSave: () => _save(),
        onNew: _newInvoice,
        onPrint: _print,
        onExport: _exportExcel,
        onShare: _share,
        onDeleteDocument: _deleteInvoice,
        onEditPrices: _editPrices,
        onPrintBarcode: _printBarcode,
        onSettings: _showSettings,
        onClose: _close,
        onShortcuts: _showShortcuts,
        onClear: _deleteInvoice,
      ),
    );
  }

  Widget _dialogButton({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
    double width = 92,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: 30,
          color: hovered ? kHoverYellow : color,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, color: textColor),
          ),
        ),
      ),
    );
  }
}

class _SalesPanelCaption extends StatelessWidget {
  const _SalesPanelCaption(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 20,
    width: double.infinity,
    child: Align(
      alignment: Alignment.centerRight,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: _kRed,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
