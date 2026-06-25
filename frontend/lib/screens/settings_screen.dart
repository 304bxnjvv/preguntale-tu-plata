import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/data_providers.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/orb.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _deleting = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'eliminar mis datos',
          style: AppText.display(20, weight: FontWeight.w700),
        ),
        content: Text(
          'esto borrará todas tus transacciones, historial de chat y archivos subidos. la acción no se puede deshacer.',
          style: AppText.body(14, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'cancelar',
              style: AppText.body(14, color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: Text(
              'eliminar todo',
              style: AppText.body(14, weight: FontWeight.w600, color: AppColors.negative),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(apiProvider).deleteAccountData();
      if (mounted) {
        await Supabase.instance.client.auth.signOut();
        // router listener will redirect to /login
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
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
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.negative.withValues(alpha: 0.9),
            content: Text(
              'ocurrió un error. intenta de nuevo.',
              style: AppText.body(14, color: AppColors.onPrimary),
            ),
          ),
        );
      }
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
        title: Text('ajustes', style: AppText.body(17, weight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Privacy section
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
                        const Icon(Icons.lock_outline, color: AppColors.accent, size: 18),
                        const SizedBox(width: 8),
                        Text('privacidad', style: AppText.label(AppColors.accent)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'no le pedimos permiso a tu banco. solo los archivos que tú subes.',
                      style: AppText.body(15),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'tus datos se borran automáticamente a los 30 días o cuando tú lo pidas. nunca los vendemos ni compartimos.',
                      style: AppText.body(14, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    // TODO: replace placeholder with live URL and add url_launcher
                    Text(
                      'leer política de privacidad →',
                      style: AppText.body(14,
                          color: AppColors.primary,
                          weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Orb accent
              const Center(child: Orb(size: 40)),
              const SizedBox(height: 16),
              Text(
                'zona peligrosa',
                style: AppText.label(AppColors.negative),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Delete button
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _deleting ? null : _confirmDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.negative,
                    side: BorderSide(
                        color: AppColors.negative.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    disabledForegroundColor:
                        AppColors.negative.withValues(alpha: 0.4),
                  ),
                  icon: _deleting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.negative.withValues(alpha: 0.5),
                          ),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 20),
                  label: Text(
                    _deleting ? 'eliminando...' : 'Eliminar mis datos',
                    style: AppText.body(16,
                        weight: FontWeight.w600, color: AppColors.negative),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Text(
                'esta acción es permanente e irreversible.',
                style: AppText.body(12, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
