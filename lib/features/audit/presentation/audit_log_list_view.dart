import '../../../shared/widgets/list_page_body.dart';
import '../../../core/localization/app_strings.dart';

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
    final patients = catalog?.valueOrNull ?? [];
    final choices = {
      for (final patient in patients) patient.id: patient.fullName,
    };
    final selected = state.selectedPatientId;
    if (selected != null && !choices.containsKey(selected)) {
      choices[selected] = context.tr('Paciente #$selected');
    }
    final notifier = ref.read(auditNotifierProvider.notifier);
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListPageBody(
          header: [
            PageTitle('Auditoría'),
            if (state.loading || state.exporting) LinearProgressIndicator(),
          ],
          child: RefreshIndicator(
            onRefresh: notifier.reload,
            child: ListView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              children: !allowed
                  ? [
                      Text(
                        context.tr(
                          'Solo Doctor o Admin pueden consultar Auditoría.',
                        ),
                      ),
                    ]
                  : [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            context.tr(
                              state.hasLoaded
                                  ? '${state.logs.length} movimientos consultados'
                                  : 'Consulta de movimientos',
                            ),
                          ),
                          OutlinedButton.icon(
                            key: ValueKey('audit-export'),
                            icon: Icon(Icons.picture_as_pdf),
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              context.tr(describeAuditError(e)),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            label: Text(
                              context.tr(
                                state.exporting
                                    ? 'Exportando…'
                                    : notifier.hasPendingPdf
                                    ? 'Guardar PDF pendiente'
                                    : 'Exportar PDF',
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        context.tr(
                          'El PDF incluye hasta 200 movimientos del filtro seleccionado.',
                        ),
                      ),
                      if (state.exportNotice != null)
                        Text(
                          context.tr(state.exportNotice!),
                          key: ValueKey('audit-export-notice'),
                        ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('audit-patient-${selected ?? 'all'}'),
                        initialValue: selected ?? '',
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.tr('Filtrar por paciente'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(context.tr('Todos los pacientes')),
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
                        Text(context.tr('Cargando pacientes…')),
                      if (catalog?.hasError == true) ...[
                        Text(
                          context.tr(
                            'No se pudo cargar el catálogo de pacientes.',
                          ),
                        ),
                        TextButton(
                          key: ValueKey('audit-patients-retry'),
                          onPressed: () =>
                              ref.invalidate(auditPatientsProvider),
                          child: Text(context.tr('Reintentar pacientes')),
                        ),
                      ],
                      if (selected != null)
                        Text(
                          context.tr(
                            'Historial del paciente: del más antiguo al más reciente.',
                          ),
                        ),
                      if (state.error != null) ...[
                        Text(
                          context.tr(state.error!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        if (state.hasLoaded)
                          Text(
                            context.tr(
                              'Se muestran los datos de la última consulta completada.',
                            ),
                          ),
                        TextButton(
                          key: ValueKey('audit-retry'),
                          onPressed: state.loading ? null : notifier.reload,
                          child: Text(context.tr('Reintentar')),
                        ),
                      ],
                      if (state.hasLoaded && state.logs.isEmpty)
                        Text(context.tr('No hay movimientos de auditoría.')),
                      for (final log in state.logs)
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr(
                                    '${log.code} · ${context.tr(log.actionLabel)}',
                                  ),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(log.description),
                                Text(
                                  context.tr(
                                    '${context.tr(log.entityLabel)} #${log.entityId}',
                                  ),
                                ),
                                Text(
                                  context.tr(
                                    'Por ${log.performedBy} · ${DateFormat('dd/MM/yyyy HH:mm').format(log.performedAt.toLocal())}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (selected == null && state.totalElements != null) ...[
                        Text(
                          context.tr(
                            '${state.totalElements} movimientos en total',
                          ),
                        ),
                        if ((state.totalPages ?? 0) > 0)
                          Text(
                            context.tr(
                              'Página ${state.page + 1} de ${state.totalPages}',
                            ),
                          ),
                        Wrap(
                          spacing: 12,
                          children: [
                            TextButton(
                              key: ValueKey('audit-previous'),
                              onPressed:
                                  state.loading ||
                                      state.exporting ||
                                      state.page == 0
                                  ? null
                                  : () => notifier.loadPage(state.page - 1),
                              child: Text(context.tr('Anterior')),
                            ),
                            TextButton(
                              key: ValueKey('audit-next'),
                              onPressed:
                                  state.loading || state.exporting || state.last
                                  ? null
                                  : () => notifier.loadPage(state.page + 1),
                              child: Text(context.tr('Siguiente')),
                            ),
                          ],
                        ),
                      ],
                    ],
            ),
          ),
        ),
      ),
    );
  }
}
