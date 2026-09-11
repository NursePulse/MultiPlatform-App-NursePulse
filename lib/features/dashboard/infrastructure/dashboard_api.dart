import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/dashboard_summary.dart';

/// There is no backend controller for /dashboard/summary. This tries it
/// anyway (in case a future backend adds it) and returns null on any
/// failure, so the notifier can fall back to a client-side aggregate.
class DashboardApi {
  DashboardApi(this._dio);

  final Dio _dio;

  Future<DashboardSummary?> getSummary() async {
    try {
      final response = await _dio.get('/dashboard/summary');
      return DashboardSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }
}

final dashboardApiProvider = Provider(
  (ref) => DashboardApi(ref.watch(dioProvider)),
);
