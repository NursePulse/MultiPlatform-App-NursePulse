import '../../iam/domain/user.dart';
import 'report.dart';

class ReportPeriod {
  const ReportPeriod(this.start, this.end);
  final DateTime start, end;
  bool contains(DateTime value) =>
      !value.isBefore(start) && !value.isAfter(end);
}

class ReportRules {
  static bool canGenerate(User? user) =>
      user?.hasAnyRole([kRoleDoctor, kRoleAdmin]) == true;
  static DateTime day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  static String? title(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'El título es obligatorio.' : null;
  static String? dates(DateTime? from, DateTime? to) {
    if (from == null || to == null) return 'Selecciona ambas fechas.';
    return day(from).isAfter(day(to))
        ? 'La fecha inicial no puede ser posterior a la final.'
        : null;
  }

  static ReportPeriod validate(
    String type,
    String text,
    DateTime? from,
    DateTime? to,
  ) {
    final error = title(text) ?? dates(from, to);
    if (error != null) throw FormatException(error);
    if (!ReportType.values.contains(type)) {
      throw const FormatException('Selecciona un tipo de reporte válido.');
    }
    // El siguiente día menos un microsegundo incluye también la última fracción del día.
    return ReportPeriod(
      day(from!),
      DateTime(
        to!.year,
        to.month,
        to.day + 1,
      ).subtract(const Duration(microseconds: 1)),
    );
  }

  static String conclusion(ReportSummary summary) {
    if (summary.criticalAlerts > 0) {
      return 'Se detectaron ${summary.criticalAlerts} alerta(s) crítica(s). Requiere revisión médica prioritaria.';
    }
    if (summary.activeAlerts > 0) {
      return 'Existen ${summary.activeAlerts} alerta(s) activa(s). Mantener seguimiento del turno.';
    }
    if (summary.vitalSigns > 0 || summary.sbarTransfers > 0) {
      return 'Periodo con actividad clínica registrada y sin alertas críticas activas.';
    }
    return 'No se encontraron movimientos clínicos relevantes en el periodo seleccionado.';
  }

  static String tone(ReportSummary? summary) =>
      (summary?.criticalAlerts ?? 0) > 0
      ? 'Prioridad crítica'
      : (summary?.activeAlerts ?? 0) > 0
      ? 'Requiere seguimiento'
      : 'Sin alertas activas';
}
