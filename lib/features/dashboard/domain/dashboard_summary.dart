class DashboardSummary {
  const DashboardSummary({
    required this.monitoredPatients,
    required this.activeAlerts,
    required this.criticalAlerts,
    required this.moderateAlerts,
    required this.clinicalEventsToday,
    required this.inspectionsThisMonth,
    required this.lastUpdate,
  });

  final int monitoredPatients;
  final int activeAlerts;
  final int criticalAlerts;
  final int moderateAlerts;
  final int clinicalEventsToday;
  final int inspectionsThisMonth;
  final DateTime lastUpdate;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      DashboardSummary(
        monitoredPatients: json['monitoredPatients'] as int,
        activeAlerts: json['activeAlerts'] as int,
        criticalAlerts: json['criticalAlerts'] as int,
        moderateAlerts: json['moderateAlerts'] as int,
        clinicalEventsToday: json['clinicalEventsToday'] as int,
        inspectionsThisMonth: json['inspectionsThisMonth'] as int,
        lastUpdate: DateTime.parse(json['lastUpdate'] as String),
      );
}
