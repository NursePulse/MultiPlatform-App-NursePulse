import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/page_title.dart';
import '../application/audit_notifier.dart';
import '../domain/audit_rules.dart';

class AuditLogListView extends ConsumerWidget {
  const AuditLogListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(auditNotifierProvider);
    final allowed = AuditRules.canRead(ref.watch(auditUserProvider));
    final catalog = allowed ? ref.watch(auditPatientsProvider) : null;
    final patients = catalog?.valueOrNull ?? const [];
    final choices = {
      for (final patient in patients) patient.id: patient.fullName,
    };
    final selected = state.selectedPatientId;
    if (selected != null && !choices.containsKey(selected)) {
      choices[selected] = 'Paciente #$selected';
    }
    final notifier = ref.read(auditNotifierProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageTitle('Auditoría'),
            if (state.loading || state.exporting)
              const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: notifier.reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: !allowed
                      ? [
                          const Text(
                            'Solo Doctor o Admin pueden consultar Auditoría.',
                          ),
                        ]
                      : [
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                state.hasLoaded
                                    ? '${state.logs.length} movimientos consultados'
                                    : 'Consulta de movimientos',
                              ),
                              OutlinedButton.icon(
                                key: const ValueKey('audit-export'),
                                icon: const Icon(Icons.picture_as_pdf),
                                onPressed:
                                    state.exporting ||
                                        state.loading ||
                                        !state.hasLoaded
                                    ? null
                                    : () async {
                                        try {
                                          await notifier.exportPdf();
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      describeAuditError(e),
                                                    ),
                                                  ),
                                                );
                                          }
                                        }
                                      },
                                label: Text(
                                  state.exporting
                                      ? 'Exportando…'
                                      : notifier.hasPendingPdf
                                      ? 'Guardar PDF pendiente'
                                      : 'Exportar PDF',
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'El PDF incluye hasta 200 movimientos del filtro seleccionado.',
                          ),
                          if (state.exportNotice != null)
                            Text(
                              state.exportNotice!,
                              key: const ValueKey('audit-export-notice'),
                            ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey('audit-patient-${selected ?? 'all'}'),
                            initialValue: selected ?? '',
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Filtrar por paciente',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Todos los pacientes'),
                              ),
                              for (final entry in choices.entries)
                                DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(
                                    entry.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: state.exporting
                                ? null
                                : (id) {
                                    if (id == null) return;
                                    if (id.isEmpty) {
                                      notifier.load();
                                    } else {
                                      notifier.loadForPatient(id);
                                    }
                                  },
                          ),
                          if (catalog?.isLoading == true)
                            const Text('Cargando pacientes…'),
                          if (catalog?.hasError == true) ...[
                            const Text(
                              'No se pudo cargar el catálogo de pacientes.',
                            ),
                            TextButton(
                              key: const ValueKey('audit-patients-retry'),
                              onPressed: () =>
                                  ref.invalidate(auditPatientsProvider),
                              child: const Text('Reintentar pacientes'),
                            ),
                          ],
                          if (selected != null)
                            const Text(
                              'Historial del paciente: del más antiguo al más reciente.',
                            ),
                          if (state.error != null) ...[
                            Text(
                              state.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            if (state.hasLoaded)
                              const Text(
                                'Se muestran los datos de la última consulta completada.',
                              ),
                            TextButton(
                              key: const ValueKey('audit-retry'),
                              onPressed: state.loading ? null : notifier.reload,
                              child: const Text('Reintentar'),
                            ),
                          ],
                          if (state.hasLoaded && state.logs.isEmpty)
                            const Text('No hay movimientos de auditoría.'),
                          for (final log in state.logs)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${log.code} · ${log.actionLabel}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    Text(log.description),
                                    Text('${log.entityLabel} #${log.entityId}'),
                                    Text(
                                      'Por ${log.performedBy} · ${DateFormat('dd/MM/yyyy HH:mm').format(log.performedAt.toLocal())}',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (selected == null &&
                              state.totalElements != null) ...[
                            Text('${state.totalElements} movimientos en total'),
                            if ((state.totalPages ?? 0) > 0)
                              Text(
                                'Página ${state.page + 1} de ${state.totalPages}',
                              ),
                            Wrap(
                              spacing: 12,
                              children: [
                                TextButton(
                                  key: const ValueKey('audit-previous'),
                                  onPressed:
                                      state.loading ||
                                          state.exporting ||
                                          state.page == 0
                                      ? null
                                      : () => notifier.loadPage(state.page - 1),
                                  child: const Text('Anterior'),
                                ),
                                TextButton(
                                  key: const ValueKey('audit-next'),
                                  onPressed:
                                      state.loading ||
                                          state.exporting ||
                                          state.last
                                      ? null
                                      : () => notifier.loadPage(state.page + 1),
                                  child: const Text('Siguiente'),
                                ),
                              ],
                            ),
                          ],
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
