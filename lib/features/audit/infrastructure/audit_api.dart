import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/audit_log.dart';

class AuditApi {
  AuditApi(this._dio);

  final Dio _dio;

  Future<List<AuditLog>> getAll() async {
    final response = await _dio.get(
      '/audit-logs',
      queryParameters: {'page': 0, 'size': 100},
    );
    final data = response.data;
    final list = data is List
        ? data
        : (data as Map<String, dynamic>)['content'] as List;
    return list
        .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AuditLog>> getPatientTimeline(String patientId) async {
    final response = await _dio.get('/audit-logs/patients/$patientId/timeline');
    return (response.data as List)
        .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AuditLog> create({
    required String entityType,
    required String entityId,
    required String actionType,
    required String performedBy,
    String? patientId,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _dio.post(
      '/audit-logs',
      data: {
        'entityType': entityType,
        'entityId': entityId,
        'actionType': actionType,
        'performedBy': performedBy,
        if (patientId != null) 'patientId': int.parse(patientId),
        'metadata': ?metadata,
      },
    );
    return AuditLog.fromJson(response.data as Map<String, dynamic>);
  }
}

final auditApiProvider = Provider((ref) => AuditApi(ref.watch(dioProvider)));
