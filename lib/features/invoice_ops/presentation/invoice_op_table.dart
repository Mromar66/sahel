part of 'invoice_op_page.dart';

/// Column definitions, rows and totals for the purchase table.
///
/// The Excel-like behaviour lives in the shared [SharedDataGrid]; this class
/// only adds the purchase-specific totals and row helpers.
class _InvoiceTableController extends SharedDataGridController<InvoiceLine> {
  _InvoiceTableController({required this.salesStyle})
    : super(
        columns: salesStyle ? _salesColumns : _standardColumns,
        cellText: (line, column) => _cellText(line, column, salesStyle),
        cellValue: (line, column) => _cellValue(line, column, salesStyle),
        setCellValue: (line, column, value) =>
            _setCellValue(line, column, value, salesStyle),
        lockedMessage: 'المستند محفوظ — لا يمكن تعديل سطوره.',
      );

  final bool salesStyle;

  static const _standardColumns = [
    DataGridColumn(label: 'رقم الصنف', width: 64, minWidth: 46),
    DataGridColumn(label: 'اسم الصنف', width: 200, minWidth: 90),
    DataGridColumn(label: 'وحدة', width: 58, minWidth: 40),
    DataGridColumn(label: 'المتاح', width: 58, minWidth: 44),
    DataGridColumn(label: 'الكمية', width: 58, minWidth: 44, editable: true),
    DataGridColumn(label: 'السعر', width: 62, minWidth: 50, editable: true),
    DataGridColumn(label: 'الإجمالي', width: 78, minWidth: 60),
    DataGridColumn(label: 'الخصم', width: 58, minWidth: 44, editable: true),
    DataGridColumn(label: 'النهائي', width: 78, minWidth: 60),
  ];

  static const _salesColumns = [
    DataGridColumn(label: 'الكود', width: 132, minWidth: 68),
    DataGridColumn(label: 'اسم الصنف', width: 338, minWidth: 140),
    DataGridColumn(label: 'الكمية', width: 102, minWidth: 60, editable: true),
    DataGridColumn(label: 'الوحدة', width: 102, minWidth: 58),
    DataGridColumn(label: 'السعر', width: 102, minWidth: 60, editable: true),
    DataGridColumn(label: 'الإجمالي', width: 110, minWidth: 70),
    DataGridColumn(label: 'الخصم', width: 80, minWidth: 50, editable: true),
    DataGridColumn(label: 'الصافي', width: 100, minWidth: 65),
    DataGridColumn(label: 'المتاح', width: 88, minWidth: 55),
  ];

  int get quantityColumn => salesStyle ? 2 : 4;
  int get priceColumn => salesStyle ? 4 : 5;

  int get qtyTotal => lines.fold<int>(0, (sum, line) => sum + line.qty);
  int get grossTotal => lines.fold<int>(0, (sum, line) => sum + line.gross);
  int get discountTotal =>
      lines.fold<int>(0, (sum, line) => sum + line.discount);
  int get netTotal => lines.fold<int>(0, (sum, line) => sum + line.net);

  void add(InvoiceLine line) => addRow(line);

  void clear() => clearRows();

  void update(
    int index, {
    int? qty,
    int? price,
    int? discount,
    int? available,
  }) {
    if (index < 0 || index >= lines.length) return;
    final line = lines[index];
    if (qty != null) line.qty = qty < 0 ? 0 : qty;
    if (price != null) line.price = price < 0 ? 0 : price;
    if (discount != null) {
      line.discount = discount < 0 ? 0 : math.min(discount, line.gross);
    }
    if (available != null) line.available = available < 0 ? 0 : available;
    notifyListeners();
  }

  void duplicateSelected() {
    final index = selectedIndex;
    if (index < 0) return;
    lines.insert(index + 1, lines[index].clone());
    selectedIndex = index + 1;
    notifyListeners();
  }

  static String _cellText(InvoiceLine line, int column, bool salesStyle) {
    if (salesStyle) {
      switch (column) {
        case 0:
          return line.code;
        case 1:
          return line.name;
        case 3:
          return line.unit;
        default:
          return '${_cellValue(line, column, salesStyle)}';
      }
    }
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
        return '${_cellValue(line, column, salesStyle)}';
    }
  }

  static int _cellValue(InvoiceLine line, int column, bool salesStyle) {
    if (salesStyle) {
      switch (column) {
        case 2:
          return line.qty;
        case 4:
          return line.price;
        case 5:
          return line.gross;
        case 6:
          return line.discount;
        case 7:
          return line.net;
        default:
          return line.available;
      }
    }
    switch (column) {
      case 4:
        return line.qty;
      case 5:
        return line.price;
      case 6:
        return line.gross;
      case 7:
        return line.discount;
      case 8:
        return line.net;
      default:
        return line.available;
    }
  }

  static void _setCellValue(
    InvoiceLine line,
    int column,
    int value,
    bool salesStyle,
  ) {
    if (salesStyle) {
      switch (column) {
        case 2:
          line.qty = value < 0 ? 0 : value;
        case 4:
          line.price = value < 0 ? 0 : value;
        case 6:
          line.discount = value < 0 ? 0 : math.min(value, line.gross);
      }
      return;
    }
    switch (column) {
      case 4:
        line.qty = value < 0 ? 0 : value;
      case 5:
        line.price = value < 0 ? 0 : value;
      case 7:
        line.discount = value < 0 ? 0 : math.min(value, line.gross);
    }
  }
}
