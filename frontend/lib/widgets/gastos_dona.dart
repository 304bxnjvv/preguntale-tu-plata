import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/summary.dart';
import '../theme.dart';

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class GastosDona extends StatelessWidget {
  final List<CategoriaTotal> porCategoria;
  const GastosDona({super.key, required this.porCategoria});

  static const _colores = [
    AppColors.primary,
    AppColors.accent,
    AppColors.positive,
    AppColors.negative,
    AppColors.textMuted,
  ];

  @override
  Widget build(BuildContext context) {
    if (porCategoria.isEmpty) return const SizedBox.shrink();
    final total = porCategoria.fold<double>(0, (a, b) => a + b.total.abs());
    if (total == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.donut_small_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text('Por categoría', style: AppText.label(AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 46,
                sections: [
                  for (var i = 0; i < porCategoria.length; i++)
                    PieChartSectionData(
                      value: porCategoria[i].total.abs(),
                      color: _colores[i % _colores.length],
                      title: '${(porCategoria[i].total.abs() / total * 100).toStringAsFixed(0)}%',
                      radius: 38,
                      titleStyle: AppText.label(AppColors.text),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (var i = 0; i < porCategoria.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _colores[i % _colores.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _capitalize(porCategoria[i].categoria),
                      style: AppText.label(AppColors.textMuted),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
