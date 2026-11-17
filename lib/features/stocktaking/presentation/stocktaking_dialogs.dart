part of 'stocktaking_page.dart';

/// Warehouse selector shown by the green bar in the top block.
class _WarehousePickerDialog extends StatelessWidget {
  const _WarehousePickerDialog({
    required this.warehouses,
    required this.selectedId,
  });

  final List<StocktakingWarehouse> warehouses;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    return ShopDialogFrame(
      title: 'اختيار المخزن',
      width: 420,
      actions: [
        shopDialogButton(
          label: 'إغلاق',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: SizedBox(
        height: 300,
        child: warehouses.isEmpty
            ? const Center(
                child: Text(
                  'لا توجد مخازن مسجلة.',
                  style: TextStyle(fontSize: 12.5, color: _kInk),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCCCCCC)),
                ),
                child: ListView.builder(
                  itemExtent: 32,
                  itemCount: warehouses.length,
                  itemBuilder: (context, index) {
                    final warehouse = warehouses[index];
                    final active = warehouse.id == selectedId;
                    return HoverBuilder(
                      builder: (context, hovered) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(warehouse),
                        child: Container(
                          color: hovered
                              ? kHoverYellow
                              : (active
                                    ? _kRowSelected
                                    : (index.isEven
                                          ? Colors.white
                                          : const Color(0xFFF2F2F2))),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              const Icon(
                                Icons.warehouse_outlined,
                                size: 17,
                                color: Color(0xFF336641),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  warehouse.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: _kInk,
                                  ),
                                ),
                              ),
                              if (active)
                                const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Color(0xFF2E7D43),
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
    );
  }
}

/// Small subscription / licensing dialog opened from the yellow license bar.
class _SubscriptionDialog extends StatelessWidget {
  const _SubscriptionDialog();

  @override
  Widget build(BuildContext context) {
    return ShopDialogFrame(
      title: 'اشتراك صفو',
      width: 430,
      actions: [
        shopDialogButton(
          label: 'إغلاق',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Text(
            'هذه نسخة غير مرخصة للتجربة فقط.',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'للحصول على نسخة مرخصة ودعم فني وتحديثات، تواصل مع فريق صفو '
            'عبر بيانات الاتصال الموجودة في شاشة «حول البرنامج».',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 12.5, height: 1.6, color: _kInk),
          ),
          SizedBox(height: 12),
          Text(
            'نسبة الإستخدام الحالية: 0%',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 12, color: Color(0xFF555555)),
          ),
        ],
      ),
    );
  }
}
