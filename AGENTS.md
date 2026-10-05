# Instrucciones de trabajo de NursePulse

## Alcance y conservación

- Comunicar avances y resultados en español, de forma breve.
- Completar la paridad Flutter con la web por fases, conservando Riverpod,
  GoRouter y domain/application/infrastructure/presentation.
- Revisar rama, estado de Git, documentación y cambios existentes antes de editar.
- Conservar el trabajo local y las funciones que ya funcionan.
- Backend sin modificaciones; usar únicamente contratos y endpoints existentes.
- No actualizar SDK, dependencias ni herramientas sin una necesidad concreta.
- Registro de usuarios: edad entera 18–90 inclusive; no aplicar a pacientes.
- Pruebas con APIs simuladas y datos ficticios, sin credenciales ni datos clínicos reales.

## Verificación y publicación por fase

1. Confirmar que la fase anterior está integrada en `test` remoto.
2. Partir de `test` actualizado y trabajar en una rama por sección.
3. Implementar y verificar reglas, permisos, errores y paridad web/API.
4. Ejecutar `dart format lib test`, `flutter analyze`, `flutter test`,
   `git diff --check` y compilación del APK release. Se puede usar `--no-pub`
   cuando las dependencias ya estén resueltas y no hayan cambiado.
5. Si las comprobaciones pasan, revisar los archivos que entrarán al commit,
   hacer commit y push de la rama sin pedir otra confirmación. Esta publicación
   está autorizada por el usuario; excluir cambios ajenos a la fase.
6. Dar un resumen de cambios, resultados realmente comprobados, APK,
   commit/rama publicados, pendientes y título/descripcion del PR hacia `test`.
7. Si ya existe un PR, comprobar sus checks sobre el último commit publicado.
   Un check pendiente o de un commit anterior no acredita el commit actual.
8. El tester revisa el APK y la integración manual. No declarar funcionamiento
   en dispositivo o contra producción basándose solo en pruebas simuladas.
9. No hacer merge ni abrir un PR sin indicación del usuario. La siguiente fase
   comienza después de confirmar el merge de la anterior en `test`.
10. `test` pasa a `main` después de la revisión y autorización del usuario.

Si una comprobación falla, resolver el problema dentro del alcance y repetir
las comprobaciones afectadas antes de publicar. Informar los bloqueos reales.
Una falla posterior de auditoría/alerta no debe repetir una escritura confirmada.

Estas instrucciones sustituyen la petición anterior de esperar autorización
adicional para cada commit y push; el merge sigue requiriendo autorización.
