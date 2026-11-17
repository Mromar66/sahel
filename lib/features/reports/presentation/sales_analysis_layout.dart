part of 'sales_analysis_page.dart';

const double _kFilterHeight = 21;
const double _kDataRowHeight = 25;
const double _kHeaderHeight = 44;
const double _kFooterHeight = 22;
const double _kGutterWidth = 137;
const double _kTableRightInset = 38;
const Color _kHeaderLine = Color(0xFFC4C4C4);
const Color _kGridLine = Color(0xFFE9E9E9);
const Color _kTabRest = Color(0xFFF2F2F2);
const Color _kTabEdge = Color(0xFFE1E1E1);
const Color _kTabBlueLine = Color(0xFFB7CFF5);

/// One column of the 11-column sales grid, laid out from right to left.
class _SalesColumn {
  const _SalesColumn(this.label, this.width, this.field);

  final String label;
  final double width;
  final _SortField field;
}

const List<_SalesColumn> _salesColumns = [
  _SalesColumn('فواتير', 65, _SortField.invoices),
  _SalesColumn('الكمية\nالحالية', 65, _SortField.currentQty),
  _SalesColumn('الكمية', 65, _SortField.qty),
  _SalesColumn('الإجمالي', 81, _SortField.total),
  _SalesColumn('التكلفة', 81, _SortField.cost),
  _SalesColumn('الربح', 81, _SortField.profit),
  _SalesColumn('الخصم', 81, _SortField.discount),
  _SalesColumn('نسبة الربح\nللإجمالي', 81, _SortField.profitToTotal),
  _SalesColumn('نسبة الربح\nللتكلفة', 81, _SortField.profitToCost),
  _SalesColumn('نسبة الإجمالي\nللمبيعات', 81, _SortField.totalToSales),
  _SalesColumn('نسبة الربح\nلإجمالي الربح', 81, _SortField.profitToProfit),
];

/// X coordinates of every vertical grid line, measured from the left edge of
/// the design canvas (1018 px). The blank identity gutter is 137 px wide.
const List<double> _gridLines = [
  137,
  218,
  299,
  380,
  461,
  542,
  623,
  704,
  785,
  850,
  915,
  980,
];

