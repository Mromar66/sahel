import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:inventory_app/app/widgets/hover_widgets.dart';

/// Red confirmation dialog — exact copy of the reference:
/// red frame, white title strip "صفو لإدارة الأعمال" with a close X on the
/// left, a question bubble, bold "هل أنت متأكد ؟", a yellow [نعم ✓] button
/// with the ENTER shortcut hint and a gray [لا ✗] button with ESC.
Future<bool> showConfirmDeleteDialog(
  BuildContext context, {
  required String question,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x66000000),
    builder: (dialogContext) => _ConfirmDeleteDialog(question: question),
  );
  return result ?? false;
}

class _ConfirmDeleteDialog extends StatefulWidget {
  const _ConfirmDeleteDialog({required this.question});

  final String question;

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      Navigator.of(context).pop(true);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop(false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            width: 758,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFFDE3B32), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [_buildTitleBar(), _buildBody()],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(1)),
        border: Border(
          bottom: BorderSide(color: Color(0xFFDE3B32), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.only(right: 12, left: 8),
      child: Row(
        children: [
          const Text(
            'صفو لإدارة الأعمال',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(false),
              child: SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: CustomPaint(
                    painter: _ClosePainter(color: const Color(0xFF555555)),
                    size: const Size(12, 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      child: Column(
        children: [
          // Question bubble.
          CustomPaint(
            painter: _BubblePainter(),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF2F2),
                border: Border.all(color: const Color(0xFFDE3B32), width: 1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.question,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: Color(0xFF333333),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'هل أنت متأكد ؟',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _decisionButton(
                label: 'نعم',
                glyph: _GlyphType.check,
                background: const Color(0xFFE6C33C),
                foreground: const Color(0xFF1A1A1A),
                shortcut: 'ENTER',
                onTap: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(width: 18),
              _decisionButton(
                label: 'لا',
                glyph: _GlyphType.cross,
                background: const Color(0xFF8E8E8E),
                foreground: Colors.white,
                shortcut: 'ESC',
                onTap: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _decisionButton({
    required String label,
    required _GlyphType glyph,
    required Color background,
    required Color foreground,
    required String shortcut,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        HoverBuilder(
          builder: (context, hovered) {
            final bg = hovered ? kHoverYellow : background;
            final fg = hovered ? const Color(0xFF1A1A1A) : foreground;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                width: 132,
                height: 34,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: hovered
                        ? const Color(0xFFC7A62B)
                        : const Color(0xFFB7B7B7),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                    const SizedBox(width: 7),
                    CustomPaint(
                      painter: _GlyphPainter(type: glyph, color: fg),
                      size: const Size(11, 11),
                    ),
                  ],
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
            color: Color(0xFF9A9A9A),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

enum _GlyphType { check, cross }

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({required this.type, required this.color});

  final _GlyphType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (type == _GlyphType.check) {
      final path = Path()
        ..moveTo(size.width * 0.08, size.height * 0.55)
        ..lineTo(size.width * 0.38, size.height * 0.88)
        ..lineTo(size.width * 0.95, size.height * 0.12);
      canvas.drawPath(path, paint);
    } else {
      canvas.drawLine(
        Offset(size.width * 0.12, size.height * 0.12),
        Offset(size.width * 0.88, size.height * 0.88),
        paint,
      );
      canvas.drawLine(
        Offset(size.width * 0.88, size.height * 0.12),
        Offset(size.width * 0.12, size.height * 0.88),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}

/// Speech-bubble tail under the bubble.
class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFDF2F2)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0xFFDE3B32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Tail centered-right, pointing down.
    final tail = Path()
      ..moveTo(size.width - 64, size.height - 1)
      ..lineTo(size.width - 44, size.height + 9)
      ..lineTo(size.width - 24, size.height - 1)
      ..close();
    canvas.drawPath(tail, paint);
    // Cover the border line behind the tail.
    canvas.drawLine(
      Offset(size.width - 62, size.height - 0.5),
      Offset(size.width - 26, size.height - 0.5),
      paint,
    );
    canvas.drawPath(tail, border);
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => false;
}

class _ClosePainter extends CustomPainter {
  const _ClosePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_ClosePainter oldDelegate) => oldDelegate.color != color;
}
