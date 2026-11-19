import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Registro e inicio de sesión: Google, Facebook o correo y contraseña.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _register = true;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AuthService.friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    _run(() => _register
        ? _auth.registerWithEmail(
            name: _name.text,
            email: _email.text,
            password: _password.text,
            phone: _phone.text,
          )
        : _auth.signInWithEmail(_email.text, _password.text));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: const Color(0xFF0F766E), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.home_outlined, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text('Roomies', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 24),
                Text(_register ? 'Crea tu cuenta' : 'Inicia sesión',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Reparte las cuentas del depa sin discusiones.', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _run(_auth.signInWithGoogle),
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Google'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _run(_auth.signInWithFacebook),
                      icon: const Icon(Icons.facebook),
                      label: const Text('Facebook'),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                const Row(children: [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('o con tu correo')),
                  Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),
                if (_register) ...[
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nombre completo'),
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Ingresa tu nombre' : null,
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Correo electrónico'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Correo no válido' : null,
                ),
                const SizedBox(height: 14),
                if (_register) ...[
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Celular (opcional)'),
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'Contraseña', helperText: _register ? 'Mínimo 8 caracteres' : null),
                  validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text(_register ? 'Crear cuenta' : 'Entrar'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _register = !_register),
                  child: Text(_register ? '¿Ya tienes cuenta? Inicia sesión' : '¿No tienes cuenta? Regístrate'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
