import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../models/categorias.dart';
import '../providers/data_providers.dart';
import '../theme.dart';

class TransactionTile extends ConsumerWidget {
  final Transaction t;
  final VoidCallback? onCategoriaChanged;

  const TransactionTile({super.key, required this.t, this.onCategoriaChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        onTap: () => _abrirSelectorCategoria(context, ref),
      ),
    );
  }

  Future<void> _abrirSelectorCategoria(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CategoriaSheet(
        txn: t,
        onElegida: (cat) async {
          Navigator.of(ctx).pop();
          try {
            await ref.read(apiProvider).editarCategoria(t.id, cat);
            onCategoriaChanged?.call();
          } catch (_) {
            // Error silencioso — no bloqueamos la UI
          }
        },
      ),
    );
  }
}

class _CategoriaSheet extends StatelessWidget {
  final Transaction txn;
  final void Function(String) onElegida;

  const _CategoriaSheet({required this.txn, required this.onElegida});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cambiar categoría', style: AppText.body(16, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              txn.descripcion,
              style: AppText.body(13, color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCategorias.map((cat) {
                final seleccionada = cat == txn.categoria;
                return ChoiceChip(
                  label: Text(cat),
                  selected: seleccionada,
                  onSelected: (_) => onElegida(cat),
                  selectedColor: AppColors.primary.withValues(alpha: 0.85),
                  backgroundColor: AppColors.glass,
                  labelStyle: AppText.body(
                    13,
                    color: seleccionada ? AppColors.onPrimary : AppColors.text,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: seleccionada ? AppColors.primary : AppColors.border,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
