import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/data_providers.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/orb.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _agreed = false;
  bool _loading = false;

  Future<void> _proceed() async {
    if (!_agreed || _loading) return;
    setState(() => _loading = true);
    try {
      final url = await ref.read(apiProvider).checkout();
      if (!mounted) return;
      // url_launcher not in pubspec — show in dialog instead
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'te llevamos al pago',
            style: AppText.display(20, weight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'copia este enlace en tu navegador para completar el pago:',
                style: AppText.body(14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              SelectableText(
                url,
                style: AppText.body(13, color: AppColors.primary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cerrar', style: AppText.body(14, color: AppColors.textMuted)),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 503) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              'el cobro estará disponible muy pronto 🙌',
              style: AppText.body(14),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.negative.withValues(alpha: 0.9),
            content: Text(
              e.message,
              style: AppText.body(14, color: AppColors.onPrimary),
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.negative.withValues(alpha: 0.9),
          content: Text(
            'ocurrió un error. intenta de nuevo.',
            style: AppText.body(14, color: AppColors.onPrimary),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textMuted),
          onPressed: () => context.pop(),
        ),
        title: Text('autorización de cobro', style: AppText.body(17, weight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Orb(size: 60)),
              const SizedBox(height: 24),
              // SERNAC consent glass card
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
                    Row(
                      children: [
                        const Icon(Icons.gavel_rounded, color: AppColors.accent, size: 18),
                        const SizedBox(width: 8),
                        Text('autorización SERNAC', style: AppText.label(AppColors.accent)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Autorizo el cobro automático de \$3.990 al mes una vez terminada mi prueba gratis. Puedo cancelar cuando quiera desde la app, sin trámites.',
                      style: AppText.body(15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Checkbox
              GestureDetector(
                onTap: () => setState(() => _agreed = !_agreed),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _agreed ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _agreed ? AppColors.primary : AppColors.textMuted,
                          width: 1.5,
                        ),
                      ),
                      child: _agreed
                          ? const Icon(Icons.check_rounded, size: 16, color: AppColors.onPrimary)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'entiendo y autorizo',
                        style: AppText.body(15, weight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: (_agreed && !_loading) ? _proceed : null,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Text(
                        'continuar al pago',
                        style: AppText.body(16, weight: FontWeight.w600, color: AppColors.onPrimary),
                      ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.pop(),
                child: Text('volver', style: AppText.body(15, color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
