# NursePulse — Flutter multiplataforma

Aplicación clínica equivalente a la web Angular de NursePulse. Usa Riverpod
para estado, Dio para REST, GoRouter para navegación y almacenamiento seguro
para la sesión JWT. Consume el backend Spring Boot existente sin modificarlo.

## Requisitos

- Flutter **3.47.2**, correspondiente a la revisión de `.metadata`.
- Dart incluido con ese Flutter; `pubspec.yaml` requiere `^3.13.2`.
- Git y un editor. En Visual Studio Code, instala las extensiones Dart y Flutter.
- Para Android: Android SDK, Java 17 y un emulador o dispositivo configurado.

Instalación: <https://docs.flutter.dev/install/manual>.
Versiones: <https://docs.flutter.dev/install/archive>.
Comprueba la versión instalada antes de cambiar restricciones de SDK.

Desde la carpeta que contiene `pubspec.yaml`:

```powershell
flutter --version
flutter doctor -v
flutter pub get
flutter devices
```

## Ejecutar con la API existente

Por defecto la app usa el backend de producción
(`https://backend-nursepulse-qfct.onrender.com/api/v1`), así que basta con:

```powershell
flutter run
```

Ten en cuenta que en ese modo los registros y los cambios se hacen sobre datos
reales de producción, y que registrar una cuenta envía un correo de
verificación: no podrás iniciar sesión hasta abrir el enlace.

Si en Chrome (`flutter run -d chrome`) aparece "No se pudo conectar con el
servidor", es CORS: el backend solo acepta los orígenes locales
`http://localhost:4200` y los dominios de Vercel/Netlify. Fija el puerto:

```powershell
flutter run -d chrome --web-port=4200
```

La aplicación en Android o iOS no depende de CORS.

### Usar un backend local

`API_BASE_URL` debe incluir `/api/v1`. Si ejecutas el backend en tu equipo:

| Destino | URL local |
| --- | --- |
| Emulador Android | `http://10.0.2.2:8080/api/v1` |
| Navegador o escritorio en el mismo equipo | `http://localhost:8080/api/v1` |
| Teléfono físico | `http://<IP-LAN-del-equipo>:8080/api/v1` |

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

`localhost` en un teléfono apunta al teléfono. Para LAN necesitas conectividad
y que el servidor escuche en una interfaz accesible. La compilación web depende
también del CORS vigente; registra los bloqueos antes de proponer cambios.

VS Code incluye configuraciones de ejecución para API desplegada, emulador
Android local y Chrome local. Selecciona el dispositivo antes de ejecutar.
Los demás destinos requieren sus propias pruebas; que existan sus carpetas
no demuestra compatibilidad validada.

## Verificaciones antes de un PR

```powershell
dart format lib test
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://backend-nursepulse-qfct.onrender.com/api/v1
```

La CI comprueba el formato sin modificarlo. En VS Code hay tasks para
dependencias, análisis y pruebas. Las pruebas automatizadas deben usar datos
ficticios y API simulada; documenta aparte las pruebas manuales de integración.

## Trabajo por ramas

El primer bloque es `chore/mobile-foundation`. Tras integrar su PR, cada sección
parte del `main` actualizado:

```powershell
git switch main
git pull --ff-only origin main
git switch -c feature/auth-validation
```

Comprueba antes `git status` y conserva los cambios en curso. Cada PR incluye
reglas por campo, permisos, pruebas y resultados reales. No declares completo
un módulo cuya integración no se comprobó. Consulta la
[matriz y secuencia de ramas](docs/mobile-baseline.md).

## Integración continua y distribución

En PRs y pushes a `main`, la CI instala Flutter 3.47.2, comprueba formato,
ejecuta análisis y pruebas y construye el APK Android. `Verify Flutter` debe
pasar antes de distribuir.

Solo los pushes a `main` ejecutan después la distribución Firebase y publicación
de Release que ya existían. Firebase requiere el secreto `FIREBASE_TOKEN`;
los PRs no usan ese secreto. Configura la protección de `main` en GitHub para
exigir los checks antes del merge; el YAML no habilita esa protección.

La firma release Android actual usa la clave debug. La firma para publicación
debe definirse antes de entregar a una tienda. La CI actual cubre Android.

## Diferencias conocidas

El registro móvil aún no incluye todos los datos obligatorios del backend;
los roles móviles y varias validaciones requieren los siguientes PRs.
Reportes y recuperación requieren confirmar compatibilidad con la API disponible.
La revisión de bases no acredita que esos módulos ya funcionen.