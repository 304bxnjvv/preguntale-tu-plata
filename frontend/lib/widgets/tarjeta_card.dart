import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_providers.dart';
import '../theme.dart';

/// Glass card que muestra el estado de la tarjeta de crédito del usuario.
/// Se oculta (SizedBox.shrink) cuando tiene_datos == false.
class TarjetaCard extends ConsumerWidget {
  const TarjetaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tarjeta = ref.watch(tarjetaProvider);

    return tarjeta.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (t) {
        if (!t.tieneDatos) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _TarjetaCardContent(data: t),
        );
      },
    );
  }
}

class _TarjetaCardContent extends StatelessWidget {
  final TarjetaEstado data;
  const _TarjetaCardContent({required this.data});

  /// Parsea "YYYY-MM-DD" y devuelve "dd/mm", o null si es inválido.
  String? _formatFecha(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    return '${parts[2]}/${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final fechaDisplay = _formatFecha(data.fechaVencimiento);
    final cupoProgress = data.cupoTotal > 0
        ? (data.cupoUtilizado / data.cupoTotal).clamp(0.0, 1.0)
        : 0.0;
    final porcentajeCupo = data.cupoTotal > 0
        ? (data.cupoUtilizado / data.cupoTotal * 100).round()
        : 0;

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
          // Header
          Row(
            children: [
              const Icon(Icons.credit_card_rounded, size: 14, color: AppColors.negative),
              const SizedBox(width: 6),
              Text('Tu tarjeta de crédito', style: AppText.label(AppColors.negative)),
            ],
          ),
          const SizedBox(height: 12),

          // Total a pagar — monto grande en salmón
          Text(
            formatCLP(data.totalAPagar),
            style: AppText.amount(28, color: AppColors.negative),
          ),

          // Fecha vencimiento
          if (fechaDisplay != null) ...[
            const SizedBox(height: 4),
            Text(
              'antes del $fechaDisplay',
              style: AppText.body(13, color: AppColors.textMuted),
            ),
          ],

          const SizedBox(height: 10),

          // Comprometido próximo mes — ámbar destacado
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 13, color: AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'comprometido el próximo mes: ${formatCLP(data.comprometidoProximoMes)}',
                  style: AppText.body(13, weight: FontWeight.w600, color: AppColors.accent),
                ),
              ),
            ],
          ),

          // Barra de cupo usado
          if (data.cupoTotal > 0) ...[
            const SizedBox(height: 14),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('cupo usado', style: AppText.label(AppColors.textMuted)),
                Text(
                  '$porcentajeCupo%  (${formatCLP(data.cupoUtilizado)} / ${formatCLP(data.cupoTotal)})',
                  style: AppText.label(AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: cupoProgress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    cupoProgress > 0.8 ? AppColors.negative : AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
