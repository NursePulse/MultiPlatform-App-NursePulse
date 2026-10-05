import '../../../shared/widgets/page_action.dart';
import '../../../shared/widgets/list_page_body.dart';
import '../../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/clinical_card.dart';
import '../../patient/application/patient_notifier.dart';
import '../application/sbar_notifier.dart';
import '../domain/sbar_rules.dart';
import '../domain/sbar_transfer.dart';
import 'sbar_form_dialog.dart';
import 'sbar_detail_dialog.dart';

class SbarListView extends ConsumerStatefulWidget {
  const SbarListView({super.key});
  @override
  ConsumerState<SbarListView> createState() => _SbarListViewState();
}

class _SbarListViewState extends ConsumerState<SbarListView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(sbarNotifierProvider.notifier).load();
      if (SbarRules.canRead(ref.read(sbarUserProvider)?.roles ?? [])) {
        ref.read(patientNotifierProvider.notifier).load();
      }
    });
  }

  Future<void> _acknowledge(SbarTransfer transfer) async {
    try {
      await ref.read(sbarNotifierProvider.notifier).acknowledge(transfer.id);
      if (mounted) {
        final warning = ref.read(sbarNotifierProvider).warning;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(warning ?? 'Recepción del traspaso confirmada.'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(describeSbarError(e)))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sbarNotifierProvider);
    final allowed = ref.watch(sbarCanManageProvider);
    final patients = ref.watch(patientNotifierProvider).patients;
    final users = ref.watch(sbarUsersProvider).valueOrNull ?? [];
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListPageBody(
          header: [
            PageTitle(
              'Traspasos SBAR',
              subtitle: '${state.transfers.length} traspasos',
            ),
            if (allowed)
              PageAction(
                child: FilledButton.icon(
                  onPressed: state.saving ? null : () => showSbarForm(context),
                  icon: Icon(Icons.add),
                  label: Text(context.tr('Nuevo traspaso')),
                ),
              ),
            if (state.loading || state.saving) LinearProgressIndicator(),
            if (state.error != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: Text(context.tr(state.error!))),
                    TextButton(
                      onPressed: state.loading || state.saving
                          ? null
                          : () =>
                                ref.read(sbarNotifierProvider.notifier).load(),
                      child: Text(context.tr('Reintentar')),
                    ),
                  ],
                ),
              ),
            if (state.warning != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: Text(context.tr(state.warning!))),
                    IconButton(
                      tooltip: context.tr('Ocultar aviso'),
                      icon: Icon(Icons.close),
                      onPressed: () => ref
                          .read(sbarNotifierProvider.notifier)
                          .clearWarning(),
                    ),
                  ],
                ),
              ),
          ],
          child: RefreshIndicator(
            onRefresh: () => ref.read(sbarNotifierProvider.notifier).load(),
            child: ListView.builder(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: state.transfers.isEmpty ? 1 : state.transfers.length,
              itemBuilder: (context, index) {
                if (state.transfers.isEmpty) {
                  return state.loading || state.error != null
                      ? SizedBox.shrink()
                      : Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            context.tr(
                              'No hay traspasos SBAR registrados todavía.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                }
                final t = state.transfers[index];
                var patientName = context.tr('Paciente #${t.patientId}');
                for (final p in patients) {
                  if (p.id == t.patientId) patientName = p.fullName;
                }
                var receiver = t.targetNurseId == null
                    ? context.tr('Sin receptor asignado')
                    : context.tr('Enfermero #${t.targetNurseId}');
                for (final u in users) {
                  if (u.id == t.targetNurseId) receiver = u.username;
                }
                return Padding(
                  padding: EdgeInsets.zero,
                  child: ClinicalCard(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => SbarDetailDialog(transferId: t.id),
                    ),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              patientName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          SizedBox(width: 12),
                          Flexible(
                            child: StatusChip(
                              label: t.statusLabel,
                              palette: ClinicalColors.sbarStatus(t.status),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        t.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 8),
                      MetadataLine(
                        Icons.person_outline,
                        context.tr(
                          'De: ${t.registeredBy ?? context.tr('Sin información')}',
                        ),
                      ),
                      MetadataLine(
                        Icons.person_outline,
                        context.tr('Para: $receiver'),
                      ),
                      MetadataLine(
                        Icons.schedule,
                        t.transferredAt == null
                            ? context.tr('Fecha no disponible')
                            : DateFormat('dd/MM/yyyy HH:mm')
                                  .format(t.transferredAt!.toLocal()),
                      ),
                      SizedBox(height: 12),
                      for (final section in [
                        ('S', 'Situación', t.situation),
                        ('B', 'Antecedentes', t.background),
                        ('A', 'Evaluación', t.assessment),
                        ('R', 'Recomendación', t.recommendation),
                      ])
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(radius: 16, child: Text(section.$1)),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr(section.$2),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    SizedBox(height: 4),
                                    Text(section.$3),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      Divider(),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  SbarDetailDialog(transferId: t.id),
                            ),
                            child: Text(context.tr('Ver detalle')),
                          ),
                          if (allowed &&
                              t.canAcknowledge &&
                              !state.confirmedAcknowledgements.contains(t.id))
                            FilledButton.icon(
                              key: ValueKey('sbar-ack-${t.id}'),
                              icon: Icon(Icons.check_circle_outline),
                              label: Text(context.tr('Confirmar recepción')),
                              onPressed: state.saving
                                  ? null
                                  : () => _acknowledge(t),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
