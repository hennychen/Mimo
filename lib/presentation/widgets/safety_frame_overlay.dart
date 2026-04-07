import 'package:flutter/material.dart';

/// 安全框叠加层Widget
/// 
/// 显示一个引导框，帮助用户正确站立位置
class SafetyFrameOverlay extends StatelessWidget {
  const SafetyFrameOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SafetyFramePainter(),
      child: const Center(
        child: Text(
          '请站在框内',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class SafetyFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(
      size.width * 0.2,
      size.height * 0.1,
      size.width * 0.6,
      size.height * 0.8,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}