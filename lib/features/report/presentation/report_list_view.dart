import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/page_title.dart';
import '../application/report_notifier.dart';
import '../domain/report.dart';
import '../domain/report_rules.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');

class ReportListView extends ConsumerWidget {
  const ReportListView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportNotifierProvider);
    final allowed = ReportRules.canGenerate(ref.watch(reportUserProvider));
    final notifier = ref.read(reportNotifierProvider.notifier);
    return Scaffold(
      floatingActionButton: !allowed
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('report-new'),
              onPressed: state.loading || state.generating
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const _GenerateReportDialog(),
                    ),
              icon: const Icon(Icons.add_chart_rounded),
              label: const Text('Generar reporte'),
            ),
      body: SafeArea(
        child: Column(
          children: [
            const PageTitle('Reportes'),
            if (state.loading || state.generating)
              const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: notifier.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: !allowed
                      ? [
                          const Text(
                            'Solo Doctor o Admin pueden consultar y generar reportes.',
                          ),
                        ]
                      : [
                          const Text(
                            'Los reportes se guardan en este dispositivo.',
                          ),
                          Text('${state.reports.length} reportes'),
                          if (state.error != null) ...[
                            Text(
                              state.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            TextButton(
                              key: const ValueKey('report-retry'),
                              onPressed: state.loading || state.generating
                                  ? null
                                  : notifier.load,
                              child: const Text('Reintentar'),
                            ),
                          ],
                          if (state.warning != null)
                            Text(
                              state.warning!,
                              key: const ValueKey('report-warning'),
                            ),
                          if (state.reports.isEmpty &&
                              !state.loading &&
                              state.error == null)
                            const Text('Aún no generaste ningún reporte.'),
                          for (final report in state.reports)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      report.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text(
                                      '${ReportType.labelFor(report.type)} · ${ReportStatus.labelFor(report.status)}',
                                    ),
                                    Text(
                                      '${_dateFormat.format(report.startDate.toLocal())} - ${_dateFormat.format(report.endDate.toLocal())} · por ${report.generatedBy}',
                                    ),
                                    Text(
                                      'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(report.createdAt.toLocal())}',
                                    ),
                                    if (report.summary != null)
                                      _Summary(report.summary!),
                                    if (report.clinicalConclusion != null)
                                      Text(report.clinicalConclusion!),
                                    TextButton(
                                      key: ValueKey(
                                        'report-detail-${report.id}',
                                      ),
                                      onPressed: () => showDialog<void>(
                                        context: context,
                                        builder: (_) => _ReportDetail(report),
                                      ),
                                      child: const Text('Ver detalle'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.summary);
  final ReportSummary summary;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        Text('Pacientes: ${summary.patients}'),
        Text('Signos vitales: ${summary.vitalSigns}'),
        Text('Eventos: ${summary.clinicalEvents}'),
        Text('SBAR: ${summary.sbarTransfers}'),
        Text('Alertas activas: ${summary.activeAlerts}'),
        Text('Críticas activas: ${summary.criticalAlerts}'),
        Text('Auditorías: ${summary.auditLogs}'),
      ],
    ),
  );
}

class _ReportDetail extends StatelessWidget {
  const _ReportDetail(this.report);
  final Report report;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(report.title),
    scrollable: true,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${ReportType.labelFor(report.type)} · ${ReportStatus.labelFor(report.status)}',
        ),
        Text(
          'Periodo: ${_dateFormat.format(report.startDate.toLocal())} - ${_dateFormat.format(report.endDate.toLocal())}',
        ),
        Text(
          'Por ${report.generatedBy} · ${DateFormat('dd/MM/yyyy HH:mm').format(report.createdAt.toLocal())}',
        ),
        Text(ReportRules.tone(report.summary)),
        if (report.summary != null) ...[
          _Summary(report.summary!),
          Text('Actividad registrada: ${report.summary!.activityTotal}'),
        ],
        Text(report.clinicalConclusion ?? 'Sin conclusión.'),
        const SizedBox(height: 12),
        Text('ID: ${report.id}'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cerrar'),
      ),
    ],
  );
}

class _GenerateReportDialog extends ConsumerStatefulWidget {
  const _GenerateReportDialog();
  @override
  ConsumerState<_GenerateReportDialog> createState() =>
      _GenerateReportDialogState();
}

class _GenerateReportDialogState extends ConsumerState<_GenerateReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  String _type = ReportType.general;
  DateTime? _startDate, _endDate;
  bool _submitting = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final now = ref.read(reportClockProvider)();
    _endDate = ReportRules.day(now);
    _startDate = DateTime(now.year, now.month, now.day - 7);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          (start ? _startDate : _endDate) ?? ref.read(reportClockProvider)(),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (picked != null && mounted && !_submitting) {
      setState(() {
        if (start) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(reportNotifierProvider.notifier)
          .generate(
            type: _type,
            title: _title.text,
            startDate: _startDate,
            endDate: _endDate,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = describeReportError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _dateField(bool start, bool busy) {
    final date = start ? _startDate : _endDate;
    return TextFormField(
      key: ValueKey(
        'report-date-${start ? 'start' : 'end'}-${date?.toIso8601String() ?? 'empty'}',
      ),
      initialValue: date == null ? '' : _dateFormat.format(date),
      readOnly: true,
      enabled: !busy,
      decoration: InputDecoration(
        labelText: start ? 'Desde' : 'Hasta',
        suffixIcon: IconButton(
          key: ValueKey(start ? 'report-clear-start' : 'report-clear-end'),
          onPressed: busy || date == null
              ? null
              : () => setState(() {
                  if (start) {
                    _startDate = null;
                  } else {
                    _endDate = null;
                  }
                }),
          icon: const Icon(Icons.clear),
        ),
      ),
      onTap: busy ? null : () => _pickDate(start),
      validator: (_) => date == null
          ? 'Selecciona la fecha.'
          : ReportRules.dates(_startDate, _endDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allowed = ReportRules.canGenerate(ref.watch(reportUserProvider));
    final busy =
        _submitting ||
        ref.watch(reportNotifierProvider.select((s) => s.generating));
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: const Text('Generar reporte'),
        scrollable: true,
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('report-title'),
                  controller: _title,
                  enabled: !busy && allowed,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: ReportRules.title,
                ),
                DropdownButtonFormField<String>(
                  key: const ValueKey('report-type'),
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: [
                    for (final type in ReportType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(ReportType.labelFor(type)),
                      ),
                  ],
                  onChanged: busy || !allowed
                      ? null
                      : (value) => setState(() => _type = value ?? _type),
                ),
                _dateField(true, busy || !allowed),
                _dateField(false, busy || !allowed),
                if (_error != null)
                  Text(
                    _error!,
                    key: const ValueKey('report-form-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (!allowed)
                  const Text('Solo Doctor o Admin pueden generar reportes.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('report-cancel'),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('report-generate'),
            onPressed: busy || !allowed ? null : _submit,
            child: Text(busy ? 'Generando…' : 'Generar'),
          ),
        ],
      ),
    );
  }
}
