# Registro y acceso

Rama: feature/auth-validation, creada desde main después del PR #4.

## Alcance

- Registro envía los ocho campos requeridos por la API.
- Valida usuario, nombres, teléfono, edad, correo, contraseña y confirmación.
- Registro público permite ROLE_NURSE y ROLE_DOCTOR.
- Reconoce ROLE_ADMIN en sesiones existentes.
- Roles desconocidos no reciben permisos por defecto.
- Formularios inválidos no envían solicitudes.
- Evita doble envío y conserva datos ante errores.
- HTTP 400 muestra el detalle disponible.
- Menús y rutas restringidas usan los roles del usuario.
- Acceso valida usuario 3–50 y contraseña 8–72.
- Backend y web sin modificaciones.

## Compatibilidad

La API exige edad entre 18 y 120, aunque la web permite una edad menor.
Se mantiene el máximo web de 20 caracteres para nombres y apellidos.
Los nombres usan grupos de letras separados por un espacio, según la API.

## Validación

45 comprobaciones de dominio ejecutadas con Dart: aprobadas.
Formato Dart aplicado.

Pendiente para estos cambios:
- flutter analyze
- flutter test
- Compilación Android en CI
- Prueba de registro, acceso y roles contra la API con el tester

Los permisos de acciones específicas de otros módulos se completarán
en sus respectivos PRs.