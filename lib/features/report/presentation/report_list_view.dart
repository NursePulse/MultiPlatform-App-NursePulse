import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_title.dart';
import '../application/report_notifier.dart';
import '../domain/report.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');

class ReportListView extends ConsumerStatefulWidget {
  const ReportListView({super.key});

  @override
  ConsumerState<ReportListView> createState() => _ReportListViewState();
}

class _ReportListViewState extends ConsumerState<ReportListView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(reportNotifierProvider.notifier).load());
  }

  Future<void> _showGenerateDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _GenerateReportDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportNotifierProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGenerateDialog,
        icon: const Icon(Icons.add_chart_rounded),
        label: const Text('Generar reporte'),
      ),
      body: Column(
        children: [
          const PageTitle('Reportes'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(reportNotifierProvider.notifier).load(),
              child: AsyncValueView<ReportState>(
                loading: state.loading,
                error: state.error,
                data: state,
                isEmpty: (s) => s.reports.isEmpty,
                emptyMessage: 'Aún no generaste ningún reporte.',
                onRetry: () => ref.read(reportNotifierProvider.notifier).load(),
                builder: (context, s) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: s.reports.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final report = s.reports[index];
              final summary = report.summary;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${ReportType.labelFor(report.type)} · '
                        '${_dateFormat.format(report.startDate)} - '
                        '${_dateFormat.format(report.endDate)} · '
                        'por ${report.generatedBy}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (summary != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            Text('Pacientes: ${summary.patients}'),
                            Text('Signos vitales: ${summary.vitalSigns}'),
                            Text('Eventos: ${summary.clinicalEvents}'),
                            Text('SBAR: ${summary.sbarTransfers}'),
                            Text('Alertas activas: ${summary.activeAlerts}'),
                            Text('Críticas: ${summary.criticalAlerts}'),
                            Text('Auditorías: ${summary.auditLogs}'),
                          ],
                        ),
                      ],
                      if (report.clinicalConclusion != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          report.clinicalConclusion!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(reportNotifierProvider.notifier)
          .generate(
            type: _type,
            title: _title.text.trim(),
            startDate: _startDate,
            endDate: _endDate,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = describeDioError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generar reporte'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Requerido'
                    : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
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
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(isStart: true),
                      child: Text(
                        'Desde ${_dateFormat.format(_startDate)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(isStart: false),
                      child: Text('Hasta ${_dateFormat.format(_endDate)}'),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Generar'),
        ),
      ],
    );
  }
}
