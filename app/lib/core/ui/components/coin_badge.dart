import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_specs.dart';
import '../tokens/app_typography.dart';

/// Badge de saldo de moedas cósmicas.
///
/// Único momento animado do Design System "Starlight": quando o saldo
/// sobe (missão aprovada / moeda creditada), um "twinkle" breve (escala +
/// glow) marca a recompensa — o resto do app segue Calm Technology, sem
/// animação. Respeita "reduzir movimento" do sistema.
class CoinBadge extends StatefulWidget {
  const CoinBadge({super.key, required this.coins});

  final int coins;

  @override
  State<CoinBadge> createState() => _CoinBadgeState();
}

class _CoinBadgeState extends State<CoinBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _glow = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5, curve: Curves.easeOut)),
    );
  }

  @override
  void didUpdateWidget(covariant CoinBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.coins > oldWidget.coins && !reduceMotion) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpecs.spaceM,
              vertical: AppSpecs.spaceS,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppSpecs.radiusS),
              border: Border.all(color: AppColors.stardustYellow.withValues(alpha: 0.5)),
              boxShadow: _glow.value == 0
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.stardustYellow.withValues(alpha: 0.45 * _glow.value),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
            ),
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, color: AppColors.stardustYellow, size: 20),
          const SizedBox(width: AppSpecs.spaceS),
          Text('${widget.coins}', style: AppTypography.coinCounter),
        ],
      ),
    );
  }
}
