# Integración final y revisión del APK

Fecha: 2026-10-04. Rama: `feature/final-integration-validation`.
Base: `test` remoto `9dfbb49cf64e0806d4812f737f477a31c8e0bde0`.

Se confirmó el merge del PR #14 de Reportes y suscripciones con Git y GitHub.
El commit `af3fb62` está incluido en esa base. `Verify Flutter` terminó en
success sobre ese commit; `Distribute Android` fue skipped. Git estaba limpio
al comenzar. Flutter 3.47.2 y Dart 3.13.2 siguen instalados, sin actualizaciones.

## Correcciones y decisiones

El Dashboard muestra **Última actualización** con el mismo orden de prioridad
que la web: fecha del primer movimiento de auditoría cargado, después fecha
de la primera alerta cargada y, si ninguna existe, hora de la consulta.
Las colecciones están ordenadas por fecha descendente. Una auditoría tiene
prioridad incluso si una alerta es más nueva; las alertas cerradas también
pueden aportar fecha. No se usa el último signo o evento para ese campo.
La fecha de actualización anterior permanece cuando falla un refresco.

Se conserva **Módulos del perfil** con el rol autenticado: Admin 8, Doctor 5,
Nurse 6. La web utiliza su modo visual de demostración. La adaptación móvil
ya establecida evita presentar un perfil distinto al de la sesión; los números
coinciden con el catálogo web del perfil real. Un modo visual distinto no
cambia menús, permisos, acceso a Reportes/Auditoría/Usuarios ni operaciones.
No se añade un selector de rol ni un flujo nuevo en esta fase.

Se corrigió el aislamiento de Pacientes, Signos vitales, Eventos, SBAR y
Alertas: sus notifiers se reconstruyen cuando cambia el usuario, incluso
entre cuentas con el mismo rol. Se vacían listados y avisos en memoria;
las respuestas tardías de una instancia descartada no repueblan la nueva.
Detalle, historial y catálogos por sesión también observan la identidad.
SBAR no inicia consultas por paciente después de perder la sesión durante
su primera lectura. Signos y Pacientes comprueban permisos antes de leer;
Signos valida y normaliza el ID al consultar por paciente.

Se mantienen las reglas y los contratos de las fases anteriores. Reportes
y plan de suscripción conservan su persistencia local según la web; cerrar
sesión no borra esos documentos del dispositivo. Nurse sigue sin leer Reportes;
el plan de suscripción no concede permisos clínicos.
El formulario de prueba de Signos ahora inyecta también los permisos de su
sesión ficticia; las validaciones y los casos existentes permanecen activos.

## Evidencia de integración automatizada

Todas las APIs, sesiones y almacenamiento utilizados son simulados. Las pruebas
no se conectan a producción y solo usan datos ficticios.

| Flujo | Comprobación |
| --- | --- |
| Navegación con GoRouter real | Diez rutas por Nurse/Doctor/Admin, con pantalla de 320 px y texto al 100/200 %, menú, restricciones y cierre de sesión |
| Permisos | Nurse no accede a Reportes/Auditoría/Usuarios ni lee reportes locales; Doctor no accede a Usuarios; modo visual no concede permisos |
| Sesiones | Cinco listados se vacían al salir o cambiar a otra cuenta con el mismo rol; cinco respuestas tardías se descartan |
| Escrituras en validación | Cambiar sesión mientras se consulta el paciente impide POST de Signos/Eventos |
| Seguimiento | Cambio de cuenta con la misma lista de roles vuelve a consultar detalle e historial, sin reutilizar el resultado anterior |
| Lecturas sin sesión | Pacientes, Signos y Dashboard no llaman a sus APIs |
| Flujo completo | Crear paciente, registrar signos de riesgo y evento crítico, generar dos alertas automáticas, registrar SBAR, atender/cerrar alerta, consolidar reporte y dar alta |
| Auditoría fallida | El mismo flujo conserva escrituras clínicas, alertas y reporte; el conteo de Eventos desde auditoría queda en cero según la regla web |
| Refrescos | Dashboard, historial y Reportes reflejan cambios; recargar no repite POST/PATCH ni las auditorías del reporte |
| Reporte consolidado | Cuenta pacientes, signos, eventos desde auditoría, SBAR y alertas del periodo; persiste el resumen anterior aunque luego se dé de alta al paciente |
| Fecha Dashboard | Prioridad auditoría/alerta/reloj, alerta cerrada, auditoría ausente/vacía, fecha real visible y signos/eventos sin influencia |

