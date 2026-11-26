import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:safwa/app/theme/shop_colors.dart';
import 'package:safwa/app/widgets/hover_widgets.dart';

/// One column of the Excel-like grid. [editable] columns open an inline numeric
/// editor when clicked and are visited by Tab / Shift+Tab.
class DataGridColumn {
  const DataGridColumn({
    required this.label,
    required this.width,
    required this.minWidth,
    this.editable = false,
  });

  final String label;
  final double width;
  final double minWidth;
  final bool editable;
}

/// Shared state for every document grid (purchase lines, stocktaking lines).
///
/// Subclasses add their own business helpers (totals, cloning, …) while the
/// widget below only depends on this generic contract.
class SharedDataGridController<T> extends ChangeNotifier {
  SharedDataGridController({
    required List<DataGridColumn> columns,
    required this.cellText,
    required this.cellValue,
    required this.setCellValue,
    this.lockedMessage = 'السجل محفوظ — لا يمكن تعديل سطوره.',
  }) : _columns = List<DataGridColumn>.unmodifiable(columns),
       widths = columns.map((c) => c.width).toList();

  static const double caretWidth = 22;

  final List<DataGridColumn> _columns;
  final String Function(T row, int column) cellText;
  final int Function(T row, int column) cellValue;
  final void Function(T row, int column, int value) setCellValue;
  final String lockedMessage;

  final List<T> rows = <T>[];
  final List<double> widths;

  int selectedIndex = -1;
  bool locked = false;

  List<DataGridColumn> get columns => _columns;

  /// Purchase page and stocktaking page both call the row list `lines`.
  List<T> get lines => rows;

  double get contentWidth =>
      caretWidth + widths.fold<double>(0, (sum, width) => sum + width);

  List<int> get editableColumns => [
    for (var i = 0; i < _columns.length; i++)
      if (_columns[i].editable) i,
  ];

  void addRow(T row) {
    rows.add(row);
    selectedIndex = rows.length - 1;
    notifyListeners();
  }

  void clearRows() {
    rows.clear();
    selectedIndex = -1;
    notifyListeners();
  }

  void select(int index) {
    if (index < 0 || index >= rows.length || index == selectedIndex) return;
    selectedIndex = index;
    notifyListeners();
  }

  void setCell(int index, int column, int value) {
    if (index < 0 || index >= rows.length) return;
    setCellValue(rows[index], column, value);
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= rows.length) return;
    rows.removeAt(index);
    selectedIndex = rows.isEmpty ? -1 : math.min(index, rows.length - 1);
    notifyListeners();
  }

  void moveSelection(int delta) {
    if (rows.isEmpty) return;
    final next = selectedIndex < 0
        ? 0
        : (selectedIndex + delta).clamp(0, rows.length - 1);
    select(next);
  }

  void moveSelected(int delta) {
    final index = selectedIndex;
    if (index < 0) return;
    final target = index + delta;
    if (target < 0 || target >= rows.length) return;
    final row = rows.removeAt(index);
    rows.insert(target, row);
    selectedIndex = target;
    notifyListeners();
  }

  void setWidth(int column, double width) {
    if (column < 0 || column >= widths.length) return;
    widths[column] = width.clamp(_columns[column].minWidth, 640);
    notifyListeners();
  }

  void nudgeAllWidths(double delta) {
    for (var i = 0; i < widths.length; i++) {
      widths[i] = (widths[i] + delta).clamp(_columns[i].minWidth, 640);
    }
    notifyListeners();
  }

  void resetWidths() {
    for (var i = 0; i < widths.length; i++) {
      widths[i] = _columns[i].width;
    }
    notifyListeners();
  }

  void fitWidths(double viewport) {
    final available = viewport - caretWidth - 2;
    if (available <= 0) return;
    final current = widths.fold<double>(0, (sum, width) => sum + width);
    if (current <= 0) return;
    final scale = available / current;
    for (var i = 0; i < widths.length; i++) {
      widths[i] = (widths[i] * scale).clamp(_columns[i].minWidth, 640);
    }
    notifyListeners();
  }
}

