import 'package:flutter/material.dart';

class HazardStripe extends StatelessWidget {
  const HazardStripe({super.key, this.height = 8});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: const CustomPaint(painter: _HazardPainter()),
    );
  }
}

class _HazardPainter extends CustomPainter {
  const _HazardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF141414),
    );
    final paint = Paint()..color = const Color(0xFFF0C400);
    const band = 12.0;
    for (var x = -size.height; x < size.width + band; x += band * 2) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + band, 0)
        ..lineTo(x + band, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HazardPainter oldDelegate) => false;
}
