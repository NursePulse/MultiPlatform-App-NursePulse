# Rediseño visual por rol e idioma ES/EN

## Base y alcance

- Fecha: 2026-10-05 (America/Lima).
- Base: `origin/test` en `789e70e`, merge del PR #16 de interfaz adaptable.
- Rama: `feature/ui-role-localization`.
- Git estaba limpio al comenzar. Se conserva el trabajo anterior.
- Se implementa la propuesta aprobada en todos los módulos. Backend, endpoints, contratos, permisos y reglas clínicas conservados.

## Cambios

- Enfermería: verde `#0F766E`, cabecera `#123B37`.
- Medicina: azul `#1D4ED8`, cabecera `#17395C`.
- Administración: dorado `#85621D`, cabecera `#45371C`, conforme a la preferencia del usuario.
- El tema deriva del rol real de la sesión. No hay selector para suplantar otro perfil.
- Tarjetas blancas con bordes sutiles, tipografía Roboto consistente, etiquetas legibles y acciones separadas. Severidad, riesgo y estados clínicos conservan sus colores para cualquier rol.
- Dashboard: icono y valor alineados, columnas adaptables y encabezados desplazables en ventanas cortas.
- Seguimiento: una única cabecera con regreso; información agrupada en campos y columnas adaptables, seguida del historial y filtros existentes.
- Tema y distribución consistentes en pacientes, alertas, eventos, SBAR, signos, usuarios, auditoría, reportes y suscripciones. Las alertas críticas tienen un acento lateral rojo.
- Separación entre controles en los formularios, especialmente Reportes y checkout simulado. El teclado no reduce dos veces el área disponible entre scaffolds anidados.
- Selector visible ES/EN en acceso, registro y sesión. La preferencia usa el almacenamiento seguro ya instalado con una clave independiente de la sesión.
- La restauración tardía no sobrescribe una elección explícita; escrituras sucesivas serializadas. Un fallo al guardar el idioma muestra un aviso sin bloquear la app.
- Traducciones en la presentación: navegación, formularios, validaciones, estados, mensajes propios y resumen local de reportes. Calendarios y controles Material localizados.
- Nombres, documentos, diagnósticos, notas clínicas, descripciones ingresadas y valores enviados a la API conservan su contenido. Mensajes desconocidos del servidor y PDF del backend conservan su idioma original.
- Se incorpora `flutter_localizations` del SDK. Requiere `intl ^0.20.3`; solo se ajusta esa dependencia. No se actualizan Flutter/Dart ni los demás paquetes.

## Verificación automatizada

- Flutter `3.47.2`, Dart `3.13.2`.
- `dart format lib test`: correcto.
- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub`: **930 pruebas aprobadas**, 902 existentes y 28 nuevas; sin excepciones ni avisos de taps fuera de alcance en la ejecución final.
- APIs simuladas y datos ficticios. Se conservan las pruebas anteriores de roles, sesión, validaciones, errores, doble envío y escrituras confirmadas.
- Nuevos casos: persistencia ES/EN, restauración tardía, elecciones rápidas, fallos de preferencias, conservación del formulario al cambiar idioma, entradas inválidas sin API, calendarios localizados, campos separados, notas clínicas sin traducir y regreso desde seguimiento.
- `NursePulseApp` se prueba en ES/EN con los tres roles a 390×844, 320×640 con texto al 200% y 1024×768. Continúa la matriz anterior de otras dimensiones, orientación horizontal y formularios con teclado.
- Las pruebas de historial y checkout desplazan el contenido y esperan el layout antes de interactuar. Dashboard distingue el scroll del encabezado del contenido.
- Se renderizaron y revisaron capturas de Flutter con fuentes Material y datos ficticios, sin emulador. Auxiliares en `build/ui-role-preview`, no assets de la app ni prueba de funcionamiento en un teléfono.
- `git diff --check`: correcto.
- `flutter build apk --release --no-pub`: correcto, salida Flutter **0**. APK en `build/app/outputs/flutter-apk/app-release.apk`, **58,690,374 bytes** (56.0 MiB mostrados por Flutter).
- SHA-256: `FF0FE4881D4D842B67499779A255D218E9741F6C28465AABD1433B95E83D260A`.
- Gradle/JDK emite las advertencias de acceso nativo del entorno existente; la compilación termina correctamente. No se cambia Java/Gradle por estas advertencias.

## Revisión del tester pendiente

1. Instalar el APK nuevo y revisar los tres roles: cabeceras, botones, navegación y colores clínicos.
2. Revisar login, registro, Dashboard y todos los módulos con fuente normal y ampliada; desplazar las pantallas bajo el teclado.
3. Abrir formularios clínicos, generación de reporte y pago simulado: campos separados, errores sin envíos inválidos y datos conservados ante fallos recuperables.
4. Cambiar ES/EN, cerrar/reabrir la app y verificar persistencia y calendarios. Las notas clínicas deben conservar su texto.
5. Probar navegación directa, regreso desde seguimiento, menú de cuenta y cierre de sesión. Permisos acordes al usuario autenticado.
6. Repetir flujos funcionales contra la API con cuentas de prueba y comprobar que una escritura confirmada no se repite.

No se declara validación en dispositivo real ni contra producción. El tester revisa antes del merge.

## PR listo para copiar

**Título:** `feat(ui): rediseñar interfaz por rol y añadir idioma ES/EN`

**Base:** `test` · **Head:** `feature/ui-role-localization`

```markdown
Corrige espacios excesivos, doble cabecera de seguimiento y controles pegados en formularios. Aplica el diseño aprobado a todos los módulos con tarjetas y tipografía consistentes, verde para enfermería, azul para medicina y dorado para administración, conservando permisos y colores clínicos.

Añade selector ES/EN visible y persistente, traducciones de interfaz/validaciones y calendarios localizados. Los datos clínicos y el backend se conservan. flutter_localizations requiere ajustar intl a ^0.20.3; el SDK y los demás paquetes mantienen sus versiones.

Validación: dart format, flutter analyze sin incidencias, 930 pruebas aprobadas con APIs simuladas, git diff --check y APK release. Incluye pruebas de roles, dimensiones, teclado, idioma, persistencia y conservación de datos. Pendiente revisión del APK por el tester antes del merge.
```
