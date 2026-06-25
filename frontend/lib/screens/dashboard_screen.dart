import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/data_providers.dart';
import '../models/summary.dart';
import '../models/insights.dart';
import '../theme.dart';
import '../widgets/orb.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/gastos_dona.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);
    final txns = ref.watch(transactionsProvider);
    final suscripciones = ref.watch(suscripcionesProvider);
    final comparativo = ref.watch(comparativoProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            const Orb(size: 36),
            const SizedBox(width: 10),
            Text('Tu plata', style: AppText.display(20, weight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textMuted, size: 20),
            tooltip: 'Salir',
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'subir',
            onPressed: () => context.push('/upload'),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.text,
            elevation: 0,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text('Subir cartola', style: AppText.body(14, weight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: 'preguntar',
            onPressed: () => context.push('/chat'),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            elevation: 0,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text('Preguntar', style: AppText.body(14, weight: FontWeight.w600, color: AppColors.onPrimary)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(summaryProvider);
          ref.invalidate(transactionsProvider);
          ref.invalidate(suscripcionesProvider);
          ref.invalidate(comparativoProvider);
          await ref.read(transactionsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            summary.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (e, _) => _ErrorBox(
                msg: 'No se pudo cargar el resumen',
                onRetry: () => ref.invalidate(summaryProvider),
              ),
              data: (s) => _Resumen(s: s, comparativo: comparativo),
            ),
            suscripciones.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (s) => s.items.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _SuscripcionesCard(s: s),
                    ),
            ),
            const SizedBox(height: 20),
            const _FilterBar(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text('Movimientos', style: AppText.label(AppColors.textMuted)),
                ],
              ),
            ),
            txns.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (e, _) => _ErrorBox(
                msg: 'No se pudo cargar los movimientos',
                onRetry: () => ref.invalidate(transactionsProvider),
              ),
              data: (list) => list.isEmpty
                  ? const _EmptyState()
                  : Column(children: [for (final t in list) TransactionTile(t: t)]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  // null dias = "Todo" (sin filtro de fecha)
  static const _diasOpts = [
    (label: 'Todo', dias: null),
    (label: '24h', dias: 1),
    (label: '3d', dias: 3),
    (label: '7d', dias: 7),
    (label: '15d', dias: 15),
    (label: '30d', dias: 30),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time range chips
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _diasOpts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final opt = _diasOpts[i];
              final selected = filter.dias == opt.dias;
              return _FilterChip(
                label: opt.label,
                selected: selected,
                onTap: () => ref.read(dashboardFilterProvider.notifier).state =
                    DashboardFilter(dias: opt.dias, tipo: filter.tipo),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Type segmented control
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _TypeSegment(
                label: 'Ingresos',
                selected: filter.tipo == 'ingreso',
                isFirst: true,
                isLast: false,
                onTap: () => ref.read(dashboardFilterProvider.notifier).state =
                    DashboardFilter(dias: filter.dias, tipo: 'ingreso'),
              ),
              _TypeSegment(
                label: 'Gastos',
                selected: filter.tipo == 'gasto',
                isFirst: false,
                isLast: false,
                onTap: () => ref.read(dashboardFilterProvider.notifier).state =
                    DashboardFilter(dias: filter.dias, tipo: 'gasto'),
              ),
              _TypeSegment(
                label: 'Ambos',
                selected: filter.tipo == null,
                isFirst: false,
                isLast: true,
                onTap: () => ref.read(dashboardFilterProvider.notifier).state =
                    DashboardFilter(dias: filter.dias),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.glass,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppText.body(
            13,
            weight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.onPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _TypeSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _TypeSegment({
    required this.label,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: isFirst ? const Radius.circular(11) : Radius.zero,
              right: isLast ? const Radius.circular(11) : Radius.zero,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.body(
              13,
              weight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppColors.onPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Summary ───────────────────────────────────────────────────────────────────

class _Resumen extends StatelessWidget {
  final Summary s;
  final AsyncValue<Comparativo> comparativo;
  const _Resumen({required this.s, required this.comparativo});

  @override
  Widget build(BuildContext context) {
    final clp = s.porMoneda['CLP'];
    final gastos = clp?.gastos ?? 0;
    final ingresos = clp?.ingresos ?? 0;

    // Comparativo line: only shown when gastosAnterior != 0
    final comparativoLine = comparativo.whenOrNull(
      data: (c) {
        if (c.gastosAnterior == 0) return null;
        final subio = c.delta > 0; // delta positive = gasto subió
        final arrow = subio ? '↑' : '↓';
        final color = subio ? AppColors.negative : AppColors.positive;
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Text(
                'vs mes pasado: $arrow ${formatCLP(c.delta.abs())}',
                style: AppText.body(12, color: color, weight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SummaryCard(
                    label: 'Gastos',
                    valor: formatCLP(gastos),
                    color: AppColors.negative,
                    icon: Icons.arrow_downward_rounded,
                  ),
                  if (comparativoLine != null) comparativoLine,
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                label: 'Ingresos',
                valor: formatCLP(ingresos),
                color: AppColors.positive,
                icon: Icons.arrow_upward_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GastosDona(porCategoria: s.gastosPorCategoria),
      ],
    );
  }
}

// ── Suscripciones card ────────────────────────────────────────────────────────

class _SuscripcionesCard extends StatelessWidget {
  final Suscripciones s;
  const _SuscripcionesCard({required this.s});

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              const Icon(Icons.autorenew_rounded, size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              Text('Suscripciones detectadas', style: AppText.label(AppColors.accent)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatCLP(s.totalMensual),
            style: AppText.amount(22, color: AppColors.accent),
          ),
          const SizedBox(height: 12),
          ...s.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _capitalize(item.descripcion),
                      style: AppText.body(13, color: AppColors.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCLP(item.monto),
                    style: AppText.body(13, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ── Empty / Error ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          const Orb(size: 56),
          const SizedBox(height: 20),
          Text(
            'todavía no me conoces 😅',
            style: AppText.body(16, weight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Sube tu primera cartola (PDF/CSV) y pregúntame lo que quieras.',
            style: AppText.body(14, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorBox({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(msg, style: AppText.body(14, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: Text('Reintentar', style: AppText.body(14, weight: FontWeight.w600, color: AppColors.primary)),
            ),
          ],
        ),
      );
}
