import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_providers.dart';
import '../models/categorias.dart';
import '../theme.dart';

/// Pantalla `/presupuestos` — lista categorías con barra de progreso coloreada
/// por estado (ok=salvia, cerca=ámbar, excedido=salmón).
class PresupuestosScreen extends ConsumerWidget {
  const PresupuestosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presupuestos = ref.watch(presupuestosProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textMuted, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Presupuestos', style: AppText.display(18, weight: FontWeight.w600)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nuevo_tope',
        onPressed: () => _mostrarSheetNuevoTope(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text('+ tope', style: AppText.body(14, weight: FontWeight.w600, color: AppColors.onPrimary)),
      ),
      body: presupuestos.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text('No se pudieron cargar los presupuestos',
              style: AppText.body(14, color: AppColors.textMuted)),
        ),
        data: (lista) => lista.isEmpty
            ? _EmptyState(onAdd: () => _mostrarSheetNuevoTope(context, ref))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: lista.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final p = lista[i];
                  return _PresupuestoItem(
                    presupuesto: p,
                    onDelete: () async {
                      await ref.read(apiProvider).deleteTope(p.categoria);
                      ref.invalidate(presupuestosProvider);
                    },
                  );
                },
              ),
      ),
    );
  }

  void _mostrarSheetNuevoTope(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NuevoTopeSheet(onGuardar: (cat, monto) async {
        await ref.read(apiProvider).setTope(cat, monto);
        ref.invalidate(presupuestosProvider);
      }),
    );
  }
}

// ── Ítem de presupuesto ───────────────────────────────────────────────────────

class _PresupuestoItem extends StatelessWidget {
  final PresupuestoEstado presupuesto;
  final VoidCallback onDelete;

  const _PresupuestoItem({required this.presupuesto, required this.onDelete});

  Color get _barColor {
    switch (presupuesto.estado) {
      case 'excedido':
        return AppColors.negative;
      case 'cerca':
        return AppColors.accent;
      default:
        return AppColors.positive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final barColor = _barColor;
    final pct = presupuesto.pct.clamp(0.0, 1.0);
    final pctDisplay = (presupuesto.pct * 100).round();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: presupuesto.estado != 'ok'
              ? barColor.withValues(alpha: 0.35)
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
                  presupuesto.categoria,
                  style: AppText.body(15, weight: FontWeight.w600),
                ),
              ),
              // Badge de estado
              if (presupuesto.estado != 'ok')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    presupuesto.estado == 'excedido' ? 'excedido' : 'cerca',
                    style: AppText.label(barColor),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
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
          // Montos gastado / tope y porcentaje
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatCLP(presupuesto.gastado)} de ${formatCLP(presupuesto.montoTope)}',
                style: AppText.body(12, color: AppColors.textMuted),
              ),
              Text(
                '$pctDisplay%',
                style: AppText.body(12, weight: FontWeight.w600, color: barColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sheet para nuevo tope ─────────────────────────────────────────────────────

class _NuevoTopeSheet extends StatefulWidget {
  final Future<void> Function(String categoria, num monto) onGuardar;
  const _NuevoTopeSheet({required this.onGuardar});

  @override
  State<_NuevoTopeSheet> createState() => _NuevoTopeSheetState();
}

class _NuevoTopeSheetState extends State<_NuevoTopeSheet> {
  String _categoria = kCategorias.first;
  final _montoCtrl = TextEditingController();
  bool _guardando = false;

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
          Text('Fijar tope', style: AppText.display(18, weight: FontWeight.w600)),
          const SizedBox(height: 20),
          // Dropdown categoría
          DropdownButtonFormField<String>(
            value: _categoria,
            dropdownColor: AppColors.surface,
            decoration: InputDecoration(
              labelText: 'Categoría',
              labelStyle: AppText.body(14, color: AppColors.textMuted),
            ),
            items: kCategorias
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, style: AppText.body(14)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _categoria = v ?? _categoria),
          ),
          const SizedBox(height: 16),
          // Campo monto
          TextField(
            controller: _montoCtrl,
            keyboardType: TextInputType.number,
            style: AppText.body(15),
            decoration: InputDecoration(
              labelText: 'Monto tope (CLP)',
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
                : Text('Guardar', style: AppText.body(15, weight: FontWeight.w600, color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _guardar() async {
    final montoStr = _montoCtrl.text.trim().replaceAll('.', '').replaceAll(',', '');
    final monto = num.tryParse(montoStr);
    if (monto == null || monto <= 0) return;
    setState(() => _guardando = true);
    try {
      await widget.onGuardar(_categoria, monto);
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
            const Icon(Icons.savings_outlined, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 20),
            Text(
              'sin topes aún',
              style: AppText.display(18, weight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'fija tu primer presupuesto y cuida cada peso',
              style: AppText.body(14, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Fijar primer presupuesto',
                style: AppText.body(14, weight: FontWeight.w600, color: AppColors.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
