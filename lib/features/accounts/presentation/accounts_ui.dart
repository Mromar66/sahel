import 'package:flutter/material.dart';

import 'package:inventory_app/app/widgets/hover_widgets.dart';

// Reference palette for the accounts screens.
const Color kAcctGreen = Color(0xFF3CCB62);
const Color kAcctGreenText = Color(0xFF31BB56);
const Color kAcctPanelHeader = Color(0xFF2FB753);
const Color kAcctPanelBody = Color(0xFF35C25B);
const Color kAcctPanelBorder = Color(0xFF9FE3B1);
const Color kAcctTableGreen = Color(0xFF30D25B);
const Color kAcctTile = Color(0xFFF0F0F0);
const Color kAcctBorder = Color(0xFFC0C0C0);
const Color kAcctText = Color(0xFF1A1A1A);

/// Green page title, e.g. "الحسابات" / "كشف حساب".
class AcctTitle extends StatelessWidget {
  const AcctTitle(this.text, {super.key, this.fontSize = 26});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: kAcctGreenText,
        height: 1.1,
      ),
    );
  }
}

/// Gray command tile with an optional icon (delivered as a widget) and a
/// caption. Turns yellow on hover.
class AcctTile extends StatelessWidget {
  const AcctTile({
    super.key,
    required this.label,
    this.width = 270,
    this.height = 36,
    this.onTap,
    this.icon,
    this.iconAtEnd = false,
    this.fontSize = 13,
    this.maxLines = 1,
    this.enabled = true,
    this.textColor,
  });

  final String label;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final Widget? icon;
  final bool iconAtEnd;
  final double fontSize;
  final int maxLines;
  final bool enabled;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    return HoverBuilder(
      cursor: active ? SystemMouseCursors.click : MouseCursor.defer,
      builder: (context, hovered) {
        final hot = hovered && active;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: active ? onTap : null,
          child: Container(
            width: width,
            height: height,
            color: hot ? kHoverYellow : kAcctTile,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
                      color: !enabled
                          ? const Color(0xFF9A9A9A)
                          : (textColor ?? kAcctText),
                      height: 1.2,
                    ),
                  ),
                ),
                if (icon != null) ...[const SizedBox(width: 6), icon!],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The green "$" quick-action tile (صرف / قبض).
class AcctMoneyTile extends StatelessWidget {
  const AcctMoneyTile({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 132,
    this.height = 73,
  });

  final String label;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          color: hovered ? kHoverYellow : kAcctTile,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _MoneyGlyph(),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 12.5, color: kAcctText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneyGlyph extends StatelessWidget {
  const _MoneyGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        color: Color(0xFF2FBF55),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        '\$',
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

/// Square checkbox with a caption used in the filter bar.
class AcctCheckRow extends StatelessWidget {
  const AcctCheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.fontSize = 12.5,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFF8A8A8A)),
              ),
              child: value
                  ? const Icon(Icons.check, size: 11, color: Color(0xFF2B2B2B))
                  : null,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: fontSize, color: kAcctText),
            ),
          ],
        ),
      ),
    );
  }
}

/// Labeled white input used across the filter bars and forms.
class AcctField extends StatelessWidget {
  const AcctField({
    super.key,
    this.label,
    required this.controller,
    this.width = 200,
    this.height = 26,
    this.hint,
    this.numeric = false,
    this.readOnly = false,
    this.onTap,
    this.suffix,
    this.fontSize = 12.5,
    this.textAlign = TextAlign.right,
    this.autofocus = false,
    this.onChanged,
    this.underline = false,
  });

  final String? label;
  final TextEditingController controller;
  final double width;
  final double height;
  final String? hint;
  final bool numeric;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;
  final double fontSize;
  final TextAlign textAlign;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final field = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: underline ? null : Border.all(color: const Color(0xFFBFBFBF)),
      ),
      child: Row(
        children: [
          if (suffix != null) ...[suffix!, const SizedBox(width: 2)],
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              autofocus: autofocus,
              onTap: onTap,
              onChanged: onChanged,
              keyboardType: numeric ? TextInputType.number : null,
              textAlign: textAlign,
              style: TextStyle(fontSize: fontSize, color: kAcctText),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 6,
                ),
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9A9A9A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            label!,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF333333)),
          ),
        ),
        field,
      ],
    );
  }
}

/// Small white combo box with a "▼" glyph, matching the reference filters.
class AcctDropdown extends StatelessWidget {
  const AcctDropdown({
    super.key,
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 112,
    this.height = 26,
    this.hint,
    this.fontSize = 12,
  });

  final String? label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final double width;
  final double height;
  final String? hint;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFBFBFBF)),
      ),
      padding: const EdgeInsets.only(right: 3),
      child: Row(
        children: [
          const Icon(Icons.arrow_drop_down, size: 17, color: Color(0xFF555555)),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value != null && items.contains(value) ? value : null,
                isExpanded: true,
                isDense: true,
                icon: const SizedBox.shrink(),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(2),
                hint: hint == null
                    ? null
                    : Text(
                        hint!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF9A9A9A),
                        ),
                      ),
                style: TextStyle(fontSize: fontSize, color: kAcctText),
                items: items
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(
                          item,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: fontSize,
                            color: kAcctText,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
    if (label == null) return box;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            label!,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF333333)),
          ),
        ),
        box,
      ],
    );
  }
}

/// The yellow "عرض التقرير" style button.
class AcctYellowButton extends StatelessWidget {
  const AcctYellowButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 140,
    this.height = 32,
    this.icon = Icons.search,
  });

  final String label;
  final VoidCallback onTap;
  final double width;
  final double height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          color: hovered ? const Color(0xFFFFD65C) : const Color(0xFFF5C73D),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13.5, color: kAcctText),
              ),
              if (icon != null) ...[
                const SizedBox(width: 6),
                Icon(icon, size: 17, color: const Color(0xFF333333)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard gray page-action button (إغلاق / تحديث / طباعة ...).
class AcctButton extends StatelessWidget {
  const AcctButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.width = 110,
    this.height = 30,
    this.fill = kAcctTile,
    this.fontSize = 13,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final double width;
  final double height;
  final Color fill;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          color: hovered ? kHoverYellow : fill,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: fontSize, color: kAcctText),
              ),
              if (icon != null) ...[
                const SizedBox(width: 5),
                Icon(icon, size: 16, color: const Color(0xFF444444)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Round "×" used to clear a filter.
class AcctClearX extends StatelessWidget {
  const AcctClearX({super.key, required this.onTap, this.size = 20});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          color: hovered ? kHoverYellow : const Color(0xFFE9E9E9),
          child: const Icon(Icons.close, size: 13, color: Color(0xFF555555)),
        ),
      ),
    );
  }
}

/// Toolbar button used inside the print preview window.
class AcctToolbarButton extends StatelessWidget {
  const AcctToolbarButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 34,
          alignment: Alignment.center,
          color: hovered && enabled ? kHoverYellow : Colors.transparent,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: enabled
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFF9A9A9A),
            ),
          ),
        ),
      ),
    );
  }
}