Archivos nuevos: `test/integration/session_isolation_test.dart`,
`test/integration/navigation_test.dart` y
`test/integration/clinical_report_flow_test.dart`. También se amplían las
pruebas de reglas y pantalla de Dashboard. Las pruebas anteriores siguen
cubriendo formatos, límites, entradas inválidas sin API, duplicados, permisos,
doble envío, fallos HTTP, confirmaciones y recuperación por módulo.

## Estado de los módulos

| Módulo | Estado del código y evidencia |
| --- | --- |
| Registro/acceso | Integrado; edad entera 18–90 inclusive, roles reales y sesiones. [Reglas](auth-validation-checks.md) |
| Pacientes | Integrado; validaciones, duplicados, médico, permisos, ficha por ID e historial. No aplica la edad 18–90. [Reglas](patient-validation.md) |
| Signos vitales | Integrado; suite existente y flujo completo con alerta automática; lectura protegida y estado por sesión |
| Eventos clínicos | Integrado; validaciones, auditoría y alertas automáticas. [Reglas](clinical-events-validation.md) |
| SBAR | Integrado; contratos por paciente, receptor y recepción, sin GET global inexistente. [Reglas](sbar-validation.md) |
| Alertas | Integrado; estados reales, permisos, atención y cierre. [Reglas](alerts-validation.md) |
| Dashboard/monitoreo | Integrado; fecha corregida y diferencia visual documentada. [Historial](dashboard-monitoring-validation.md) |
| Auditoría/usuarios | Integrado; paginación, PDF y administración según rol. [Reglas](audit-users-validation.md) |
| Reportes/suscripciones | Integrado por PR #14; reportes locales y checkout simulado. [Reglas](reports-subscriptions-validation.md) |

Este estado acredita implementación y pruebas simuladas; la aceptación del APK
en dispositivo y de los flujos contra la API desplegada depende del tester.

## Contratos y límites conservados

Se leyó el OpenAPI desplegado, sin modificar el backend ni consultar datos
clínicos de producción. Están disponibles los recursos de autenticación,
pacientes, signos, eventos, traspasos, alertas, auditoría y usuarios utilizados
por Flutter. No existen `/dashboard/summary`, `/reports`, `/payments` ni
`/subscriptions`; la consolidación usa recursos existentes y la persistencia
local implementada. El checkout sigue siendo una demostración sin cobros.

Dashboard y Reportes consultan auditoría `page=0&size=100`; sus contadores
representan los registros cargados. Reportes cuenta movimientos CLINICAL_EVENT,
no eventos únicos. La pantalla Auditoría dispone de paginación independiente.
Estas diferencias de significado están documentadas y no se cambian en esta fase.

La recuperación de contraseña mencionada en el inventario inicial no forma
parte de las siete fases clínicas acordadas y no se añade con endpoints
inventados. El contrato desplegado incluye `verify-email`, pero no una API de
restablecimiento de contraseña que permita completar ese flujo de la web:
`forgot-password`, `verify-code` y `resend-code` no están en el OpenAPI.
Implementarlo requeriría definir el soporte del backend con el propietario.

## Fuentes primarias contrastadas

La rama main de la web sigue en `60430f93b920f891cce0417f2ec5a67834a4c544`.
Se volvieron a leer Dashboard, sus rutas, NotificationStore, AuditStore y
ViewModeStore antes de resolver las dos diferencias pendientes.

