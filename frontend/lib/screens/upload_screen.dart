import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/data_providers.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/orb.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});
  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  bool _cargando = false;
  String? _msg;
  bool _exito = false;

  Future<void> _subir() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'csv', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (res == null || res.files.single.bytes == null) return;
    setState(() {
      _cargando = true;
      _msg = null;
      _exito = false;
    });
    try {
      final r = await ref.read(apiProvider).uploadFile(
            res.files.single.bytes!, res.files.single.name);
      ref.invalidate(summaryProvider);
      ref.invalidate(transactionsProvider);
      if (mounted) {
        setState(() {
          _msg = '${r.count} transacciones cargadas';
          _exito = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _exito = false;
          _msg = e.statusCode == 429
              ? 'llegaste al límite de subidas del mes. vuelve el próximo.'
              : e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(
          'subir archivo',
          style: AppText.body(17, weight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Orb + título
              Center(
                child: Column(
                  children: [
                    Orb(size: 64, thinking: _cargando),
                    const SizedBox(height: 20),
                    Text(
                      'súbeme tu cartola',
                      style: AppText.display(26, weight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'la leo con IA y te cuento en qué se fue la plata',
                      style: AppText.body(15, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Card glass — instrucciones
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿qué puedes subir?',
                      style: AppText.label(AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    _FileTypeRow(
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'cartola PDF o CSV',
                      sublabel: 'descárgala directo desde tu banco',
                    ),
                    const SizedBox(height: 10),
                    _FileTypeRow(
                      icon: Icons.camera_alt_outlined,
                      label: 'foto de boleta',
                      sublabel: 'JPG o PNG, que se lea el monto',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Card glass — privacidad/confianza
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline, color: AppColors.accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'tus archivos no salen de aquí. no nos conectamos a tu banco.',
                        style: AppText.body(14, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Botón primario
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _cargando ? null : _subir,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: _cargando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Icon(Icons.upload_file_outlined, size: 20),
                  label: Text(
                    _cargando ? 'leyendo archivo...' : 'elegir archivo',
                    style: AppText.body(16, weight: FontWeight.w600, color: AppColors.onPrimary),
                  ),
                ),
              ),

              // Mensaje de resultado
              if (_msg != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: (_exito ? AppColors.positive : AppColors.negative)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (_exito ? AppColors.positive : AppColors.negative)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _exito
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        color: _exito ? AppColors.positive : AppColors.negative,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _msg!,
                          style: AppText.body(
                            14,
                            color: _exito ? AppColors.positive : AppColors.negative,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FileTypeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;

  const _FileTypeRow({
    required this.icon,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.body(14, weight: FontWeight.w600)),
            Text(sublabel, style: AppText.body(12, color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}
