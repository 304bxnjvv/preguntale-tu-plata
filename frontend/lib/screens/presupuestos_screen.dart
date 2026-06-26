import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_providers.dart';
import '../models/categorias.dart';
import '../theme.dart';
import '../services/api_service.dart';

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

class _NuevoTopeSheet extends ConsumerStatefulWidget {
  final Future<void> Function(String categoria, num monto) onGuardar;
  const _NuevoTopeSheet({required this.onGuardar});

  @override
  ConsumerState<_NuevoTopeSheet> createState() => _NuevoTopeSheetState();
}

class _NuevoTopeSheetState extends ConsumerState<_NuevoTopeSheet> {
  String? _categoria;
  final _montoCtrl = TextEditingController();
  bool _guardando = false;

  // Estado para crear categoría nueva
  bool _mostraNuevaCategoria = false;
  final _nuevaCatCtrl = TextEditingController();
  bool _creandoCat = false;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _nuevaCatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriasAsync = ref.watch(categoriasProvider);
    final todasCats = categoriasAsync.when(
      data: (d) => d.todas,
      loading: () => kCategorias,
      error: (_, __) => kCategorias,
    );
    // Si la categoría seleccionada ya no está en la lista, fallback al primero.
    final categoria = _categoria != null && todasCats.contains(_categoria)
        ? _categoria!
        : todasCats.first;

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
          // Dropdown categoría (usa categoriasProvider)
          DropdownButtonFormField<String>(
            value: category(todasCats, categoria),
            dropdownColor: AppColors.surface,
            decoration: InputDecoration(
              labelText: 'Categoría',
              labelStyle: AppText.body(14, color: AppColors.textMuted),
            ),
            items: todasCats
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, style: AppText.body(14)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _categoria = v ?? categoria),
          ),
          const SizedBox(height: 8),
          // Opción de crear nueva categoría
          if (!_mostraNuevaCategoria)
            TextButton.icon(
              key: const Key('btn_nueva_categoria'),
              onPressed: () => setState(() => _mostraNuevaCategoria = true),
              icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
              label: Text(
                '+ Nueva categoría',
                style: AppText.body(14, color: AppColors.primary),
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('field_nueva_categoria'),
                  controller: _nuevaCatCtrl,
                  style: AppText.body(15),
                  decoration: InputDecoration(
                    labelText: 'Nombre de la nueva categoría',
                    labelStyle: AppText.body(14, color: AppColors.textMuted),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _creandoCat
                            ? null
                            : () => setState(() {
                                  _mostraNuevaCategoria = false;
                                  _nuevaCatCtrl.clear();
                                }),
                        child: Text('Cancelar', style: AppText.body(14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _creandoCat ? null : _crearCategoria,
                        child: _creandoCat
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.onPrimary),
                              )
                            : Text('Crear',
                                style: AppText.body(14,
                                    weight: FontWeight.w600,
                                    color: AppColors.onPrimary)),
                      ),
                    ),
                  ],
                ),
              ],
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
            onPressed: _guardando ? null : () => _guardar(categoria),
            child: _guardando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                  )
                : Text('Guardar',
                    style:
                        AppText.body(15, weight: FontWeight.w600, color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }

  String category(List<String> lista, String fallback) =>
      lista.contains(fallback) ? fallback : lista.first;

  Future<void> _crearCategoria() async {
    final nombre = _nuevaCatCtrl.text.trim();
    if (nombre.isEmpty) return;
    setState(() => _creandoCat = true);
    try {
      await ref.read(apiProvider).crearCategoria(nombre);
      ref.invalidate(categoriasProvider);
      setState(() {
        _categoria = nombre;
        _mostraNuevaCategoria = false;
        _nuevaCatCtrl.clear();
        _creandoCat = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      if (mounted) setState(() => _creandoCat = false);
    } catch (_) {
      if (mounted) setState(() => _creandoCat = false);
    }
  }

  Future<void> _guardar(String categoria) async {
    final montoStr = _montoCtrl.text.trim().replaceAll('.', '').replaceAll(',', '');
    final monto = num.tryParse(montoStr);
    if (monto == null || monto <= 0) return;
    setState(() => _guardando = true);
    try {
      await widget.onGuardar(categoria, monto);
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
