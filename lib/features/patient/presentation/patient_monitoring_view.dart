import '../../../shared/widgets/vital_metrics.dart';
import '../../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/clinical_card.dart';
import '../../../shared/widgets/status_chip.dart';

import '../../clinical_event/domain/clinical_event.dart';
import '../../notification/domain/alert.dart';
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
      helpText: context.tr('Periodo de signos y eventos'),
      saveText: context.tr('Aplicar'),
    );

    if (mounted && picked != null) {
      final error = PatientMonitoringRules.period(
        picked.start,
        picked.end,
        today: today,
      );
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr(error))));
      } else {
        setState(() => _period = picked);
      }
    }
  }

  Widget _error(Object error, VoidCallback retry) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(context.tr(describePatientError(error))),
      TextButton(onPressed: retry, child: Text(context.tr('Reintentar'))),
    ],
  );

  Widget _title(String text) => Padding(
    padding: EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      context.tr(text),
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );

  Widget _card(
    String title,
    List<String> lines, {
    Color? accent,
    List<Widget> tags = const [],
  }) => ClinicalCard(
    accent: accent,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      SizedBox(height: 12),
      if (tags.isNotEmpty) ...[
        Wrap(spacing: 8, runSpacing: 8, children: tags),
        SizedBox(height: 12),
      ],
      for (final line in lines)
        Padding(padding: EdgeInsets.only(bottom: 8), child: Text(line)),
    ],
  );

  List<Widget> _history(PatientHistory history) {
    bool inPeriod(DateTime date) =>
        PatientRules.inPeriod(date, from: _period?.start, to: _period?.end);

    final vitals = history.vitals.where((v) => inPeriod(v.recordedAt)).toList();
    final events = history.events.where((e) => inPeriod(e.occurredAt)).toList();

    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StatusChip(
            label:
                'Alertas activas: ${history.alerts.where((a) => a.isActive).length}',
            palette: history.alerts.any((a) => a.isActive)
                ? ClinicalColors.alertOpen
                : ClinicalColors.alertClosed,
          ),
          StatusChip(
            label:
                'Último riesgo registrado: ${context.tr(history.vitals.isEmpty ? 'Sin registros' : history.vitals.first.riskLabel)}',
            palette: history.vitals.isEmpty
                ? ClinicalColors.riskUnassessed
                : ClinicalColors.risk(
                    history.vitals.first.riskLevel.name.toUpperCase(),
                  ),
          ),
        ],
      ),
      SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _pickPeriod,
            icon: Icon(Icons.date_range),
            label: Text(
              context.tr(
                _period == null
                    ? 'Filtrar signos y eventos'
                    : '${_date(_period!.start)} – ${_date(_period!.end)}',
              ),
            ),
          ),
          if (_period != null)
            TextButton(
              onPressed: () => setState(() => _period = null),
              child: Text(context.tr('Ver todo')),
            ),
        ],
      ),
      _title('Signos vitales (${vitals.length})'),
      TextButton(
        onPressed: () => context.go('/vital-signs'),
        child: Text(
          context.tr(
            ref
                    .read(patientMonitoringRolesProvider)
                    .any([kRoleNurse, kRoleAdmin].contains)
                ? 'Registrar signos vitales'
                : 'Ver signos vitales',
          ),
        ),
      ),
      if (vitals.isEmpty)
        Text(context.tr('No hay signos vitales en este periodo.')),
      for (final v in vitals)
        ClinicalCard(
          children: [
            Text(
              _time(v.recordedAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: 12),
            StatusChip(
              label: v.riskLabel,
              palette: ClinicalColors.risk(v.riskLevel.name.toUpperCase()),
            ),
            SizedBox(height: 16),
            VitalMetrics(v),
          ],
        ),
      _title('Eventos clínicos (${events.length})'),
      if (events.isEmpty)
        Text(context.tr('No hay eventos clínicos en este periodo.')),
      for (final e in events)
        _card(e.title, [
          '${_time(e.occurredAt)} · ${context.tr(ClinicalEventType.labelFor(e.eventType))}',
          context.tr(
            'Severidad: ${context.tr(ClinicalEventSeverity.labelFor(e.severity))}',
          ),
          e.description,
          if (e.registeredBy.isNotEmpty)
            context.tr('Registrado por: ${e.registeredBy}'),
        ], accent: ClinicalColors.severity(e.severity).foreground),
      _title('Alertas (${history.alerts.length})'),
      TextButton(
        onPressed: () => context.go('/alerts'),
        child: Text(context.tr('Ver todas las alertas')),
      ),
      Text(context.tr('Las alertas se muestran sin filtro de fechas.')),
      if (history.alerts.isEmpty)
        Text(context.tr('No hay alertas registradas.')),
      for (final a in history.alerts)
        _card(
          a.title,
          [
            a.message,
            a.triggeredAt == null
                ? context.tr('Generada: sin información')
                : context.tr('Generada: ${_time(a.triggeredAt!)}'),
            if (a.attendedBy != null)
              context.tr('Atendida por: ${a.attendedBy}'),
            if (a.attendedAt != null)
              context.tr('Atendida: ${_time(a.attendedAt!)}'),
            if (a.closedBy != null) context.tr('Cerrada por: ${a.closedBy}'),
            if (a.closedAt != null)
              context.tr('Cerrada: ${_time(a.closedAt!)}'),
            if (a.resolutionNotes?.isNotEmpty == true)
              context.tr('Resolución: ${a.resolutionNotes}'),
          ],
          accent: ClinicalColors.severity(a.severity.wireValue).foreground,
          tags: [
            StatusChip(
              label: a.severityLabel,
              palette: ClinicalColors.severity(a.severity.wireValue),
            ),
            StatusChip(
              label: a.statusLabel,
              palette: ClinicalColors.alertStatus(a.status.wireValue),
            ),
          ],
        ),
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.all(20),
          physics: AlwaysScrollableScrollPhysics(),
          children: [
            ...(!allowed
                ? [
                    Text(
                      context.tr(
                        'No tienes permiso para consultar el seguimiento del paciente.',
                      ),
                    ),
                  ]
                : patient.when(
                    loading: () => [Center(child: CircularProgressIndicator())],
                    error: (error, _) => [
                      _error(
                        error,
                        () =>
                            ref.invalidate(patientDetailProvider(_providerId)),
                      ),
                    ],
                    data: (p) => [
                      ClinicalCard(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                child: Text(p.initials),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      p.fullName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    Text(p.code),
                                    SizedBox(height: 6),
                                    StatusChip(
                                      label: context.patientStatus(
                                        p.statusLabel,
                                      ),
                                      palette: ClinicalColors.patientStatus(
                                        p.statusLabel,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          InfoField(
                            'Documento:',
                            '${p.documentNumber} · ${p.age} ${context.tr('años')}',
                          ),
                          InfoGrid(
                            fields: [
                              InfoField('Habitación:', p.roomNumber),
                              InfoField('Cama:', p.bedNumber),
                              InfoField('Nacimiento:', _date(p.birthDate)),
                              InfoField('Ingreso:', _date(p.admissionDate)),
                            ],
                          ),
                          Divider(),
                          InfoField(
                            'Género:',
                            context.tr(
                              PatientRules.genders[p.gender] ?? p.gender,
                            ),
                          ),
                          InfoField('Médico tratante:', p.attendingPhysician),
                          InfoField('Diagnóstico:', p.diagnosis),
                        ],
                      ),
                      SizedBox(height: 12),
                      ...?history?.when(
                        loading: () => [
                          LinearProgressIndicator(),
                          Text(context.tr('Cargando historial…')),
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
                  )),
          ],
        ),
      ),
    );
  }
}
