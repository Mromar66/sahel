import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:safwa/app/shell/app_top_bar.dart';
import 'package:safwa/app/theme/shop_colors.dart';
import 'package:safwa/app/widgets/hover_widgets.dart';
import 'package:safwa/app/widgets/document_custom_fields.dart';
import 'package:safwa/app/widgets/product_search_field.dart';
import 'package:safwa/app/widgets/shared_data_grid.dart';
import 'package:safwa/app/widgets/shop_command_rail.dart';
import 'package:safwa/app/widgets/shop_dialog_kit.dart';
import 'package:safwa/app/widgets/shop_dialogs.dart';
import 'package:safwa/app/widgets/shop_footer_bar.dart';
import 'package:safwa/core/services/database_service.dart';
import 'package:safwa/core/services/shop_preferences.dart';
import 'package:safwa/core/security/guarded_actions.dart';
import 'package:safwa/core/utils/constants.dart';
import 'package:safwa/features/accounts/presentation/print_preview_dialog.dart';
import 'package:safwa/features/invoice_ops/data/invoice_op_repository.dart';
import 'package:safwa/features/invoice_ops/data/purchase_return_repository.dart';
import 'package:safwa/features/invoice_ops/data/quotation_repository.dart';
import 'package:safwa/features/invoice_ops/data/sales_repository.dart';
import 'package:safwa/features/invoice_ops/data/sales_return_repository.dart';
import 'package:safwa/features/invoice_ops/domain/invoice_op_models.dart';

part 'invoice_op_layout.dart';
part 'invoice_op_table.dart';
part 'invoice_op_dialogs.dart';

/// The shared invoice screen used by بيع جديد, مرتجع بيع, مرتجع شراء and
/// عرض أسعار. The layout is the existing شراء screen; only the operation
/// selected through [kind] changes the business rules and labels.
class InvoiceOpPage extends StatefulWidget {
  const InvoiceOpPage({
    super.key,
    required this.kind,
    this.quotationId,
    this.editId,
  });

  final InvoiceOpKind kind;

  /// When a quotation is converted to a sale, the sale page opens with this id
  /// and loads the saved quotation lines.
  final int? quotationId;

  /// Opens the screen in edit mode for an existing document. Saving updates
  /// this exact id instead of creating a new document.
  final int? editId;

  @override
  State<InvoiceOpPage> createState() => _InvoiceOpPageState();
}

extension _InvoiceKindUi on InvoiceOpKind {
  String get tabLabel => switch (this) {
    InvoiceOpKind.sale => 'بيع | جديد',
    InvoiceOpKind.salesReturn => 'مرتجع بيع | جديد',
    InvoiceOpKind.purchaseReturn => 'مرتجع شراء | جديد',
    InvoiceOpKind.quotation => 'عرض أسعار | جديد',
  };

  String get brandLabel => switch (this) {
    InvoiceOpKind.sale => 'بيع',
    InvoiceOpKind.salesReturn => 'مرتجع',
    InvoiceOpKind.purchaseReturn => 'مرتجع',
    InvoiceOpKind.quotation => 'عرض',
  };

  String get screenName => switch (this) {
    InvoiceOpKind.sale => 'البيع',
    InvoiceOpKind.salesReturn => 'مرتجع البيع',
    InvoiceOpKind.purchaseReturn => 'مرتجع الشراء',
    InvoiceOpKind.quotation => 'عرض الأسعار',
  };

  String get partyWord => isPurchaseReturn ? 'المورد' : 'العميل';

  String get accountPickerTitle => 'اختيار حساب $partyWord';

  String get priceLabel => isPurchaseReturn ? 'سعر الشراء' : 'سعر البيع';

  String get paymentTileLabel => switch (this) {
    InvoiceOpKind.sale => 'سداد F11',
    InvoiceOpKind.salesReturn => 'استرداد F11',
    InvoiceOpKind.purchaseReturn => 'تحصيل F11',
    InvoiceOpKind.quotation => 'تحويل لبيع',
  };

  String get paymentDialogTitle => switch (this) {
    InvoiceOpKind.sale => 'سداد فاتورة البيع',
    InvoiceOpKind.salesReturn => 'استرداد مرتجع البيع',
    InvoiceOpKind.purchaseReturn => 'تحصيل مرتجع الشراء',
    InvoiceOpKind.quotation => 'تحويل عرض السعر',
  };

  String get paymentConfirmLabel => switch (this) {
    InvoiceOpKind.sale => 'تأكيد السداد',
    InvoiceOpKind.salesReturn => 'تأكيد الاسترداد',
    InvoiceOpKind.purchaseReturn => 'تأكيد التحصيل',
    InvoiceOpKind.quotation => 'تحويل',
  };

  String get paymentAmountLabel => switch (this) {
    InvoiceOpKind.sale => 'قيمة السداد',
    InvoiceOpKind.salesReturn => 'قيمة الاسترداد',
    InvoiceOpKind.purchaseReturn => 'قيمة التحصيل',
    InvoiceOpKind.quotation => 'المبلغ',
  };

  String get settingsTitle => 'إعدادات شاشة $screenName';

  String get shortcutsTitle => 'اختصارات شاشة $screenName';

  String get printTitle => switch (this) {
    InvoiceOpKind.sale => 'فاتورة بيع',
    InvoiceOpKind.salesReturn => 'مرتجع بيع',
    InvoiceOpKind.purchaseReturn => 'مرتجع شراء',
    InvoiceOpKind.quotation => 'عرض سعر',
  };

  String get filePrefix => switch (this) {
    InvoiceOpKind.sale => 'sale',
    InvoiceOpKind.salesReturn => 'sales_return',
    InvoiceOpKind.purchaseReturn => 'purchase_return',
    InvoiceOpKind.quotation => 'quotation',
  };

  String get saveMessage => switch (this) {
    InvoiceOpKind.sale => 'تم حفظ فاتورة البيع رقم',
    InvoiceOpKind.salesReturn => 'تم حفظ مرتجع البيع رقم',
    InvoiceOpKind.purchaseReturn => 'تم حفظ مرتجع الشراء رقم',
    InvoiceOpKind.quotation => 'تم حفظ عرض السعر رقم',
  };
}

const Color _kYellow = ShopColors.yellow;
const Color _kGreen = ShopColors.green;
const Color _kPanelGreen = ShopColors.panelGreen;
const Color _kRed = ShopColors.red;
const Color _kBlue = ShopColors.blue;
const Color _kSoft = ShopColors.soft;
const Color _kField = ShopColors.field;
const Color _kInk = ShopColors.ink;
const Color _kLine = ShopColors.line;
const Color _kFocusBlue = ShopColors.focusBlue;
const Color _kRowSelected = ShopColors.rowSelected;

const List<String> _kPayTabs = [
  'درج النقدية',
  'بطاقة إئتمان',
  'الخزينة',
  'آجل',
];
const List<String> _kPayMethods = ['cash', 'card', 'bank', 'credit'];

const List<LineOption> _kInvoiceLineOptions = [
  LineOption(key: 'duplicate', label: 'تكرار السطر'),
  LineOption(key: 'up', label: 'تحريك السطر لأعلى'),
  LineOption(key: 'down', label: 'تحريك السطر لأسفل'),
  LineOption(key: 'custom-fields', label: 'الحقول الإضافية للصنف'),
  LineOption(key: 'clear-discount', label: 'إلغاء خصم السطر'),
  LineOption(key: 'delete', label: 'حذف السطر', danger: true),
];

const List<(String, String)> _kInvoiceShortcuts = [
  ('F4', 'طباعة الفاتورة'),
  ('F5', 'تعديل كمية السطر'),
  ('F6', 'تعديل سعر السطر'),
  ('F7', 'خيارات السطر'),
  ('F8', 'حذف السطر'),
  ('F9', 'حفظ الفاتورة'),
  ('F10', 'فاتورة جديدة'),
  ('F11', 'سداد الفاتورة'),
  ('F12', 'حفظ وفتح فاتورة جديدة'),
  ('Enter', 'الانتقال للسطر التالي'),
  ('Tab', 'الانتقال للخلية التالية'),
  ('Esc', 'إلغاء تعديل الخلية'),
];