extension _SalesAnalysisLayout on _SalesAnalysisPageState {
  // ---------------------------------------------------------------------------
  // Title bar: report title, yellow hint banner, close button.
  // ---------------------------------------------------------------------------
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      child: SizedBox(
        height: 32,
        child: Stack(
          children: [
            Positioned(
              right: 10,
              top: 3,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Text(
                    'تقرير تحليل المبيعات',
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
              child: Align(alignment: Alignment.topLeft, child: _closeButton()),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: IgnorePointer(
                  child: Container(
                    width: 400,
                    height: 25,
                    color: _kYellow,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: const Text(
                      'حدد نوع التقرير ثم اضغط عرض التقرير .. لديك أدوات كثيرة للبحث',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF353535),
                        height: 1.1,
                      ),
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

  Widget _closeButton() {
    return HoverBuilder(
      builder: (context, hovered) => Tooltip(
        message: 'إغلاق التقرير (Esc)',
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
                Text('إغلاق', style: TextStyle(fontSize: 11.5, color: _kInk)),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Green dimension tabs.
  // ---------------------------------------------------------------------------
  Widget _buildGroupTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Container(
        height: 26,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _kTabBlueLine)),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (
              var index = 0;
              index < SalesAnalysisGroup.values.length;
              index++
            ) ...[
              if (index > 0) const SizedBox(width: 2),
              Expanded(child: _groupTab(SalesAnalysisGroup.values[index])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _groupTab(SalesAnalysisGroup group) {
    final active = _group == group;
    return HoverBuilder(
      builder: (context, hovered) => Tooltip(
        message: group.isUnavailable
            ? '${group.label} — غير متوفر في قاعدة البيانات الحالية'
            : 'تجميع التقرير حسب ${group.label}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _setGroup(group),
          child: Container(
            height: 26,
            decoration: BoxDecoration(
              color: active
                  ? _kGreen
                  : hovered
                  ? const Color(0xFFE6F6EC)
                  : _kTabRest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              border: Border(
                top: BorderSide(
                  color: active ? const Color(0xFF23A846) : _kTabEdge,
                  width: 2,
                ),
              ),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              group.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.6,
                color: active ? Colors.white : _kInk,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter canvas. Positions are measured from the 1274-wide reference and
  // scaled by 0.8 so the exact arrangement survives in the 1018 canvas.
  // ---------------------------------------------------------------------------
  Widget _buildFilters() {
    return SizedBox(
      height: 121,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Row 1 — period, to-date, from-date, warehouse.
          Positioned(left: 904, top: 0, child: _periodCombo()),
          Positioned(
            left: 795,
            top: 0,
            child: _dateField(_toDate, tooltip: 'إلى تاريخ'),
          ),
          Positioned(left: 769, top: 0, child: _calendarButton(_toDate)),
          const Positioned(
            left: 688,
            top: 5,
            width: 72,
            child: _FilterLabel('إلى التاريخ', align: TextAlign.center),
          ),
          Positioned(
            left: 562,
            top: 0,
            child: _dateField(_fromDate, tooltip: 'من تاريخ'),
          ),
          Positioned(left: 536, top: 0, child: _calendarButton(_fromDate)),
          const Positioned(
            left: 418,
            top: 5,
            width: 48,
            child: _FilterLabel('المخزن', align: TextAlign.center),
          ),
          Positioned(
            left: 249,
            top: 0,
            child: _optionCombo(
              width: 128,
              options: _warehouses,
              value: _warehouseId,
              onChanged: _setWarehouse,
              emptyMessage: 'لا توجد مخازن مسجلة.',
            ),
          ),
          Positioned(
            left: 225,
            top: 0,
            child: _clearButton(
              tooltip: 'كل المخازن',
              onTap: () => _setWarehouse(null),
            ),
          ),

          // Row 2 — account, payment method, user.
          const Positioned(
            left: 930,
            top: 32,
            width: 76,
            child: _FilterLabel('الحساب', align: TextAlign.right),
          ),
          Positioned(left: 805, top: 27, child: _accountField()),
          Positioned(
            left: 775,
            top: 27,
            child: _clearButton(
              tooltip: 'كل الحسابات',
              onTap: () => _setAccount(null),
            ),
          ),
          Positioned(
            left: 747,
            top: 27,
            child: Tooltip(
              message: 'غير متاح',
              child: Container(
                width: 23,
                height: _kFilterHeight,
                color: _kSoft,
              ),
            ),
          ),
          const Positioned(
            left: 676,
            top: 32,
            width: 66,
            child: _FilterLabel('طريقة السداد', align: TextAlign.center),
          ),
          Positioned(left: 518, top: 27, width: 132, child: _paymentRadios()),
          const Positioned(
            left: 374,
            top: 32,
            width: 92,
            child: _FilterLabel('المستخدم', align: TextAlign.right),
          ),
          Positioned(
            left: 260,
            top: 27,
            child: _optionCombo(
              width: 100,
              options: _users,
              value: _userId,
              onChanged: _setUser,
              emptyMessage:
                  'لا توجد بيانات مستخدمين في قاعدة البيانات الحالية.',
            ),
          ),
          Positioned(
            left: 233,
            top: 27,
            child: _clearButton(
              tooltip: 'كل المستخدمين',
              onTap: () => _setUser(null),
            ),
          ),

          // Row 3 — sales representative.
          const Positioned(
            left: 918,
            top: 59,
            width: 88,
            child: _FilterLabel('مندوب البيع', align: TextAlign.right),
          ),
          Positioned(
            left: 805,
            top: 54,
            child: _optionCombo(
              width: 119,
              options: _salesReps,
              value: _salesRepId,
              onChanged: _setSalesRep,
              emptyMessage:
                  'لا توجد بيانات مندوبي بيع في قاعدة البيانات الحالية.',
            ),
          ),
          Positioned(
            left: 775,
            top: 54,
            child: _clearButton(
              tooltip: 'كل مندوبي البيع',
              onTap: () => _setSalesRep(null),
            ),
          ),

          // Row 4 — category. The reference places its label above the field.
          const Positioned(
            left: 857,
            top: 76,
            width: 72,
            child: _FilterLabel('التصنيف', align: TextAlign.right),
          ),
          Positioned(left: 840, top: 99, child: _categoryCombo()),
          Positioned(
            left: 810,
            top: 99,
            child: _clearButton(
              tooltip: 'كل التصنيفات',
              onTap: () => _setCategory(null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodCombo() {
    return Container(
      width: 101,
      height: _kFilterHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC9C9C9)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _period,
          isExpanded: true,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 12,
            color: Color(0xFF6B6B6B),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.zero,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          style: const TextStyle(fontSize: 10.5, color: _kInk),
          items: [
            for (final period in _SalesAnalysisPageState._periods)
              DropdownMenuItem<String>(
                value: period,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    period,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: _kInk),
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

  Widget _dateField(
    TextEditingController controller, {
    required String tooltip,
  }) {
    return Tooltip(
      message: '$tooltip (يوم/شهر/سنة)',
      child: Container(
        width: 99,
        height: _kFilterHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFC9C9C9)),
        ),
        child: Center(
          child: TextField(
            controller: controller,
            textAlign: TextAlign.right,
            textDirection: TextDirection.ltr,
            onSubmitted: (_) => _loadReport(),
            style: const TextStyle(fontSize: 10.5, color: _kInk, height: 1.1),
            decoration: const InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 2, right: 5),
              constraints: BoxConstraints(minHeight: 0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _calendarButton(TextEditingController controller) {
    return HoverBuilder(
      builder: (context, hovered) => Tooltip(
        message: 'اختيار التاريخ',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _pickDate(controller),
          child: Container(
            width: 23,
            height: _kFilterHeight,
            color: hovered ? kHoverYellow : const Color(0xFFF0F0F0),
            alignment: Alignment.center,
            child: const Icon(
              Icons.calendar_today_outlined,
              size: 12,
              color: Color(0xFF8A8A8A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionCombo({
    required double width,
    required List<SalesAnalysisOption> options,
    required int? value,
    required ValueChanged<int?> onChanged,
    required String emptyMessage,
  }) {
    final selected = options.any((option) => option.id == value) ? value : null;
    final box = Container(
      width: width,
      height: _kFilterHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC9C9C9)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.centerRight,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selected,
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
          style: const TextStyle(fontSize: 10.5, color: _kInk),
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
                    style: const TextStyle(fontSize: 10.5, color: _kInk),
                  ),
                ),
              ),
          ],
          onChanged: options.isEmpty ? null : onChanged,
        ),
      ),
    );
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

  Widget _accountField() {
    final name = _optionName(_accounts, _accountId);
    return PopupMenuButton<int>(
      tooltip: 'اختيار الحساب',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 2),
      color: Colors.white,
      onSelected: (value) => _setAccount(value == 0 ? null : value),
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
        width: 119,
        height: _kFilterHeight,
        padding: const EdgeInsets.only(right: 5, left: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFC9C9C9)),
        ),
        alignment: Alignment.centerRight,
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, color: _kInk),
        ),
      ),
    );
  }

  Widget _categoryCombo() {
    final selected = _categories.any((option) => option.id == _categoryId)
        ? _categoryId
        : null;
    return Container(
      width: 89,
      height: _kFilterHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC9C9C9)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selected,
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
          style: const TextStyle(fontSize: 10.5, color: _kInk),
          items: [
            for (final option in _categories)
              DropdownMenuItem<int>(
                value: option.id,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    option.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: _kInk),
                  ),
                ),
              ),
          ],
          onChanged: _setCategory,
        ),
      ),
    );
  }

  Widget _paymentRadios() {
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _radioOption('الكل', SalesAnalysisFilters.paymentAll),
        _radioOption('نقدي', SalesAnalysisFilters.paymentCash),
        _radioOption('أجل', SalesAnalysisFilters.paymentCredit),
      ],
    );
  }

  Widget _radioOption(String label, String value) {
    final selected = _paymentMethod == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _setPaymentMethod(value),
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
          Text(label, style: const TextStyle(fontSize: 10.5, color: _kInk)),
        ],
      ),
    );
  }

  Widget _clearButton({required String tooltip, required VoidCallback onTap}) {
    return HoverBuilder(
      builder: (context, hovered) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 23,
            height: _kFilterHeight,
            color: hovered ? const Color(0xFFDCDCDC) : _kSoft,
            alignment: Alignment.center,
            child: const Icon(Icons.close, size: 14, color: Color(0xFF979797)),
          ),
        ),
      ),
    );
  }

  String _optionName(List<SalesAnalysisOption> options, int? id) {
    if (id == null) return '';
    for (final option in options) {
      if (option.id == id) return option.name;
    }
    return '';
  }

  // ---------------------------------------------------------------------------
  // Report action buttons.
  // ---------------------------------------------------------------------------
  Widget _buildActions() {
    return SizedBox(
      height: 50,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, right: 108),
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _actionButton(
              'عرض تقرير مبسط',
              Icons.search,
              () => _setMode(SalesAnalysisMode.simple),
              width: 132,
              background: _kYellow,
              iconSize: 17,
            ),
            const SizedBox(width: 20),
            _actionButton(
              'عرض تقرير تفصيلي',
              Icons.search,
              () => _setMode(SalesAnalysisMode.detailed),
              width: 135,
              background: _kSoft,
              iconSize: 17,
            ),
            const SizedBox(width: 8),
            _actionButton(
              'طباعة',
              Icons.print,
              _print,
              width: 90,
              background: _kSoft,
              iconSize: 19,
            ),
            const SizedBox(width: 8),
            _actionButton(
              '',
              Icons.share,
              _share,
              width: 35,
              background: _kSoft,
              iconSize: 16,
              iconColor: const Color(0xFF2D70DB),
            ),
          ],
        ),
      ),
    );
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
        message: label.isEmpty ? 'مشاركة / تصدير (F11)' : label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: width,
            height: 30,
            color: hovered ? kHoverYellow : background,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              textDirection: TextDirection.rtl,
              children: [
                Icon(icon, size: iconSize, color: iconColor ?? _kInk),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.2, color: _kInk),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Report grid.
  // ---------------------------------------------------------------------------
  Widget _buildReportTable() {
    final report = _report;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(child: _buildTableBody(report)),
          _buildTableFooter(report?.totals),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.only(right: _kTableRightInset),
      child: SizedBox(
        height: _kHeaderHeight,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: _kHeaderLine)),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              for (final column in _salesColumns) _headerCell(column),
              const SizedBox(width: _kGutterWidth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCell(_SalesColumn column) {
    final sorted = _sortField == column.field;
    return HoverBuilder(
      builder: (context, hovered) => Tooltip(
        message: 'ترتيب حسب ${column.label.replaceAll('\n', ' ')}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _sortBy(column.field),
          child: Container(
            width: column.width,
            height: _kHeaderHeight,
            decoration: BoxDecoration(
              color: hovered ? const Color(0xFFD5D5D5) : _kHeader,
              border: const Border(
                left: BorderSide(color: _kHeaderLine),
                top: BorderSide(color: Color(0xFFD2D2D2)),
                bottom: BorderSide(color: _kHeaderLine),
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Center(
                      child: Text(
                        column.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10.3,
                          height: 1.18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B3B3B),
                        ),
                      ),
                    ),
                  ),
                ),
                if (sorted)
                  Positioned(
                    left: 2,
                    top: 2,
                    child: Icon(
                      _sortAscending
                          ? Icons.arrow_drop_up
                          : Icons.arrow_drop_down,
                      size: 10,
                      color: const Color(0xFF707070),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableBody(SalesAnalysisReport? report) {
    final rows = report?.rows ?? const <SalesAnalysisRow>[];
    final message = report?.unavailableReason;
    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _GridPainter())),
        ),
        if (message != null)
          Positioned.fill(
            child: Center(
              child: Container(
                width: 430,
                padding: const EdgeInsets.all(14),
                color: const Color(0xFFF7F7F7),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.5,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
            ),
          )
        else if (rows.isNotEmpty)
          Positioned.fill(
            child: ListView.builder(
              controller: _rowsScroll,
              padding: EdgeInsets.zero,
              itemExtent: _kDataRowHeight,
              itemCount: rows.length,
              itemBuilder: (context, index) => _dataRow(rows[index]),
            ),
          ),
        Positioned(
          right: 41,
          top: 2,
          bottom: 2,
          width: 8,
          child: _scrollThumb(),
        ),
      ],
    );
  }

  Widget _dataRow(SalesAnalysisRow row) {
    return HoverBuilder(
      builder: (context, hovered) => Container(
        color: hovered ? const Color(0x1431BB68) : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.only(right: _kTableRightInset),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              for (final column in _salesColumns)
                _bodyCell(_bodyValue(row, column.field), column.width),
              SizedBox(
                width: _kGutterWidth,
                child: Tooltip(
                  message: row.subtitle.isEmpty ? row.label : row.subtitle,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, left: 6),
                      child: Text(
                        row.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 10.7,
                          height: 1.1,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF262626),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bodyCell(String value, double width) {
    return SizedBox(
      width: width,
      height: _kDataRowHeight,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, height: 1.1, color: _kInk),
          ),
        ),
      ),
    );
  }

  Widget _buildTableFooter(SalesAnalysisTotals? totals) {
    return Padding(
      padding: const EdgeInsets.only(right: _kTableRightInset),
      child: SizedBox(
        height: _kFooterHeight,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: _kHeaderLine)),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              for (final column in _salesColumns)
                _footerCell(_footerValue(totals, column.field), column.width),
              SizedBox(
                width: _kGutterWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, left: 6),
                    child: Text(
                      'الإجمالي',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF303030),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerCell(String value, double width) {
    return Container(
      width: width,
      height: _kFooterHeight,
      padding: const EdgeInsets.only(right: 5, left: 2),
      alignment: Alignment.centerRight,
      decoration: const BoxDecoration(
        color: _kHeader,
        border: Border(
          left: BorderSide(color: _kHeaderLine),
          top: BorderSide(color: Color(0xFFD2D2D2)),
          bottom: BorderSide(color: Color(0xFF838383)),
        ),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11.2,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: _kInk,
        ),
      ),
    );
  }

  String _bodyValue(SalesAnalysisRow row, _SortField field) {
    switch (field) {
      case _SortField.invoices:
        return '${row.invoices}';
      case _SortField.currentQty:
        return _money(row.currentQty);
      case _SortField.qty:
        return _money(row.qty);
      case _SortField.total:
        return _money(row.total);
      case _SortField.cost:
        return _money(row.cost);
      case _SortField.profit:
        return _money(row.profit);
      case _SortField.discount:
        return _money(row.discount);
      case _SortField.profitToTotal:
        return _percent(row.profitToTotal);
      case _SortField.profitToCost:
        return _percent(row.profitToCost);
      case _SortField.totalToSales:
        return _percent(row.totalToSales);
      case _SortField.profitToProfit:
        return _percent(row.profitToProfit);
      case _SortField.label:
        return '';
    }
  }

  String _footerValue(SalesAnalysisTotals? totals, _SortField field) {
    if (totals == null) {
      return switch (field) {
        _SortField.invoices ||
        _SortField.profitToTotal ||
        _SortField.profitToCost => '',
        _ => '0',
      };
    }
    switch (field) {
      case _SortField.invoices:
      case _SortField.profitToTotal:
      case _SortField.profitToCost:
        return '';
      case _SortField.currentQty:
        return _money(totals.currentQty);
      case _SortField.qty:
        return _money(totals.qty);
      case _SortField.total:
        return _money(totals.total);
      case _SortField.cost:
        return _money(totals.cost);
      case _SortField.profit:
        return _money(totals.profit);
      case _SortField.discount:
        return _money(totals.discount);
      case _SortField.totalToSales:
        return _percent(totals.totalToSales);
      case _SortField.profitToProfit:
        return _percent(totals.profitToProfit);
      case _SortField.label:
        return '';
    }
  }

  Widget _scrollThumb() {
    return AnimatedBuilder(
      animation: _rowsScroll,
      builder: (context, _) {
        var thumbHeight = 1.0;
        var thumbTop = 0.0;
        if (_rowsScroll.hasClients) {
          final position = _rowsScroll.position;
          final viewport = position.viewportDimension;
          final extent = position.maxScrollExtent + viewport;
          if (extent > 0) {
            thumbHeight = (viewport / extent).clamp(0.06, 1.0);
            thumbTop = position.maxScrollExtent == 0
                ? 0
                : (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0) *
                      (1 - thumbHeight);
          }
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final barHeight = (height * thumbHeight).clamp(24.0, height);
            return Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFFFAFAFA),
                    alignment: Alignment.topCenter,
                  ),
                ),
                Positioned(
                  top: thumbTop * (height - barHeight),
                  left: 0.5,
                  width: 7,
                  height: barHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFC7C7C7),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Icon(
                    Icons.arrow_drop_up,
                    size: 10,
                    color: Color(0xFF9A9A9A),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.text, {this.align = TextAlign.center});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: align == TextAlign.right
          ? Alignment.centerRight
          : align == TextAlign.left
          ? Alignment.centerLeft
          : Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: const TextStyle(fontSize: 10.8, height: 1.1, color: _kInk),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kGridLine
      ..strokeWidth = 1;
    for (final x in _gridLines) {
      if (x > size.width) continue;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
