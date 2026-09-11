import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/sbar_transfer.dart';

class SbarApi {
  SbarApi(this._dio);

  final Dio _dio;

  Future<List<SbarTransfer>> getByPatientId(String patientId) async {
    final response = await _dio.get('/handovers/patients/$patientId');
    return (response.data as List)
        .map((e) => SbarTransfer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SbarTransfer> getById(String id) async {
    final response = await _dio.get('/handovers/$id');
    return SbarTransfer.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /handovers only returns the created id (a bare number), not the
  /// full resource — mirrors sbar.store.ts's registerTransfer(), which does
  /// the same follow-up getById() fetch.
  Future<SbarTransfer> register(RegisterSbarCommand command) async {
    final response = await _dio.post('/handovers', data: command.toJson());
    if (response.data is Map<String, dynamic>) {
      return SbarTransfer.fromJson(response.data as Map<String, dynamic>);
    }
    return getById(response.data.toString());
  }

  /// The acknowledging nurse is derived server-side from the JWT
  /// (AcknowledgeHandoverResource only accepts `additionalNotes`), so no
  /// nurse identity is sent from the client.
  Future<SbarTransfer> acknowledge(String id, {String? additionalNotes}) async {
    final response = await _dio.patch(
      '/handovers/$id/acknowledge',
      data: {if (additionalNotes != null) 'additionalNotes': additionalNotes},
    );
    return SbarTransfer.fromJson(response.data as Map<String, dynamic>);
  }
}

final sbarApiProvider = Provider((ref) => SbarApi(ref.watch(dioProvider)));
