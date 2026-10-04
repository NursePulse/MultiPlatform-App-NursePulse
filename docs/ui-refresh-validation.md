# Interfaz adaptable de NursePulse

## Alcance

Implementación del modelo visual aprobado por el usuario, con bordes más
sutiles. Rama `feature/responsive-ui-refresh`, creada desde `test` en `ab76004`
después del merge del PR #15 de integración final.

- Cabeceras y menú lateral verde profundo `#123B37`, botones teal `#0F766E`,
  fondos claros y marca de pulso dibujada con Flutter.
- Tarjetas con contorno `#B9CDCC` de 1 px; campos con `#8CA5A5` de 1 px y foco
  de 1,5 px. Estados clínicos conservan sus colores y etiquetas.
- Login y registro comparten cabecera y formulario desplazable. Se conserva
  toda validación y el registro de edad entera entre 18 y 90 inclusive.
- Móvil: Inicio, Pacientes, Alertas y Más. Más abre el menú completo según el
  rol real. Se conserva el acceso superior al menú y el cierre de sesión.
- Desde 900 px: menú lateral desplazable, también con texto ampliado.
  Contenido limitado a 1200 px, autenticación a 560 px y hojas de formulario
  a 720 px. El teclado, áreas seguras y orientación reducen el espacio disponible.
- Dashboard: indicadores en 1, 2 o 4 columnas según ancho y escala de texto;
  tarjetas alineadas por fila sin alturas fijas. Pacientes y alertas se muestran
  en paneles independientes que caben lado a lado cuando hay espacio suficiente.
- Pacientes: avatar, estado clínico, habitación/cama, documento, diagnóstico y
  acceso al seguimiento. Se conservan todas las acciones autorizadas.
- El tema compartido renueva signos vitales, eventos, SBAR, alertas,
  seguimiento, reportes, auditoría, usuarios y suscripciones, incluidos sus
  botones, tarjetas, campos, estados, diálogos y hojas.
- Filtros de Pacientes, Signos vitales y Alertas pueden desplazarse cuando el
  teclado o una ventana corta dejan poco espacio. Los formularios de eventos,
  SBAR y alertas desplazan también el título para evitar desbordamientos.
- Barras del sistema: iconos claros sobre las cabeceras oscuras e iconos oscuros
  junto a la navegación inferior clara.

Cambios de presentación únicamente. Backend, contratos API, reglas clínicas,
permisos de aplicación, Riverpod, GoRouter y dependencias permanecen conservados.
Los reportes siguen locales y el pago de suscripciones sigue siendo simulado.
Las imágenes generadas para aprobar el diseño no forman parte de la aplicación.

## Comprobación automatizada

Entorno conservado: Flutter 3.47.2 y Dart 3.13.2 en Windows/PowerShell.

- `dart format lib test`: completado.
- `flutter analyze --no-pub`: sin problemas.
- `flutter test --no-pub`: **902 pruebas aprobadas** (857 existentes y 45 nuevas).
- Prueba de arranque repetida después del ajuste final de barras del sistema:
  aprobada con `flutter test --no-pub test/widget_test.dart`.
- `git diff --check`: sin errores.
- `flutter build apk --release --no-pub`: compilación aprobada. APK disponible
  en `build/app/outputs/flutter-apk/app-release.apk`, aproximadamente 53,7 MB.
  Java/Gradle emite advertencias de acceso nativo del entorno; no impiden compilar.

Las 45 pruebas nuevas usan el tema real, GoRouter, Riverpod, almacenamiento
simulado y Dio interceptado, con datos ficticios:

| Cobertura | Casos |
| --- | ---: |
| Todas las rutas y navegación móvil/lateral por rol, tamaños y escala | 18 |
| Login y registro con teclado, texto al 200 % y datos vacíos | 6 |
| Formularios de pacientes, signos, eventos, SBAR, alertas, reportes y suscripciones con teclado | 21 |

Tamaños comprobados: 320×640, 390×844, 844×390, 1024×768 y 1280×720.
Escalas de texto: 100 % y 200 %. Las pruebas comprueban ausencia de excepciones
de layout, acceso a los botones, navegación y que formularios vacíos no
escriben en la API. La navegación de enfermería no consulta auditoría.
La integración de navegación anterior también usa ahora el tema real.

Se revisaron capturas de widgets renderizados con datos ficticios para login,
Dashboard móvil/tablet, Pacientes y su formulario. Los artefactos de revisión
permanecen en `build/ui-preview/`, excluidos de Git; no son pruebas en dispositivo.

## Revisión pendiente del tester

1. Instalar el APK y comprobar login, registro y cierre de sesión.
2. Recorrer todos los módulos con Enfermería, Médico y Admin; revisar menú,
   accesos inferiores, Más y permisos para registrar o administrar.
3. Abrir los formularios con teclado, girar el dispositivo y ampliar el texto;
   comprobar campos, errores, acciones y conservación de datos.
4. Revisar tarjetas, etiquetas clínicas, contornos sutiles y contraste de
   cabeceras, barras del sistema, botones y estados en el dispositivo real.
5. Repetir un flujo clínico autorizado y un fallo recuperable con datos de
   prueba: comprobar actualización de listas/detalles y ausencia de doble envío.
6. Comprobar persistencia de reportes locales y aviso de suscripción simulada.

Las pruebas automatizadas y la compilación no acreditan funcionamiento contra
producción, instalación en un dispositivo real ni validación de iOS.

## PR hacia test, listo para copiar

**Título:** feat(ui): renovar NursePulse con interfaz adaptable y bordes sutiles

**Descripción:**

Aplica el diseño visual aprobado desde login a todos los módulos: cabeceras
verde profundo, tarjetas y campos con bordes suaves, navegación inferior en
móvil y menú lateral desplazable en tablet. Dashboard adapta indicadores y
paneles al espacio disponible; filtros y formularios siguen accesibles con
teclado, orientación horizontal y texto ampliado.

Conserva validaciones, permisos, datos, Riverpod, GoRouter y contratos existentes.
Backend y dependencias sin cambios. Verificado con formato, análisis sin
problemas, 902 pruebas aprobadas, `git diff --check` y APK release compilado.
Incluye 45 pruebas nuevas con APIs simuladas. Pendiente revisión visual y
funcional del APK por el tester antes del merge.
