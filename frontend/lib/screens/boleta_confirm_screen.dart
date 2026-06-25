import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/boleta_draft.dart';
import '../models/categorias.dart';
import '../theme.dart';

/// Tipo de la función que guarda el gasto — inyectable para tests.
typedef GuardarGastoFn = Future<void> Function({
  required String comercio,
  required double monto,
  required String fecha,
  required String categoria,
});

/// Pantalla `/boleta` — confirmar y editar un draft extraído de una boleta.
///
/// Recibe [draft] con los datos pre-rellenados. El usuario puede editar
/// cualquier campo antes de pulsar "Guardar gasto", que llama a [onGuardar].
class BoletaConfirmScreen extends StatefulWidget {
  final BoletaDraft draft;
  final GuardarGastoFn onGuardar;

  const BoletaConfirmScreen({
    super.key,
    required this.draft,
    required this.onGuardar,
  });

  @override
  State<BoletaConfirmScreen> createState() => _BoletaConfirmScreenState();
}

class _BoletaConfirmScreenState extends State<BoletaConfirmScreen> {
  late final TextEditingController _comercioCtrl;
  late final TextEditingController _montoCtrl;
  late String _fecha;
  late String _categoria;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _comercioCtrl = TextEditingController(text: widget.draft.comercio);
    // Mostrar el monto como positivo (es gasto, monto es negativo)
    final montoAbs = widget.draft.monto.abs();
    _montoCtrl = TextEditingController(text: montoAbs.toStringAsFixed(0));
    _fecha = widget.draft.fecha;
    _categoria = widget.draft.categoria ?? kCategorias.first;
  }

  @override
  void dispose() {
    _comercioCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final inicial = DateTime.tryParse(_fecha) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _fecha =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _guardar() async {
    final comercio = _comercioCtrl.text.trim();
    if (comercio.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre del comercio')),
      );
      return;
    }
    final montoVal = double.tryParse(_montoCtrl.text.replaceAll('.', '').replaceAll(',', '.'));
    if (montoVal == null || montoVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await widget.onGuardar(
        comercio: comercio,
        monto: -montoVal, // siempre gasto (negativo)
        fecha: _fecha,
        categoria: _categoria,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textMuted, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Cancelar',
        ),
        title: Text('Confirmar boleta',
            style: AppText.display(18, weight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Icono decorativo ──────────────────────────────────────────
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.accent,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Revisa y edita si algo salió mal',
              style: AppText.body(14, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // ── Comercio ──────────────────────────────────────────────────
            _Label('Comercio'),
            const SizedBox(height: 6),
            TextField(
              controller: _comercioCtrl,
              style: AppText.body(15),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Ej: LIDER, Farmacias Cruz Verde…',
                hintStyle: AppText.body(15, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Monto ─────────────────────────────────────────────────────
            _Label('Monto total (\$)'),
            const SizedBox(height: 6),
            TextField(
              controller: _montoCtrl,
              style: AppText.amount(15),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                prefixText: '\$',
                prefixStyle: AppText.amount(15, color: AppColors.textMuted),
                hintText: '0',
                hintStyle: AppText.body(15, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Fecha ─────────────────────────────────────────────────────
            _Label('Fecha'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _seleccionarFecha,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: AppColors.textMuted, size: 16),
                    const SizedBox(width: 10),
                    Text(_fecha, style: AppText.body(15)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Categoría ─────────────────────────────────────────────────
            _Label('Categoría'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCategorias.map((cat) {
                final selected = cat == _categoria;
                return GestureDetector(
                  onTap: () => setState(() => _categoria = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.glass,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: AppText.body(
                        13,
                        weight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // ── Botones ───────────────────────────────────────────────────
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _guardando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Text(
                      'Guardar gasto',
                      style: AppText.body(
                        16,
                        weight: FontWeight.w600,
                        color: AppColors.onPrimary,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(
                'Cancelar',
                style: AppText.body(15, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pequeño label de sección ──────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppText.label(AppColors.textMuted),
      );
}
