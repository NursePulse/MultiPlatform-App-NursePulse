import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/audit_log.dart';
import '../domain/audit_page.dart';
import '../domain/audit_rules.dart';

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
    final id = AuditRules.id(patientId);
    final response = await _dio.get('/audit-logs/patients/$id/timeline');
    final data = response.data;
    final List list;
    if (data is List) {
      list = data;
    } else if (data is Map<String, dynamic> &&
        data['patientId'].toString() == id &&
        data['events'] is List) {
      list = data['events'] as List;
      if (data['eventCount'] != list.length) {
        throw const FormatException(
          'El contador del historial no coincide con sus registros.',
        );
      }
    } else {
      throw const FormatException(
        'El historial de auditoría no corresponde al paciente.',
      );
    }
    return list.map((e) {
      final record = e as Map<String, dynamic>;
      if (record['patientId'] != null && record['patientId'].toString() != id) {
        throw const FormatException(
          'El historial contiene auditoría de otro paciente.',
        );
      }
      return AuditLog.fromJson({...record, 'patientId': id});
    }).toList();
  }

  Future<AuditPage> getPage({int page = 0, int size = 100}) async {
    AuditRules.pagination(page, size);
    final response = await _dio.get(
      '/audit-logs',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data;
    if (data is List && page == 0) {
      return AuditPage(
        logs: data
            .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
            .toList(),
        page: page,
        size: size,
      );
    }
    if (data is! Map<String, dynamic> ||
        data['content'] is! List ||
        data['page'] != page ||
        data['size'] != size ||
        data['last'] is! bool ||
        data['totalElements'] is! int ||
        data['totalPages'] is! int ||
        (data['totalElements'] as int) < 0 ||
        (data['totalPages'] as int) < 0) {
      throw const FormatException(
        'La API no devolvió una página válida de auditoría.',
      );
    }
    final logs = (data['content'] as List)
        .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
        .toList();
    if (logs.length > size ||
        logs.map((log) => log.id).toSet().length != logs.length) {
      throw const FormatException(
        'La página de auditoría contiene registros duplicados o excede su tamaño.',
      );
    }
    return AuditPage(
      logs: logs,
      page: page,
      size: size,
      totalElements: data['totalElements'] as int,
      totalPages: data['totalPages'] as int,
      last: data['last'] as bool,
    );
  }

  Future<Uint8List> exportPdf({String? patientId}) async {
    final id = patientId == null ? null : AuditRules.id(patientId);
    final response = await _dio.get<List<int>>(
      '/audit-logs/export/pdf',
      queryParameters: {if (id != null) 'patientId': int.parse(id)},
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/pdf'},
      ),
    );
    final bytes = response.data;
    if (bytes == null || !AuditRules.isPdf(bytes)) {
      throw const FormatException(
        'La API no devolvió un documento PDF válido.',
      );
    }
    return Uint8List.fromList(bytes);
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
