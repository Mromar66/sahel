import 'package:flutter/material.dart';

/// The yellow used across the app for hover highlights.
const Color kHoverYellow = Color(0xFFFBBC04);

/// A borderless, unfilled input theme for the white fields used in the
/// reference screens. The legacy dark theme otherwise paints its own grey
/// outline *inside* every field, which looked like stray white/grey lines.
InputDecorationTheme get plainInputTheme => const InputDecorationTheme(
  filled: false,
  fillColor: Colors.transparent,
  isDense: true,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
);

/// Wraps [child] with [plainInputTheme] while keeping every other theme value.
Widget withPlainInputs(Widget child) {
  return Builder(
    builder: (context) => Theme(
      data: Theme.of(context).copyWith(inputDecorationTheme: plainInputTheme),
      child: child,
    ),
  );
}

/// Builder-based hover helper: rebuilds its child when the pointer enters or
/// leaves the widget.
class HoverBuilder extends StatefulWidget {
  const HoverBuilder({
    super.key,
    required this.builder,
    this.cursor = SystemMouseCursors.click,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final MouseCursor cursor;

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;

  void _set(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => _set(true),
      onExit: (_) => _set(false),
      child: widget.builder(context, _hovered),
    );
  }
}

/// Sprite image button (full button bitmap) that turns yellow on hover.
///
/// The yellow state uses a pre-rendered `*_hover.png` twin of the sprite: the
/// light background pixels are replaced with yellow while the dark caption and
/// icon keep their colours — matching the reference program's hover look
/// without any blend-mode layers (which paint unreliably with Impeller).
class HoverAssetButton extends StatefulWidget {
  const HoverAssetButton({
    super.key,
    required this.asset,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String asset;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  State<HoverAssetButton> createState() => _HoverAssetButtonState();
}

class _HoverAssetButtonState extends State<HoverAssetButton> {
  String get _assetName => widget.asset.split('/').last.toLowerCase();

  IconData get _fallbackIcon {
    final name = _assetName;
    if (name.contains('cancel') || name.contains('delete')) return Icons.close;
    if (name.contains('refresh')) return Icons.refresh;
    if (name.contains('search')) return Icons.search;
    if (name.contains('more')) return Icons.more_horiz;
    if (name.contains('new')) return Icons.add;
    if (name.contains('edit')) return Icons.edit_outlined;
    if (name.contains('print') || name.contains('printer')) return Icons.print;
    if (name.contains('share')) return Icons.share_outlined;
    if (name.contains('report_move')) return Icons.timeline_outlined;
    if (name.contains('report_wh')) return Icons.warehouse_outlined;
    if (name.contains('report_note')) return Icons.description_outlined;
    if (name.contains('doc')) return Icons.description_outlined;
    if (name.contains('prices')) return Icons.sell_outlined;
    if (name.contains('labels')) return Icons.qr_code_2;
    if (name.contains('perm')) return Icons.lock_outline;
    if (name.contains('serial')) return Icons.qr_code_2;
    if (name.contains('move')) return Icons.swap_horiz;
    return Icons.image_not_supported_outlined;
  }

  String get _fallbackTooltip {
    final name = _assetName;
    if (name.contains('cancel')) return 'إغلاق';
    if (name.contains('power')) return 'إغلاق';
    if (name.contains('refresh')) return 'تحديث';
    if (name.contains('search')) return 'بحث';
    if (name.contains('more')) return 'المزيد';
    if (name.contains('new')) return 'جديد';
    if (name.contains('edit')) return 'تعديل';
    if (name.contains('delete')) return 'حذف';
    if (name.contains('print')) return 'طباعة';
    if (name.contains('share')) return 'مشاركة';
    if (name.contains('report_move') || name.contains('half_move')) {
      return 'تقرير الحركة';
    }
    if (name.contains('report_wh')) return 'تقرير المخزن';
    if (name.contains('prices')) return 'الأسعار';
    if (name.contains('labels')) return 'ملصقات الباركود';
    if (name.contains('perm')) return 'الصلاحيات';
    if (name.contains('serial')) return 'الرقم المسلسل';
    if (name.contains('doc')) return 'عرض المستند';
    if (name.contains('title_goods')) return 'البضاعة';
    return 'فتح';
  }

  String get _hoverAsset {
    final dot = widget.asset.lastIndexOf('.png');
    if (dot < 0) return widget.asset;
    return '${widget.asset.substring(0, dot)}_hover.png';
  }

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovered) => Semantics(
        button: true,
        label: _fallbackTooltip,
        onTap: widget.onTap,
        excludeSemantics: true,
        child: Tooltip(
          message: _fallbackTooltip,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              mouseCursor: SystemMouseCursors.click,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: Image.asset(
                hovered ? _hoverAsset : widget.asset,
                width: widget.width,
                height: widget.height,
                filterQuality: FilterQuality.none,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: widget.width,
                  height: widget.height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hovered ? kHoverYellow : const Color(0xFFE7E7E7),
                    border: Border.all(color: const Color(0xFFB8B8B8)),
                  ),
                  child: widget.width < 62
                      ? Icon(
                          _fallbackIcon,
                          size: widget.height < 36 ? 17 : 21,
                          color: const Color(0xFF383838),
                        )
                      : widget.height < 36
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _fallbackIcon,
                              size: 15,
                              color: const Color(0xFF383838),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _fallbackTooltip,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF222222),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _fallbackIcon,
                              size: 23,
                              color: const Color(0xFF383838),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _fallbackTooltip,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF222222),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
