import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/alert.dart';

class AlertWriteReceipt {
  const AlertWriteReceipt({this.id, this.alert, this.readError});
  final String? id;
  final Alert? alert;
  final Object? readError;
}

class AlertApi {
  AlertApi(this._dio);

  final Dio _dio;

  Future<List<Alert>> getAll() async {
    final response = await _dio.get('/alerts');
    return (response.data as List)
        .map((e) => Alert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Alert>> getByPatientId(String patientId) async {
    final response = await _dio.get('/alerts/patients/$patientId');
    return (response.data as List)
        .map((e) => Alert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Alert> getById(String id) async {
    final response = await _dio.get('/alerts/$id');
    final alert = Alert.fromJson(response.data as Map<String, dynamic>);
    if (alert.id != id) {
      throw const FormatException('La API devolvió otra alerta.');
    }
    return alert;
  }

  // Un 2xx confirma la escritura. Se recupera el cuerpo con GET,
  // nunca repitiendo POST/PATCH ni fabricando una entidad.
  Future<AlertWriteReceipt> _receipt(
    Object? body, {
    String? id,
    String? patientId,
    required AlertStatus status,
  }) async {
    String? confirmedId = id;
    if (confirmedId == null && body is Map) {
      final number = int.tryParse(body['id'].toString());
      if (number != null && number > 0) confirmedId = number.toString();
    }
    bool matches(Alert alert) =>
        alert.id == confirmedId &&
        (patientId == null || alert.patientId == patientId) &&
        (alert.status == status ||
            (status == AlertStatus.open && alert.status != AlertStatus.open) ||
            (status == AlertStatus.attended &&
                alert.status == AlertStatus.closed));
    try {
      final alert = Alert.fromJson(body as Map<String, dynamic>);
      if (!matches(alert)) {
        throw const FormatException('Respuesta de alerta inconsistente.');
      }
      return AlertWriteReceipt(id: alert.id, alert: alert);
    } catch (error) {
      if (confirmedId != null) {
        try {
          final actual = await getById(confirmedId);
          if (matches(actual)) {
            return AlertWriteReceipt(id: actual.id, alert: actual);
          }
        } catch (_) {}
      }
      return AlertWriteReceipt(id: confirmedId, readError: error);
    }
  }

  Future<AlertWriteReceipt> create({
    required String patientId,
    required String type,
    required AlertSeverity severity,
    required String description,
    required String triggeredBy,
  }) async {
    final response = await _dio.post(
      '/alerts',
      data: {
        'patientId': int.parse(patientId),
        'type': type,
        'severity': severity.wireValue,
        'description': description,
        'triggeredBy': triggeredBy,
      },
    );
    return _receipt(
      response.data,
      patientId: patientId,
      status: AlertStatus.open,
    );
  }

  Future<AlertWriteReceipt> attend(
    String id,
    String attendedBy, {
    String? patientId,
  }) async {
    final response = await _dio.patch(
      '/alerts/$id/attend',
      data: {'attendedBy': attendedBy},
    );
    return _receipt(
      response.data,
      id: id,
      patientId: patientId,
      status: AlertStatus.attended,
    );
  }

  Future<AlertWriteReceipt> close(
    String id,
    String closedBy, {
    String? patientId,
    String resolutionNotes = 'Alerta cerrada desde seguimiento clínico.',
  }) async {
    final response = await _dio.patch(
      '/alerts/$id/close',
      data: {'closedBy': closedBy, 'resolutionNotes': resolutionNotes},
    );
    return _receipt(
      response.data,
      id: id,
      patientId: patientId,
      status: AlertStatus.closed,
    );
  }
}

final alertApiProvider = Provider((ref) => AlertApi(ref.watch(dioProvider)));
