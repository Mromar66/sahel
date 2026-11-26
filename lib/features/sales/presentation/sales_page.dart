import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safwa/app/shell/app_top_bar.dart';
import 'package:safwa/app/widgets/hover_widgets.dart';
import 'package:safwa/features/products/data/product_repository.dart';
import 'package:safwa/features/products/domain/product_entity.dart';

/// Point-of-sale «بيع» page — pixel replica of the reference sales screen.
class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

const Color _kYellow = Color(0xFFF7D244);
const Color _kGreen = Color(0xFF8DCDE2);
const Color _kPanelGreen = Color(0xFF43B5DB);
const Color _kSellGreen = Color(0xFF43B5DB);
const Color _kBlue = Color(0xFF0059E8);
const Color _kRed = Color(0xFFD8432E);
const Color _kHeader = Color(0xFFDDDDDD);
const Color _kSoft = Color(0xFFE8E8E8);
const Color _kField = Color(0xFFF0F0F0);
const Color _kFooter = Color(0xFF3C3C3C);
const Color _kFooterBlue = Color(0xFF2171F1);
const Color _kInk = Color(0xFF1A1A1A);
const Color _kFocusBlue = Color(0xFF004AC0);
const Color _kLine = Color(0xFFEAEAEA);
const Color _kBoxLine = Color(0xFFC0C0C0);

class _SaleLine {
  _SaleLine({
    required this.code,
    required this.name,
    required this.unit,
    required this.available,
    required this.qty,
    required this.price,
  });

  final String code;
  final String name;
  final String unit;
  final int available;
  final int qty;
  final int price;

  int get total => qty * price;
}

class _SalesPageState extends State<SalesPage> {
  final TextEditingController _invoiceNo = TextEditingController(text: '1');
  final TextEditingController _date = TextEditingController();
  final TextEditingController _time = TextEditingController();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _account = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _addQty = TextEditingController(text: '1');
  final TextEditingController _addVal = TextEditingController();
  final TextEditingController _addPct = TextEditingController();
  final TextEditingController _discVal = TextEditingController();
  final TextEditingController _discPct = TextEditingController();

  final List<_SaleLine> _lines = <_SaleLine>[];
  int _selectedLine = -1;
  int _payTab = 0;
  String _treasury = 'درج النقدية';
  String _priceKind = 'سعر البيع';
  String _addKind = '';

  List<ProductEntity> _catalog = const [];
  Map<int, String> _units = const {};

  static const List<String> _payTabs = [
    'درج النقدية',
    'بطاقة إئتمان',
    'الخزينة',
    'آجل',
  ];

