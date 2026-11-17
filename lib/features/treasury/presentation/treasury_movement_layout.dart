part of 'treasury_movement_page.dart';

extension _TreasuryMovementLayout on _TreasuryMovementPageState {
  // ---------------------------------------------------------------------------
  // Toolbar.
  // ---------------------------------------------------------------------------
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
      child: SizedBox(
        height: 32,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            const Text(
              'حركة الخزينة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _kPanelGreen,
              ),
            ),
            const SizedBox(width: 12),
            if (_loading)
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kPanelGreen,
                ),
              )
            else
              Flexible(
                child: Text(
                  _status.isEmpty ? 'جاهز' : _status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            const Spacer(),
            _toolbarButton(
              'تحديث',
              Icons.refresh,
              () => _refresh(initial: true),
            ),
            const SizedBox(width: 6),
            _toolbarButton('إغلاق', Icons.power_settings_new, _close),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton(String label, IconData icon, VoidCallback onTap) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 118,
          height: 30,
          decoration: BoxDecoration(
            color: hovered ? kHoverYellow : const Color(0xFFF6F6F6),
            border: Border.all(color: const Color(0xFFCFCFCF)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.rtl,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, color: _kInk)),
              const SizedBox(width: 7),
              Icon(icon, size: 16, color: const Color(0xFF333333)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filters.
  // ---------------------------------------------------------------------------
  Widget _buildFilterPanel() {
    return Container(
      height: 66,
      margin: const EdgeInsets.fromLTRB(6, 3, 6, 3),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD4D4D4)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _filterBlock(
            label: 'الخزينة',
            width: 118,
            child: _treasuryDropdown(),
          ),
          _filterGap(),
          _filterBlock(label: 'الفترة', width: 98, child: _periodDropdown()),
          _filterGap(),
          _filterBlock(
            label: 'من تاريخ',
            width: 92,
            child: _dateFilter(_fromDate),
          ),
          _filterGap(),
          _filterBlock(
            label: 'من وقت',
            width: 64,
            child: _timeFilter(_fromTime),
          ),
          _filterGap(),
          _filterBlock(
            label: 'إلى تاريخ',
            width: 92,
            child: _dateFilter(_toDate),
          ),
          _filterGap(),
          _filterBlock(
            label: 'إلى وقت',
            width: 64,
            child: _timeFilter(_toTime),
          ),
          _filterGap(),
          _filterBlock(
            label: 'رقم الحركة / المرجع',
            width: 108,
            child: _textFilter(
              _numberFilter,
              onSubmitted: (_) => _loadReport(),
            ),
          ),
          _filterGap(),
          Expanded(
            child: _filterBlock(
              label: 'ملاحظات',
              child: _textFilter(
                _notesFilter,
                onSubmitted: (_) => _loadReport(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
      child: SizedBox(
        height: 32,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            _filterAction(
              'عرض التقرير',
              _kPanelGreen,
              Icons.search,
              _viewReport,
              width: 132,
              ink: Colors.white,
            ),
            const SizedBox(width: 6),
            _filterAction(
              'طباعة',
              const Color(0xFFE6E6E6),
              Icons.print_outlined,
              _print,
              width: 84,
            ),
            const SizedBox(width: 6),
            _filterAction(
              '',
              _kBlue,
              Icons.share,
              _share,
              width: 48,
              ink: Colors.white,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _filterGap() => const SizedBox(width: 4);

  Widget _filterBlock({
    required String label,
    required Widget child,
    double? width,
  }) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 14,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF555555)),
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(height: 26, child: child),
      ],
    );
    if (width == null) return column;
    return SizedBox(width: width, child: column);
  }

  Widget _filterBox({required Widget child, Color color = Colors.white}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: const Color(0xFFB8B8B8)),
      ),
      child: child,
    );
  }

  Widget _treasuryDropdown() {
    final items = <DropdownMenuItem<int>>[
      const DropdownMenuItem<int>(
        value: 0,
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            'كل الخزائن',
            style: TextStyle(fontSize: 11, color: _kInk),
          ),
        ),
      ),
      for (final treasury in _treasuries)
        DropdownMenuItem<int>(
          value: treasury.id,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              treasury.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: _kInk),
            ),
          ),
        ),
    ];
    return _filterBox(
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _treasuryFilter,
                isExpanded: true,
                isDense: true,
                icon: const SizedBox.shrink(),
                dropdownColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                style: const TextStyle(fontSize: 11, color: _kInk),
                items: items,
                onChanged: (value) {
                  if (value == null) return;
                  _rebuild(() => _treasuryFilter = value);
                  _loadReport();
                },
              ),
            ),
          ),
          const SizedBox(
            width: 15,
            child: Icon(
              Icons.keyboard_arrow_down,
              size: 15,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodDropdown() {
    return _filterBox(
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _period,
                isExpanded: true,
                isDense: true,
                icon: const SizedBox.shrink(),
                dropdownColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                style: const TextStyle(fontSize: 11, color: _kInk),
                items: [
                  for (final period in _TreasuryMovementPageState._periods)
                    DropdownMenuItem<String>(
                      value: period,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          period,
                          style: const TextStyle(fontSize: 11, color: _kInk),
                        ),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) _applyPeriod(value);
                },
              ),
            ),
          ),
          const SizedBox(
            width: 15,
            child: Icon(
              Icons.keyboard_arrow_down,
              size: 15,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateFilter(TextEditingController controller) {
    return _filterBox(
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              onSubmitted: (_) => _loadReport(),
              style: const TextStyle(fontSize: 10.5, color: _kInk),
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
            onTap: () => _pickDate(controller),
            child: const SizedBox(
              width: 20,
              child: Icon(
                Icons.calendar_today_outlined,
                size: 12,
                color: Color(0xFF555555),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeFilter(TextEditingController controller) {
    return _filterBox(
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              onSubmitted: (_) => _loadReport(),
              style: const TextStyle(fontSize: 10.5, color: _kInk),
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
            onTap: () => _pickTime(controller),
            child: const SizedBox(
              width: 19,
              child: Icon(
                Icons.access_time,
                size: 12,
                color: Color(0xFF555555),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textFilter(
    TextEditingController controller, {
    ValueChanged<String>? onSubmitted,
  }) {
    return _filterBox(
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 11, color: _kInk),
        decoration: const InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        ),
      ),
    );
  }

  Widget _filterAction(
    String label,
    Color color,
    IconData icon,
    VoidCallback onTap, {
    required double width,
    Color ink = _kInk,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: 28,
          color: hovered ? kHoverYellow : color,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.rtl,
            children: [
              if (label.isNotEmpty) ...[
                Text(label, style: TextStyle(fontSize: 10.5, color: ink)),
                const SizedBox(width: 6),
              ],
              Icon(icon, size: 15, color: ink),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Summary cards.
  // ---------------------------------------------------------------------------
  Widget _buildCards() {
    final report = _report;
    final net = report?.netMovement ?? 0;
    final current = report?.currentBalance ?? 0;
    final count = report == null ? 0 : report.movements.length - 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
      child: SizedBox(
        height: 56,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            if (report != null) ...[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    report.treasuryName,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'من ${_dateText(report.filters.from)} '
                    '${_timeText(report.filters.from)} إلى '
                    '${_dateText(report.filters.to)} '
                    '${_timeText(report.filters.to)}',
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count حركة • ${report.summary.length - 1} خزينة',
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
            ],
            const Spacer(),
            _summaryCard(
              width: 210,
              label: 'رصيد الخزينة الحالي',
              value: current,
              green: true,
            ),
            const SizedBox(width: 7),
            _summaryCard(
              width: 228,
              label: 'صافي حركة الخزينة للفترة',
              value: net,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard({
    required double width,
    required String label,
    required int value,
    bool green = false,
  }) {
    final background = green ? _kPanelGreen : _kYellow;
    final labelColor = green
        ? const Color(0xFFE8FFF2)
        : const Color(0xFF5C4500);
    final ink = green ? Colors.white : _kInk;
    return Container(
      width: width,
      height: 56,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: labelColor),
          ),
          const SizedBox(height: 2),
          Text(
            _money(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tabs.
  // ---------------------------------------------------------------------------
  Widget _buildTabs() {
    final summaryCount = (_report?.summary.length ?? 1) - 1;
    final movementCount = (_report?.movements.length ?? 2) - 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
      child: SizedBox(
        height: 32,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            _tabCell(0, 'ملخص', summaryCount),
            const SizedBox(width: 3),
            _tabCell(1, 'حركات', movementCount),
            const Spacer(),
            const Text(
              'اسحب حدود العناوين لتغيير عرض الأعمدة • التمرير داخل الجدول',
              style: TextStyle(fontSize: 9.5, color: Color(0xFF777777)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabCell(int index, String label, int count) {
    final active = _tab == index;
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_tab == index) return;
          _rebuild(() => _tab = index);
          _pageFocus.requestFocus();
        },
        child: Container(
          width: 136,
          height: 32,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF357DF0)
                : (hovered ? kHoverYellow : Colors.white),
            border: Border.all(
              color: active ? const Color(0xFF357DF0) : const Color(0xFFD0D0D0),
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          alignment: Alignment.center,
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: _kInk,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Table + action rail.
  // ---------------------------------------------------------------------------
  Widget _buildTableArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
      child: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 200, child: _buildRail()),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: _kLine),
                color: Colors.white,
              ),
              child: _tab == 0
                  ? RepaintBoundary(
                      key: _summaryBoundaryKey,
                      child: SharedDataGrid<TreasurySummaryRow>(
                        key: _summaryGridKey,
                        controller: _summaryTable,
                        onMessage: _toast,
                        onEditFinished: _pageFocus.requestFocus,
                        emptyMessage: 'لا توجد خزائن مطابقة للفلاتر المحددة.',
                        emptyEditMessage: 'لا توجد صفوف قابلة للتعديل.',
                      ),
                    )
                  : SharedDataGrid<TreasuryMovement>(
                      key: _movementGridKey,
                      controller: _movementTable,
                      onMessage: _toast,
                      onEditFinished: _pageFocus.requestFocus,
                      emptyMessage:
                          'لا توجد حركات مطابقة للفترة والفلاتر المحددة.',
                      emptyEditMessage: 'لا توجد حركات قابلة للتعديل.',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRail() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(3),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _railBigTile(
                    'قبض',
                    Icons.add_circle_outline,
                    () => _openReceive(),
                    color: _kBlue,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _railBigTile(
                    'صرف',
                    Icons.remove_circle_outline,
                    () => _openExpense(),
                    color: _kBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _railBigTile(
                    'حذف',
                    Icons.close,
                    _deleteSelected,
                    color: _kRed,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _railBigTile(
                    'تعديل',
                    Icons.edit_outlined,
                    _editSelected,
                    color: const Color(0xFFD9A400),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            _railWideTile(
              'تحويل من خزينة لأخرى',
              Icons.swap_horiz,
              () => _openTransfer(),
              color: _kBlue,
            ),
            const SizedBox(height: 4),
            _railWideTile(
              'إدخال حركة الخزينة اليومية',
              Icons.payments_outlined,
              _openDailyEntry,
              color: const Color(0xFF1F8A3C),
            ),
            const SizedBox(height: 4),
            _railWideTile(
              'تحليل المصروفات',
              Icons.receipt_long_outlined,
              () => _openAnalysis(expenses: true),
              color: const Color(0xFFD9A400),
            ),
            const SizedBox(height: 4),
            _railWideTile(
              'تحليل المقبوضات',
              Icons.receipt_long_outlined,
              () => _openAnalysis(expenses: false),
              color: const Color(0xFFD9A400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _railBigTile(
    String label,
    IconData icon,
    VoidCallback onTap, {
    required Color color,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 64,
          color: hovered ? kHoverYellow : const Color(0xFFF2F2F2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 23, color: color),
              const SizedBox(height: 5),
              Text(label, style: const TextStyle(fontSize: 11.5, color: _kInk)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _railWideTile(
    String label,
    IconData icon,
    VoidCallback onTap, {
    required Color color,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 41,
          color: hovered ? kHoverYellow : const Color(0xFFF2F2F2),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 7),
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

  // ---------------------------------------------------------------------------
  // Footer.
  // ---------------------------------------------------------------------------
  Widget _buildFooter() {
    return Container(
      height: 44,
      color: ShopColors.footer,
      padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          _footerButton('F5 تحديث', Icons.refresh, _refresh),
          const SizedBox(width: 4),
          _footerButton('F4 طباعة', Icons.print, _print),
          const SizedBox(width: 4),
          _footerIconButton(_excelGlyph(), _exportExcel),
          const SizedBox(width: 4),
          _footerIconButton(
            const Icon(Icons.share, size: 17, color: ShopColors.footerBlue),
            _share,
          ),
          const SizedBox(width: 4),
          _footerButton(
            'تحليل المصروفات',
            Icons.pie_chart_outline,
            () => _openAnalysis(expenses: true),
          ),
          const SizedBox(width: 4),
          _footerButton(
            'تحليل المقبوضات',
            Icons.receipt_long_outlined,
            () => _openAnalysis(expenses: false),
          ),
          const SizedBox(width: 4),
          _footerButton('إغلاق', Icons.power_settings_new, _close),
          const Spacer(),
          Text(
            _status.isEmpty ? 'حركة الخزينة — تقرير تفاعلي' : _status,
            style: const TextStyle(fontSize: 10, color: Color(0xFFCFCFCF)),
          ),
        ],
      ),
    );
  }

  Widget _footerButton(String label, IconData icon, VoidCallback onTap) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          color: hovered ? kHoverYellow : _kSoft,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(icon, size: 15, color: ShopColors.footerBlue),
              const SizedBox(width: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: const TextStyle(fontSize: 10.5, color: _kInk),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerIconButton(Widget child, VoidCallback onTap) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          color: hovered ? kHoverYellow : _kSoft,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  Widget _excelGlyph() {
    return Container(
      width: 16,
      height: 16,
      color: const Color(0xFF087425),
      alignment: Alignment.center,
      child: const Text(
        'x',
        style: TextStyle(
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
