import 'package:flutter/material.dart';

import 'package:safwa/app/theme/shop_colors.dart';
import 'package:safwa/app/widgets/hover_widgets.dart';

/// Light dialog frame shared by the شراء and جرد مخزن screens. The app theme is
/// dark, so dialogs opt out explicitly instead of inheriting the dark surface.
class ShopDialogFrame extends StatelessWidget {
  const ShopDialogFrame({
    super.key,
    required this.title,
    required this.child,
    this.width = 430,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final double width;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 30,
                color: const Color(0xFFEFEFEF),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ShopColors.ink,
                        ),
                      ),
                    ),
                    HoverBuilder(
                      builder: (context, hovered) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 24,
                          height: 24,
                          color: hovered ? kHoverYellow : Colors.transparent,
                          child: const Icon(
                            Icons.close,
                            size: 15,
                            color: ShopColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: withPlainInputs(child),
                ),
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        actions[i],
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget shopDialogButton({
  required String label,
  required VoidCallback onTap,
  bool primary = false,
  Color? color,
}) {
  return HoverBuilder(
    builder: (context, hovered) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 30,
        constraints: const BoxConstraints(minWidth: 88),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        color: hovered
            ? kHoverYellow
            : (color ?? (primary ? ShopColors.green : const Color(0xFFE8E8E8))),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: ShopColors.ink),
        ),
      ),
    ),
  );
}

Widget shopFieldLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 4),
  child: Text(
    text,
    style: const TextStyle(fontSize: 12, color: ShopColors.ink),
  ),
);

Widget shopTextBox(
  TextEditingController controller, {
  TextAlign align = TextAlign.right,
  bool readOnly = false,
}) {
  return Container(
    height: 28,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFB8B8B8)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.centerRight,
    child: TextField(
      controller: controller,
      readOnly: readOnly,
      textAlign: align,
      style: const TextStyle(fontSize: 12.5, color: ShopColors.ink),
      decoration: const InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 6),
      ),
    ),
  );
}

/// Small white/red confirmation dialog reused by both document screens.
Future<bool> showShopConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  String cancelLabel = 'إلغاء',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Directionality(
        textDirection: TextDirection.rtl,
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
                    color: ShopColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 12.5, color: ShopColors.ink),
                ),
                const SizedBox(height: 16),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    _confirmButton(
                      label: confirmLabel,
                      color: ShopColors.red,
                      textColor: Colors.white,
                      onTap: () => Navigator.of(ctx).pop(true),
                    ),
                    const SizedBox(width: 8),
                    _confirmButton(
                      label: cancelLabel,
                      color: ShopColors.soft,
                      textColor: ShopColors.ink,
                      onTap: () => Navigator.of(ctx).pop(false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}

Widget _confirmButton({
  required String label,
  required Color color,
  required Color textColor,
  required VoidCallback onTap,
}) {
  return HoverBuilder(
    builder: (context, hovered) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 92,
        height: 30,
        color: hovered ? kHoverYellow : color,
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 12.5, color: textColor)),
      ),
    ),
  );
}
