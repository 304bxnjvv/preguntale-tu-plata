import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/data_providers.dart';
import '../models/summary.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/gastos_dona.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _miles(double m) => m.abs().toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (mm) => '${mm[1]}.');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);
    final txns = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Tu plata'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'subir',
            onPressed: () => context.push('/upload'),
            icon: const Icon(Icons.upload_file),
            label: const Text('Subir'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'preguntar',
            onPressed: () => context.push('/chat'),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Preguntar'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(summaryProvider);
          ref.invalidate(transactionsProvider);
          await ref.read(transactionsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            summary.when(
              loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (e, _) => _ErrorBox(msg: 'No se pudo cargar el resumen',
                  onRetry: () => ref.invalidate(summaryProvider)),
              data: (s) => _Resumen(s: s, miles: _miles),
            ),
            const SizedBox(height: 20),
            const Text('Movimientos',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            txns.when(
              loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (e, _) => _ErrorBox(msg: 'No se pudieron cargar los movimientos',
                  onRetry: () => ref.invalidate(transactionsProvider)),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Sube tu primera cartola para empezar',
                          style: TextStyle(color: Color(0xFF8B949E)))))
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
  final String Function(double) miles;
  const _Resumen({required this.s, required this.miles});

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
            Expanded(child: SummaryCard(
                label: 'Gastos', valor: '\$${miles(gastos)}', color: const Color(0xFFF85149))),
            const SizedBox(width: 12),
            Expanded(child: SummaryCard(
                label: 'Ingresos', valor: '\$${miles(ingresos)}', color: const Color(0xFF00C896))),
          ],
        ),
        const SizedBox(height: 16),
        GastosDona(porBanco: s.gastosPorBanco),
      ],
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
        child: Column(children: [
          Text(msg, style: const TextStyle(color: Color(0xFF8B949E))),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ]),
      );
}
