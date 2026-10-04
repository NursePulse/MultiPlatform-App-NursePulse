import '../../iam/domain/user.dart';
import 'vital_sign.dart';

class VitalSignRules {
  VitalSignRules._();

  static bool canRead(List<String> roles) =>
      roles.any([kRoleNurse, kRoleDoctor, kRoleAdmin].contains);

  static bool canRecord(List<String> roles) =>
      roles.any([kRoleNurse, kRoleAdmin].contains);

  static String? id(String? value) {
    final text = value?.trim() ?? '';
    final number = int.tryParse(text);

    return RegExp(r'^[0-9]+$').hasMatch(text) && number != null && number > 0
        ? null
        : 'Selecciona un identificador válido.';
  }

  static String? number(
    String? value,
    String label,
    num min,
    num max, {
    bool integer = true,
  }) {
    final text = value?.trim() ?? '';
    final format = integer
        ? RegExp(r'^[0-9]+$')
        : RegExp(r'^[0-9]+(?:[.,][0-9]+)?$');
    final parsed = num.tryParse(text.replaceAll(',', '.'));

    if (!format.hasMatch(text) || parsed == null || !parsed.isFinite) {
      return integer
          ? '$label debe ser un número entero.'
          : '$label debe ser un número válido.';
    }

    return parsed < min || parsed > max
        ? '$label debe estar entre $min y $max.'
        : null;
  }

  static String? pressure(num systolic, num diastolic) => systolic <= diastolic
      ? 'La presión sistólica debe ser mayor que la diastólica.'
      : null;

  static RecordVitalSignCommand fromForm({
    required String patientId,
    required String nurseId,
    required String heartRate,
    required String respiratoryRate,
    required String systolic,
    required String diastolic,
    required String oxygen,
    required String temperature,
  }) {
    final errors = [
      id(patientId),
      id(nurseId),
      number(heartRate, 'FC', 20, 250),
      number(respiratoryRate, 'FR', 5, 80),
      number(systolic, 'TA sistólica', 50, 260),
      number(diastolic, 'TA diastólica', 30, 180),
      number(oxygen, 'SpO₂', 0, 100),
      number(temperature, 'Temperatura', 30, 45, integer: false),
    ];

    for (final error in errors) {
      if (error != null) throw FormatException(error);
    }

    return validate(
      RecordVitalSignCommand(
        patientId: patientId.trim(),
        nurseId: int.parse(nurseId.trim()).toString(),
        heartRate: int.parse(heartRate.trim()),
        respiratoryRate: int.parse(respiratoryRate.trim()),
        systolicPressure: int.parse(systolic.trim()),
        diastolicPressure: int.parse(diastolic.trim()),
        oxygenSaturation: int.parse(oxygen.trim()),
        temperature: num.parse(temperature.trim().replaceAll(',', '.')),
      ),
      nurseId: nurseId,
    );
  }

  static RecordVitalSignCommand validate(
    RecordVitalSignCommand c, {
    required String nurseId,
  }) {
    if (id(c.patientId) != null) {
      throw const FormatException('Selecciona un paciente válido.');
    }

    if (id(nurseId) != null) {
      throw const FormatException(
        'La sesión no contiene un usuario válido. Inicia sesión de nuevo.',
      );
    }

    void range(
      num value,
      String label,
      num min,
      num max, {
      bool integer = true,
    }) {
      if (!value.isFinite ||
          (integer && value % 1 != 0) ||
          value < min ||
          value > max) {
        throw FormatException(
          '$label debe estar entre $min y $max'
          '${integer ? ' y ser entero' : ''}.',
        );
      }
    }

    range(c.heartRate, 'FC', 20, 250);
    range(c.respiratoryRate, 'FR', 5, 80);
    range(c.systolicPressure, 'TA sistólica', 50, 260);
    range(c.diastolicPressure, 'TA diastólica', 30, 180);
    range(c.oxygenSaturation, 'SpO₂', 0, 100);
    range(c.temperature, 'Temperatura', 30, 45, integer: false);

    final error = pressure(c.systolicPressure, c.diastolicPressure);
    if (error != null) throw FormatException(error);

    return RecordVitalSignCommand(
      patientId: int.parse(c.patientId.trim()).toString(),
      nurseId: int.parse(nurseId.trim()).toString(),
      heartRate: c.heartRate.toInt(),
      respiratoryRate: c.respiratoryRate.toInt(),
      systolicPressure: c.systolicPressure.toInt(),
      diastolicPressure: c.diastolicPressure.toInt(),
      oxygenSaturation: c.oxygenSaturation.toInt(),
      temperature: c.temperature,
    );
  }

  static String alertDescription(VitalSign s) =>
      '${s.isCritical ? 'Signos vitales críticos' : 'Signos vitales fuera de rango'}: '
      'FC ${s.heartRate} lpm; FR ${s.respiratoryRate} rpm; '
      'TA ${s.systolic}/${s.diastolic} mmHg; '
      'SpO₂ ${s.oxygenSaturation} %; T ${s.temperature} °C.';
}
