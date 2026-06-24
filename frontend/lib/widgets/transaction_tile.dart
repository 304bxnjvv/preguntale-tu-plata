import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../theme.dart';

class TransactionTile extends StatelessWidget {
  final Transaction t;
  const TransactionTile({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final gasto = t.monto < 0;
    final color = gasto ? AppColors.negative : AppColors.positive;
    final icon = gasto ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        title: Text(
          t.descripcion,
          style: AppText.body(14, weight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${t.fecha} · ${t.banco}',
          style: AppText.label(AppColors.textMuted),
        ),
        trailing: Text(
          formatCLP(t.monto, conSigno: true),
          style: AppText.amount(15, color: color),
        ),
      ),
    );
  }
}
