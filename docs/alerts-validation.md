# Alertas y transiciones de estado

Fecha: 2026-10-04. Rama: `feature/alerts-validation`.
Base: `test` remoto `5642011`, después del merge de SBAR (PR #10).
El check `Verify Flutter` del commit SBAR `67a4e1a` terminó en success;
`Distribute Android` fue skipped.

## Reglas y permisos

| Operación / campo | Regla aplicada en Flutter |
| --- | --- |
| Consulta, creación y atención | Nurse, Doctor o Admin |
| Cierre | Doctor o Admin |
| Paciente | Selección explícita, ID entero positivo y consulta de disponibilidad antes del POST |
| Tipo | CARDIAC, RESPIRATORY, NEUROLOGICAL, FALL, MEDICATION u OTHER |
| Severidad | LOW, MEDIUM, HIGH o CRITICAL |
| Descripción | Obligatoria, 1–255 caracteres después de trim; no truncar entradas inválidas |
| Actor de atención / cierre | Username de la sesión, trim y 1–120 caracteres; no recibido desde el formulario |
| Actor de creación | `Equipo clínico`, como en la web |
| Notas de cierre | `Alerta cerrada desde seguimiento clínico.`, como en la web; aplicación valida 1–255 tras trim |
| Atender | Solo OPEN → ATTENDED |
| Cerrar | Solo ATTENDED → CLOSED, conforme al flujo visible de la web |

El backend permite también cerrar OPEN. La app sigue la secuencia de la
web y comprueba el estado actual por ID antes del PATCH. No se modifica
el backend ni se añade una transición a la interfaz.

Los filtros Todas, Críticas y Moderadas muestran únicamente alertas
no cerradas. Moderadas incluye LOW, MEDIUM y HIGH, como la web.
Los nombres de pacientes se actualizan al cargar el catálogo.

## Contratos existentes

| Método | Ruta (relativa a `/api/v1`) | Uso |
| --- | --- | --- |
| GET | `/alerts` | Listado |
| GET | `/alerts/patients/{patientId}` | Historial del paciente |
| GET | `/alerts/{id}` | Detalle y comprobación de estado |
| POST | `/alerts` | patientId, type, severity, description, triggeredBy |
| PATCH | `/alerts/{id}/attend` | attendedBy |
| PATCH | `/alerts/{id}/close` | closedBy, resolutionNotes |
| GET | `/patients/{id}` | Disponibilidad del paciente antes de crear |
| POST | `/audit-logs` | Auditoría posterior a escritura confirmada |

POST/PATCH devuelven `AlertResource`. El estado, las identidades y las
fechas mostrados proceden de ese recurso; no se fabrican respuestas.
El backend actual expone `triggeredAt` y lo obtiene de `createdAt`
persistido. Si falta o es ilegible se muestra sin información, sin usar
la hora actual ni la fecha de atención/cierre como fecha de creación.
Los estados y severidades desconocidos se rechazan en vez de convertirlos
silenciosamente en OPEN o LOW. Se mantienen los alias de compatibilidad existentes.

La creación usa `ALERT_TRIGGERED`, la atención `ALERT_ACKNOWLEDGED`
y el cierre `UPDATE` en auditoría. Se corrige el `ALERT_CREATED` anterior,
que no existe en el enum backend. El actor de auditoría es la sesión real.

## Errores y actualización

- Validación y permisos antes de llamar a APIs; sesión comprobada nuevamente antes de escribir.
- Guardado y transiciones bloqueados mientras hay una escritura pendiente.
- Formulario conserva descripción y selecciones ante rechazo recuperable; campos, cancelar y salida bloqueados durante envío.
- Error de listado conserva los datos existentes; reintento y refresco disponibles incluso con lista vacía.
- POST/PATCH 2xx con cuerpo ilegible se recupera mediante GET por ID, cuando existe. No se repite la escritura ni se inventa el detalle.
- Si no se puede recuperar el cuerpo confirmado, se muestra aviso. Las transiciones confirmadas se recuerdan durante la vida del notifier para bloquear su repetición.
- Una auditoría fallida muestra aviso y no convierte la escritura clínica confirmada en un fallo de registro.
- Creación y transiciones actualizan el listado, invalidan detalle e historial del paciente cuando hay un ID confirmado.
- Las alertas automáticas de Signos vitales y Eventos clínicos conservan la escritura original y propagan avisos de Alertas sin repetirla.
- Se corrige únicamente el comentario obsoleto sobre fechas en Reportes; su conteo actual se conserva para su propia fase.

## Referencias revisadas

Fuentes de solo lectura, fijadas al commit revisado:

- [Formulario y permisos web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/notification/presentation/views/alert-list/alert-list.ts).
- [Filtros y acciones web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/notification/application/notification.store.ts).
- [Rutas y notas de cierre web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/notification/infrastructure/notification-api-endpoint.ts).
- [Controlador API](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/criticalevents/interfaces/rest/AlertsController.java).
- [Validaciones del POST](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/criticalevents/interfaces/rest/resources/CreateAlertResource.java).
- [Permisos backend](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/iam/infrastructure/authorization/sfs/configuration/WebSecurityConfiguration.java).
- [Origen de fecha persistida](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/criticalevents/infrastructure/persistence/jpa/assemblers/AlertPersistenceAssembler.java).
- [Acciones válidas de auditoría](https://github.com/NursePulse/Backend-NursePulse/blob/0fdae8277c629d967f49b925132419a76d52acfd/src/main/java/com/brainspark/nursepulse/platform/auditlogs/domain/model/valueobjects/AuditActionType.java).

## Verificación

Entorno comprobado: Flutter 3.47.2 y Dart 3.13.2, sin actualizaciones.
Todas las pruebas usan APIs simuladas, usuarios y datos ficticios.

| Comprobación | Resultado final |
| --- | --- |
| `dart format lib test` | Ejecutado; 104 archivos |
| `flutter analyze --no-pub` | Aprobado: sin incidencias |
| `flutter test --no-pub` | Aprobado: 380 casos, incluidos 133 nuevos de Alertas |
| `git diff --check` | Aprobado: sin errores de espacios |
| `flutter build apk --release --no-pub --dart-define=API_BASE_URL=https://backend-nursepulse-qfct.onrender.com/api/v1` | Aprobado: APK release de 53,3 MB |

APK: `build/app/outputs/flutter-apk/app-release.apk`.
Sin cambios en backend, SDK o dependencias. No se hicieron escrituras
en producción ni pruebas en dispositivo/emulador.

## Revisión pendiente del tester

1. Nurse: crear alerta con paciente explícito; probar vacíos, espacios, 255 y 256 caracteres; atender y comprobar que espera cierre médico.
2. Doctor/Admin: comprobar atención y cierre de una atendida; una activa no ofrece cierre directo y una cerrada no aparece en filtros activos.
3. Revisar filtros, contador, nombres, estado y fechas en listado/detalle/historial; refrescar después de escrituras.
4. Simular desconexión o rechazo recuperable: conservar formulario y evitar doble envío; revisar mensajes y recuperación de lecturas.
5. Verificar alertas automáticas desde Signos vitales y Eventos críticos sin duplicar la escritura original.
6. Comprobar auditoría con ALERT_TRIGGERED / ALERT_ACKNOWLEDGED / UPDATE.

El tester comprueba el APK y la API desplegada. CI del nuevo PR queda
pendiente de abrirlo y debe corresponder al último commit publicado.
La fase siguiente es Dashboard y monitoreo, después del merge en `test`.

## PR hacia test

**Título:** `feat(alerts): completar validaciones y transiciones de estado`

```markdown
Completa Alertas con descripción de 1–255 caracteres tras trim, paciente
explícito y permisos Nurse/Doctor/Admin en interfaz y aplicación.
Solo Doctor/Admin cierran; el flujo sigue Activa → Atendida → Cerrada.

Añade filtros de alertas activas, detalle por ID y actualización del
historial. Usa fechas reales de la API y comprueba el estado antes del PATCH.
Evita doble envío, conserva formularios ante errores y recupera respuestas
confirmadas mediante GET sin repetir escrituras.

Corrige la auditoría de creación a ALERT_TRIGGERED y conserva los avisos
de alertas automáticas sin repetir Signos vitales ni Eventos clínicos.

Verificación: 380 pruebas aprobadas, incluidas 133 nuevas de Alertas;
formato, análisis y git diff --check aprobados.
APK release compilado. Pendiente: CI del PR y revisión del APK por el tester.
Sin cambios en backend, SDK ni dependencias.
```
