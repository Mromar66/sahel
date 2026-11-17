import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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
import 'package:inventory_app/core/security/guarded_actions.dart';
import 'package:inventory_app/core/services/database_service.dart';
import 'package:inventory_app/features/accounts/presentation/print_preview_dialog.dart';
import 'package:inventory_app/features/purchases/data/purchase_repository.dart';
import 'package:inventory_app/features/purchases/domain/purchase_models.dart';

part 'purchase_layout.dart';
part 'purchase_table.dart';
part 'purchase_dialogs.dart';

/// شراء — replica of the reference new-purchase screen, wired to the real
/// purchase / stock / payment / treasury tables.
class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key, this.editId});

  /// Opens the screen in edit mode for an existing purchase invoice. Saving
  /// updates this exact id instead of creating a new invoice.
  final int? editId;

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

const Color _kYellow = ShopColors.yellow;
const Color _kGreen = ShopColors.green;
const Color _kPanelGreen = ShopColors.panelGreen;
const Color _kRed = ShopColors.red;
const Color _kRedHover = ShopColors.redHover;
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

const List<LineOption> _kPurchaseLineOptions = [
  LineOption(key: 'duplicate', label: 'تكرار السطر'),
  LineOption(key: 'up', label: 'تحريك السطر لأعلى'),
  LineOption(key: 'down', label: 'تحريك السطر لأسفل'),
  LineOption(key: 'custom-fields', label: 'الحقول الإضافية للصنف'),
  LineOption(key: 'clear-discount', label: 'إلغاء خصم السطر'),
  LineOption(key: 'delete', label: 'حذف السطر', danger: true),
];

