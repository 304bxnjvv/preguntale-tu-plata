import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/data_providers.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/orb.dart';
import '../utils/download_helper.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _deleting = false;
  bool _cancelling = false;
  bool _deletingCuenta = false;
  bool _exporting = false;

  // ── helpers ──────────────────────────────────────────────────────────────────

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor:
          error ? AppColors.negative.withValues(alpha: 0.9) : AppColors.surface,
      content: Text(
        msg,
        style: AppText.body(14,
            color: error ? AppColors.onPrimary : AppColors.text),
      ),
    ));
  }

  // ── Editar nombre ────────────────────────────────────────────────────────────

  Future<void> _editarNombre() async {
    final actual = Supabase.instance.client.auth.currentUser
            ?.userMetadata?['nombre'] as String? ??
        '';
    final ctrl = TextEditingController(text: actual);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            Text('editar nombre', style: AppText.display(20, weight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppText.body(15),
          decoration: const InputDecoration(hintText: 'tu nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('cancelar', style: AppText.body(14, color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('guardar',
                style: AppText.body(14,
                    color: AppColors.primary, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(data: {'nombre': ctrl.text.trim()}));
      _snack('nombre actualizado');
    } catch (_) {
      _snack('no se pudo actualizar el nombre', error: true);
    }
  }

  // ── Cambiar contraseña ────────────────────────────────────────────────────────

  Future<void> _cambiarPassword() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('nueva contraseña',
              style: AppText.display(20, weight: FontWeight.w700)),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            autofocus: true,
            style: AppText.body(15),
            decoration:
                const InputDecoration(hintText: 'mínimo 6 caracteres'),
            onChanged: (_) => setS(() {}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancelar',
                  style: AppText.body(14, color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: ctrl.text.length >= 6
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: Text('cambiar',
                  style: AppText.body(14,
                      color: AppColors.primary, weight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: ctrl.text));
      _snack('contraseña actualizada');
    } catch (_) {
      _snack('no se pudo cambiar la contraseña', error: true);
    }
  }

  // ── Exportar datos ───────────────────────────────────────────────────────────

  Future<void> _exportarDatos() async {
    setState(() => _exporting = true);
    try {
      final datos = await ref.read(apiProvider).exportarDatos();
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'tus datos están listos',
                style: AppText.display(20, weight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'elige cómo quieres acceder a tu información',
                style: AppText.body(14, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: datos));
                  if (ctx.mounted) Navigator.pop(ctx);
                  _snack('copiado al portapapeles');
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(
                  'copiar al portapapeles',
                  style: AppText.body(15,
                      weight: FontWeight.w600, color: AppColors.onPrimary),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  downloadJson(datos, 'mis-datos-preguntale.json');
                  Navigator.pop(ctx);
                  _snack('descarga iniciada');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  'descargar JSON',
                  style: AppText.body(15, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack('no se pudieron exportar los datos', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Borrar datos (sin cerrar sesión) ─────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'eliminar mis datos',
            style: AppText.display(20, weight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'esto borrará tus transacciones, tarjeta, presupuestos, metas, historial de chat y archivos subidos. tu cuenta queda activa. la acción no se puede deshacer.',
                style: AppText.body(14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              Text(
                'escribe "borrar" para confirmar',
                style: AppText.body(13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                style: AppText.body(15),
                decoration: InputDecoration(
                  hintText: 'borrar',
                  hintStyle: AppText.body(15, color: AppColors.border),
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
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
              onPressed: controller.text.trim().toLowerCase() == 'borrar'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: TextButton.styleFrom(foregroundColor: AppColors.negative),
              child: Text(
                'eliminar todo',
                style: AppText.body(14,
                    weight: FontWeight.w600, color: AppColors.negative),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(apiProvider).deleteAccountData();
      if (mounted) {
        ref.invalidate(summaryProvider);
        ref.invalidate(transactionsProvider);
        ref.invalidate(chatHistoryProvider);
        ref.invalidate(suscripcionesProvider);
        ref.invalidate(comparativoProvider);
        ref.invalidate(finScoreProvider);
        ref.invalidate(tarjetaProvider);
        ref.invalidate(presupuestosProvider);
        ref.invalidate(metasProvider);
        ref.invalidate(alertasProvider);
        ref.invalidate(forecastProvider);
        ref.invalidate(resumenSemanalProvider);
        setState(() => _deleting = false);
        _snack('listo, borramos tus datos.');
        context.go('/dashboard');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        _snack(e.message, error: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        _snack('ocurrió un error. intenta de nuevo.', error: true);
      }
    }
  }

  // ── Borrar cuenta completa ────────────────────────────────────────────────────

  Future<void> _confirmDeleteCuenta() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'borrar mi cuenta',
            style: AppText.display(20, weight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'se eliminarán todos tus datos y tu acceso a la app. esta acción no se puede deshacer.',
                style: AppText.body(14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              Text(
                'escribe "borrar" para confirmar',
                style: AppText.body(13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                style: AppText.body(15),
                decoration: InputDecoration(
                  hintText: 'borrar',
                  hintStyle: AppText.body(15, color: AppColors.border),
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
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
              onPressed: controller.text.trim().toLowerCase() == 'borrar'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: TextButton.styleFrom(foregroundColor: AppColors.negative),
              child: Text(
                'borrar cuenta',
                style: AppText.body(14,
                    weight: FontWeight.w600, color: AppColors.negative),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingCuenta = true);
    try {
      final result = await ref.read(apiProvider).eliminarCuenta();
      final authEliminada = result['auth_eliminada'] as bool? ?? false;
      if (mounted) {
        setState(() => _deletingCuenta = false);
        if (authEliminada) {
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            _snack('cuenta eliminada');
            context.go('/login');
          }
        } else {
          _snack(
              'borramos tus datos; tu acceso se eliminará pronto',
              error: false);
          await Supabase.instance.client.auth.signOut();
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _deletingCuenta = false);
        _snack(e.message, error: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _deletingCuenta = false);
        _snack('ocurrió un error. intenta de nuevo.', error: true);
      }
    }
  }

  // ── Cancelar suscripción ─────────────────────────────────────────────────────

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('cancelar suscripción',
            style: AppText.display(20, weight: FontWeight.w700)),
        content: Text(
          '¿seguro que quieres cancelar? seguirás teniendo acceso hasta que termine el período pagado.',
          style: AppText.body(14, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('volver', style: AppText.body(14, color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: Text('cancelar suscripción',
                style: AppText.body(14,
                    weight: FontWeight.w600, color: AppColors.negative)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await ref.read(apiProvider).cancelSubscription();
      if (mounted) {
        ref.invalidate(subscriptionProvider);
        _snack('suscripción cancelada');
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, error: true);
    } catch (_) {
      if (mounted) _snack('ocurrió un error. intenta de nuevo.', error: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────────────

  Widget _section({required String label, IconData? icon, required List<Widget> children}) {
    return Container(
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
              if (icon != null) ...[
                Icon(icon, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label, style: AppText.label(AppColors.accent)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, VoidCallback onTap, {Widget? trailing}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppText.body(15))),
            trailing ??
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(color: AppColors.border, height: 1);

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(subscriptionProvider);
    String email = '—';
    try {
      email = Supabase.instance.client.auth.currentUser?.email ?? '—';
    } catch (_) {}

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
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Mi cuenta ───────────────────────────────────────────────
              _section(
                label: 'mi cuenta',
                icon: Icons.person_outline_rounded,
                children: [
                  // Email read-only
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.mail_outline_rounded,
                            color: AppColors.textMuted, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(email,
                              style: AppText.body(14,
                                  color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                  ),
                  _divider(),
                  _row('Editar nombre', _editarNombre),
                  _divider(),
                  _row('Cambiar contraseña', _cambiarPassword),
                ],
              ),

              const SizedBox(height: 16),

              // ── Mis datos ────────────────────────────────────────────────
              _section(
                label: 'mis datos',
                icon: Icons.storage_outlined,
                children: [
                  _row(
                    _exporting ? 'exportando...' : 'Exportar mis datos',
                    _exporting ? () {} : _exportarDatos,
                    trailing: _exporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.download_outlined,
                            color: AppColors.textMuted, size: 20),
                  ),
                  _divider(),
                  _row(
                    _deleting ? 'eliminando...' : 'Eliminar mis datos',
                    _deleting ? () {} : _confirmDelete,
                    trailing: _deleting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.negative.withValues(alpha: 0.6),
                            ),
                          )
                        : Icon(Icons.delete_outline_rounded,
                            color: AppColors.negative.withValues(alpha: 0.7),
                            size: 20),
                  ),
                  _divider(),
                  _row('Política de privacidad',
                      () => context.push('/legal/privacidad')),
                  _divider(),
                  _row('Términos y condiciones',
                      () => context.push('/legal/terminos')),
                ],
              ),

              const SizedBox(height: 16),

              // ── Privacidad block ─────────────────────────────────────────
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
                        const Icon(Icons.lock_outline,
                            color: AppColors.accent, size: 18),
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
                      'tus datos se borran automáticamente al 1 año o cuando tú lo pidas. nunca los vendemos ni compartimos.',
                      style: AppText.body(14, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Suscripción ──────────────────────────────────────────────
              subscription.whenOrNull(
                    data: (sub) => sub.estado == 'activa'
                        ? _section(
                            label: 'suscripción',
                            icon: Icons.star_outline_rounded,
                            children: [
                              SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed:
                                      _cancelling ? null : _confirmCancel,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textMuted,
                                    side: BorderSide(color: AppColors.border),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                  icon: _cancelling
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.textMuted),
                                        )
                                      : const Icon(Icons.cancel_outlined,
                                          size: 20),
                                  label: Text(
                                    _cancelling
                                        ? 'cancelando...'
                                        : 'cancelar suscripción',
                                    style: AppText.body(15,
                                        weight: FontWeight.w600,
                                        color: AppColors.textMuted),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ) ??
                  const SizedBox.shrink(),

              const SizedBox(height: 24),

              // ── Zona peligrosa ────────────────────────────────────────────
              const Center(child: Orb(size: 40)),
              const SizedBox(height: 12),
              Text(
                'zona peligrosa',
                style: AppText.label(AppColors.negative),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed:
                      _deletingCuenta ? null : _confirmDeleteCuenta,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.negative,
                    side: BorderSide(
                        color: AppColors.negative.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    disabledForegroundColor:
                        AppColors.negative.withValues(alpha: 0.4),
                  ),
                  icon: _deletingCuenta
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                AppColors.negative.withValues(alpha: 0.5),
                          ),
                        )
                      : const Icon(Icons.person_remove_outlined, size: 20),
                  label: Text(
                    _deletingCuenta
                        ? 'eliminando...'
                        : 'Borrar mi cuenta completa',
                    style: AppText.body(16,
                        weight: FontWeight.w600,
                        color: AppColors.negative),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Text(
                'esta acción es permanente e irreversible.',
                style: AppText.body(12, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
