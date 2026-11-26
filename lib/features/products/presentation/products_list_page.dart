import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:safwa/app/shell/app_top_bar.dart';
import 'package:safwa/core/utils/constants.dart';
import 'package:safwa/app/widgets/hover_widgets.dart';
import 'package:safwa/features/products/data/product_repository.dart';
import 'package:safwa/features/products/presentation/confirm_delete_dialog.dart';
import 'package:safwa/features/products/presentation/export_dialog.dart';
import 'package:safwa/features/products/presentation/product_form_page.dart';

/// Products page (البضاعة) — pixel copy of the reference program:
/// a white page header with the green Kufi title, action buttons and search
/// fields; a left sidebar of command buttons; and the 10-column products grid
/// with green rows, footer totals, scrollbar and the warehouse mini-table.
class ProductsListPage extends StatefulWidget {
  const ProductsListPage({super.key, this.openNewOnStart = false});

  final bool openNewOnStart;

  @override
  State<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends State<ProductsListPage> {
  final ProductRepository _repo = ProductRepository();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tableScrollController = ScrollController();
  final GlobalKey _categoryKey = GlobalKey();
  final GlobalKey _tableBoundaryKey = GlobalKey();

  List<ProductListRow> _rows = [];
  List<Map<String, Object?>> _categories = [];
  bool _loading = true;
  bool _refreshing = false;

  String _search = '';
  int? _categoryFilter;
  final Set<int> _selectedIds = {};
  int _sortColumn = -1;
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _reload();
    if (widget.openNewOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openNew();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<void> _reload({bool feedback = false}) async {
    if (_refreshing) return;
    if (feedback) {
      setState(() => _refreshing = true);
    }
    final rows = await _repo.getProductListRows();
    final categories = await _repo.getCategories();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _categories = categories;
      _loading = false;
      _refreshing = false;
    });
    if (feedback) {
      _info('تم تحديث قائمة الأصناف — ${rows.length} صنف.');
    }
  }

