import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/vital_sign.dart';

class VitalSignApi {
  VitalSignApi(this._dio);

  final Dio _dio;

  Future<List<VitalSign>> getAll() async {
    final response = await _dio.get('/vital-sign-records');
    return (response.data as List)
        .map((e) => VitalSign.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<VitalSign>> getByPatientId(String patientId) async {
    final response = await _dio.get('/vital-sign-records/patients/$patientId');
    return (response.data as List)
        .map((e) => VitalSign.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<VitalSign?> getLatestByPatientId(String patientId) async {
    try {
      final response = await _dio.get(
        '/vital-sign-records/patients/$patientId/latest',
      );
      return VitalSign.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<VitalSign> record(RecordVitalSignCommand command) async {
    final response = await _dio.post(
      '/vital-sign-records',
      data: command.toJson(),
    );
    return VitalSign.fromJson(response.data as Map<String, dynamic>);
  }
}

final vitalSignApiProvider = Provider(
  (ref) => VitalSignApi(ref.watch(dioProvider)),
);
