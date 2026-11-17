import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:printing/printing.dart';

import 'package:inventory_app/app/shell/app_top_bar.dart';
import 'package:inventory_app/app/theme/shop_colors.dart';
import 'package:inventory_app/app/widgets/hover_widgets.dart';
import 'package:inventory_app/app/widgets/shop_dialog_kit.dart';
import 'package:inventory_app/features/accounts/presentation/print_preview_dialog.dart';
import 'package:inventory_app/features/invoices/data/invoice_archive_repository.dart';
import 'package:inventory_app/features/invoices/domain/invoice_archive_models.dart';
import 'package:inventory_app/features/products/presentation/export_dialog.dart';

part 'invoice_archive_layout.dart';
part 'invoice_archive_table.dart';

const Color _kYellow = ShopColors.yellow;
const Color _kGreen = ShopColors.panelGreen;
const Color _kSoft = ShopColors.soft;
const Color _kInk = ShopColors.ink;
const Color _kRed = ShopColors.red;
const Color _kHeader = Color(0xFFDDDDDD);
const Color _kGridLine = Color(0xFFE9E9E9);
const Color _kBorder = Color(0xFFC9C9C9);

final intl.NumberFormat _kNumberFormat = intl.NumberFormat('#,##0', 'en');

String _money(int value) => _kNumberFormat.format(value);

/// The two search modes of the archive screen.
enum ArchiveSearchMode { general, advanced }

/// الفواتير — the document archive. Every tab reads one real document family
/// and every action uses the same tables as the document screens.
class InvoiceArchivePage extends StatefulWidget {
  const InvoiceArchivePage({super.key});

  @override
  State<InvoiceArchivePage> createState() => _InvoiceArchivePageState();
}

class _InvoiceArchivePageState extends State<InvoiceArchivePage> {
  final _repo = InvoiceArchiveRepository();
  final _pageFocus = FocusScopeNode(debugLabel: 'invoice-archive-page');
  final _hScroll = ScrollController();
  final _vScroll = ScrollController();
  final _tableKey = GlobalKey();

  ArchiveDocType _type = ArchiveDocType.sale;
  ArchiveSearchMode _mode = ArchiveSearchMode.general;
  ArchiveSort _sort = const ArchiveSort();
  ArchiveItemSort _itemSort = const ArchiveItemSort();

  bool _showItems = false;
  bool _loaded = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  List<ArchiveDocument> _documents = const [];
  List<ArchiveItem> _items = const [];
  ArchiveTotals _totals = const ArchiveTotals();
  int _totalCount = 0;
  bool _hasMore = false;

  final Set<String> _selection = {};
  String? _anchorKey;

  bool _today = true;
  String _period = 'today';

  late final TextEditingController _invoiceNumber;
  late final TextEditingController _exactNumber;
  late final TextEditingController _partyName;
  late final TextEditingController _itemName;
  late final TextEditingController _itemCode;
  late final TextEditingController _barcode;
  late final TextEditingController _notes;
  late final TextEditingController _minAmount;
  late final TextEditingController _maxAmount;
  late final TextEditingController _fromDate;
  late final TextEditingController _toDate;
  late final TextEditingController _fromTime;
  late final TextEditingController _toTime;

  List<ArchiveOption> _warehouses = const [];
  List<ArchiveOption> _accounts = const [];
  List<ArchiveOption> _treasuries = const [];
  List<ArchiveOption> _categories = const [];
  List<ArchiveStringOption> _accountTypes = const [];

  static const int _pageSize = 100;

  @override
  void initState() {
    super.initState();
    _invoiceNumber = TextEditingController();
    _exactNumber = TextEditingController();
    _partyName = TextEditingController();
    _itemName = TextEditingController();
    _itemCode = TextEditingController();
    _barcode = TextEditingController();
    _notes = TextEditingController();
    _minAmount = TextEditingController();
    _maxAmount = TextEditingController();
    _fromDate = TextEditingController();
    _toDate = TextEditingController();
    _fromTime = TextEditingController();
    _toTime = TextEditingController();
    final today = _dateOnly(DateTime.now());
    _filters = ArchiveFilters(
      fromDate: today,
      toDate: today,
      fromTime: '00:00',
      toTime: '23:59',
    );
    _syncDateControllers();
    _syncTimeControllers();
    _vScroll.addListener(_onScroll);
    _loadLookups();
  }

