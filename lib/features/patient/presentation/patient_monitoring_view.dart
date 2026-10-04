import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../clinical_event/application/clinical_event_notifier.dart';
import '../../clinical_event/domain/clinical_event.dart';
import '../../notification/application/alert_notifier.dart';
import '../../notification/domain/alert.dart';
import '../../vital_sign/application/vital_sign_notifier.dart';
import '../../vital_sign/domain/vital_sign.dart';
import '../application/patient_notifier.dart';
import '../domain/patient.dart';

final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

class PatientMonitoringView extends ConsumerStatefulWidget {
  const PatientMonitoringView({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<PatientMonitoringView> createState() =>
      _PatientMonitoringViewState();
}

class _PatientMonitoringViewState extends ConsumerState<PatientMonitoringView> {
  late Future<(List<VitalSign>, List<ClinicalEvent>, List<Alert>)> _future;
  DateTime? _periodFrom;
  DateTime? _periodTo;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  bool _inPeriod(DateTime value) {
    if (_periodFrom != null && value.isBefore(_periodFrom!)) return false;
    if (_periodTo != null &&
        value.isAfter(_periodTo!.add(const Duration(days: 1)))) {
      return false;
    }
    return true;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _periodFrom : _periodTo) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _periodFrom = picked;
      } else {
        _periodTo = picked;
      }
    });
  }

  void _clearPeriod() => setState(() {
    _periodFrom = null;
    _periodTo = null;
  });

  Future<(List<VitalSign>, List<ClinicalEvent>, List<Alert>)> _load() async {
    final results = await Future.wait([
      ref
          .read(vitalSignNotifierProvider.notifier)
          .loadForPatient(widget.patientId),
      ref
          .read(clinicalEventNotifierProvider.notifier)
          .loadForPatient(widget.patientId),
      ref.read(alertNotifierProvider.notifier).loadForPatient(widget.patientId),
    ]);
    return (
      results[0] as List<VitalSign>,
      results[1] as List<ClinicalEvent>,
      results[2] as List<Alert>,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.read(patientNotifierProvider).patients.isEmpty) {
      Future.microtask(() => ref.read(patientNotifierProvider.notifier).load());
    }
    final patient = ref
        .watch(patientNotifierProvider.notifier)
        .byId(widget.patientId);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 16, 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/patients'),
                ),
                Expanded(
                  child: Text(
                    patient?.fullName ?? 'Paciente',
                    style: Theme.of(context).textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(describeDioError(snapshot.error!)));
                }
                final (allVitals, allEvents, alerts) = snapshot.data!;
                final vitals = allVitals
                    .where((v) => _inPeriod(v.recordedAt))
                    .toList();
                final events = allEvents
                    .where((e) => _inPeriod(e.occurredAt))
                    .toList();
                final hasPeriodFilter =
                    _periodFrom != null || _periodTo != null;
                return RefreshIndicator(
                  onRefresh: () async => setState(() => _future = _load()),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (patient != null) _PatientHeaderCard(patient: patient),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _pickDate(isFrom: true),
                              child: Text(
                                _periodFrom == null
                                    ? 'Desde'
                                    : DateFormat('dd/MM/yyyy')
                                          .format(_periodFrom!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _pickDate(isFrom: false),
                              child: Text(
                                _periodTo == null
                                    ? 'Hasta'
                                    : DateFormat('dd/MM/yyyy')
                                          .format(_periodTo!),
                              ),
                            ),
                          ),
                          if (hasPeriodFilter) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Ver todo',
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: _clearPeriod,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Signos vitales',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (vitals.isEmpty)
                        Text(
                          hasPeriodFilter
                              ? 'No hay información registrada en el periodo consultado.'
                              : 'Sin registros todavía.',
                        ),
                      for (final v in vitals)
                        Card(
                          child: ListTile(
                            title: Text(
                              '${v.bloodPressureFormatted} · ${v.heartRateFormatted} · SpO2 ${v.oxygenSaturation}%',
                            ),
                            subtitle: Text(_dateFormat.format(v.recordedAt)),
                            trailing: StatusChip(
                              label: v.riskLabel,
                              palette: ClinicalColors.risk(
                                v.riskLevel.wireValue,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        'Eventos clínicos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (events.isEmpty)
                        Text(
                          hasPeriodFilter
                              ? 'No hay información registrada en el periodo consultado.'
                              : 'Sin eventos registrados.',
                        ),
                      for (final e in events)
                        Card(
                          child: ListTile(
                            title: Text(e.title),
                            subtitle: Text(
                              '${ClinicalEventType.labelFor(e.eventType)} · '
                              '${_dateFormat.format(e.occurredAt)}',
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        'Alertas',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (alerts.isEmpty) const Text('Sin alertas.'),
                      for (final a in alerts)
                        Card(
                          child: ListTile(
                            title: Text(a.title),
                            subtitle: Text(a.message),
                            trailing: StatusChip(
                              label: a.statusLabel,
                              palette: ClinicalColors.alertStatus(
                                a.status.wireValue,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientHeaderCard extends StatelessWidget {
  const _PatientHeaderCard({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              patient.fullName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${patient.diagnosis} · ${patient.age} años · ${patient.statusLabel}',
            ),
            Text(
              'Habitación ${patient.roomNumber}-${patient.bedNumber} · ${patient.attendingPhysician}',
            ),
          ],
        ),
      ),
    );
  }
}