  List<ProductListRow> get _filtered {
    Iterable<ProductListRow> result = _rows;
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      result = result.where((r) {
        final p = r.product;
        return p.name.toLowerCase().contains(q) ||
            p.productCode.toLowerCase().contains(q) ||
            (p.barcode ?? '').toLowerCase().contains(q);
      });
    }
    if (_categoryFilter != null) {
      result = result.where((r) => r.product.categoryId == _categoryFilter);
    }
    final list = result.toList();
    if (_sortColumn >= 0) {
      list.sort(_compare);
    }
    return list;
  }

  int _compare(ProductListRow a, ProductListRow b) {
    int r;
    switch (_sortColumn) {
      case 1:
        r = (a.product.id ?? 0).compareTo(b.product.id ?? 0);
        break;
      case 2:
        r = a.product.name.compareTo(b.product.name);
        break;
      case 3:
        r = a.totalQuantity.compareTo(b.totalQuantity);
        break;
      case 4:
        r = a.unitName.compareTo(b.unitName);
        break;
      case 5:
        r = a.product.sellingPrice.compareTo(b.product.sellingPrice);
        break;
      case 6:
        r = a.avgPurchasePrice.compareTo(b.avgPurchasePrice);
        break;
      case 7:
        r = a.lastPurchasePrice.compareTo(b.lastPurchasePrice);
        break;
      case 8:
        r = (a.product.barcode ?? '').compareTo(b.product.barcode ?? '');
        break;
      case 9:
        r = a.product.productCode.compareTo(b.product.productCode);
        break;
      default:
        r = 0;
    }
    return _sortAsc ? r : -r;
  }

  ProductListRow? get _selectedRow {
    for (final row in _filtered) {
      if (row.product.id != null && _selectedIds.contains(row.product.id)) {
        return row;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Page scaffolding.
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return withPlainInputs(
      AppShell(
        activeTab: AppTab.products,
        child: Column(
          children: [
            _buildPageHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  textDirection: TextDirection.ltr,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 286,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _buildSidebar(),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _buildTable(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page header (white strip with title + buttons + search fields).
  // ---------------------------------------------------------------------------
  Widget _buildPageHeader() {
    return Container(
      height: 95,
      color: Colors.white,
      child: Stack(
        children: [
          // Green title sprite at the top right.
          Positioned(
            right: 8,
            top: 10,
            child: Image(
              image: AssetImage('assets/icons/products/title_goods.png'),
              width: 73,
              height: 27,
              filterQuality: FilterQuality.none,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                width: 73,
                height: 27,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'البضاعة',
                    style: TextStyle(
                      color: Color(0xFF43B5DB),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Action buttons row at the left.
          Positioned(
            left: 8,
            top: 8,
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                _headerButton('assets/icons/products/top_cancel.png', 126, () {
                  // إغلاق: closes the البضاعة tab and returns to the home tab.
                  removeCurrentAppTab(context);
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.home);
                  }
                }),
                _gap(7),
                _headerButton('assets/icons/products/top_refresh.png', 126, () {
                  _reload(feedback: true);
                }),
                _gap(7),
                _headerButton(
                  'assets/icons/products/top_search.png',
                  126,
                  _showAdvancedSearch,
                ),
                _gap(7),
                _headerButton(
                  'assets/icons/products/top_more.png',
                  30,
                  _showMoreMenu,
                ),
              ],
            ),
          ),

          // بحث عن field (rightmost).
          Positioned(
            right: 10,
            top: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const _FieldLabel('بحث عن'),
                const SizedBox(height: 4),
                _searchField(),
              ],
            ),
          ),

          // التصنيف dropdown.
          Positioned(
            right: 218,
            top: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const _FieldLabel('التصنيف'),
                const SizedBox(height: 4),
                _categoryDropdown(),
              ],
            ),
          ),

          // Clear (X) button.
          Positioned(right: 335, top: 66, child: _clearButton()),
        ],
      ),
    );
  }

  Widget _gap(double w) => SizedBox(width: w);

  Widget _headerButton(String asset, double width, VoidCallback onTap) {
    return HoverAssetButton(
      asset: asset,
      width: width,
      height: 30,
      onTap: onTap,
    );
  }

  Widget _searchField() {
    return Container(
      width: 200,
      height: 23,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFEEEEEE)),
          right: BorderSide(color: Color(0xFFE4E4E4)),
          left: BorderSide(color: Color(0xFFE4E4E4)),
          bottom: BorderSide(color: Color(0xFF004AC0), width: 2),
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)),
        textAlignVertical: TextAlignVertical.center,
        decoration: const InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(right: 6, bottom: 12),
        ),
        onChanged: (v) => setState(() => _search = v),
      ),
    );
  }

  Widget _categoryDropdown() {
    String label = '';
    if (_categoryFilter != null) {
      for (final c in _categories) {
        if (c['id'] == _categoryFilter) {
          label = c['name'] as String? ?? '';
          break;
        }
      }
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pickCategory,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          key: _categoryKey,
          width: 110,
          height: 23,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF8D8D8D)),
          ),
          padding: const EdgeInsets.only(right: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(
                width: 14,
                child: CustomPaint(painter: _ChevronPainter()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCategory() async {
    final box = _categoryKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    RelativeRect position = const RelativeRect.fromLTRB(940, 148, 218, 0);
    if (box != null) {
      final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
      position = RelativeRect.fromLTRB(
        topLeft.dx - 160,
        topLeft.dy + box.size.height + 2,
        overlay.size.width - topLeft.dx - box.size.width,
        0,
      );
    }
    final selected = await showMenu<int>(
      context: context,
      position: position,
      color: Colors.white,
      items: [
        const PopupMenuItem<int>(
          value: -1,
          height: 34,
          child: Text('كل التصنيفات', style: TextStyle(fontSize: 12.5)),
        ),
        for (final c in _categories)
          PopupMenuItem<int>(
            value: c['id'] as int,
            height: 34,
            child: Text(
              c['name'] as String? ?? '',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
      ],
    );
    if (!mounted || selected == null) return;
    setState(() => _categoryFilter = selected == -1 ? null : selected);
  }

  Widget _clearButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _searchController.clear();
          setState(() {
            _search = '';
            _categoryFilter = null;
          });
        },
        child: Container(
          width: 30,
          height: 17,
          color: const Color(0xFFE8E8E8),
          child: const CustomPaint(painter: _ClearGlyphPainter()),
        ),
      ),
    );
  }

  void _showAdvancedSearch() {
    final nameCtrl = TextEditingController(text: _search);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text(
            'بحث متقدم',
            style: TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم / كود / باركود الصنف',
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF444444),
                    ),
                    filled: false,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFBBBBBB)),
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'التصنيف يُحدد من قائمة التصنيف بجانب حقل البحث.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF777777)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Color(0xFF555555)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004AC0),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() => _search = nameCtrl.text);
                _searchController.text = nameCtrl.text;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('بحث'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreMenu() {
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(440, 100, 0, 0),
      color: Colors.white,
      items: const [
        PopupMenuItem<String>(
          value: 'all',
          height: 34,
          child: Text('تحديد الكل', style: TextStyle(fontSize: 12.5)),
        ),
        PopupMenuItem<String>(
          value: 'none',
          height: 34,
          child: Text('إلغاء التحديد', style: TextStyle(fontSize: 12.5)),
        ),
        PopupMenuItem<String>(
          value: 'reload',
          height: 34,
          child: Text('تحديث القائمة', style: TextStyle(fontSize: 12.5)),
        ),
      ],
    ).then((value) {
      if (!mounted || value == null) return;
      setState(() {
        switch (value) {
          case 'all':
            for (final r in _filtered) {
              if (r.product.id != null) _selectedIds.add(r.product.id!);
            }
            break;
          case 'none':
            _selectedIds.clear();
            break;
          case 'reload':
            _reload();
            break;
        }
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Left sidebar.
  // ---------------------------------------------------------------------------
  Widget _buildSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CRUD buttons.
        Row(
          textDirection: TextDirection.rtl,
          children: [
            _sidebarAsset(
              'assets/icons/products/crud_new.png',
              86,
              80,
              _openNew,
            ),
            const SizedBox(width: 6),
            _sidebarAsset(
              'assets/icons/products/crud_edit.png',
              86,
              80,
              _openEdit,
            ),
            const SizedBox(width: 6),
            _sidebarAsset(
              'assets/icons/products/crud_delete.png',
              86,
              80,
              _deleteSelected,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          textDirection: TextDirection.rtl,
          children: [
            _sidebarAsset(
              'assets/icons/products/print_list.png',
              216,
              45,
              _printList,
            ),
            const SizedBox(width: 5),
            _sidebarAsset(
              'assets/icons/products/share.png',
              49,
              45,
              _shareSelected,
            ),
          ],
        ),
        const SizedBox(height: 6),
        _sidebarAsset(
          'assets/icons/products/report_move.png',
          270,
          45,
          () => _showMovementsReport(),
        ),
        const SizedBox(height: 6),
        _sidebarAsset(
          'assets/icons/products/report_wh.png',
          270,
          45,
          () => _showWarehouseReport(),
        ),
        const SizedBox(height: 6),
        Row(
          textDirection: TextDirection.rtl,
          children: [
            _sidebarAsset(
              'assets/icons/products/half_move.png',
              132,
              45,
              () => _showMovementsReport(),
            ),
            const SizedBox(width: 6),
            _sidebarAsset(
              'assets/icons/products/half_perm.png',
              132,
              45,
              _showPermissionsInfo,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          textDirection: TextDirection.rtl,
          children: [
            _sidebarAsset(
              'assets/icons/products/half_prices.png',
              132,
              45,
              _editSellingPrice,
            ),
            const SizedBox(width: 6),
            _sidebarAsset(
              'assets/icons/products/half_labels.png',
              132,
              45,
              _showBarcodeLabels,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: _sidebarAsset(
            'assets/icons/products/serial.png',
            132,
            45,
            _searchSerial,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showWarehouseReport(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Text(
                  'كمية الصنف في المخازن',
                  style: TextStyle(
                    color: Color(0xFF0059E8),
                    fontSize: 14.5,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxHeight < 49
                ? const SizedBox.shrink()
                : _buildWarehouseBox(),
          ),
        ),
      ],
    );
  }

  Widget _sidebarAsset(String asset, double w, double h, VoidCallback onTap) {
    return HoverAssetButton(asset: asset, width: w, height: h, onTap: onTap);
  }

  /// Bordered warehouse box: header + green row + message / stock rows.
  Widget _buildWarehouseBox() {
    final selected = _selectedRow;
    return Container(
      margin: const EdgeInsets.only(top: 0),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDEDEDE)),
        color: Colors.white,
      ),
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 2),
              // Header row: المخزن | المتاح | كمية حجز
              Padding(
                padding: const EdgeInsets.only(left: 23, right: 12),
                child: SizedBox(
                  height: 20,
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      _whCell('المخزن', 100, isHeader: true),
                      _whSep(),
                      _whCell('المتاح', 65, isHeader: true),
                      _whSep(),
                      _whCell('كمية حجز', 65, isHeader: true),
                    ],
                  ),
                ),
              ),
              // Green row (values or empty).
              Padding(
                padding: const EdgeInsets.only(left: 23, right: 12),
                child: SizedBox(
                  height: 27,
                  child: FutureBuilder<List<Map<String, Object?>>>(
                    future: selected == null
                        ? Future<List<Map<String, Object?>>>.value(const [])
                        : _repo.getProductWarehouseStock(selected.product.id!),
                    builder: (context, snapshot) {
                      final stock = snapshot.data ?? const [];
                      return Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          _whCell(
                            selected == null ? '' : selected.product.name,
                            100,
                            green: true,
                          ),
                          _whSepGreen(),
                          _whCell(
                            stock.isEmpty ? '' : '${stock.first['available']}',
                            65,
                            green: true,
                          ),
                          _whSepGreen(),
                          _whCell(
                            stock.isEmpty ? '' : '${stock.first['reserved']}',
                            65,
                            green: true,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'لا يوجد كمية بالمخازن',
                    style: TextStyle(
                      color: const Color(0xFF7F7F7F),
                      fontSize: 15.5,
                      shadows: [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.6),
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Small sort arrow at the top-right inside the box.
          const Positioned(
            right: 2,
            top: 5,
            child: CustomPaint(
              painter: _SortArrowPainter(
                size: Size(10, 7),
                color: Color(0xFF444444),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _whCell(
    String text,
    double width, {
    bool isHeader = false,
    bool green = false,
  }) {
    return Container(
      width: width,
      height: double.infinity,
      color: isHeader
          ? const Color(0xFFDDDDDD)
          : green
          ? const Color(0xFF8DCDE2)
          : Colors.white,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 5),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isHeader ? 12 : 11.5,
          color: const Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  Widget _whSep() => Container(width: 1, color: const Color(0xFFC0C0C0));

  Widget _whSepGreen() => Container(width: 1, color: const Color(0xFFBCBCBC));

  // ---------------------------------------------------------------------------
  // Products table.
  // ---------------------------------------------------------------------------
  Widget _buildTable() {
    return RepaintBoundary(
      key: _tableBoundaryKey,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columnWidth = _cols.fold<double>(
              _cols.length - 1,
              (sum, column) => sum + column.width,
            );
            final contentWidth = math.max(columnWidth, constraints.maxWidth);
            return Column(
              children: [
                Expanded(
                  child: Scrollbar(
                    controller: _tableScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    thickness: 12,
                    radius: Radius.zero,
                    child: SingleChildScrollView(
                      controller: _tableScrollController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: contentWidth,
                        child: Column(
                          children: [
                            _tableHeader(),
                            Expanded(child: _tableBody()),
                            _tableFooter(),
                            // Reserve space so the horizontal thumb does not
                            // paint over the last product row or table footer.
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Container(height: 1, color: const Color(0xFF838383)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return SizedBox(
      height: 49,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          for (var i = 0; i < _cols.length; i++) ...[
            if (i > 0) _vSeparator(const Color(0xFFC0C0C0)),
            _headerCell(i),
          ],
        ],
      ),
    );
  }

  Widget _headerCell(int index) {
    final col = _cols[index];
    final sorted = _sortColumn == index;
    final isControl = col.label.isEmpty;
    return MouseRegion(
      cursor: isControl ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isControl
            ? null
            : () => setState(() {
                if (_sortColumn == index) {
                  _sortAsc = !_sortAsc;
                } else {
                  _sortColumn = index;
                  _sortAsc = true;
                }
              }),
        child: Container(
          width: col.width,
          height: double.infinity,
          color: const Color(0xFFDDDDDD),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.rtl,
              children: [
                if (!isControl) ...[
                  Flexible(
                    child: Text(
                      col.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF111111),
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                CustomPaint(
                  painter: _SortArrowPainter(
                    size: const Size(7, 4),
                    color: sorted
                        ? const Color(0xFF3D3D3D)
                        : const Color(0xFF5A5A5A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableBody() {
    final rows = _filtered;
    return Stack(
      children: [
        // Vertical grid lines for the empty area — built as a real row of
        // columns so every separator lines up exactly with the header/footer.
        Positioned.fill(
          child: IgnorePointer(
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                for (var i = 0; i < _cols.length; i++) ...[
                  if (i > 0)
                    Container(width: 1, color: const Color(0xFFE0E0E0)),
                  SizedBox(width: _cols[i].width),
                ],
              ],
            ),
          ),
        ),
        if (_loading)
          const SizedBox.shrink()
        else if (rows.isEmpty)
          const SizedBox.shrink()
        else
          ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: rows.length,
            itemBuilder: (context, index) => _dataRow(rows[index], index),
          ),
      ],
    );
  }

  Widget _dataRow(ProductListRow row, int index) {
    final product = row.product;
    final selected = product.id != null && _selectedIds.contains(product.id);
    final zebra = index.isEven ? Colors.white : const Color(0xFFF2F2F2);
    final values = <String>[
      '',
      '${product.id ?? ''}',
      product.name,
      '${row.totalQuantity}',
      row.unitName,
      _price(product.sellingPrice),
      _price(row.avgPurchasePrice),
      _price(row.lastPurchasePrice),
      product.barcode ?? '',
      product.productCode,
    ];

    return HoverBuilder(
      builder: (context, hovered) {
        final active = selected || hovered;
        final background = active ? const Color(0xFF8DCDE2) : zebra;
        final separator = active
            ? const Color(0xFF8DCDE2)
            : const Color(0xFFD6D6D6);
        return SizedBox(
          height: 27,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              // Control cell.
              Container(
                width: _cols[0].width,
                color: background,
                child: Stack(
                  children: [
                    if (selected)
                      const Positioned(
                        left: 5,
                        top: 9,
                        child: CustomPaint(painter: _LeftTrianglePainter()),
                      ),
                    Positioned(
                      left: 16,
                      top: 7,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _toggleSelect(product.id),
                        child: SizedBox(
                          width: 13,
                          height: 13,
                          child: CustomPaint(
                            painter: _CheckboxPainter(checked: selected),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _vSeparator(separator),
              for (var i = 1; i < _cols.length; i++) ...[
                _dataCell(values[i], _cols[i].width, background),
                if (i < _cols.length - 1) _vSeparator(separator),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _dataCell(String text, double width, Color background) {
    return Container(
      width: width,
      color: background,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 5, left: 3),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Color(0xFF111111)),
      ),
    );
  }

  Widget _vSeparator(Color color) => Container(width: 1, color: color);

  Widget _tableFooter() {
    final totalQty = _filtered.fold<int>(0, (sum, r) => sum + r.totalQuantity);
    return SizedBox(
      height: 27,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Control cell shows the current page number.
          Container(
            width: _cols[0].width,
            color: Colors.white,
            alignment: Alignment.center,
            child: const Text(
              '1',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF333333)),
            ),
          ),
          _vSeparator(const Color(0xFFC0C0C0)),
          for (var i = 1; i < _cols.length; i++) ...[
            Container(
              width: _cols[i].width,
              color: i == 3 ? const Color(0xFF8DCDE2) : const Color(0xFFDDDDDD),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 5),
              child: Text(
                i == 3 ? '$totalQty' : '',
                style: const TextStyle(fontSize: 12, color: Color(0xFF111111)),
              ),
            ),
            if (i < _cols.length - 1) _vSeparator(const Color(0xFFC0C0C0)),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions.
  // ---------------------------------------------------------------------------
  void _toggleSelect(int? id) {
    if (id == null) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  String _price(int amount) => amount.toString();

  Future<void> _openNew() async {
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0x33000000),
      builder: (_) => const ProductFormPage(),
    );
    _reload();
  }

  Future<void> _openEdit() async {
    final row = _selectedRow;
    if (row == null) {
      _info('اختر صنفاً من الجدول أولاً.');
      return;
    }
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0x33000000),
      builder: (_) => ProductFormPage(product: row.product),
    );
    _reload();
  }

  Future<void> _deleteSelected() async {
    final row = _selectedRow;
    if (row == null) {
      _info('اختر صنفاً من الجدول أولاً.');
      return;
    }
    final confirmed = await showConfirmDeleteDialog(
      context,
      question:
          'هل تريد حذف الصنف "${row.product.name}"؟ سيتم نقل الصنف إلى الأصناف غير النشطة ولن يظهر في القائمة.',
    );
    if (confirmed && row.product.id != null) {
      await _repo.deleteProduct(row.product.id!);
      _selectedIds.remove(row.product.id);
      await _reload();
      if (mounted) _info('تم حذف الصنف.');
    }
  }

  void _shareSelected() {
    showExportDialog(
      context,
      rows: _filtered,
      tableBoundaryKey: _tableBoundaryKey,
    );
  }

  void _printList() {
    final rows = _filtered;
    if (rows.isEmpty) {
      _info('لا توجد أصناف لطباعتها.');
      return;
    }
    final buffer = StringBuffer('قائمة الأصناف (${rows.length} صنف)\n');
    for (final r in rows) {
      buffer.writeln(
        '${r.product.productCode} - ${r.product.name} - ${_price(r.product.sellingPrice)}',
      );
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text(
            'طباعة قائمة الأصناف',
            style: TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
          ),
          content: SizedBox(
            width: 420,
            height: 320,
            child: SingleChildScrollView(
              child: SelectableText(
                buffer.toString(),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF222222),
                  height: 1.5,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: buffer.toString()));
                Navigator.of(dialogContext).pop();
                _info('تم نسخ القائمة إلى الحافظة للطباعة.');
              },
              child: const Text(
                'نسخ للطباعة',
                style: TextStyle(color: Color(0xFF004AC0)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'إغلاق',
                style: TextStyle(color: Color(0xFF555555)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMovementsReport() async {
    final row = _selectedRow;
    if (row == null) {
      _info('اختر صنفاً من الجدول أولاً.');
      return;
    }
    final movements = await _repo.getProductMovements(row.product.id!);
    if (!mounted) return;
    final buffer = StringBuffer();
    if (movements.isEmpty) {
      buffer.write('لا توجد حركات مسجلة لهذا الصنف.');
    } else {
      for (final m in movements) {
        buffer.writeln(
          '${m['movement_date']} | ${m['movement_type']} | كمية ${m['quantity']}'
          ' | من: ${m['from_name'] ?? '-'} | إلى: ${m['to_name'] ?? '-'}',
        );
      }
    }
    _reportDialog('تقرير حركة الصنف - ${row.product.name}', buffer.toString());
  }

  Future<void> _showWarehouseReport() async {
    final row = _selectedRow;
    if (row == null) {
      _info('اختر صنفاً من الجدول أولاً.');
      return;
    }
    final stock = await _repo.getProductWarehouseStock(row.product.id!);
    if (!mounted) return;
    final buffer = StringBuffer();
    if (stock.isEmpty) {
      buffer.write('لا يوجد كمية بالمخازن لهذا الصنف.');
    } else {
      for (final s in stock) {
        buffer.writeln('${s['name']} : ${s['available']}');
      }
    }
    _reportDialog('تقرير بضاعة مخزن - ${row.product.name}', buffer.toString());
  }

  void _reportDialog(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(
            title,
            style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
          ),
          content: SizedBox(
            width: 420,
            child: SelectableText(
              body,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF222222),
                height: 1.6,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: body));
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'نسخ',
                style: TextStyle(color: Color(0xFF004AC0)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'إغلاق',
                style: TextStyle(color: Color(0xFF555555)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissionsInfo() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text(
            'صلاحية الأصناف',
            style: TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المستخدم الحالي: مسؤول (كل الصلاحيات).',
                style: TextStyle(fontSize: 13, color: Color(0xFF333333)),
              ),
              SizedBox(height: 8),
              Text(
                'إضافة أصناف: مسموح\nتعديل أصناف: مسموح\nحذف أصناف: مسموح',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF333333),
                  height: 1.7,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'إغلاق',
                style: TextStyle(color: Color(0xFF555555)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSellingPrice() async {
    final row = _selectedRow;
    if (row == null) {
      _info('اختر صنفاً من الجدول أولاً.');
      return;
    }
    final priceCtrl = TextEditingController(
      text: _price(row.product.sellingPrice),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(
            'تعديل سعر البيع - ${row.product.name}',
            style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
          ),
          content: TextField(
            controller: priceCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
            cursorColor: const Color(0xFF004AC0),
            decoration: const InputDecoration(
              labelText: 'السعر الجديد',
              labelStyle: TextStyle(fontSize: 12.5, color: Color(0xFF444444)),
              floatingLabelStyle: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF004AC0),
              ),
              hintText: 'مثال: 1500',
              hintStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A3)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFBBBBBB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF004AC0), width: 1.6),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Color(0xFF555555)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004AC0),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final value = int.tryParse(priceCtrl.text);
      if (value == null) {
        _info('أدخل سعراً صحيحاً.');
        return;
      }
      final updated = row.product.copyWith(
        sellingPrice: value,
        updatedAt: DateTime.now(),
      );
      await _repo.updateProduct(updated);
      await _reload();
      if (mounted) _info('تم تحديث سعر البيع.');
    }
  }

  void _showBarcodeLabels() {
    final row = _selectedRow;
    if (row == null) {
      _info('اختر صنفاً من الجدول أولاً.');
      return;
    }
    final label =
        '${row.product.name}\n${row.product.barcode ?? row.product.productCode}';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text(
            'طباعة ملصقات الباركود',
            style: TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
          ),
          content: Container(
            width: 260,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCCCCCC)),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  row.product.barcode ?? row.product.productCode,
                  style: const TextStyle(
                    fontSize: 18,
                    letterSpacing: 2,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: label));
                Navigator.of(dialogContext).pop();
                _info('تم نسخ بيانات الملصق.');
              },
              child: const Text(
                'نسخ الملصق',
                style: TextStyle(color: Color(0xFF004AC0)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'إغلاق',
                style: TextStyle(color: Color(0xFF555555)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchSerial() async {
    final ctrl = TextEditingController(text: _search);
    final results = <ProductListRow>[];
    final searched = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              'بحث عن رقم سيريال',
              style: TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(
                      labelText: 'رقم السيريال / الباركود / الكود',
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF444444),
                      ),
                      filled: false,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFBBBBBB)),
                      ),
                    ),
                    onChanged: (v) {
                      setDialogState(() {
                        results
                          ..clear()
                          ..addAll(
                            _rows.where((r) {
                              final q = v.trim().toLowerCase();
                              return q.isNotEmpty &&
                                  ((r.product.barcode ?? '')
                                          .toLowerCase()
                                          .contains(q) ||
                                      r.product.productCode
                                          .toLowerCase()
                                          .contains(q));
                            }),
                          );
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ...results
                      .take(5)
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            '${r.product.productCode} - ${r.product.name}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                      ),
                  if (results.isEmpty)
                    const Text(
                      'لا توجد نتائج بعد.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text(
                  'إغلاق',
                  style: TextStyle(color: Color(0xFF555555)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004AC0),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('تطبيق على الجدول'),
              ),
            ],
          ),
        ),
      ),
    );
    if (searched == true) {
      setState(() {
        _search = ctrl.text;
        _searchController.text = ctrl.text;
      });
    }
  }

  void _info(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Table columns (right to left), widths measured from the reference.
// -----------------------------------------------------------------------------
class _Col {
  const _Col(this.width, this.label);

  final double width;
  final String label;
}

const List<_Col> _cols = [
  _Col(42, ''), // control
  _Col(70, 'رقم الصنف'),
  _Col(200, 'اسم الصنف'),
  _Col(100, 'إجمالي الكمية'),
  _Col(100, 'الوحدة'),
  _Col(75, 'سعر البيع'),
  _Col(75, 'متوسط سعر الشراء'),
  _Col(75, 'آخر سعر شراء'),
  _Col(120, 'باركود'),
  _Col(118, 'كود الصنف 1'),
];

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          color: Color(0xFF1A1A1A),
          height: 1.1,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Small painters.
// -----------------------------------------------------------------------------
class _ChevronPainter extends CustomPainter {
  const _ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..moveTo(2, size.height / 2 - 2)
      ..lineTo(size.width / 2, size.height / 2 + 2)
      ..lineTo(size.width - 2, size.height / 2 - 2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => false;
}

class _ClearGlyphPainter extends CustomPainter {
  const _ClearGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(const Offset(10, 4), const Offset(20, 13), paint);
    canvas.drawLine(const Offset(20, 4), const Offset(10, 13), paint);
  }

  @override
  bool shouldRepaint(_ClearGlyphPainter oldDelegate) => false;
}

class _SortArrowPainter extends CustomPainter {
  const _SortArrowPainter({required this.size, required this.color});

  final Size size;
  final Color color;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SortArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.size != size;
}

class _LeftTrianglePainter extends CustomPainter {
  const _LeftTrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(7, 0)
      ..lineTo(7, 10)
      ..lineTo(0, 5)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF3D3D3D));
  }

  @override
  bool shouldRepaint(_LeftTrianglePainter oldDelegate) => false;
}

class _CheckboxPainter extends CustomPainter {
  const _CheckboxPainter({required this.checked});

  final bool checked;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    canvas.drawRect(rect, Paint()..color = Colors.white);
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF808080)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (checked) {
      final paint = Paint()
        ..color = const Color(0xFF1A1A1A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      final path = Path()
        ..moveTo(3, size.height * 0.55)
        ..lineTo(size.width * 0.42, size.height - 3.5)
        ..lineTo(size.width - 3, 3);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CheckboxPainter oldDelegate) =>
      oldDelegate.checked != checked;
}
