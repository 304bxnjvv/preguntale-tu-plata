import 'package:flutter/material.dart';
import '../theme.dart';

class SummaryCard extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;
  final IconData icon;
  const SummaryCard({
    super.key,
    required this.label,
    required this.valor,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label, style: AppText.label(color)),
            ],
          ),
          const SizedBox(height: 10),
          Text(valor, style: AppText.amount(22, color: color)),
        ],
      ),
    );
  }
}
