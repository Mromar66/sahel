part of 'daily_movement_page.dart';

const double _labelWidth = 90;
const double _labelGap = 50;
const double _cellWidth = 94;
const double _cellGap = 5;
const double _headerHeight = 32;
const double _dataRowHeight = 24.5;
const double _panelWidth = 194;
const double _panelValueWidth = 94;

const DailyTreasurySummary _zeroTreasurySummary = DailyTreasurySummary(
  cashSales: 0,
  cashSalesReturn: 0,
  cashPurchases: 0,
  cashPurchaseReturn: 0,
  receipts: 0,
  payments: 0,
  expenses: 0,
  previousBalance: 0,
  incoming: 0,
  outgoing: 0,
  netMovement: 0,
  finalBalance: 0,
);

const List<DailyMovementRow> _placeholderRows = [
  DailyMovementRow(label: 'بيع'),
  DailyMovementRow(label: 'مرتجع بيع'),
  DailyMovementRow(label: 'شراء'),
  DailyMovementRow(label: 'مرتجع شراء'),
  DailyMovementRow(label: 'قبض', visibleCells: 2),
  DailyMovementRow(label: 'صرف', visibleCells: 2),
  DailyMovementRow(label: 'مصروف مخزن', visibleCells: 2),
  DailyMovementRow(label: 'جرد مخزن', visibleCells: 1),
  DailyMovementRow(label: 'تحويل مخزن', visibleCells: 1),
  DailyMovementRow(label: 'تسوية مخزن', visibleCells: 1),
];

class _TreasuryLine {
  const _TreasuryLine(this.label, this.value, {this.highlight = false});

  final String label;
  final int value;
  final bool highlight;
}

extension _DailyMovementTables on _DailyMovementPageState {
  double get _numericWidth => _cellWidth * 4 + _cellGap * 3;

  // ---------------------------------------------------------------------------
  // Main summary grid.
  // ---------------------------------------------------------------------------
  Widget _buildDailyTable() {
    final rows = _report?.rows ?? _placeholderRows;
    return SizedBox(
      width: _labelWidth + _labelGap + _numericWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              const SizedBox(width: _labelWidth, height: _headerHeight),
              const SizedBox(width: _labelGap),
              SizedBox(
                width: _numericWidth,
                height: _headerHeight,
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    _headerCell('عدد الفواتير'),
                    const SizedBox(width: _cellGap),
                    _headerCell('الإجمالي'),
                    const SizedBox(width: _cellGap),
                    _headerCell('نقدي'),
                    const SizedBox(width: _cellGap),
                    _headerCell('أجل'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: _cellGap),
          for (var index = 0; index < rows.length; index++) ...[
            _dataRow(rows[index]),
            if (index != rows.length - 1) const SizedBox(height: _cellGap),
          ],
        ],
      ),
    );
  }

  Widget _headerCell(String label) {
    return Container(
      width: _cellWidth,
      height: _headerHeight,
      color: _kGreen,
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _dataRow(DailyMovementRow row) {
    final values = <int>[];
    if (row.visibleCells >= 1) values.add(row.count);
    if (row.visibleCells >= 2) values.add(row.total);
    if (row.visibleCells >= 4) {
      values
        ..add(row.cash)
        ..add(row.credit);
    }
    return SizedBox(
      height: _dataRowHeight,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          SizedBox(
            width: _labelWidth,
            height: _dataRowHeight,
            child: Center(
              child: Text(
                row.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _kInk,
                  height: 1.1,
                ),
              ),
            ),
          ),
          const SizedBox(width: _labelGap),
          for (var index = 0; index < values.length; index++) ...[
            if (index > 0) const SizedBox(width: _cellGap),
            Container(
              width: _cellWidth,
              height: _dataRowHeight,
              color: _kCell,
              alignment: Alignment.center,
              child: Text(
                _money(values[index]),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _kInk,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Treasury movement panel.
  // ---------------------------------------------------------------------------
  Widget _buildTreasuryPanel() {
    final lines = _treasuryLines(_report?.treasury ?? _zeroTreasurySummary);
    return SizedBox(
      width: _panelWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: _headerHeight,
            color: _kGreen,
            alignment: Alignment.center,
            child: const Text(
              'ملخص حركة الخزينة',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: _cellGap),
          for (var index = 0; index < lines.length; index++) ...[
            _panelRow(lines[index]),
            if (index != lines.length - 1) const SizedBox(height: _cellGap),
          ],
        ],
      ),
    );
  }

  Widget _panelRow(_TreasuryLine line) {
    return SizedBox(
      height: _dataRowHeight,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Container(
              height: _dataRowHeight,
              color: Colors.white,
              alignment: Alignment.center,
              child: Text(
                line.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: _kInk,
                  height: 1.1,
                ),
              ),
            ),
          ),
          const SizedBox(width: _cellGap),
          Container(
            width: _panelValueWidth,
            height: _dataRowHeight,
            color: line.highlight ? _kYellow : _kCell,
            alignment: Alignment.center,
            child: Text(
              _money(line.value),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _kInk,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_TreasuryLine> _treasuryLines(DailyTreasurySummary summary) {
    return [
      _TreasuryLine('بيع نقدي', summary.cashSales),
      _TreasuryLine('مرتجع بيع نقدي', summary.cashSalesReturn),
      _TreasuryLine('شراء نقدي', summary.cashPurchases),
      _TreasuryLine('مرتجع شراء نقدي', summary.cashPurchaseReturn),
      _TreasuryLine('قبض', summary.receipts),
      _TreasuryLine('صرف', summary.payments),
      _TreasuryLine('مصروف خزينة', summary.expenses),
      _TreasuryLine('رصيد سابق', summary.previousBalance, highlight: true),
      _TreasuryLine('صافي حركة الخزينة', summary.netMovement),
      _TreasuryLine('الرصيد النهائي', summary.finalBalance, highlight: true),
    ];
  }
}
