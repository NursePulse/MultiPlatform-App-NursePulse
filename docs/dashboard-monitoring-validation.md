# Dashboard y monitoreo

Estado actualizado, 2026-10-04: Dashboard está integrado en `test` desde el
PR #12. Reportes quedó integrado por PR #14 y ya usa almacenamiento local.
La fecha de actualización y el aislamiento de sesiones se revisan en
[Integración final](final-integration-validation.md). El contador móvil
conserva el perfil autenticado, con la diferencia visual documentada allí.
Las secciones siguientes registran la implementación y resultados históricos.

Fecha: 2026-10-04. Rama: `feature/dashboard-monitoring-validation`.
Base: `test` remoto `e22c79c`, después del merge de Alertas (PR #11).
Se comprobó que el commit de Alertas `bc77e29` está incluido en esa base.
Su check `Verify Flutter` terminó en success; `Distribute Android` fue skipped.

## Comportamiento y paridad

El Dashboard consulta directamente los recursos existentes. Se elimina la
consulta especulativa a `/dashboard/summary`, que no tiene controlador en
el backend revisado. No se inventan respuestas ni se modifica el backend.

| Campo o flujo | Regla aplicada | Evidencia automatizada |
| --- | --- | --- |
| Acceso clínico | Nurse, Doctor y Admin; sesión real, sin cambiar permisos por modo visual | Reglas, notifier, API y widgets |
| Pacientes monitoreados | Todos salvo DISCHARGED | Estados, lista vacía, alta y eliminación |
| Pacientes prioritarios | Estado CRITICAL; indicador de Nurse/Doctor | Reglas y widgets por rol |
| Alertas activas | OPEN y ATTENDED; CLOSED queda fuera | KPIs y atención/cierre confirmados |
| Alertas críticas/moderadas | Activas CRITICAL / activas de cualquier otra severidad, igual que la web | Todas las severidades y estados |
| Eventos de hoy / controles del mes | Fecha local; mes y año deben coincidir | Límites de días/meses/años y conversión UTC |
| Módulos del perfil | Catálogo web: Admin 8, Doctor 5, Nurse 6 | Roles y sesiones con varios roles |
| Movimientos de auditoría | Número de registros cargados, solo indicador Admin | Página con content y totalElements diferente |
| Paneles recientes | Primeros cinco pacientes del orden recibido; cinco alertas activas por fecha real; cinco auditorías cargadas por fecha | Límites de paneles, navegación por ID |
| Accesos rápidos | Acciones del perfil web; Nurse conserva registro de signos y SBAR | Widgets y navegación GoRouter |
| Monitoreo por ID | Entero positivo, normalizado; nunca catálogo global para resolver la ficha | IDs inválidos y sin permiso: cero llamadas |
| Aislamiento del historial | Rechaza detalle, signos, eventos o alertas de otro patientId | Contratos simulados con IDs cruzados |
| Periodo de signos/eventos | Ambas fechas, inclusivas, desde 01/01/1930 hasta hoy, fin no anterior al inicio | Reglas, límites y selector de fechas |
| Alertas y último riesgo | Alertas sin filtro temporal; riesgo del último signo de todo el historial | Widget con periodo de un día |
| Fechas de alertas | triggeredAt, attendedAt y closedAt reales; si falta generación se indica sin información | Ordenación y widgets con fecha ausente |
| Permiso de signos | Nurse/Admin ven Registrar; Doctor ve Ver signos vitales; lógica existente protege escritura | Widgets por rol y suite de Signos vitales |

El catálogo de módulos no representa disponibilidad de APIs. La auditoría
usa la consulta existente `page=0&size=100`: el indicador cuenta esa página,
no el total global. El panel ordena los registros cargados; no acredita que
se haya consultado toda la auditoría. La paginación completa corresponde
a la fase de Auditoría y administración de usuarios.

Se conserva la ficha, el diagnóstico, los eventos y los filtros ya presentes
en Flutter. La regla de edad 18–90 del registro de usuarios no se aplica
a pacientes; las pruebas de pantalla incluyen un paciente menor de edad.

## Contratos utilizados

Prefijo configurado: `/api/v1`.

| Método | Endpoint | Uso en esta fase |
| --- | --- | --- |
| GET | `/patients` | Dashboard |
| GET | `/alerts` | Dashboard |
| GET | `/clinical-events` | Dashboard |
| GET | `/vital-sign-records` | Dashboard |
| GET | `/audit-logs?page=0&size=100` | Dashboard Doctor/Admin; Nurse nunca consulta auditoría |
| GET | `/patients/{id}` | Ficha por ID |
| GET | `/vital-sign-records/patients/{id}` | Historial de signos |
| GET | `/clinical-events/patients/{id}` | Historial de eventos |
| GET | `/alerts/patients/{id}` | Historial de alertas |

Las escrituras de Pacientes, Signos vitales, Eventos, Alertas y SBAR conservan
sus contratos. Después de confirmar una escritura se invalida el Dashboard;
los cambios de paciente invalidan también ficha e historial, y los registros
clínicos y transiciones de alertas invalidan el historial correspondiente.
Los fallos posteriores de auditoría no repiten la escritura confirmada.

Reportes ahora aparece en el menú y admite la ruta para Doctor/Admin, según
la web. Este ajuste de acceso no implementa la fase Reportes ni acredita
su API: no se encontró controlador `/reports` en el backend revisado.
La prueba de la ruta simula 404 para los roles autorizados y verifica que
Nurse ni siquiera consulta ese recurso. El soporte de Reportes sigue pendiente
de la fase correspondiente, sin cambios en backend.

## Recuperación de errores

- Las recargas simultáneas del Dashboard comparten una consulta pendiente.
- Un fallo clínico conserva la última consulta completada con aviso y reintento. El primer fallo no muestra ceros ficticios.
- Un fallo de auditoría conserva los indicadores clínicos y muestra valor desconocido y reintento para Admin.
- La hora de última consulta indica cuándo terminó la lectura; no sustituye fechas clínicas.
- Un cambio de sesión restablece el Dashboard; las respuestas de notifiers descartados no publican datos.
- El monitoreo inicial espera una ficha válida antes de consultar el historial. Si un refresco de la ficha devuelve 404, oculta el historial y no lo vuelve a consultar.
- El reintento del historial consulta solo sus recursos, conservando la ficha; el filtro persiste al refrescar y se reinicia al cambiar de paciente.
- Refresco y reintento de estas pantallas solo realizan lecturas; no vuelven a ejecutar POST/PUT/PATCH.

## Fuentes revisadas

Web: `60430f93b920f891cce0417f2ec5a67834a4c544`.
Backend, solo lectura: `0fdae8277c629d967f49b925132419a76d52acfd`.

- [Dashboard web: indicadores y límites](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/dashboard/presentation/views/dashboard-view/dashboard-view.ts).
- [Paneles web por perfil](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/dashboard/presentation/views/dashboard-view/dashboard-view.html).
- [Monitoreo web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/patient/presentation/views/patient-monitoring/patient-monitoring.html).
- [Permisos de rutas web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/app.routes.ts).
- [Permisos backend](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/iam/infrastructure/authorization/sfs/configuration/WebSecurityConfiguration.java).
- [Consulta de signos por paciente](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/vitalsigns/interfaces/rest/VitalSignRecordsController.java).
- [Contrato paginado de auditoría](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/auditlogs/interfaces/REST/AuditLogsController.java).

## Verificación local

Entorno comprobado: Flutter 3.47.2 y Dart 3.13.2, sin actualizaciones.
Las pruebas utilizan APIs simuladas, usuarios y registros ficticios.

| Comprobación | Resultado |
| --- | --- |
| `dart format lib test` | Aprobado: 116 archivos, ejecución final sin cambios |
| `flutter analyze --no-pub` | Aprobado: sin incidencias |
| `flutter test --no-pub` | Aprobado: 487 casos, incluidos 107 nuevos de Dashboard/monitoreo |
| Pruebas de monitoreo tras ajustes de estilo | Aprobado: 10 casos |
| `git diff --check` | Aprobado: sin errores de espacios |
| APK release con API configurada | Aprobado: 53,4 MB; exit code 0 |

APK: `build/app/outputs/flutter-apk/app-release.apk`.
El comando utilizado es:

```powershell
flutter build apk --release --no-pub --dart-define=API_BASE_URL=https://backend-nursepulse-qfct.onrender.com/api/v1
```

No se modificaron backend, SDK ni dependencias. No se realizaron escrituras
contra producción ni pruebas en emulador o dispositivo.
Gradle emitió una advertencia de acceso nativo de Java; la compilación terminó
correctamente. No se actualizaron herramientas por esa advertencia.

## Revisión pendiente del tester

1. Entrar como Nurse, Doctor y Admin: contrastar indicadores, módulos y accesos con el mismo conjunto de datos en la web.
2. Abrir seguimiento desde un paciente del Dashboard; comprobar ficha por ID, menor de edad, diagnóstico, riesgo y fechas de alertas.
3. Filtrar un solo día y un intervalo: incluir ambos límites en signos/eventos; mantener alertas y último riesgo sin ese filtro.
4. Registrar signos, evento y SBAR; crear/atender/cerrar alerta; editar/dar alta/eliminar paciente con los permisos correspondientes. Volver al Dashboard y comprobar actualización sin repetir escrituras.
5. Probar desconexión, consulta de auditoría rechazada y paciente eliminado mientras se visualiza; revisar mensajes y reintentos.
6. Revisar móvil pequeño y tamaño de texto ampliado, navegación y refresco con listas vacías.

La compilación y las pruebas simuladas no acreditan integración con la API
desplegada. El tester comprueba el APK; CI del PR debe corresponder al último
commit publicado. La siguiente fase es Auditoría y administración de usuarios,
después del merge autorizado en `test`.

## PR hacia test

**Título:** `feat(dashboard): completar Dashboard y monitoreo de pacientes`

```markdown
## Cambio y comportamiento

Completa el Dashboard por perfil con indicadores, pacientes y alertas recientes,
auditoría para Admin y accesos rápidos. Consulta recursos existentes directamente
y elimina la petición a /dashboard/summary sin controlador.

El seguimiento valida ID y permisos antes de consultar, rechaza respuestas de
otro paciente, conserva filtros inclusivos y muestra fechas reales de alertas.
Las escrituras confirmadas refrescan Dashboard, ficha e historial según el módulo.

## Paridad y validaciones

| Flujo | Regla / permiso | Referencia | Prueba |
| --- | --- | --- | --- |
| Dashboard | Nurse/Doctor/Admin; auditoría solo Doctor/Admin | Dashboard web y seguridad backend | Reglas, API, notifier y widgets |
| KPIs | Altas excluidas; alertas OPEN/ATTENDED; fechas locales | Dashboard web y recursos clínicos | Estados, fechas y límites |
| Monitoreo | ID positivo y datos del paciente solicitado | APIs por paciente | Entradas inválidas: cero llamadas; IDs cruzados rechazados |
| Periodo | Inclusivo; 1930–hoy; fin >= inicio | Filtro móvil existente | Reglas y selector de fechas |
| Recargas | Última consulta conservada y reintento; sin repetir escrituras | Contratos existentes | Errores HTTP y escrituras confirmadas con auditoría fallida |
| Reportes | Menú/ruta Doctor y Admin; Nurse bloqueado | Rutas web | Navegación con API simulando 404 |

Auditoría cuenta la página cargada, no el total global. Módulos del perfil es el
catálogo web, no una comprobación de disponibilidad. No se implementa soporte
de Reportes ni se cambia el backend. Detalles en docs/dashboard-monitoring-validation.md.

## Verificación

- [x] dart format lib test: 116 archivos; ejecución final sin cambios.
- [x] flutter analyze --no-pub: sin incidencias.
- [x] flutter test --no-pub: 487 aprobadas, incluidas 107 nuevas.
- [x] Permisos, IDs inválidos, límites, errores y recuperación comprobados con APIs simuladas.
- [x] git diff --check: aprobado.
- [x] APK release compilado con la API configurada: 53,4 MB.
- [ ] Revisión del APK y de la API desplegada por el tester.
- [ ] CI del PR sobre el último commit.

## Evidencia y pendientes

Datos y usuarios ficticios; pruebas sin emulador ni escrituras en producción.
Backend, SDK y dependencias sin cambios. Pendientes: CI y pruebas manuales;
soporte de Reportes se revisará en su fase. Después del merge en test sigue
Auditoría y administración de usuarios.
```