/// Excel-like table: independent column resizing, horizontal + vertical
/// scrolling, inline numeric editing and keyboard navigation.
///
/// The widget is deliberately business-agnostic; the controller supplies the
/// text/value adapters, so شراء and جرد مخزن share exactly the same behaviour.
class SharedDataGrid<T> extends StatefulWidget {
  const SharedDataGrid({
    super.key,
    required this.controller,
    required this.onMessage,
    this.onEditFinished,
    this.emptyMessage = 'ابدأ بالبحث عن صنف بالإسم أو بالكود',
    this.emptyEditMessage = 'أضف صنفاً أولاً ثم عدّل الكمية أو السعر.',
    this.salesStyle = false,
    this.footerCellText,
    this.newRowChild,
    this.newRowColumn = 0,
    this.newRowAtEnd = false,
  });

  final SharedDataGridController<T> controller;
  final ValueChanged<String> onMessage;

  /// Called after an inline cell edit ends so the page can take keyboard focus
  /// back (shortcuts stop working while no node is focused).
  final VoidCallback? onEditFinished;

  /// Centered hint shown while the grid has no rows.
  final String emptyMessage;

  /// Toast shown when F5/F6 is pressed with an empty grid.
  final String emptyEditMessage;

  /// Sales invoices use the rounded blue header and striped rows from DEXEF.
  /// Other document grids keep their current appearance.
  final bool salesStyle;

  /// Optional summary values aligned to their column indices.
  final String? Function(int column)? footerCellText;

  /// Optional entry control shown as an extra row in the grid body.
  final Widget? newRowChild;
  final int newRowColumn;

  /// Places the entry row after existing records when true, otherwise before.
  final bool newRowAtEnd;

  @override
  State<SharedDataGrid<T>> createState() => SharedDataGridState<T>();
}

class SharedDataGridState<T> extends State<SharedDataGrid<T>> {
  double get _rowHeight => widget.salesStyle ? 28 : 24;

  final _hCtrl = ScrollController();
  final _vCtrl = ScrollController();
  final _cellCtrl = TextEditingController();
  final _cellFocus = FocusNode();

  int _editRow = -1;
  int _editCol = -1;
  double _viewport = 0;

