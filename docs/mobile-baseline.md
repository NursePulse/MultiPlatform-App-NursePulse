# NursePulse: bases y plan de paridad móvil

Revisión estática: 2026-10-03. Este documento fija el punto de partida;
no acredita compilación, pruebas aprobadas ni funcionamiento contra la API desplegada.

## Alcance acordado

- Trabajar en NursePulse/MultiPlatform-App-NursePulse con Flutter multiplataforma.
- Reproducir funciones y validaciones de la web, adaptando las pantallas al dispositivo.
- Incluir pruebas automatizadas de las reglas y del comportamiento del formulario.
- Mantener el backend sin cambios. Cualquier propuesta de modificación requiere
  explicación previa al propietario y autorización explícita.
- Desarrollar por sección: rama desde main, validación, PR, revisión, merge y
  siguiente rama desde el main actualizado.

Los destinos exactos de entrega, la fecha de entrega y los dispositivos de prueba
quedan pendientes de confirmar. La rúbrica recibida requiere su análisis.
La existencia de carpetas de plataforma no demuestra compatibilidad verificada.

## Versiones de referencia

| Repositorio | Commit revisado |
| --- | --- |
| MultiPlatform-App-NursePulse | 44cc3541081647a3fecfe236f3bc560e94c5129c |
| Application-Web-Nurse-Pulse | 7bd388fd4e0c930ff310dd21bdc6eddfc3ebdaf3 |
| Backend-NursePulse, solo lectura | 0fdae8277c629d967f49b925132419a76d52acfd |

El código web configura Spring Boot en src/environments y ya usa servicios
HTTP para autenticación y módulos clínicos. Su README aún menciona json-server;
no debe usarse como evidencia de la integración vigente.

CreateHandoverResource del backend ya recibe Situation, Background,
Assessment y Recommendation. No hace falta añadir esos campos al backend.

## Base existente y diferencias verificadas

| Área | Diferencia o pendiente |
| --- | --- |
| Arquitectura | Conservar los módulos domain/application/infrastructure/presentation |
| Red y sesión | Probar restauración, expiración y 403; configurar URL por entorno |
| Registro | Faltan nombres, apellidos, teléfono, edad, correo y selección Nurse/Doctor |
| Roles | Descarta Doctor/Admin y aplica Nurse como fallback; alinear con roles reales |
| Pacientes | Faltan formato, límites, duplicados y selección de médico como en web |
| Vitales | Probar límites, tipos numéricos y rechazo de valores no finitos |
| Eventos | Faltan máximos 120 y 1000 y pruebas de envío bloqueado |
| SBAR | Falta paridad de longitudes y revisión del receptor |
| Dashboard | No se encontró controlador /dashboard/summary en el backend revisado |
| Alertas | Revisar cada acción, transición y permiso contra Spring Boot |
| Reportes | No se encontró controlador /reports en el backend revisado |
| Suscripciones | Pago simulado como en web; portar pruebas de validación |
| Recuperación | Falta pantalla móvil; no se encontraron los mappings web en el backend revisado |
| Calidad | Un test móvil de arranque/splash; añadir cobertura por módulo |

La web tiene seis archivos de pruebas: autenticación store, login, registro,
auditoría store, alertas store y validación de pago. Su existencia no demuestra
que pasen ni que todos los formularios estén cubiertos; no fueron ejecutados aquí.

## Matriz inicial de validaciones

La matriz combina las reglas del componente y los atributos de la plantilla web.
Cuando la web difiere del backend, se registra la diferencia y se conserva el
contrato existente. Validar también al enviar y al pegar texto.

