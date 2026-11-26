part of 'profit_loss_page.dart';

const double _kFilterHeight = 21;
const double _kStatementRowHeight = 25;
const double _kDetailRowHeight = 24;
const double _kDetailHeaderHeight = 28;
const Color _kHeaderLine = Color(0xFFC4C4C4);
const Color _kRowLine = Color(0xFFE7E7E7);
const Color _kSubtotalFill = Color(0xFFF0F0F0);
const Color _kTotalFill = Color(0xFFE5E5E5);
const Color _kProfitFill = Color(0xFFFFF3C4);

extension _ProfitLossLayout on _ProfitLossPageState {
  // ---------------------------------------------------------------------------
  // Title bar.
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
                    'الأرباح والخسائر',
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
                      'حدد الفترة والخزينة ثم اضغط عرض التقرير .. القائمة تُحسب من بياناتك الحقيقية',
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
  // Filters.
  // ---------------------------------------------------------------------------
  Widget _buildFilters() {
    return SizedBox(
      height: 90,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Row 1 — dates, warehouse, treasury.
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
            left: 483,
            top: 5,
            width: 48,
            child: _FilterLabel('المخزن', align: TextAlign.center),
          ),
          Positioned(left: 354, top: 0, child: _warehouseField()),
          const Positioned(
            left: 289,
            top: 5,
            width: 54,
            child: _FilterLabel('الخزينة', align: TextAlign.center),
          ),
          Positioned(left: 161, top: 0, child: _treasuryField()),
          Positioned(
            left: 137,
            top: 0,
            child: _clearButton(
              tooltip: 'كل الخزائن',
              onTap: () => _setTreasury(null),
            ),
          ),

          // Row 2 — checkboxes.
          Positioned(
            left: 488,
            top: 32,
            width: 430,
            child: _checkOption(
              label: 'تجاهل المصروفات والإيرادات المرتبطة بالحسابات',
              value: _manualOnly,
              onChanged: _setManualOnly,
              tooltip:
                  'عند التفعيل تُستخدم الحركات اليدوية فقط، فلا تتداخل مصروفات '
                  'أو إيرادات الفواتير مع الإيرادات والتكلفة.',
            ),
          ),
          Positioned(
            left: 180,
            top: 32,
            width: 280,
            child: _checkOption(
              label: 'عرض الإيرادات الأخرى',
              value: _showOtherIncome,
              onChanged: _setShowOtherIncome,
              tooltip: 'إظهار الإيرادات اليدوية غير المرتبطة بالمبيعات.',
            ),
          ),
        ],
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

