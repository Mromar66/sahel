import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:inventory_app/app/shell/app_top_bar.dart';
import 'package:inventory_app/app/theme/shop_colors.dart';
import 'package:inventory_app/app/widgets/hover_widgets.dart';
import 'package:inventory_app/app/widgets/product_search_field.dart';
import 'package:inventory_app/app/widgets/shared_data_grid.dart';
import 'package:inventory_app/app/widgets/shop_command_rail.dart';
import 'package:inventory_app/app/widgets/shop_dialog_kit.dart';
import 'package:inventory_app/app/widgets/shop_dialogs.dart';
import 'package:inventory_app/app/widgets/shop_footer_bar.dart';
import 'package:inventory_app/app/widgets/document_custom_fields.dart';
import 'package:inventory_app/core/services/shop_preferences.dart';
import 'package:inventory_app/features/accounts/presentation/print_preview_dialog.dart';
import 'package:inventory_app/features/warehouse_ops/data/warehouse_ops_repository.dart';
import 'package:inventory_app/features/warehouse_ops/domain/warehouse_op_models.dart';

part 'warehouse_op_layout.dart';
part 'warehouse_op_table.dart';
part 'warehouse_op_dialogs.dart';

/// Which of the two green warehouse bars the operator is choosing.
enum _WarehouseSlot { source, target }

const Color _kYellow = ShopColors.yellow;
const Color _kGreen = ShopColors.green;
const Color _kTeal = ShopColors.teal;
const Color _kSoft = ShopColors.soft;
const Color _kField = ShopColors.field;
const Color _kInk = ShopColors.ink;
const Color _kLine = ShopColors.line;
const Color _kRowSelected = ShopColors.rowSelected;

/// تسوية مخزن / تحويل لمخزن — two warehouse documents built on exactly the
/// same screen as جرد مخزن.
///
/// The layout, table, resizing, scrolling, shortcuts and footer are identical
/// to the stocktaking screen; what changes is the document: its own tables,
/// its own numbering, its own validation and its own stock posting.
class WarehouseOpPage extends StatefulWidget {
  const WarehouseOpPage({super.key, required this.kind, this.editId});

  final WarehouseOpKind kind;

  /// Opens an existing document for editing.
  final int? editId;

  @override
  State<WarehouseOpPage> createState() => _WarehouseOpPageState();
}

class _WarehouseOpPageState extends State<WarehouseOpPage> {
  late final WarehouseOpKind _kind = widget.kind;
  final _repo = WarehouseOpsRepository();
  late final _tbl = _WarehouseOpTableController(kind: _kind);
  final _tableKey = GlobalKey<SharedDataGridState<WarehouseOpLine>>();
  final _searchKey = GlobalKey<ProductSearchFieldState<WarehouseOpProduct>>();
  final _searchFocus = FocusNode();
  final _pageFocus = FocusScopeNode(debugLabel: 'warehouse-op-page');

  final _sessionNo = TextEditingController();
  final _date = TextEditingController();
  final _time = TextEditingController();
  final _search = TextEditingController();
  final _notes = TextEditingController();

  final _grandTotal = ValueNotifier<int>(0);

  WarehouseOpWarehouse? _selectedWarehouse;
  WarehouseOpWarehouse? _targetWarehouse;

  /// Posting is the purpose of both documents, so the toggle starts enabled;
  /// the operator can still save a draft with it turned off.
  bool _applyStock = true;
  bool _saving = false;
  bool _confirmDelete = true;
  Map<int, String> _customFieldValues = {};

  int? _savedSessionId;
  String _savedNumber = '';

  /// True while an existing document is open through [WarehouseOpPage.editId].
  bool _editing = false;

  String get _newDocumentLabel => _kind.isTransfer
      ? 'تم تجهيز مستند تحويل جديد.'
      : 'تم تجهيز مستند تسوية جديد.';

  String get _defaultTargetName => 'اختر المخزن';

  @override
  void initState() {
    super.initState();
    _confirmDelete = ShopPreferences.confirmDelete;
    _editing = widget.editId != null;
    final now = DateTime.now();
    _date.text = _fmtDate(now);
    _time.text = _fmtTime(now);
    _sessionNo.text = _repo.nextSessionNumber(_kind);
    _tbl.addListener(_recompute);
    _loadLookups();
  }

