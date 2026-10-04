import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/sign_up_request.dart';
import '../../../shared/widgets/auth_page.dart';
import '../../../core/network/api_exception.dart';
import '../application/auth_notifier.dart';

class SignInView extends ConsumerStatefulWidget {
  const SignInView({super.key});

  @override
  ConsumerState<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends ConsumerState<SignInView> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _submitting = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .signIn(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message
              : describeSignInError(e),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: 'Bienvenido',
      subtitle: 'Ingresa tus credenciales para continuar',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _usernameController,
              enabled: !_submitting,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: 'Usuario',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
              validator: RegistrationValidators.username,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              enabled: !_submitting,
              maxLength: 72,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _showPassword
                      ? 'Ocultar contraseña'
                      : 'Mostrar contraseña',
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              textInputAction: TextInputAction.done,
              obscureText: !_showPassword,
              onFieldSubmitted: (_) => _submit(),
              validator: RegistrationValidators.signInPassword,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ingresar'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/sign-up'),
              child: const Text('¿No tienes cuenta? Regístrate'),
            ),
          ],
        ),
      ),
    );
  }
}
