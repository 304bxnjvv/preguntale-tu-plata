import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets/orb.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registrando = false;
  bool _cargando = false;
  bool _consentido = false; // checkbox 18+ solo en registro
  String? _error;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validar() {
    if (!_emailRe.hasMatch(_email.text.trim())) return 'ingresa un email válido';
    if (_password.text.length < 6) return 'la contraseña debe tener al menos 6 caracteres';
    if (_registrando && !_consentido) {
      return 'debes confirmar que eres mayor de 18 años y aceptar los términos';
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _validar();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _cargando = true;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (_registrando) {
        await auth.signUp(email: _email.text.trim(), password: _password.text);
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
      }
      // El redirect del router (authState) lleva al dashboard automáticamente.
    } on AuthException catch (e) {
      setState(() => _error = _traducir(e.message));
    } catch (_) {
      setState(() => _error = 'no se pudo conectar. intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _traducir(String m) {
    final low = m.toLowerCase();
    if (low.contains('invalid login')) return 'email o contraseña incorrectos';
    if (low.contains('already registered')) return 'este email ya está registrado';
    if (low.contains('confirm')) return 'revisa tu correo para confirmar la cuenta';
    return m;
  }

  bool get _submitEnabled {
    if (_cargando) return false;
    if (_registrando && !_consentido) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Orbe presencia de marca
                const Center(child: Orb(size: 64, thinking: false)),
                const SizedBox(height: 20),

                // Título
                Text(
                  'pregúntale a tu plata',
                  textAlign: TextAlign.center,
                  style: AppText.display(26, weight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                // Hero privacidad
                Text(
                  'la única app que no le pide permiso a tu banco',
                  textAlign: TextAlign.center,
                  style: AppText.body(15,
                      weight: FontWeight.w500, color: AppColors.accent),
                ),
                const SizedBox(height: 8),
                Text(
                  'súbeme tu cartola y te cuento la verdad — sin retos.\ntus archivos no salen de aquí.',
                  textAlign: TextAlign.center,
                  style: AppText.body(14, color: AppColors.textMuted),
                ),
                const SizedBox(height: 28),

                // Tabs Entrar / Registrarse
                _TabToggle(
                  registrando: _registrando,
                  onChanged: (v) => setState(() {
                    _registrando = v;
                    _error = null;
                    if (!v) _consentido = false;
                  }),
                ),
                const SizedBox(height: 20),

                // Campo email
                TextField(
                  key: const Key('email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: AppText.body(15),
                  decoration: const InputDecoration(
                    hintText: 'tu email',
                    prefixIcon: Icon(Icons.mail_outline_rounded,
                        color: AppColors.textMuted, size: 20),
                  ),
                ),
                const SizedBox(height: 12),

                // Campo contraseña
                TextField(
                  key: const Key('password'),
                  controller: _password,
                  obscureText: true,
                  style: AppText.body(15),
                  decoration: const InputDecoration(
                    hintText: 'contraseña',
                    prefixIcon: Icon(Icons.lock_outline_rounded,
                        color: AppColors.textMuted, size: 20),
                  ),
                ),

                // Checkbox 18+ solo en modo registro
                if (_registrando) ...[
                  const SizedBox(height: 16),
                  _ConsentCheckbox(
                    key: const Key('consent_checkbox'),
                    checked: _consentido,
                    onChanged: (v) => setState(() => _consentido = v),
                    onPrivacidad: () => context.push('/legal/privacidad'),
                    onTerminos: () => context.push('/legal/terminos'),
                  ),
                ],

                // Mensaje de error
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.negative, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppText.body(13, color: AppColors.negative),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),

                // Botón primario
                FilledButton(
                  key: const Key('submit'),
                  onPressed: _submitEnabled ? _submit : null,
                  child: _cargando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary),
                        )
                      : Text(
                          _registrando ? 'Crear cuenta' : 'Entrar',
                          style: AppText.body(16,
                              weight: FontWeight.w600,
                              color: AppColors.onPrimary),
                        ),
                ),
                const SizedBox(height: 24),

                // Nota tranquilizadora al pie
                Text(
                  'sin tarjeta de crédito · cancela cuando quieras',
                  textAlign: TextAlign.center,
                  style: AppText.label(AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Checkbox de consentimiento mayor de 18 años con links a legal.
class _ConsentCheckbox extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool> onChanged;
  final VoidCallback onPrivacidad;
  final VoidCallback onTerminos;

  const _ConsentCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
    required this.onPrivacidad,
    required this.onTerminos,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          key: const Key('consent_check'),
          value: checked,
          activeColor: AppColors.primary,
          onChanged: (v) => onChanged(v ?? false),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: RichText(
              text: TextSpan(
                style: AppText.body(13, color: AppColors.textMuted),
                children: [
                  const TextSpan(
                      text: 'Soy mayor de 18 años y acepto la '),
                  TextSpan(
                    text: 'Política de Privacidad',
                    style: AppText.body(13,
                        color: AppColors.primary,
                        weight: FontWeight.w600),
                    recognizer: TapGestureRecognizer()..onTap = onPrivacidad,
                  ),
                  const TextSpan(text: ' y los '),
                  TextSpan(
                    text: 'Términos y Condiciones',
                    style: AppText.body(13,
                        color: AppColors.primary,
                        weight: FontWeight.w600),
                    recognizer: TapGestureRecognizer()..onTap = onTerminos,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Toggle personalizado Entrar / Registrarse con el estilo del design system.
class _TabToggle extends StatelessWidget {
  final bool registrando;
  final ValueChanged<bool> onChanged;

  const _TabToggle({required this.registrando, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Entrar',
            active: !registrando,
            onTap: () => onChanged(false),
            isLeft: true,
          ),
          _Tab(
            label: 'Registrarse',
            active: registrando,
            onTap: () => onChanged(true),
            isLeft: false,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool isLeft;

  const _Tab({
    required this.label,
    required this.active,
    required this.onTap,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: isLeft ? const Radius.circular(13) : Radius.zero,
              right: !isLeft ? const Radius.circular(13) : Radius.zero,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.body(
              14,
              weight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppColors.onPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
