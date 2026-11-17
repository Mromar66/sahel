import 'package:flutter/material.dart';

import 'package:inventory_app/app/theme/shop_colors.dart';
import 'package:inventory_app/app/widgets/hover_widgets.dart';

/// Left command rail shared by شراء and جرد مخزن.
class ShopCommandRail extends StatelessWidget {
  const ShopCommandRail({
    super.key,
    required this.onQty,
    required this.onPrice,
    required this.onMore,
    required this.onDelete,
    required this.onDown,
    required this.onUp,
  });

  final VoidCallback onQty;
  final VoidCallback onPrice;
  final VoidCallback onMore;
  final VoidCallback onDelete;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _railTile('الكمية', 'F5', Icons.shopping_basket_outlined, onQty),
        const SizedBox(height: 6),
        _railTile('السعر', 'F6', Icons.sell_outlined, onPrice),
        const SizedBox(height: 6),
        _railTile('المزيد', 'F7', Icons.percent, onMore),
        const SizedBox(height: 6),
        _railTile('حذف', 'F8', null, onDelete, deleteStyle: true),
        const SizedBox(height: 6),
        SizedBox(
          height: 28,
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              Expanded(
                child: _arrowTile(Icons.keyboard_arrow_down, 'الأسفل', onDown),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _arrowTile(Icons.keyboard_arrow_up, 'الأعلى', onUp),
              ),
            ],
          ),
        ),
      ],
    );
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
          color: hovered ? kHoverYellow : ShopColors.soft,
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
                style: const TextStyle(fontSize: 10.5, color: ShopColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrowTile(IconData icon, String tip, VoidCallback onTap) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: hovered ? kHoverYellow : ShopColors.soft,
          child: Icon(icon, size: 20, color: const Color(0xFF111111)),
        ),
      ),
    );
  }
}
