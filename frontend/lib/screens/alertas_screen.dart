import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../widgets/orb.dart';

/// Pantalla `/alertas` — lista de alertas del usuario coloreadas por severidad.
/// urgent = salmón, warning = ámbar, info = índigo/salvia.
class AlertasScreen extends ConsumerWidget {
  const AlertasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertas = ref.watch(alertasProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textMuted, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Alertas', style: AppText.display(18, weight: FontWeight.w600)),
      ),
      body: alertas.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text(
            'No se pudieron cargar las alertas',
            style: AppText.body(14, color: AppColors.textMuted),
          ),
        ),
        data: (lista) => lista.isEmpty ? const _EmptyState() : _AlertasList(alertas: lista),
      ),
    );
  }
}

// ── Lista de alertas ──────────────────────────────────────────────────────────

class _AlertasList extends StatelessWidget {
  final List<Alerta> alertas;
  const _AlertasList({required this.alertas});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: alertas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _AlertaCard(alerta: alertas[i]),
    );
  }
}

// ── Tarjeta individual de alerta ──────────────────────────────────────────────

class _AlertaCard extends StatelessWidget {
  final Alerta alerta;
  const _AlertaCard({required this.alerta});

  Color get _severidadColor {
    switch (alerta.severidad) {
      case 'urgent':
        return AppColors.negative; // salmón
      case 'warning':
        return AppColors.accent; // ámbar
      default:
        return AppColors.primary; // índigo (info)
    }
  }

  IconData get _tipoIcon {
    switch (alerta.tipo) {
      case 'tarjeta_vence':
        return Icons.credit_card_outlined;
      case 'presupuesto':
        return Icons.savings_outlined;
      case 'cuotas_proximo_mes':
        return Icons.calendar_today_outlined;
      case 'gasto_inusual':
        return Icons.trending_up_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severidadColor;

    return Card(
      elevation: 0,
      color: AppColors.glass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_tipoIcon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alerta.titulo,
                    style: AppText.body(14, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alerta.detalle,
                    style: AppText.body(13, color: AppColors.textMuted),
                  ),
                  if (alerta.fecha != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      alerta.fecha!,
                      style: AppText.label(AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Estado vacío ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Orb(size: 56),
            const SizedBox(height: 20),
            Text(
              'todo en orden',
              style: AppText.display(18, weight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'no tienes alertas pendientes, vas bien',
              style: AppText.body(14, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
