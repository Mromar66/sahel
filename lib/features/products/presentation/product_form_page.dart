import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inventory_app/app/widgets/hover_widgets.dart';
import 'package:inventory_app/app/widgets/document_custom_fields.dart';
import 'package:inventory_app/core/services/database_service.dart';
import 'package:inventory_app/core/services/document_custom_fields.dart';
import 'package:inventory_app/features/products/data/product_repository.dart';
import 'package:inventory_app/features/products/domain/product_entity.dart';
import 'package:inventory_app/features/products/domain/product_provider.dart';

/// Green product form shown as a small 992×630 floating page over the products
/// list — matching the reference screen: photo box, big blue-underlined
/// "اسم الصنف" field, price fields, tabs (عام / الكميات الإقتصادية /
/// وحدات الغياس / المزيد), the three panels (تصنيفات / أكواد الصنف / عام),
/// the "»" bar on the right edge and the bottom save buttons with their
/// shortcut captions.
class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, this.product});

  final ProductEntity? product;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final ProductRepository _repo = ProductRepository();

  late final TextEditingController _name;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _sellingPrice2;
  late final TextEditingController _sellingPrice3;
  late final TextEditingController _sellingPrice4;
  late final TextEditingController _lastSellingPrice;
  late final TextEditingController _discountPercent;
  late final TextEditingController _code1;
  late final TextEditingController _barcode;
  late final TextEditingController _code2;
  late final TextEditingController _otherCodes;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _reorderPoint;
  late final TextEditingController _economicQty;
  late final TextEditingController _minimumStock;
  late final TextEditingController _currentStock;
  late final TextEditingController _lastQty;

  List<Map<String, Object?>> _categories = const [];
  List<Map<String, Object?>> _units = const [];
  int? _categoryId;
  int? _unitId;
  bool _isService = false;
  bool _quickFamily = false;
  bool _inactive = false;
  String? _imagePath;
  bool _panelsVisible = true;
  int _tabIndex = 0;
  bool _saving = false;
  Map<int, String> _customFieldValues = {};
  String _categoryFilter = '';
  List<String> _priceListNames = const [
    'سعر البيع',
    'سعر البيع الثاني',
    'سعر البيع الثالث',
    'سعر البيع الرابع',
  ];

  static const _kTabLabels = [
    'عام',
    'قوائم الأسعار',
    'الكميات الإقتصادية',
    'وحدات الغياس',
    'المزيد',
  ];

  // Google palette with neutral surfaces for clear field and icon contrast.
  static const _bg = Color(0xFFF8F9FA);
  static const _panelHeader = Color(0xFF4285F4);
  static const _panelBody = Color(0xFFFFFFFF);
  static const _panelBorder = Color(0xFFDADCE0);
  static const _primary = Color(0xFF1A73E8);
  static const _ink = Color(0xFF202124);
  static const _mutedInk = Color(0xFF5F6368);

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _sellingPrice = TextEditingController(
      text: p == null ? '' : '${p.sellingPrice}',
    );
    _sellingPrice2 = TextEditingController(
      text: p == null ? '' : '${p.sellingPrice2}',
    );
    _sellingPrice3 = TextEditingController(
      text: p == null ? '' : '${p.sellingPrice3}',
    );
    _sellingPrice4 = TextEditingController(
      text: p == null ? '' : '${p.sellingPrice4}',
    );
    _lastSellingPrice = TextEditingController(
      text: p == null ? '' : '${p.lastSellingPrice}',
    );
    _discountPercent = TextEditingController(
      text: p == null ? '' : '${p.discountPercent}',
    );
    _code1 = TextEditingController(text: p?.productCode ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _code2 = TextEditingController(text: p?.code2 ?? '');
    _otherCodes = TextEditingController(text: p?.otherCodes ?? '');
    _purchasePrice = TextEditingController(
      text: p == null ? '' : '${p.purchasePrice}',
    );
    _reorderPoint = TextEditingController(
      text: p == null ? '' : '${p.reorderPoint}',
    );
    _economicQty = TextEditingController(
      text: p == null ? '' : '${p.economicQty}',
    );
    _minimumStock = TextEditingController(
      text: p == null ? '' : '${p.minimumStock}',
    );
    _currentStock = TextEditingController(
      text: p?.currentStock.toString() ?? '0',
    );
    _lastQty = TextEditingController(text: p == null ? '' : '${p.lastQty}');
    _categoryId = p?.categoryId;
    _unitId = p?.unitId;
    _isService = p?.isService ?? false;
    _quickFamily = p?.quickFamily ?? false;
    _inactive = p == null ? false : !p.isActive;
    _imagePath = p?.imagePath;
    if (p?.id != null) {
      _customFieldValues = DocumentCustomFields.entityValues('product', p!.id!);
    }
    _loadPriceListNames();
    _loadLookups();
  }

  void _loadPriceListNames() {
    final db = DatabaseService().database.db;
    _priceListNames = List.generate(4, (index) {
      final key = 'settings.price_${index + 1}';
      final rows = db.select('SELECT value FROM settings WHERE key=?', [key]);
      final value = rows.isEmpty ? '' : (rows.first['value'] as String).trim();
      return value.isEmpty ? _priceListNames[index] : value;
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _sellingPrice,
      _sellingPrice2,
      _sellingPrice3,
      _sellingPrice4,
      _lastSellingPrice,
      _discountPercent,
      _code1,
      _barcode,
      _code2,
      _otherCodes,
      _purchasePrice,
      _reorderPoint,
      _economicQty,
      _minimumStock,
      _currentStock,
      _lastQty,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    final categories = await _repo.getCategories();
    final units = await _repo.getUnits();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _units = units;
    });
  }

  int _parse(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  // ---------------------------------------------------------------------------
  // Save actions.
  // ---------------------------------------------------------------------------
  ProductEntity? _collect() {
    final name = _name.text.trim();
    final code = _code1.text.trim();
    if (name.isEmpty) {
      _toast('أدخل اسم الصنف.');
      return null;
    }
    if (code.isEmpty) {
      _toast('أدخل كود الصنف من لوحة "أكواد الصنف".');
      return null;
    }
    final p = widget.product;
    return ProductEntity(
      id: p?.id,
      name: name,
      productCode: code,
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      categoryId: _categoryId,
      unitId: _unitId,
      purchasePrice: _parse(_purchasePrice),
      sellingPrice: _parse(_sellingPrice),
      sellingPrice2: _parse(_sellingPrice2),
      sellingPrice3: _parse(_sellingPrice3),
      sellingPrice4: _parse(_sellingPrice4),
      currentStock: _parse(_currentStock),
      minimumStock: _parse(_minimumStock),
      code2: _code2.text.trim().isEmpty ? null : _code2.text.trim(),
      otherCodes: _otherCodes.text.trim().isEmpty
          ? null
          : _otherCodes.text.trim(),
      discountPercent: _parse(_discountPercent),
      lastSellingPrice: _parse(_lastSellingPrice),
      lastQty: _parse(_lastQty),
      reorderPoint: _parse(_reorderPoint),
      economicQty: _parse(_economicQty),
      isService: _isService,
      quickFamily: _quickFamily,
      imagePath: _imagePath,
      isActive: !_inactive,
      createdAt: p?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<bool> _save({bool closeAfter = false, bool newAfter = false}) async {
    if (_saving) return false;
    final product = _collect();
    if (product == null) return false;
    setState(() => _saving = true);

    final notifier = ref.read(productNotifierProvider.notifier);
    try {
      int productId;
      if (product.id == null) {
        productId = await notifier.addProduct(product);
      } else {
        await notifier.updateProduct(product);
        productId = product.id!;
      }
      DocumentCustomFields.saveEntityValues(
        'product',
        productId,
        _customFieldValues,
      );
      if (!mounted) return false;
      if (newAfter) {
        _resetForNew();
        _toast('تم حفظ الصنف — أدخل الصنف الجديد.');
        return true;
      }
      if (closeAfter) {
        Navigator.of(context).pop(true);
        return true;
      }
      _toast('تم حفظ الصنف بنجاح.');
      return true;
    } catch (_) {
      if (mounted) _toast('تعذر حفظ الصنف.');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetForNew() {
    setState(() {
      for (final controller in [
        _name,
        _sellingPrice,
        _sellingPrice2,
        _sellingPrice3,
        _sellingPrice4,
        _lastSellingPrice,
        _discountPercent,
        _code1,
        _barcode,
        _code2,
        _otherCodes,
        _purchasePrice,
        _reorderPoint,
        _economicQty,
        _minimumStock,
        _lastQty,
      ]) {
        controller.clear();
      }
      _currentStock.text = '0';
      _categoryId = null;
      _unitId = null;
      _isService = false;
      _quickFamily = false;
      _inactive = false;
      _imagePath = null;
      _tabIndex = 0;
      _categoryFilter = '';
      _customFieldValues = {};
    });
  }

  Future<void> _editCustomFields() async {
    final values = await showDocumentCustomFieldsDialog(
      context,
      scope: 'product',
      initialValues: _customFieldValues,
    );
    if (values == null || !mounted) return;
    setState(() => _customFieldValues = values);
  }

  // ---------------------------------------------------------------------------
  // Image picking (offline, via the Windows file dialog).
  // ---------------------------------------------------------------------------
  Future<void> _pickImage() async {
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$dlg = New-Object System.Windows.Forms.OpenFileDialog
$dlg.Filter = 'صور|*.png;*.jpg;*.jpeg;*.bmp;*.webp'
if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $dlg.FileName }
''';
    try {
      final result = await Process.run('powershell', [
        '-STA',
        '-NoProfile',
        '-Command',
        script,
      ]);
      final picked = (result.stdout as String).trim();
      if (picked.isEmpty) return;
      final source = File(picked);
      final dir = Directory('database/product_images');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final ext = picked.contains('.')
          ? picked.substring(picked.lastIndexOf('.'))
          : '.png';
      final target =
          '${dir.path}\\img_${DateTime.now().millisecondsSinceEpoch}$ext';
      source.copySync(target);
      if (!mounted) return;
      setState(() => _imagePath = target);
    } catch (_) {
      if (mounted) _toast('تعذر اختيار الصورة.');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Keyboard shortcuts.
  // ---------------------------------------------------------------------------
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;
    final control = HardwareKeyboard.instance.isControlPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;
    if (control) {
      _save(newAfter: true);
    } else if (alt) {
      _save(closeAfter: true);
    } else {
      _save();
    }
    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------------------
  // UI.
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = math.min(
      992.0,
      (viewport.width - 24).clamp(280.0, 992.0).toDouble(),
    );
    final dialogHeight = math.min(
      630.0,
      (viewport.height - 71).clamp(280.0, 630.0).toDouble(),
    );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: withPlainInputs(
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Focus(
            autofocus: true,
            onKeyEvent: _onKey,
            child: Container(
              width: dialogWidth,
              height: dialogHeight,
              decoration: BoxDecoration(
                color: _bg,
                border: Border.all(color: _panelBorder, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCollapseBar(),
                  Expanded(child: _buildMainColumn()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainColumn() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 14, 30, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopSection(),
          const SizedBox(height: 12),
          _buildTabStrip(),
          const SizedBox(height: 4),
          Expanded(child: _buildTabContent()),
          const SizedBox(height: 10),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  // Top: name + prices on the right, photo box on the left.
  Widget _buildTopSection() {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 438,
          child: Column(
            children: [
              _nameField(),
              const SizedBox(height: 14),
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: _labeledField(_priceListNames[0], _sellingPrice),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _labeledField('آخر سعر بيع', _lastSellingPrice),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _labeledField(
                      'نسبة الخصم',
                      _discountPercent,
                      suffix: '%',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        _buildPhotoBox(),
      ],
    );
  }

  Widget _buildPhotoBox() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pickImage,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 124,
          height: 124,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: _panelBorder, width: 1.2),
          ),
          child: _imagePath != null && File(_imagePath!).existsSync()
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                    ),
                    Positioned(
                      left: 3,
                      top: 3,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _imagePath = null),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDE3B32),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                '×',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: CustomPaint(
                    painter: _CameraPainter(color: _primary),
                    size: const Size(54, 44),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _nameField() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextField(
            controller: _name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
            textAlignVertical: TextAlignVertical.center,
            decoration: const InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            ),
          ),
          Container(
            height: 2.5,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            color: _primary,
          ),
        ],
      ),
    );
  }

  Widget _labeledField(
    String label,
    TextEditingController controller, {
    String? suffix,
    Color labelColor = _ink,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: labelColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: _panelBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13.5, color: _ink),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              if (suffix != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    suffix,
                    style: const TextStyle(fontSize: 12.5, color: _mutedInk),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Tab strip with trapezoid tabs.
  Widget _buildTabStrip() {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        for (var i = 0; i < _kTabLabels.length; i++) ...[
          _tab(i),
          const SizedBox(width: 2),
        ],
        const Spacer(),
      ],
    );
  }

  Widget _tab(int index) {
    final active = _tabIndex == index;
    return HoverBuilder(
      builder: (context, hovered) {
        final background = active
            ? const Color(0xFFE8F0FE)
            : (hovered ? kHoverYellow : const Color(0xFFF1F3F4));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _tabIndex = index),
          child: CustomPaint(
            painter: _TabPainter(background: background),
            child: Container(
              width: _tabWidth(_kTabLabels[index]),
              height: 29,
              alignment: Alignment.center,
              child: Text(
                _kTabLabels[index],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: (hovered && !active)
                      ? const Color(0xFF1A1A1A)
                      : (active ? _primary : _mutedInk),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _tabWidth(String label) {
    switch (label) {
      case 'عام':
        return 82;
      case 'الكميات الإقتصادية':
        return 136;
      case 'قوائم الأسعار':
        return 118;
      case 'وحدات الغياس':
        return 114;
      default:
        return 96;
    }
  }

  Widget _buildTabContent() {
    switch (_tabIndex) {
      case 1:
        return _priceListsTab();
      case 2:
        return _economicTab();
      case 3:
        return _unitsTab();
      case 4:
        return _moreTab();
      default:
        return _generalTab();
    }
  }

  Widget _priceListsTab() => _panel(
    title: 'قوائم أسعار البيع',
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('القائمة الأولى: ${_priceListNames[0]} (تُعدّل من إعداد صفو)'),
          const SizedBox(height: 10),
          for (final entry in <(int, TextEditingController)>[
            (1, _sellingPrice2),
            (2, _sellingPrice3),
            (3, _sellingPrice4),
          ]) ...[
            _labeledField(_priceListNames[entry.$1], entry.$2),
            const SizedBox(height: 8),
          ],
          const Text(
            'الأسعار الإضافية مستقلة عن السعر الأول؛ تركها بصفر لا يغيّر السعر الافتراضي.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFFE2F8EB)),
          ),
        ],
      ),
    ),
  );

  // "عام" tab: three panels.
  Widget _generalTab() {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 246, child: _categoriesPanel()),
        if (_panelsVisible) ...[
          const SizedBox(width: 8),
          SizedBox(width: 262, child: _codesPanel()),
          const SizedBox(width: 8),
          Expanded(child: _generalPanel()),
        ],
      ],
    );
  }

  Widget _categoriesPanel() {
    final filtered = _categoryFilter.trim().isEmpty
        ? _categories
        : _categories
              .where(
                (c) => (c['name'] as String? ?? '').toLowerCase().contains(
                  _categoryFilter.trim().toLowerCase(),
                ),
              )
              .toList();
    return _panel(
      title: 'تصنيفات',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: SizedBox(
              height: 30,
              child: Container(
                color: Colors.white,
                child: TextField(
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: (v) => setState(() => _categoryFilter = v),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    hintText: 'التصنيف',
                    hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF8AA591)),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 7,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد تصنيفات',
                      style: TextStyle(fontSize: 12, color: Color(0xFFE2F8EB)),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final category = filtered[index];
                      final id = category['id'] as int;
                      final selected = _categoryId == id;
                      return InkWell(
                        onTap: () =>
                            setState(() => _categoryId = selected ? null : id),
                        child: SizedBox(
                          height: 32,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: [
                                _checkboxGlyph(checked: selected, onGreen: true),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    category['name'] as String? ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _codesPanel() {
    return _panel(
      title: 'أكواد الصنف',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          children: [
            _codeRow('باركود', _barcode, _CodeGlyph.barcode),
            const SizedBox(height: 8),
            _codeRow(
              'كود الصنف 1',
              _code1,
              _CodeGlyph.plus,
              onPlus: () {
                if (_barcode.text.trim().isEmpty) {
                  _barcode.text = _code1.text.trim();
                  _toast('تم نسخ كود الصنف إلى الباركود.');
                }
              },
            ),
            const SizedBox(height: 8),
            _codeRow(
              'كود الصنف 2',
              _code2,
              _CodeGlyph.plus,
              onPlus: () {
                _code2.text = _code1.text.trim();
              },
            ),
            const SizedBox(height: 8),
            _codeRow('أكواد أخرى', _otherCodes, _CodeGlyph.more),
          ],
        ),
      ),
    );
  }

  Widget _generalPanel() {
    return _panel(
      title: 'عام',
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'آخر كمية للصنف',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Container(
                      height: 28,
                      color: Colors.white,
                      child: TextField(
                        controller: _lastQty,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF1A1A1A),
                        ),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: const InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _checkRow(
              'خدمة بدون كمية',
              _isService,
              (v) => setState(() => _isService = v),
            ),
            _checkRow(
              'اضافة لعائلة الأصناف السريعة',
              _quickFamily,
              (v) => setState(() => _quickFamily = v),
            ),
            _checkRow(
              'صنف غير نشط',
              _inactive,
              (v) => setState(() => _inactive = v),
            ),
          ],
        ),
      ),
    );
  }

  // "الكميات الإقتصادية" tab.
  Widget _economicTab() {
    return _panel(
      title: 'الكميات الإقتصادية',
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(child: _labeledField('سعر الشراء', _purchasePrice)),
                const SizedBox(width: 12),
                Expanded(
                  child: _labeledField('الحد الأدنى للمخزون', _minimumStock),
                ),
                const SizedBox(width: 12),
                Expanded(child: _labeledField('حد الطلب', _reorderPoint)),
                const SizedBox(width: 12),
                Expanded(
                  child: _labeledField('الكمية الاقتصادية', _economicQty),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // "وحدات الغياس" tab.
  Widget _unitsTab() {
    return _panel(
      title: 'وحدات الغياس',
      child: _units.isEmpty
          ? const Center(
              child: Text(
                'لا توجد وحدات مسجلة',
                style: TextStyle(fontSize: 12, color: Color(0xFFE2F8EB)),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _units.length,
              itemBuilder: (context, index) {
                final unit = _units[index];
                final id = unit['id'] as int;
                final selected = _unitId == id;
                return InkWell(
                  onTap: () => setState(() => _unitId = selected ? null : id),
                  child: SizedBox(
                    height: 34,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          _checkboxGlyph(checked: selected, onGreen: true),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              unit['name'] as String? ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            unit['abbreviation'] as String? ?? '',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFFE2F8EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // "المزيد" tab.
  Widget _moreTab() {
    return _panel(
      title: 'المزيد',
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(child: _labeledField('الرصيد الحالي', _currentStock)),
            const SizedBox(width: 12),
            Expanded(
              child: _labeledField('الحد الأدنى للمخزون', _minimumStock),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
  }

  Widget _panel({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _panelBody,
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 30,
            decoration: const BoxDecoration(
              color: _panelHeader,
              border: Border(bottom: BorderSide(color: _panelBorder)),
            ),
            alignment: Alignment.center,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _codeRow(
    String label,
    TextEditingController controller,
    _CodeGlyph glyph, {
    VoidCallback? onPlus,
  }) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 28,
            color: Colors.white,
            child: TextField(
              controller: controller,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF1A1A1A),
              ),
              textAlignVertical: TextAlignVertical.center,
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 7,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (onPlus != null) {
                onPlus();
              } else {
                Clipboard.setData(ClipboardData(text: controller.text.trim()));
                _toast('تم نسخ "$label".');
              }
            },
            child: SizedBox(
              width: 20,
              height: 28,
              child: Center(
                child: CustomPaint(
                  painter: _CodeGlyphPainter(type: glyph),
                  size: const Size(14, 14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _checkRow(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: SizedBox(
        height: 32,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              _checkboxGlyph(checked: value, onGreen: true),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12.5, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkboxGlyph({required bool checked, bool onGreen = false}) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        color: checked ? Colors.white : Colors.transparent,
        border: Border.all(
          color: onGreen ? Colors.white : const Color(0xFF7FBF90),
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: checked
          ? const Icon(Icons.check, size: 12, color: Color(0xFF2FB753))
          : null,
    );
  }

  // "»" collapse bar on the right edge.
  Widget _buildCollapseBar() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _panelsVisible = !_panelsVisible),
        child: Container(
          width: 26,
          color: const Color(0xFF2FB753),
          child: Center(
            child: CustomPaint(
              painter: _CollapsePainter(
                expanded: _panelsVisible,
                color: Colors.white,
              ),
              size: const Size(13, 16),
            ),
          ),
        ),
      ),
    );
  }

  // Bottom buttons: حفظ / حفظ جديد / حفظ | تكرار / إلغاء.
  Widget _buildBottomButtons() {
    return LayoutBuilder(
      builder: (context, constraints) => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: math.max(720.0, constraints.maxWidth),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              TextButton.icon(
                onPressed: _saving ? null : _editCustomFields,
                icon: const Icon(Icons.tune, size: 16),
                label: const Text(
                  'حقول إضافية',
                  style: TextStyle(fontSize: 11),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _ink,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    textDirection: TextDirection.rtl,
                    children: [
                      _saveButton(
                        label: 'حفظ',
                        shortcut: 'ENTER',
                        style: _SaveStyle.yellow,
                        glyphKind: _TickKind.check,
                        onTap: _saving ? null : () => _save(),
                      ),
                      const SizedBox(width: 10),
                      _saveButton(
                        label: 'حفظ جديد',
                        shortcut: 'CTRL + ENTER',
                        style: _SaveStyle.white,
                        glyphKind: _TickKind.plus,
                        onTap: _saving ? null : () => _save(newAfter: true),
                      ),
                      const SizedBox(width: 10),
                      _saveButton(
                        label: 'حفظ | تكرار',
                        shortcut: 'ALT + ENTER',
                        style: _SaveStyle.white,
                        glyphKind: _TickKind.plus,
                        onTap: _saving ? null : () => _save(closeAfter: true),
                      ),
                    ],
                  ),
                ),
              ),
              _cancelButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _saveButton({
    required String label,
    required String shortcut,
    required _SaveStyle style,
    required _TickKind glyphKind,
    required VoidCallback? onTap,
  }) {
    final yellow = style == _SaveStyle.yellow;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HoverBuilder(
          cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
          builder: (context, hovered) {
            final background = hovered
                ? kHoverYellow
                : (yellow ? const Color(0xFFFBBC04) : Colors.white);
            final border = hovered
                ? const Color(0xFFF9AB00)
                : (yellow ? const Color(0xFFF9AB00) : _panelBorder);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Opacity(
                opacity: onTap == null ? 0.6 : 1,
                child: Container(
                  width: 132,
                  height: 37,
                  decoration: BoxDecoration(
                    color: background,
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      CustomPaint(
                        painter: _TickPainter(
                          type: glyphKind,
                          color: (yellow || hovered) ? _ink : _primary,
                        ),
                        size: const Size(11, 11),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 3),
        Text(
          shortcut,
          style: const TextStyle(
            fontSize: 10,
            color: _mutedInk,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _cancelButton() {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 152,
          height: 37,
          decoration: BoxDecoration(
            color: hovered ? kHoverYellow : const Color(0xFFF1F3F4),
            border: Border.all(
              color: hovered ? const Color(0xFFC7A62B) : _panelBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CustomPaint(
                painter: _PowerPainter(color: _ink),
                size: Size(12, 12),
              ),
              SizedBox(width: 7),
              Text(
                'إلغاء',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SaveStyle { yellow, white }

enum _TickKind { check, plus }

enum _CodeGlyph { barcode, plus, more }

// -----------------------------------------------------------------------------
// Painters.
// -----------------------------------------------------------------------------
class _CameraPainter extends CustomPainter {
  const _CameraPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.34, 0, w * 0.32, h * 0.22),
        const Radius.circular(2),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.16, w, h * 0.84),
        const Radius.circular(3),
      ),
      paint,
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.58),
      w * 0.185,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.58),
      w * 0.11,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_CameraPainter oldDelegate) => oldDelegate.color != color;
}

/// Slight trapezoid tab shape (slanted sides).
class _TabPainter extends CustomPainter {
  const _TabPainter({required this.background});

  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(3, 0)
      ..lineTo(size.width - 3, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = background);
  }

  @override
  bool shouldRepaint(_TabPainter oldDelegate) =>
      oldDelegate.background != background;
}

/// "»" / "«" glyph for the collapse bar.
class _CollapsePainter extends CustomPainter {
  const _CollapsePainter({required this.expanded, required this.color});

  final bool expanded;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    for (final dx in [0.0, w * 0.45]) {
      final path = Path();
      if (expanded) {
        path
          ..moveTo(dx, h * 0.12)
          ..lineTo(dx + w * 0.4, h * 0.5)
          ..lineTo(dx, h * 0.88);
      } else {
        path
          ..moveTo(dx + w * 0.4, h * 0.12)
          ..lineTo(dx, h * 0.5)
          ..lineTo(dx + w * 0.4, h * 0.88);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CollapsePainter oldDelegate) =>
      oldDelegate.expanded != expanded || oldDelegate.color != color;
}

class _TickPainter extends CustomPainter {
  const _TickPainter({required this.type, required this.color});

  final _TickKind type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (type == _TickKind.check) {
      final path = Path()
        ..moveTo(size.width * 0.08, size.height * 0.55)
        ..lineTo(size.width * 0.38, size.height * 0.88)
        ..lineTo(size.width * 0.95, size.height * 0.12);
      canvas.drawPath(path, paint);
    } else {
      canvas.drawLine(
        Offset(size.width * 0.5, size.height * 0.08),
        Offset(size.width * 0.5, size.height * 0.92),
        paint,
      );
      canvas.drawLine(
        Offset(size.width * 0.08, size.height * 0.5),
        Offset(size.width * 0.92, size.height * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}

class _CodeGlyphPainter extends CustomPainter {
  const _CodeGlyphPainter({required this.type, required this.color});

  final _CodeGlyph type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    switch (type) {
      case _CodeGlyph.barcode:
        final widths = [1.2, 2.0, 1.0, 2.4, 1.2, 2.8, 1.0, 1.8];
        var x = 1.0;
        for (var i = 0; i < widths.length; i++) {
          canvas.drawRect(
            Rect.fromLTWH(x, h * 0.12, widths[i], h * 0.76),
            paint,
          );
          x += widths[i] + 1.4;
        }
        break;
      case _CodeGlyph.plus:
        canvas.drawLine(
          Offset(w * 0.5, h * 0.1),
          Offset(w * 0.5, h * 0.9),
          stroke,
        );
        canvas.drawLine(
          Offset(w * 0.1, h * 0.5),
          Offset(w * 0.9, h * 0.5),
          stroke,
        );
        break;
      case _CodeGlyph.more:
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(w * (0.15 + i * 0.35), h * 0.5),
            w * 0.09,
            paint,
          );
        }
        break;
    }
  }

  @override
  bool shouldRepaint(_CodeGlyphPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}

class _PowerPainter extends CustomPainter {
  const _PowerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromLTWH(1, 2, size.width - 2, size.height - 2);
    canvas.drawArc(rect, -1.2, 4.2, false, paint);
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height * 0.45),
      paint,
    );
  }

  @override
  bool shouldRepaint(_PowerPainter oldDelegate) => oldDelegate.color != color;
}
