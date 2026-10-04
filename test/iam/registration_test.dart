import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/domain/sign_up_request.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/iam/infrastructure/iam_api.dart';

SignUpRequest validRequest({String role = 'ROLE_NURSE', String age = '18'}) =>
    SignUpRequest.fromForm(
      username: ' nurse.test ',
      password: 'TestPass123!x',
      firstName: ' María ',
      lastName: ' Núñez ',
      phone: '912345678',
      age: age,
      email: ' maria@example.com ',
      role: role,
    );

void main() {
  test('usuario: vacío y límites 2/3/50/51', () {
    expect(RegistrationValidators.username(' '), isNotNull);
    for (final length in [2, 3, 50, 51]) {
      expect(
        RegistrationValidators.username('a' * length) == null,
        length == 3 || length == 50,
      );
    }
  });

  test('nombres: acentos, ñ, espacios y máximo 20', () {
    for (final name in ['María', 'Núñez', 'Ana María', 'a' * 20]) {
      expect(RegistrationValidators.name(name), isNull);
    }
    for (final name in ['', ' ', 'Ana2', 'Ana!', 'Ana  María', 'a' * 21]) {
      expect(RegistrationValidators.name(name), isNotNull);
    }
  });

  test('teléfono: exactamente nueve dígitos', () {
    for (final phone in ['', '1' * 8, '1' * 10, '12345678a']) {
      expect(RegistrationValidators.phone(phone), isNotNull);
    }
    expect(RegistrationValidators.phone('912345678'), isNull);
  });

  test('edad: 17/18/120/121 y solo enteros', () {
    for (final age in ['', '17', '121', '-18', '18.5', 'NaN', 'Infinity']) {
      expect(RegistrationValidators.age(age), isNotNull);
    }
    expect(RegistrationValidators.age('18'), isNull);
    expect(RegistrationValidators.age('120'), isNull);
  });

  test('correo: formato, espacios y máximo 254', () {
    expect(RegistrationValidators.email('ana@example.com'), isNull);
    for (final email in [
      '',
      'ana',
      'ana@',
      'ana @example.com',
      '${'a' * 245}@example.com',
    ]) {
      expect(RegistrationValidators.email(email), isNotNull);
    }
  });

  test('contraseña: límites y requisitos independientes', () {
    for (final length in [11, 12, 20, 21]) {
      expect(
        RegistrationValidators.password('A1!${'a' * (length - 3)}') == null,
        length == 12 || length == 20,
      );
    }
    for (final password in [
      'abcdefghijkl',
      'abcdefghijk1!',
      'Abcdefghijkl!',
      'Abcdefghijk1',
    ]) {
      expect(RegistrationValidators.password(password), isNotNull);
    }

    expect(
      RegistrationValidators.confirmPassword('', 'TestPass123!x'),
      isNotNull,
    );
    expect(
      RegistrationValidators.confirmPassword('TestPass123!y', 'TestPass123!x'),
      isNotNull,
    );
    expect(
      RegistrationValidators.confirmPassword('TestPass123!x', 'TestPass123!x'),
      isNull,
    );
  });

  test('registro público acepta Nurse/Doctor y rechaza Admin', () {
    expect(RegistrationValidators.role('ROLE_NURSE'), isNull);
    expect(RegistrationValidators.role('ROLE_DOCTOR'), isNull);
    expect(RegistrationValidators.role('ROLE_ADMIN'), isNotNull);
    expect(() => validRequest(role: 'ROLE_ADMIN'), throwsFormatException);
    expect(() => validRequest(age: '17'), throwsFormatException);
  });

  test('acceso: contraseña 8–72 sin exigir reglas de registro', () {
    for (final length in [7, 8, 72, 73]) {
      expect(
        RegistrationValidators.signInPassword('a' * length) == null,
        length == 8 || length == 72,
      );
    }
    expect(RegistrationValidators.signInPassword(' ' * 8), isNotNull);
  });

  test('API rechaza sesiones sin token o sin rol conocido', () async {
    for (final data in [
      {
        'id': 1,
        'username': 'test',
        'roles': ['ROLE_NURSE'],
      },
      {
        'id': 1,
        'username': 'test',
        'roles': ['ROLE_UNKNOWN'],
        'token': 'token',
      },
    ]) {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(requestOptions: options, data: data, statusCode: 200),
            );
          },
        ),
      );

      await expectLater(
        AuthenticationApi(dio).signIn(username: 'test', password: 'abcdefgh'),
        throwsFormatException,
      );
    }
  });

  test('API envía exactamente los ocho datos y edad numérica', () async {
    RequestOptions? sent;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sent = options;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'id': 9,
                'username': 'nurse.test',
                'roles': ['ROLE_DOCTOR'],
              },
            ),
          );
        },
      ),
    );

    final user = await AuthenticationApi(dio)
        .signUp(validRequest(role: 'ROLE_DOCTOR'));

    expect(sent!.path, '/authentication/sign-up');
    expect(sent!.data, {
      'username': 'nurse.test',
      'password': 'TestPass123!x',
      'firstName': 'María',
      'lastName': 'Núñez',
      'phone': '912345678',
      'age': 18,
      'email': 'maria@example.com',
      'role': 'ROLE_DOCTOR',
    });
    expect(user.primaryRole, kRoleDoctor);
  });

  test('conserva roles reales y no concede Nurse por defecto', () {
    for (final role in [kRoleAdmin, kRoleDoctor, kRoleNurse]) {
      final user = User.fromJson({
        'id': 1,
        'username': 'test',
        'roles': [role],
      });
      expect(user.primaryRole, role);
      expect(user.hasKnownRole, isTrue);
    }

    for (final roles in [
      [],
      ['ROLE_UNKNOWN'],
      ['ROLE_HEAD_ADMIN_NURSE'],
    ]) {
      final user = User.fromJson({'id': 1, 'username': 'test', 'roles': roles});
      expect(user.hasKnownRole, isFalse);
      expect(user.hasAnyRole([kRoleNurse]), isFalse);
      expect(user.primaryRole, isEmpty);
    }
  });
}
