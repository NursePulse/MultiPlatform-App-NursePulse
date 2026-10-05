# Reportes y suscripciones

Fecha: 2026-10-04. Rama: `feature/reports-subscriptions-validation`.
Base: `test` remoto `7179383cf93caa4872364dbc5d1e5081b2c629aa`, merge del PR #13.
Se comprobó con Git y GitHub que el commit de Auditoría/usuarios `5f1ea1f`
está incluido en esa base; `Verify Flutter` aprobó ese commit. Git estaba
limpio al comenzar. Backend consultado solo para contratos, sin modificaciones.

## Reportes: criterios acordados

| Criterio | Implementación y evidencia |
| --- | --- |
| Persistencia | Se elimina ReportApi y sus GET/POST `/reports`. ReportLocalStore usa flutter_secure_storage ya instalado, clave `nurse-pulse.generated-reports`; no se añaden paquetes. Pruebas entre instancias y del canal nativo simulado |
| Corrupción | JSON ilegible, esquema inválido o IDs duplicados devuelven lista vacía; una falla real de almacenamiento muestra error y no se trata como corrupción |
| Hasta inclusiva | Inicio a medianoche local y fin al último microsegundo del día elegido. Incluye registros a las 23:59:59 y fracciones del último segundo; excluye el siguiente día |
| Formulario | Título obligatorio tras trim, tipo reconocido, ambas fechas obligatorias, inicial no posterior a final; validación en UI y aplicación antes de consultas |
| Alertas | Usa triggeredAt real del recurso; fecha ausente se incluye, como web. CLOSED no cuenta como activa ni crítica |
| Auditoría | Después del guardado local se intentan AUDIT_LOG/VIEW y AUDIT_LOG/UPDATE, como resolveAuditContext de la web. Metadata conserva descripción/source y actor de sesión. Un fallo muestra aviso y conserva el reporte |
| Resumen | Total de pacientes, signos del periodo, eventos desde auditoría CLINICAL_EVENT, SBAR del periodo, alertas activas y críticas activas, auditorías del periodo |
| Fallos parciales | Signos, cada consulta SBAR, alertas y auditoría aportan cero si fallan; los otros recursos conservan su conteo. Fallo de Pacientes aborta, conserva listado y no guarda ni audita |
| Permisos/concurrencia | Doctor/Admin en ruta, UI y aplicación. Nurse/desconocidos no leen almacenamiento ni consultan recursos desde Reportes. Un envío por vez, también durante guardado/auditoría; formulario, cancelar y salida bloqueados |
| Lista y detalle | Orden descendente por creación, tipo, estado, periodo, autor, fecha, siete indicadores, conclusión, tono, actividad e ID local; refresco solo lee almacenamiento |

Se sigue la decisión acordada de **contar Eventos desde la auditoría**, igual
que report.store.ts. No se consulta `/clinical-events` para Reportes. Ese
conteo representa movimientos de entidad CLINICAL_EVENT, no necesariamente
eventos únicos: una entidad con varias auditorías puede contar varias veces.
El historial y Dashboard conservan sus consultas reales de Eventos; no se
cambia su criterio por el del reporte.

La auditoría utilizada para resumir sigue la lectura web de la primera página
`page=0&size=100`. El contador representa los registros cargados de esa página
que caen en el periodo, no toda la auditoría histórica. Las dos auditorías de
generación se envían después de calcular y guardar el resumen y no se incluyen
retroactivamente en ese mismo reporte.

Las cuatro conclusiones son las de la web: críticas, activas, actividad sin
alertas y sin movimientos relevantes. La tercera se decide por signos o SBAR;
solo movimientos de auditoría/Eventos no la activan. Se documenta y prueba ese
detalle para mantener la regla existente.

El fin de día móvil incluye fracciones de segundo; la web construye
23:59:59. La adaptación cumple la inclusión del día completo solicitado.
El formulario comienza con los últimos siete días, como web. Los reportes
son locales y el almacenamiento conserva su contenido al cerrar sesión,
como el navegador web; el acceso sigue protegido por rol. No hay sincronización
de reportes entre dispositivos ni exportación de reportes, funciones que la
referencia no ofrece en este flujo.

## Suscripciones

La web usa catálogo y selección locales y PaymentGatewayService simulado.
El OpenAPI desplegado no expone `/subscriptions`, `/payments` ni `/reports`.
Se conserva esa simulación y se muestra explícitamente que no realiza cobros.
No se inventa una pasarela ni una suscripción confirmada por un servidor.

