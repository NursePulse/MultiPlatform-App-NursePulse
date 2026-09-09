enum RiskLevel { unassessed, low, medium, high, critical }

extension RiskLevelX on RiskLevel {
  String get label => switch (this) {
    RiskLevel.unassessed => 'Sin evaluar',
    RiskLevel.low => 'Bajo',
    RiskLevel.medium => 'Medio',
    RiskLevel.high => 'Alto',
    RiskLevel.critical => 'Crítico',
  };

  String get wireValue => switch (this) {
    RiskLevel.unassessed => 'UNASSESSED',
    RiskLevel.low => 'LOW',
    RiskLevel.medium => 'MEDIUM',
    RiskLevel.high => 'HIGH',
    RiskLevel.critical => 'CRITICAL',
  };

  static RiskLevel fromWire(String value) => switch (value) {
    'LOW' => RiskLevel.low,
    'MEDIUM' => RiskLevel.medium,
    'HIGH' => RiskLevel.high,
    'CRITICAL' => RiskLevel.critical,
    _ => RiskLevel.unassessed,
  };
}

class VitalSign {
  const VitalSign({
    required this.id,
    required this.patientId,
    required this.nurseId,
    required this.heartRate,
    required this.respiratoryRate,
    required this.systolic,
    required this.diastolic,
    required this.oxygenSaturation,
    required this.temperature,
    required this.riskLevel,
    required this.recordedAt,
  });

  final String id;
  final String patientId;
  final String nurseId;
  final num heartRate;
  final num respiratoryRate;
  final num systolic;
  final num diastolic;
  final num oxygenSaturation;
  final num temperature;
  final RiskLevel riskLevel;
  final DateTime recordedAt;

  factory VitalSign.fromJson(Map<String, dynamic> json) => VitalSign(
    id: json['id'].toString(),
    patientId: json['patientId'].toString(),
    nurseId: json['nurseId'].toString(),
    heartRate: json['heartRate'] as num,
    respiratoryRate: json['respiratoryRate'] as num,
    systolic: json['systolic'] as num,
    diastolic: json['diastolic'] as num,
    oxygenSaturation: json['oxygenSaturation'] as num,
    temperature: json['temperature'] as num,
    riskLevel: RiskLevelX.fromWire(json['riskLevel'] as String),
    recordedAt: DateTime.parse(json['recordedAt'] as String),
  );

  String get bloodPressureFormatted => 'TA $systolic/$diastolic';

  String get heartRateFormatted => 'FC $heartRate';

  String get respiratoryRateFormatted => 'FR $respiratoryRate';

  String get riskLabel => riskLevel.label;

  bool get isCritical => riskLevel == RiskLevel.critical;

  bool get isHighRisk =>
      riskLevel == RiskLevel.critical || riskLevel == RiskLevel.high;
}

/// Deliberately does not carry a nurse identity: the backend derives the
/// responsible nurse from the authenticated JWT (mirrors
/// record-vital-sign.request.ts in the Angular app).
class RecordVitalSignCommand {
  const RecordVitalSignCommand({
    required this.patientId,
    required this.heartRate,
    required this.respiratoryRate,
    required this.systolicPressure,
    required this.diastolicPressure,
    required this.oxygenSaturation,
    required this.temperature,
  });

  final String patientId;
  final num heartRate;
  final num respiratoryRate;
  final num systolicPressure;
  final num diastolicPressure;
  final num oxygenSaturation;
  final num temperature;

  Map<String, dynamic> toJson() => {
    'patientId': int.parse(patientId),
    'heartRate': heartRate,
    'respiratoryRate': respiratoryRate,
    'systolicPressure': systolicPressure,
    'diastolicPressure': diastolicPressure,
    'oxygenSaturation': oxygenSaturation,
    'temperature': temperature,
  };
}
