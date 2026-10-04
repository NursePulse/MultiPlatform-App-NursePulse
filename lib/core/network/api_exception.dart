import 'package:dio/dio.dart';

/// Message for a failed sign-in. The backend answers wrong credentials with
/// 400 (VALIDATION_ERROR) and an unverified email with 422, and puts the useful
/// text in `details`, so the generic `message` alone would not help the user.
String describeSignInError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final details = data is Map ? data['details'] : null;

    if (status == 422) {
      return 'Debes confirmar tu correo antes de iniciar sesión. '
          'Revisa tu bandeja de entrada.';
    }
    if (status == 401 ||
        (status == 400 &&
            details is String &&
            details.toLowerCase().contains('invalid username or password'))) {
      return 'Usuario o contraseña incorrectos.';
    }
  }
  return describeDioError(error);
}

/// Extracts a human-readable, Spanish message from a failed request.
String describeDioError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['error'] ?? data['detail'];
      if (message is String && message.isNotEmpty) return message;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'La conexión con el servidor demoró demasiado. Intenta de nuevo.';
      case DioExceptionType.connectionError:
        return 'No se pudo conectar con el servidor. Verifica tu conexión.';
      default:
        break;
    }
    final status = error.response?.statusCode;
    if (status == 401) return 'Credenciales inválidas.';
    if (status == 403) return 'No tienes permisos para realizar esta acción.';
    if (status == 404) return 'El recurso solicitado no existe.';
    if (status == 409) return 'Ya existe un registro con esos datos.';
    if (status != null && status >= 500) {
      return 'Ocurrió un error en el servidor. Intenta más tarde.';
    }
  }
  return 'Ocurrió un error inesperado.';
}
