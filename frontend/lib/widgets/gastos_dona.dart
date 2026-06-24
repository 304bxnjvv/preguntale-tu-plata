import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/summary.dart';

class GastosDona extends StatelessWidget {
  final List<BancoTotal> porBanco;
  const GastosDona({super.key, required this.porBanco});

  static const _colores = [
    Color(0xFF00C896), Color(0xFF1F6FEB), Color(0xFFF85149),
    Color(0xFFD29922), Color(0xFFA371F7),
  ];

  @override
  Widget build(BuildContext context) {
    if (porBanco.isEmpty) return const SizedBox.shrink();
    final total = porBanco.fold<double>(0, (a, b) => a + b.total.abs());
    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 50,
          sections: [
            for (var i = 0; i < porBanco.length; i++)
              PieChartSectionData(
                value: porBanco[i].total.abs(),
                color: _colores[i % _colores.length],
                title: total == 0
                    ? ''
                    : '${(porBanco[i].total.abs() / total * 100).toStringAsFixed(0)}%',
                radius: 40,
                titleStyle: const TextStyle(
                    fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
