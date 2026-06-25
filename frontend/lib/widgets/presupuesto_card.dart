import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/data_providers.dart';
import '../theme.dart';

/// Glass card de presupuestos para el dashboard.
/// - Sin topes: CTA "fija tu primer presupuesto".
/// - Topes ok: "vas bien con tus topes".
/// - Hay cerca/excedido: "N categorías cerca del tope" en ámbar/salmón.
/// onTap → `/presupuestos`.
class PresupuestoCard extends ConsumerWidget {
  const PresupuestoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presupuestos = ref.watch(presupuestosProvider);

    return presupuestos.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (lista) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _PresupuestoCardContent(lista: lista),
      ),
    );
  }
}

class _PresupuestoCardContent extends StatelessWidget {
  final List<PresupuestoEstado> lista;
  const _PresupuestoCardContent({required this.lista});

  @override
  Widget build(BuildContext context) {
    // Categorías fuera de control
    final alertas = lista.where((p) => p.estado == 'cerca' || p.estado == 'excedido').toList();
    final hayExcedido = alertas.any((p) => p.estado == 'excedido');

    // Color del borde/texto
    final Color highlightColor = lista.isEmpty
        ? AppColors.primary
        : alertas.isEmpty
            ? AppColors.positive
            : hayExcedido
                ? AppColors.negative
                : AppColors.accent;

    return GestureDetector(
      onTap: () => context.push('/presupuestos'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: alertas.isNotEmpty
                ? highlightColor.withValues(alpha: 0.35)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              lista.isEmpty
                  ? Icons.savings_outlined
                  : alertas.isEmpty
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
              size: 20,
              color: highlightColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Presupuestos',
                    style: AppText.label(AppColors.textMuted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _mensaje(lista, alertas),
                    style: AppText.body(14,
                        weight: FontWeight.w600,
                        color: alertas.isNotEmpty ? highlightColor : AppColors.text),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  String _mensaje(List<PresupuestoEstado> lista, List<PresupuestoEstado> alertas) {
    if (lista.isEmpty) return 'fija tu primer presupuesto';
    if (alertas.isEmpty) return 'vas bien con tus topes';
    final n = alertas.length;
    return n == 1 ? '1 categoría cerca del tope' : '$n categorías cerca del tope';
  }
}
