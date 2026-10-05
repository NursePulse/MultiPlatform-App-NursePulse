import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/clinical_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_action.dart';
import '../../../shared/widgets/list_page_body.dart';
import '../../../core/localization/app_strings.dart';

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
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListPageBody(
          header: [
            PageTitle('Reportes'),
            if (allowed)
              PageAction(
                child: FilledButton.icon(
                  key: ValueKey('report-new'),
                  onPressed: state.loading || state.generating
                      ? null
                      : () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useRootNavigator: true,
                          isDismissible: false,
                          enableDrag: false,
                          constraints: BoxConstraints(maxWidth: 640),
                          builder: (_) => _GenerateReportDialog(),
                        ),
                  icon: Icon(Icons.add_chart_rounded),
                  label: Text(context.tr('Generar reporte')),
                ),
              ),
            if (state.loading || state.generating) LinearProgressIndicator(),
          ],
          child: RefreshIndicator(
            onRefresh: notifier.load,
            child: ListView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: !allowed
                  ? [
                      Text(
                        context.tr(
                          'Solo Doctor o Admin pueden consultar y generar reportes.',
                        ),
                      ),
                    ]
                  : [
                      InfoNotice(
                        context.tr(
                          'Los reportes se guardan en este dispositivo.',
                        ),
                      ),
                      Text(context.tr('${state.reports.length} reportes')),
                      if (state.error != null) ...[
                        Text(
                          context.tr(state.error!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          key: ValueKey('report-retry'),
                          onPressed: state.loading || state.generating
                              ? null
                              : notifier.load,
                          child: Text(context.tr('Reintentar')),
                        ),
                      ],
                      if (state.warning != null)
                        Text(
                          context.tr(state.warning!),
                          key: ValueKey('report-warning'),
                        ),
                      if (state.reports.isEmpty &&
                          !state.loading &&
                          state.error == null)
                        Text(context.tr('Aún no generaste ningún reporte.')),
                      for (final report in state.reports)
                        ClinicalCard(
                          children: [
                            Text(
                              report.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            SizedBox(height: 12),
                            StatusChip(
                              label: ReportStatus.labelFor(report.status),
                              palette: ClinicalColors.riskLow,
                            ),
                            SizedBox(height: 12),
                            MetadataLine(
                              Icons.description_outlined,
                              context.tr(ReportType.labelFor(report.type)),
                            ),
                            MetadataLine(
                              Icons.date_range,
                              '${_dateFormat.format(report.startDate.toLocal())} – ${_dateFormat.format(report.endDate.toLocal())}',
                            ),
                            MetadataLine(
                              Icons.person_outline,
                              context.tr('Por ${report.generatedBy}'),
                            ),
                            MetadataLine(
                              Icons.schedule,
                              context.tr(
                                'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(report.createdAt.toLocal())}',
                              ),
                            ),
                            if (report.summary != null) ...[
                              Divider(),
                              _Summary(report.summary!),
                            ],
                            if (report.clinicalConclusion != null)
                              InfoNotice(
                                context.tr(report.clinicalConclusion!),
                                warning:
                                    (report.summary?.criticalAlerts ?? 0) > 0,
                              ),
                            Divider(),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                key: ValueKey('report-detail-${report.id}'),
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (_) => _ReportDetail(report),
                                ),
                                child: Text(context.tr('Ver detalle')),
                              ),
                            ),
                          ],
                        ),
                    ],
            ),
          ),
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
    padding: EdgeInsets.symmetric(vertical: 8),
    child: InfoGrid(
      fields: [
        InfoField(
          'Pacientes',
          '${summary.patients}',
          key: ValueKey('report-summary-patients'),
        ),
        InfoField('Signos vitales', '${summary.vitalSigns}'),
        InfoField('Eventos', '${summary.clinicalEvents}'),
        InfoField('Traspasos SBAR', '${summary.sbarTransfers}'),
        InfoField('Alertas activas', '${summary.activeAlerts}'),
        InfoField('Críticas activas', '${summary.criticalAlerts}'),
        InfoField('Auditorías', '${summary.auditLogs}'),
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
    content: SizedBox(
      width: 420,
      height: MediaQuery.sizeOf(context).height * 0.5,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(
                '${context.tr(ReportType.labelFor(report.type))} · ${context.tr(ReportStatus.labelFor(report.status))}',
              ),
            ),
            Text(
              context.tr(
                'Periodo: ${_dateFormat.format(report.startDate.toLocal())} - ${_dateFormat.format(report.endDate.toLocal())}',
              ),
            ),
            Text(
              context.tr(
                'Por ${report.generatedBy} · ${DateFormat('dd/MM/yyyy HH:mm').format(report.createdAt.toLocal())}',
              ),
            ),
            Text(context.tr(ReportRules.tone(report.summary))),
            if (report.summary != null) ...[
              _Summary(report.summary!),
              Text(
                context.tr(
                  'Actividad registrada: ${report.summary!.activityTotal}',
                ),
              ),
            ],
            Text(context.tr(report.clinicalConclusion ?? 'Sin conclusión.')),
            SizedBox(height: 12),
            Text(context.tr('ID: ${report.id}')),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.tr('Cerrar')),
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
        labelText: context.tr(start ? 'Desde' : 'Hasta'),
        prefixIcon: Icon(Icons.date_range),
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
          icon: Icon(Icons.clear),
        ),
      ),
      onTap: busy ? null : () => _pickDate(start),
      validator: (_) => context.validation(
        date == null
            ? 'Selecciona la fecha.'
            : ReportRules.dates(_startDate, _endDate),
      ),
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
      child: FormSheet(
        title: 'Generar reporte',
        busy: busy,
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: ValueKey('report-title'),
                  controller: _title,
                  enabled: !busy && allowed,
                  decoration: InputDecoration(labelText: context.tr('Título')),
                  validator: (value) =>
                      context.validation(ReportRules.title(value)),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('report-type'),
                  initialValue: _type,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: context.tr('Tipo')),
                  items: [
                    for (final type in ReportType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(context.tr(ReportType.labelFor(type))),
                      ),
                  ],
                  onChanged: busy || !allowed
                      ? null
                      : (value) => setState(() => _type = value ?? _type),
                ),
                SizedBox(height: 16),
                _dateField(true, busy || !allowed),
                SizedBox(height: 16),
                _dateField(false, busy || !allowed),
                SizedBox(height: 12),
                Text(
                  context.tr('Incluye todo el día de la fecha final.'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SizedBox(height: 12),
                if (_error != null)
                  Text(
                    context.tr(_error!),
                    key: ValueKey('report-form-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (!allowed)
                  Text(
                    context.tr('Solo Doctor o Admin pueden generar reportes.'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: ValueKey('report-cancel'),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(context.tr('Cancelar')),
          ),
          FilledButton(
            key: ValueKey('report-generate'),
            onPressed: busy || !allowed ? null : _submit,
            child: Text(context.tr(busy ? 'Generando…' : 'Generar')),
          ),
        ],
      ),
    );
  }
}
