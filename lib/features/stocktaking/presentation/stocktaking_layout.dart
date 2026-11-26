part of 'stocktaking_page.dart';

/// Layout widgets for the جرد مخزن screen. Mirrors the شراء screen structure
/// (same blocks, same metrics) while showing only stocktaking content.
extension _StocktakingLayout on _StocktakingPageState {
  // ---------------------------------------------------------------------------
  // Top block: controls on the right, green summary panel on the left.
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
            child: SizedBox(width: 404, child: _buildRightColumn()),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: SizedBox(width: 274, child: _buildMiddleColumn()),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: SizedBox(
              width: 186,
              height: 127,
              child: _buildSummaryPanel(),
            ),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel() {
    return Container(
      color: ShopColors.panelGreen,
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
                  width: 115,
                  color: _kGreen,
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _sessionNo,
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
                  SizedBox(width: 70, child: _timeField()),
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
  // Right column: search row, warehouse bar and notes.
  // ---------------------------------------------------------------------------
  Widget _buildRightColumn() {
    return Column(
      children: [
        _buildSearchRow(),
        const SizedBox(height: 2),
        _buildWarehouseBar(),
        const Spacer(),
        SizedBox(height: 23, child: _buildNotesRow()),
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
            child: ProductSearchField<StocktakingProduct>(
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
          _blankBox(54, _kField, _showCategories),
          const SizedBox(width: 4),
          _blankBox(54, _kYellow, _showQuickList),
          const SizedBox(width: 4),
          _inquiryButton(width: 84),
        ],
      ),
    );
  }

  Widget _buildWarehouseBar() {
    final name = _selectedWarehouse?.name ?? 'المخزن الرئيسي';
    return SizedBox(
      height: 37,
      child: HoverBuilder(
        builder: (context, hovered) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _pickWarehouse,
          child: Container(
            height: 37,
            color: hovered ? kHoverYellow : _kGreen,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 10, left: 10),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                const Icon(
                  Icons.warehouse_outlined,
                  size: 18,
                  color: Color(0xFF248EB2),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _kInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: Color(0xFF248EB2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesRow() {
    return Row(
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
          width: 78,
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
    );
  }

  // ---------------------------------------------------------------------------
  // Middle column: quick chips, counters and the confirm tile.
  // ---------------------------------------------------------------------------
  Widget _buildMiddleColumn() {
    return Column(
      children: [
        SizedBox(
          height: 27,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              _chipButton(
                width: 86,
                chip: '2',
                label: 'الكمية',
                onTap: () => _tableKey.currentState?.editSelected(4),
              ),
              _chipButton(
                width: 117,
                chip: '3',
                label: 'سعر الشراء',
                onTap: () => _tableKey.currentState?.editSelected(5),
              ),
              _chipButton(
                width: 70,
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
              AnimatedBuilder(
                animation: _tbl,
                builder: (context, _) => _greenBox(
                  width: 76,
                  value:
                      '${_tbl.selectedIndex >= 0 ? _tbl.selectedIndex + 1 : 1}',
                  onTap: () {
                    if (_tbl.lines.isNotEmpty) {
                      _tbl.select(0);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _tbl,
                builder: (context, _) => _greenBox(
                  width: 106,
                  value:
                      '${_tbl.selectedIndex >= 0 ? _tbl.lines[_tbl.selectedIndex].qty : 0}',
                  onTap: () => _tableKey.currentState?.editSelected(4),
                ),
              ),
              const SizedBox(width: 8),
              _checkTile(),
              const SizedBox(width: 12),
            ],
          ),
        ),
        const SizedBox(height: 2),
        const SizedBox(height: 57),
      ],
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
      builder: (context, hovered) => Tooltip(
        message: 'حفظ وترحيل الجرد',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _save,
          child: Container(
            width: 64,
            height: 37,
            color: hovered ? kHoverYellow : _kYellow,
            alignment: Alignment.center,
            child: const Icon(Icons.check, size: 26, color: Color(0xFF43B5DB)),
          ),
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

  Widget _inquiryButton({double width = 70}) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _inquiry,
        child: Container(
          width: width,
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
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: _kLine)),
              child: SharedDataGrid<StocktakingLine>(
                key: _tableKey,
                controller: _tbl,
                onMessage: _toast,
                onEditFinished: _pageFocus.requestFocus,
                emptyMessage: 'ابدأ بالبحث عن صنف بالإسم أو بالكود',
                emptyEditMessage: 'أضف صنفاً أولاً ثم عدّل الكمية أو السعر.',
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
              onTap: () => _toast('أنت الآن في شاشة جرد المخزن.'),
              child: Container(
                width: 120,
                height: 60,
                color: hovered ? kHoverYellow : _kTeal,
                alignment: Alignment.center,
                child: Text(
                  'جرد مخزن',
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
            child: Container(
              width: 120,
              color: _kSoft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12, right: 10, left: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      textDirection: TextDirection.rtl,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _stripSmallButton(
                          icon: Icons.print,
                          tooltip: 'طباعة مستند الجرد',
                          onTap: _print,
                        ),
                        const SizedBox(width: 10),
                        _applyToggle(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(height: 1, color: _kField),
        ],
      ),
    );
  }

  Widget _applyToggle() {
    return Tooltip(
      message: _applyStock
          ? 'ترحيل المخزون عند الحفظ: مفعّل'
          : 'ترحيل المخزون عند الحفظ: متوقف',
      child: HoverBuilder(
        builder: (context, hovered) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleApplyStock,
          child: Container(
            width: 34,
            height: 17,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: hovered ? kHoverYellow : Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFF2B2B2B), width: 1.6),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 120),
              alignment: _applyStock
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: _applyStock
                      ? const Color(0xFF43B5DB)
                      : const Color(0xFF2B2B2B),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stripSmallButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: HoverBuilder(
        builder: (context, hovered) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 22,
            height: 22,
            color: hovered ? kHoverYellow : Colors.transparent,
            child: Icon(icon, size: 17, color: const Color(0xFF222222)),
          ),
        ),
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
  // License / information bar.
  // ---------------------------------------------------------------------------
  Widget _buildLicenseBar() {
    return Container(
      height: 23,
      color: _kYellow,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Text(
              'هذه نسخة تجريبية غير مرخصة. للتعرّف على برنامج Safwa ومدى ملاءمته لمشروعك، '
              'ستتوقف بعد فترة من الاستخدام.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8.6, color: _kInk),
            ),
          ),
          const SizedBox(width: 8),
          HoverBuilder(
            builder: (context, hovered) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showSubscription,
              child: Container(
                width: 91,
                height: 17,
                color: hovered ? const Color(0xFFFFF4C9) : Colors.white,
                alignment: Alignment.center,
                child: const Text(
                  'اشتراك',
                  style: TextStyle(fontSize: 9.5, color: Color(0xFF2D6CDF)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '0%',
            style: TextStyle(fontSize: 9.5, color: Color(0xFF2D6CDF)),
          ),
          const SizedBox(width: 3),
          const Text(
            'نسبة الإستخدام',
            style: TextStyle(fontSize: 9.5, color: _kInk),
          ),
          const SizedBox(width: 2),
        ],
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
        onNew: _newSession,
        onPrint: _print,
        onExport: _exportExcel,
        onShare: _share,
        onDeleteDocument: _deleteDocument,
        onEditPrices: _editPrices,
        onPrintBarcode: _printBarcode,
        onSettings: _showSettings,
        onClose: _close,
        onShortcuts: _showShortcuts,
        onClear: _deleteDocument,
        clearLabel: 'مسح المستند',
        deleteLabel: 'حذف المستند',
        printMenuLabel: 'طباعة المستند',
        shareMenuLabel: 'نسخ نص المستند',
      ),
    );
  }
}