class _InvoiceOpPageState extends State<InvoiceOpPage> {
  late final InvoiceOpRepository _repo;
  late final _tbl = _InvoiceTableController(salesStyle: _kind.isSale);
  final _tableKey = GlobalKey<SharedDataGridState<InvoiceLine>>();
  final _searchKey = GlobalKey<ProductSearchFieldState<InvoiceProduct>>();
  final _searchFocus = FocusNode();
  final _pageFocus = FocusScopeNode(debugLabel: 'invoice-op-page');
  final _invoiceImportPath = TextEditingController();

  InvoiceOpKind get _kind => widget.kind;

  final _invoiceNo = TextEditingController();
  final _date = TextEditingController();
  final _time = TextEditingController();
  final _search = TextEditingController();
  final _account = TextEditingController();
  final _notes = TextEditingController();
  final _addQty = TextEditingController(text: '1');
  final _addVal = TextEditingController();
  final _addPct = TextEditingController();
  final _discVal = TextEditingController();
  final _discPct = TextEditingController();

  final _grandTotal = ValueNotifier<int>(0);
  final _paidNotifier = ValueNotifier<int>(0);

  List<InvoiceAccount> _accounts = const [];
  List<InvoiceAccount> _salesRepresentatives = const [];
  List<InvoiceWarehouse> _warehouses = const [];
  List<InvoiceTreasury> _treasuries = const [];
  int? _selectedWarehouseId;
  int? _selectedTreasuryId;
  List<String> _priceListNames = const [
    'سعر البيع',
    'سعر البيع الثاني',
    'سعر البيع الثالث',
    'سعر البيع الرابع',
  ];
  int _selectedPriceLevel = 0;
  Map<int, String> _customFieldValues = {};
  InvoiceAccount? _selectedAccount;
  InvoiceAccount? _selectedSalesRepresentative;
  String _treasury = 'درج النقدية';
  int _payTab = 0;
  int _salesTab = 0;
  bool? _salesSidebarCollapsed;
  String _addKind = 'نسبة';
  bool _saving = false;
  bool _pinPayment = false;
  bool _confirmDelete = true;
  int _roundStep = 5;
  bool _syncing = false;

  /// True while a saved document is open through [InvoiceOpPage.editId].
  bool _editing = false;

  int? _savedInvoiceId;
  String _savedNumber = '';
  int _paid = 0;
  InvoicePaymentInput? _pendingPayment;

  /// Original invoice loaded on a return screen.
  int? _originalInvoiceId;

  /// Quotation currently being converted into a sale.
  int? _sourceQuoteId;

  @override
  void initState() {
    super.initState();
    _confirmDelete = ShopPreferences.confirmDelete;
    _roundStep = ShopPreferences.roundStep;
    _repo = switch (widget.kind) {
      InvoiceOpKind.sale => SalesRepository(),
      InvoiceOpKind.salesReturn => SalesReturnRepository(),
      InvoiceOpKind.purchaseReturn => PurchaseReturnRepository(),
      InvoiceOpKind.quotation => QuotationRepository(),
    };
    _sourceQuoteId = widget.quotationId;
    _editing = widget.editId != null;
    final now = DateTime.now();
    _date.text = _fmtDate(now);
    _time.text = _fmtTime(now);
    _tbl.addListener(_recompute);
    _discPct.addListener(_onDiscPctChanged);
    _discVal.addListener(_onDiscValChanged);
    _addPct.addListener(_onAddPctChanged);
    _addVal.addListener(_onAddValChanged);
    _loadPriceListNames();
    _loadLookups();
    _focusProductSearch();
  }

