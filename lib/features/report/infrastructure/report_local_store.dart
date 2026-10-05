import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/report.dart';

typedef ReportRead = Future<String?> Function();
typedef ReportWrite = Future<void> Function(String value);

class ReportLocalStore {
  ReportLocalStore({ReportRead? read, ReportWrite? write})
    : _read =
          read ?? (() => const FlutterSecureStorage().read(key: storageKey)),
      _write =
          write ??
          ((value) => const FlutterSecureStorage().write(
            key: storageKey,
            value: value,
          ));
  static const storageKey = 'nurse-pulse.generated-reports';
  final ReportRead _read;
  final ReportWrite _write;

  Future<List<Report>> getAll() async {
    final raw = await _read();
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final reports = decoded.map((item) {
        final report = Report.fromJson(item as Map<String, dynamic>);
        final summary = report.summary;
        if (report.id.trim().isEmpty ||
            report.id == 'null' ||
            report.title.trim().isEmpty ||
            !ReportType.values.contains(report.type) ||
            report.status != ReportStatus.completed ||
            report.generatedBy.trim().isEmpty ||
            report.endDate.isBefore(report.startDate) ||
            summary == null ||
            report.clinicalConclusion == null ||
            summary.toJson().values.any((count) => (count as int) < 0)) {
          throw const FormatException('Reporte local inválido.');
        }
        return report;
      }).toList();
      if (reports.map((report) => report.id).toSet().length != reports.length) {
        return [];
      }
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reports;
    } catch (_) {
      // Igual que la web: datos corruptos no derriban la lista ni fabrican reportes.
      return [];
    }
  }

  Future<List<Report>> add(Report report) async {
    final reports = [
      report,
      ...await getAll().then(
        (items) => items.where((item) => item.id != report.id),
      ),
    ];
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _write(jsonEncode(reports.map((item) => item.toJson()).toList()));
    return List.unmodifiable(reports);
  }
}

String newReportId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

final reportLocalStoreProvider = Provider((ref) => ReportLocalStore());