const List<(String, String)> _kPurchaseShortcuts = [
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

class _PurchasesPageState extends State<PurchasesPage> {
  final _repo = PurchaseRepository();
  final _tbl = _PurchaseTableController();
  final _tableKey = GlobalKey<SharedDataGridState<PurchaseLine>>();
  final _searchKey = GlobalKey<ProductSearchFieldState<PurchaseProduct>>();
  final _searchFocus = FocusNode();
  final _pageFocus = FocusScopeNode(debugLabel: 'purchase-page');

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

  List<PurchaseAccount> _accounts = const [];
  PurchaseAccount? _selectedAccount;
  String _treasury = 'درج النقدية';
  int _payTab = 0;
  String _addKind = 'نسبة';
  bool _saving = false;
  bool _pinPayment = false;
  bool _confirmDelete = true;
  int _roundStep = 5;
  bool _syncing = false;

  int? _savedInvoiceId;
  String _savedNumber = '';
  int _paid = 0;
  PurchasePaymentInput? _pendingPayment;
  Map<int, String> _customFieldValues = {};

  /// True while a saved invoice is open through [PurchasesPage.editId].
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _confirmDelete = ShopPreferences.confirmDelete;
    _roundStep = ShopPreferences.roundStep;
    _editing = widget.editId != null;
    final now = DateTime.now();
    _date.text = _fmtDate(now);
    _time.text = _fmtTime(now);
    _tbl.addListener(_recompute);
    _discPct.addListener(_onDiscPctChanged);
    _discVal.addListener(_onDiscValChanged);
    _addPct.addListener(_onAddPctChanged);
    _addVal.addListener(_onAddValChanged);
    if (ShopPreferences.defaultPurchaseTaxPercent > 0) {
      _addPct.text = '${ShopPreferences.defaultPurchaseTaxPercent}';
    }
    _loadLookups();
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
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final accounts = await _repo.getAccounts();
      final invoice = _repo.nextInvoiceNumber();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _invoiceNo.text = invoice;
      });
      if (widget.editId != null) {
        await _loadForEdit(widget.editId!);
      }
    } catch (_) {
      // The screen still opens; the search box reports the DB error on use.
    }
  }

  Future<void> _loadForEdit(int id) async {
    try {
      final data = await _repo.loadPurchaseForEdit(id);
      if (!mounted) return;
      if (data == null) {
        _editing = false;
        _toast('فاتورة الشراء المطلوبة غير موجودة.');
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
            PurchaseLine(
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
        _customFieldValues = Map<int, String>.from(data.customFields);
      });
      _recompute();
      _toast('تم تحميل فاتورة الشراء رقم ${data.number} للتعديل.');
    } catch (e) {
      if (!mounted) return;
      _editing = false;
      _toast(
        e is PurchaseValidationException
            ? e.message
            : 'تعذر تحميل الفاتورة: $e',
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

  /// Runs [fn] through setState from the shared layout extension parts.
  void _rebuild(VoidCallback fn) => setState(fn);

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

  // ---------------------------------------------------------------------------
  // Products.
  // ---------------------------------------------------------------------------
  void _addProduct(PurchaseProduct product, {int? qty}) {
    final amount = qty ?? _qtyFromField;
    final existing = _tbl.lines.indexWhere((l) => l.productId == product.id);
    if (existing >= 0) {
      final line = _tbl.lines[existing];
      _tbl.update(existing, qty: line.qty + amount);
      _tbl.select(existing);
    } else {
      _tbl.add(
        PurchaseLine(
          productId: product.id,
          code: product.code,
          name: product.name,
          unit: product.unitName.trim().isEmpty ? 'حبة' : product.unitName,
          available: product.available,
          qty: amount,
          price: product.purchasePrice,
        ),
      );
    }
    _addQty.text = '1';
    _toast('تمت إضافة «${product.name}».');
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
        _addProduct(byCode, qty: _qtyFromField);
        return;
      }
      final results = await _repo.searchProducts(key);
      if (!mounted) return;
      if (results.isNotEmpty) {
        _search.clear();
        _addProduct(results.first, qty: _qtyFromField);
      } else {
        _toast('لا توجد نتائج مطابقة لـ «$key».');
      }
    } catch (e) {
      _toast('تعذر البحث في الأصناف: $e');
    }
  }

  void _onSearchPicked(PurchaseProduct product) {
    _search.clear();
    _addProduct(product, qty: _qtyFromField);
  }

  Future<void> _showQuickList() async {
    final product = await showDialog<PurchaseProduct>(
      context: context,
      builder: (_) => QuickProductDialog<PurchaseProduct>(
        title: 'قائمة سريعة',
        loader: () => _repo.listProducts(),
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
      final product = await showDialog<PurchaseProduct>(
        context: context,
        builder: (_) => QuickProductDialog<PurchaseProduct>(
          title: 'أصناف قسم ${picked['name']}',
          loader: () => _repo.listProducts(categoryId: id),
        ),
      );
      if (!mounted || product == null) return;
      _addProduct(product, qty: _qtyFromField);
    } catch (e) {
      _toast('تعذر فتح الأقسام: $e');
    }
  }

  Future<void> _inquiry() async {
    PurchaseProduct? product;
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
      builder: (_) => InquiryDialog<PurchaseProduct>(product: product!),
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
    final picked = await showDialog<PurchaseAccount>(
      context: context,
      builder: (_) =>
          _AccountPickerDialog(accounts: _accounts, selected: _selectedAccount),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedAccount = picked.id == 0 ? null : picked;
      _account.text = _selectedAccount?.name ?? '';
    });
  }

  Future<void> _openPayment() async {
    final total = _grandTotal.value;
    if (total <= 0) {
      _toast('أضف أصنافاً للفاتورة أولاً.');
      return;
    }
    final account = _selectedAccount;
    if (account == null) {
      _toast('اختر حساب المورد أولاً من الشريط الأحمر.');
      return;
    }
    final alreadyPaid = _savedInvoiceId != null
        ? _paid
        : (_pendingPayment?.amount ?? 0);
    final remaining = total - alreadyPaid;
    if (remaining <= 0) {
      _toast('الفاتورة مسددة بالكامل.');
      return;
    }
    final input = await showDialog<PurchasePaymentInput>(
      context: context,
      builder: (_) => _PaymentDialog(
        accountId: account.id,
        total: total,
        remaining: remaining,
        accountName: account.name,
        initialMethod: _payTab == 3 ? 'cash' : _methodForTab(_payTab),
        treasury: _treasury,
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
        );
        if (!mounted) return;
        setState(() {
          _paid = result.paid;
          _paidNotifier.value = result.paid;
        });
        _toast('تم تسجيل سداد ${input.amount}.');
      } catch (e) {
        _toast(e is PurchaseValidationException ? e.message : '$e');
      }
    } else {
      setState(() {
        _pendingPayment = input;
        _paid = input.amount;
        _paidNotifier.value = input.amount;
      });
      _toast('سيتم تسجيل سداد ${input.amount} عند حفظ الفاتورة.');
    }
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
        _toast(
          'الفاتورة رقم $_savedNumber محفوظة بالفعل. اضغط F10 لفاتورة جديدة.',
        );
      }
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
    setState(() => _saving = true);
    try {
      final result = _editing && _savedInvoiceId != null
          ? await _repo.updatePurchase(
              invoiceId: _savedInvoiceId!,
              accountId: accountId,
              invoiceNumber: number.isEmpty ? '1' : number,
              lines: _tbl.lines.map((l) => l.clone()).toList(),
              discount: discount,
              addition: addition,
              notes: _notes.text.trim(),
              paymentMethod: _methodForTab(_payTab),
              customFields: _customFieldValues,
            )
          : await _repo.savePurchase(
              accountId: accountId,
              invoiceNumber: number.isEmpty ? '1' : number,
              lines: _tbl.lines.map((l) => l.clone()).toList(),
              discount: discount,
              addition: addition,
              notes: _notes.text.trim(),
              paymentMethod: _methodForTab(_payTab),
              payment: pending,
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
            ? 'تم تحديث فاتورة الشراء رقم ${result.invoiceNumber} '
                  'بإجمالي ${result.total}.'
            : 'تم حفظ فاتورة الشراء رقم ${result.invoiceNumber} '
                  'بإجمالي ${result.total}.',
      );
      if (resetAfter) _newInvoice(alreadySaved: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(
        e is PurchaseValidationException ? e.message : 'تعذر حفظ الفاتورة: $e',
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
      _account.clear();
      _notes.clear();
      _customFieldValues = {};
      _search.clear();
      _addQty.text = '1';
      _addVal.clear();
      _addPct.clear();
      _discVal.clear();
      _discPct.clear();
      _addKind = 'نسبة';
      if (ShopPreferences.defaultPurchaseTaxPercent > 0) {
        _addPct.text = '${ShopPreferences.defaultPurchaseTaxPercent}';
      }
      _payTab = 0;
      _treasury = 'درج النقدية';
      _editing = false;
      _invoiceNo.text = _repo.nextInvoiceNumber();
      final now = DateTime.now();
      _date.text = _fmtDate(now);
      _time.text = _fmtTime(now);
    });
    _recompute();
    _toast(
      alreadySaved
          ? 'تم حفظ الفاتورة وفتح فاتورة شراء جديدة.'
          : 'تم تجهيز فاتورة شراء جديدة.',
    );
  }

  Future<void> _deleteInvoice() async {
    if (_tbl.lines.isEmpty && _savedInvoiceId == null) {
      _toast('لا توجد فاتورة لحذفها.');
      return;
    }
    final ok = await _confirm(
      'حذف الفاتورة',
      'هل تريد مسح الفاتورة الحالية وبدء فاتورة جديدة؟',
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
      _toast('الفاتورة محفوظة — لا يمكن تعديل سطورها.');
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
      builder: (_) => const LineOptionsDialog(options: _kPurchaseLineOptions),
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
      _toast('الفاتورة محفوظة — لا يمكن تعديل حقولها.');
      return;
    }
    final values = await showDocumentCustomFieldsDialog(
      context,
      scope: 'line',
      initialValues: Map<int, String>.from(_tbl.lines[index].customFields),
    );
    if (!mounted || values == null) return;
    setState(() => _tbl.lines[index].customFields = values);
    _toast('تم حفظ الحقول الإضافية للصنف.');
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
      _toast('الفاتورة محفوظة — لا يمكن تعديل أسعارها.');
      return;
    }
    final prices = await showDialog<Map<int, int>>(
      context: context,
      builder: (_) => BulkPriceDialog(
        title: 'تعديل أسعار الشراء',
        items: _tbl.lines
            .map((l) => BulkPriceItem(name: l.name, price: l.price))
            .toList(),
      ),
    );
    if (!mounted || prices == null) return;
    prices.forEach((index, price) {
      _tbl.update(index, price: price);
    });
    _toast('تم تحديث أسعار الشراء.');
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
    var title = 'فاتورة شراء';
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
          title = 'فاتورة شراء رقم ${invoice['invoice_number']}';
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
        '${dir.path}/purchase_${_invoiceNo.text.trim()}_$stamp.csv',
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
      _toast('تم تصدير الفاتورة إلى ${file.path}');
    } catch (e) {
      _toast('تعذر التصدير إلى Excel: $e');
    }
  }

  Future<void> _share() async {
    final buffer = StringBuffer();
    buffer.writeln('فاتورة شراء رقم ${_invoiceNo.text.trim()}');
    if (_selectedAccount != null) {
      buffer.writeln('الحساب: ${_selectedAccount!.name}');
    }
    buffer.writeln('التاريخ: ${_date.text}');
    for (final line in _tbl.lines) {
      buffer.writeln('${line.name} × ${line.qty} = ${line.net}');
    }
    buffer.writeln('الإجمالي: ${_grandTotal.value}');
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    _toast('تم نسخ نص الفاتورة.');
  }

  Future<void> _printBarcode() async {
    if (_tbl.lines.isEmpty) {
      _toast('أضف أصنافاً لطباعة باركوداتها.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => BarcodeLabelsDialog(
        title: 'فاتورة شراء ${_invoiceNo.text.trim()}',
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
        title: 'إعدادات شاشة الشراء',
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
    _toast('تم حفظ إعدادات شاشة الشراء.');
  }

  Future<void> _showShortcuts() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const ShopShortcutsDialog(
        title: 'اختصارات شاشة الشراء',
        items: _kPurchaseShortcuts,
      ),
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
      extraTabLabel: 'شراء | جديد',
      extraTabColor: _kRed,
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
          _buildTotalsBar(),
          _buildFooter(),
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
