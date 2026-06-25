import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_providers.dart';
import '../services/resumen_seen.dart';
import '../theme.dart';

/// Glass card cálida "Tu semana en plata 💸".
/// Se muestra solo cuando tiene_datos == true y han pasado ≥7 días desde el
/// último descarte. El botón "ya lo vi" oculta la card y guarda el timestamp.
class ResumenSemanalCard extends ConsumerStatefulWidget {
  /// Inyección de dependencia para tests (evita SharedPreferences reales).
  final ResumenSeen? seenOverride;

  const ResumenSemanalCard({super.key, this.seenOverride});

  @override
  ConsumerState<ResumenSemanalCard> createState() => _ResumenSemanalCardState();
}

class _ResumenSemanalCardState extends ConsumerState<ResumenSemanalCard> {
  late final ResumenSeen _seen;
  bool _visible = true; // optimistic; se oculta tras "ya lo vi"
  bool _debeMostrarCache = false;
  bool _seenLoaded = false;

  @override
  void initState() {
    super.initState();
    _seen = widget.seenOverride ?? ResumenSeen();
    _loadSeen();
  }

  Future<void> _loadSeen() async {
    final debe = await _seen.debeMostrar();
    if (mounted) {
      setState(() {
        _debeMostrarCache = debe;
        _seenLoaded = true;
      });
    }
  }

  Future<void> _marcarVisto() async {
    setState(() => _visible = false);
    await _seen.marcarVisto();
  }

  @override
  Widget build(BuildContext context) {
    final resumenAsync = ref.watch(resumenSemanalProvider);

    if (!_seenLoaded) return const SizedBox.shrink();
    if (!_visible || !_debeMostrarCache) return const SizedBox.shrink();

    return resumenAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (resumen) {
        if (!resumen.tieneDatos) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ResumenCard(resumen: resumen, onDismiss: _marcarVisto),
        );
      },
    );
  }
}

class _ResumenCard extends StatelessWidget {
  final ResumenSemanal resumen;
  final VoidCallback onDismiss;

  const _ResumenCard({required this.resumen, required this.onDismiss});

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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('💸', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text('Tu semana en plata', style: AppText.label(AppColors.accent)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Texto principal del resumen
          Text(
            resumen.texto,
            style: AppText.body(14, color: AppColors.text),
          ),

          const SizedBox(height: 14),

          // Botón de descarte
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onDismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'ya lo vi',
                  style: AppText.body(13, weight: FontWeight.w600, color: AppColors.textMuted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
