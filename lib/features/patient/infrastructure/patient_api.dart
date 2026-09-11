import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/patient.dart';

class PatientApi {
  PatientApi(this._dio);

  final Dio _dio;

  Future<List<Patient>> getAll() async {
    final response = await _dio.get('/patients');
    return (response.data as List)
        .map((e) => Patient.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Patient> getById(String id) async {
    final response = await _dio.get('/patients/$id');
    return Patient.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Patient> create(RegisterPatientCommand command) async {
    final response = await _dio.post('/patients', data: command.toJson());
    return Patient.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Patient> update(String id, RegisterPatientCommand command) async {
    final response = await _dio.put('/patients/$id', data: command.toJson());
    return Patient.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _dio.delete('/patients/$id');
}

final patientApiProvider = Provider(
  (ref) => PatientApi(ref.watch(dioProvider)),
);
