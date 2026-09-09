import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/clinical_event.dart';

class ClinicalEventApi {
  ClinicalEventApi(this._dio);

  final Dio _dio;

  Future<List<ClinicalEvent>> getAll() async {
    final response = await _dio.get('/clinical-events');
    return (response.data as List)
        .map((e) => ClinicalEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ClinicalEvent>> getByPatientId(String patientId) async {
    final response = await _dio.get('/clinical-events/patients/$patientId');
    return (response.data as List)
        .map((e) => ClinicalEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ClinicalEvent> register(RegisterClinicalEventCommand command) async {
    final response = await _dio.post(
      '/clinical-events',
      data: command.toJson(),
    );
    return ClinicalEvent.fromJson(response.data as Map<String, dynamic>);
  }
}

final clinicalEventApiProvider = Provider(
  (ref) => ClinicalEventApi(ref.watch(dioProvider)),
);
