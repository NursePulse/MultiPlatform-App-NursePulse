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
    final currentPlanId = ref.watch(subscriptionNotifierProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: Column(
        children: [
          const PageTitle('Suscripciones'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final plan in kPlanCatalog)
                    SizedBox(
                      width: isWide ? 320 : double.infinity,
                      child: _PlanCard(
                        plan: plan,
                        isCurrent: plan.id == currentPlanId,
                        onSelect: () async {
                          if (plan.monthlyPrice == 0) {
                            ref
                                .read(subscriptionNotifierProvider.notifier)
                                .selectPlan(plan.id);
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
    required this.onSelect,
  });

  final Plan plan;
  final bool isCurrent;
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
              onPressed: isCurrent ? null : onSelect,
              child: Text(isCurrent ? 'Plan actual' : 'Elegir plan'),
            ),
          ],
        ),
      ),
    );
  }
}
