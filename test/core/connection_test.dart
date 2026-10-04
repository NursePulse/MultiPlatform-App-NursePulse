import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/config/app_config.dart';
import 'package:nurse_pulse_app/core/network/api_exception.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';

DioException failure(int status, [Object? body]) => DioException(
  requestOptions: RequestOptions(path: '/authentication/sign-in'),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(path: '/authentication/sign-in'),
    statusCode: status,
    data: body,
  ),
);

void main() {
  test('sin configuración extra la app apunta al backend de producción', () {
    expect(
      AppConfig.apiBaseUrl,
      'https://backend-nursepulse-qfct.onrender.com/api/v1',
    );
    expect(AppConfig.apiBaseUrl, AppConfig.productionApiBaseUrl);
  });

  test('las peticiones piden los mensajes del backend en español', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final headers = container.read(dioProvider).options.headers;

    expect(headers['Accept-Language'], 'es');
  });

  group('describeSignInError', () {
    test('400 de credenciales incorrectas, como responde el backend real', () {
      final error = failure(400, {
        'code': 'VALIDATION_ERROR',
        'message': 'Validacion fallida',
        'details': 'Invalid username or password',
      });

      expect(describeSignInError(error), 'Usuario o contraseña incorrectos.');
    });

    test('401 también se trata como credenciales incorrectas', () {
      expect(
        describeSignInError(failure(401)),
        'Usuario o contraseña incorrectos.',
      );
    });

    test('422 explica que falta confirmar el correo', () {
      final error = failure(422, {
        'code': 'BUSINESS_RULE_VIOLATION',
        'message': 'Violacion de regla de negocio',
        'details':
            'Email not verified. Check your inbox for the confirmation link.',
      });

      expect(describeSignInError(error), contains('confirmar tu correo'));
    });

    test('otros errores conservan el mensaje genérico del servidor', () {
      final error = failure(500, {'message': 'Error inesperado'});

      expect(describeSignInError(error), 'Error inesperado');
    });

    test('sin conexión no se confunde con credenciales incorrectas', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/authentication/sign-in'),
        type: DioExceptionType.connectionError,
      );

      expect(
        describeSignInError(error),
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    });
  });
}
