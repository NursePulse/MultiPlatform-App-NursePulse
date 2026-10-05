import '../../../core/localization/app_strings.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/auth_page.dart';
import '../application/auth_notifier.dart';
import '../domain/sign_up_request.dart';

class SignUpView extends ConsumerStatefulWidget {
  const SignUpView({super.key});

  @override
  ConsumerState<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends ConsumerState<SignUpView> {
  final _formKey = GlobalKey<FormState>();
  final _fields = {
    for (final key in [
      'username',
      'firstName',
      'lastName',
      'phone',
      'age',
      'email',
      'password',
      'confirm',
    ])
      key: TextEditingController(),
  };

  String _role = 'ROLE_NURSE';
  String? _error;
  bool _submitting = false;
  bool _registered = false;
  bool _showPassword = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || _registered) return;

    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      final request = SignUpRequest.fromForm(
        username: _fields['username']!.text,
        password: _fields['password']!.text,
        firstName: _fields['firstName']!.text,
        lastName: _fields['lastName']!.text,
        phone: _fields['phone']!.text,
        age: _fields['age']!.text,
        email: _fields['email']!.text,
        role: _role,
      );

      await ref.read(registrationSubmitProvider)(request);

      if (mounted) {
        _fields['password']!.clear();
        _fields['confirm']!.clear();
        setState(() => _registered = true);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _describeError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _describeError(Object error) {
    if (error is FormatException) return error.message;

    if (error is DioException) {
      final body = error.response?.data;
      final messages = body is Map
          ? [
              body['details'],
              body['detail'],
              body['message'],
            ].whereType<String>().where((s) => s.trim().isNotEmpty).toList()
          : <String>[];

      if (error.response?.statusCode == 409) {
        final reason = messages.join(' ').toLowerCase();
        if (reason.contains('email') || reason.contains('correo')) {
          return 'Ese correo ya está registrado.';
        }
        if (reason.contains('phone') || reason.contains('teléfono')) {
          return 'Ese teléfono ya está registrado.';
        }
        return 'Ese nombre de usuario no está disponible.';
      }

      if (error.response?.statusCode == 400) {
        return messages.isNotEmpty
            ? messages.first
            : 'El servidor rechazó los datos. Revisa los campos del formulario.';
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'El servidor demoró demasiado. Intenta de nuevo.';
      }

      if (error.type == DioExceptionType.connectionError) {
        return 'No se pudo conectar con el servidor. Verifica tu conexión.';
      }
    }

    return 'No se pudo crear la cuenta. Intenta de nuevo.';
  }

  Widget _field(
    String key,
    String label,
    String? Function(String?) validator, {
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey('register-$key'),
      controller: _fields[key],
      validator: (value) => context.validation(validator(value)),
      enabled: !_submitting,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: context.tr(label),
        counterText: '',
      ),
    ),
  );

  Widget _passwordField({required bool confirmation}) {
    final visible = confirmation ? _showConfirm : _showPassword;

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey(confirmation ? 'register-confirm' : 'register-password'),
        controller: _fields[confirmation ? 'confirm' : 'password'],
        enabled: !_submitting,
        obscureText: !visible,
        enableSuggestions: false,
        autocorrect: false,
        maxLength: 20,
        textInputAction: confirmation
            ? TextInputAction.done
            : TextInputAction.next,
        onFieldSubmitted: confirmation ? (_) => _submit() : null,
        validator: (value) => context.validation(
          confirmation
              ? RegistrationValidators.confirmPassword(
                  value,
                  _fields['password']!.text,
                )
              : RegistrationValidators.password(value),
        ),
        decoration: InputDecoration(
          labelText: context.tr(
            confirmation ? 'Confirmar contraseña' : 'Contraseña',
          ),
          counterText: '',
          suffixIcon: IconButton(
            tooltip: context.tr(
              visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
            ),
            onPressed: _submitting
                ? null
                : () => setState(() {
                    if (confirmation) {
                      _showConfirm = !_showConfirm;
                    } else {
                      _showPassword = !_showPassword;
                    }
                  }),
            icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = [
      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ ]')),
    ];

    return AuthPage(
      title: 'Crear cuenta clínica',
      subtitle: 'Completa tus datos para solicitar acceso a NursePulse',
      onBack: () => context.go('/sign-in'),
      child: _registered
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 48),
                SizedBox(height: 16),
                Text(
                  context.tr(
                    'Cuenta creada para ${_fields['email']!.text.trim()}.',
                  ),
                ),
                Text(
                  context.tr(
                    'Te enviamos un correo para confirmarla. Abre el '
                    'enlace antes de iniciar sesión.',
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/sign-in'),
                  child: Text(context.tr('Ir a iniciar sesión')),
                ),
              ],
            )
          : Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field(
                    'username',
                    'Usuario',
                    RegistrationValidators.username,
                    maxLength: 50,
                  ),
                  _field(
                    'firstName',
                    'Nombres',
                    RegistrationValidators.name,
                    maxLength: 20,
                    inputFormatters: names,
                  ),
                  _field(
                    'lastName',
                    'Apellidos',
                    RegistrationValidators.name,
                    maxLength: 20,
                    inputFormatters: names,
                  ),
                  _field(
                    'phone',
                    'Teléfono',
                    RegistrationValidators.phone,
                    maxLength: 9,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  _field(
                    'age',
                    'Edad',
                    RegistrationValidators.age,
                    maxLength: 3,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) =>
                            RegExp(r'^[0-9]{0,3}$').hasMatch(newValue.text)
                            ? newValue
                            : oldValue,
                      ),
                    ],
                  ),
                  _field(
                    'email',
                    'Correo electrónico',
                    RegistrationValidators.email,
                    maxLength: 254,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('register-role'),
                    initialValue: _role,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.tr('Rol clínico'),
                    ),
                    validator: (value) =>
                        context.validation(RegistrationValidators.role(value)),
                    items: [
                      DropdownMenuItem(
                        value: 'ROLE_NURSE',
                        child: Text(context.tr('Enfermería')),
                      ),
                      DropdownMenuItem(
                        value: 'ROLE_DOCTOR',
                        child: Text(context.tr('Medicina')),
                      ),
                    ],
                    onChanged: _submitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _role = value);
                            }
                          },
                  ),
                  SizedBox(height: 16),
                  _passwordField(confirmation: false),
                  Text(
                    context.tr(
                      '12–20 caracteres, una mayúscula, un número y un símbolo.',
                    ),
                  ),
                  SizedBox(height: 12),
                  _passwordField(confirmation: true),
                  if (_error != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        context.tr(_error!),
                        key: ValueKey('register-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton(
                    key: ValueKey('register-submit'),
                    onPressed: _submitting ? null : _submit,
                    child: Text(
                      context.tr(
                        _submitting ? 'Creando cuenta…' : 'Registrarme',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/sign-in'),
                    child: Text(context.tr('Ya tengo cuenta')),
                  ),
                ],
              ),
            ),
    );
  }
}
