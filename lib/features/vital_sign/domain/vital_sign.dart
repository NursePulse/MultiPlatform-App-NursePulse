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

  factory VitalSign.fromJson(Map<String, dynamic> json) {
    final heartRate = json['heartRate'] as num;
    final respiratoryRate = json['respiratoryRate'] as num;
    final systolic = json['systolic'] as num;
    final diastolic = json['diastolic'] as num;
    final oxygenSaturation = json['oxygenSaturation'] as num;
    final temperature = json['temperature'] as num;

    final backendRisk = RiskLevelX.fromWire(json['riskLevel'] as String);
    final riskLevel = backendRisk != RiskLevel.unassessed
        ? backendRisk
        : _calculateRiskLevel(
            heartRate: heartRate,
            respiratoryRate: respiratoryRate,
            systolic: systolic,
            diastolic: diastolic,
            oxygenSaturation: oxygenSaturation,
            temperature: temperature,
          );

    return VitalSign(
      id: json['id'].toString(),
      patientId: json['patientId'].toString(),
      nurseId: json['nurseId'].toString(),
      heartRate: heartRate,
      respiratoryRate: respiratoryRate,
      systolic: systolic,
      diastolic: diastolic,
      oxygenSaturation: oxygenSaturation,
      temperature: temperature,
      riskLevel: riskLevel,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
    );
  }

  /// The backend's riskLevel currently always comes back UNASSESSED, so this
  /// fallback (mirrors calculateRiskLevel() in vital-sign-assembler.ts) is
  /// what actually determines the risk badge shown to the nurse in practice.
  static RiskLevel _calculateRiskLevel({
    required num heartRate,
    required num respiratoryRate,
    required num systolic,
    required num diastolic,
    required num oxygenSaturation,
    required num temperature,
  }) {
    final isCritical =
        oxygenSaturation < 90 ||
        heartRate >= 130 ||
        heartRate < 40 ||
        respiratoryRate >= 30 ||
        respiratoryRate < 8 ||
        systolic >= 180 ||
        systolic < 80 ||
        diastolic >= 120 ||
        temperature >= 39.5 ||
        temperature < 35;
    if (isCritical) return RiskLevel.critical;

    final isHigh =
        oxygenSaturation < 94 ||
        heartRate >= 110 ||
        heartRate < 50 ||
        respiratoryRate >= 24 ||
        systolic >= 160 ||
        systolic < 90 ||
        diastolic >= 100 ||
        temperature >= 38;
    if (isHigh) return RiskLevel.high;

    final isMedium =
        heartRate >= 100 ||
        respiratoryRate >= 20 ||
        systolic >= 140 ||
        diastolic >= 90 ||
        oxygenSaturation < 96 ||
        temperature >= 37.5;
    if (isMedium) return RiskLevel.medium;

    return RiskLevel.low;
  }

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