  /// Caret column / رقم الصنف / اسم الصنف / وحدة / المتاح / الكمية / السعر /
  /// الإجمالي / الهامش الأيسر — matching the reference column widths.
  static const List<int> _colFlex = [80, 250, 80, 80, 80, 80, 100, 16];
  static const List<String> _colLabels = [
    'رقم الصنف',
    'اسم الصنف',
    'وحدة',
    'المتاح',
    'الكمية',
    'السعر',
    'الإجمالي',
    '',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date.text = _fmtDate(now);
    _time.text = _fmtTime(now);
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final repo = ProductRepository();
      final products = await repo.getAllProducts();
      final units = await repo.getUnits();
      if (!mounted) return;
      setState(() {
        _catalog = products;
        _units = {
          for (final u in units)
            (u['id'] as num).toInt(): (u['name'] as String? ?? ''),
        };
      });
    } catch (_) {
      // The replica still works with free-text lines if the DB is unavailable.
    }
  }

  @override
  void dispose() {
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

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _fmtTime(DateTime d) {
    final h = (d.hour % 12 == 0 ? 12 : d.hour % 12).toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
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

  void _close() {
    removeCurrentAppTab(context);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _resetInvoice() {
    setState(() {
      _search.clear();
      _account.clear();
      _notes.clear();
      _addVal.clear();
      _addPct.clear();
      _discVal.clear();
      _discPct.clear();
      _lines.clear();
      _selectedLine = -1;
      _invoiceNo.text = '1';
      final now = DateTime.now();
      _date.text = _fmtDate(now);
      _time.text = _fmtTime(now);
    });
    _toast('تم تجهيز فاتورة بيع جديدة.');
  }

  ProductEntity? _findProduct(String text) {
    final key = text.trim();
    if (key.isEmpty) return null;
    for (final p in _catalog) {
      if (p.barcode == key || p.productCode == key) return p;
    }
    for (final p in _catalog) {
      if (p.name.contains(key)) return p;
    }
    return null;
  }

  void _addLine() {
    final text = _search.text.trim();
    if (text.isEmpty) {
      _toast('اكتب اسم الصنف أو الكود أولاً ثم اضغط أضف.');
      return;
    }
    final product = _findProduct(text);
    final qty = int.tryParse(_addQty.text.trim()) ?? 1;
    setState(() {
      _lines.add(
        _SaleLine(
          code: product?.productCode.isNotEmpty == true
              ? product!.productCode
              : '${_lines.length + 1}',
          name: product?.name ?? text,
          unit:
              _units[product?.unitId] ??
              (product?.isService == true ? 'خدمة' : 'حبة'),
          available: product?.currentStock ?? 0,
          qty: qty <= 0 ? 1 : qty,
          price: product?.sellingPrice ?? 0,
        ),
      );
      _selectedLine = _lines.length - 1;
      _search.clear();
    });
  }

  int get _qtyTotal => _lines.fold<int>(0, (s, l) => s + l.qty);
  int get _grandTotal => _lines.fold<int>(0, (s, l) => s + l.total);

  @override
  Widget build(BuildContext context) {
    return withPlainInputs(_buildShell());
  }

  Widget _buildShell() {
    return AppShell(
      activeTab: AppTab.products,
      extraTabLabel: 'بيع | جديد',
      extraTabColor: _kSellGreen,
      extraTabTextColor: _kInk,
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
          _buildUsageBar(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main content.
  // ---------------------------------------------------------------------------
  Widget _buildMain() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: SizedBox(width: 860, height: 136, child: _buildTopBlock()),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                const designWidth = 766.0;
                if (c.maxWidth >= designWidth - 0.5) {
                  return _buildTableArea();
                }
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topRight,
                  child: SizedBox(
                    width: designWidth,
                    height: 673,
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

  Widget _buildTopBlock() {
    return SizedBox(
      height: 136,
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildControls()),
          const SizedBox(width: 1),
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: SizedBox(
              width: 186,
              height: 127,
              child: _buildInvoicePanel(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Green invoice panel — رقم / التاريخ / الوقت / الإجمالي.
  // ---------------------------------------------------------------------------
  Widget _buildInvoicePanel() {
    return Container(
      color: _kPanelGreen,
      child: Column(
        children: [
          const SizedBox(height: 3),
          SizedBox(
            height: 19,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'رقم',
                        style: const TextStyle(fontSize: 12, color: _kInk),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 113,
                  color: _kGreen,
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _invoiceNo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _kInk,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 23,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(child: _dateField()),
                  const SizedBox(width: 3),
                  SizedBox(width: 76, child: _timeField()),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '$_grandTotal',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _kInk,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _borderField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF8D8D8D)),
      ),
      child: child,
    );
  }

  Widget _dateField() {
    return _borderField(
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Expanded(
            child: TextField(
              controller: _date,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 12, color: _kInk),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(left: 3, top: 4),
              ),
            ),
          ),
          const SizedBox(
            width: 16,
            child: Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeField() {
    return _borderField(
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Expanded(
            child: TextField(
              controller: _time,
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 11.5, color: _kInk),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(left: 2, top: 4),
              ),
            ),
          ),
          SizedBox(
            width: 13,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.arrow_drop_up, size: 9, color: Color(0xFF555555)),
                Icon(Icons.arrow_drop_down, size: 9, color: Color(0xFF555555)),
              ],
            ),
          ),
          const SizedBox(width: 1),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search / quick buttons / payment rows.
  // ---------------------------------------------------------------------------
  Widget _buildControls() {
    return Column(
      children: [
        SizedBox(
          height: 37,
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _searchField()),
              const SizedBox(width: 6),
              _blankBox(55, _kField, () => _toast('تصنيف الأصناف.')),
              const SizedBox(width: 6),
              _blankBox(55, _kYellow, () => _toast('قائمة سريعة.')),
              const SizedBox(width: 6),
              _inquiryButton(),
              const SizedBox(width: 6),
              _chipButton(
                width: 87,
                chip: '2',
                label: 'الكمية',
                onTap: () => _toast('أدخل الكمية في مربع الكمية أسفل الشاشة.'),
              ),
              const SizedBox(width: 6),
              _chipButton(
                width: 117,
                chip: '3',
                label: 'سعر البيع',
                onTap: () => _toast('أدخل سعر البيع للصنف.'),
              ),
              const SizedBox(width: 6),
              _chipButton(width: 71, chip: '4', label: 'أضف', onTap: _addLine),
            ],
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 37,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: HoverBuilder(
                  builder: (context, hovered) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toast('اختيار الحساب.'),
                    child: Container(
                      height: 37,
                      color: hovered ? const Color(0xFFE85B45) : _kRed,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 8),
                      child: TextField(
                        controller: _account,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              _greenBox(77, '1'),
              const SizedBox(width: 7),
              _greenBox(107, '0'),
              const SizedBox(width: 9),
              _checkTile(),
            ],
          ),
        ),
        SizedBox(
          height: 2,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 1),
                  color: _kFocusBlue,
                ),
              ),
              SizedBox(
                width: 275,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(height: 1, color: const Color(0xFF838383)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 58,
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildFieldsColumn()),
              const SizedBox(width: 7),
              _paymentTabs(),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _pinButton(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldsColumn() {
    return Column(
      children: [
        const SizedBox(height: 6),
        SizedBox(
          height: 21,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              _rowLabel('الحساب', 70),
              const SizedBox(width: 6),
              Expanded(child: _softField(21, bordered: true)),
              const SizedBox(width: 6),
              _softField(21, width: 30),
              const SizedBox(width: 6),
              _softField(21, width: 68),
              const SizedBox(width: 6),
              _softField(21, width: 68),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 23,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              _rowLabel('ملاحظات', 70),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _kField,
                    border: Border.all(color: const Color(0xFFB8B8B8)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: TextField(
                    controller: _notes,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: _kInk),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchField() {
    return Container(
      height: 27,
      color: Colors.white,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          HoverBuilder(
            builder: (context, hovered) => Container(
              width: 23,
              color: hovered ? kHoverYellow : _kYellow,
              alignment: Alignment.center,
              child: const Text(
                '1',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kInk,
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _search,
              textAlign: TextAlign.right,
              onSubmitted: (_) => _addLine(),
              style: const TextStyle(fontSize: 12, color: _kInk),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                hintText: 'ابحث عن الصنف',
                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF555555)),
                contentPadding: EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inquiryButton() {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toast('استعلام عن الصنف: ${_search.text}'),
        child: Container(
          width: 78,
          height: 27,
          color: hovered ? kHoverYellow : _kYellow,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              const SizedBox(width: 2),
              Container(
                width: 19,
                height: 19,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '؟',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              const Expanded(
                child: Text(
                  'استعلام',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: _kInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blankBox(double width, Color color, VoidCallback onTap) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: 27,
          color: hovered ? kHoverYellow : color,
        ),
      ),
    );
  }

  Widget _chipButton({
    required double width,
    required String chip,
    required String label,
    required VoidCallback onTap,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: 27,
          color: hovered ? kHoverYellow : Colors.white,
          padding: const EdgeInsets.only(right: 2),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 23,
                height: 25,
                color: _kYellow,
                alignment: Alignment.center,
                child: Text(
                  chip,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: _kInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkTile() {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toast('تأكيد الدفع.'),
        child: Container(
          width: 65,
          height: 37,
          color: hovered ? kHoverYellow : _kYellow,
          alignment: Alignment.center,
          child: const Icon(Icons.check, size: 28, color: Color(0xFF43B5DB)),
        ),
      ),
    );
  }

  Widget _greenBox(double width, String value) {
    return Container(
      width: width,
      height: 37,
      color: _kGreen,
      alignment: Alignment.center,
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w600,
          color: _kInk,
        ),
      ),
    );
  }

  Widget _rowLabel(String text, double width) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(text, style: const TextStyle(fontSize: 12, color: _kInk)),
      ),
    );
  }

  Widget _softField(double height, {double? width, bool bordered = false}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _kField,
        border: bordered ? Border.all(color: const Color(0xFFB8B8B8)) : null,
      ),
    );
  }

  Widget _paymentTabs() {
    return Column(
      children: [
        const SizedBox(height: 6),
        SizedBox(
          height: 52,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              for (var i = 0; i < _payTabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 1),
                HoverBuilder(
                  builder: (context, hovered) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _payTab = i),
                    child: Container(
                      width: 61,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _payTab == i
                            ? _kBlue
                            : (hovered ? kHoverYellow : _kSoft),
                        border: const Border(
                          bottom: BorderSide(color: _kBlue, width: 2),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _payTabs[i],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: _kInk),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _pinButton() {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toast('تثبيت شريط الدفع.'),
        child: Container(
          width: 20,
          height: 20,
          color: hovered ? kHoverYellow : _kSoft,
          child: const Icon(Icons.push_pin, size: 13, color: Color(0xFF111111)),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Table + left command rail.
  // ---------------------------------------------------------------------------
  Widget _buildTableArea() {
    return Row(
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(width: 8),
        SizedBox(width: 62, child: _buildRail()),
        const SizedBox(width: 8),
        Expanded(
          // 6px breathing room above the green totals bar, as in the reference.
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              children: [
                Expanded(
                  flex: 182,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _kLine),
                    ),
                    child: Column(
                      children: [
                        _buildTableHeader(),
                        _buildActiveBand(),
                        Expanded(child: _buildTableBody()),
                        _buildTotalsRow(),
                        _buildScrollStrip(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(flex: 135, child: _buildAllBox()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return SizedBox(
      height: 24,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: _kHeader)),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: Color(0xFF555555),
            ),
          ),
          for (var i = 0; i < _colLabels.length; i++)
            Expanded(
              flex: _colFlex[i],
              child: Container(
                decoration: const BoxDecoration(
                  color: _kHeader,
                  border: Border(left: BorderSide(color: Colors.white)),
                ),
                alignment: Alignment.center,
                child: i == _colLabels.length - 1
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 2,
                          height: 12,
                          color: const Color(0xFF2B374A),
                        ),
                      )
                    : Text(
                        _colLabels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: _kInk),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveBand() {
    return SizedBox(
      height: 27,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: _kHeader)),
            ),
            alignment: Alignment.center,
            child: const SizedBox.shrink(),
          ),
          for (var i = 0; i < _colLabels.length; i++)
            Expanded(
              flex: _colFlex[i],
              child: Container(
                decoration: const BoxDecoration(
                  color: _kGreen,
                  border: Border(left: BorderSide(color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableBody() {
    if (_lines.isEmpty) {
      return Container(
        color: Colors.white,
        child: Stack(
          children: [
            _bodyGrid(),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFDFDFDF)),
                  ),
                  child: const Text(
                    'ابدأ بالبحث عن صنف بالإسم أو بالكود',
                    style: TextStyle(fontSize: 15, color: Color(0xFF8A8A8A)),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      color: Colors.white,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _lines.length,
        itemBuilder: (context, index) => _lineRow(_lines[index], index),
      ),
    );
  }

  /// Vertical column separators shown behind the empty-state hint.
  Widget _bodyGrid() {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Container(
          width: 22,
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: _kHeader)),
          ),
        ),
        for (var i = 0; i < _colLabels.length; i++)
          Expanded(
            flex: _colFlex[i],
            child: Container(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFFE8E8E8))),
              ),
            ),
          ),
      ],
    );
  }

  Widget _lineRow(_SaleLine line, int index) {
    final selected = index == _selectedLine;
    final cells = <String>[
      line.code,
      line.name,
      line.unit,
      '${line.available}',
      '${line.qty}',
      '${line.price}',
      '${line.total}',
      '',
    ];
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedLine = index),
        child: Container(
          height: 24,
          color: selected
              ? const Color(0xFFD9E8EC)
              : (hovered ? const Color(0xFFF7F9FA) : Colors.white),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 22,
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Color(0xFFE6E6E6))),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 11, color: _kInk),
                ),
              ),
              for (var i = 0; i < _colFlex.length; i++)
                Expanded(
                  flex: _colFlex[i],
                  child: Container(
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Color(0xFFE6E6E6)),
                      ),
                    ),
                    child: Text(
                      cells[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: _kInk),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalsRow() {
    final hasLines = _lines.isNotEmpty;
    final totals = <String>[
      '',
      '',
      '',
      '',
      hasLines ? '$_qtyTotal' : '',
      '',
      hasLines ? '$_grandTotal' : '',
      '',
    ];
    return SizedBox(
      height: 27,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: _kHeader)),
            ),
          ),
          for (var i = 0; i < _colFlex.length; i++)
            Expanded(
              flex: _colFlex[i],
              child: Container(
                decoration: const BoxDecoration(
                  color: _kHeader,
                  border: Border(left: BorderSide(color: Colors.white)),
                ),
                alignment: Alignment.center,
                child: Text(
                  totals[i],
                  style: const TextStyle(fontSize: 11.5, color: _kInk),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScrollStrip() {
    return SizedBox(
      height: 18,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: _kField,
              alignment: Alignment.bottomCenter,
              child: Container(height: 1, color: const Color(0xFF838383)),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned(
                    left: constraints.maxWidth * 0.17,
                    right: 24,
                    top: 7,
                    child: Container(height: 2, color: const Color(0xFF858585)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllBox() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: _kBoxLine)),
      child: Stack(
        children: [
          Positioned(
            top: 6,
            right: 0,
            child: HoverBuilder(
              builder: (context, hovered) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedLine = -1),
                child: Container(
                  width: 159,
                  height: 26,
                  color: hovered ? kHoverYellow : _kBlue,
                  alignment: Alignment.center,
                  child: const Text(
                    'الكل',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _railTile(
          'الكمية',
          'F5',
          Icons.shopping_basket_outlined,
          () => _toast('تعديل كمية السطر المحدد.'),
        ),
        const SizedBox(height: 6),
        _railTile(
          'السعر',
          'F6',
          Icons.sell_outlined,
          () => _toast('تعديل سعر السطر المحدد.'),
        ),
        const SizedBox(height: 6),
        _railTile(
          'المزيد',
          'F7',
          Icons.percent,
          () => _toast('خيارات إضافية للسطر.'),
        ),
        const SizedBox(height: 6),
        _railTile('حذف', 'F8', null, _removeSelected, deleteStyle: true),
        const SizedBox(height: 6),
        SizedBox(
          height: 28,
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              Expanded(child: _arrowTile(Icons.keyboard_arrow_down, 'الأسفل')),
              const SizedBox(width: 6),
              Expanded(child: _arrowTile(Icons.keyboard_arrow_up, 'الأعلى')),
            ],
          ),
        ),
      ],
    );
  }

  void _removeSelected() {
    if (_selectedLine < 0 || _selectedLine >= _lines.length) {
      _toast('حدد سطراً من الجدول أولاً.');
      return;
    }
    setState(() {
      _lines.removeAt(_selectedLine);
      _selectedLine = -1;
    });
    _toast('تم حذف السطر.');
  }

  Widget _railTile(
    String label,
    String key,
    IconData? icon,
    VoidCallback onTap, {
    bool deleteStyle = false,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 59,
          color: hovered ? kHoverYellow : _kSoft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (deleteStyle)
                Container(width: 20, height: 5, color: const Color(0xFFFF6B5E))
              else
                Icon(icon, size: 20, color: const Color(0xFF111111)),
              const SizedBox(height: 5),
              Text(
                '$key $label',
                style: const TextStyle(fontSize: 10.5, color: _kInk),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrowTile(IconData icon, String tip) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toast('تحريك التحديد $tip.'),
        child: Container(
          color: hovered ? kHoverYellow : _kSoft,
          child: Icon(icon, size: 20, color: const Color(0xFF111111)),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Green totals bar (full width, above the footer).
  // ---------------------------------------------------------------------------
  static const double _barLabelH = 23;
  static const double _barGapH = 4;
  static const double _barControlH = 23;
  static const TextStyle _barLabelStyle = TextStyle(fontSize: 12, color: _kInk);

  Widget _buildTotalsBar() {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: _kGreen,
        border: Border(
          top: BorderSide(color: _kPanelGreen, width: 5),
          bottom: BorderSide(color: _kPanelGreen, width: 5),
          right: BorderSide(color: _kPanelGreen, width: 5),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 1018,
          height: 70,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              _barPinnedGroup(
                label: 'الخزينة',
                child: _barDropdown(
                  width: 96,
                  value: _treasury,
                  items: const ['درج النقدية', 'البنك', 'الشيكات'],
                  onChanged: (v) => setState(() => _treasury = v),
                  boxedCaret: true,
                ),
              ),
              _barDivider(),
              _barPinnedGroup(
                label: 'سعر البيع',
                child: _barDropdown(
                  width: 96,
                  value: _priceKind,
                  items: const ['سعر البيع', 'سعر الجملة', 'سعر التكلفة'],
                  onChanged: (v) => setState(() => _priceKind = v),
                ),
              ),
              _barDivider(),
              _barAddSection(),
              _barDivider(),
              _barDiscountSection(),
              const SizedBox(width: 4),
              _barFekkaButton(),
              const SizedBox(width: 4),
              Expanded(child: Container(color: _kPanelGreen)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barDivider() {
    return Container(width: 5, color: _kPanelGreen);
  }

  Widget _barPercent() {
    return const SizedBox(
      width: 20,
      child: Center(
        child: Text('%', style: TextStyle(fontSize: 11.5, color: _kInk)),
      ),
    );
  }

  Widget _barPinnedGroup({required String label, required Widget child}) {
    return SizedBox(
      width: 110,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: _barLabelH,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.right,
                      style: _barLabelStyle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  HoverBuilder(
                    builder: (context, hovered) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _toast('تثبيت $label.'),
                      child: Container(
                        width: 23,
                        height: 23,
                        color: hovered ? kHoverYellow : Colors.white,
                        alignment: Alignment.center,
                        child: Transform.rotate(
                          angle: 0.785,
                          child: const Icon(
                            Icons.push_pin,
                            size: 14,
                            color: Color(0xFF111111),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _barGapH),
            child,
          ],
        ),
      ),
    );
  }

  /// إضافة + نوع الإضافة block (fixed width so it lands where the reference
  /// places the fields).
  Widget _barAddSection() {
    return SizedBox(
      width: 256,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: _barLabelH,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  SizedBox(
                    width: 137,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Text('إضافة', style: _barLabelStyle),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text('نوع الإضافة', style: _barLabelStyle),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _barGapH),
            SizedBox(
              height: _barControlH,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  _barField(_addPct, 40),
                  _barPercent(),
                  _barField(_addVal, 73),
                  const SizedBox(width: 4),
                  _barTypeDropdown(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barDiscountSection() {
    return SizedBox(
      width: 137,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: _barLabelH,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 7),
                child: Text('خصم', style: _barLabelStyle),
              ),
            ),
          ),
          const SizedBox(height: _barGapH),
          SizedBox(
            height: _barControlH,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                const SizedBox(width: 4),
                _barField(_discPct, 40),
                _barPercent(),
                _barField(_discVal, 73),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barFekkaButton() {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toast('خصم الفكة.'),
        child: Container(
          width: 55,
          height: 50,
          color: hovered ? kHoverYellow : _kSoft,
          alignment: Alignment.center,
          child: const Text(
            'خصم الفكة',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: _kInk, height: 1.3),
          ),
        ),
      ),
    );
  }

  Widget _barTypeDropdown() {
    return Container(
      width: 109,
      height: _barControlH,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF8D8D8D)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _addKind.isEmpty ? null : _addKind,
                isExpanded: true,
                isDense: true,
                hint: const SizedBox.shrink(),
                icon: const SizedBox.shrink(),
                dropdownColor: Colors.white,
                padding: const EdgeInsets.only(right: 6),
                style: const TextStyle(fontSize: 12, color: _kInk),
                items: const ['نسبة', 'مبلغ']
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            e,
                            style: const TextStyle(fontSize: 12, color: _kInk),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _addKind = v);
                },
              ),
            ),
          ),
          const SizedBox(
            width: 16,
            child: Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barDropdown({
    required double width,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    bool boxedCaret = false,
  }) {
    return Container(
      width: width,
      height: _barControlH,
      decoration: const BoxDecoration(
        color: Color(0xFFFDFDFD),
        border: Border(
          top: BorderSide(color: Color(0xFFD2D2D2)),
          bottom: BorderSide(color: Color(0xFFBCBCBC)),
          left: BorderSide(color: Color(0xFFD2D2D2)),
          right: BorderSide(color: Color(0xFFD2D2D2)),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                isDense: true,
                icon: const SizedBox.shrink(),
                dropdownColor: Colors.white,
                alignment: AlignmentDirectional.centerEnd,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                style: const TextStyle(fontSize: 12, color: _kInk),
                items: items
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            e,
                            style: const TextStyle(fontSize: 12, color: _kInk),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
          Container(
            width: 16,
            height: _barControlH,
            decoration: boxedCaret
                ? const BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFD2D2D2))),
                  )
                : null,
            child: const Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barField(TextEditingController controller, double width) {
    return Container(
      width: width,
      height: _barControlH,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFECECEC)),
          bottom: BorderSide(color: Color(0xFF838383)),
          left: BorderSide(color: Color(0xFFE0E0E0)),
          right: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 11.5, color: _kInk),
        decoration: const InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Right brand strip.
  // ---------------------------------------------------------------------------
  Widget _buildRightStrip() {
    return Container(
      width: 136,
      color: _kField,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          Container(
            height: 119,
            width: 120,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/icons/safwa_logo.png',
              width: 120,
              height: 119,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                color: const Color(0xFF43B5DB),
                child: const Icon(
                  Icons.shopping_cart,
                  size: 62,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          HoverBuilder(
            builder: (context, hovered) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toast('أنت الآن في شاشة البيع.'),
              child: Container(
                width: 120,
                height: 60,
                color: hovered ? kHoverYellow : _kSellGreen,
                alignment: Alignment.center,
                child: Text(
                  'بيع',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: hovered ? _kInk : Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 120,
            height: 29,
            color: _kSoft,
            child: Row(
              children: [
                Expanded(
                  child: _stripIcon(
                    Icons.keyboard_double_arrow_right,
                    () => _toast('توسيع النافذة.'),
                  ),
                ),
                Container(width: 2, color: Colors.white),
                Expanded(
                  child: _stripIcon(
                    Icons.keyboard_double_arrow_left,
                    () => _toast('تصغير النافذة.'),
                  ),
                ),
                Container(width: 2, color: Colors.white),
                Expanded(
                  child: _stripIconText(
                    'K',
                    () => _toast('اختصارات لوحة المفاتيح.'),
                  ),
                ),
                Container(width: 2, color: Colors.white),
                Expanded(
                  child: _stripIcon(Icons.search, () => _toast('بحث سريع.')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          HoverBuilder(
            builder: (context, hovered) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _saveInvoice,
              child: Container(
                width: 120,
                height: 115,
                color: hovered ? const Color(0xFFFFD65C) : _kYellow,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(
                      height: 48,
                      child: OverflowBox(
                        maxHeight: 91,
                        child: Icon(
                          Icons.check,
                          size: 91,
                          color: Color(0xFF2F76E8),
                        ),
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'حفظ | جديد',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: _kInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'F12',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: _kInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: HoverBuilder(
              builder: (context, hovered) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toast('سداد الفاتورة (F11).'),
                child: Container(
                  width: 120,
                  color: hovered ? kHoverYellow : _kSoft,
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      const Icon(
                        Icons.account_balance_wallet,
                        size: 44,
                        color: Color(0xFF111111),
                      ),
                      const Text(
                        'سداد F11',
                        style: TextStyle(fontSize: 11.5, color: _kInk),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: const Alignment(0.35, 0),
                        child: Container(
                          width: 33,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF2B2B2B),
                              width: 2,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsets.only(left: 2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2B2B2B),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(height: 1, color: _kField),
        ],
      ),
    );
  }

  Widget _stripIcon(IconData icon, VoidCallback onTap) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: hovered ? kHoverYellow : Colors.transparent,
          child: Icon(icon, size: 17, color: const Color(0xFF222222)),
        ),
      ),
    );
  }

  Widget _stripIconText(String text, VoidCallback onTap) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: hovered ? kHoverYellow : Colors.transparent,
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF222222),
            ),
          ),
        ),
      ),
    );
  }

  void _saveInvoice() {
    if (_lines.isEmpty) {
      _toast('أضف صنفاً واحداً على الأقل قبل الحفظ.');
      return;
    }
    _toast('تم حفظ فاتورة البيع بإجمالي $_grandTotal.');
  }

  // ---------------------------------------------------------------------------
  // Footer.
  // ---------------------------------------------------------------------------
  Widget _buildFooter() {
    return Container(
      height: 48,
      color: _kFooter,
      padding: const EdgeInsets.only(top: 6, bottom: 7, right: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 1018,
          height: 48,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              _footerButton(
                label: 'F9 حفظ',
                icon: Icons.check,
                iconColor: _kFooterBlue,
                iconSize: 27,
                width: 113,
                onTap: _saveInvoice,
              ),
              const SizedBox(width: 6),
              _footerButton(
                label: 'F10 جديد',
                icon: Icons.add,
                iconColor: _kFooterBlue,
                iconSize: 27,
                width: 113,
                onTap: _resetInvoice,
              ),
              const SizedBox(width: 6),
              _footerButton(
                label: 'F4 طباعة',
                icon: Icons.print,
                width: 113,
                onTap: () => _toast('طباعة الفاتورة (F4).'),
              ),
              const SizedBox(width: 6),
              _footerIcon(
                child: Container(
                  width: 16,
                  height: 16,
                  color: const Color(0xFF248EB2),
                  alignment: Alignment.center,
                  child: const Text(
                    'x',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                width: 44,
                onTap: () => _toast('تصدير إلى ملف Excel.'),
              ),
              const SizedBox(width: 6),
              _footerIcon(
                child: const Icon(Icons.share, size: 19, color: _kFooterBlue),
                width: 44,
                onTap: () => _toast('مشاركة الفاتورة.'),
              ),
              const SizedBox(width: 6),
              _footerButton(
                label: 'حذف الفاتورة',
                icon: Icons.close,
                iconColor: const Color(0xFFFA6352),
                iconSize: 24,
                width: 113,
                onTap: _resetInvoice,
              ),
              const SizedBox(width: 6),
              _footerButton(
                label: 'تعديل الأسعار',
                icon: Icons.sell,
                width: 118,
                yellow: true,
                onTap: () => _toast('تعديل أسعار الأصناف.'),
              ),
              const SizedBox(width: 6),
              _footerBarcodeCell(),
              _footerClippedCell(
                width: 43,
                onTap: () => _toast('خيارات إضافية.'),
                child: const Icon(Icons.more_horiz, size: 20, color: _kInk),
              ),
              _footerClippedCell(
                width: 32,
                yellow: true,
                label: 'الأصناف',
                onTap: () => _toast('الأصناف.'),
              ),
              _footerClippedCell(
                width: 43,
                onTap: () => _toast('إعدادات العملة.'),
                child: const Icon(
                  Icons.monetization_on_outlined,
                  size: 20,
                  color: _kInk,
                ),
              ),
              _footerClippedCell(
                width: 31,
                yellow: true,
                label: 'إعدادات',
                onTap: () => _toast('إعدادات شاشة البيع.'),
              ),
              const SizedBox(width: 6),
              _footerButton(
                label: 'إغلاق',
                icon: Icons.power_settings_new,
                width: 100,
                onTap: _close,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerButton({
    required String label,
    required VoidCallback onTap,
    required double width,
    IconData? icon,
    Color? iconColor,
    double iconSize = 18,
    bool yellow = false,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: 35,
          color: hovered ? kHoverYellow : (yellow ? _kYellow : _kSoft),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.rtl,
            children: [
              if (icon != null) ...[
                Icon(icon, size: iconSize, color: iconColor ?? _kInk),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: const TextStyle(fontSize: 12, color: _kInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerIcon({
    required Widget child,
    required VoidCallback onTap,
    required double width,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: 35,
          color: hovered ? kHoverYellow : _kSoft,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  /// Footer cell whose content is wider than the cell: the label keeps its
  /// right-aligned start and is clipped on the left, exactly as in the
  /// reference build.
  Widget _footerClippedCell({
    required double width,
    required VoidCallback onTap,
    String? label,
    Widget? child,
    bool yellow = false,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: 35,
          color: hovered ? kHoverYellow : (yellow ? _kYellow : _kSoft),
          alignment: Alignment.center,
          child:
              child ??
              ClipRect(
                child: Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OverflowBox(
                      alignment: Alignment.centerRight,
                      minWidth: 0,
                      maxWidth: 260,
                      child: Text(
                        label ?? '',
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(fontSize: 12, color: _kInk),
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }

  /// «باركود» cell: clipped label on the right, barcode glyph on the left.
  Widget _footerBarcodeCell() {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toast('طباعة الباركود.'),
        child: Container(
          width: 49,
          height: 35,
          color: hovered ? kHoverYellow : _kYellow,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              const Expanded(
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OverflowBox(
                      alignment: Alignment.centerRight,
                      minWidth: 0,
                      maxWidth: 200,
                      child: Text(
                        'باركود',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(fontSize: 12, color: _kInk),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              const _BarcodeGlyph(),
              const SizedBox(width: 3),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Yellow usage bar (reference status strip).
  // ---------------------------------------------------------------------------
  Widget _buildUsageBar() {
    return Container(
      height: 30,
      color: _kYellow,
      padding: const EdgeInsets.only(left: 8, right: 13),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          const Expanded(
            child: Text(
              'هذه نسخة تجريبية غير مرخصة. للتعرّف على برنامج Safwa ومدى ملاءمته لمشروعك، ستتوقف بعد فترة من الاستخدام.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: _kInk),
            ),
          ),
          const SizedBox(width: 21),
          Container(
            width: 104,
            height: 20,
            color: _kSoft,
            alignment: Alignment.center,
            child: const Text(
              'اشتراكى',
              style: TextStyle(fontSize: 11.5, color: _kInk),
            ),
          ),
          const SizedBox(width: 91),
          const SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'نسبة الإستخدام',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(fontSize: 12, color: _kInk),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1A1A1A)),
            ),
            alignment: Alignment.center,
            child: const Text(
              '0%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small black barcode glyph used by the footer «باركود» button.
class _BarcodeGlyph extends StatelessWidget {
  const _BarcodeGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _BarcodePainter()),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1A1A1A);
    const bars = <double>[1, 2, 1, 2, 1, 1, 2];
    var x = 0.0;
    for (final w in bars) {
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += w + 1;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
