import 'package:flutter/material.dart';

import 'package:safwa/app/models/product_search_item.dart';
import 'package:safwa/app/theme/shop_colors.dart';
import 'package:safwa/app/widgets/barcode_glyph.dart';
import 'package:safwa/app/widgets/hover_widgets.dart';
import 'package:safwa/app/widgets/shop_dialog_kit.dart';
import 'package:safwa/features/accounts/presentation/print_preview_dialog.dart';

// -----------------------------------------------------------------------------
// Quick product list / category list.
// -----------------------------------------------------------------------------
class QuickProductDialog<T extends ProductSearchItem> extends StatefulWidget {
  const QuickProductDialog({
    super.key,
    required this.title,
    required this.loader,
  });

  final String title;
  final Future<List<T>> Function() loader;

  @override
  State<QuickProductDialog<T>> createState() => _QuickProductDialogState<T>();
}

class _QuickProductDialogState<T extends ProductSearchItem>
    extends State<QuickProductDialog<T>> {
  final _query = TextEditingController();
  late Future<List<T>> _future;
  List<T> _all = const [];

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShopDialogFrame(
      title: widget.title,
      width: 520,
      actions: [
        shopDialogButton(
          label: 'إغلاق',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: SizedBox(
        height: 400,
        child: FutureBuilder<List<T>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'تعذر تحميل الأصناف: ${snapshot.error}',
                  style: const TextStyle(fontSize: 12.5, color: ShopColors.ink),
                ),
              );
            }
            _all = snapshot.data ?? const [];
            final key = _query.text.trim().toLowerCase();
            final visible = key.isEmpty
                ? _all
                : _all
                      .where(
                        (p) =>
                            p.name.toLowerCase().contains(key) ||
                            p.code.toLowerCase().contains(key),
                      )
                      .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                shopTextBox(_query),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCCCCCC)),
                    ),
                    child: visible.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد أصناف مطابقة.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: ShopColors.ink,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemExtent: 29,
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final product = visible[index];
                              return HoverBuilder(
                                builder: (context, hovered) => GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      Navigator.of(context).pop(product),
                                  child: Container(
                                    color: hovered
                                        ? kHoverYellow
                                        : (index.isEven
                                              ? Colors.white
                                              : const Color(0xFFF2F2F2)),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        SizedBox(
                                          width: 68,
                                          child: Text(
                                            product.code,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: Color(0xFF666666),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            product.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: ShopColors.ink,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${product.purchasePrice}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF43B5DB),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'متاح ${product.available}',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: Color(0xFF777777),
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CategoryPickerDialog extends StatelessWidget {
  const CategoryPickerDialog({super.key, required this.categories});

  final List<Map<String, Object?>> categories;

  @override
  Widget build(BuildContext context) {
    return ShopDialogFrame(
      title: 'أقسام الأصناف',
      width: 380,
      actions: [
        shopDialogButton(
          label: 'إغلاق',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: SizedBox(
        height: 330,
        child: ListView.builder(
          itemExtent: 32,
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return HoverBuilder(
              builder: (context, hovered) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(category),
                child: Container(
                  color: hovered
                      ? kHoverYellow
                      : (index.isEven ? Colors.white : const Color(0xFFF2F2F2)),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '${category['name'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: ShopColors.ink,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Line options (F7).
// -----------------------------------------------------------------------------
class LineOption {
  const LineOption({
    required this.key,
    required this.label,
    this.danger = false,
  });

  final String key;
  final String label;
  final bool danger;
}

class LineOptionsDialog extends StatelessWidget {
  const LineOptionsDialog({super.key, required this.options});

  final List<LineOption> options;

  @override
  Widget build(BuildContext context) {
    return ShopDialogFrame(
      title: 'خيارات السطر',
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: HoverBuilder(
                builder: (context, hovered) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(option.key),
                  child: Container(
                    height: 32,
                    color: hovered
                        ? kHoverYellow
                        : (option.danger
                              ? const Color(0xFFFFE3DF)
                              : const Color(0xFFF2F2F2)),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: option.danger
                            ? const Color(0xFFB3261E)
                            : ShopColors.ink,
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
}

// -----------------------------------------------------------------------------
// Bulk price editor.
// -----------------------------------------------------------------------------
class BulkPriceItem {
  const BulkPriceItem({required this.name, required this.price});

  final String name;
  final int price;
}

class BulkPriceDialog extends StatefulWidget {
  const BulkPriceDialog({
    super.key,
    required this.items,
    this.title = 'تعديل الأسعار',
  });

  final List<BulkPriceItem> items;
  final String title;

  @override
  State<BulkPriceDialog> createState() => _BulkPriceDialogState();
}

class _BulkPriceDialogState extends State<BulkPriceDialog> {
  late final List<TextEditingController> _controllers = widget.items
      .map((item) => TextEditingController(text: '${item.price}'))
      .toList();

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final prices = <int, int>{};
    for (var i = 0; i < _controllers.length; i++) {
      final value = int.tryParse(_controllers[i].text.trim());
      if (value == null || value < 0) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تحقق من الأسعار: يجب أن تكون أرقاماً غير سالبة.',
              style: TextStyle(fontSize: 12.5),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      prices[i] = value;
    }
    Navigator.of(context).pop(prices);
  }

  @override
  Widget build(BuildContext context) {
    return ShopDialogFrame(
      title: widget.title,
      width: 480,
      actions: [
        shopDialogButton(label: 'تطبيق', primary: true, onTap: _submit),
        shopDialogButton(
          label: 'إلغاء',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: SizedBox(
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              textDirection: TextDirection.rtl,
              children: const [
                SizedBox(
                  width: 34,
                  child: Text(
                    '#',
                    style: TextStyle(fontSize: 11, color: Color(0xFF666666)),
                  ),
                ),
                Expanded(
                  child: Text(
                    'الصنف',
                    style: TextStyle(fontSize: 11, color: Color(0xFF666666)),
                  ),
                ),
                SizedBox(
                  width: 84,
                  child: Text(
                    'السعر',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF666666)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                itemExtent: 34,
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ShopColors.ink,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 84,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: shopTextBox(
                            _controllers[index],
                            align: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Settings (delete confirmation + rounding).
// -----------------------------------------------------------------------------
class ShopSettings {
  const ShopSettings({required this.confirmDelete, required this.roundStep});

  final bool confirmDelete;
  final int roundStep;
}

class ShopSettingsDialog extends StatefulWidget {
  const ShopSettingsDialog({
    super.key,
    required this.title,
    required this.confirmDelete,
    required this.roundStep,
    this.showRoundStep = true,
  });

  final String title;
  final bool confirmDelete;
  final int roundStep;
  final bool showRoundStep;

  @override
  State<ShopSettingsDialog> createState() => _ShopSettingsDialogState();
}

class _ShopSettingsDialogState extends State<ShopSettingsDialog> {
  late bool _confirmDelete = widget.confirmDelete;
  late int _roundStep = widget.roundStep;

  @override
  Widget build(BuildContext context) {
    return ShopDialogFrame(
      title: widget.title,
      width: 380,
      actions: [
        shopDialogButton(
          label: 'حفظ',
          primary: true,
          onTap: () => Navigator.of(context).pop(
            ShopSettings(confirmDelete: _confirmDelete, roundStep: _roundStep),
          ),
        ),
        shopDialogButton(
          label: 'إلغاء',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HoverBuilder(
            builder: (context, hovered) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _confirmDelete = !_confirmDelete),
              child: Container(
                height: 34,
                color: hovered ? kHoverYellow : const Color(0xFFF6F6F6),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Icon(
                      _confirmDelete
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: ShopColors.ink,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'تأكيد قبل حذف السطر أو المستند',
                        style: TextStyle(fontSize: 12.5, color: ShopColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.showRoundStep) ...[
            const SizedBox(height: 12),
            shopFieldLabel('تقريب خصم الفكة'),
            Container(
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFB8B8B8)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _roundStep,
                  isExpanded: true,
                  isDense: true,
                  dropdownColor: Colors.white,
                  style: const TextStyle(fontSize: 12.5, color: ShopColors.ink),
                  items: const [1, 5, 10, 25]
                      .map(
                        (step) => DropdownMenuItem<int>(
                          value: step,
                          child: Text(
                            'أقرب $step',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: ShopColors.ink,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _roundStep = value);
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Keyboard shortcuts reference.
// -----------------------------------------------------------------------------
class ShopShortcutsDialog extends StatelessWidget {
  const ShopShortcutsDialog({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return ShopDialogFrame(
      title: title,
      width: 380,
      actions: [
        shopDialogButton(
          label: 'إغلاق',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: SizedBox(
        height: 390,
        child: ListView.builder(
          itemExtent: 30,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              color: index.isEven ? Colors.white : const Color(0xFFF4F4F4),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 54,
                    height: 21,
                    color: ShopColors.yellow,
                    alignment: Alignment.center,
                    child: Text(
                      item.$1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ShopColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: ShopColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Product inquiry.
// -----------------------------------------------------------------------------
class InquiryDialog<T extends ProductSearchItem> extends StatelessWidget {
  const InquiryDialog({super.key, required this.product});

  final T product;

  @override
  Widget build(BuildContext context) {
    return ShopDialogFrame(
      title: 'استعلام عن صنف',
      width: 400,
      actions: [
        shopDialogButton(
          label: 'إغلاق',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoRow('الصنف', product.name),
          _infoRow('رقم الصنف', product.code),
          _infoRow('الباركود', product.barcode ?? '—'),
          _infoRow('الوحدة', product.unitName),
          _infoRow('المتاح', '${product.available}'),
          _infoRow('سعر الشراء', '${product.purchasePrice}'),
          _infoRow('سعر البيع', '${product.sellingPrice}'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDEDED))),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: ShopColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Barcode labels.
// -----------------------------------------------------------------------------
class BarcodeLabel {
  const BarcodeLabel({
    required this.code,
    required this.name,
    required this.price,
  });

  final String code;
  final String name;
  final int price;
}

class BarcodeLabelsDialog extends StatelessWidget {
  const BarcodeLabelsDialog({
    super.key,
    required this.title,
    required this.labels,
  });

  final String title;
  final List<BarcodeLabel> labels;

  void _print(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => PrintPreviewDialog(
        title: 'باركود $title',
        columns: const ['الصنف', 'رقم الصنف', 'الباركود'],
        rows: labels.map((l) => [l.name, l.code, l.code]).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShopDialogFrame(
      title: 'طباعة الباركود',
      width: 480,
      actions: [
        shopDialogButton(
          label: 'طباعة',
          primary: true,
          onTap: () => _print(context),
        ),
        shopDialogButton(
          label: 'إغلاق',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: SizedBox(
        height: 380,
        child: ListView.builder(
          itemExtent: 62,
          itemCount: labels.length,
          itemBuilder: (context, index) {
            final label = labels[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFDDDDDD)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: ShopColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            const BarcodeGlyph(width: 96, height: 20),
                            const SizedBox(width: 6),
                            Text(
                              label.code,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF555555),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${label.price}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ShopColors.ink,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