  ArchiveFilters _filters = const ArchiveFilters();

  @override
  void dispose() {
    _pageFocus.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    _invoiceNumber.dispose();
    _exactNumber.dispose();
    _partyName.dispose();
    _itemName.dispose();
    _itemCode.dispose();
    _barcode.dispose();
    _notes.dispose();
    _minAmount.dispose();
    _maxAmount.dispose();
    _fromDate.dispose();
    _toDate.dispose();
    _fromTime.dispose();
    _toTime.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Lookups.
  // ---------------------------------------------------------------------------
  void _loadLookups() {
    try {
      final warehouses = _repo.warehouses();
      final accounts = _repo.accounts();
      final treasuries = _repo.treasuries();
      final categories = _repo.categories();
      final accountTypes = _repo.accountTypes();
      if (!mounted) return;
      setState(() {
        _warehouses = warehouses;
        _accounts = accounts;
        _treasuries = treasuries;
        _categories = categories;
        _accountTypes = accountTypes;
      });
    } catch (error) {
      if (mounted) _toast('تعذر تحميل قوائم البحث: ${_errorText(error)}');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------------------
  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _close() => context.go('/');

  String _errorText(Object error) {
    if (error is ArchiveException) return error.message;
    final text = '$error';
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : text;
  }

  void _focusPage() => _pageFocus.requestFocus();

  String _optionName(List<ArchiveOption> options, int? id) {
    if (id == null) return '';
    for (final option in options) {
      if (option.id == id) return option.name;
    }
    return '';
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _fmtFilterDate(DateTime? value) {
    if (value == null) return '';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  static String _fmtFilterTime(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '${display.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')} '
        '${hour < 12 ? 'AM' : 'PM'}';
  }

  static String _timeValue(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';

  void _syncDateControllers() {
    _fromDate.text = _fmtFilterDate(_filters.fromDate);
    _toDate.text = _fmtFilterDate(_filters.toDate);
  }

  void _syncTimeControllers() {
    _fromTime.text = _fmtFilterTime(_filters.fromTime);
    _toTime.text = _fmtFilterTime(_filters.toTime);
  }

  void _syncControllersToFilters() {
    _invoiceNumber.text = _filters.invoiceNumber;
    _exactNumber.text = _filters.exactNumber;
    _partyName.text = _filters.partyName;
    _itemName.text = _filters.itemName;
    _itemCode.text = _filters.itemCode;
    _barcode.text = _filters.barcode;
    _notes.text = _filters.notes;
    _minAmount.text = _filters.minAmount == null ? '' : '${_filters.minAmount}';
    _maxAmount.text = _filters.maxAmount == null ? '' : '${_filters.maxAmount}';
    _syncDateControllers();
    _syncTimeControllers();
  }

  void _updateFilters(ArchiveFilters next) {
    setState(() => _filters = next);
  }

  // ---------------------------------------------------------------------------
  // Dates / period.
  // ---------------------------------------------------------------------------
  Future<void> _pickDate(bool isFrom) async {
    final current = isFrom ? _filters.fromDate : _filters.toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: isFrom ? 'من تاريخ' : 'إلى تاريخ',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _filters = isFrom
          ? _filters.copyWith(fromDate: _dateOnly(picked))
          : _filters.copyWith(toDate: _dateOnly(picked));
      _today = false;
      _period = '';
    });
    _syncDateControllers();
    _focusPage();
  }

  Future<void> _pickTime(bool isFrom) async {
    final current = isFrom ? _filters.fromTime : _filters.toTime;
    final parts = (current ?? '').split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isFrom ? 'من وقت' : 'إلى وقت',
    );
    if (picked == null || !mounted) return;
    final value = _timeValue(picked.hour, picked.minute);
    setState(() {
      _filters = isFrom
          ? _filters.copyWith(fromTime: value)
          : _filters.copyWith(toTime: value);
    });
    _syncTimeControllers();
    _focusPage();
  }

  void _clearDate(bool isFrom) {
    setState(() {
      _filters = isFrom
          ? _filters.copyWith(fromDate: null)
          : _filters.copyWith(toDate: null);
      _today = false;
      _period = '';
    });
    _syncDateControllers();
  }

  void _clearTime(bool isFrom) {
    setState(() {
      _filters = isFrom
          ? _filters.copyWith(fromTime: '')
          : _filters.copyWith(toTime: '');
    });
    _syncTimeControllers();
  }

  void _toggleToday(bool value) {
    final today = _dateOnly(DateTime.now());
    setState(() {
      _today = value;
      _period = value ? 'today' : '';
      _filters = value
          ? _filters.copyWith(fromDate: today, toDate: today)
          : _filters.copyWith(fromDate: null, toDate: null);
    });
    _syncDateControllers();
  }

  void _applyPeriod(String value) {
    final today = _dateOnly(DateTime.now());
    DateTime? from;
    DateTime? to;
    switch (value) {
      case 'today':
        from = today;
        to = today;
      case 'week':
        from = today.subtract(const Duration(days: 6));
        to = today;
      case 'month':
        from = DateTime(today.year, today.month);
        to = today;
      case 'year':
        from = DateTime(today.year);
        to = today;
      default:
        from = null;
        to = null;
    }
    setState(() {
      _period = value;
      _today = value == 'today';
      _filters = _filters.copyWith(fromDate: from, toDate: to);
    });
    _syncDateControllers();
  }

  // ---------------------------------------------------------------------------
  // Tabs / modes.
  // ---------------------------------------------------------------------------
  void _setType(ArchiveDocType next) {
    if (_type == next) return;
    setState(() {
      _type = next;
      _filters = _sanitizeFilters(_filters, next);
      _documents = const [];
      _items = const [];
      _totals = const ArchiveTotals();
      _totalCount = 0;
      _hasMore = false;
      _selection.clear();
      _anchorKey = null;
      _loaded = false;
      _error = null;
      _showItems = false;
    });
    _syncControllersToFilters();
  }

  ArchiveFilters _sanitizeFilters(ArchiveFilters filters, ArchiveDocType type) {
    return filters.copyWith(
      warehouseId: type.hasWarehouse ? filters.warehouseId : null,
      accountId: type.hasAccount ? filters.accountId : null,
      accountType: type.hasAccount ? filters.accountType : '',
      treasuryId: type.hasTreasury ? filters.treasuryId : null,
      paymentMethod: type.hasPaymentMethod ? filters.paymentMethod : 'all',
      paymentStatus: type.hasPaymentStatus ? filters.paymentStatus : 'all',
      documentStatus: _documentStatusFor(type, filters.documentStatus),
      categoryId: type.hasItems ? filters.categoryId : null,
      itemName: type.hasItems ? filters.itemName : '',
      itemCode: type.hasItems ? filters.itemCode : '',
      barcode: type.hasItems ? filters.barcode : '',
      userId: null,
      salesRepId: null,
    );
  }

  static String _documentStatusFor(ArchiveDocType type, String value) {
    final allowed = type.isQuotation
        ? const {'all', 'open', 'converted'}
        : type.isStockDocument
        ? const {'all', 'applied', 'draft'}
        : const {'all'};
    return allowed.contains(value) ? value : 'all';
  }

  ArchiveFilters _sanitizeAdvancedFilters(ArchiveFilters filters) {
    return filters.copyWith(
      exactNumber: '',
      minAmount: null,
      maxAmount: null,
      partyName: '',
      categoryId: null,
      itemName: '',
      itemCode: '',
      barcode: '',
      notes: '',
    );
  }

  void _setMode(ArchiveSearchMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      if (mode == ArchiveSearchMode.general) {
        _filters = _sanitizeAdvancedFilters(_filters);
      }
    });
    _syncControllersToFilters();
  }

  // ---------------------------------------------------------------------------
  // Search.
  // ---------------------------------------------------------------------------
  void _showDocumentResults() {
    setState(() => _showItems = false);
    _search();
  }

  void _showItemResults() {
    if (!_type.hasItems) {
      _toast('هذا النوع لا يحتوي سطور أصناف — استخدم عرض الفواتير.');
      return;
    }
    setState(() => _showItems = true);
    _search();
  }

  Future<void> _search({bool append = false}) async {
    if ((_loading && !append) || (_loadingMore && append)) return;
    final validation = _repo.validateFilters(_type, _filters);
    if (validation != null) {
      _toast(validation);
      return;
    }
    _focusPage();
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
        _loaded = true;
        _documents = const [];
        _items = const [];
        _selection.clear();
        _anchorKey = null;
        _totalCount = 0;
        _totals = const ArchiveTotals();
        _hasMore = false;
      }
    });
    try {
      if (_showItems) {
        final page = await _repo.searchItems(
          type: _type,
          filters: _filters,
          sort: _itemSort,
          limit: _pageSize,
          offset: append ? _items.length : 0,
        );
        if (!mounted) return;
        setState(() {
          _items = append ? [..._items, ...page.rows] : page.rows;
          _totalCount = page.totalCount;
          _totals = page.totals;
          _hasMore = page.hasMore;
          _loadingMore = false;
          _loading = false;
        });
      } else {
        final page = await _repo.searchDocuments(
          type: _type,
          filters: _filters,
          sort: _sort,
          limit: _pageSize,
          offset: append ? _documents.length : 0,
        );
        if (!mounted) return;
        setState(() {
          _documents = append ? [..._documents, ...page.rows] : page.rows;
          _totalCount = page.totalCount;
          _totals = page.totals;
          _hasMore = page.hasMore;
          _loadingMore = false;
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'تعذر تحميل البيانات: ${_errorText(error)}';
        if (!append) {
          _documents = const [];
          _items = const [];
          _hasMore = false;
        }
      });
    }
  }

  void _onScroll() {
    if (!_vScroll.hasClients || _loadingMore || !_hasMore) return;
    final position = _vScroll.position;
    if (position.pixels >= position.maxScrollExtent - 180) {
      _search(append: true);
    }
  }

  void _setDocSort(ArchiveSortField field) {
    setState(() {
      _sort = ArchiveSort(
        field: field,
        ascending: _sort.field == field ? !_sort.ascending : true,
      );
    });
    if (_loaded) _search();
  }

  void _setItemSort(ArchiveItemSortField field) {
    setState(() {
      _itemSort = ArchiveItemSort(
        field: field,
        ascending: _itemSort.field == field ? !_itemSort.ascending : true,
      );
    });
    if (_loaded) _search();
  }

  // ---------------------------------------------------------------------------
  // Selection.
  // ---------------------------------------------------------------------------
  String _docKey(ArchiveDocument document) => 'd:${document.id}';

  String _itemKey(ArchiveItem item, int index) => 'i:${item.documentId}:$index';

  List<String> get _visibleKeys => _showItems
      ? [
          for (var index = 0; index < _items.length; index++)
            _itemKey(_items[index], index),
        ]
      : [for (final document in _documents) _docKey(document)];

  void _selectRow(String key, {bool ctrl = false, bool shift = false}) {
    final keys = _visibleKeys;
    final index = keys.indexOf(key);
    if (index < 0) return;
    setState(() {
      if (shift && _anchorKey != null) {
        final anchor = keys.indexOf(_anchorKey!);
        if (anchor >= 0) {
          final start = math.min(anchor, index);
          final end = math.max(anchor, index);
          for (var i = start; i <= end; i++) {
            _selection.add(keys[i]);
          }
          return;
        }
      }
      if (ctrl) {
        if (!_selection.add(key)) _selection.remove(key);
        _anchorKey = key;
        return;
      }
      _selection
        ..clear()
        ..add(key);
      _anchorKey = key;
    });
  }

  int? _documentIdFromKey(String key) {
    if (key.startsWith('d:')) return int.tryParse(key.substring(2));
    final parts = key.split(':');
    return parts.length >= 3 ? int.tryParse(parts[1]) : null;
  }

  int? get _singleSelectedDocumentId {
    if (_selection.length != 1) return null;
    return _documentIdFromKey(_selection.first);
  }

  List<int> get _selectedDocumentIds {
    final ids = <int>{};
    for (final key in _selection) {
      final id = _documentIdFromKey(key);
      if (id != null) ids.add(id);
    }
    return ids.toList();
  }

  bool _isSelected(String key) => _selection.contains(key);

  // ---------------------------------------------------------------------------
  // Edit / delete.
  // ---------------------------------------------------------------------------
  void _openDocument(int documentId) {
    final route = _type.editRoute;
    if (route == null) {
      _toast('لا توجد شاشة تعديل لهذا النوع من المستندات.');
      return;
    }
    context.go('$route?edit=$documentId');
  }

  void _editSelected() {
    final id = _singleSelectedDocumentId;
    if (id == null) {
      _toast(
        _selection.isEmpty
            ? 'حدد مستنداً واحداً من الجدول ثم اضغط تعديل.'
            : 'اختر مستنداً واحداً فقط للتعديل.',
      );
      return;
    }
    _openDocument(id);
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedDocumentIds;
    if (ids.isEmpty) {
      _toast('حدد مستنداً واحداً على الأقل من الجدول ثم اضغط حذف.');
      return;
    }
    final label = ids.length == 1 ? _type.documentLabel : 'المستندات';
    final ok = await showShopConfirm(
      context,
      title: 'حذف $label',
      message: ids.length == 1
          ? 'سيتم حذف ${_type.documentLabel} رقم ${_rowNumberFor(ids.first)} '
                'نهائياً مع عكس أثره على المخزون والحسابات والخزينة.\n'
                'لا يمكن التراجع عن هذه العملية.'
          : 'سيتم حذف ${ids.length} مستنداً من نوع ${_type.label} نهائياً '
                'مع عكس أثرها على المخزون والحسابات والخزينة.\n'
                'لا يمكن التراجع عن هذه العملية.',
      confirmLabel: 'حذف نهائي',
    );
    _focusPage();
    if (!mounted || !ok) return;
    setState(() => _loading = true);
    var deleted = 0;
    final errors = <String>[];
    for (final id in ids) {
      try {
        await _repo.deleteDocument(_type, id);
        deleted++;
      } catch (error) {
        errors.add('مستند ${_rowNumberFor(id)}: ${_errorText(error)}');
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
    await _search();
    if (!mounted) return;
    if (errors.isEmpty) {
      _toast(
        deleted == 1
            ? 'تم حذف ${_type.documentLabel} وإرجاع الحركات المرتبطة به.'
            : 'تم حذف $deleted مستندات وإرجاع حركاتها المرتبطة.',
      );
    } else {
      _toast(
        'تم حذف $deleted مستنداً. تعذر حذف ${errors.length}: '
        '${errors.first}',
      );
    }
  }

  String _rowNumberFor(int documentId) {
    for (final document in _documents) {
      if (document.id == documentId) return document.number;
    }
    return '#$documentId';
  }

  // ---------------------------------------------------------------------------
  // Printing / sharing.
  // ---------------------------------------------------------------------------
  Future<_ArchivePrintData> _collectReportData() async {
    if (_showItems) {
      final all = <ArchiveItem>[];
      var offset = 0;
      var totals = const ArchiveTotals();
      while (true) {
        final page = await _repo.searchItems(
          type: _type,
          filters: _filters,
          sort: _itemSort,
          limit: 500,
          offset: offset,
        );
        all.addAll(page.rows);
        totals = page.totals;
        if (!page.hasMore || page.rows.isEmpty) break;
        offset += page.rows.length;
      }
      final columns = _itemColumnsFor(_type);
      return _ArchivePrintData(
        headers: [for (final column in columns) _headerText(column.label)],
        rows: [
          for (final item in all)
            [for (final column in columns) column.itemValue?.call(item) ?? ''],
        ],
        subtitle: _reportSubtitle(totals),
        count: all.length,
      );
    }
    final all = <ArchiveDocument>[];
    var offset = 0;
    var totals = const ArchiveTotals();
    while (true) {
      final page = await _repo.searchDocuments(
        type: _type,
        filters: _filters,
        sort: _sort,
        limit: 500,
        offset: offset,
      );
      all.addAll(page.rows);
      totals = page.totals;
      if (!page.hasMore || page.rows.isEmpty) break;
      offset += page.rows.length;
    }
    final columns = _documentColumnsFor(_type);
    return _ArchivePrintData(
      headers: [for (final column in columns) _headerText(column.label)],
      rows: [
        for (final document in all)
          [for (final column in columns) column.docValue?.call(document) ?? ''],
      ],
      subtitle: _reportSubtitle(totals),
      count: all.length,
    );
  }

  String _reportSubtitle(ArchiveTotals totals) {
    final parts = <String>['النوع: ${_type.label}'];
    if (_filters.fromDate != null || _filters.toDate != null) {
      parts.add(
        'من: ${_filters.fromDate == null ? 'البداية' : _fmtFilterDate(_filters.fromDate)}'
        ' ${_fmtFilterTime(_filters.fromTime)}',
      );
      parts.add(
        'إلى: ${_filters.toDate == null ? 'النهاية' : _fmtFilterDate(_filters.toDate)}'
        ' ${_fmtFilterTime(_filters.toTime)}',
      );
    }
    if (_filters.invoiceNumber.trim().isNotEmpty) {
      parts.add('الرقم: ${_filters.invoiceNumber.trim()}');
    }
    if (_filters.accountId != null) {
      parts.add('الحساب: ${_optionName(_accounts, _filters.accountId)}');
    }
    if (_filters.warehouseId != null) {
      parts.add('المخزن: ${_optionName(_warehouses, _filters.warehouseId)}');
    }
    if (_filters.paymentMethod != 'all') {
      parts.add('السداد: ${_filters.paymentMethod == 'cash' ? 'نقدي' : 'آجل'}');
    }
    if (_filters.paymentStatus != 'all') {
      parts.add('الحالة: ${_paymentStatusLabel(_filters.paymentStatus)}');
    }
    parts.add('العدد: ${totals.count}');
    parts.add('الإجمالي: ${_money(totals.total)}');
    if (totals.paid != 0 || totals.remaining != 0) {
      parts.add('المدفوع: ${_money(totals.paid)}');
      parts.add('المتبقي: ${_money(totals.remaining)}');
    }
    if (totals.quantity != 0) {
      parts.add('الكمية: ${_money(totals.quantity)}');
    }
    return parts.join('  |  ');
  }

  static String _headerText(String label) => label.replaceAll('\n', ' ');

  String _paymentStatusLabel(String value) => switch (value) {
    'paid' => 'مدفوع',
    'partial' => 'مدفوع جزئياً',
    'unpaid' => 'غير مدفوع',
    _ => value,
  };

  Future<void> _printReport() async {
    if (!_loaded) {
      _toast('اعرض البيانات أولاً ثم أعد المحاولة.');
      return;
    }
    try {
      final data = await _collectReportData();
      if (!mounted) return;
      if (data.rows.isEmpty) {
        _toast('لا توجد بيانات مطابقة لطباعتها.');
        return;
      }
      final title = 'تقرير ${_type.label}';
      await showDialog<void>(
        context: context,
        builder: (_) => PrintPreviewDialog(
          title: 'طباعة التقرير',
          subtitle: data.subtitle,
          columns: data.headers,
          rows: data.rows,
          onPrint: () => _printPdf(
            title: title,
            subtitle: data.subtitle,
            headers: data.headers,
            rows: data.rows,
          ),
        ),
      );
    } catch (error) {
      if (mounted) _toast('تعذر تجهيز التقرير: ${_errorText(error)}');
    }
  }

  Future<void> _printDocument() async {
    final id = _singleSelectedDocumentId;
    if (id == null) {
      _toast('حدد مستنداً واحداً من الجدول لطباعته.');
      return;
    }
    try {
      final detail = await _repo.loadDocument(_type, id);
      if (!mounted) return;
      if (detail == null) {
        _toast('المستند المطلوب غير موجود.');
        return;
      }
      final data = _documentPrintData(detail);
      final title = '${_type.documentLabel} ${data.number}';
      await showDialog<void>(
        context: context,
        builder: (_) => PrintPreviewDialog(
          title: 'طباعة المستند',
          subtitle: data.subtitle,
          columns: data.headers,
          rows: data.rows,
          onPrint: () => _printPdf(
            title: title,
            subtitle: data.subtitle,
            headers: data.headers,
            rows: data.rows,
          ),
        ),
      );
    } catch (error) {
      if (mounted) _toast('تعذر تجهيز المستند: ${_errorText(error)}');
    }
  }

  Future<void> _printPdf({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    try {
      final document = await buildTablePdfDocument(
        title: title,
        subtitle: subtitle,
        headers: headers,
        rows: rows,
      );
      if (!mounted) return;
      if (document == null) {
        _toast('تعذر تجهيز ملف الطباعة (خط عربي غير متوفر).');
        return;
      }
      final printed = await Printing.layoutPdf(
        onLayout: (format) => document.save(),
        name: title,
        windowsModernDialog: true,
      );
      if (!mounted) return;
      if (printed) _toast('تم إرسال $title إلى الطباعة.');
    } catch (_) {
      if (mounted) _toast('تعذر بدء الطباعة.');
    }
  }

  Future<void> _shareReport() async {
    if (!_loaded) {
      _toast('اعرض البيانات أولاً ثم أعد المحاولة.');
      return;
    }
    try {
      final data = await _collectReportData();
      if (!mounted) return;
      if (data.rows.isEmpty) {
        _toast('لا توجد بيانات مطابقة لمشاركتها.');
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await showTableExportDialog(
        context,
        table: ExportTable(
          headers: data.headers,
          rows: data.rows,
          filePrefix: 'archive_${_type.name}',
          printName: 'تقرير ${_type.label}',
          printSentLabel: 'التقرير',
          emptyMessage: 'لا توجد بيانات لتصديرها.',
          whatsAppIntro: 'تقرير ${_type.label}\n${data.subtitle}',
          whatsAppLine: (row) => row.take(4).join(' | '),
          pdfTitle: 'تقرير ${_type.label}',
          pdfSubtitle: data.subtitle,
        ),
        tableBoundaryKey: _tableKey,
      );
    } catch (error) {
      if (mounted) _toast('تعذر تجهيز المشاركة: ${_errorText(error)}');
    }
  }

  Future<void> _shareDocument() async {
    final id = _singleSelectedDocumentId;
    if (id == null) {
      _toast('حدد مستنداً واحداً من الجدول لمشاركته.');
      return;
    }
    try {
      final detail = await _repo.loadDocument(_type, id);
      if (!mounted) return;
      if (detail == null) {
        _toast('المستند المطلوب غير موجود.');
        return;
      }
      final data = _documentPrintData(detail);
      await showTableExportDialog(
        context,
        table: ExportTable(
          headers: data.headers,
          rows: data.rows,
          filePrefix: 'document_${_type.name}_${data.number}',
          printName: '${_type.documentLabel} ${data.number}',
          printSentLabel: 'المستند',
          emptyMessage: 'لا توجد سطور لتصديرها.',
          whatsAppIntro:
              '${_type.documentLabel} ${data.number}\n${data.subtitle}',
          whatsAppLine: (row) => row.join(' | '),
          pdfTitle: '${_type.documentLabel} ${data.number}',
          pdfSubtitle: data.subtitle,
        ),
      );
    } catch (error) {
      if (mounted) _toast('تعذر تجهيز المستند: ${_errorText(error)}');
    }
  }

  // ---------------------------------------------------------------------------
  // Keyboard.
  // ---------------------------------------------------------------------------
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f2) {
      _editSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete) {
      _deleteSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f5) {
      if (_loaded) _search();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f12) {
      _printReport();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f11) {
      _shareReport();
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
        child: AppShell(
          activeTab: AppTab.home,
          homeTabActive: false,
          extraTabLabel: 'الفواتير',
          extraTabColor: Colors.white,
          extraTabTextColor: _kInk,
          onExtraTabClose: _close,
          hideActiveTab: true,
          extraTabWidth: 210,
          child: Container(
            color: Colors.white,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 1018,
                    height: 618,
                    child: Column(
                      children: [
                        _buildToolbar(),
                        _buildDocTabs(),
                        _buildModeTabs(),
                        _buildFilters(),
                        _buildActions(),
                        Expanded(child: _buildResults()),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The rows and headers used by the print/export dialogs.
class _ArchivePrintData {
  const _ArchivePrintData({
    required this.headers,
    required this.rows,
    required this.subtitle,
    required this.count,
    this.number = '',
  });

  final List<String> headers;
  final List<List<String>> rows;
  final String subtitle;
  final int count;
  final String number;
}
