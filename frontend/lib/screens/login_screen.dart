import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String? _error;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validar() {
    if (!_emailRe.hasMatch(_email.text.trim())) return 'Ingresa un email válido';
    if (_password.text.length < 6) return 'La contraseña debe tener al menos 6 caracteres';
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
      setState(() => _error = 'No se pudo conectar. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _traducir(String m) {
    final low = m.toLowerCase();
    if (low.contains('invalid login')) return 'Email o contraseña incorrectos';
    if (low.contains('already registered')) return 'Este email ya está registrado';
    if (low.contains('confirm')) return 'Revisa tu correo para confirmar la cuenta';
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Pregúntale a tu plata',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Entrar')),
                    ButtonSegment(value: true, label: Text('Registrarse')),
                  ],
                  selected: {_registrando},
                  onSelectionChanged: (s) => setState(() {
                    _registrando = s.first;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('password'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFFF85149))),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('submit'),
                  onPressed: _cargando ? null : _submit,
                  child: _cargando
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_registrando ? 'Crear cuenta' : 'Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