  void _focusProductSearch() {
    if (!_kind.isSale) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocus.requestFocus();
      _search.selection = TextSelection.collapsed(offset: _search.text.length);
    });
  }

  void _loadPriceListNames() {
    final db = DatabaseService().database.db;
    _priceListNames = List.generate(4, (index) {
      final rows = db.select('SELECT value FROM settings WHERE key=?', [
        'settings.price_${index + 1}',
      ]);
      final value = rows.isEmpty ? '' : (rows.first['value'] as String).trim();
      return value.isEmpty
          ? const [
              'سعر البيع',
              'سعر البيع الثاني',
              'سعر البيع الثالث',
              'سعر البيع الرابع',
            ][index]
          : value;
    });
  }

  Future<void> _editCustomFields() async {
    final values = await showDocumentCustomFieldsDialog(
      context,
      initialValues: _customFieldValues,
    );
    if (values == null || !mounted) return;
    setState(() => _customFieldValues = values);
  }

  @override
  void dispose() {
    _tbl.removeListener(_recompute);
    _tbl.dispose();
    _grandTotal.dispose();
    _paidNotifier.dispose();
    _searchFocus.dispose();
    _pageFocus.dispose();
    for (final c in [
      _invoiceNo,
      _date,
      _time,
      _search,
      _account,
      _notes,
      _addQty,
      _addVal,
      _addPct,
      _discVal,
      _discPct,
      _invoiceImportPath,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final accounts = await _repo.getAccounts();
      final salesRepresentatives = await _repo.getSalesRepresentatives();
      final warehouses = await _repo.getWarehouses();
      final treasuries = await _repo.getTreasuries();
      final invoice = _repo.nextInvoiceNumber();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _salesRepresentatives = salesRepresentatives;
        _warehouses = warehouses;
        _treasuries = treasuries;
        _selectedWarehouseId ??= warehouses.firstOrNull?.id;
        _selectedTreasuryId ??= treasuries.firstOrNull?.id;
        if (_treasury == 'درج النقدية' && treasuries.isNotEmpty) {
          final selected = treasuries.firstWhere(
            (row) => row.id == _selectedTreasuryId,
            orElse: () => treasuries.first,
          );
          _treasury = selected.name;
        }
        _invoiceNo.text = invoice;
      });
      if (_sourceQuoteId != null) {
        final quote = await _repo.loadQuotation(_sourceQuoteId!);
        if (!mounted || quote == null) return;
        _applyLoadedDocument(quote, isQuotation: true);
      }
      if (widget.editId != null) {
        await _loadForEdit(widget.editId!);
      }
    } catch (_) {
      // The screen still opens; the search box reports the DB error on use.
    }
  }

  Future<void> _loadForEdit(int id) async {
    try {
      final data = await _repo.loadInvoiceForEdit(id);
      if (!mounted) return;
      if (data == null) {
        _editing = false;
        _toast('المستند المطلوب غير موجود.');
        return;
      }
      final account = data.accountId == null
          ? null
          : _accounts.where((a) => a.id == data.accountId).firstOrNull;
      setState(() {
        _tbl.clear();
        _tbl.locked = false;
        _editing = true;
        _pendingPayment = null;
        for (final line in data.lines) {
          _tbl.add(
            InvoiceLine(
              productId: line.productId,
              code: line.code,
              name: line.name,
              unit: line.unit,
              available: line.available,
              qty: line.qty,
              price: line.price,
              discount: line.discount,
              customFields: Map<int, String>.from(line.customFields),
            ),
          );
        }
        _selectedAccount = account;
        _selectedSalesRepresentative = _salesRepresentatives
            .where(
              (representative) =>
                  representative.id == data.salesRepresentativeId,
            )
            .firstOrNull;
        if (data.warehouseId != null &&
            _warehouses.any((warehouse) => warehouse.id == data.warehouseId)) {
          _selectedWarehouseId = data.warehouseId;
        }
        _account.text = account?.name ?? (data.accountName ?? '');
        _invoiceNo.text = data.number;
        _notes.text = data.notes;
        if (data.date != null) {
          _date.text = _fmtDate(data.date!);
          _time.text = _fmtTime(data.date!);
        }
        _discVal.text = data.discount > 0 ? '${data.discount}' : '';
        _discPct.clear();
        _addVal.text = data.tax > 0 ? '${data.tax}' : '';
        _addPct.clear();
        _savedInvoiceId = data.id;
        _savedNumber = data.number;
        _paid = data.paid;
        _paidNotifier.value = data.paid;
        _originalInvoiceId = data.originalInvoiceId;
        _customFieldValues = Map<int, String>.from(data.customFields);
      });
      _recompute();
      _toast('تم تحميل ${_kind.printTitle} رقم ${data.number} للتعديل.');
    } catch (e) {
      if (!mounted) return;
      _editing = false;
      _toast(
        e is InvoiceValidationException ? e.message : 'تعذر تحميل المستند: $e',
      );
    }
  }

  void _applyLoadedDocument(
    OriginalInvoiceData data, {
    bool isQuotation = false,
  }) {
    final account = data.accountId == null
        ? null
        : _accounts.where((a) => a.id == data.accountId).firstOrNull;
    setState(() {
      _tbl.clear();
      _tbl.locked = false;
      _pendingPayment = null;
      _paid = 0;
      _paidNotifier.value = 0;
      for (final item in data.lines) {
        final qty = isQuotation
            ? item.quantity
            : (item.available < item.returnable
                  ? item.available
                  : item.returnable);
        if (qty <= 0) continue;
        final lineDiscount = isQuotation
            ? item.discount
            : (item.quantity <= 0 ? 0 : item.discount * qty ~/ item.quantity);
        _tbl.add(
          InvoiceLine(
            productId: item.productId,
            code: item.code,
            name: item.name,
            unit: item.unit.trim().isEmpty ? 'حبة' : item.unit,
            available: isQuotation ? item.available : item.available,
            qty: qty,
            price: item.unitPrice,
            discount: lineDiscount,
          ),
        );
      }
      _selectedAccount = account;
      _account.text = account?.name ?? data.accountName;
      _notes.text = isQuotation
          ? 'تحويل من عرض سعر رقم ${data.number}'
          : 'مرتجع عن فاتورة رقم ${data.number}';
      _originalInvoiceId = isQuotation ? null : data.id;
    });
    _recompute();
    _toast(
      isQuotation
          ? 'تم تحميل عرض السعر رقم ${data.number}.'
          : 'تم تحميل الفاتورة رقم ${data.number}.',
    );
  }

  Future<void> _loadOriginalInvoice() async {
    if (!_kind.needsOriginalInvoice) return;
    if (_tbl.lines.isNotEmpty) {
      final ok = await _confirm(
        'تحميل فاتورة',
        'سيتم استبدال السطور الحالية بسطور الفاتورة المختارة. هل تريد المتابعة؟',
      );
      if (!mounted || !ok) return;
    }
    final picked = await showDialog<OriginalInvoiceSummary>(
      context: context,
      builder: (_) => _InvoicePickerDialog(
        title: _kind.isSalesReturn ? 'اختيار فاتورة بيع' : 'اختيار فاتورة شراء',
        loader: _repo.searchOriginalInvoices,
      ),
    );
    if (!mounted || picked == null) return;
    try {
      final data = await _repo.loadOriginalInvoice(picked.id);
      if (!mounted || data == null) return;
      _applyLoadedDocument(data);
    } catch (e) {
      _toast(e is InvoiceValidationException ? e.message : '$e');
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  DateTime? _parseInvoiceTimestamp() {
    final dateText = _date.text.trim();
    final dateParts = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$')
        .firstMatch(dateText);
    int year;
    int month;
    int day;
    if (dateParts != null) {
      day = int.parse(dateParts.group(1)!);
      month = int.parse(dateParts.group(2)!);
      year = int.parse(dateParts.group(3)!);
    } else {
      final parsed = DateTime.tryParse(dateText);
      if (parsed == null) return null;
      year = parsed.year;
      month = parsed.month;
      day = parsed.day;
    }
    var hour = 0;
    var minute = 0;
    final timeText = _time.text.trim();
    final timeParts = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$',
      caseSensitive: false,
    ).firstMatch(timeText);
    if (timeText.isNotEmpty && timeParts == null) return null;
    if (timeParts != null) {
      hour = int.parse(timeParts.group(1)!);
      minute = int.parse(timeParts.group(2)!);
      final period = timeParts.group(3)?.toUpperCase();
      if (period != null) {
        if (hour < 1 || hour > 12) return null;
        if (period == 'AM' && hour == 12) hour = 0;
        if (period == 'PM' && hour != 12) hour += 12;
      }
    }
    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31 ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    final value = DateTime(year, month, day, hour, minute);
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }
    return value;
  }

  static String _fmtTime(DateTime d) {
    final h = (d.hour % 12 == 0 ? 12 : d.hour % 12).toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  /// Runs [fn] through setState from the shared layout extension parts.
  void _rebuild(VoidCallback fn) => setState(fn);

  Future<void> _selectSalesWarehouse(int warehouseId) async {
    setState(() => _selectedWarehouseId = warehouseId);
    for (var i = 0; i < _tbl.lines.length; i++) {
      final line = _tbl.lines[i];
      final product = await _repo.findByBarcode(
        line.code,
        warehouseId: warehouseId,
      );
      if (product != null && product.id == line.productId) {
        _tbl.update(i, available: product.available);
      }
    }
  }

  void _selectSalesTreasury(String name) {
    final treasury = _treasuries.where((item) => item.name == name).firstOrNull;
    setState(() {
      _treasury = name;
      _selectedTreasuryId = treasury?.id;
    });
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

  Future<void> _browseSalesInvoices() async {
    if (!_kind.isSale) return;
    final query = TextEditingController();
    final rows = _repo.db
        .query('''
      SELECT si.id, si.invoice_number, si.invoice_date, si.total,
             si.payment_status, COALESCE(a.name, '') AS account_name
      FROM sales_invoices si
      LEFT JOIN accounts a ON a.id = si.account_id
      WHERE si.is_return = 0
      ORDER BY si.id DESC
      LIMIT 150
      ''')
        .map((row) => Map<String, Object?>.from(row))
        .toList();
    final picked = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          final key = query.text.trim().toLowerCase();
          final visible = rows.where((row) {
            final searchable = [
              row['invoice_number'],
              row['account_name'],
              row['invoice_date'],
            ].join(' ').toLowerCase();
            return key.isEmpty || searchable.contains(key);
          }).toList();
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('تحميل فاتورة مبيعات'),
              content: SizedBox(
                width: 620,
                height: 430,
                child: Column(
                  children: [
                    TextField(
                      controller: query,
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'ابحث برقم الفاتورة أو اسم العميل',
                      ),
                      onChanged: (_) => dialogSetState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(child: Text('مفيش فواتير مطابقة.'))
                          : ListView.separated(
                              itemCount: visible.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final row = visible[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    'فاتورة ${row['invoice_number']} · ${row['account_name']}',
                                  ),
                                  subtitle: Text('${row['invoice_date']}'),
                                  trailing: Text('${row['total']}'),
                                  onTap: () =>
                                      Navigator.of(dialogContext).pop(row),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
              ],
            ),
          );
        },
      ),
    );
    query.dispose();
    if (!mounted || picked == null) return;
    if (_tbl.lines.isNotEmpty && (_savedInvoiceId == null || _editing)) {
      final replace = await _confirm(
        'تحميل فاتورة',
        'هيتم استبدال الفاتورة الحالية. تحب تكمل؟',
      );
      if (!mounted || !replace) return;
    }
    await _loadForEdit((picked['id'] as num).toInt());
  }

  Future<void> _navigateSalesInvoice(int direction) async {
    final rows = _repo.db.query(
      'SELECT id FROM sales_invoices WHERE is_return=0 ORDER BY id',
    );
    if (rows.isEmpty) {
      _toast('لسه مفيش فواتير محفوظة.');
      return;
    }
    final ids = rows.map((row) => (row['id'] as num).toInt()).toList();
    final current = _savedInvoiceId == null
        ? -1
        : ids.indexOf(_savedInvoiceId!);
    final target = current < 0
        ? (direction > 0 ? ids.length - 1 : 0)
        : current + direction;
    if (target < 0 || target >= ids.length) {
      _toast('مفيش فاتورة في الاتجاه ده.');
      return;
    }
    if (_tbl.lines.isNotEmpty && (_savedInvoiceId == null || _editing)) {
      final replace = await _confirm(
        'التنقل بين الفواتير',
        'هيتم استبدال الفاتورة الحالية. تحب تكمل؟',
      );
      if (!mounted || !replace) return;
    }
    await _loadForEdit(ids[target]);
  }

  void _copyCurrentSalesInvoice() {
    if (!_kind.isSale) return;
    if (_tbl.lines.isEmpty) {
      _toast('أضف أصناف قبل ما تنسخ الفاتورة.');
      return;
    }
    final lines = _tbl.lines.map((line) => line.clone()).toList();
    final account = _selectedAccount;
    final notes = _notes.text;
    final discount = _discVal.text;
    final discountPercent = _discPct.text;
    final addition = _addVal.text;
    final additionPercent = _addPct.text;
    final priceLevel = _selectedPriceLevel;
    final salesRepresentative = _selectedSalesRepresentative;
    _newInvoice();
    setState(() {
      _selectedAccount = account;
      _selectedSalesRepresentative = salesRepresentative;
      _account.text = account?.name ?? '';
      _notes.text = notes;
      _discVal.text = discount;
      _discPct.text = discountPercent;
      _addVal.text = addition;
      _addPct.text = additionPercent;
      _selectedPriceLevel = priceLevel;
      for (final line in lines) {
        _tbl.add(line);
      }
    });
    _recompute();
    _toast('اتنسخت بيانات الفاتورة في فاتورة جديدة من غير المدفوعات.');
  }

  Future<void> _importSalesCsv() async {
    if (!_kind.isSale) return;
    _invoiceImportPath.clear();
    final path = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('استيراد أصناف من ملف Excel'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'اختار ملف CSV محفوظ من Excel، وبعدها الصق مساره هنا.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _invoiceImportPath,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: r'C:\المسار\ملف.csv',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext)
                      .pop(_invoiceImportPath.text.trim()),
              child: const Text('استيراد'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || path == null || path.isEmpty) return;
    try {
      final source = await File(path).readAsString();
      final rows = _parseCsv(source.replaceFirst('\uFEFF', ''));
      if (rows.isEmpty) {
        _toast('الملف فاضي أو تنسيقه مش مفهوم.');
        return;
      }
      final header = rows.first
          .map((cell) => cell.trim().toLowerCase())
          .toList();
      int column(Iterable<String> keys, int fallback) {
        final index = header.indexWhere((cell) => keys.any(cell.contains));
        return index < 0 ? fallback : index;
      }

      final hasHeader = header.any(
        (cell) =>
            cell.contains('الصنف') ||
            cell.contains('code') ||
            cell.contains('quantity'),
      );
      final codeColumn = hasHeader
          ? column(['رقم الصنف', 'كود', 'code', 'barcode'], 0)
          : 0;
      final nameColumn = hasHeader
          ? column(['اسم الصنف', 'الاسم', 'name'], 1)
          : 1;
      final qtyColumn = hasHeader
          ? column(['الكمية', 'qty', 'quantity'], 4)
          : 4;
      final priceColumn = hasHeader ? column(['السعر', 'price'], 5) : 5;
      final added = <InvoiceLine>[];
      var skipped = 0;
      for (final row in rows.skip(hasHeader ? 1 : 0)) {
        String valueAt(int index) =>
            index < row.length ? row[index].trim() : '';
        final code = valueAt(codeColumn);
        final name = valueAt(nameColumn);
        if (code.isEmpty && name.isEmpty) continue;
        final qty = int.tryParse(valueAt(qtyColumn)) ?? 1;
        if (qty <= 0) {
          skipped++;
          continue;
        }
        final product = code.isNotEmpty
            ? await _repo.findByBarcode(code, warehouseId: _selectedWarehouseId)
            : null;
        final matches = product == null && name.isNotEmpty
            ? await _repo.searchProducts(
                name,
                warehouseId: _selectedWarehouseId,
              )
            : const <InvoiceProduct>[];
        final found = product ?? matches.firstOrNull;
        if (found == null) {
          skipped++;
          continue;
        }
        final levelPrices = [
          found.sellingPrice,
          found.sellingPrice2,
          found.sellingPrice3,
          found.sellingPrice4,
        ];
        final importedPrice = int.tryParse(valueAt(priceColumn));
        added.add(
          InvoiceLine(
            productId: found.id,
            code: found.code,
            name: found.name,
            unit: found.unitName,
            available: found.available,
            qty: qty,
            price: importedPrice != null && importedPrice >= 0
                ? importedPrice
                : levelPrices[_selectedPriceLevel],
          ),
        );
      }
      if (added.isEmpty) {
        _toast('مفيش أصناف صالحة للاستيراد. الأصناف غير المطابقة: $skipped.');
        return;
      }
      setState(() {
        for (final line in added) {
          _tbl.add(line);
        }
      });
      _recompute();
      _toast('اتضاف ${added.length} صنف. الأصناف المتخطاة: $skipped.');
    } catch (e) {
      _toast('تعذر استيراد الملف: $e');
    }
  }

  List<List<String>> _parseCsv(String source) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (char == '"') {
        if (quoted && i + 1 < source.length && source[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        row.add(cell.toString());
        cell.clear();
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') {
          i++;
        }
        row.add(cell.toString());
        cell.clear();
        if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        cell.write(char);
      }
    }
    row.add(cell.toString());
    if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
    return rows;
  }

  Future<void> _showCouponDiscount() async {
    if (_tbl.lines.isEmpty) {
      _toast('ضيف أصناف للفاتورة الأول.');
      return;
    }
    final valueController = TextEditingController();
    var kind = 'مبلغ';
    final result = await showDialog<(String, int)?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('كوبون الخصم'),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'نوع الخصم'),
                    items: const ['مبلغ', 'نسبة']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        dialogSetState(() => kind = value ?? kind),
                  ),
                  TextField(
                    controller: valueController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: kind == 'نسبة' ? 'نسبة الخصم %' : 'مبلغ الخصم',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  final value = int.tryParse(valueController.text.trim());
                  Navigator.of(dialogContext)
                      .pop(value == null ? null : (kind, value));
                },
                child: const Text('تطبيق'),
              ),
            ],
          ),
        ),
      ),
    );
    valueController.dispose();
    if (!mounted || result == null) return;
    final (discountKind, value) = result;
    final subtotal = _tbl.netTotal;
    if (value <= 0 ||
        (discountKind == 'نسبة' && value > 100) ||
        (discountKind == 'مبلغ' && value > subtotal)) {
      _toast('قيمة الخصم مش صحيحة.');
      return;
    }
    _syncing = true;
    if (discountKind == 'نسبة') {
      _discPct.text = '$value';
      _discVal.clear();
    } else {
      _discVal.text = '$value';
      _discPct.clear();
    }
    _syncing = false;
    _recompute();
    _toast('اتطبق الخصم على الفاتورة.');
  }

  Future<void> _showCalculator() async {
    try {
      final executable = Platform.isWindows
          ? 'calc.exe'
          : Platform.isMacOS
          ? 'open'
          : 'gnome-calculator';
      await Process.start(
        executable,
        Platform.isMacOS ? ['/System/Applications/Calculator.app'] : const [],
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      _toast('مش قادر أفتح آلة حاسبة النظام: $e');
    }
  }

  Future<void> _showSelectedProductImage() async {
    InvoiceProduct? product;
    final index = _tbl.selectedIndex;
    if (index >= 0 && index < _tbl.lines.length) {
      final line = _tbl.lines[index];
      product = await _repo.findByBarcode(
        line.code,
        warehouseId: _selectedWarehouseId,
      );
      product ??= (await _repo.searchProducts(
        line.name,
        warehouseId: _selectedWarehouseId,
      )).where((item) => item.id == line.productId).firstOrNull;
    }
    if (!mounted) return;
    final path = product?.imagePath;
    if (path == null || path.trim().isEmpty || !File(path).existsSync()) {
      _toast('مفيش صورة مسجلة للصنف المحدد.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(product!.name),
                trailing: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Flexible(child: Image.file(File(path), fit: BoxFit.contain)),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshSalesLookups() async {
    try {
      final accounts = await _repo.getAccounts();
      final salesRepresentatives = await _repo.getSalesRepresentatives();
      final warehouses = await _repo.getWarehouses();
      final treasuries = await _repo.getTreasuries();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _salesRepresentatives = salesRepresentatives;
        if (!_salesRepresentatives.any(
          (row) => row.id == _selectedSalesRepresentative?.id,
        )) {
          _selectedSalesRepresentative = null;
        }
        _warehouses = warehouses;
        _treasuries = treasuries;
        if (!_warehouses.any((row) => row.id == _selectedWarehouseId)) {
          _selectedWarehouseId = warehouses.firstOrNull?.id;
        }
        if (!_treasuries.any((row) => row.id == _selectedTreasuryId)) {
          _selectedTreasuryId = treasuries.firstOrNull?.id;
        }
      });
      _toast('اتحدّثت بيانات العملاء والمندوبين والمخازن والخزائن.');
    } catch (e) {
      _toast('تعذر تحديث البيانات: $e');
    }
  }

  Future<void> _saveAndPrint() async {
    if (_savedInvoiceId == null || _editing) await _save();
    if (!mounted || _savedInvoiceId == null || _editing) return;
    await _print();
  }

  Future<void> _saveAndClose() async {
    if (_savedInvoiceId == null || _editing) await _save();
    if (!mounted || _savedInvoiceId == null || _editing) return;
    _close();
  }

  void _close() {
    removeCurrentAppTab(context);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  // ---------------------------------------------------------------------------
  // Header discount / addition.
  // ---------------------------------------------------------------------------
  int _discountAmount(int subtotal) {
    final pct = int.tryParse(_discPct.text.trim()) ?? 0;
    if (pct > 0) return subtotal * pct ~/ 100;
    return int.tryParse(_discVal.text.trim()) ?? 0;
  }

  int _additionAmount(int subtotal) {
    final amount = int.tryParse(_addVal.text.trim()) ?? 0;
    final pct = int.tryParse(_addPct.text.trim()) ?? 0;
    if (_addKind == 'نسبة' && pct > 0) return subtotal * pct ~/ 100;
    return amount;
  }

  void _recompute() {
    final subtotal = _tbl.netTotal;
    final total = math.max(
      0,
      subtotal - _discountAmount(subtotal) + _additionAmount(subtotal),
    );
    if (_grandTotal.value != total) _grandTotal.value = total;
  }

  void _onDiscPctChanged() {
    if (_syncing) return;
    final pct = int.tryParse(_discPct.text.trim());
    _syncing = true;
    if (pct == null || pct <= 0) {
      _discVal.clear();
    } else {
      _discVal.text = '${_tbl.netTotal * pct ~/ 100}';
    }
    _syncing = false;
    _recompute();
  }

  void _onDiscValChanged() {
    if (_syncing) return;
    if (_discPct.text.isNotEmpty) {
      _syncing = true;
      _discPct.clear();
      _syncing = false;
    }
    _recompute();
  }

  void _onAddPctChanged() {
    if (_syncing) return;
    final pct = int.tryParse(_addPct.text.trim());
    _syncing = true;
    if (pct == null || pct <= 0) {
      _addVal.clear();
    } else {
      _addVal.text = '${_tbl.netTotal * pct ~/ 100}';
    }
    _syncing = false;
    if (_addKind != 'نسبة') {
      setState(() => _addKind = 'نسبة');
    }
    _recompute();
  }

  void _onAddValChanged() {
    if (_syncing) return;
    if (_addPct.text.isNotEmpty) {
      _syncing = true;
      _addPct.clear();
      _syncing = false;
    }
    if (_addKind != 'مبلغ') {
      setState(() => _addKind = 'مبلغ');
    }
    _recompute();
  }

  String _methodForTab(int tab) =>
      tab >= 0 && tab < _kPayMethods.length ? _kPayMethods[tab] : 'cash';

  int get _qtyFromField {
    final value = int.tryParse(_addQty.text.trim()) ?? 1;
    return value <= 0 ? 1 : value;
  }

  int _sellingPriceFor(InvoiceProduct product) {
    final price = switch (_selectedPriceLevel) {
      1 => product.sellingPrice2,
      2 => product.sellingPrice3,
      3 => product.sellingPrice4,
      _ => product.sellingPrice,
    };
    return price > 0 ? price : product.sellingPrice;
  }

  // ---------------------------------------------------------------------------
  // Products.
  // ---------------------------------------------------------------------------
  void _addProduct(InvoiceProduct product, {int? qty}) {
    final amount = qty ?? _qtyFromField;
    if ((_kind.isSale || _kind.isPurchaseReturn) &&
        amount > product.available) {
      _toast(
        'الكمية المطلوبة أكبر من المتاح للصنف «${product.name}» '
        '(${product.available}).',
      );
      return;
    }
    final existing = _tbl.lines.indexWhere((l) => l.productId == product.id);
    if (existing >= 0) {
      final line = _tbl.lines[existing];
      final newQty = line.qty + amount;
      if ((_kind.isSale || _kind.isPurchaseReturn) &&
          newQty > product.available) {
        _toast(
          'إجمالي الكمية أكبر من المتاح للصنف «${product.name}» '
          '(${product.available}).',
        );
        return;
      }
      _tbl.update(existing, qty: newQty);
      _tbl.select(existing);
    } else {
      final customerPrice =
          _kind == InvoiceOpKind.sale &&
              _selectedPriceLevel == 0 &&
              _selectedAccount != null
          ? _repo.customerLastSoldPrice(_selectedAccount!.id, product.id)
          : null;
      _tbl.add(
        InvoiceLine(
          productId: product.id,
          code: product.code,
          name: product.name,
          unit: product.unitName.trim().isEmpty ? 'حبة' : product.unitName,
          available: product.available,
          qty: amount,
          price:
              customerPrice ??
              (_kind.usesSellingPrice
                  ? _sellingPriceFor(product)
                  : product.purchasePrice),
        ),
      );
    }
    _addQty.text = '1';
    _toast('تمت إضافة «${product.name}».');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_kind.isSale) {
        _tableKey.currentState?.scrollToEntryRow();
      } else {
        _tableKey.currentState?.scrollToSelected();
      }
    });
  }

  Future<void> _submitSearch(String text) async {
    final key = text.trim();
    if (key.isEmpty) {
      _toast('اكتب اسم الصنف أو الباركود أولاً.');
      return;
    }
    try {
      final byCode = await _repo.findByBarcode(
        key,
        warehouseId: _kind.isSale ? _selectedWarehouseId : null,
      );
      if (!mounted) return;
      if (byCode != null) {
        _search.clear();
        _addProduct(byCode, qty: _qtyFromField);
        _searchFocus.requestFocus();
        return;
      }
      final results = await _repo.searchProducts(
        key,
        warehouseId: _kind.isSale ? _selectedWarehouseId : null,
      );
      if (!mounted) return;
      if (results.isNotEmpty) {
        _search.clear();
        _addProduct(results.first, qty: _qtyFromField);
        _searchFocus.requestFocus();
      } else {
        _toast('لا توجد نتائج مطابقة لـ «$key».');
      }
    } catch (e) {
      _toast('تعذر البحث في الأصناف: $e');
    }
  }

  void _onSearchPicked(InvoiceProduct product) {
    _search.clear();
    _addProduct(product, qty: _qtyFromField);
    _focusProductSearch();
  }

  Future<void> _showQuickList() async {
    final product = await showDialog<InvoiceProduct>(
      context: context,
      builder: (_) => QuickProductDialog<InvoiceProduct>(
        title: 'قائمة سريعة',
        loader: () => _repo.listProducts(
          warehouseId: _kind.isSale ? _selectedWarehouseId : null,
        ),
      ),
    );
    if (!mounted || product == null) return;
    _addProduct(product, qty: _qtyFromField);
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
      if (!mounted || picked == null) return;
      final id = (picked['id'] as num).toInt();
      final product = await showDialog<InvoiceProduct>(
        context: context,
        builder: (_) => QuickProductDialog<InvoiceProduct>(
          title: 'أصناف قسم ${picked['name']}',
          loader: () => _repo.listProducts(
            categoryId: id,
            warehouseId: _kind.isSale ? _selectedWarehouseId : null,
          ),
        ),
      );
      if (!mounted || product == null) return;
      _addProduct(product, qty: _qtyFromField);
    } catch (e) {
      _toast('تعذر فتح الأقسام: $e');
    }
  }

  Future<void> _inquiry() async {
    InvoiceProduct? product;
    final selected = _tbl.selectedIndex;
    final line = selected >= 0 ? _tbl.lines[selected] : null;
    final key = _search.text.trim();
    try {
      if (line != null) {
        final results = await _repo.searchProducts(
          line.name,
          warehouseId: _kind.isSale ? _selectedWarehouseId : null,
        );
        product =
            results.where((p) => p.id == line.productId).firstOrNull ??
            results.firstOrNull;
      } else if (key.isNotEmpty) {
        product = await _repo.findByBarcode(
          key,
          warehouseId: _kind.isSale ? _selectedWarehouseId : null,
        );
        if (product == null) {
          final results = await _repo.searchProducts(
            key,
            warehouseId: _kind.isSale ? _selectedWarehouseId : null,
          );
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
      builder: (_) => InquiryDialog<InvoiceProduct>(product: product!),
    );
  }

  // ---------------------------------------------------------------------------
  // Accounts / payment.
  // ---------------------------------------------------------------------------
  Future<void> _pickAccount() async {
    if (_accounts.isEmpty) {
      try {
        _accounts = await _repo.getAccounts();
      } catch (_) {}
    }
    if (!mounted) return;
    if (_accounts.isEmpty) {
      _toast('لا توجد حسابات مسجلة.');
      return;
    }
    final picked = await showDialog<InvoiceAccount>(
      context: context,
      builder: (_) => _InvoiceAccountPickerDialog(
        accounts: _accounts,
        selected: _selectedAccount,
        title: _kind.accountPickerTitle,
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedAccount = picked.id == 0 ? null : picked;
      _account.text = _selectedAccount?.name ?? '';
    });
  }

  Future<void> _openPayment() async {
    if (_kind.isQuotation) {
      await _convertQuotationToSale();
      return;
    }
    final total = _grandTotal.value;
    if (total <= 0) {
      _toast('أضف أصنافاً للفاتورة أولاً.');
      return;
    }
    final account = _selectedAccount;
    if (account == null) {
      _toast('اختر حساب ${_kind.partyWord} أولاً من الشريط الأحمر.');
      return;
    }
    final alreadyPaid = _savedInvoiceId != null
        ? _paid
        : (_pendingPayment?.amount ?? 0);
    final remaining = total - alreadyPaid;
    if (remaining <= 0) {
      _toast(
        _kind.isSalesReturn
            ? 'تم استرداد قيمة المرتجع بالكامل.'
            : (_kind.isPurchaseReturn
                  ? 'تم تحصيل قيمة المرتجع بالكامل.'
                  : 'الفاتورة محصلة بالكامل.'),
      );
      return;
    }
    final input = await showDialog<InvoicePaymentInput>(
      context: context,
      builder: (_) => _InvoicePaymentDialog(
        accountId: account.id,
        total: total,
        remaining: remaining,
        accountName: account.name,
        initialMethod: _payTab == 3 ? 'cash' : _methodForTab(_payTab),
        treasuries: _treasuries,
        selectedTreasuryId: _selectedTreasuryId,
        title: _kind.paymentDialogTitle,
        amountLabel: _kind.paymentAmountLabel,
        confirmLabel: _kind.paymentConfirmLabel,
      ),
    );
    if (!mounted || input == null) return;
    if (_savedInvoiceId != null) {
      try {
        final result = await _repo.recordPayment(
          invoiceId: _savedInvoiceId!,
          accountId: account.id,
          amount: input.amount,
          method: input.method,
          treasuryId: input.treasuryId,
        );
        if (!mounted) return;
        setState(() {
          _paid = result.paid;
          _paidNotifier.value = result.paid;
        });
        _toast('تم تسجيل مبلغ ${input.amount}.');
      } catch (e) {
        _toast(e is InvoiceValidationException ? e.message : '$e');
      }
    } else {
      setState(() {
        _pendingPayment = input;
        _paid = input.amount;
        _paidNotifier.value = input.amount;
      });
      _toast('سيتم تسجيل مبلغ ${input.amount} عند حفظ المستند.');
    }
  }

  /// Save the quotation if needed, then open the sale screen pre-filled with
  /// its lines. The quotation is marked converted inside the sale transaction.
  Future<void> _convertQuotationToSale() async {
    if (_tbl.lines.isEmpty) {
      _toast('أضف أصنافاً لعرض السعر أولاً.');
      return;
    }
    if (_savedInvoiceId == null) {
      await _save();
      if (!mounted || _savedInvoiceId == null) return;
    }
    final id = _savedInvoiceId!;
    await context.push('/sales?quote=$id');
  }

  // ---------------------------------------------------------------------------
  // Save / new / delete.
  // ---------------------------------------------------------------------------
  Future<void> _save({bool resetAfter = false}) async {
    if (_saving) return;
    if (_savedInvoiceId != null && !_editing) {
      if (resetAfter) {
        _newInvoice();
      } else {
        _toast('المستند رقم $_savedNumber محفوظ بالفعل. اضغط F10 لجديد.');
      }
      return;
    }
    if (!_editing && _kind.needsOriginalInvoice && _originalInvoiceId == null) {
      _toast(
        'حمّل ${_kind.isSalesReturn ? 'فاتورة بيع' : 'فاتورة شراء'} أولاً.',
      );
      return;
    }
    if (_tbl.lines.isEmpty) {
      _toast('أضف صنفاً واحداً على الأقل قبل الحفظ.');
      return;
    }
    final subtotal = _tbl.netTotal;
    final discount = _discountAmount(subtotal);
    final addition = _additionAmount(subtotal);
    final pending = _pendingPayment;
    final accountId = pending?.accountId ?? _selectedAccount?.id;
    final number = _invoiceNo.text.trim();
    final invoiceDate = _kind.isSale ? _parseInvoiceTimestamp() : null;
    if (_kind.isSale && invoiceDate == null) {
      _toast('راجع التاريخ والوقت واكتبهم بشكل صحيح قبل الحفظ.');
      return;
    }
    final fallbackNumber = _repo.nextInvoiceNumber();
    setState(() => _saving = true);
    try {
      final result = _editing && _savedInvoiceId != null
          ? await _repo.updateInvoice(
              invoiceId: _savedInvoiceId!,
              accountId: accountId,
              invoiceNumber: number.isEmpty ? fallbackNumber : number,
              lines: _tbl.lines.map((l) => l.clone()).toList(),
              discount: discount,
              addition: addition,
              notes: _notes.text.trim(),
              paymentMethod: _methodForTab(_payTab),
              invoiceDate: invoiceDate,
              warehouseId: _kind.isSale ? _selectedWarehouseId : null,
              salesRepresentativeId: _kind.isSale
                  ? _selectedSalesRepresentative?.id
                  : null,
              originalInvoiceId: _originalInvoiceId,
              customFields: _customFieldValues,
            )
          : await _repo.saveInvoice(
              accountId: accountId,
              invoiceNumber: number.isEmpty ? fallbackNumber : number,
              lines: _tbl.lines.map((l) => l.clone()).toList(),
              discount: discount,
              addition: addition,
              notes: _notes.text.trim(),
              paymentMethod: _methodForTab(_payTab),
              payment: pending,
              invoiceDate: invoiceDate,
              warehouseId: _kind.isSale ? _selectedWarehouseId : null,
              salesRepresentativeId: _kind.isSale
                  ? _selectedSalesRepresentative?.id
                  : null,
              originalInvoiceId: _originalInvoiceId,
              quotationId: _sourceQuoteId,
              customFields: _customFieldValues,
            );
      if (!mounted) return;
      final wasEditing = _editing;
      setState(() {
        _saving = false;
        _editing = false;
        _savedInvoiceId = result.invoiceId;
        _savedNumber = result.invoiceNumber;
        _paid = result.paid;
        _pendingPayment = null;
        _paidNotifier.value = result.paid;
        _tbl.locked = true;
      });
      _toast(
        wasEditing
            ? 'تم تحديث ${_kind.printTitle} رقم ${result.invoiceNumber} '
                  'بإجمالي ${result.total}.'
            : '${_kind.saveMessage} ${result.invoiceNumber} '
                  'بإجمالي ${result.total}.',
      );
      if (resetAfter) _newInvoice(alreadySaved: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(
        e is InvoiceValidationException ? e.message : 'تعذر حفظ المستند: $e',
      );
    }
  }

  void _newInvoice({bool alreadySaved = false}) {
    setState(() {
      _tbl.clear();
      _tbl.locked = false;
      _savedInvoiceId = null;
      _savedNumber = '';
      _paid = 0;
      _pendingPayment = null;
      _paidNotifier.value = 0;
      _selectedAccount = null;
      _selectedSalesRepresentative = null;
      _account.clear();
      _notes.clear();
      _search.clear();
      _addQty.text = '1';
      _addVal.clear();
      _addPct.clear();
      _discVal.clear();
      _discPct.clear();
      _addKind = 'نسبة';
      _selectedPriceLevel = 0;
      _customFieldValues = {};
      _payTab = 0;
      _treasury =
          _treasuries
              .where((item) => item.id == _selectedTreasuryId)
              .firstOrNull
              ?.name ??
          'درج النقدية';
      _originalInvoiceId = null;
      _sourceQuoteId = null;
      _editing = false;
      _invoiceNo.text = _repo.nextInvoiceNumber();
      final now = DateTime.now();
      _date.text = _fmtDate(now);
      _time.text = _fmtTime(now);
    });
    _recompute();
    _focusProductSearch();
    _toast(
      alreadySaved
          ? 'تم حفظ المستند وفتح ${_kind.printTitle} جديد.'
          : 'تم تجهيز ${_kind.printTitle} جديد.',
    );
  }

  Future<void> _deleteInvoice() async {
    if (_tbl.lines.isEmpty && _savedInvoiceId == null) {
      _toast('لا يوجد مستند لحذفه.');
      return;
    }
    final ok = await _confirm(
      'حذف المستند',
      'هل تريد مسح المستند الحالي وبدء مستند جديد؟',
    );
    if (!mounted || !ok) return;
    _newInvoice();
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: SizedBox(
          width: 360,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 12.5, color: _kInk),
                ),
                const SizedBox(height: 16),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    _dialogButton(
                      label: 'تأكيد',
                      color: _kRed,
                      textColor: Colors.white,
                      onTap: () => Navigator.of(ctx).pop(true),
                    ),
                    const SizedBox(width: 8),
                    _dialogButton(
                      label: 'إلغاء',
                      color: _kSoft,
                      textColor: _kInk,
                      onTap: () => Navigator.of(ctx).pop(false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result ?? false;
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
      _toast('المستند محفوظ — لا يمكن تعديل سطوره.');
      return;
    }
    if (!await verifyInvoiceLineDeletePassword(context) || !mounted) return;
    if (ask && _confirmDelete) {
      final ok = await _confirm('حذف السطر', 'هل تريد حذف السطر المحدد؟');
      if (!mounted || !ok) return;
    }
    _tbl.removeAt(index);
    _toast('تم حذف السطر.');
  }

  Future<void> _lineOptions() async {
    if (_tbl.selectedIndex < 0) {
      _toast('حدد سطراً من الجدول أولاً.');
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (_) => const LineOptionsDialog(options: _kInvoiceLineOptions),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'duplicate':
        _tbl.duplicateSelected();
        _toast('تم تكرار السطر.');
      case 'up':
        _tbl.moveSelected(-1);
      case 'down':
        _tbl.moveSelected(1);
      case 'clear-discount':
        _tbl.update(_tbl.selectedIndex, discount: 0);
        _toast('تم إلغاء خصم السطر.');
      case 'custom-fields':
        await _editSelectedLineCustomFields();
      case 'delete':
        await _removeSelected();
    }
  }

  Future<void> _editSelectedLineCustomFields() async {
    final index = _tbl.selectedIndex;
    if (index < 0 || index >= _tbl.lines.length) return;
    if (_tbl.locked) {
      _toast('المستند محفوظ — لا يمكن تعديل حقوله.');
      return;
    }
    final values = await showDocumentCustomFieldsDialog(
      context,
      scope: 'line',
      initialValues: Map<int, String>.from(_tbl.lines[index].customFields),
    );
    if (!mounted || values == null) return;
    setState(() => _tbl.lines[index].customFields = values);
    _toast('تم حفظ حقول الصنف للمستند.');
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
      _toast('المستند محفوظ — لا يمكن تعديل أسعاره.');
      return;
    }
    final prices = await showDialog<Map<int, int>>(
      context: context,
      builder: (_) => BulkPriceDialog(
        title: 'تعديل ${_kind.priceLabel}',
        items: _tbl.lines
            .map((l) => BulkPriceItem(name: l.name, price: l.price))
            .toList(),
      ),
    );
    if (!mounted || prices == null) return;
    prices.forEach((index, price) {
      _tbl.update(index, price: price);
    });
    _toast('تم تحديث ${_kind.priceLabel}.');
  }

  // ---------------------------------------------------------------------------
  // Print / export / share.
  // ---------------------------------------------------------------------------
  Future<void> _print() async {
    const columns = [
      'الصنف',
      'الوحدة',
      'الكمية',
      'السعر',
      'الإجمالي',
      'الخصم',
      'النهائي',
    ];
    var title = _kind.printTitle;
    var rows = _tbl.lines
        .map(
          (l) => [
            l.name,
            l.unit,
            '${l.qty}',
            '${l.price}',
            '${l.gross}',
            '${l.discount}',
            '${l.net}',
          ],
        )
        .toList();
    if (_savedInvoiceId != null) {
      try {
        final invoice = await _repo.getInvoice(_savedInvoiceId!);
        final items = await _repo.getInvoiceItems(_savedInvoiceId!);
        if (!mounted) return;
        if (invoice != null) {
          title = '${_kind.printTitle} رقم ${invoice['invoice_number']}';
        }
        if (items.isNotEmpty) {
          rows = items
              .map(
                (r) => [
                  '${r['product_name']}',
                  '${r['product_code']}',
                  '${r['quantity']}',
                  '${r['unit_price']}',
                  '${(r['quantity'] as int) * (r['unit_price'] as int)}',
                  '${r['discount']}',
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
        '${dir.path}/${_kind.filePrefix}_${_invoiceNo.text.trim()}_$stamp.csv',
      );
      final buffer = StringBuffer('\uFEFF');
      buffer.writeln(
        'رقم الصنف,اسم الصنف,الوحدة,المتاح,الكمية,السعر,الإجمالي,الخصم,النهائي',
      );
      for (final line in _tbl.lines) {
        buffer.writeln(
          '${line.code},"${line.name}",${line.unit},${line.available},'
          '${line.qty},${line.price},${line.gross},${line.discount},${line.net}',
        );
      }
      buffer.writeln(
        ',,,,,,${_tbl.grossTotal},${_tbl.discountTotal},${_tbl.netTotal}',
      );
      await file.writeAsString(buffer.toString(), flush: true);
      if (!mounted) return;
      _toast('تم تصدير المستند إلى ${file.path}');
    } catch (e) {
      _toast('تعذر التصدير إلى Excel: $e');
    }
  }

  Future<void> _share() async {
    await Clipboard.setData(ClipboardData(text: _invoiceShareText()));
    _toast('تم نسخ نص المستند.');
  }

  String _invoiceShareText() {
    final buffer = StringBuffer();
    buffer.writeln('${_kind.printTitle} رقم ${_invoiceNo.text.trim()}');
    if (_selectedAccount != null) {
      buffer.writeln('الحساب: ${_selectedAccount!.name}');
    }
    buffer.writeln('التاريخ: ${_date.text}');
    for (final line in _tbl.lines) {
      buffer.writeln('${line.name} × ${line.qty} = ${line.net}');
    }
    buffer.writeln('الإجمالي: ${_grandTotal.value}');
    return buffer.toString();
  }

  Future<void> _sendInvoice(String channel) async {
    if (_tbl.lines.isEmpty) {
      _toast('أضف أصنافاً إلى الفاتورة أولاً.');
      return;
    }
    if (_savedInvoiceId == null || _editing) await _save();
    if (!mounted || _savedInvoiceId == null || _editing) return;

    final text = Uri.encodeComponent(_invoiceShareText());
    final accountContact = _selectedAccount == null
        ? null
        : _repo.db.query('SELECT phone, email FROM accounts WHERE id = ?', [
            _selectedAccount!.id,
          ]).firstOrNull;
    final uri = switch (channel) {
      'email' => () {
        final email = '${accountContact?['email'] ?? ''}'.trim();
        if (email.isEmpty) {
          _toast('أضف البريد الإلكتروني للعميل من بيانات الحساب أولاً.');
          return null;
        }
        final subject = Uri.encodeComponent(
          '${_kind.printTitle} رقم ${_invoiceNo.text.trim()}',
        );
        return 'mailto:$email?subject=$subject&body=$text';
      }(),
      _ => () {
        final phone = '${accountContact?['phone'] ?? ''}'.replaceAll(
          RegExp(r'[^0-9+]'),
          '',
        );
        final recipient = phone.replaceAll('+', '');
        final destination = recipient.isEmpty ? '' : '$recipient/';
        return 'https://wa.me/$destination?text=$text';
      }(),
    };
    if (uri == null) return;
    try {
      await Process.start('explorer.exe', [
        uri,
      ], mode: ProcessStartMode.detached);
    } catch (error) {
      _toast('تعذر فتح تطبيق الإرسال: $error');
    }
  }

  Future<void> _printJournal() async {
    if (_tbl.lines.isEmpty) {
      _toast('أضف أصنافاً إلى الفاتورة أولاً.');
      return;
    }
    if (_savedInvoiceId == null || _editing) await _save();
    if (!mounted || _savedInvoiceId == null || _editing) return;

    final subtotal = _tbl.netTotal;
    final discount = _discountAmount(subtotal);
    final addition = _additionAmount(subtotal);
    final paid = (_pendingPayment?.amount ?? _paid).clamp(0, _grandTotal.value);
    final remaining = (_grandTotal.value - paid).clamp(0, 1 << 30);
    final rows = <List<String>>[
      [_treasury, '$paid', '0'],
      [_selectedAccount?.name ?? 'العميل', '$remaining', '0'],
      ['خصم الفاتورة', '$discount', '0'],
      ['المبيعات', '0', '$subtotal'],
      if (addition > 0) ['إضافات / ضريبة', '0', '$addition'],
    ];
    await showDialog<void>(
      context: context,
      builder: (_) => PrintPreviewDialog(
        title: 'قيد ${_kind.printTitle} رقم ${_invoiceNo.text.trim()}',
        columns: const ['الحساب', 'مدين', 'دائن'],
        rows: rows,
      ),
    );
  }

  Future<void> _printBarcode() async {
    if (_tbl.lines.isEmpty) {
      _toast('أضف أصنافاً لطباعة باركوداتها.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => BarcodeLabelsDialog(
        title: '${_kind.printTitle} ${_invoiceNo.text.trim()}',
        labels: _tbl.lines
            .map(
              (l) => BarcodeLabel(code: l.code, name: l.name, price: l.price),
            )
            .toList(),
      ),
    );
  }

  Future<void> _showSettings() async {
    final settings = await showDialog<ShopSettings>(
      context: context,
      builder: (_) => ShopSettingsDialog(
        title: _kind.settingsTitle,
        confirmDelete: _confirmDelete,
        roundStep: _roundStep,
      ),
    );
    if (!mounted || settings == null) return;
    setState(() {
      _confirmDelete = settings.confirmDelete;
      _roundStep = settings.roundStep;
    });
    ShopPreferences.save(
      confirmDelete: settings.confirmDelete,
      roundStep: settings.roundStep,
    );
    _toast('تم حفظ ${_kind.settingsTitle}.');
  }

  Future<void> _showShortcuts() async {
    final items = _kInvoiceShortcuts
        .map(
          (item) => item.$1 == 'F11'
              ? (item.$1, _kind.paymentTileLabel.replaceAll(' F11', ''))
              : item,
        )
        .toList();
    await showDialog<void>(
      context: context,
      builder: (_) =>
          ShopShortcutsDialog(title: _kind.shortcutsTitle, items: items),
    );
  }

  // ---------------------------------------------------------------------------
  // Fekka.
  // ---------------------------------------------------------------------------
  void _discountFekka() {
    final subtotal = _tbl.netTotal;
    if (subtotal <= 0) {
      _toast('أضف أصنافاً أولاً.');
      return;
    }
    final total = _grandTotal.value;
    final remainder = total % _roundStep;
    if (remainder == 0) {
      _toast('الإجمالي $total بالفعل من مضاعفات $_roundStep.');
      return;
    }
    final currentDiscount = _discountAmount(subtotal);
    _syncing = true;
    _discPct.clear();
    _discVal.text = '${currentDiscount + remainder}';
    _syncing = false;
    _recompute();
    _toast(
      'تم خفض الفكة بمبلغ $remainder — الإجمالي الآن ${_grandTotal.value}.',
    );
  }

  // ---------------------------------------------------------------------------
  // Keyboard shortcuts.
  // ---------------------------------------------------------------------------
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isAltPressed) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_kind.isSale &&
        HardwareKeyboard.instance.isControlPressed &&
        key == LogicalKeyboardKey.keyM) {
      _printJournal();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f4) {
      _print();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f5) {
      _tableKey.currentState?.editSelected(_tbl.quantityColumn);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f6) {
      _tableKey.currentState?.editSelected(_tbl.priceColumn);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f7) {
      _lineOptions();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f8) {
      _removeSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f9) {
      _save();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f10) {
      _newInvoice();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f11) {
      _openPayment();
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
      extraTabColor: _kRed,
      extraTabTextColor: Colors.white,
      onExtraTabClose: _close,
      hideActiveTab: true,
      extraTabWidth: 201,
      child: LayoutBuilder(
        builder: (context, viewport) {
          final narrowSales = _kind.isSale && viewport.maxWidth < 1000;
          final sidebarCollapsed = _salesSidebarCollapsed ?? narrowSales;
          return Column(
            children: [
              if (_kind.isSale) _buildSalesToolbar(),
              if (_kind.isSale)
                Expanded(
                  child: Row(
                    textDirection: TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSalesSidebar(collapsed: sidebarCollapsed),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, available) {
                            final totalsHeight = math
                                .min(
                                  238.0,
                                  math.max(60.0, available.maxHeight * .31),
                                )
                                .toDouble();
                            final widthScale = math
                                .min(1.0, available.maxWidth / 1005.0)
                                .toDouble();
                            final designHeaderHeight = 220.0 * widthScale;
                            final maxHeaderHeight = math.max(
                              0.0,
                              available.maxHeight - totalsHeight - 8 - 56,
                            );
                            final headerHeight = math
                                .min(designHeaderHeight, maxHeaderHeight)
                                .toDouble();
                            return Column(
                              children: [
                                Expanded(
                                  child: _buildMain(
                                    salesHeaderHeight: headerHeight,
                                  ),
                                ),
                                SizedBox(
                                  height: totalsHeight,
                                  child: _buildSalesTotalsAndActions(
                                    height: totalsHeight,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
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
                _buildTotalsBar(),
                _buildFooter(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildMain({double salesHeaderHeight = 200}) {
    if (_kind.isSale) {
      return Container(
        color: Colors.white,
        child: Column(
          children: [
            SizedBox(
              height: salesHeaderHeight,
              child: _buildTopBlock(salesHeight: salesHeaderHeight),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildTableArea()),
          ],
        ),
      );
    }

    const designWidth = 882.0;
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
                if (c.maxWidth >= designWidth - 0.5) {
                  return _buildTableArea();
                }
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topRight,
                  child: SizedBox(
                    width: designWidth,
                    height: 618,
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
