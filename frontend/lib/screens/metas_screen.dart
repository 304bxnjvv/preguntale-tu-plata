import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_providers.dart';
import '../theme.dart';

/// Pantalla `/metas` — lista metas de ahorro con barra de progreso y aporte mensual.
class MetasScreen extends ConsumerWidget {
  const MetasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metas = ref.watch(metasProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textMuted, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Mis metas', style: AppText.display(18, weight: FontWeight.w600)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nueva_meta',
        onPressed: () => _mostrarSheetNuevaMeta(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text('+ meta', style: AppText.body(14, weight: FontWeight.w600, color: AppColors.onPrimary)),
      ),
      body: metas.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text('No se pudieron cargar las metas',
              style: AppText.body(14, color: AppColors.textMuted)),
        ),
        data: (lista) => lista.isEmpty
            ? _EmptyState(onAdd: () => _mostrarSheetNuevaMeta(context, ref))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: lista.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final m = lista[i];
                  return _MetaItem(
                    meta: m,
                    onEditar: () => _mostrarSheetEditarMeta(context, ref, m),
                    onEliminar: () async {
                      await ref.read(apiProvider).eliminarMeta(m.id);
                      ref.invalidate(metasProvider);
                    },
                  );
                },
              ),
      ),
    );
  }

  void _mostrarSheetNuevaMeta(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NuevaMetaSheet(onGuardar: (nombre, objetivo, fecha) async {
        await ref.read(apiProvider).crearMeta(nombre, objetivo, fechaObjetivo: fecha);
        ref.invalidate(metasProvider);
      }),
    );
  }

  void _mostrarSheetEditarMeta(BuildContext context, WidgetRef ref, Meta meta) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditarMetaSheet(
        meta: meta,
        onGuardar: (montoActual) async {
          await ref.read(apiProvider).actualizarMeta(meta.id, montoActual: montoActual);
          ref.invalidate(metasProvider);
        },
      ),
    );
  }
}

// ── Ítem de meta ─────────────────────────────────────────────────────────────

class _MetaItem extends StatelessWidget {
  final Meta meta;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _MetaItem({
    required this.meta,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final pct = meta.progreso.clamp(0.0, 1.0);
    final pctDisplay = (meta.progreso * 100).round();
    // Color por progreso
    final barColor = pct >= 1.0
        ? AppColors.positive
        : pct >= 0.7
            ? AppColors.accent
            : AppColors.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pct >= 1.0
              ? AppColors.positive.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  meta.nombre,
                  style: AppText.body(15, weight: FontWeight.w600),
                ),
              ),
              if (pct >= 1.0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.positive.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'lograda',
                    style: AppText.label(AppColors.positive),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEditar,
                child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onEliminar,
                child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Barra de progreso animada
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: pct),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatCLP(meta.montoActual)} de ${formatCLP(meta.montoObjetivo)}',
                style: AppText.body(12, color: AppColors.textMuted),
              ),
              Text(
                '$pctDisplay%',
                style: AppText.body(12, weight: FontWeight.w600, color: barColor),
              ),
            ],
          ),
          if (meta.aporteMensualNecesario != null && meta.aporteMensualNecesario! > 0) ...[
            const SizedBox(height: 4),
            Text(
              'necesitas ${formatCLP(meta.aporteMensualNecesario!)}/mes',
              style: AppText.body(12, color: AppColors.textMuted),
            ),
          ],
          if (meta.fechaObjetivo != null) ...[
            const SizedBox(height: 2),
            Text(
              'objetivo: ${meta.fechaObjetivo}',
              style: AppText.body(11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sheet nueva meta ──────────────────────────────────────────────────────────

class _NuevaMetaSheet extends StatefulWidget {
  final Future<void> Function(String nombre, num objetivo, String? fecha) onGuardar;
  const _NuevaMetaSheet({required this.onGuardar});

  @override
  State<_NuevaMetaSheet> createState() => _NuevaMetaSheetState();
}

class _NuevaMetaSheetState extends State<_NuevaMetaSheet> {
  final _nombreCtrl = TextEditingController();
  final _objetivoCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _objetivoCtrl.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nueva meta', style: AppText.display(18, weight: FontWeight.w600)),
          const SizedBox(height: 20),
          TextField(
            controller: _nombreCtrl,
            style: AppText.body(15),
            decoration: InputDecoration(
              labelText: 'Nombre de la meta',
              labelStyle: AppText.body(14, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _objetivoCtrl,
            keyboardType: TextInputType.number,
            style: AppText.body(15),
            decoration: InputDecoration(
              labelText: 'Monto objetivo (CLP)',
              labelStyle: AppText.body(14, color: AppColors.textMuted),
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _fechaCtrl,
            style: AppText.body(15),
            decoration: InputDecoration(
              labelText: 'Fecha objetivo (opcional, ej: 2026-12-31)',
              labelStyle: AppText.body(14, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                  )
                : Text('Guardar', style: AppText.body(15, weight: FontWeight.w600, color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    final objetivoStr = _objetivoCtrl.text.trim().replaceAll('.', '').replaceAll(',', '');
    final objetivo = num.tryParse(objetivoStr);
    if (nombre.isEmpty || objetivo == null || objetivo <= 0) return;
    final fecha = _fechaCtrl.text.trim().isEmpty ? null : _fechaCtrl.text.trim();
    setState(() => _guardando = true);
    try {
      await widget.onGuardar(nombre, objetivo, fecha);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

// ── Sheet editar meta ─────────────────────────────────────────────────────────

class _EditarMetaSheet extends StatefulWidget {
  final Meta meta;
  final Future<void> Function(num montoActual) onGuardar;
  const _EditarMetaSheet({required this.meta, required this.onGuardar});

  @override
  State<_EditarMetaSheet> createState() => _EditarMetaSheetState();
}

class _EditarMetaSheetState extends State<_EditarMetaSheet> {
  late final TextEditingController _montoCtrl;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _montoCtrl = TextEditingController(
      text: widget.meta.montoActual > 0 ? widget.meta.montoActual.round().toString() : '',
    );
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ya llevo \$…',
            style: AppText.display(18, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            widget.meta.nombre,
            style: AppText.body(14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _montoCtrl,
            keyboardType: TextInputType.number,
            style: AppText.body(15),
            decoration: InputDecoration(
              labelText: 'Monto ahorrado hasta ahora (CLP)',
              labelStyle: AppText.body(14, color: AppColors.textMuted),
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                  )
                : Text('Actualizar', style: AppText.body(15, weight: FontWeight.w600, color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _guardar() async {
    final montoStr = _montoCtrl.text.trim().replaceAll('.', '').replaceAll(',', '');
    final monto = num.tryParse(montoStr);
    if (monto == null || monto < 0) return;
    setState(() => _guardando = true);
    try {
      await widget.onGuardar(monto);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_outlined, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 20),
            Text(
              'sin metas aún',
              style: AppText.display(18, weight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'crea tu primera meta y empieza a ahorrar con propósito',
              style: AppText.body(14, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Crear primera meta',
                style: AppText.body(14, weight: FontWeight.w600, color: AppColors.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
