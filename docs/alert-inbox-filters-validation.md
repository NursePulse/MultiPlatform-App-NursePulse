# Alertas: gravedades, filtros y avisos dentro de la app

Seguimiento del PR #22, todavía abierto hacia `test`, en la misma rama
`feature/ui-spacing-severity`. No requiere cambios en el backend ni dependencias.
Login y Registro conservan su diseño.

## Cambios

- Barras laterales de 5 px: Crítica roja `#DC2626`, Alta naranja `#F97316`,
  Moderada amarilla `#EAB308`, Baja verde `#15803D`. El texto de las etiquetas
  conserva colores más oscuros para mantener el contraste. Dashboard,
  Seguimiento y Eventos clínicos usan la misma distinción de gravedad.
- Filtros Todas, Críticas, Altas, Moderadas y Bajas, traducidos a ES/EN.
  Cada gravedad coincide exactamente con su valor de API; Moderadas ya no
  agrupa Altas ni Bajas. Se siguen excluyendo las cerradas y mostrando las
  atendidas pendientes de cierre. Cambiar de filtro reinicia el desplazamiento.
- Campana en la cabecera con el número de alertas pendientes y las cinco
  últimas, más acceso al listado completo. El panel entero se desplaza para
  conservar el acceso con texto ampliado y ventanas pequeñas.
- Aviso debajo de la cabecera para alertas nuevas. Al tocarlo, o seleccionar
  una entrada de la campana, se navega a `/alerts?alert=ID` y se abre el detalle
  mediante el GET existente por ID. Al cerrar el detalle se limpia el parámetro,
  permitiendo abrir otra vez la misma alerta.
- La primera lectura correcta establece la referencia inicial: las alertas
  históricas cuentan en la campana pero no generan avisos nuevos. Los IDs vistos
  no se anuncian de nuevo al recargar, atender, cerrar o reaparecer. Si llegan
  varias alertas juntas, el aviso muestra la primera del listado ordenado;
  las demás quedan accesibles en la campana y el listado.
- Consulta cada 30 segundos mientras la app está activa, y al volver a ella.
  Se evitan consultas superpuestas y durante escrituras. El temporizador se
  cancela cuando no hay interfaz suscrita y al eliminar el proveedor.
- Una lectura automática fallida conserva el listado anterior. La primera
  carga y los reintentos manuales muestran errores. Los avisos, la referencia
  inicial y los IDs vistos se reinician al cambiar de cuenta o cerrar sesión.
  Sin un rol permitido no se consulta el endpoint de alertas.

Los avisos son internos mientras la app está abierta; no son notificaciones
push del sistema con la aplicación cerrada. La detección automática depende
de recibir una lectura correcta del servidor. No se fabrican estados, fechas,
pacientes ni IDs, y navegar por las notificaciones no realiza POST/PATCH.

## Verificación

Las pruebas usan APIs simuladas y datos ficticios. Se comprueban filtros
exactos, exclusión de cerradas, ancho de barra, las cuatro gravedades con los
tres roles y ES/EN, navegación por ID y apertura repetida, ausencia de avisos
históricos y duplicados, pausa/reanudación, fallos de lectura, aislamiento de
cuentas y permisos. El panel se prueba a 320 px con texto al 200 %.

- `dart format lib test`: completado.
- `flutter test --no-pub --reporter expanded`: **954 pruebas aprobadas**
  (947 anteriores y 7 nuevas), sin avisos de taps fallidos ni desbordamientos.

- `flutter analyze --no-pub`: **sin incidencias**.
- `git diff --check`: aprobado.
- Renderizado de las pantallas reales con datos ficticios: aprobado.
- `flutter build apk --release --no-pub`: aprobado, salida 0; 56.4 MB según
  Flutter, **59 147 094 bytes**. Sin validación todavía en dispositivo/API real.

APK: `build/app/outputs/flutter-apk/app-release.apk`.
SHA-256: `448AC5919B0716B4A72282589BB2F1ED84233B4321D0865A3920B0B0FEEE4DDE`.

Referencias web revisadas en el commit `60430f93b920f891cce0417f2ec5a67834a4c544`:
[campana y contador](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/shared/presentation/components/header/header.ts),
[filtro previo de Moderadas](https://github.com/NursePulse/Application-Web-Nurse-Pulse/blob/60430f93b920f891cce0417f2ec5a67834a4c544/src/app/notification/application/notification.store.ts).

## Revisión del tester

1. Comprobar Crítica/Alta/Moderada/Baja en Alertas, Dashboard y Seguimiento:
   la barra debe ser gruesa y la diferencia amarillo/naranja clara.
2. Probar los cinco filtros en ES/EN. Moderadas debe mostrar únicamente
   MEDIUM/MODERATE; Altas HIGH y Bajas LOW. Una tarjeta cortada por un
   desplazamiento anterior no debe quedar al comienzo de un filtro nuevo.
3. Entrar con alertas ya existentes: verificar contador/campana sin avisos
   históricos. Crear una alerta desde otra sesión de prueba, mantener la app
   activa y esperar una consulta (hasta 30 segundos, con servidor disponible).
4. Tocar el aviso y comprobar el ID/detalle correcto; cerrar y volver a abrirlo
   desde la campana. Confirmar que consultar no atiende ni cierra la alerta.
5. Revisar el panel con texto ampliado y pantalla horizontal. Probar pérdida
   de conexión, segundo plano/reanudación y cambio de cuenta sin datos ajenos.

## PR

Título sugerido: `Mejorar interfaz clínica, filtros de gravedad y avisos de alertas`

Descripción para el PR #22: mantiene los diseños aprobados y agrega barras de
gravedad más visibles, filtros exactos para todas las categorías y campana con
avisos internos que abren el detalle correspondiente. Conserva permisos,
transiciones, protección de escrituras confirmadas y contratos del backend.
Login y Registro mantienen su diseño. La validación en dispositivo y contra
la API real corresponde al tester antes del merge.

Validación para la descripción: formato y análisis sin incidencias, 954 pruebas
aprobadas, comprobación de diferencias y compilación del APK release.
