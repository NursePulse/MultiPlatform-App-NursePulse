# Verificación del primer bloque de bases

Rama: chore/mobile-foundation.
Base móvil revisada: 44cc354.
Fecha de preparación: 2026-10-03.

Estado: preparado localmente; pendiente de ejecución Flutter
y revisión remota antes del merge.

## Cambios

- CI en PRs y pushes a main: formato, análisis, pruebas y APK.
- Flutter fijado a 3.47.2, correspondiente al commit de .metadata.
- Distribución Firebase/Release separada del job de verificación.
- README operativo y configuraciones compartidas de VS Code.
- Matriz de paridad y plantilla de PR.
- Normalización de formato Dart; sin implementación de formularios nuevos.

## Resultados del entorno que preparó los cambios

| Check | Resultado |
| --- | --- |
| git diff --check | Aprobado |
| Parseo de launch/tasks JSON y workflow YAML | Aprobado |
| Revisión estática de separación de distribución | Aprobado |
| Dart formatter sobre 62 archivos | Ejecutado; segunda pasada sin cambios |
| Dependencias de la aplicación | No resueltas |
| flutter analyze | No ejecutado |
| flutter test | No ejecutado |
| Compilación APK | No ejecutada |
| CI en GitHub | No ejecutada |
| Integración manual con API real | No ejecutada |

La ejecución de Flutter fue bloqueada por la revisión automática al detectar
una consulta a metadatos del entorno. El formatter Dart se ejecutó directamente
sobre archivos locales y advirtió que no podía resolver flutter_lints porque
las dependencias de la app no estaban instaladas.

El formato aprobado no sustituye el análisis, las pruebas ni la compilación.

## Comprobaciones en el equipo de desarrollo

Ejecutar los comandos del README y registrar aquí sus resultados reales.
Resolver las incidencias antes del merge.

La rama de autenticación comienza después del merge de este bloque.