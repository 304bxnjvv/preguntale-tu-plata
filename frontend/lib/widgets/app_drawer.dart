import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../providers/data_providers.dart';
import '../services/boleta_action.dart';
import 'orb.dart';

/// Drawer de navegación principal de la app.
/// [actual] es la ruta activa (ej. '/dashboard') para resaltar el ítem correspondiente.
class AppDrawer extends ConsumerWidget {
  final String actual;

  const AppDrawer({super.key, required this.actual});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);

    // Estado de suscripción como texto descriptivo
    final estadoSub = subscription.whenOrNull(
      data: (sub) {
        if (sub.estado == 'trial') {
          return 'te quedan ${sub.diasRestantes} días de prueba';
        }
        if (sub.estado == 'activa') {
          return 'plan activo';
        }
        if (sub.estado == 'vencida') {
          return 'prueba vencida';
        }
        return null;
      },
    );

    return Drawer(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  const Orb(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tu plata', style: AppText.display(20, weight: FontWeight.w700)),
                        if (estadoSub != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            estadoSub,
                            style: AppText.body(12, color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: AppColors.border, height: 1),

            // ── Ítems de navegación ───────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.home_rounded,
                    label: 'Inicio',
                    activo: actual == '/dashboard',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/dashboard');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Preguntar',
                    activo: actual == '/chat',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/chat');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.pie_chart_outline_rounded,
                    label: 'Presupuestos',
                    activo: actual == '/presupuestos',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/presupuestos');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.flag_outlined,
                    label: 'Metas',
                    activo: actual == '/metas',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/metas');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.notifications_none_rounded,
                    label: 'Alertas',
                    activo: actual == '/alertas',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/alertas');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.upload_file_rounded,
                    label: 'Subir cartola',
                    activo: actual == '/upload',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/upload');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.receipt_long_rounded,
                    label: 'Escanear boleta',
                    activo: false,
                    onTap: () {
                      Navigator.pop(context);
                      escanearBoleta(context, ref);
                    },
                  ),

                  const SizedBox(height: 4),
                  Divider(color: AppColors.border, height: 1, indent: 16, endIndent: 16),
                  const SizedBox(height: 4),

                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Ajustes',
                    activo: actual == '/ajustes',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/ajustes');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.logout_rounded,
                    label: 'Cerrar sesión',
                    activo: false,
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      Supabase.instance.client.auth.signOut();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ítem individual del drawer ────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool activo;
  final bool isDestructive;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.activo,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconColor;
    final Color textColor;
    final Color bgColor;

    if (isDestructive) {
      iconColor = AppColors.negative;
      textColor = AppColors.negative;
      bgColor = Colors.transparent;
    } else if (activo) {
      iconColor = AppColors.primary;
      textColor = AppColors.primary;
      bgColor = AppColors.glass;
    } else {
      iconColor = AppColors.textMuted;
      textColor = AppColors.text;
      bgColor = Colors.transparent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: activo
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  )
                : null,
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: AppText.body(
                    15,
                    weight: activo ? FontWeight.w600 : FontWeight.w400,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
