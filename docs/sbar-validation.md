# Fase SBAR y entrega de turno

## Base y alcance

Revisión local: 2026-10-04.
Rama: `feature/sbar-validation`.
Base: `test` actualizado, `76236d6`, merge del PR #9 de Eventos.
Git estaba limpio al comenzar. Flutter 3.47.2 y Dart 3.13.2 disponibles.

Se conserva domain/application/infrastructure/presentation, Riverpod y GoRouter.
Backend consultado solo en modo lectura; SDK y dependencias sin modificaciones.
La fase completa el registro, listado, detalle y confirmación de recepción
expuestos por la web y la API existente.

## Reglas y permisos

| Campo o acción | Regla |
| --- | --- |
| Paciente | Selección explícita, ID positivo; comprobación por ID antes de crear |
| Personal receptor | Obligatorio; otro usuario ROLE_NURSE del catálogo GET /users |
| S, B, A, R | Obligatorios; 8–1000 caracteres cada uno después de trim |
| Título | Generado como SBAR - nombre del paciente; 1–255 según contrato |
| Crear | Nurse/Admin, en interfaz y lógica de aplicación |
| Confirmar recepción | Nurse/Admin y estado PENDING; se consulta estado actual antes del PATCH |
| Consultar | Nurse/Doctor/Admin; Doctor no ve acciones de escritura |
| Identidad | registeredBy e incomingNurseId devueltos por el servidor, derivados del JWT |
| Concurrencia | Una escritura a la vez; campos, cancelación y acciones bloqueados mientras guarda |
| Errores recuperables | Conserva texto, selecciones y listado; reintento explícito |
| Directorio | Carga/reintento independientes; solo GET /users, sin GET /roles ni GET /users/{id} |
| Listado | Fecha descendente, fechas desconocidas al final, error visible y recarga |
| Detalle | Consulta por ID; cuatro secciones, emisor, receptor, estado, fecha y notas |
| Recepción | Notas fijas como en web: Traspaso SBAR revisado y atendido. |

Los campos S/B/A/R también se validan al llamar directamente al notifier.
Antes del POST se comprueba de nuevo que el receptor exista y conserve el rol
Nurse, y que la sesión siga siendo la misma.

El backend admite receptores opcionales, pero la web exige seleccionarlos:
la app mantiene esa regla de la web. Los permisos de recepción se aplican como
en la web y el backend revisados: Nurse/Admin. No se introduce una restricción
nueva que limite la recepción exclusivamente al destinatario.

## Endpoints existentes

- `GET /patients` y `GET /patients/{id}`.
- `GET /users`.
- `GET /handovers/patients/{patientId}`.
- `GET /handovers/{id}`.
- `POST /handovers`.
- `PATCH /handovers/{id}/acknowledge`.
- `POST /audit-logs`.

No se usa `GET /handovers`: el controlador no expone un listado global.
Se agregan los traspasos de cada paciente, como en la web. Si falla una
consulta, se conserva el listado anterior y se comunica el error.

El POST envía solo patientId, targetNurseId, title, situation, background,
assessment y recommendation. El PATCH envía solo additionalNotes.

## Escrituras confirmadas y recuperación

El POST existente devuelve el ID creado; después se obtiene el detalle con
GET /handovers/{id}. Si falla esa lectura, la confirmación de creación se
conserva, el formulario se cierra con un aviso y no se realiza otro POST.
No se fabrica una entidad ni se inventan autor, estado o fecha del servidor.

Si una respuesta de escritura confirmada es ilegible, se comunica el problema
sin habilitar un reenvío automático. En recepción se conserva el ID confirmado
para bloquear otro PATCH del mismo traspaso en la sesión del notifier.
La recarga posterior consulta los datos del servidor.

La auditoría se intenta después de la confirmación usando el actor de la sesión.
Un fallo de auditoría muestra un aviso y no revierte la escritura. Al registrar
o recibir se actualiza el listado y se invalida el detalle del ID afectado.
Una carga antigua no borra una escritura que terminó después.

