import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// Mascote "Stellar" — o cometa de estardust, símbolo do Design System
/// "Starlight". Estático por design: a única animação do sistema é o
/// "twinkle" do [CoinBadge] ao creditar moeda, não o mascote em si — quando
/// ele aparece dentro do badge, herda esse movimento de graça.
class StellarMascot extends StatelessWidget {
  const StellarMascot({super.key, this.size = 48, this.trail = false});

  final double size;

  /// Rastro de cometa atrás do corpo — só faz sentido em tamanhos grandes
  /// (ilustração de estado vazio); em ícones pequenos (badge, avatar) vira
  /// ruído visual.
  final bool trail;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _StellarPainter(trail: trail)),
    );
  }
}

class _StellarPainter extends CustomPainter {
  const _StellarPainter({required this.trail});

  final bool trail;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);

    if (trail) {
      final trailPaint = Paint()..color = AppColors.stardustYellow;
      canvas.drawCircle(const Offset(20, 78), 3, trailPaint..color = AppColors.stardustYellow.withValues(alpha: 0.35));
      canvas.drawCircle(const Offset(28, 70), 4.5, trailPaint..color = AppColors.stardustYellow.withValues(alpha: 0.55));
      canvas.drawCircle(const Offset(37, 63), 6, trailPaint..color = AppColors.stardustYellow.withValues(alpha: 0.75));
    }

    canvas.drawCircle(const Offset(50, 50), 24, Paint()..color = AppColors.stardustYellow);

    final facePaint = Paint()..color = AppColors.spaceDark;
    canvas.drawCircle(const Offset(43, 49), 2.2, facePaint);
    canvas.drawCircle(const Offset(57, 49), 2.2, facePaint);

    final mouthPaint = Paint()
      ..color = AppColors.spaceDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(44, 57)
        ..quadraticBezierTo(50, 62, 56, 57),
      mouthPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(70, 18)
        ..cubicTo(71, 23, 73, 25, 78, 26)
        ..cubicTo(73, 27, 71, 29, 70, 34)
        ..cubicTo(69, 29, 67, 27, 62, 26)
        ..cubicTo(67, 25, 69, 23, 70, 18)
        ..close(),
      Paint()..color = AppColors.auroraGreen,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StellarPainter oldDelegate) => trail != oldDelegate.trail;
}
