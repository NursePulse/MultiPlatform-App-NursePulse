class SbarTransfer {
  const SbarTransfer({
    required this.id,
    required this.patientId,
    required this.title,
    required this.situation,
    required this.background,
    required this.assessment,
    required this.recommendation,
    required this.status,
    this.registeredBy,
    this.incomingNurseId,
    this.targetNurseId,
    this.additionalNotes,
    this.transferredAt,
  });

  final String id;
  final String patientId;
  final String title;
  final String situation;
  final String background;
  final String assessment;
  final String recommendation;
  final String status;
  final String? registeredBy;
  final String? incomingNurseId;
  final String? targetNurseId;
  final String? additionalNotes;
  final DateTime? transferredAt;

  factory SbarTransfer.fromJson(Map<String, dynamic> json) => SbarTransfer(
    id: json['id'].toString(),
    patientId: json['patientId'].toString(),
    title: json['title'] as String,
    situation: json['situation'] as String? ?? '',
    background: json['background'] as String? ?? '',
    assessment: json['assessment'] as String? ?? '',
    recommendation: json['recommendation'] as String? ?? '',
    status: json['status'] as String? ?? 'PENDING',
    registeredBy: json['registeredBy'] as String?,
    incomingNurseId: json['incomingNurseId']?.toString(),
    targetNurseId: json['targetNurseId']?.toString(),
    additionalNotes: json['additionalNotes'] as String?,
    // The backend names this field `createdAt`; `transferredAt` is kept as a
    // fallback in case an older API version is ever pointed at by mistake.
    transferredAt: DateTime.tryParse(
      (json['createdAt'] ?? json['transferredAt'] ?? '') as String,
    ),
  );

  String get statusLabel => switch (status) {
    'ACKNOWLEDGED' => 'Atendido',
    'COMPLETED' => 'Completado',
    'CANCELLED' => 'Cancelado',
    _ => 'Pendiente',
  };

  bool get canAcknowledge => status == 'PENDING';
}

class RegisterSbarCommand {
  const RegisterSbarCommand({
    required this.patientId,
    required this.title,
    required this.situation,
    required this.background,
    required this.assessment,
    required this.recommendation,
    this.targetNurseId,
  });

  final String patientId;
  final String title;
  final String situation;
  final String background;
  final String assessment;
  final String recommendation;
  final String? targetNurseId;

  Map<String, dynamic> toJson() => {
    'patientId': int.parse(patientId),
    'title': title,
    'situation': situation,
    'background': background,
    'assessment': assessment,
    'recommendation': recommendation,
    if (targetNurseId != null) 'targetNurseId': int.parse(targetNurseId!),
  };
}