## Fuentes revisadas

Web, `60430f93b920f891cce0417f2ec5a67834a4c544`:
- [Formulario y reglas](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/sbar/presentation/views/sbar-list/sbar-list.ts).
- [Vista web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/sbar/presentation/views/sbar-list/sbar-list.html).
- [Registro y recepción](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/sbar/application/sbar.store.ts).

Backend, `0fdae8277c629d967f49b925132419a76d52acfd`:
- [Controlador](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/handover/interfaces/rest/HandoversController.java).
- [Creación](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/handover/interfaces/rest/resources/CreateHandoverResource.java).
- [Recepción](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/handover/interfaces/rest/resources/AcknowledgeHandoverResource.java).
- [Límites de persistencia](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/handover/infrastructure/persistence/jpa/entities/HandoverPersistenceEntity.java).
- [Permisos](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/iam/infrastructure/authorization/sfs/configuration/WebSecurityConfiguration.java).

## Verificación local

- `dart format lib test`: ejecutado, 96 archivos.
- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub test/sbar`: 98 pruebas nuevas aprobadas.
- `flutter test --no-pub`: 247 pruebas aprobadas en toda la suite.
- `git diff --check`: aprobado.
- `flutter build apk --release --no-pub
  --dart-define=API_BASE_URL=https://backend-nursepulse-qfct.onrender.com/api/v1`:
  compilación aprobada; APK `build/app/outputs/flutter-apk/app-release.apk`
  (53.1 MB).

Las pruebas usan exclusivamente datos ficticios y APIs simuladas. Cubren
vacíos/espacios, mínimos y máximos, IDs y receptor, permisos, paciente
desaparecido, cambio de sesión, doble envío, HTTP 400/401/403/409, conexión,
errores de lectura posterior y auditoría, estado actualizado antes del PATCH,
cargas antiguas, formularios, directorio y detalle actualizado.

## Pendiente del tester y CI

- Revisar APK en dispositivo con cuentas y pacientes ficticios autorizados.
- Crear con los cuatro campos en 8 y 1000 caracteres y rechazar 7/1001.
- Verificar que Doctor puede consultar y no puede crear ni recibir.
- Seleccionar otro Nurse y comprobar emisor, receptor y fecha reales.
- Confirmar recepción y comprobar estado, incomingNurseId y notas.
- Comprobar doble pulsación, errores de red y conservación del formulario.
- Verificar que un POST confirmado seguido de GET fallido no se repita.
- Registrar dispositivo, resultados y bloqueos antes del merge.
- Revisar los checks de CI del último commit al abrir el PR hacia test.

No se ejecutó el APK en emulador ni dispositivo, ni se hicieron escrituras
contra producción desde las herramientas. La siguiente fase es Alertas y
transiciones de estado, después de integrar SBAR en test.

## PR hacia test

Título:

```text
feat(sbar): completar validaciones y entrega de turno
```

Descripción:

```markdown
Completa SBAR con paciente y receptor Nurse distinto del usuario actual,
cuatro campos de 8–1000 caracteres tras trim y permisos Nurse/Admin
en interfaz y aplicación. Doctor conserva acceso de consulta.

Bloquea doble envío, conserva el formulario ante errores y actualiza
listado y detalle al registrar o confirmar recepción. Comprueba el estado
actual antes del PATCH y usa las identidades devueltas por el servidor.

Si el POST confirma la creación pero falla el GET posterior, conserva
la confirmación sin repetir el registro ni fabricar el detalle. Los fallos
posteriores de auditoría muestran aviso sin repetir la escritura.

Verificación: formato, análisis y git diff --check aprobados;
247 pruebas aprobadas, incluidas 98 nuevas con APIs simuladas.
APK Android release compilado.
Pendiente: revisión del APK por el tester y CI.

Sin cambios en backend, SDK ni dependencias.
```
