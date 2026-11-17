part of 'daily_movement_page.dart';

extension _DailyMovementLayout on _DailyMovementPageState {
  static const double _periodWidth = 85;
  static const double _dateWidth = 56;
  static const double _calendarWidth = 20;
  static const double _timeWidth = 55;
  static const double _smallLabelWidth = 40;
  static const double _filterHeight = 19;

  // ---------------------------------------------------------------------------
  // Title bar.
  // ---------------------------------------------------------------------------
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: SizedBox(
        height: 26,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            const Text(
              'تقرير الحركة اليومية',
              style: TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w700,
                color: _kGreen,
                height: 1.1,
              ),
            ),
            if (_loading) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kGreen,
                ),
              ),
            ],
            const Spacer(),
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
          width: 94,
          height: 25,
          decoration: BoxDecoration(
            color: hovered ? kHoverYellow : _kSoft,
            border: Border.all(color: const Color(0xFFCFCFCF)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.rtl,
            children: [
              Icon(icon, size: 15, color: const Color(0xFF333333)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 10, color: _kInk)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filters.
  // ---------------------------------------------------------------------------
  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _filterHeight,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                _periodBox(),
                const SizedBox(width: 8),
                _dateBox(_fromDate),
                const SizedBox(width: 12),
                _calendarBox(_fromDate),
                const SizedBox(width: 3),
                _timeBox(
                  _fromTime,
                  onUp: () => _adjustTime(_fromTime, 15),
                  onDown: () => _adjustTime(_fromTime, -15),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: _smallLabelWidth + 10,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'إلى التاريخ',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: _kInk,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 53),
                _dateBox(_toDate),
                const SizedBox(width: 12),
                _calendarBox(_toDate),
                const SizedBox(width: 3),
                _timeBox(
                  _toTime,
                  onUp: () => _adjustTime(_toTime, 15),
                  onDown: () => _adjustTime(_toTime, -15),
                ),
                const SizedBox(width: 6),
                _iconSquare(
                  icon: Icons.push_pin,
                  tooltip: 'تثبيت الفترة',
                  active: _pinned,
                  onTap: _togglePin,
                  width: 23,
                ),
                const SizedBox(width: 5),
                _iconSquare(
                  icon: Icons.close,
                  tooltip: 'مسح الفلاتر',
                  onTap: _resetFilters,
                  width: 23,
                  iconColor: const Color(0xFF9B9B9B),
                ),
                const Spacer(),
              ],
            ),
          ),
          SizedBox(
            height: _filterHeight,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                SizedBox(
                  width: _smallLabelWidth,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'المخزن',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: _kInk,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 53),
                _optionBox(
                  width: 117,
                  options: _warehouses,
                  value: _warehouseId,
                  onChanged: _setWarehouse,
                ),
                const SizedBox(width: 6),
                _iconSquare(
                  icon: Icons.close,
                  tooltip: 'كل المخازن',
                  onTap: () => _setWarehouse(null),
                  width: 23,
                  iconColor: const Color(0xFF9B9B9B),
                ),
                const SizedBox(width: 39),
                SizedBox(
                  width: _smallLabelWidth,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'الخزينة',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: _kInk,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
                _optionBox(
                  width: 117,
                  options: _treasuries,
                  value: _treasuryId,
                  onChanged: _setTreasury,
                ),
                const SizedBox(width: 6),
                _iconSquare(
                  icon: Icons.close,
                  tooltip: 'كل الخزائن',
                  onTap: () => _setTreasury(null),
                  width: 23,
                  iconColor: const Color(0xFF9B9B9B),
                ),
                const Spacer(),
              ],
            ),
          ),
          SizedBox(
            height: 31,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                const SizedBox(width: 92),
                _actionButton(
                  'عرض التقرير',
                  Icons.search,
                  () => _loadReport(showToast: true),
                  width: 148,
                ),
                const SizedBox(width: 6),
                _actionButton('طباعة', Icons.print_outlined, _print, width: 98),
                const SizedBox(width: 6),
                _actionButton(
                  '',
                  Icons.share,
                  _share,
                  width: 39,
                  iconColor: ShopColors.blue,
                  iconSize: 17,
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodBox() {
    return Container(
      width: _periodWidth,
      height: _filterHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kLine),
      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 3),
                style: const TextStyle(fontSize: 9.5, color: _kInk),
                items: [
                  for (final period in _DailyMovementPageState._periods)
                    DropdownMenuItem<String>(
                      value: period,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          period,
                          style: const TextStyle(fontSize: 9.5, color: _kInk),
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
            width: 13,
            child: Icon(
              Icons.keyboard_arrow_down,
              size: 13,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateBox(TextEditingController controller) {
    return Container(
      width: _dateWidth,
      height: _filterHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kLine),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        onSubmitted: (_) => _loadReport(),
        style: const TextStyle(fontSize: 9.2, color: _kInk),
        decoration: const InputDecoration(
          isCollapsed: true,
          filled: false,
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(top: 3),
          constraints: BoxConstraints(minHeight: 0),
        ),
      ),
    );
  }

  Widget _calendarBox(TextEditingController controller) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pickDate(controller),
        child: Container(
          width: _calendarWidth,
          height: _filterHeight,
          color: hovered ? kHoverYellow : Colors.white,
          alignment: Alignment.center,
          child: const Icon(
            Icons.calendar_today_outlined,
            size: 11,
            color: Color(0xFF555555),
          ),
        ),
      ),
    );
  }

  Widget _timeBox(
    TextEditingController controller, {
    required VoidCallback onUp,
    required VoidCallback onDown,
  }) {
    return Container(
      width: _timeWidth,
      height: _filterHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kLine),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _pickTime(controller),
              child: TextField(
                controller: controller,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                onSubmitted: (_) => _loadReport(),
                style: const TextStyle(fontSize: 9.2, color: _kInk),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(top: 3),
                  constraints: BoxConstraints(minHeight: 0),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 12,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _spinArrow(Icons.arrow_drop_up, onUp),
                _spinArrow(Icons.arrow_drop_down, onDown),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _spinArrow(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 12,
        height: 8,
        child: Icon(icon, size: 12, color: const Color(0xFF555555)),
      ),
    );
  }

  Widget _optionBox({
    required double width,
    required List<DailyMovementOption> options,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return Container(
      width: width,
      height: _filterHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kLine),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: const SizedBox.shrink(),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 13,
            color: Color(0xFF555555),
          ),
          dropdownColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          style: const TextStyle(fontSize: 9.5, color: _kInk),
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
                    style: const TextStyle(fontSize: 9.5, color: _kInk),
                  ),
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _iconSquare({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    double width = 26,
    Color iconColor = const Color(0xFF222222),
    bool active = false,
  }) {
    final button = HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: _filterHeight,
          color: hovered ? kHoverYellow : _kSoft,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 13,
            color: active ? ShopColors.blue : iconColor,
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }

  Widget _actionButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    required double width,
    Color? iconColor,
    double iconSize = 18,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: 31,
          color: hovered ? kHoverYellow : _kSoft,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.rtl,
            children: [
              Icon(icon, size: iconSize, color: iconColor ?? _kInk),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(fontSize: 10.5, color: _kInk),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Summary tab.
  // ---------------------------------------------------------------------------
  Widget _buildTabs() {
    return Container(
      height: 23,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kTabBlue)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 168,
            height: 23,
            decoration: const BoxDecoration(
              color: _kTabBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            ),
            alignment: Alignment.center,
            child: const Text(
              'ملخص',
              style: TextStyle(fontSize: 11.5, color: _kInk, height: 1.1),
            ),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Report canvas.
  // ---------------------------------------------------------------------------
  Widget _buildReportArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 23, 6, 12),
      child: RepaintBoundary(
        key: _reportBoundaryKey,
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDailyTable(),
            const SizedBox(width: 52),
            _buildTreasuryPanel(),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
