part of 'warehouse_op_page.dart';

/// Column definitions and totals for the تسوية / تحويل table.
///
/// The columns, widths and editing behaviour are identical to جرد مخزن; only
/// the wording of the locked-state message changes per document.
class _WarehouseOpTableController
    extends SharedDataGridController<WarehouseOpLine> {
  _WarehouseOpTableController({required WarehouseOpKind kind})
    : super(
        columns: const [
          DataGridColumn(label: 'رقم الصنف', width: 80, minWidth: 46),
          DataGridColumn(label: 'اسم الصنف', width: 250, minWidth: 90),
          DataGridColumn(label: 'وحدة', width: 75, minWidth: 40),
          DataGridColumn(label: 'المتاح', width: 80, minWidth: 44),
          DataGridColumn(
            label: 'الكمية',
            width: 80,
            minWidth: 44,
            editable: true,
          ),
          DataGridColumn(
            label: 'السعر',
            width: 80,
            minWidth: 50,
            editable: true,
          ),
          DataGridColumn(label: 'الإجمالي', width: 114, minWidth: 60),
        ],
        cellText: _cellText,
        cellValue: _cellValue,
        setCellValue: _setCellValue,
        lockedMessage: '${kind.documentName} محفوظ — لا يمكن تعديل سطوره.',
      );

  int get grossTotal => lines.fold<int>(0, (sum, line) => sum + line.gross);
  int get qtyTotal => lines.fold<int>(0, (sum, line) => sum + line.qty);

  void add(WarehouseOpLine line) => addRow(line);

  void clear() => clearRows();

  void update(int index, {int? qty, int? price}) {
    if (index < 0 || index >= lines.length) return;
    final line = lines[index];
    if (qty != null) line.qty = qty < 0 ? 0 : qty;
    if (price != null) line.price = price < 0 ? 0 : price;
    notifyListeners();
  }

  void duplicateSelected() {
    final index = selectedIndex;
    if (index < 0) return;
    lines.insert(index + 1, lines[index].clone());
    selectedIndex = index + 1;
    notifyListeners();
  }

  static String _cellText(WarehouseOpLine line, int column) {
    switch (column) {
      case 0:
        return line.code;
      case 1:
        return line.name;
      case 2:
        return line.unit;
      case 3:
        return '${line.available}';
      default:
        return '${_cellValue(line, column)}';
    }
  }

  static int _cellValue(WarehouseOpLine line, int column) {
    switch (column) {
      case 4:
        return line.qty;
      case 5:
        return line.price;
      case 6:
        return line.gross;
      default:
        return line.available;
    }
  }

  static void _setCellValue(WarehouseOpLine line, int column, int value) {
    switch (column) {
      case 4:
        line.qty = value < 0 ? 0 : value;
      case 5:
        line.price = value < 0 ? 0 : value;
    }
  }
}