| Formulario / campo | Regla de referencia |
| --- | --- |
| Registro / usuario | Obligatorio; contrato de 3 a 50 caracteres |
| Registro / nombres y apellidos | Letras y espacios, con acentos/ñ; máximo 20 en web |
| Registro / teléfono | Exactamente 9 dígitos; limitar escritura y pegado |
| Registro / edad | Entero; web declara 1–120, backend exige 18–120; respetar el contrato |
| Registro / correo | Obligatorio y formato válido; máximo 254 según contrato |
| Registro / contraseña | 12–20 caracteres, mayúscula, número y carácter especial |
| Registro / confirmación | Obligatoria y exactamente igual a contraseña |
| Registro / rol | Solo ROLE_NURSE o ROLE_DOCTOR en registro público |
| Paciente / nombres y apellidos | Obligatorios; letras/acentos/ñ/espacios; máximo 80 |
| Paciente / documento clínico | Solo dígitos, 8–20 caracteres; sin duplicados, excluyendo el propio paciente al editar |
| Paciente / nacimiento | Obligatorio, desde 1930-01-01 hasta hoy |
| Paciente / diagnóstico | Obligatorio; máximo 180 |
| Paciente / habitación y cama | Obligatorios; máximo 20 cada uno |
| Paciente / género y médico | Selección requerida; médico desde usuarios Doctor |
| Vitales / paciente | Selección válida requerida |
| Vitales / frecuencia cardíaca | 20–250 |
| Vitales / frecuencia respiratoria | 5–80 |
| Vitales / presión sistólica | 50–260 y mayor que diastólica |
| Vitales / presión diastólica | 30–180 |
| Vitales / saturación | 0–100 |
| Vitales / temperatura | 30–45 |
| Evento / paciente, tipo y severidad | Paciente requerido; opciones del dominio |
| Evento / título | 4–120 caracteres tras trim |
| Evento / descripción | 10–1000 caracteres tras trim |
| SBAR / paciente y receptor | Requeridos; receptor Nurse, distinto del usuario actual |
| SBAR / S, B, A y R | Cada campo entre 8 y 1000 caracteres tras trim |
| Alertas, reportes, recuperación, usuarios y pagos | Completar inventario antes de implementar su sección |

Fuentes: componentes y plantillas web sign-up, patient-list, vital-sign-list,
clinical-event-list y sbar-list; contratos del backend SignUpResource y
CreatePatientResource.

El backend exige nombres de registro formados por grupos de letras separados
por un espacio. Esa condición se comprobará junto con el límite web.

El campo actual se llama documento clínico y acepta 8–20 dígitos.
Las validaciones locales de duplicados se complementan con los errores de la API;
no sustituyen las restricciones del servidor.

## Permisos de referencia del backend

| Acción | Nurse | Doctor | Admin |
| --- | --- | --- | --- |
| Consultar pacientes y vitales | Sí | Sí | Sí |
| Crear paciente / registrar vitales | Sí | No | Sí |
| Editar paciente | Sí | Sí | Sí |
| Eliminar paciente | No | No | Sí |
| Crear o reconocer handover | Sí | No | Sí |
| Atender alerta | Sí | Sí | Sí |
| Cerrar alerta | No | Sí | Sí |
| Consultar auditoría | No | Sí | Sí |
| Administrar roles | No | No | Sí |

Fuente: WebSecurityConfiguration.java. Verificar también restricciones de los
controladores y reglas de negocio en cada módulo. El modo visual de demostración
no debe cambiar la autorización. Un rol desconocido no concede permisos Nurse.

## Ramas y secuencia

La documentación inicial se incluye en chore/mobile-foundation.
Cada rama posterior parte del main actualizado tras integrar la anterior.

| Orden | Rama |
| --- | --- |
| 1 | chore/mobile-foundation |
| 2 | feature/auth-validation |
| 3 | feature/patients-validation |
| 4 | feature/vitals-validation |
| 5 | feature/clinical-events-validation |
| 6 | feature/sbar-validation |
| 7 | feature/alerts-workflow |
| 8 | feature/dashboard-monitoring |
| 9 | feature/audit-users |
| 10 | feature/reports-subscriptions |
| 11 | feature/multiplatform-polish |

Recuperación y reportes requieren una decisión de alcance si la API vigente
no soporta sus operaciones. Confirmar si el despliegue usa el mismo commit revisado.

## Criterios de cada PR funcional

- Inventario de campos, reglas, textos de error, permisos y referencias web/API.
- Pruebas de vacío/espacios, tipo inválido y bordes min-1/min/max/max+1.
- Pruebas de reglas entre campos cuando corresponda.
- Widget tests: error visible junto al campo; una entrada inválida no llama la API;
  una válida envía el payload esperado; evitar doble envío mientras guarda.
- API simulada para respuestas relevantes: 400, 401, 403, 409, conexión y éxito.
- Comprobar que formulario y datos se conservan ante errores recuperables.
- Ejecutar formato, flutter analyze, flutter test y build aplicable.
- Registrar evidencia de integración manual con el backend existente.
- Documentar resultados reales y checks pendientes.
- Revisar el PR antes del merge y actualizar main antes de la siguiente rama.

## Estado de la revisión

Se compararon estáticamente contratos y validaciones de los tres repositorios.
La web y el backend están sin cambios.
El estado de las comprobaciones se registra en foundation-checks.md.