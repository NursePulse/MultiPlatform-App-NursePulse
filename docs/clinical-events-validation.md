# Fase Eventos clínicos

## Base y alcance

Revisión y ejecución local: 2026-10-04.
Rama: `feature/clinical-events-validation`.
Base: `test`, commit `c66ef0d`, merge del PR #8 de Pacientes.
Git estaba limpio al comenzar. El usuario informó que el tester verificó
Signos vitales y Pacientes; esas pruebas manuales no fueron ejecutadas por Codex.

Se completa el registro y consulta de Eventos clínicos. Se conservan Riverpod,
GoRouter, arquitectura por capas, SDK y dependencias. Backend consultado solo
en modo lectura. No se agregan acciones de edición o eliminación porque la web
y el controlador revisado no las exponen.

## Reglas y contratos

| Campo o acción | Comportamiento |
| --- | --- |
| Paciente | Selección explícita; ID entero positivo; se comprueba por ID antes del POST |
| Tipo | MEDICATION, PROCEDURE, CONDITION_CHANGE, COMPLICATION, EMERGENCY, OBSERVATION |
| Severidad | LOW, MODERATE, HIGH, CRITICAL |
| Título | Obligatorio; 4–120 caracteres tras trim |
| Descripción | Obligatoria; 10–1000 caracteres tras trim |
| Autor y fecha | Los devuelve el servidor; no se envían como campos de creación |
| Permisos | Nurse, Doctor y Admin pueden consultar y registrar; desconocidos no reciben permisos |
| Concurrencia | Bloqueo de doble envío en interfaz y notifier; campos y cancelación bloqueados durante envío |
| Error de escritura | Se conserva formulario/listado, se libera saving y no se reintenta automáticamente |
| Registro confirmado | Actualiza listado ordenado e invalida historial del paciente |
| Recarga | Conserva datos ante fallos; muestra error y reintento; cargas antiguas no borran nuevos registros |
| Listado | Paciente, tipo, severidad, título, descripción, responsable y fecha |

Endpoints existentes:
- `GET /clinical-events`.
- `GET /clinical-events/patients/{patientId}`.
- `POST /clinical-events`.
- `GET /patients/{patientId}` para comprobar el paciente.
- `POST /audit-logs` para auditoría.
- `POST /alerts` para eventos HIGH/CRITICAL.

El backend admite mínimos de 3 caracteres en título y descripción; la app
aplica los mínimos de la web (4 y 10), compatibles con ese contrato.

## Alertas y efectos posteriores

Como la web, HIGH/CRITICAL generan alerta con tipo OTHER y la misma severidad.
Se mantiene el actor de alertas del módulo existente (`Equipo clínico`);
la auditoría del evento usa el usuario de la sesión.

`CreateAlertResource` limita la descripción a 255 caracteres. Se resume solo
la descripción de la alerta, conservando completos título y descripción del
evento. El contrato no acepta sourceType/sourceId; no se agregan esos campos.

Una falla de auditoría o alerta se comunica como aviso después del evento
confirmado. No provoca otro POST del evento ni un reintento automático de la
alerta. El historial se actualiza también en ese caso. El tester debe comprobar
esta integración contra el despliegue existente.

## Fuentes consultadas

Web, commit `60430f93b920f891cce0417f2ec5a67834a4c544`:
- [Formulario y validación](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/clinical-event/presentation/views/clinical-event-list/clinical-event-list.ts).
- [Listado web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/clinical-event/presentation/views/clinical-event-list/clinical-event-list.html).
- [Efectos del evento](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/clinical-event/application/clinical-event.store.ts).
- [Adaptación de alertas](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/notification/application/notification.store.ts).

Backend, commit `0fdae8277c629d967f49b925132419a76d52acfd`:
- [Controlador](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/clinicalevents/interfaces/rest/ClinicalEventsController.java).
- [Contrato de creación](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/clinicalevents/interfaces/rest/resources/CreateClinicalEventResource.java).
- [Permisos](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/iam/infrastructure/authorization/sfs/configuration/WebSecurityConfiguration.java).
- [Contrato de alertas](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/criticalevents/interfaces/rest/resources/CreateAlertResource.java).

## Verificación local

- Flutter 3.47.2 y Dart 3.13.2, previamente comprobados en esta sesión.
- `dart format lib test`: ejecutado; 88 archivos.
- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub test/clinical_event`: 68 pruebas nuevas aprobadas.
- `flutter test --no-pub`: 149 pruebas aprobadas en la suite completa.
- `git diff --check`: sin incidencias.
- `flutter build apk --release --no-pub
  --dart-define=API_BASE_URL=https://backend-nursepulse-qfct.onrender.com/api/v1`:
  compilación aprobada; APK en `build/app/outputs/flutter-apk/app-release.apk`
  (53.1 MB). No se ejecutó en emulador ni dispositivo.

Las pruebas usan datos ficticios y APIs simuladas: límites, vacíos/espacios,
tipos y severidades, permisos, paciente inexistente, cambio de sesión,
doble envío, HTTP 400/401/403/409, conexión, cargas antiguas, errores de efectos,
payload, integración del historial y conservación del formulario.

## Pendiente del tester

Con datos ficticios autorizados y cuentas de los tres roles:
- Registrar eventos en los límites de longitud; rechazar campos vacíos y fuera de rango.
- Confirmar responsable y fecha del servidor, orden y actualización del listado.
- Abrir el paciente y verificar el evento nuevo en su historial.
- LOW/MODERATE no crean alerta; HIGH/CRITICAL sí, con tipo OTHER.
- Descripción de evento de 1000 caracteres: guardado íntegro y alerta resumida.
- Verificar conservación de datos ante error y una escritura al pulsar varias veces.
- Registrar resultado, dispositivo y bloqueos de la API.

Eventos requiere revisión del tester y CI antes del merge. La siguiente fase
es SBAR y entrega de turno, desde `test` actualizado tras integrar Eventos.

## PR preparado hacia test

Título:

```text
feat(clinical-events): completar validaciones, permisos y alertas
```

Descripción:

```markdown
Completa Eventos clínicos con selección de paciente, tipos y severidades del
dominio, título de 4–120 y descripción de 10–1000 caracteres tras trim.
Aplica permisos Nurse/Doctor/Admin en interfaz y aplicación, bloquea doble
envío y conserva el formulario ante errores.

Actualiza listado e historial tras guardar, muestra responsable y fecha
devueltos por la API y genera alertas OTHER para HIGH/CRITICAL. Resume la
alerta a 255 caracteres sin recortar el evento original. Los fallos de
auditoría o alerta muestran aviso sin repetir la escritura confirmada.

Validación: formato, análisis y git diff --check aprobados; 149 pruebas
aprobadas, incluidas 68 nuevas con APIs simuladas. APK Android release compilado.
Pendiente: revisión del APK por el tester y checks de CI.

Sin cambios en backend, dependencias ni herramientas.
```
