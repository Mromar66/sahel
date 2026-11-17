part of 'treasury_movement_page.dart';

/// Summary tab controller. The widget itself is the shared [SharedDataGrid]
/// used by شراء, so column resizing, scrolling and selection stay identical.
class TreasurySummaryTableController
    extends SharedDataGridController<TreasurySummaryRow> {
  TreasurySummaryTableController()
    : super(
        columns: const [
          DataGridColumn(label: 'الخزينة', width: 190, minWidth: 100),
          DataGridColumn(label: 'رصيد سابق', width: 125, minWidth: 78),
          DataGridColumn(label: 'وارد', width: 115, minWidth: 70),
          DataGridColumn(label: 'منصرف', width: 115, minWidth: 70),
          DataGridColumn(label: 'الرصيد', width: 135, minWidth: 85),
        ],
        cellText: _cellText,
        cellValue: _cellValue,
        setCellValue: _setCellValue,
      );

  void setRows(Iterable<TreasurySummaryRow> rows) {
    this.rows
      ..clear()
      ..addAll(rows);
    selectedIndex = -1;
    notifyListeners();
  }

  TreasurySummaryRow? get selectedRow =>
      selectedIndex >= 0 && selectedIndex < rows.length
      ? rows[selectedIndex]
      : null;

  static String _cellText(TreasurySummaryRow row, int column) {
    switch (column) {
      case 0:
        return row.treasuryName;
      case 1:
        return _money(row.previousBalance);
      case 2:
        return _money(row.incoming);
      case 3:
        return _money(row.outgoing);
      case 4:
        return _money(row.balance);
      default:
        return '';
    }
  }

  static int _cellValue(TreasurySummaryRow row, int column) {
    switch (column) {
      case 1:
        return row.previousBalance;
      case 2:
        return row.incoming;
      case 3:
        return row.outgoing;
      case 4:
        return row.balance;
      default:
        return 0;
    }
  }

  static void _setCellValue(TreasurySummaryRow row, int column, int value) {}
}

/// Movements tab controller.
class TreasuryMovementTableController
    extends SharedDataGridController<TreasuryMovement> {
  TreasuryMovementTableController()
    : super(
        columns: const [
          DataGridColumn(label: 'الحركة', width: 118, minWidth: 78),
          DataGridColumn(label: 'التاريخ', width: 88, minWidth: 68),
          DataGridColumn(label: 'الوقت', width: 62, minWidth: 48),
          DataGridColumn(label: 'وارد', width: 84, minWidth: 58),
          DataGridColumn(label: 'منصرف', width: 84, minWidth: 58),
          DataGridColumn(label: 'الرصيد', width: 96, minWidth: 70),
          DataGridColumn(label: 'القيمة', width: 78, minWidth: 58),
          DataGridColumn(label: 'مصروف الخزينة', width: 126, minWidth: 78),
          DataGridColumn(label: 'رقم الحركة', width: 170, minWidth: 110),
        ],
        cellText: _cellText,
        cellValue: _cellValue,
        setCellValue: _setCellValue,
      );

  void setRows(Iterable<TreasuryMovement> rows) {
    this.rows
      ..clear()
      ..addAll(rows);
    selectedIndex = -1;
    notifyListeners();
  }

  TreasuryMovement? get selectedMovement {
    if (selectedIndex < 0 || selectedIndex >= rows.length) return null;
    final row = rows[selectedIndex];
    return row.isSynthetic ? null : row;
  }

  static String _cellText(TreasuryMovement row, int column) {
    final synthetic = row.isSynthetic;
    switch (column) {
      case 0:
        if (row.type == 'previous') return 'رصيد سابق';
        if (row.type == 'total') return 'الإجمالي';
        return row.typeLabel;
      case 1:
        if (row.type == 'total') return '';
        return _dateText(row.date);
      case 2:
        if (row.type == 'total') return '';
        return _timeText(row.date);
      case 3:
        return row.displayIncoming == 0 ? '' : _money(row.displayIncoming);
      case 4:
        return row.displayOutgoing == 0 ? '' : _money(row.displayOutgoing);
      case 5:
        return _money(row.balanceAfter);
      case 6:
        if (row.type == 'previous') return '';
        return _money(row.amount);
      case 7:
        if (synthetic) return '';
        return row.categoryLabel;
      case 8:
        if (synthetic) return '';
        return row.referenceLabel;
      default:
        return '';
    }
  }

  static int _cellValue(TreasuryMovement row, int column) {
    switch (column) {
      case 3:
        return row.displayIncoming;
      case 4:
        return row.displayOutgoing;
      case 5:
        return row.balanceAfter;
      case 6:
        return row.amount;
      default:
        return 0;
    }
  }

  static void _setCellValue(TreasuryMovement row, int column, int value) {}
}
