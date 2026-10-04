import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth_notifier.dart';
import '../domain/user.dart';

/// Mirrors PASSWORD_POLICY_PATTERN in sign-up.ts: 12-20 chars, at least one
/// uppercase letter and one special character.
final _passwordPolicyPattern = RegExp(
  r'^(?=.*[A-Z])(?=.*[^A-Za-z0-9\s]).{12,20}$',
);
const _passwordPolicyHint =
    '12 a 20 caracteres, con al menos una mayúscula y un carácter especial.';

class SignUpView extends ConsumerStatefulWidget {
  const SignUpView({super.key});

  @override
  ConsumerState<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends ConsumerState<SignUpView> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  static const _role = kRoleNurse;
  String? _error;
  String? _success;
  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .signUp(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
            role: _role,
          );
      setState(() => _success = 'Cuenta creada. Ahora puedes iniciar sesión.');
    } catch (e) {
      setState(() => _error = _describeSignUpError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Mirrors toErrorKey() in sign-up.ts: 409 and 400 need distinct messages
  /// so a taken username is never confused with a rejected weak password.
  String _describeSignUpError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 409) return 'Ese nombre de usuario no está disponible.';
      if (status == 400) {
        return 'Revisa los datos ingresados. La contraseña debe tener entre '
            '12 y 20 caracteres, con al menos una mayúscula y un carácter '
            'especial.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'No se pudo conectar con el servidor. Verifica tu conexión.';
      }
    }
    return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/sign-in'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Crear cuenta clínica',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(labelText: 'Usuario'),
                        validator: (value) =>
                            (value == null || value.trim().length < 3)
                            ? 'Mínimo 3 caracteres'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                        ),
                        obscureText: true,
                        validator: (value) =>
                            (value == null ||
                                !_passwordPolicyPattern.hasMatch(value))
                            ? 'La contraseña debe tener entre 12 y 20 '
                                  'caracteres, con al menos una mayúscula y '
                                  'un carácter especial.'
                            : null,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          _passwordPolicyHint,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contraseña',
                        ),
                        obscureText: true,
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (_success != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _success!,
                          style: const TextStyle(color: Colors.green),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Registrarme'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