| Campo o flujo | Regla aplicada y comprobada |
| --- | --- |
| Catálogo | Esencial USD 0 / 5 plazas; Profesional USD 49 / 25; Empresarial USD 129 / 100, características y recomendado como web |
| Acceso | Sesión Nurse/Doctor/Admin; selección de plan no cambia roles ni desbloquea funciones |
| Titular | 3–80 caracteres tras trim |
| Correo | Regla Validators.email de Angular y máximo 120 caracteres, con trim |
| Documento | DNI 8 o RUC 11 dígitos; cambiar tipo limpia el documento; obligatorio en UI y lógica |
| Tarjeta | Formato de hasta 19 dígitos, Luhn 13–19; marca Visa/Mastercard/Amex como referencia |
| Vencimiento/CVV | MM/AA no pasado, incluye mes vigente; CVV de 3–4 dígitos |
| Solicitud simulada | Plan/precio de catálogo, USD, titular, correo y últimos cuatro dígitos. PAN completo, CVV y documento no pasan al gateway ni se persisten |
| Plan local | Solo se publica después de guardar el ID; se restaura al reiniciar, valor desconocido vuelve a Esencial |
| Concurrencia | Bloqueo de doble pago, edición, cancelación, arrastre y salida durante envío |
| Errores | Fallo de simulación conserva formulario. Simulación confirmada seguida de guardado fallido conserva recibo y ofrece reintentar solo almacenamiento |
| Recibo | Transacción simulada, últimos cuatro, fecha y total; campos sensibles del formulario se limpian tras confirmación. Volver a Esencial descarta el recibo anterior antes de otro checkout |

Las lecturas iniciales deduplican y no pisan una selección mientras guarda.
Un cambio de sesión descarta el estado de aplicación; respuestas de notifiers
descartados no publican datos ni inician una persistencia pendiente de lectura.
Las pruebas no usan tarjetas, documentos o datos clínicos reales: solo valores
ficticios y el número de demostración que publica el formulario web.

## Contratos de red y almacenamiento

| Método | Recurso existente | Uso |
| --- | --- | --- |
| GET | `/patients` | Obligatorio para consolidación |
| GET | `/vital-sign-records` | Signos del periodo |
| GET | `/handovers/patients/{id}` | SBAR por paciente, como web; no listado global |
| GET | `/alerts` | Alertas con triggeredAt real o ausente |
| GET | `/audit-logs?page=0&size=100` | Movimientos y conteo de Eventos |
| POST | `/audit-logs` | Dos acciones distintas VIEW/UPDATE después de guardado local |
| Local | `nurse-pulse.generated-reports` | JSON validado de reportes consolidados |
| Local | `nurse_pulse_subscription_plan` | ID de plan; clave móvil existente conservada |

Refrescar Reportes no consulta APIs clínicas ni repite las dos auditorías.
El Dashboard y la vista Auditoría se invalidan después de los intentos de
auditoría. Las pruebas de contrato verifican que no aparece ningún GET/POST
a `/reports`, ni acciones REPORT_GENERATED ni entidades REPORT en la red.

## Fuentes revisadas

Web: `60430f93b920f891cce0417f2ec5a67834a4c544`, confirmado en revisiones previas
y conservado como referencia de esta fase.

