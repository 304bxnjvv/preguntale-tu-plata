import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_providers.dart';
import '../theme.dart';

/// Lista de meses en español chileno (1-indexado).
const _meses = [
  '',
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// Glass card "Proyección de [mes]" para el dashboard.
/// - Con datos: muestra gasto proyectado grande; neto si existe; categorías en riesgo; caveat si confianza baja.
/// - Sin datos: CTA "sube tu cartola para proyectar".
class ForecastCard extends ConsumerWidget {
  const ForecastCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(forecastProvider);

    return forecastAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (forecast) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ForecastCardContent(forecast: forecast),
      ),
    );
  }
}

class _ForecastCardContent extends StatelessWidget {
  final Forecast forecast;
  const _ForecastCardContent({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final mesActual = _meses[DateTime.now().month];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: forecast.tieneDatos
          ? _WithData(forecast: forecast, mes: mesActual)
          : _NoData(mes: mesActual),
    );
  }
}

class _WithData extends StatelessWidget {
  final Forecast forecast;
  final String mes;
  const _WithData({required this.forecast, required this.mes});

  @override
  Widget build(BuildContext context) {
    final neto = forecast.netoProyectado;
    final netoPositivo = neto != null && neto >= 0;
    final netoColor = netoPositivo ? AppColors.positive : AppColors.negative;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.trending_up_rounded, size: 14, color: AppColors.accent),
            const SizedBox(width: 6),
            Text('Proyección de $mes', style: AppText.label(AppColors.accent)),
          ],
        ),
        const SizedBox(height: 12),

        // Gasto proyectado — monto grande
        Text(
          formatCLP(forecast.gastoProyectado),
          style: AppText.amount(28, color: AppColors.text),
        ),
        Text(
          'gasto proyectado a fin de mes',
          style: AppText.body(12, color: AppColors.textMuted),
        ),

        // Neto proyectado (solo si hay ingresos)
        if (neto != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                netoPositivo ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                size: 14,
                color: netoColor,
              ),
              const SizedBox(width: 6),
              Text(
                netoPositivo
                    ? 'te sobran ${formatCLP(neto.abs())}'
                    : 'te faltan ${formatCLP(neto.abs())}',
                style: AppText.body(13, weight: FontWeight.w600, color: netoColor),
              ),
            ],
          ),
        ],

        // Categorías en riesgo
        if (forecast.categoriasEnRiesgo.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),
          ...forecast.categoriasEnRiesgo.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.arrow_upward_rounded, size: 12, color: AppColors.negative),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'te vas a pasar en ${c.categoria}',
                      style: AppText.body(13, color: AppColors.negative),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Caveat (confianza baja/media)
        if (forecast.caveat.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            forecast.caveat,
            style: AppText.body(12, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _NoData extends StatelessWidget {
  final String mes;
  const _NoData({required this.mes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up_rounded, size: 14, color: AppColors.accent),
            const SizedBox(width: 6),
            Text('Proyección de $mes', style: AppText.label(AppColors.accent)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'sube tu cartola para proyectar',
          style: AppText.body(14, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
