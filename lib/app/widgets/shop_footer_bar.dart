import 'package:flutter/material.dart';

import 'package:safwa/app/theme/shop_colors.dart';
import 'package:safwa/app/widgets/barcode_glyph.dart';
import 'package:safwa/app/widgets/hover_widgets.dart';

/// Callbacks for every button of the document footer bar. Both شراء and
/// جرد مخزن pass their own handlers; the visuals stay identical.
class ShopFooterActions {
  const ShopFooterActions({
    required this.onSave,
    required this.onNew,
    required this.onPrint,
    required this.onExport,
    required this.onShare,
    required this.onDeleteDocument,
    required this.onEditPrices,
    required this.onPrintBarcode,
    required this.onSettings,
    required this.onClose,
    required this.onShortcuts,
    required this.onClear,
    this.clearLabel = 'مسح الفاتورة',
    this.deleteLabel = 'حذف الفاتورة',
    this.printMenuLabel = 'طباعة الفاتورة',
    this.shareMenuLabel = 'نسخ نص الفاتورة',
  });

  final VoidCallback onSave;
  final VoidCallback onNew;
  final VoidCallback onPrint;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onDeleteDocument;
  final VoidCallback onEditPrices;
  final VoidCallback onPrintBarcode;
  final VoidCallback onSettings;
  final VoidCallback onClose;
  final VoidCallback onShortcuts;
  final VoidCallback onClear;
  final String clearLabel;
  final String deleteLabel;
  final String printMenuLabel;
  final String shareMenuLabel;
}

/// Dark 48px footer with the shortcut-labelled buttons from the reference.
class ShopFooterBar extends StatelessWidget {
  const ShopFooterBar({super.key, required this.actions});

  final ShopFooterActions actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: ShopColors.footer,
      padding: const EdgeInsets.only(top: 6, bottom: 7, right: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 1008,
          height: 35,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              _footerButton(
                label: 'F9 حفظ',
                icon: Icons.check,
                iconColor: ShopColors.footerBlue,
                iconSize: 27,
                width: 96,
                onTap: actions.onSave,
              ),
              const SizedBox(width: 6),
              _footerButton(
                label: 'F10 جديد',
                icon: Icons.add,
                iconColor: ShopColors.footerBlue,
                iconSize: 27,
                width: 96,
                onTap: actions.onNew,
              ),
              const SizedBox(width: 6),
              _footerButton(
                label: 'F4 طباعة',
                icon: Icons.print,
                width: 96,
                onTap: actions.onPrint,
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
                width: 36,
                onTap: actions.onExport,
              ),
              const SizedBox(width: 6),
              _footerIcon(
                child: const Icon(
                  Icons.share,
                  size: 19,
                  color: ShopColors.footerBlue,
                ),
                width: 36,
                onTap: actions.onShare,
              ),
              const SizedBox(width: 6),
              _footerButton(
                label: actions.deleteLabel,
                icon: Icons.close,
                iconColor: const Color(0xFFFA6352),
                iconSize: 24,
                width: 100,
                onTap: actions.onDeleteDocument,
              ),
              const SizedBox(width: 6),
              _footerButton(
                label: 'تعديل الأسعار',
                icon: Icons.sell,
                width: 104,
                yellow: true,
                onTap: actions.onEditPrices,
              ),
              const SizedBox(width: 6),
              _footerBarcodeCell(onTap: actions.onPrintBarcode),
              const Expanded(child: SizedBox()),
              _footerMenu(actions),
              _footerClippedCell(
                width: 86,
                yellow: true,
                label: 'إعدادات',
                onTap: actions.onSettings,
              ),
              const SizedBox(width: 6),
              _footerButton(
                label: 'إغلاق',
                icon: Icons.power_settings_new,
                width: 86,
                onTap: actions.onClose,
              ),
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
          color: hovered
              ? kHoverYellow
              : (yellow ? ShopColors.yellow : ShopColors.soft),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.rtl,
            children: [
              if (icon != null) ...[
                Icon(icon, size: iconSize, color: iconColor ?? ShopColors.ink),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: const TextStyle(fontSize: 12, color: ShopColors.ink),
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
          color: hovered ? kHoverYellow : ShopColors.soft,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

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
          color: hovered
              ? kHoverYellow
              : (yellow ? ShopColors.yellow : ShopColors.soft),
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: ShopColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _footerMenu(ShopFooterActions actions) {
    return PopupMenuButton<String>(
      tooltip: '',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      color: Colors.white,
      constraints: const BoxConstraints(minWidth: 168, maxWidth: 240),
      onSelected: (value) {
        switch (value) {
          case 'print':
            actions.onPrint();
          case 'excel':
            actions.onExport();
          case 'share':
            actions.onShare();
          case 'clear':
            actions.onClear();
          case 'shortcuts':
            actions.onShortcuts();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'print',
          height: 34,
          child: Text(
            actions.printMenuLabel,
            style: const TextStyle(fontSize: 12, color: ShopColors.ink),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'excel',
          height: 34,
          child: Text(
            'تصدير Excel',
            style: TextStyle(fontSize: 12, color: ShopColors.ink),
          ),
        ),
        PopupMenuItem<String>(
          value: 'share',
          height: 34,
          child: Text(
            actions.shareMenuLabel,
            style: const TextStyle(fontSize: 12, color: ShopColors.ink),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'shortcuts',
          height: 34,
          child: Text(
            'الاختصارات',
            style: TextStyle(fontSize: 12, color: ShopColors.ink),
          ),
        ),
        PopupMenuItem<String>(
          value: 'clear',
          height: 34,
          child: Text(
            actions.clearLabel,
            style: const TextStyle(fontSize: 12, color: ShopColors.ink),
          ),
        ),
      ],
      child: const SizedBox(
        width: 36,
        height: 35,
        child: ColoredBox(
          color: ShopColors.soft,
          child: Icon(Icons.more_horiz, size: 20, color: ShopColors.ink),
        ),
      ),
    );
  }

  Widget _footerBarcodeCell({required VoidCallback onTap}) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 106,
          height: 35,
          color: hovered ? kHoverYellow : ShopColors.yellow,
          child: Row(
            textDirection: TextDirection.rtl,
            children: const [
              SizedBox(width: 4),
              Expanded(
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OverflowBox(
                      alignment: Alignment.centerRight,
                      minWidth: 0,
                      maxWidth: 200,
                      child: Text(
                        'طباعة الباركود',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(fontSize: 12, color: ShopColors.ink),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 4),
              BarcodeGlyph(),
              SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