  Widget _warehouseField() {
    return HoverBuilder(
      builder: (context, hovered) => Tooltip(
        message: 'المخزن غير مسجل على الفواتير، لذلك القائمة تعرض كل الحركة.',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toast(
            'لا يمكن تصفية الأرباح والخسائر حسب المخزن لأن الفواتير لا تسجل '
            'المخزن. القائمة تشمل كل المخازن.',
          ),
          child: Container(
            width: 128,
            height: _kFilterHeight,
            padding: const EdgeInsets.only(right: 5, left: 4),
            decoration: BoxDecoration(
              color: hovered ? const Color(0xFFF7F7F7) : Colors.white,
              border: Border.all(color: const Color(0xFFC9C9C9)),
            ),
            alignment: Alignment.centerRight,
            child: const Text(
              'غير محدد',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: Color(0xFF8A8A8A)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _treasuryField() {
    final name = _treasuryName();
    return PopupMenuButton<int>(
      tooltip: 'اختيار الخزينة',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 2),
      color: Colors.white,
      onSelected: (value) => _setTreasury(value == 0 ? null : value),
      itemBuilder: (context) => [
        const PopupMenuItem<int>(
          value: 0,
          height: 32,
          child: Text(
            'كل الخزائن',
            style: TextStyle(fontSize: 11, color: _kInk),
          ),
        ),
        for (final option in _treasuries)
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
        width: 150,
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

  Widget _checkOption({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: value ? ShopColors.focusBlue : Colors.white,
                border: Border.all(
                  color: value ? ShopColors.focusBlue : const Color(0xFF9A9A9A),
                  width: 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: value
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.8, color: _kInk),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _treasuryName() {
    if (_treasuryId == null) return 'كل الخزائن';
    for (final option in _treasuries) {
      if (option.id == _treasuryId) return option.name;
    }
    return 'كل الخزائن';
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

  // ---------------------------------------------------------------------------
  // Actions.
  // ---------------------------------------------------------------------------
  Widget _buildActions() {
    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, right: 108),
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _actionButton(
              'عرض التقرير',
              Icons.search,
              () => _loadReport(showToast: true),
              width: 120,
              background: _kYellow,
            ),
            const SizedBox(width: 10),
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
  // Content.
  // ---------------------------------------------------------------------------
  Widget _buildContent(ProfitLossReport? report) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RepaintBoundary(
              key: _reportBoundaryKey,
              child: report == null
                  ? _emptyPanel(
                      _loading ? 'جارٍ تحميل القائمة...' : 'لا توجد بيانات.',
                    )
                  : _detailed
                  ? _buildDetailTable(report)
                  : _buildStatement(report),
            ),
          ),
          const SizedBox(width: 10),
          _detailUtility(),
        ],
      ),
    );
  }

  Widget _buildStatement(ProfitLossReport report) {
    final lines = report.statement;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kHeaderLine),
      ),
      child: Column(
        children: [
          for (var index = 0; index < lines.length; index++)
            _statementRow(lines[index], index),
        ],
      ),
    );
  }

  Widget _statementRow(ProfitLossStatementLine line, int index) {
    final isHeader = line.kind == ProfitLossLineKind.header;
    final isProfit = line.kind == ProfitLossLineKind.profit;
    final isSubtotal =
        line.kind == ProfitLossLineKind.subtotal ||
        line.kind == ProfitLossLineKind.total;
    final background = isHeader
        ? _kGreen
        : isProfit
        ? _kProfitFill
        : line.kind == ProfitLossLineKind.total
        ? _kTotalFill
        : line.kind == ProfitLossLineKind.subtotal
        ? _kSubtotalFill
        : Colors.white;
    final textColor = isHeader
        ? Colors.white
        : isProfit
        ? const Color(0xFF43B5DB)
        : _kInk;
    return Container(
      height: _kStatementRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(
            color: isHeader ? const Color(0xFF43B5DB) : _kRowLine,
          ),
          top: index == 0
              ? BorderSide.none
              : index > 0 && linesKindAt(index - 1) == ProfitLossLineKind.header
              ? const BorderSide(color: _kHeaderLine)
              : BorderSide.none,
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Text(
              line.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: isHeader ? 11.6 : 11.2,
                height: 1.1,
                fontWeight: isHeader || isSubtotal || isProfit
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          SizedBox(
            width: 160,
            child: Text(
              isHeader ? '' : _money(line.amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: isProfit ? 12.2 : 11.4,
                height: 1.1,
                fontWeight: isHeader || isSubtotal || isProfit
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  ProfitLossLineKind linesKindAt(int index) {
    final report = _report;
    if (report == null) return ProfitLossLineKind.normal;
    final lines = report.statement;
    if (index < 0 || index >= lines.length) return ProfitLossLineKind.normal;
    return lines[index].kind;
  }

  Widget _buildDetailTable(ProfitLossReport report) {
    final rows = report.details;
    final debit = rows.fold<int>(0, (sum, row) => sum + row.debit);
    final credit = rows.fold<int>(0, (sum, row) => sum + row.credit);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kHeaderLine),
      ),
      child: Column(
        children: [
          _detailHeader(),
          Expanded(
            child: rows.isEmpty
                ? _emptyPanel('لا توجد حركة تفصيلية في الفترة المحددة.')
                : Stack(
                    children: [
                      Positioned.fill(
                        child: ListView.builder(
                          controller: _rowsScroll,
                          padding: EdgeInsets.zero,
                          itemExtent: _kDetailRowHeight,
                          itemCount: rows.length,
                          itemBuilder: (context, index) =>
                              _detailRow(rows[index], index),
                        ),
                      ),
                      Positioned(
                        left: 2,
                        top: 2,
                        bottom: 2,
                        width: 8,
                        child: _scrollThumb(),
                      ),
                    ],
                  ),
          ),
          _detailFooter(debit, credit),
        ],
      ),
    );
  }

  Widget _detailHeader() {
    return Container(
      height: _kDetailHeaderHeight,
      decoration: const BoxDecoration(
        color: _kHeader,
        border: Border(bottom: BorderSide(color: _kHeaderLine)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: const [
          _DetailCell('التاريخ', 82, header: true),
          _DetailCell('النوع', 96, header: true),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'البيان',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10.8,
                  fontWeight: FontWeight.w600,
                  color: _kInk,
                ),
              ),
            ),
          ),
          _DetailCell('مدين', 100, header: true),
          _DetailCell('دائن', 100, header: true),
        ],
      ),
    );
  }

  Widget _detailRow(ProfitLossDetailRow row, int index) {
    return HoverBuilder(
      builder: (context, hovered) => Container(
        color: hovered
            ? const Color(0x1431BB68)
            : index.isEven
            ? Colors.white
            : const Color(0xFFFAFAFA),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            SizedBox(
              width: 82,
              child: Text(
                _dateText(row.date),
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 10.3, color: _kInk),
              ),
            ),
            SizedBox(
              width: 96,
              child: Text(
                row.type,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, color: _kInk),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  row.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 10.5, color: _kInk),
                ),
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                row.debit == 0 ? '' : _money(row.debit),
                textAlign: TextAlign.left,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 10.5, color: _kInk),
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                row.credit == 0 ? '' : _money(row.credit),
                textAlign: TextAlign.left,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 10.5, color: _kInk),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailFooter(int debit, int credit) {
    return Container(
      height: _kDetailRowHeight,
      decoration: const BoxDecoration(
        color: _kHeader,
        border: Border(
          top: BorderSide(color: _kHeaderLine),
          bottom: BorderSide(color: Color(0xFF838383)),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'الإجمالي',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kInk,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              _money(debit),
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              _money(credit),
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailUtility() {
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HoverBuilder(
            builder: (context, hovered) => Tooltip(
              message: _detailed
                  ? 'العودة إلى قائمة الأرباح والخسائر'
                  : 'عرض حركات الإيراد والتكلفة والمصروفات بالتفصيل',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleDetailed,
                child: Container(
                  height: 34,
                  color: _detailed
                      ? _kYellow
                      : hovered
                      ? const Color(0xFFFFF3CE)
                      : _kSoft,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    textDirection: TextDirection.rtl,
                    children: [
                      Icon(
                        _detailed ? Icons.article_outlined : Icons.list_alt,
                        size: 15,
                        color: _kInk,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _detailed ? 'عرض الملخص' : 'تقرير تفصيلي',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: _kInk),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'كل حركة على حدة\nمدين / دائن',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.2,
              height: 1.4,
              color: Color(0xFF8A8A8A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyPanel(String message) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        border: Border.all(color: _kHeaderLine),
      ),
      alignment: Alignment.center,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          height: 1.5,
          color: Color(0xFF555555),
        ),
      ),
    );
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

class _DetailCell extends StatelessWidget {
  const _DetailCell(this.text, this.width, {this.header = false});

  final String text;
  final double width;
  final bool header;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.8,
          fontWeight: header ? FontWeight.w600 : FontWeight.w400,
          color: _kInk,
        ),
      ),
    );
  }
}
