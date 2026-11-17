part of 'purchases_page.dart';

/// Layout widgets for the شراء screen. Kept in an extension so the state class
/// stays readable while all pieces still share the same private state.
extension _PurchaseLayout on _PurchasesPageState {
  // ---------------------------------------------------------------------------
  // Top block: controls on the right, green invoice panel on the left.
  // ---------------------------------------------------------------------------
  Widget _buildTopBlock() {
    return SizedBox(
      height: 136,
      child: Row(
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
            child: SizedBox(
              width: 149,
              height: 127,
              child: _buildInvoicePanel(),
            ),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildInvoicePanel() {
    return Container(
      color: _kPanelGreen,
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
                  color: _kGreen,
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
            child: Center(
              child: ValueListenableBuilder<int>(
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
        SizedBox(height: 57, child: _buildFieldsColumn()),
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
          Expanded(
            child: ProductSearchField<PurchaseProduct>(
              key: _searchKey,
              controller: _search,
              focusNode: _searchFocus,
              lookup: _repo.findByBarcode,
              search: _repo.searchProducts,
              onAdd: _onSearchPicked,
              onMessage: _toast,
              onSubmit: _submitSearch,
            ),
          ),
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

  Widget _buildAccountRow() {
    return SizedBox(
      height: 37,
      child: HoverBuilder(
        builder: (context, hovered) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _pickAccount,
          child: Container(
            height: 37,
            color: hovered ? _kRedHover : _kRed,
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
                onTap: () => _tableKey.currentState?.editSelected(4),
              ),
              const SizedBox(width: 5),
              _chipButton(
                width: 82,
                chip: '3',
                label: 'سعر الشراء',
                onTap: () => _tableKey.currentState?.editSelected(5),
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
                  onTap: () => _tableKey.currentState?.editSelected(4),
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

  Widget _payTabCell(int index) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _rebuild(() => _payTab = index),
        child: Container(
          width: 46,
          height: 51,
          decoration: BoxDecoration(
            color: _payTab == index
                ? _kBlue
                : (hovered ? kHoverYellow : _kSoft),
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
              SizedBox(
                width: 80,
                height: 23,
                child: TextButton.icon(
                  onPressed: _tbl.locked ? null : _editCustomFields,
                  icon: const Icon(Icons.tune, size: 13),
                  label: Text(
                    'حقول ${_customFieldValues.length}',
                    style: const TextStyle(fontSize: 10),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

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
          height: 27,
          color: hovered ? kHoverYellow : Colors.white,
          padding: const EdgeInsets.only(right: 2),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 23,
                height: 25,
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

  Widget _checkTile() {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openPayment,
        child: Container(
          width: 57,
          height: 37,
          color: hovered ? kHoverYellow : _kYellow,
          alignment: Alignment.center,
          child: const Icon(Icons.check, size: 26, color: Color(0xFF42B460)),
        ),
      ),
    );
  }

  Widget _greenBox({
    required double width,
    required String value,
    required VoidCallback onTap,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: 37,
          color: hovered ? kHoverYellow : _kGreen,
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
              child: SharedDataGrid<PurchaseLine>(
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
      onQty: () => _tableKey.currentState?.editSelected(4),
      onPrice: () => _tableKey.currentState?.editSelected(5),
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
              'assets/icons/logo.png',
              width: 120,
              height: 119,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                color: const Color(0xFF27B04C),
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
              onTap: () => _toast('أنت الآن في شاشة الشراء.'),
              child: Container(
                width: 120,
                height: 60,
                color: hovered ? kHoverYellow : _kRed,
                alignment: Alignment.center,
                child: Text(
                  'شراء',
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
                      const Icon(
                        Icons.account_balance_wallet,
                        size: 44,
                        color: Color(0xFF111111),
                      ),
                      const Text(
                        'سداد F11',
                        style: TextStyle(fontSize: 11.5, color: _kInk),
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
