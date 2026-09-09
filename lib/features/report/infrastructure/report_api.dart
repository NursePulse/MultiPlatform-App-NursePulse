import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/report.dart';

/// Real, persisted reports API (`POST/GET /api/v1/reports`) — mirrors
/// ReportApiEndpoint in the Angular app. The backend just persists a
/// consolidated summary the client already computed from live clinical data.
class ReportApi {
  ReportApi(this._dio);

  final Dio _dio;

  Future<List<Report>> getAll() async {
    final response = await _dio.get('/reports');
    return (response.data as List)
        .map((e) => Report.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Report> generate(CreateReportCommand command) async {
    final response = await _dio.post('/reports', data: command.toJson());
    return Report.fromJson(response.data as Map<String, dynamic>);
  }
}

final reportApiProvider = Provider((ref) => ReportApi(ref.watch(dioProvider)));
