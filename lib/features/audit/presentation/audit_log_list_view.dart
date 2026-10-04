import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_title.dart';
import '../../patient/application/patient_notifier.dart';
import '../application/audit_notifier.dart';

final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

class AuditLogListView extends ConsumerStatefulWidget {
  const AuditLogListView({super.key});

  @override
  ConsumerState<AuditLogListView> createState() => _AuditLogListViewState();
}

class _AuditLogListViewState extends ConsumerState<AuditLogListView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(auditNotifierProvider.notifier).load();
      if (ref.read(patientNotifierProvider).patients.isEmpty) {
        ref.read(patientNotifierProvider.notifier).load();
      }
    });
  }

  void _reload() {
    final patientId = ref.read(auditNotifierProvider).selectedPatientId;
    if (patientId == null) {
      ref.read(auditNotifierProvider.notifier).load();
    } else {
      ref.read(auditNotifierProvider.notifier).loadForPatient(patientId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(auditNotifierProvider);
    final patients = ref.watch(patientNotifierProvider).patients;
    return Scaffold(
      body: Column(
        children: [
          const PageTitle('Auditoría'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: DropdownButtonFormField<String?>(
                      initialValue: state.selectedPatientId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Filtrar por paciente',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todos los pacientes'),
                        ),
                        for (final patient in patients)
                          DropdownMenuItem(
                            value: patient.id,
                            child: Text(patient.fullName),
                          ),
                      ],
                      onChanged: (patientId) {
                        if (patientId == null) {
                          ref.read(auditNotifierProvider.notifier).load();
                        } else {
                          ref
                              .read(auditNotifierProvider.notifier)
                              .loadForPatient(patientId);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: AsyncValueView<AuditState>(
                      loading: state.loading,
                      error: state.error,
                      data: state,
                      isEmpty: (s) => s.logs.isEmpty,
                      onRetry: _reload,
                      builder: (context, s) => ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: s.logs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = s.logs[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.receipt_long_rounded),
                              title: Text(
                                '${log.actionLabel} · ${log.entityLabel}',
                              ),
                              subtitle: Text(
                                'Por ${log.performedBy} · '
                                '${_dateFormat.format(log.performedAt)}',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