  @override
  void dispose() {
    _tbl.removeListener(_recompute);
    _tbl.dispose();
    _grandTotal.dispose();
    _searchFocus.dispose();
    _pageFocus.dispose();
    for (final c in [_sessionNo, _date, _time, _search, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final warehouses = await _repo.getWarehouses();
      if (!mounted) return;
      setState(() {
        _selectedWarehouse = warehouses.isEmpty ? null : warehouses.first;
        if (_kind.isTransfer) {
          _targetWarehouse = warehouses.length > 1 ? warehouses[1] : null;
        }
        _sessionNo.text = _repo.nextSessionNumber(_kind);
      });
      if (widget.editId != null) {
        await _loadForEdit(widget.editId!);
      }
    } catch (_) {
      // The screen still opens; product search reports the error on use.
    }
  }

  Future<void> _loadForEdit(int id) async {
    try {
      final data = await _repo.loadSessionForEdit(_kind, id);
      final warehouses = await _repo.getWarehouses();
      if (!mounted) return;
      if (data == null) {
        _editing = false;
        _toast('${_kind.documentName} المطلوب غير موجود.');
        return;
      }
      final source = data.warehouseId != null
          ? warehouses.where((w) => w.id == data.warehouseId).firstOrNull
          : (data.fromWarehouseId != null
                ? warehouses
                      .where((w) => w.id == data.fromWarehouseId)
                      .firstOrNull
                : null);
      final target = data.toWarehouseId != null
          ? warehouses.where((w) => w.id == data.toWarehouseId).firstOrNull
          : null;
      setState(() {
        _tbl.clear();
        _tbl.locked = false;
        _editing = true;
        for (final line in data.lines) {
          _tbl.add(
            WarehouseOpLine(
              productId: line.productId,
              code: line.code,
              name: line.name,
              unit: line.unit,
              available: line.available,
              qty: line.qty,
              price: line.price,
            ),
          );
        }
        _selectedWarehouse =
            source ?? (warehouses.isEmpty ? null : warehouses.first);
        if (_kind.isTransfer) {
          _targetWarehouse =
              target ?? (warehouses.length > 1 ? warehouses[1] : null);
        }
        _sessionNo.text = data.number;
        _notes.text = data.notes;
        _applyStock = data.applied;
        if (data.date != null) {
          _date.text = _fmtDate(data.date!);
          _time.text = _fmtTime(data.date!);
        }
        _savedSessionId = data.id;
        _savedNumber = data.number;
        _customFieldValues = Map<int, String>.from(data.customFields);
      });
      _recompute();
      _toast('تم تحميل ${_kind.documentName} رقم ${data.number} للتعديل.');
    } catch (e) {
      if (!mounted) return;
      _editing = false;
      _toast(
        e is WarehouseOpValidationException
            ? e.message
            : 'تعذر تحميل ${_kind.documentName}: $e',
      );
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _fmtTime(DateTime d) {
    final h = (d.hour % 12 == 0 ? 12 : d.hour % 12).toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _editCustomFields() async {
    final values = await showDocumentCustomFieldsDialog(
      context,
      initialValues: _customFieldValues,
    );
    if (!mounted || values == null) return;
    setState(() => _customFieldValues = values);
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  /// Return keyboard focus to the page after a dialog closes, so the
  /// F-shortcuts keep working.
  void _focusPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      _pageFocus.requestFocus();
    });
  }

  void _recompute() {
    if (_grandTotal.value != _tbl.grossTotal) {
      _grandTotal.value = _tbl.grossTotal;
    }
  }

  // ---------------------------------------------------------------------------
  // Products.
  // ---------------------------------------------------------------------------
  void _addProduct(WarehouseOpProduct product) {
    final existing = _tbl.lines.indexWhere((l) => l.productId == product.id);
    if (existing >= 0) {
      _tbl.select(existing);
      _toast('الصنف «${product.name}» موجود مسبقاً في هذا المستند.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tableKey.currentState?.scrollToSelected();
      });
      return;
    }
    final available = _repo.stockForWarehouse(
      product.id,
      _selectedWarehouse?.id,
    );
    _tbl.add(
      WarehouseOpLine(
        productId: product.id,
        code: product.code,
        name: product.name,
        unit: product.unitName.trim().isEmpty ? 'حبة' : product.unitName,
        available: available,
        qty: available,
        price: product.purchasePrice,
      ),
    );
    _toast('تمت إضافة «${product.name}» إلى المستند.');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tableKey.currentState?.scrollToSelected();
    });
  }

  Future<void> _submitSearch(String text) async {
    final key = text.trim();
    if (key.isEmpty) {
      _toast('اكتب اسم الصنف أو الباركود أولاً.');
      return;
    }
    try {
      final byCode = await _repo.findByBarcode(key);
      if (!mounted) return;
      if (byCode != null) {
        _search.clear();
        _addProduct(byCode);
        return;
      }
      final results = await _repo.searchProducts(key);
      if (!mounted) return;
      if (results.isNotEmpty) {
        _search.clear();
        _addProduct(results.first);
      } else {
        _toast('لا توجد نتائج مطابقة لـ «$key».');
      }
    } catch (e) {
      _toast('تعذر البحث في الأصناف: $e');
    }
  }

  void _onSearchPicked(WarehouseOpProduct product) {
    _search.clear();
    _addProduct(product);
  }

  Future<void> _showQuickList() async {
    final product = await showDialog<WarehouseOpProduct>(
      context: context,
      builder: (_) => QuickProductDialog<WarehouseOpProduct>(
        title: 'قائمة سريعة',
        loader: () => _repo.listProducts(),
      ),
    );
    _focusPage();
    if (!mounted || product == null) return;
    _addProduct(product);
  }

  Future<void> _showCategories() async {
    try {
      final categories = await _repo.getCategories();
      if (!mounted) return;
      if (categories.isEmpty) {
        _toast('لا توجد أقسام مسجلة.');
        return;
      }
      final picked = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => CategoryPickerDialog(categories: categories),
      );
      _focusPage();
      if (!mounted || picked == null) return;
      final id = (picked['id'] as num).toInt();
      final product = await showDialog<WarehouseOpProduct>(
        context: context,
        builder: (_) => QuickProductDialog<WarehouseOpProduct>(
          title: 'أصناف قسم ${picked['name']}',
          loader: () => _repo.listProducts(categoryId: id),
        ),
      );
      _focusPage();
      if (!mounted || product == null) return;
      _addProduct(product);
    } catch (e) {
      _toast('تعذر فتح الأقسام: $e');
    }
  }

  Future<void> _inquiry() async {
    WarehouseOpProduct? product;
    final selected = _tbl.selectedIndex;
    final line = selected >= 0 ? _tbl.lines[selected] : null;
    final key = _search.text.trim();
    try {
      if (line != null) {
        final results = await _repo.searchProducts(line.name);
        product =
            results.where((p) => p.id == line.productId).firstOrNull ??
            results.firstOrNull;
      } else if (key.isNotEmpty) {
        product = await _repo.findByBarcode(key);
        if (product == null) {
          final results = await _repo.searchProducts(key);
          product = results.firstOrNull;
        }
      }
    } catch (e) {
      _toast('تعذر الاستعلام: $e');
      return;
    }
    if (!mounted) return;
    if (product == null) {
      _toast('حدد صنفاً من الجدول أو اكتب اسمه للاستعلام.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => InquiryDialog<WarehouseOpProduct>(product: product!),
    );
    _focusPage();
  }

  // ---------------------------------------------------------------------------
  // Warehouses.
  // ---------------------------------------------------------------------------
  Future<void> _pickWarehouse(_WarehouseSlot slot) async {
    List<WarehouseOpWarehouse> warehouses;
    try {
      warehouses = await _repo.getWarehouses();
    } catch (e) {
      _toast('تعذر تحميل المخازن: $e');
      return;
    }
    if (!mounted) return;
    if (warehouses.isEmpty) {
      _toast(
        _kind.isTransfer
            ? 'لا توجد مخازن مسجلة — يحتاج التحويل إلى مخزنين على الأقل.'
            : 'لا توجد مخازن مسجلة — تتم التسوية على المخزون الحالي للمنتجات.',
      );
      return;
    }
    final isTarget = slot == _WarehouseSlot.target;
    final picked = await showDialog<WarehouseOpWarehouse>(
      context: context,
      builder: (_) => _OpWarehousePickerDialog(
        title: !_kind.isTransfer
            ? 'اختيار المخزن'
            : (isTarget ? 'اختيار مخزن الوجهة' : 'اختيار مخزن المصدر'),
        warehouses: warehouses,
        selectedId: isTarget ? _targetWarehouse?.id : _selectedWarehouse?.id,
      ),
    );
    _focusPage();
    if (!mounted || picked == null) return;
    setState(() {
      if (isTarget) {
        _targetWarehouse = picked;
      } else {
        _selectedWarehouse = picked;
        for (final line in _tbl.lines) {
          if (line.productId != null) {
            line.available = _repo.stockForWarehouse(
              line.productId!,
              picked.id,
            );
          }
        }
      }
    });
    _toast('تم اختيار المخزن «${picked.name}».');
  }

  // ---------------------------------------------------------------------------
  // Save / new / delete.
  // ---------------------------------------------------------------------------
  Future<void> _save({bool resetAfter = false}) async {
    if (_saving) return;
    if (_savedSessionId != null && !_editing) {
      if (resetAfter) {
        _newSession();
      } else {
        _toast(
          '${_kind.documentName} رقم $_savedNumber محفوظ بالفعل. '
          'اضغط F10 لمستند جديد.',
        );
      }
      return;
    }
    if (_tbl.lines.isEmpty) {
      _toast('أضف صنفاً واحداً على الأقل قبل الحفظ.');
      return;
    }
    if (_kind.isTransfer && _applyStock) {
      final from = _selectedWarehouse?.id;
      final to = _targetWarehouse?.id;
      if (from == null || to == null) {
        _toast(
          'لا توجد مخازن كافية للتحويل — احفظ مخزنين على الأقل ثم اختر '
          'مخزن المصدر ومخزن الوجهة.',
        );
        return;
      }
      if (from == to) {
        _toast('اختر مخزن مصدر ومخزن وجهة مختلفين قبل التحويل.');
        return;
      }
    }

    final changed = _kind.isTransfer
        ? _tbl.lines.where((l) => l.qty != 0).length
        : _tbl.lines.where((l) => l.difference != 0).length;
    if (_applyStock) {
      final fromName = _selectedWarehouse?.name ?? 'المخزن الرئيسي';
      final toName = _targetWarehouse?.name ?? '';
      final ok = await showShopConfirm(
        context,
        title: _kind.isTransfer
            ? 'ترحيل التحويل إلى المخزون'
            : 'ترحيل التسوية إلى المخزون',
        message: _kind.isTransfer
            ? 'سيتم حفظ مستند التحويل بإجمالي ${_tbl.grossTotal} ونقل '
                  '$changed صنفاً من «$fromName» إلى «$toName».'
            : 'سيتم حفظ مستند التسوية بإجمالي ${_tbl.grossTotal} '
                  'وترحيل فروق التسوية إلى المخزون.\n'
                  'عدد الأصناف التي تختلف كميتها عن المسجل: $changed.',
        confirmLabel: 'حفظ وترحيل',
      );
      _focusPage();
      if (!mounted || !ok) return;
    }

    final number = _sessionNo.text.trim();
    setState(() => _saving = true);
    try {
      final WarehouseOpSaveResult result;
      if (_editing && _savedSessionId != null) {
        result = _kind.isTransfer
            ? await _repo.updateTransfer(
                sessionId: _savedSessionId!,
                fromWarehouseId: _selectedWarehouse?.id,
                toWarehouseId: _targetWarehouse?.id,
                sessionNumber: number.isEmpty
                    ? _repo.nextSessionNumber(_kind)
                    : number,
                lines: _tbl.lines.map((l) => l.clone()).toList(),
                notes: _notes.text.trim(),
                customFields: _customFieldValues,
                applyStock: _applyStock,
              )
            : await _repo.updateAdjustment(
                sessionId: _savedSessionId!,
                warehouseId: _selectedWarehouse?.id,
                sessionNumber: number.isEmpty
                    ? _repo.nextSessionNumber(_kind)
                    : number,
                lines: _tbl.lines.map((l) => l.clone()).toList(),
                notes: _notes.text.trim(),
                customFields: _customFieldValues,
                applyStock: _applyStock,
              );
      } else {
        result = _kind.isTransfer
            ? await _repo.saveTransfer(
                fromWarehouseId: _selectedWarehouse?.id,
                toWarehouseId: _targetWarehouse?.id,
                sessionNumber: number.isEmpty
                    ? _repo.nextSessionNumber(_kind)
                    : number,
                lines: _tbl.lines.map((l) => l.clone()).toList(),
                notes: _notes.text.trim(),
                customFields: _customFieldValues,
                applyStock: _applyStock,
              )
            : await _repo.saveAdjustment(
                warehouseId: _selectedWarehouse?.id,
                sessionNumber: number.isEmpty
                    ? _repo.nextSessionNumber(_kind)
                    : number,
                lines: _tbl.lines.map((l) => l.clone()).toList(),
                notes: _notes.text.trim(),
                customFields: _customFieldValues,
                applyStock: _applyStock,
              );
      }
      if (!mounted) return;
      final wasEditing = _editing;
      setState(() {
        _saving = false;
        _editing = false;
        _savedSessionId = result.sessionId;
        _savedNumber = result.sessionNumber;
        _tbl.locked = true;
      });
      _toast(
        wasEditing
            ? 'تم تحديث ${_kind.documentName} رقم ${result.sessionNumber}.'
            : (result.applied
                  ? 'تم حفظ ${_kind.documentName} رقم ${result.sessionNumber} '
                        'وترحيل ${result.changedCount} صنفاً.'
                  : 'تم حفظ ${_kind.documentName} رقم ${result.sessionNumber} '
                        'بدون ترحيل للمخزون.'),
      );
      if (resetAfter) _newSession(alreadySaved: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(
        e is WarehouseOpValidationException
            ? e.message
            : 'تعذر حفظ ${_kind.documentName}: $e',
      );
    }
  }

  void _newSession({bool alreadySaved = false}) {
    setState(() {
      _tbl.clear();
      _tbl.locked = false;
      _savedSessionId = null;
      _savedNumber = '';
      _editing = false;
      _notes.clear();
      _customFieldValues = {};
      _search.clear();
      _sessionNo.text = _repo.nextSessionNumber(_kind);
      final now = DateTime.now();
      _date.text = _fmtDate(now);
      _time.text = _fmtTime(now);
    });
    _recompute();
    _toast(
      alreadySaved ? 'تم حفظ المستند وفتح مستند جديد.' : _newDocumentLabel,
    );
  }

  Future<void> _deleteDocument() async {
    if (_tbl.lines.isEmpty && _savedSessionId == null) {
      _toast('لا يوجد ${_kind.documentName} لمسحه.');
      return;
    }
    final ok = await showShopConfirm(
      context,
      title: 'مسح ${_kind.documentName}',
      message: 'هل تريد مسح المستند الحالي وبدء مستند جديد؟',
      confirmLabel: 'مسح',
    );
    _focusPage();
    if (!mounted || !ok) return;
    _newSession();
  }

  // ---------------------------------------------------------------------------
  // Row commands.
  // ---------------------------------------------------------------------------
  Future<void> _removeSelected({bool ask = false}) async {
    final index = _tbl.selectedIndex;
    if (index < 0) {
      _toast('حدد سطراً من الجدول أولاً.');
      return;
    }
    if (_tbl.locked) {
      _toast('${_kind.documentName} محفوظ — لا يمكن تعديل سطوره.');
      return;
    }
    if (ask && _confirmDelete) {
      final ok = await showShopConfirm(
        context,
        title: 'حذف السطر',
        message: 'هل تريد حذف السطر المحدد؟',
        confirmLabel: 'حذف',
      );
      _focusPage();
      if (!mounted || !ok) return;
    }
    _tbl.removeAt(index);
    _toast('تم حذف السطر.');
  }

  List<LineOption> get _lineOptionsList => const [
    LineOption(key: 'duplicate', label: 'تكرار السطر'),
    LineOption(key: 'up', label: 'تحريك السطر لأعلى'),
    LineOption(key: 'down', label: 'تحريك السطر لأسفل'),
    LineOption(key: 'zero', label: 'تصفير الكمية'),
    LineOption(key: 'delete', label: 'حذف السطر', danger: true),
  ];

  Future<void> _lineOptions() async {
    if (_tbl.selectedIndex < 0) {
      _toast('حدد سطراً من الجدول أولاً.');
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (_) => LineOptionsDialog(options: _lineOptionsList),
    );
    _focusPage();
    if (!mounted || action == null) return;
    switch (action) {
      case 'duplicate':
        _tbl.duplicateSelected();
        _toast('تم تكرار السطر.');
      case 'up':
        _tbl.moveSelected(-1);
      case 'down':
        _tbl.moveSelected(1);
      case 'zero':
        _tbl.update(_tbl.selectedIndex, qty: 0);
        _toast('تم تصفير الكمية.');
      case 'delete':
        await _removeSelected();
    }
  }

  void _moveSelection(int delta) {
    _tbl.moveSelection(delta);
    _tableKey.currentState?.scrollToSelected();
  }

  Future<void> _editPrices() async {
    if (_tbl.lines.isEmpty) {
      _toast('لا توجد سطور لتعديل أسعارها.');
      return;
    }
    if (_tbl.locked) {
      _toast('${_kind.documentName} محفوظ — لا يمكن تعديل أسعاره.');
      return;
    }
    final prices = await showDialog<Map<int, int>>(
      context: context,
      builder: (_) => BulkPriceDialog(
        title: _kind.isTransfer ? 'تعديل أسعار التحويل' : 'تعديل أسعار التسوية',
        items: _tbl.lines
            .map((l) => BulkPriceItem(name: l.name, price: l.price))
            .toList(),
      ),
    );
    _focusPage();
    if (!mounted || prices == null) return;
    prices.forEach((index, price) {
      _tbl.update(index, price: price);
    });
    _toast('تم تحديث الأسعار.');
  }

  // ---------------------------------------------------------------------------
  // Print / export / share.
  // ---------------------------------------------------------------------------
  Future<void> _print() async {
    const columns = [
      'الصنف',
      'الوحدة',
      'المتاح',
      'الكمية',
      'السعر',
      'الإجمالي',
    ];
    final qtyKey = _kind.isTransfer ? 'transfer_qty' : 'adjusted_qty';
    var title = _kind.printTitle;
    var rows = _tbl.lines
        .map(
          (l) => [
            l.name,
            l.unit,
            '${l.available}',
            '${l.qty}',
            '${l.price}',
            '${l.gross}',
          ],
        )
        .toList();
    if (_savedSessionId != null) {
      try {
        final session = await _repo.getSession(_kind, _savedSessionId!);
        final items = await _repo.getSessionItems(_kind, _savedSessionId!);
        if (!mounted) return;
        if (session != null) {
          title = '${_kind.printTitle} رقم ${session['session_number']}';
        }
        if (items.isNotEmpty) {
          rows = items
              .map(
                (r) => [
                  '${r['product_name']}',
                  '${r['unit_name'] ?? ''}',
                  '${r['available_qty']}',
                  '${r[qtyKey]}',
                  '${r['price']}',
                  '${r['total']}',
                ],
              )
              .toList();
        }
      } catch (_) {}
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) =>
          PrintPreviewDialog(title: title, columns: columns, rows: rows),
    );
    _focusPage();
  }

  Future<void> _exportExcel() async {
    if (_tbl.lines.isEmpty) {
      _toast('أضف أصنافاً لتصديرها إلى Excel.');
      return;
    }
    try {
      final dir = Directory('invoices');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(
        '${dir.path}/${_kind.exportPrefix}_${_sessionNo.text.trim()}_$stamp.csv',
      );
      final buffer = StringBuffer('\uFEFF');
      buffer.writeln('رقم الصنف,اسم الصنف,الوحدة,المتاح,الكمية,السعر,الإجمالي');
      for (final line in _tbl.lines) {
        buffer.writeln(
          '${line.code},"${line.name}",${line.unit},${line.available},'
          '${line.qty},${line.price},${line.gross}',
        );
      }
      buffer.writeln(',,,,,${_tbl.grossTotal}');
      await file.writeAsString(buffer.toString(), flush: true);
      if (!mounted) return;
      _toast('تم تصدير المستند إلى ${file.path}');
    } catch (e) {
      _toast('تعذر التصدير إلى Excel: $e');
    }
  }

  Future<void> _share() async {
    final buffer = StringBuffer();
    buffer.writeln('${_kind.printTitle} رقم ${_sessionNo.text.trim()}');
    if (_kind.isTransfer) {
      buffer.writeln(
        'من: ${_selectedWarehouse?.name ?? 'المخزن الرئيسي'} → '
        'إلى: ${_targetWarehouse?.name ?? ''}',
      );
    } else if (_selectedWarehouse != null) {
      buffer.writeln('المخزن: ${_selectedWarehouse!.name}');
    }
    buffer.writeln('التاريخ: ${_date.text}');
    for (final line in _tbl.lines) {
      buffer.writeln(
        '${line.name}: متاح ${line.available} / الكمية ${line.qty} = '
        '${line.gross}',
      );
    }
    buffer.writeln('الإجمالي: ${_grandTotal.value}');
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    _toast('تم نسخ نص ${_kind.documentName}.');
  }

  Future<void> _printBarcode() async {
    if (_tbl.lines.isEmpty) {
      _toast('أضف أصنافاً لطباعة باركوداتها.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => BarcodeLabelsDialog(
        title: '${_kind.title} ${_sessionNo.text.trim()}',
        labels: _tbl.lines
            .map(
              (l) => BarcodeLabel(code: l.code, name: l.name, price: l.price),
            )
            .toList(),
      ),
    );
    _focusPage();
  }

  Future<void> _showSettings() async {
    final settings = await showDialog<ShopSettings>(
      context: context,
      builder: (_) => ShopSettingsDialog(
        title: _kind.isTransfer
            ? 'إعدادات شاشة التحويل'
            : 'إعدادات شاشة التسوية',
        confirmDelete: _confirmDelete,
        roundStep: 5,
        showRoundStep: false,
      ),
    );
    _focusPage();
    if (!mounted || settings == null) return;
    setState(() => _confirmDelete = settings.confirmDelete);
    ShopPreferences.save(confirmDelete: settings.confirmDelete);
    _toast('تم حفظ إعدادات الشاشة.');
  }

  List<(String, String)> get _shortcuts => [
    ('F4', 'طباعة ${_kind.documentName}'),
    ('F5', 'تعديل الكمية'),
    ('F6', 'تعديل السعر'),
    ('F7', 'خيارات السطر'),
    ('F8', 'حذف السطر'),
    ('F9', 'حفظ ${_kind.documentName}'),
    ('F10', _kind.isTransfer ? 'مستند تحويل جديد' : 'مستند تسوية جديد'),
    ('F12', 'حفظ وفتح مستند جديد'),
    ('Enter', 'الانتقال للسطر التالي'),
    ('Tab', 'الانتقال للخلية التالية'),
    ('Esc', 'إلغاء تعديل الخلية'),
  ];

  Future<void> _showShortcuts() async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          ShopShortcutsDialog(title: _kind.shortcutsTitle, items: _shortcuts),
    );
    _focusPage();
  }

  Future<void> _showSubscription() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _OpSubscriptionDialog(),
    );
    _focusPage();
  }

  void _toggleApplyStock() {
    setState(() => _applyStock = !_applyStock);
    if (_kind.isTransfer) {
      _toast(
        _applyStock
            ? 'سيتم ترحيل التحويل وكتابة حركات المخزون عند الحفظ.'
            : 'لن يتم ترحيل التحويل — سيُحفظ المستند فقط.',
      );
      return;
    }
    _toast(
      _applyStock
          ? 'سيتم ترحيل فروق التسوية إلى المخزون عند الحفظ.'
          : 'لن يتم ترحيل فروق التسوية إلى المخزون عند الحفظ.',
    );
  }

  // ---------------------------------------------------------------------------
  // Keyboard shortcuts.
  // ---------------------------------------------------------------------------
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isAltPressed) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.f4) {
      _print();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f5) {
      _tableKey.currentState?.editSelected(4);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f6) {
      _tableKey.currentState?.editSelected(5);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f7) {
      _lineOptions();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f8) {
      _removeSelected(ask: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f9) {
      _save();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f10) {
      _newSession();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f12) {
      _save(resetAfter: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Build.
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return withPlainInputs(
      FocusScope(
        node: _pageFocus,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: _buildShell(),
      ),
    );
  }

  Widget _buildShell() {
    return AppShell(
      activeTab: AppTab.products,
      extraTabLabel: _kind.tabLabel,
      extraTabColor: _kTeal,
      extraTabTextColor: Colors.white,
      onExtraTabClose: _close,
      hideActiveTab: true,
      extraTabWidth: 201,
      child: Column(
        children: [
          Expanded(
            child: Row(
              textDirection: TextDirection.ltr,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildMain()),
                _buildRightStrip(),
              ],
            ),
          ),
          _buildFooter(),
          _buildLicenseBar(),
        ],
      ),
    );
  }

  Widget _buildMain() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: SizedBox(width: 882, height: 136, child: _buildTopBlock()),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                const designWidth = 882.0;
                if (c.maxWidth >= designWidth - 0.5) {
                  return _buildTableArea();
                }
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topRight,
                  child: SizedBox(
                    width: designWidth,
                    height: 540,
                    child: _buildTableArea(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
