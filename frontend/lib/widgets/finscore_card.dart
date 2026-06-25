import 'package:flutter/material.dart';
import '../models/finscore.dart';
import '../theme.dart';

/// Glass card que muestra el FinScore del usuario.
/// Gauge circular (CircularProgressIndicator + Stack) con el número al centro.
/// Color del arco según nivel: vas bien→positive, ojo→accent, alerta→negative, sin datos→textMuted.
class FinScoreCard extends StatelessWidget {
  final FinScore data;
  const FinScoreCard({super.key, required this.data});

  static Color _colorForNivel(String nivel) {
    switch (nivel) {
      case 'vas bien':
        return AppColors.positive;
      case 'ojo':
        return AppColors.accent;
      case 'alerta':
        return AppColors.negative;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nivelColor = _colorForNivel(data.nivel);
    final progress = (data.score / 100).clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header label
          Row(
            children: [
              Icon(Icons.favorite_rounded, size: 14, color: nivelColor),
              const SizedBox(width: 6),
              Text('Tu salud financiera', style: AppText.label(nivelColor)),
            ],
          ),
          const SizedBox(height: 16),
          // Gauge + resumen row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ScoreGauge(progress: progress, score: data.score, color: nivelColor),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nivel badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: nivelColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        data.nivel.toUpperCase(),
                        style: AppText.label(nivelColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.resumen,
                      style: AppText.body(13, color: AppColors.textMuted),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Factores list
          if (data.factores.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            ...data.factores.map((f) => _FactorRow(factor: f)),
          ],
        ],
      ),
    );
  }
}

class _ScoreGauge extends StatelessWidget {
  final double progress;
  final int score;
  final Color color;

  const _ScoreGauge({
    required this.progress,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background track
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 7,
              color: AppColors.border,
            ),
          ),
          // Foreground arc
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => CircularProgressIndicator(
                value: value,
                strokeWidth: 7,
                strokeCap: StrokeCap.round,
                color: color,
              ),
            ),
          ),
          // Score number
          Text(
            '$score',
            style: AppText.amount(26, color: color),
          ),
        ],
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  final FinFactor factor;
  const _FactorRow({required this.factor});

  @override
  Widget build(BuildContext context) {
    final isPositive = factor.signo == '+';
    final color = isPositive ? AppColors.positive : AppColors.negative;
    final icon = isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              factor.texto,
              style: AppText.body(13, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
