# Interfaz clínica: espaciado y gravedad

Fecha: 05/10/2026. Rama: `feature/ui-spacing-severity`.
Base: `test` actualizado, `5c3176e`; PR #19 de interfaz/idiomas y PR #18
del icono confirmados como integrados antes de comenzar.

Este documento registra la primera implementación aprobada. Los ajustes
posteriores del mismo PR #22, las 954 pruebas y el APK actualizado están en
[Alertas: gravedades, filtros y avisos](alert-inbox-filters-validation.md).

## Cambios aprobados

- Login y Registro conservan su implementación y diseño anteriores.
- Dashboard conserva sus ocho indicadores y las reglas por rol; mejora
  separación, tarjetas de pacientes, alertas recientes y auditoría.
- Pacientes separa estado, ubicación, documento y diagnóstico. Búsquedas
  breves con ayuda visible conservan todos sus criterios actuales.
- Signos vitales y Seguimiento presentan las cinco mediciones en bloques
  adaptativos; filtros de historial y notas originales se conservan.
- Alertas muestra borde lateral en las cuatro gravedades: crítica roja,
  alta naranja, moderada ámbar y baja verde. El estado Activa es neutro;
  Atendida y Cerrada mantienen sus etiquetas y transiciones existentes.
  El borde no cambia por rol ni por estado de atención.
- Eventos clínicos presenta identidad, gravedad, tipo, fecha, nota y
  responsable separados. SBAR muestra S/B/A/R y recepción con texto visible.
- Acciones de creación en filas propias, con los permisos y bloqueos previos.
  Se retiran botones flotantes que tapaban contenido y acciones de tarjetas.
- Reportes muestra los siete totales en una cuadrícula y separa conclusión
  y metadatos. Generación en panel desplazable sobre la navegación principal;
  las fechas inclusivas, persistencia y errores siguen en la lógica existente.
- Auditoría separa acción, descripción y metadatos. IDs largos abreviados en
  referencias; al tocarlas se abre el ID exacto, seleccionable. Los modelos,
  filtros y PDF conservan los identificadores completos.
- Usuarios conserva protección del propio rol, roles reales y colores
  correspondientes. Suscripciones conserva catálogo, precios, planes locales
  y pago simulado; formulario y aviso legibles, sin cobros reales.
- Márgenes de página de 20 px, tarjetas clínicas con 20 px interiores y
  separación de 16 px; etiquetas ajustadas al contenido. Texto ampliado y
  ventanas pequeñas pasan a una columna o desplazamiento continuo.
- Se conservan verde de Enfermería, azul de Medicina, dorado de Administración,
  ES/EN, Riverpod, GoRouter y contratos/API existentes. Backend sin cambios.
  Sin cambios en SDK, dependencias, dominio, aplicación o infraestructura.

## Comprobaciones ejecutadas

- Flutter 3.47.2 y Dart 3.13.2 disponibles; sin actualizaciones.
- `dart format lib test`: correcto.
- `flutter analyze --no-pub`: **No issues found**.
- `flutter test --no-pub --reporter expanded`: **947 pruebas aprobadas**.
- 17 pruebas nuevas: bordes de las cuatro gravedades, tres roles, ES/EN,
  tarjetas y acciones accesibles en 320/390 px y texto hasta 200 %, IDs completos,
  etiquetas compactas y formulario de reportes con teclado en ambas orientaciones.
- Suite previa adaptada a acciones sin FAB, metadatos separados y desplazamiento;
  conserva comprobaciones de permisos, inválidos sin API, errores, persistencia
  y envío único. Todas las APIs de pruebas están simuladas y los datos son ficticios.
- Sin fallos, excepciones de layout ni advertencias de pulsaciones fuera de
  pantalla en la suite final.
- Capturas renderizadas con Flutter, tipografía e iconos reales, datos ficticios:
  `build/ui-spacing-preview/`. Verificación adicional aprobada; no es emulador.
- `git diff --check`: correcto.
- APK release: compilación aprobada, código de salida de Flutter 0; 58 966 730 bytes (56.2 MB según Flutter).

APK: `build/app/outputs/flutter-apk/app-release.apk`.
SHA-256: `88857B7AAE6CA12FD1ED383CFCF235CEA9DF3D8B910D14EB374D4CA4CED595BA`.

Los logs locales están en `build/ui-spacing-verified-*.log` y no se versionan.
Gradle/JDK emite advertencias de acceso nativo; el resultado de compilación se
comprueba con el código de salida real de Flutter.

## Revisión pendiente en dispositivo

1. Instalar el APK final y recorrer todas las secciones con cada rol permitido.
2. Comprobar alertas de las cuatro gravedades y estados Activa/Atendida/Cerrada;
   revisar que Registrar, Atender y Cerrar sean accesibles al desplazarse.
3. Probar nombres y notas largos, teclado, rotación y texto ampliado.
4. Cambiar ES/EN, volver a abrir la app y comprobar preferencia y datos originales.
5. Abrir ID completo en Auditoría; comprobar filtros, paginación y exportación.
6. Generar/reabrir un reporte, probar errores recuperables y doble toque;
   confirmar el período inclusivo y conservación de resultados.
7. Probar recepción SBAR y pago simulado sin repetir operaciones confirmadas.
8. Revisar Login y Registro, que mantienen su diseño y reglas anteriores.

Las pruebas simuladas y capturas no acreditan funcionamiento en dispositivo
ni integración contra la API de producción. Merge y PR quedan a cargo del usuario.

## PR hacia test

Título: `feat(ui): aplicar mockups clínicos y bordes por gravedad`

```markdown
Mejora la distribución de Dashboard, Pacientes, Seguimiento, Signos vitales,
Eventos, SBAR, Alertas y módulos administrativos según los mockups aprobados.
Las alertas llevan bordes por gravedad y las acciones de creación ya no tapan
tarjetas. Reportes y pago simulado usan formularios adaptativos; Auditoría
permite consultar IDs completos desde referencias abreviadas.

Conserva Login y Registro, permisos, validaciones, colores por rol y ES/EN.
Backend y dependencias sin cambios.

Validación: formato, análisis sin incidencias, 947 pruebas aprobadas,
git diff --check y APK release. Pendiente revisión del APK por el tester.
```
