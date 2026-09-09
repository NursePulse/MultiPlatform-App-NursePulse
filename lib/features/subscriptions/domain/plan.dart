enum PlanId { essential, professional, enterprise }

class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.features,
    required this.maxSeats,
    required this.highlighted,
  });

  final PlanId id;
  final String name;
  final String description;
  final num monthlyPrice;
  final List<String> features;
  final int maxSeats;
  final bool highlighted;
}

const kPlanCatalog = [
  Plan(
    id: PlanId.essential,
    name: 'Esencial',
    description: 'Lo justo para empezar a digitalizar el seguimiento clínico.',
    monthlyPrice: 0,
    features: [
      'Gestión de pacientes',
      'Registro de signos vitales',
      'Alertas clínicas',
    ],
    maxSeats: 5,
    highlighted: false,
  ),
  Plan(
    id: PlanId.professional,
    name: 'Profesional',
    description: 'Para equipos clínicos que necesitan traspasos y reportes.',
    monthlyPrice: 49,
    features: [
      'Gestión de pacientes',
      'Registro de signos vitales',
      'Alertas clínicas',
      'Traspasos SBAR',
      'Reportes',
    ],
    maxSeats: 25,
    highlighted: true,
  ),
  Plan(
    id: PlanId.enterprise,
    name: 'Empresarial',
    description: 'Para instituciones con necesidades de auditoría y soporte prioritario.',
    monthlyPrice: 129,
    features: [
      'Gestión de pacientes',
      'Registro de signos vitales',
      'Alertas clínicas',
      'Traspasos SBAR',
      'Reportes',
      'Auditoría',
      'Soporte prioritario',
    ],
    maxSeats: 100,
    highlighted: false,
  ),
];