  SharedDataGridController<T> get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _cellFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _hCtrl.dispose();
    _vCtrl.dispose();
    _cellCtrl.dispose();
    _cellFocus.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (!_cellFocus.hasFocus && _editRow >= 0 && mounted) {
      setState(() {
        _editRow = -1;
        _editCol = -1;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Public commands used by shortcuts / rail.
  // ---------------------------------------------------------------------------
  void editSelected(int column) {
    if (_controller.rows.isEmpty) {
      widget.onMessage(widget.emptyEditMessage);
      return;
    }
    var index = _controller.selectedIndex;
    if (index < 0) {
      index = 0;
      _controller.select(0);
    }
    _beginEdit(index, column);
    scrollToSelected();
  }

  void scrollToSelected() {
    final index = _controller.selectedIndex;
    if (index < 0 || !_vCtrl.hasClients) return;
    final entryOffset = widget.newRowChild == null || widget.newRowAtEnd
        ? 0
        : 1;
    final target = ((index + entryOffset) * _rowHeight).clamp(
      0.0,
      _vCtrl.position.maxScrollExtent,
    );
    _vCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
    );
  }

  void scrollToEntryRow() {
    if (widget.newRowChild == null || !_vCtrl.hasClients) return;
    final target = (_controller.rows.length * _rowHeight).clamp(
      0.0,
      _vCtrl.position.maxScrollExtent,
    );
    _vCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
    );
  }

  bool _editable(int column) => _controller.columns[column].editable;

  void _beginEdit(int row, int column) {
    if (row < 0 || row >= _controller.rows.length) return;
    if (!_editable(column)) return;
    if (_controller.locked) {
      widget.onMessage(_controller.lockedMessage);
      return;
    }
    final line = _controller.rows[row];
    _cellCtrl.text = '${_controller.cellValue(line, column)}';
    setState(() {
      _editRow = row;
      _editCol = column;
    });
    _controller.select(row);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cellFocus.requestFocus();
      _cellCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _cellCtrl.text.length,
      );
    });
  }

  void _applyLive(String text) {
    if (_editRow < 0) return;
    final value = int.tryParse(text.trim());
    if (value == null) return;
    _controller.setCell(_editRow, _editCol, math.max(0, value));
  }

  void _finishEdit() {
    setState(() {
      _editRow = -1;
      _editCol = -1;
    });
    _cellFocus.unfocus();
    widget.onEditFinished?.call();
  }

  void _navigate({required bool forward, bool vertical = false}) {
    final row = _editRow;
    final column = _editCol;
    if (row < 0) return;
    final order = _controller.editableColumns;
    if (order.isEmpty) return;
    var nextRow = row;
    var nextCol = column;
    if (vertical) {
      nextRow = row + 1;
      if (nextRow >= _controller.rows.length) {
        _finishEdit();
        return;
      }
    } else {
      final position = order.indexOf(column);
      final nextPosition = forward ? position + 1 : position - 1;
      if (nextPosition >= order.length) {
        nextRow = row + 1;
        nextCol = order.first;
      } else if (nextPosition < 0) {
        nextRow = row - 1;
        nextCol = order.last;
      } else {
        nextCol = order[nextPosition];
      }
      if (nextRow < 0 || nextRow >= _controller.rows.length) {
        _finishEdit();
        return;
      }
    }
    _beginEdit(nextRow, nextCol);
    if (_vCtrl.hasClients) {
      final entryOffset = widget.newRowChild == null || widget.newRowAtEnd
          ? 0
          : 1;
      final target = ((nextRow + entryOffset) * _rowHeight).clamp(
        0.0,
        _vCtrl.position.maxScrollExtent,
      );
      _vCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  KeyEventResult _onCellKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _navigate(forward: true, vertical: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _navigate(forward: !HardwareKeyboard.instance.isShiftPressed);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _finishEdit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _columnMenu(TapDownDetails details) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromLTRB(
      details.globalPosition.dx,
      details.globalPosition.dy,
      overlay.size.width - details.globalPosition.dx,
      overlay.size.height - details.globalPosition.dy,
    );
    final choice = await showMenu<String>(
      context: context,
      position: position,
      color: Colors.white,
      items: const [
        PopupMenuItem<String>(
          value: 'reset',
          height: 32,
          child: Text(
            'إعادة ضبط عرض الأعمدة',
            style: TextStyle(fontSize: 11.5, color: ShopColors.ink),
          ),
        ),
        PopupMenuItem<String>(
          value: 'fit',
          height: 32,
          child: Text(
            'ملاءمة الأعمدة للعرض',
            style: TextStyle(fontSize: 11.5, color: ShopColors.ink),
          ),
        ),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == 'reset') {
      _controller.resetWidths();
      widget.onMessage('تمت إعادة ضبط عرض الأعمدة.');
    } else {
      _controller.fitWidths(_viewport);
      widget.onMessage('تمت ملاءمة الأعمدة لعرض الجدول.');
    }
  }

  // ---------------------------------------------------------------------------
  // Build.
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.maxWidth;
        final extra = math.max(
          0.0,
          constraints.maxWidth - _controller.contentWidth,
        );
        final contentWidth = math.max(
          constraints.maxWidth,
          _controller.contentWidth,
        );
        return Scrollbar(
          controller: _hCtrl,
          thumbVisibility: true,
          trackVisibility: true,
          thickness: 10,
          radius: Radius.zero,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            controller: _hCtrl,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  _buildHeader(extra),
                  _buildBand(extra),
                  Expanded(child: _buildBody(extra)),
                  _buildStrip(extra),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(double extra) {
    return SizedBox(
      height: widget.salesStyle ? 30 : 24,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          SizedBox(
            width: SharedDataGridController.caretWidth,
            child: Container(
              decoration: BoxDecoration(
                color: widget.salesStyle
                    ? const Color(0xFFDCE9FF)
                    : Colors.white,
                border: const Border(
                  left: BorderSide(color: ShopColors.header),
                ),
              ),
              alignment: Alignment.center,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _columnMenu,
                child: const Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: Color(0xFF555555),
                ),
              ),
            ),
          ),
          for (var i = 0; i < _controller.widths.length; i++) _headerCell(i),
          SizedBox(
            width: extra,
            child: Container(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(int index) {
    return SizedBox(
      width: _controller.widths[index],
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: widget.salesStyle
                  ? const Color(0xFFDCE9FF)
                  : ShopColors.header,
              border: const Border(left: BorderSide(color: Colors.white)),
              borderRadius: widget.salesStyle
                  ? BorderRadius.circular(7)
                  : BorderRadius.zero,
            ),
            alignment: Alignment.center,
            child: Text(
              _controller.columns[index].label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: ShopColors.ink),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 7,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  _controller.setWidth(
                    index,
                    _controller.widths[index] - details.delta.dx,
                  );
                },
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBand(double extra) {
    if (widget.salesStyle) return const SizedBox.shrink();
    return SizedBox(
      height: 27,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: SharedDataGridController.caretWidth,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: ShopColors.header)),
            ),
          ),
          for (var i = 0; i < _controller.widths.length; i++)
            Container(
              width: _controller.widths[i],
              decoration: const BoxDecoration(
                color: ShopColors.green,
                border: Border(left: BorderSide(color: Colors.white)),
              ),
            ),
          SizedBox(
            width: extra,
            child: Container(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(double extra) {
    if (_controller.rows.isEmpty && widget.newRowChild == null) {
      return Container(
        color: Colors.white,
        child: Stack(
          children: [
            Positioned.fill(child: _emptyGrid(extra)),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 9),
                child: widget.salesStyle
                    ? Text(
                        widget.emptyMessage,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8797AC),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFDFDFDF)),
                        ),
                        child: Text(
                          widget.emptyMessage,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF8A8A8A),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    }
    return Stack(
      children: [
        if (widget.salesStyle && _controller.rows.isEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: ListView.builder(
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                itemExtent: _rowHeight,
                itemCount: 500,
                itemBuilder: (context, index) => ColoredBox(
                  color: index.isOdd ? const Color(0xFFF1F4F9) : Colors.white,
                ),
              ),
            ),
          ),
        Scrollbar(
          controller: _vCtrl,
          thumbVisibility: true,
          thickness: 10,
          radius: Radius.zero,
          child: ListView.builder(
            controller: _vCtrl,
            padding: EdgeInsets.zero,
            itemExtent: _rowHeight,
            itemCount:
                _controller.rows.length + (widget.newRowChild == null ? 0 : 1),
            itemBuilder: (context, index) {
              if (widget.newRowChild != null &&
                  index == (widget.newRowAtEnd ? _controller.rows.length : 0)) {
                return _newEntryRow(extra);
              }
              final rowIndex =
                  index -
                  (widget.newRowChild != null && !widget.newRowAtEnd ? 1 : 0);
              return _row(rowIndex, extra);
            },
          ),
        ),
      ],
    );
  }

  Widget _newEntryRow(double extra) {
    return Container(
      height: _rowHeight,
      color: Colors.white,
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: SharedDataGridController.caretWidth,
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: ShopColors.header)),
            ),
          ),
          for (var i = 0; i < _controller.widths.length; i++)
            Container(
              width: _controller.widths[i],
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFFE8E8E8))),
              ),
              child: i == widget.newRowColumn
                  ? widget.newRowChild
                  : const SizedBox.shrink(),
            ),
          SizedBox(width: extra),
        ],
      ),
    );
  }

  Widget _emptyGrid(double extra) {
    final columns = Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: SharedDataGridController.caretWidth,
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: ShopColors.header)),
          ),
        ),
        for (var i = 0; i < _controller.widths.length; i++)
          Container(
            width: _controller.widths[i],
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Color(0xFFE8E8E8))),
            ),
          ),
        SizedBox(width: extra),
      ],
    );
    if (!widget.salesStyle) return columns;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: ListView.builder(
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemExtent: _rowHeight,
            itemCount: 500,
            itemBuilder: (context, index) => ColoredBox(
              color: index.isOdd ? const Color(0xFFF1F4F9) : Colors.white,
            ),
          ),
        ),
        columns,
      ],
    );
  }

  Widget _row(int index, double extra) {
    final line = _controller.rows[index];
    final selected = index == _controller.selectedIndex;
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _controller.select(index),
        child: Container(
          height: _rowHeight,
          color: selected
              ? (widget.salesStyle
                    ? const Color(0xFFD2E3FC)
                    : ShopColors.rowSelected)
              : hovered
              ? (widget.salesStyle
                    ? const Color(0xFFE8F0FE)
                    : ShopColors.rowHover)
              : (widget.salesStyle && index.isOdd
                    ? const Color(0xFFF1F4F9)
                    : Colors.white),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: SharedDataGridController.caretWidth,
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Color(0xFFE6E6E6))),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 11, color: ShopColors.ink),
                ),
              ),
              for (var i = 0; i < _controller.widths.length; i++)
                _bodyCell(index, i, line),
              SizedBox(width: extra),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bodyCell(int row, int column, T line) {
    final editing = _editRow == row && _editCol == column;
    final editable = _editable(column);
    return SizedBox(
      width: _controller.widths[column],
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: const BorderSide(color: Color(0xFFE6E6E6)),
            bottom: BorderSide(
              color: _controller.selectedIndex == row
                  ? Colors.transparent
                  : const Color(0xFFF3F3F3),
            ),
          ),
        ),
        alignment: Alignment.center,
        child: editing
            ? Focus(
                onKeyEvent: _onCellKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: ShopColors.focusBlue),
                  ),
                  child: TextField(
                    controller: _cellCtrl,
                    focusNode: _cellFocus,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    keyboardType: TextInputType.number,
                    onChanged: _applyLive,
                    onSubmitted: (_) =>
                        _navigate(forward: true, vertical: true),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ShopColors.ink,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              )
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: editable
                    ? () => _beginEdit(row, column)
                    : () => _controller.select(row),
                // Fill the whole cell so the operator does not have to hit
                // the glyph itself to start editing.
                child: SizedBox.expand(
                  child: Center(
                    child: Text(
                      _controller.cellText(line, column),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: editable
                            ? ShopColors.ink
                            : const Color(0xFF2E2E2E),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStrip(double extra) {
    if (widget.salesStyle) {
      return SizedBox(
        height: 24,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: SharedDataGridController.caretWidth,
              decoration: const BoxDecoration(
                color: Color(0xFFE3E7ED),
                border: Border(left: BorderSide(color: Colors.white)),
              ),
            ),
            for (var i = 0; i < _controller.widths.length; i++)
              Container(
                width: _controller.widths[i],
                decoration: const BoxDecoration(
                  color: Color(0xFFE3E7ED),
                  border: Border(left: BorderSide(color: Colors.white)),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.footerCellText?.call(i) ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ShopColors.ink,
                  ),
                ),
              ),
            SizedBox(
              width: extra,
              child: Container(color: Colors.white),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 18,
      child: Container(
        color: ShopColors.field,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            SizedBox(
              width: SharedDataGridController.caretWidth,
              child: Container(color: Colors.white),
            ),
            for (var i = 0; i < _controller.widths.length; i++)
              SizedBox(
                width: _controller.widths[i],
                child: Center(
                  child: Container(
                    height: 13,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    color: const Color(0xFFDCDCDC),
                  ),
                ),
              ),
            SizedBox(width: extra),
          ],
        ),
      ),
    );
  }
}
