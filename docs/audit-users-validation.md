# Auditoría y administración de usuarios

Fecha: 2026-10-04. Rama: `feature/audit-user-management-validation`.
Base: `test` remoto `ee6ddd49e825612456e155420caeb84f2fa6fe53`.
Se confirmó el merge del PR #12 y que su commit de Dashboard `57532aa`
está incluido en esa base. Su check `Verify Flutter` terminó en success;
`Distribute Android` fue skipped. No se modificó el backend.

## Comportamiento y paridad

| Flujo | Regla y comportamiento | Evidencia automatizada |
| --- | --- | --- |
| Auditoría | Doctor/Admin; Nurse no consulta registros ni catálogo de pacientes | Reglas, aplicación, widgets y GoRouter |
| Listado general | Primera página de 100, orden descendente por fecha real; código AL-id, descripción, entidad y actor | Modelo, contrato, orden y pantalla |
| Paginación | Anterior/Siguiente con page, size, totalElements, totalPages y last reales; contador cargado separado del total | API, aplicación y widgets |
| Historial por paciente | Conserva el filtro móvil; ID entero positivo normalizado, orden ascendente; contexto patientId del envelope | Contrato timeline, aislamiento de pacientes, filtro y refresco |
| Datos inválidos de API | Rechaza IDs/fechas ausentes, páginas duplicadas y timeline ajeno; no fabrica fecha, actor ni total | Modelo y API simulada |
| Exportación PDF | GET real con filtro por paciente; documento de hasta 200 movimientos según OpenAPI | Endpoint, bytes PDF, filtro, errores y ausencia de POST extra |
| Guardado PDF | Selector nativo Android/iOS; éxito solo cuando se confirma guardado; cancelar conserva documento en memoria | Canal simulado y widgets; dispositivo pendiente |
| Reintento de guardado | Reutiliza bytes después de cancelar o fallar el destino; no repite GET exportador, que genera auditoría en servidor | Aplicación y widgets |
| Usuarios | Solo Admin; lista, contador y un rol Nurse/Doctor/Admin por cambio, como web | Reglas, API, aplicación, widgets y GoRouter |
| Cuenta propia | Protegida por ID y username; verificación fresca antes de PATCH | Reglas, aplicación y pantalla |
| Rol sin cambio | Aplicar deshabilitado; ninguna escritura si ya coincide, incluida lectura fresca | Aplicación y pantalla |
| Escritura de roles | Un PATCH por envío; selección y diálogo persisten ante errores recuperables | Contrato, errores HTTP, doble tap y bloqueo de salida |
| PATCH confirmado | Respuesta inválida se recupera solo con GET por ID; si no se verifica, aviso y bloqueo hasta refrescar lista | API, aplicación y pantalla |
| Actualización tras cambios | Invalida médicos de Pacientes, receptores SBAR y Dashboard | Integración con proveedores reales y Dio simulado |
| Accesibilidad | Listas y diálogo sin desbordamiento a 320 px con escala de texto 2 | Widgets |

Se conserva Riverpod, GoRouter y la arquitectura existente, sin nuevos paquetes
ni cambios de versiones. El registro de usuarios y su edad 18–90 permanecen
en la fase de autenticación; esa restricción no se aplica a Pacientes.
No se añaden creación/eliminación de usuarios ni filtros avanzados de auditoría.

## Contratos utilizados

Prefijo configurado: `/api/v1`.

| Método | Endpoint | Contrato y uso |
| --- | --- | --- |
| GET | `/audit-logs?page={page}&size=100` | `{content,page,size,totalElements,totalPages,last}`; size permitido 1–200 |
| GET | `/audit-logs/patients/{id}/timeline` | `{patientId,from,to,eventCount,events}`; eventos heredan patientId del contexto |
| GET | `/audit-logs/export/pdf` | Bytes application/pdf; patientId opcional, máximo 200 registros |
| GET | `/patients` | Catálogo para filtro por paciente, solo Doctor/Admin en esta pantalla |
| GET | `/users` | Lista de administración y directorios clínicos existentes |
| GET | `/users/{id}` | Verificación fresca y recuperación de respuesta confirmada |
| PATCH | `/users/{id}/roles` | `{ "roles": ["ROLE_NURSE" / "ROLE_DOCTOR" / "ROLE_ADMIN"] }`; respuesta UserResource |

El timeline anterior asumía una lista; se corrige al objeto real con `events`.
Se mantiene compatibilidad con listas antiguas; en la auditoría general una
lista no incluye total/paginación y no se inventan esos valores.
El Dashboard conserva su lectura de la primera página y su indicador de
registros cargados, sin convertirlo en un total global.

El OpenAPI desplegado confirma GET `/audit-logs/export/pdf`, su límite de 200
y la auditoría de exportación realizada por servidor. El código de backend
revisado en el commit indicado abajo no contiene ese controlador PDF: para
esa operación se usa el contrato desplegado y la referencia web, sin cambios
al servidor ni operaciones clínicas reales durante esta revisión.
No se añade POST de auditoría al cambio de roles ni a la exportación.

## Recuperación y permisos

- Permisos e IDs inválidos se rechazan antes de llamar a la API.
- Las lecturas simultáneas del mismo filtro comparten consulta; una respuesta
  anterior no reemplaza el filtro más reciente.
- Refresco/reintento conserva la última consulta válida con aviso. Un primer
  error no se presenta como lista vacía exitosa.
