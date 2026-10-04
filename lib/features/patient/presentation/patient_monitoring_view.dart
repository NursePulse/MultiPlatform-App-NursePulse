import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../clinical_event/domain/clinical_event.dart';
import '../../iam/domain/user.dart';
import '../application/patient_detail.dart';
import '../application/patient_notifier.dart';
import '../domain/patient_rules.dart';
import '../domain/patient_monitoring_rules.dart';

class PatientMonitoringView extends ConsumerStatefulWidget {
  const PatientMonitoringView({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<PatientMonitoringView> createState() =>
      _PatientMonitoringViewState();
}

class _PatientMonitoringViewState extends ConsumerState<PatientMonitoringView> {
  DateTimeRange? _period;

  String get _providerId {
    try {
      return PatientMonitoringRules.id(widget.patientId);
    } on FormatException {
      return widget.patientId;
    }
  }

  @override
  void didUpdateWidget(covariant PatientMonitoringView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId) _period = null;
  }

  String _date(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

  String _time(DateTime date) =>
      DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());

  Future<void> _refresh() async {
    try {
      final patient = ref.refresh(patientDetailProvider(_providerId).future);
      await patient;
      if (!mounted) return;
      ref.invalidate(patientHistoryProvider(_providerId));
      await ref.read(patientHistoryProvider(_providerId).future);
    } catch (_) {
      // Cada proveedor muestra su error y permite reintentar.
    }
  }

  Future<void> _pickPeriod() async {
    final today = ref.read(patientMonitoringClockProvider)();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1930),
      lastDate: today,
      currentDate: today,
      initialDateRange: _period,
      helpText: 'Periodo de signos y eventos',
      saveText: 'Aplicar',
    );

    if (mounted && picked != null) {
      final error = PatientMonitoringRules.period(
        picked.start,
        picked.end,
        today: today,
      );
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      } else {
        setState(() => _period = picked);
      }
    }
  }

  Widget _error(Object error, VoidCallback retry) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(describePatientError(error)),
      TextButton(onPressed: retry, child: const Text('Reintentar')),
    ],
  );

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _card(String title, List<String> lines) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final line in lines) Text(line),
        ],
      ),
    ),
  );

  List<Widget> _history(PatientHistory history) {
    bool inPeriod(DateTime date) =>
        PatientRules.inPeriod(date, from: _period?.start, to: _period?.end);

    final vitals = history.vitals.where((v) => inPeriod(v.recordedAt)).toList();
    final events = history.events.where((e) => inPeriod(e.occurredAt)).toList();

    return [
      Text(
        'Alertas activas: ${history.alerts.where((a) => a.isActive).length}',
      ),
      Text(
        'Último riesgo registrado: ${history.vitals.isEmpty ? 'Sin registros' : history.vitals.first.riskLabel}',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _pickPeriod,
            icon: const Icon(Icons.date_range),
            label: Text(
              _period == null
                  ? 'Filtrar signos y eventos'
                  : '${_date(_period!.start)} – ${_date(_period!.end)}',
            ),
          ),
          if (_period != null)
            TextButton(
              onPressed: () => setState(() => _period = null),
              child: const Text('Ver todo'),
            ),
        ],
      ),
      _title('Signos vitales (${vitals.length})'),
      TextButton(
        onPressed: () => context.go('/vital-signs'),
        child: Text(
          ref
                  .read(patientMonitoringRolesProvider)
                  .any([kRoleNurse, kRoleAdmin].contains)
              ? 'Registrar signos vitales'
              : 'Ver signos vitales',
        ),
      ),
      if (vitals.isEmpty) const Text('No hay signos vitales en este periodo.'),
      for (final v in vitals)
        _card(_time(v.recordedAt), [
          'Presión: ${v.systolic}/${v.diastolic} mmHg · FC: ${v.heartRate} lpm',
          'FR: ${v.respiratoryRate} rpm · SpO₂: ${v.oxygenSaturation} %',
          'Temperatura: ${v.temperature} °C · Riesgo: ${v.riskLabel}',
        ]),
      _title('Eventos clínicos (${events.length})'),
      if (events.isEmpty)
        const Text('No hay eventos clínicos en este periodo.'),
      for (final e in events)
        _card(e.title, [
          '${_time(e.occurredAt)} · ${ClinicalEventType.labelFor(e.eventType)}',
          'Severidad: ${ClinicalEventSeverity.labelFor(e.severity)}',
          e.description,
          if (e.registeredBy.isNotEmpty) 'Registrado por: ${e.registeredBy}',
        ]),
      _title('Alertas (${history.alerts.length})'),
      TextButton(
        onPressed: () => context.go('/alerts'),
        child: const Text('Ver todas las alertas'),
      ),
      const Text('Las alertas se muestran sin filtro de fechas.'),
      if (history.alerts.isEmpty) const Text('No hay alertas registradas.'),
      for (final a in history.alerts)
        _card(a.title, [
          a.message,
          '${a.severityLabel} · ${a.statusLabel}',
          a.triggeredAt == null
              ? 'Generada: sin información'
              : 'Generada: ${_time(a.triggeredAt!)}',
          if (a.attendedBy != null) 'Atendida por: ${a.attendedBy}',
          if (a.attendedAt != null) 'Atendida: ${_time(a.attendedAt!)}',
          if (a.closedBy != null) 'Cerrada por: ${a.closedBy}',
          if (a.closedAt != null) 'Cerrada: ${_time(a.closedAt!)}',
          if (a.resolutionNotes?.isNotEmpty == true)
            'Resolución: ${a.resolutionNotes}',
        ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final patient = ref.watch(patientDetailProvider(_providerId));
    final allowed = PatientMonitoringRules.canRead(
      ref.watch(patientMonitoringRolesProvider),
    );
    final history = allowed && patient.hasValue && !patient.hasError
        ? ref.watch(patientHistoryProvider(_providerId))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento del paciente'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/patients');
            }
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: !allowed
              ? [
                  const Text(
                    'No tienes permiso para consultar el seguimiento del paciente.',
                  ),
                ]
              : patient.when(
                  loading: () => [
                    const Center(child: CircularProgressIndicator()),
                  ],
                  error: (error, _) => [
                    _error(
                      error,
                      () => ref.invalidate(patientDetailProvider(_providerId)),
                    ),
                  ],
                  data: (p) => [
                    Text(
                      p.fullName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    _card('${p.code} · ${p.statusLabel}', [
                      'Documento: ${p.documentNumber} · ${p.age} años',
                      'Nacimiento: ${_date(p.birthDate)} · Ingreso: ${_date(p.admissionDate)}',
                      'Género: ${PatientRules.genders[p.gender] ?? p.gender}',
                      'Habitación: ${p.roomNumber} · Cama: ${p.bedNumber}',
                      'Médico tratante: ${p.attendingPhysician}',
                      'Diagnóstico: ${p.diagnosis}',
                    ]),
                    ...?history?.when(
                      loading: () => [
                        const LinearProgressIndicator(),
                        const Text('Cargando historial…'),
                      ],
                      error: (error, _) => [
                        _error(
                          error,
                          () => ref.invalidate(
                            patientHistoryProvider(_providerId),
                          ),
                        ),
                      ],
                      data: _history,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
