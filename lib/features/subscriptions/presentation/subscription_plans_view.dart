import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/page_title.dart';
import '../application/subscription_notifier.dart';
import '../domain/plan.dart';
import 'payment_checkout_sheet.dart';

class SubscriptionPlansView extends ConsumerWidget {
  const SubscriptionPlansView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionNotifierProvider);
    final actor = ref.watch(subscriptionUserProvider);
    final allowed = actor != null && actor.hasKnownRole;
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: Column(
        children: [
          const PageTitle('Suscripciones'),
          if (state.loading || state.processing)
            const LinearProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  const Text(
                    'Simulación de suscripción. No se realizan cobros reales.',
                  ),
                  if (!allowed)
                    const Text('Inicia sesión para seleccionar un plan.'),
                  if (state.error != null) Text(state.error!),
                  if (allowed &&
                      state.error != null &&
                      state.pendingPlan == null)
                    TextButton(
                      onPressed: state.loading || state.processing
                          ? null
                          : ref
                                .read(subscriptionNotifierProvider.notifier)
                                .load,
                      child: const Text('Reintentar carga'),
                    ),
                  if (allowed && state.pendingPlan != null)
                    TextButton(
                      key: const ValueKey('subscription-save-pending'),
                      onPressed: state.processing
                          ? null
                          : () async {
                              try {
                                await ref
                                    .read(subscriptionNotifierProvider.notifier)
                                    .selectPlan(state.pendingPlan!);
                              } catch (_) {}
                            },
                      child: const Text('Guardar plan pendiente'),
                    ),
                  for (final plan in kPlanCatalog)
                    SizedBox(
                      width: isWide ? 320 : double.infinity,
                      child: _PlanCard(
                        plan: plan,
                        isCurrent: plan.id == state.planId,
                        enabled:
                            allowed &&
                            !state.loading &&
                            !state.processing &&
                            state.pendingPlan == null,
                        onSelect: () async {
                          if (plan.monthlyPrice == 0) {
                            try {
                              await ref
                                  .read(subscriptionNotifierProvider.notifier)
                                  .selectPlan(plan.id);
                            } catch (_) {}
                            return;
                          }
                          await showPaymentCheckoutSheet(context, plan);
                        },
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.enabled,
    required this.onSelect,
  });

  final Plan plan;
  final bool isCurrent;
  final bool enabled;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: plan.highlighted ? scheme.primary : scheme.outlineVariant,
          width: plan.highlighted ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plan.highlighted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Recomendado',
                  style: TextStyle(color: scheme.onPrimary, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              plan.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              plan.monthlyPrice == 0 ? 'Gratis' : '\$${plan.monthlyPrice}/mes',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text('Hasta ${plan.maxSeats} usuarios'),
            const SizedBox(height: 12),
            for (final feature in plan.features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.check_rounded, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: ValueKey('subscription-select-${plan.id.name}'),
              onPressed: isCurrent || !enabled ? null : onSelect,
              child: Text(isCurrent ? 'Plan actual' : 'Elegir plan'),
            ),
          ],
        ),
      ),
    );
  }
}
