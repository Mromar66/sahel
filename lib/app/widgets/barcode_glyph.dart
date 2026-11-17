import 'package:flutter/material.dart';

/// Small black barcode glyph used by footer buttons and barcode labels.
class BarcodeGlyph extends StatelessWidget {
  const BarcodeGlyph({super.key, this.width = 16, this.height = 16});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: const CustomPaint(painter: BarcodePainter()),
    );
  }
}

class BarcodePainter extends CustomPainter {
  const BarcodePainter();

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
