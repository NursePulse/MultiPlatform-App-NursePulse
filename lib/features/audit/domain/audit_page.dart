import 'audit_log.dart';

class AuditPage {
  const AuditPage({
    required this.logs,
    required this.page,
    required this.size,
    this.totalElements,
    this.totalPages,
    this.last = true,
  });
  final List<AuditLog> logs;
  final int page, size;
  final int? totalElements, totalPages;
  final bool last;
}