- Cambiar de paciente limpia registros del anterior, incluso ante error de la
  nueva consulta. No se atribuye información de un paciente a otro.
- El PDF exige cabecera y fin de documento; bytes inválidos no se guardan.
  Cambiar de filtro descarta el documento pendiente. Durante exportación no se
  puede cambiar el filtro ni lanzar otro envío.
- Cancelar el destino no significa éxito. Un nuevo intento de guardado usa el
  documento en memoria; reiniciar la aplicación o cambiar sesión lo descarta.
- Las respuestas de sesiones anteriores no publican datos; los proveedores se
  reconstruyen al cambiar usuario. No se guardan PDFs en preferencias.
- Los errores 422 de roles informan protección de cuenta propia; 404 exige
  actualizar listado. El estado confirmado sin detalle no repite PATCH.
- Android usa ACTION_CREATE_DOCUMENT sin permisos de almacenamiento amplios.
  iOS usa UIDocumentPicker y elimina el temporal tras confirmar/cancelar.

## Fuentes revisadas

Web: `60430f93b920f891cce0417f2ec5a67834a4c544`.
Backend, solo lectura: `0fdae8277c629d967f49b925132419a76d52acfd`.

- [Listado y exportación web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/audit/presentation/views/audit-log-list/audit-log-list.ts).
- [Contrato audit web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/audit/infrastructure/audit-api-endpoint.ts).
- [Administración de usuarios web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/iam/presentation/views/user-management/user-management.ts).
- [Roles y endpoints web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/iam/infrastructure/users-api-endpoint.ts).
- [Auditoría backend](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/auditlogs/interfaces/REST/AuditLogsController.java).
- [Usuarios backend](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/iam/interfaces/rest/UsersController.java).
- [Permisos backend](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/iam/infrastructure/authorization/sfs/configuration/WebSecurityConfiguration.java).
- [OpenAPI desplegado, consultado solo para contratos](https://backend-nursepulse-qfct.onrender.com/v3/api-docs).
- [Registro de canales con el motor implícito de Flutter/iOS](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate).

## Verificación local

Flutter 3.47.2; Dart 3.13.2. API simulada en todas las pruebas; datos ficticios.

- `dart format lib test`: aprobado.
- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub test/audit_users --reporter expanded`: **193 pruebas aprobadas**.
- `flutter test --no-pub --reporter expanded`: **680 pruebas aprobadas**, incluidas las 193 de esta fase y las regresiones anteriores.
- `git diff --check`: aprobado; sin errores de espacios.
- `flutter build apk --release --no-pub --dart-define=API_BASE_URL=https://backend-nursepulse-qfct.onrender.com/api/v1`: aprobado, **53.5 MB**.
- APK: `build/app/outputs/flutter-apk/app-release.apk` (generado, no incluido en Git).

Gradle emitió una advertencia de acceso nativo de Java; no hubo errores de
compilación. Se excluye del control de versiones la caché generada
`android/.kotlin/`; no se actualizaron herramientas ni dependencias.
El canal Android quedó compilado en el APK. El canal iOS se revisó en código
y con el contrato simulado en Dart, pero no se compiló en Windows.

## Revisión pendiente del tester

1. Android: entrar con Nurse/Doctor/Admin; verificar navegación y que accesos
   directos respeten permisos.
2. Auditoría: paginar con más de 100 registros de prueba; comprobar total,
   orden, catálogo, filtro, refresco y errores sin mezclar pacientes.
3. Exportar auditoría general y por paciente; abrir PDF, confirmar límite,
   cancelar selector, volver a guardar y comprobar que no se repita exportación.
4. Simular destino sin acceso o sin espacio, reintentar y confirmar que no se
   muestre éxito falso. Revisar cancelación con botón Atrás y rotación Android.
5. Admin: cambiar rol de cuenta ficticia, confirmar recepción en lista; comprobar
   médicos de Pacientes y receptores SBAR después del cambio.
6. Verificar cuenta propia bloqueada y selección conservada ante fallo de red,
   404, 422 o 503. Después de respuesta confirmada incompleta, refrescar sin
   repetir escritura.
7. CI del nuevo PR y pruebas contra API real pendientes. iOS requiere compilar
   en macOS y probar el selector en dispositivo; Windows no acredita ese build.

La próxima fase es Reportes y suscripciones, según soporte de la API existente,
después del merge de esta rama en `test`.

## PR hacia test

Título: `feat: completar auditoría y administración de usuarios`

```markdown
Completa la paridad de Auditoría y administración de usuarios con la web, usando los contratos existentes y sin modificar el backend.

- Auditoría para Doctor/Admin: paginación real, descripción de movimientos, historial por paciente y exportación PDF con selector nativo.
- Usuarios para Admin: un rol Nurse/Doctor/Admin por cambio, protección de cuenta propia, validaciones y bloqueo de doble envío.
- Conserva filtros y selecciones ante errores; recupera cambios confirmados con lecturas sin repetir PATCH ni exportaciones al reintentar el destino del PDF.
- Actualiza médicos de Pacientes, receptores SBAR y Dashboard después de cambios de rol.

Verificación: dart format, flutter analyze sin incidencias, 680 pruebas aprobadas (193 nuevas), git diff --check y APK Android release compilado.

Pendiente: revisión del APK y API real por el tester, checks del PR y compilación/pruebas iOS en macOS. Detalles y casos manuales en docs/audit-users-validation.md.
```
