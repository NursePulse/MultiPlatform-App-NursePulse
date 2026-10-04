# Fase Pacientes

Estado actualizado, 2026-10-04: **integrado en test** mediante PR #8,
merge `c66ef0d`, incluido en la base actual `7179383` (PR #13).
Las secciones de preparación y verificación siguientes son históricas;
las regresiones actuales se registran en
[Reportes y suscripciones](reports-subscriptions-validation.md).

Base: test actualizado tras PR #7 (`4bb6b38`).
Rama: feature/patient-validation.

## Estado de integración

Comprobado el 2026-10-04 mediante Git local y `git ls-remote origin`:
`test` local y remoto siguen en `4bb6b38`. La fase Pacientes se prepara
en `feature/patient-validation` para un PR hacia `test`; todavía no está integrada.
Eventos clínicos debe comenzar desde `test` actualizado después de integrar
Pacientes. El merge permanece pendiente de revisión.

## Comportamiento

- Valida nombres, documento, nacimiento, género, diagnóstico, habitación,
  cama, médico tratante y fecha de ingreso.
- Nombres: letras y espacios, máximo 80.
- Documento: 8–20 dígitos, preservando ceros iniciales.
- Nacimiento: desde 1930-01-01 hasta hoy.
- Diagnóstico: máximo 180; habitación y cama: máximo 20.
- Médico tratante: catálogo de usuarios Doctor; conserva el médico al editar.
- Ingreso: obligatorio en formulario y no futuro.
- Rechaza documentos duplicados, excluyendo al propio paciente al editar.
- Crear: Nurse/Admin. Editar y dar de alta: Nurse/Doctor/Admin.
- Eliminar: Admin.
- Bloquea envíos simultáneos y conserva datos ante errores.
- Dar de alta conserva los datos originales y cambia únicamente el estado.
- El listado permite buscar, recargar y reintentar.
- El detalle consulta por ID sin depender de cargar antes el listado.
- La ficha permanece disponible si falla el historial.
- El historial ordena signos y eventos por fecha y permite filtrar por periodo.
- Guardar signos vitales actualiza el historial del paciente.
- Las alertas se muestran sin filtro de fechas.
- La edad 18–90 corresponde al registro de usuarios, no a pacientes.
- Backend y dependencias sin modificaciones.

## Verificación

- Comprobado el 2026-10-04 en Windows: Flutter 3.47.2 y Dart 3.13.2.
- `dart format lib test`: 80 archivos, ninguno modificado.
- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub`: 81 pruebas aprobadas en la suite completa,
  incluidas las 26 pruebas de Pacientes con APIs simuladas.
- `git diff --check`: sin incidencias.
- `flutter build apk --release --no-pub
  --dart-define=API_BASE_URL=https://backend-nursepulse-qfct.onrender.com/api/v1`:
  compilación aprobada; APK en `build/app/outputs/flutter-apk/app-release.apk`
  (53.0 MB). Compilar no acredita la integración manual con la API.
- Sin actualización de SDK, paquetes ni herramientas.

Pendiente:

- Revisión del APK por el tester e integración manual con la API existente.
- Comprobaciones de CI cuando se autorice crear el PR hacia `test`.

## Revisión manual del tester

Usar cuentas de prueba y pacientes ficticios autorizados:

- Crear y editar: errores por campo, límites, documento con ceros iniciales,
  duplicados y selección de médico tratante.
- Verificar que Doctor no puede crear y que solo Admin puede eliminar.
- Comprobar conservación del formulario ante errores y bloqueo de doble envío.
- Buscar, recargar y abrir el detalle directamente por ID.
- Verificar fechas y orden del historial y su actualización al registrar signos.
- Dar de alta y comprobar que conserva los datos originales.
- Registrar resultado, dispositivo y bloqueos de la API antes del merge.
