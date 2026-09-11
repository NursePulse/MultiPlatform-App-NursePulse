import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/alert.dart';

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

  Future<Alert> create({
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
    return Alert.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Alert> attend(String id, String attendedBy) async {
    final response = await _dio.patch(
      '/alerts/$id/attend',
      data: {'attendedBy': attendedBy},
    );
    return Alert.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Alert> close(
    String id,
    String closedBy, {
    String resolutionNotes = 'Alerta cerrada desde seguimiento clínico.',
  }) async {
    final response = await _dio.patch(
      '/alerts/$id/close',
      data: {'closedBy': closedBy, 'resolutionNotes': resolutionNotes},
    );
    return Alert.fromJson(response.data as Map<String, dynamic>);
  }
}

final alertApiProvider = Provider((ref) => AlertApi(ref.watch(dioProvider)));
