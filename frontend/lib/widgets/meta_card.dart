import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/data_providers.dart';
import '../theme.dart';

/// Glass card de metas para el dashboard.
/// - Sin metas: CTA "crea tu primera meta".
/// - Con metas: muestra la meta más cercana a cumplirse o resumen general.
/// onTap → `/metas`.
class MetaCard extends ConsumerWidget {
  const MetaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metas = ref.watch(metasProvider);

    return metas.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (lista) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _MetaCardContent(lista: lista),
      ),
    );
  }
}

class _MetaCardContent extends StatelessWidget {
  final List<Meta> lista;
  const _MetaCardContent({required this.lista});

  @override
  Widget build(BuildContext context) {
    // Buscar la meta más cercana a completarse (mayor progreso, pero no 100%)
    final activas = lista.where((m) => m.progreso < 1.0).toList()
      ..sort((a, b) => b.progreso.compareTo(a.progreso));
    final masAdelantada = activas.isNotEmpty ? activas.first : null;

    final Color highlightColor = lista.isEmpty
        ? AppColors.primary
        : masAdelantada != null
            ? AppColors.accent
            : AppColors.positive;

    return GestureDetector(
      onTap: () => context.push('/metas'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              lista.isEmpty
                  ? Icons.flag_outlined
                  : lista.every((m) => m.progreso >= 1.0)
                      ? Icons.emoji_events_outlined
                      : Icons.savings_outlined,
              size: 20,
              color: highlightColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Metas de ahorro',
                    style: AppText.label(AppColors.textMuted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _mensaje(lista, masAdelantada),
                    style: AppText.body(14,
                        weight: FontWeight.w600,
                        color: AppColors.text),
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

  String _mensaje(List<Meta> lista, Meta? masAdelantada) {
    if (lista.isEmpty) return 'crea tu primera meta';
    if (masAdelantada == null) {
      return lista.length == 1
          ? '¡lograste tu meta!'
          : '¡lograste todas tus metas!';
    }
    final n = lista.length;
    final pct = (masAdelantada.progreso * 100).round();
    if (n == 1) return '${masAdelantada.nombre}: $pct%';
    return '$n metas activas, vas en $pct%';
  }
}
