import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/data_providers.dart';
import '../models/summary.dart';
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
            Text('tu plata', style: AppText.display(20, weight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textMuted, size: 20),
            tooltip: 'salir',
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
            label: Text('subir cartola', style: AppText.body(14, weight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: 'preguntar',
            onPressed: () => context.push('/chat'),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            elevation: 0,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text('preguntar', style: AppText.body(14, weight: FontWeight.w600, color: AppColors.onPrimary)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(summaryProvider);
          ref.invalidate(transactionsProvider);
          await ref.read(transactionsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            summary.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (e, _) => _ErrorBox(
                msg: 'no pude cargar el resumen',
                onRetry: () => ref.invalidate(summaryProvider),
              ),
              data: (s) => _Resumen(s: s),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text('movimientos', style: AppText.label(AppColors.textMuted)),
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
                msg: 'no pude cargar los movimientos',
                onRetry: () => ref.invalidate(transactionsProvider),
              ),
              data: (list) => list.isEmpty
                  ? _EmptyState()
                  : Column(children: [for (final t in list) TransactionTile(t: t)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  final Summary s;
  const _Resumen({required this.s});

  @override
  Widget build(BuildContext context) {
    final clp = s.porMoneda['CLP'];
    final gastos = clp?.gastos ?? 0;
    final ingresos = clp?.ingresos ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                label: 'gastos',
                valor: formatCLP(gastos),
                color: AppColors.negative,
                icon: Icons.arrow_downward_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                label: 'ingresos',
                valor: formatCLP(ingresos),
                color: AppColors.positive,
                icon: Icons.arrow_upward_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GastosDona(porBanco: s.gastosPorBanco),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
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
              child: Text('reintentar', style: AppText.body(14, weight: FontWeight.w600, color: AppColors.primary)),
            ),
          ],
        ),
      );
}
