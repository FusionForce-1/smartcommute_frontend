// lib/widgets/auth/smart_commute_logo.dart
//
// Logo lockup + tagline for Login / Register. Prefers the bundled PNG;
// falls back to a painted mark so the preview still matches the mockups
// when assets/images is empty.

import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

class SmartCommuteLogo extends StatelessWidget {
  const SmartCommuteLogo({
    super.key,
    this.height = 140,
    this.showTagline = true,
    this.taglineColor,
  });

  final double height;
  final bool showTagline;
  final Color? taglineColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/smart_commute_logo.png',
          height: height,
          errorBuilder: (context, error, stackTrace) =>
              _PaintedLockup(height: height),
        ),
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            'Cebu City Transit Information',
            style: TextStyle(
              color: taglineColor ?? AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

class _PaintedLockup extends StatelessWidget {
  const _PaintedLockup({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    final markHeight = height * 0.58;
    return Column(
      children: [
        SizedBox(
          height: markHeight,
          width: markHeight * 1.35,
          child: const CustomPaint(painter: _MarkPainter()),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'SMART\n',
                style: TextStyle(
                  fontSize: height * 0.18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  height: 0.95,
                  letterSpacing: 0.4,
                ),
              ),
              TextSpan(
                text: 'COMMUTE',
                style: TextStyle(
                  fontSize: height * 0.145,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                  height: 1.05,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void wave(double y, Color color, double stroke) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(w * 0.04, y)
        ..cubicTo(w * 0.22, y - h * 0.18, w * 0.38, y + h * 0.14, w * 0.58, y);
      canvas.drawPath(path, paint);
    }

    wave(h * 0.42, const Color(0xFF1A3C6E), 7);
    wave(h * 0.58, const Color(0xFF2E86AB), 7);
    wave(h * 0.74, const Color(0xFF4FB3C8), 7);

    final stem = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFF2E86AB), Color(0xFFF5A623)],
      ).createShader(Rect.fromLTWH(w * 0.55, 0, w * 0.4, h));
    final stemPath = Path()
      ..moveTo(w * 0.58, h * 0.78)
      ..quadraticBezierTo(w * 0.72, h * 0.42, w * 0.78, h * 0.22);
    canvas.drawPath(
      stemPath,
      stem
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    final pin = Path()
      ..moveTo(w * 0.78, h * 0.08)
      ..cubicTo(w * 0.92, h * 0.08, w * 0.96, h * 0.32, w * 0.78, h * 0.48)
      ..cubicTo(w * 0.60, h * 0.32, w * 0.64, h * 0.08, w * 0.78, h * 0.08);
    canvas.drawPath(
      pin,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7C14A), Color(0xFFF5A623)],
        ).createShader(Rect.fromLTWH(w * 0.6, 0, w * 0.4, h * 0.5)),
    );
    canvas.drawCircle(
      Offset(w * 0.78, h * 0.22),
      5.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