- [Consolidación, persistencia y conclusiones web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/report/application/report.store.ts).
- [Formulario y fechas web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/report/presentation/views/report-list/report-list.ts).
- [Detalle y métricas web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/report/presentation/views/report-list/report-list.html).
- [Mapeo de acciones de auditoría](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/audit/application/audit.store.ts).
- [Catálogo y persistencia de suscripciones](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/subscriptions/application/subscription.store.ts).
- [Checkout web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/subscriptions/presentation/components/payment-checkout/payment-checkout.ts).
- [Aviso de demostración y recibo web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/subscriptions/presentation/components/payment-checkout/payment-checkout.html).
- [Validación de tarjeta y documento](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/subscriptions/domain/services/payment-validation.ts).
- [Gateway simulado web](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/subscriptions/application/payment-gateway.service.ts).
- [Regla oficial de email de Angular](https://github.com/angular/angular/blob/main/packages/forms/src/validators.ts).
- [OpenAPI desplegado, consulta solo de contratos](https://backend-nursepulse-qfct.onrender.com/v3/api-docs).

## Verificación

Flutter 3.47.2; Dart 3.13.2. SDK y dependencias sin cambios.

- `dart format lib test`: ejecutado.
- `flutter test --no-pub test/reports test/subscriptions --reporter expanded`: **151 pruebas nuevas aprobadas**. También se actualizan los tres casos existentes de navegación Reportes para exigir persistencia local sin GET `/reports`.
- `flutter analyze --no-pub`: aprobado, sin incidencias.
- `flutter test --no-pub --reporter expanded`: **831 pruebas aprobadas**, incluidas las 151 nuevas y las regresiones de todas las fases anteriores.
- `flutter build apk --release --no-pub --dart-define=API_BASE_URL=https://backend-nursepulse-qfct.onrender.com/api/v1`: APK release compilado correctamente (53.7 MB), disponible en `build/app/outputs/flutter-apk/app-release.apk`. Gradle emitió una advertencia de acceso nativo de Java, sin errores de compilación.
- `git diff --check`: aprobado antes de publicación.

Las APIs y canales de plataforma se simulan en las pruebas. No se hicieron
escrituras en producción ni se ejecutó el APK en dispositivo/emulador.

## Pendientes del tester e integración final

1. Doctor/Admin: generar con título, tipo y fechas válidos; probar campos vacíos,
   rango invertido y doble toque. Nurse no accede ni consulta Reportes.
2. Generar, cerrar completamente la app y reabrir; confirmar lista, detalle,
   ID y resumen persistentes. Actualizar el APK sin borrar sus datos.
3. Con registros ficticios al inicio y fin de día, comprobar que Hasta hoy
   incluye signos y movimientos CLINICAL_EVENT de hoy y excluye mañana.
4. Comprobar alertas OPEN/ATTENDED/CLOSED, fecha ausente y fuera del periodo.
5. Simular fallos parciales y de Pacientes; comprobar cero por recurso opcional,
   aborto sin guardar para Pacientes y conservación del formulario/listado.
6. Confirmar dos auditorías AUDIT_LOG (VIEW/UPDATE); un rechazo no borra el
   reporte ni exige generarlo otra vez. Verificar límite de primera página.
7. Suscripciones: titular, email, DNI/RUC, tarjeta de demostración, mes vigente,
   CVV, cambio de tipo, cancelación y doble toque; confirmar recibo simulado.
8. Reabrir con plan seleccionado; simular fallo de guardado después del recibo
   y comprobar reintento de almacenamiento sin otra simulación de pago.
9. CI del PR del commit publicado, ejecución Android contra la API real y
   compilación/pruebas iOS en macOS siguen pendientes de revisión externa.

En integración final se revisarán las dos diferencias de Dashboard ya
señaladas: hora de consulta frente a último movimiento y contador de módulos
por rol real frente a modo visual. Este bloque conserva su comportamiento
actual y no cambia permisos ni reabre módulos anteriores.
La siguiente fase comienza después del merge de esta rama en `test`.

## PR hacia test

Título: `feat: completar reportes locales y validaciones de suscripciones`

```markdown
Corrige Reportes, que consultaba un recurso /reports inexistente: ahora consolida los datos de las APIs existentes y guarda el resumen en el dispositivo, como la web. Se restaura al reabrir y se recupera de datos locales corruptos.

- Valida título y fechas, incluye el día completo de Hasta y filtra alertas por triggeredAt real.
- Cuenta Eventos desde auditoría CLINICAL_EVENT, como la web; aplica los fallos parciales y las cuatro conclusiones acordadas.
- Solo Doctor/Admin pueden consultar o generar reportes; evita doble envío y conserva formularios ante errores.
- Audita con AUDIT_LOG/VIEW y AUDIT_LOG/UPDATE después de guardar, sin perder el reporte ante fallos.
- Completa el checkout simulado con titular, email, DNI/RUC, Luhn, vencimiento y CVV. Restaura el plan local y reintenta guardado sin repetir una simulación confirmada.

Verificación: formato, análisis sin incidencias, 831 pruebas aprobadas (151 nuevas), git diff --check y APK release compilado.

Sin cambios en backend, SDK o dependencias. Pendiente: tester Android/API real, CI del PR e iOS en macOS. Contratos, límites y casos manuales en docs/reports-subscriptions-validation.md.
```