- [Dashboard web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/dashboard/presentation/views/dashboard-view/dashboard-view.ts).
- [Rutas y permisos web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/app.routes.ts).
- [Ordenación de alertas](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/notification/application/notification.store.ts).
- [Ordenación de auditoría](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/audit/application/audit.store.ts).
- [Modo visual web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/shared/application/view-mode.store.ts).
- [Contratos web de recuperación](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/iam/infrastructure/authentication-api-endpoint.ts).
- [OpenAPI desplegado](https://backend-nursepulse-qfct.onrender.com/v3/api-docs).

## Verificación de esta rama

- Formato: `dart format lib test`, 143 archivos; ejecución final aprobada.
- Análisis: `flutter analyze --no-pub`, aprobado sin incidencias.
- Suite completa: `flutter test --no-pub --reporter expanded`, **857 pruebas aprobadas**, incluidas **26 nuevas** de integración y Dashboard. Conserva las 831 pruebas de la base anterior.
- APK release: `flutter build apk --release --no-pub --dart-define=API_BASE_URL=https://backend-nursepulse-qfct.onrender.com/api/v1`, aprobado, **53.7 MB** (56 265 278 bytes). Gradle emitió una advertencia de acceso nativo de Java, sin errores de compilación.
- `git diff --check`: aprobado, sin errores de espacios.
- Backend, SDK, dependencias y configuración nativa: sin cambios.

Archivo: `build/app/outputs/flutter-apk/app-release.apk`.
SHA-256 del APK local de esta validación:
`B21D80461A24AC12A654FACB0644DDA148CE9AD3DD49D21E9A294CC156D8FA08`.
El APK generado por CI puede tener otro hash; registrar el artefacto realmente probado.

## Aceptación del tester y orden de entrega

Usar cuentas y pacientes ficticios en un entorno autorizado; registrar el commit
y el APK probados, rol, resultado y problema encontrado. No adjuntar datos reales
ni credenciales. Las pruebas manuales permanecen pendientes hasta recibir evidencia.

1. Instalar el APK actualizado sobre la versión anterior sin borrar datos.
   Entrar con cada rol, reiniciar, salir y cambiar de cuenta; comprobar menús,
   rutas restringidas y ausencia de datos de la cuenta anterior en pantalla.
2. Validar registro 18/90 y rechazo 17/91/decimales; crear y consultar un
   paciente menor de edad sin aplicar ese límite al paciente.
3. Ejecutar el flujo clínico con datos ficticios: paciente → signos/evento →
   alertas automáticas → SBAR/recepción → atención/cierre → Dashboard/historial.
   Confirmar una sola escritura por acción y actualización al volver.
4. Probar errores y desconexión antes de guardar; conservar formulario y permitir
   reintento. Tras una escritura confirmada y fallo de auditoría/lectura posterior,
   revisar el aviso y reintentar lectura sin repetir la escritura.
5. Generar un reporte Hasta hoy con registros al inicio y final del día; revisar
   alertas, conteo desde auditoría y persistencia después de cerrar completamente.
   Confirmar las dos acciones AUDIT_LOG y conservación ante fallo de auditoría.
6. Validar la demo de suscripciones, DNI/RUC, mes vigente, doble toque y recibo;
   reabrir con el plan guardado. No debe haber cobros ni cambios de permisos.
7. Médico/Admin: auditoría paginada, filtros, historial y PDF; Admin: cambios de
   roles y actualización del médico tratante/receptor SBAR; otros roles bloqueados.
8. Comprobar teclado, orientación, navegación atrás y texto ampliado en dispositivo.
   Las pruebas de 320 px no sustituyen esta revisión del APK.
9. Revisar CI del PR sobre el último commit. iOS requiere compilación y pruebas
   en macOS; no se acredita desde Windows. Distribución Firebase/publicación
   y paso a main requieren la revisión y autorización acordadas.

La mejora visual solicitada comienza **después de validar estos flujos** y en
una rama separada desde `test` actualizado. Se conservan las reglas, permisos
y contratos aprobados. Esta fase no rediseña pantallas ni inicia el trabajo visual.

## PR hacia test

Título: `fix: cerrar integración móvil y aislar datos por sesión`

```markdown
## Cambio y comportamiento

Corrige el estado clínico que podía conservarse después de salir o cambiar de cuenta: Pacientes, Signos, Eventos, SBAR y Alertas se reconstruyen por identidad, y las respuestas tardías no repueblan otra sesión.

Dashboard muestra la fecha de auditoría/alerta con la prioridad de la web. El contador de módulos conserva el rol autenticado; su diferencia con el modo visual web queda documentada.

## Paridad y validaciones

| Flujo | Regla | Evidencia |
| --- | --- | --- |
| Sesión | Listas y seguimiento por identidad; lecturas protegidas | Cambios de cuenta con el mismo rol, logout y respuestas tardías |
| Dashboard | Auditoría → alerta → reloj, como web | Reglas y fecha real visible |
| Navegación | Permisos reales, independientes del modo visual | GoRouter con tres roles, 320 px y texto al 100/200 % |
| Integración clínica | Escritura confirmada no se repite al refrescar | Paciente → signos/evento → alertas/SBAR → reporte, también con auditoría fallida |

## Verificación

- [x] Formato, flutter analyze sin incidencias y git diff --check.
- [x] 857 pruebas aprobadas, incluidas 26 nuevas; APIs y almacenamiento simulados.
- [x] Permisos y navegación entre módulos comprobados.
- [x] APK release compilado con API configurada: 53.7 MB; ruta y SHA-256 en la guía final.
- [ ] Prueba manual del APK y API desplegada por el tester.
- [ ] CI del PR sobre el último commit e iOS en macOS.

## Evidencia y pendientes

Backend, SDK y dependencias sin cambios. Reportes locales y suscripciones simuladas conservan su alcance. La guía final documenta contratos, límites y aceptación manual. La mejora visual se realizará después de validar los flujos funcionales.
```
