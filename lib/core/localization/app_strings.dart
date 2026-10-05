import 'package:flutter/material.dart';

/// Only application labels/messages are translated. Callers must leave clinical
/// notes, personal names, identifiers and API wire values untouched.
extension AppStrings on BuildContext {
  String tr(String text) => translateAppText(
    text,
    dependOnInheritedWidgetOfExactType<AppLanguage>()?.locale.languageCode ??
        'es',
  );
  String? validation(String? message) {
    if (message == null) return null;
    String result = message;
    final language =
        dependOnInheritedWidgetOfExactType<AppLanguage>()
            ?.locale
            .languageCode ??
        'es';
    if (language == 'en') {
      for (final field in [
        'Nombre',
        'Apellido',
        'Diagnóstico',
        'Habitación',
        'Cama',
        'Médico tratante',
        'FC',
        'FR',
        'TA sistólica',
        'TA diastólica',
        'Temperatura',
        'Situación',
        'Antecedentes',
        'Evaluación',
        'Recomendación',
      ]) {
        if (result.startsWith('$field ')) {
          result = result.replaceFirst(field, englishMessages[field] ?? field);
          break;
        }
      }
    }
    return translateAppText(result, language);
  }

  String patientStatus(String label) =>
      label == 'Alta' &&
          dependOnInheritedWidgetOfExactType<AppLanguage>()
                  ?.locale
                  .languageCode ==
              'en'
      ? 'Discharged'
      : tr(label);
}

/// Shared by routed pages, dialogs and sheets. Isolated widgets default to ES.
class AppLanguage extends InheritedWidget {
  const AppLanguage({super.key, required this.locale, required super.child});
  final Locale locale;
  @override
  bool updateShouldNotify(AppLanguage oldWidget) => locale != oldWidget.locale;
}

String translateAppText(String text, String language) {
  if (language != 'en') return text;
  final exact = englishMessages[text];
  if (exact != null) return exact;
  for (final template in _templates) {
    final match = template.pattern.firstMatch(text);
    if (match == null) continue;
    return template.translation.replaceAllMapped(
      RegExp(r'\{(\d+)\}'),
      (m) => match.group(int.parse(m[1]!) + 1)!,
    );
  }
  // Unrecognized backend messages remain verbatim.
  return text;
}

class _MessageTemplate {
  _MessageTemplate(String source, this.translation)
    : pattern = RegExp(
        '^${source.split(RegExp(r'\{\d+\}')).map(RegExp.escape).join('([\\s\\S]*?)')}\$',
      );
  final RegExp pattern;
  final String translation;
}

final _templates = englishMessages.entries
    .where((e) => e.key.contains('{0}'))
    .map((e) => _MessageTemplate(e.key, e.value))
    .toList(growable: false);

const englishMessages = <String, String>{
  ..._additionalMessages,
  "Dashboard": "Dashboard",
  "Inicio": "Home",
  "Pacientes": "Patients",
  "Paciente": "Patient",
  "Signos vitales": "Vital signs",
  "Eventos clínicos": "Clinical events",
  "Traspasos SBAR": "SBAR handovers",
  "Alertas": "Alerts",
  "Reportes": "Reports",
  "Auditoría": "Audit",
  "Usuarios": "Users",
  "Suscripciones": "Subscriptions",
  "Más": "More",
  "Cuenta": "Account",
  "Abrir menú": "Open menu",
  "Cerrar sesión": "Sign out",
  "Cambiar idioma": "Change language",
  "Idioma cambiado. No se pudo guardar la preferencia.":
      "Language changed. Could not save your preference.",
  "Administrador": "Administrator",
  "Admin": "Admin",
  "Medicina": "Medical staff",
  "Médico": "Doctor",
  "Enfermera": "Nurse",
  "Enfermera/o": "Nurse",
  "Enfermería": "Nursing",
  "Sin rol válido": "No valid role",
  "Sin rol reconocido": "No recognized role",
  "Resumen administrativo": "Administration overview",
  "Resumen médico": "Medical overview",
  "Resumen de enfermería": "Nursing overview",
  "Sin acceso clínico": "No clinical access",
  "Bienvenido": "Welcome",
  "Ingresa tus credenciales para continuar":
      "Sign in with your clinical account",
  "Usuario": "Username",
  "Contraseña": "Password",
  "Ingresar": "Sign in",
  "¿No tienes cuenta? Regístrate": "Create an account",
  "Crear cuenta": "Create account",
  "Registrarse": "Register",
  "Nombre": "First name",
  "Apellido": "Last name",
  "Nombres": "First name",
  "Apellidos": "Last name",
  "Edad": "Age",
  "Correo electrónico": "Email",
  "Correo": "Email",
  "Rol": "Role",
  "Confirmar contraseña": "Confirm password",
  "Ocultar contraseña": "Hide password",
  "Mostrar contraseña": "Show password",
  "Volver a iniciar sesión": "Back to sign in",
  "Reintentar": "Retry",
  "Ver todo": "View all",
  "Ver detalle": "View details",
  "Guardar": "Save",
  "Cancelar": "Cancel",
  "Listo": "Done",
  "Seleccionar": "Select",
  "Aplicar": "Apply",
  "Editar": "Edit",
  "Eliminar": "Delete",
  "Cerrar": "Close",
  "Limpiar búsqueda": "Clear search",
  "Cerrar aviso": "Dismiss notice",
  "Ocultar aviso": "Dismiss notice",
  "Guardando…": "Saving…",
  "Procesando…": "Processing…",
  "Aplicando…": "Applying…",
  "Generando…": "Generating…",
  "Exportando…": "Exporting…",
  "Pacientes monitoreados": "Monitored patients",
  "Alertas activas": "Active alerts",
  "Alertas críticas": "Critical alerts",
  "Alertas moderadas": "Moderate alerts",
  "Pacientes prioritarios": "Priority patients",
  "Módulos del perfil": "Available modules",
  "Eventos clínicos hoy": "Clinical events today",
  "Controles este mes": "Checks this month",
  "Movimientos de auditoría consultados": "Audit entries retrieved",
  "Seguimiento de pacientes": "Patient monitoring",
  "Alertas activas recientes": "Recent active alerts",
  "Auditoría reciente": "Recent audit entries",
  "Accesos rápidos": "Quick actions",
  "Última actualización: {0}": "Last updated: {0}",
  "No tienes permiso para consultar el Dashboard.":
      "You do not have permission to view the Dashboard.",
  "Se muestran los datos de la última consulta completada.":
      "Showing data from the last completed request.",
  "No hay pacientes registrados.": "No patients registered.",
  "No hay alertas activas.": "No active alerts.",
  "No hay movimientos de auditoría.": "No audit entries.",
  "No se pudo cargar la auditoría: {0}": "Could not load audit entries: {0}",
  "Nuevo paciente": "New patient",
  "Editar paciente": "Edit patient",
  "Dar de alta": "Discharge",
  "Eliminar paciente": "Delete patient",
  "Paciente eliminado.": "Patient deleted.",
  "Paciente dado de alta.": "Patient discharged.",
  "Paciente guardado.": "Patient saved.",
  "Guardar paciente": "Save patient",
  "Buscar por nombre, documento, habitación o estado":
      "Search name, ID, room or status",
  "Cargando pacientes…": "Loading patients…",
  "No se pudo cargar el listado.": "Could not load the list.",
  "No hay coincidencias.": "No matches.",
  "{0} de {1} pacientes": "{0} of {1} patients",
  "Paciente #{0}": "Patient #{0}",
  "¿Eliminar a {0}? Esta acción es permanente.":
      "Delete {0}? This action is permanent.",
  "¿Dar de alta a {0}?": "Discharge {0}?",
  "Hab. {0} · Cama {1}": "Room {0} · Bed {1}",
  "{0} · Documento {1} · {2} años": "{0} · ID {1} · {2} years",
  "Documento": "ID document",
  "Documento:": "ID document:",
  "Fecha de nacimiento": "Date of birth",
  "Fecha de ingreso": "Admission date",
  "Género": "Gender",
  "Masculino": "Male",
  "Femenino": "Female",
  "Otro": "Other",
  "Diagnóstico": "Diagnosis",
  "Diagnóstico:": "Diagnosis:",
  "Habitación": "Room",
  "Habitación:": "Room:",
  "Cama": "Bed",
  "Cama:": "Bed:",
  "Médico tratante": "Attending physician",
  "Médico tratante:": "Attending physician:",
  "Nacimiento:": "Date of birth:",
  "Ingreso:": "Admission date:",
  "Género:": "Gender:",
  "Estado": "Status",
  "Estable": "Stable",
  "En observación": "Under observation",
  "Inestable": "Unstable",
  "Crítico": "Critical",
  "Alta": "High",
  "Baja": "Low",
  "Bajo": "Low",
  "Medio": "Medium",
  "Alto": "High",
  "Moderada": "Moderate",
  "Crítica": "Critical",
  "Sin evaluar": "Not assessed",
  "Sin registros": "No records",
  "Alta hospitalaria": "Discharged",
  "Cargando médicos…": "Loading doctors…",
  "Reintentar médicos": "Retry doctors",
  "No hay médicos disponibles. Un administrador debe asignar ese rol.":
      "No doctors available. An administrator must assign that role.",
  "No tienes permisos para guardar pacientes.":
      "You do not have permission to save patients.",
  "Seguimiento del paciente": "Patient monitoring",
  "Volver a pacientes": "Back to patients",
  "Filtrar signos y eventos": "Filter vital signs and events",
  "Periodo de signos y eventos": "Vital signs and events period",
  "Registrar signos vitales": "Record vital signs",
  "Ver signos vitales": "View vital signs",
  "Cargando historial…": "Loading history…",
  "No hay signos vitales en este periodo.": "No vital signs in this period.",
  "No hay eventos clínicos en este periodo.":
      "No clinical events in this period.",
  "No hay alertas registradas.": "No alerts recorded.",
  "Ver todas las alertas": "View all alerts",
  "Las alertas se muestran sin filtro de fechas.":
      "Alerts are displayed without a date filter.",
  "No tienes permiso para consultar el seguimiento del paciente.":
      "You do not have permission to view patient monitoring.",
  "Signos vitales ({0})": "Vital signs ({0})",
  "Eventos clínicos ({0})": "Clinical events ({0})",
  "Alertas ({0})": "Alerts ({0})",
  "Alertas activas: {0}": "Active alerts: {0}",
  "Último riesgo registrado: {0}": "Latest recorded risk: {0}",
  "Severidad: {0}": "Severity: {0}",
  "Registrado por: {0}": "Recorded by: {0}",
  "Responsable: {0}": "Recorded by: {0}",
  "Registrar alerta": "Create alert",
  "{0} alertas pendientes": "{0} pending alerts",
  "Todas": "All",
  "Críticas": "Critical",
  "Moderadas": "Moderate",
  "Activa": "Active",
  "Atendida": "Attended",
  "Cerrada": "Closed",
  "Atender": "Attend",
  "Pendiente de cierre médico.": "Awaiting medical closure.",
  "No hay alertas en este filtro.": "No alerts match this filter.",
  "Generada: sin información": "Generated: unavailable",
  "Generada: Sin información": "Generated: unavailable",
  "Generada: {0}": "Generated: {0}",
  "Atendida por: {0}": "Attended by: {0}",
  "Atendida: {0}": "Attended: {0}",
  "Cerrada por: {0}": "Closed by: {0}",
  "Cerrada: {0}": "Closed: {0}",
  "Resolución: {0}": "Resolution: {0}",
  "Sin información": "Unavailable",
  "Sin información.": "Unavailable.",
  "Tipo de alerta": "Alert type",
  "Alerta cardiaca": "Cardiac alert",
  "Alerta respiratoria": "Respiratory alert",
  "Alerta neurológica": "Neurological alert",
  "Riesgo de caída": "Fall risk",
  "Alerta de medicación": "Medication alert",
  "Alerta clínica": "Clinical alert",
  "Descripción": "Description",
  "Severidad": "Severity",
  "Paciente disponible": "Available patient",
  "Recargar pacientes": "Reload patients",
  "Reintentar detalle": "Retry details",
  "Alerta guardada.": "Alert saved.",
  "Registrar evento": "Record event",
  "Nuevo evento clínico": "New clinical event",
  "Registrar evento clínico": "Record clinical event",
  "Tipo de evento": "Event type",
  "Título": "Title",
  "Título del evento": "Event title",
  "Emergencia": "Emergency",
  "Cambio de condición": "Condition change",
  "Administración de medicamento": "Medication administration",
  "Procedimiento": "Procedure",
  "Observación": "Observation",
  "Nota de enfermería": "Nursing note",
  "Intervención": "Intervention",
  "Evento": "Event",
  "No hay eventos clínicos registrados.": "No clinical events recorded.",
  "Evento clínico registrado.": "Clinical event recorded.",
  "Nuevo traspaso": "New handover",
  "Traspaso SBAR": "SBAR handover",
  "Receptor": "Recipient",
  "Enfermero receptor": "Receiving nurse",
  "Sin receptor asignado": "No recipient assigned",
  "Enfermero #{0}": "Nurse #{0}",
  "Confirmar recepción": "Acknowledge receipt",
  "Recepción del traspaso confirmada.": "Handover receipt acknowledged.",
  "No hay traspasos SBAR registrados todavía.": "No SBAR handovers yet.",
  "Fecha no disponible": "Date unavailable",
  "Pendiente": "Pending",
  "Recibido": "Acknowledged",
  "Completado": "Completed",
  "Cancelado": "Cancelled",
  "Situación": "Situation",
  "Antecedentes": "Background",
  "Evaluación": "Assessment",
  "Recomendación": "Recommendation",
  "S · Situación": "S · Situation",
  "B · Antecedentes": "B · Background",
  "A · Evaluación": "A · Assessment",
  "R · Recomendación": "R · Recommendation",
  "Guardar traspaso": "Save handover",
  "Cargando signos vitales…": "Loading vital signs…",
  "No se pudo cargar el historial.": "Could not load history.",
  "No hay signos vitales registrados.": "No vital signs recorded.",
  "Guardar signos vitales": "Save vital signs",
  "Signos vitales guardados.": "Vital signs saved.",
  "Registra un paciente para asociar signos vitales.":
      "Register a patient to associate vital signs.",
  "No tienes permiso para registrar signos vitales.":
      "You do not have permission to record vital signs.",
  "FC (lpm)": "HR (bpm)",
  "FR (rpm)": "RR (breaths/min)",
  "TA sistólica (mmHg)": "Systolic BP (mmHg)",
  "TA diastólica (mmHg)": "Diastolic BP (mmHg)",
  "Temperatura (°C)": "Temperature (°C)",
  "FC: {0} lpm · FR: {1} rpm": "HR: {0} bpm · RR: {1} breaths/min",
  "TA: {0}/{1} mmHg": "BP: {0}/{1} mmHg",
  "SpO₂: {0} % · Temperatura: {1} °C": "SpO₂: {0} % · Temperature: {1} °C",
  "Presión: {0}/{1} mmHg · FC: {2} lpm": "BP: {0}/{1} mmHg · HR: {2} bpm",
  "FR: {0} rpm · SpO₂: {1} %": "RR: {0} breaths/min · SpO₂: {1} %",
  "Temperatura: {0} °C · Riesgo: {1}": "Temperature: {0} °C · Risk: {1}",
  "Solo Admin puede administrar usuarios.":
      "Only administrators can manage users.",
  "{0} cuentas": "{0} accounts",
  "{0} (Tú)": "{0} (You)",
  "No puedes cambiar tu propio rol.": "You cannot change your own role.",
  "Cambiar rol": "Change role",
  "Rol de {0}": "Role for {0}",
  "Rol actualizado.": "Role updated.",
  "Actualizar listado": "Refresh list",
  "Pendiente de verificar": "Awaiting verification",
  "No hay usuarios registrados.": "No users registered.",
  "Generar reporte": "Generate report",
  "Generar": "Generate",
  "Tipo": "Type",
  "Desde": "From",
  "Hasta": "To",
  "General": "General",
  "Clínico": "Clinical",
  "Operativo": "Operational",
  "Generado": "Generated",
  "Los reportes se guardan en este dispositivo.":
      "Reports are stored on this device.",
  "{0} reportes": "{0} reports",
  "Aún no generaste ningún reporte.": "You have not generated any reports yet.",
  "Solo Doctor o Admin pueden consultar y generar reportes.":
      "Only doctors and administrators can view and generate reports.",
  "Solo Doctor o Admin pueden generar reportes.":
      "Only doctors and administrators can generate reports.",
  "Pacientes: {0}": "Patients: {0}",
  "Signos vitales: {0}": "Vital signs: {0}",
  "Eventos: {0}": "Events: {0}",
  "SBAR: {0}": "SBAR: {0}",
  "Críticas activas: {0}": "Active critical alerts: {0}",
  "Auditorías: {0}": "Audit entries: {0}",
  "Generado: {0}": "Generated: {0}",
  "Periodo: {0} - {1}": "Period: {0} - {1}",
  "Sin conclusión.": "No conclusion.",
  "Prioridad crítica": "Critical priority",
  "Requiere seguimiento": "Follow-up required",
  "Sin incidencias": "No incidents",
  "Se detectaron {0} alerta(s) crítica(s). Requiere revisión médica prioritaria.":
      "Detected {0} critical alert(s). Priority medical review required.",
  "Existen {0} alerta(s) activa(s). Mantener seguimiento del turno.":
      "There are {0} active alert(s). Continue monitoring during the shift.",
  "Periodo con actividad clínica registrada y sin alertas críticas activas.": "Clinical activity recorded during the period with no active critical alerts.",
  "No se encontraron movimientos clínicos relevantes en el periodo seleccionado.":
      "No relevant clinical activity found in the selected period.",
  "Solo Doctor o Admin pueden consultar Auditoría.":
      "Only doctors and administrators can view Audit.",
  "Consulta de movimientos": "Audit search",
  "{0} movimientos consultados": "{0} entries retrieved",
  "Exportar PDF": "Export PDF",
  "Guardar PDF pendiente": "Save pending PDF",
  "El PDF incluye hasta 200 movimientos del filtro seleccionado.":
      "The PDF includes up to 200 entries for the selected filter.",
  "Filtrar por paciente": "Filter by patient",
  "Todos los pacientes": "All patients",
  "No se pudo cargar el catálogo de pacientes.":
      "Could not load the patient catalogue.",
  "Reintentar pacientes": "Retry patients",
  "Historial del paciente: del más antiguo al más reciente.":
      "Patient history: oldest to newest.",
  "Anterior": "Previous",
  "Siguiente": "Next",
  "PDF guardado.": "PDF saved.",
  "Por {0} · {1}": "By {0} · {1}",
  "Creación": "Create",
  "Actualización": "Update",
  "Eliminación": "Delete",
  "Consulta": "View",
  "Firma": "Sign",
  "Alerta generada": "Alert triggered",
  "Alerta atendida": "Alert attended",
  "Alerta cerrada": "Alert closed",
  "Registro de signos vitales": "Vital signs recorded",
  "Nota clínica agregada": "Clinical note added",
  "Evento clínico": "Clinical event",
  "Reporte": "Report",
  "Orden de medicación": "Medication order",
  "Plan de cuidados": "Care plan",
  "Sistema": "System",
  "Simulación de suscripción. No se realizan cobros reales.":
      "Subscription simulation. No real charges are made.",
  "Pago simulado. No se realizan cobros reales.":
      "Simulated payment. No real charges are made.",
  "Inicia sesión para seleccionar un plan.": "Sign in to select a plan.",
  "Reintentar carga": "Retry loading",
  "Guardar plan pendiente": "Save pending plan",
  "Recomendado": "Recommended",
  "Gratis": "Free",
  "Plan actual": "Current plan",
  "Elegir plan": "Choose plan",
  "Hasta {0} usuarios": "Up to {0} users",
  "\${0}/mes": "\${0}/month",
  "Suscribirse a {0} · USD {1}/mes": "Subscribe to {0} · USD {1}/month",
  "Titular de la tarjeta": "Cardholder name",
  "Email de facturación": "Billing email",
  "Tipo de documento": "Document type",
  "Número de tarjeta": "Card number",
  "Vencimiento (MM/AA)": "Expiry (MM/YY)",
  "MM/AA": "MM/YY",
  "Simular pago USD {0}": "Simulate payment USD {0}",
  "Pago simulado aprobado": "Simulated payment approved",
  "Transacción {0}": "Transaction {0}",
  "Tarjeta: •••• {0}": "Card: •••• {0}",
  "Fecha: {0}": "Date: {0}",
  "Total simulado: USD {0}": "Simulated total: USD {0}",
  "El plan está pendiente de guardado.": "Plan awaiting storage.",
  "Reintentar guardado del plan": "Retry saving plan",
  "Plan guardado en este dispositivo.": "Plan saved on this device.",
  "No se pudo completar el pago simulado.":
      "Could not complete the simulated payment.",
  "El título es obligatorio.": "Title is required.",
  "Selecciona ambas fechas.": "Select both dates.",
  "Selecciona la fecha.": "Select a date.",
  "La fecha inicial no puede ser posterior a la final.":
      "Start date cannot be after end date.",
  "Selecciona un paciente disponible.": "Select an available patient.",
  "Selecciona un paciente válido.": "Select a valid patient.",
  "Selecciona un género.": "Select a gender.",
  "Ya existe un paciente con ese documento.":
      "A patient with that ID document already exists.",
  "La descripción es obligatoria.": "Description is required.",
  "La descripción admite hasta 255 caracteres.":
      "Description allows up to 255 characters.",
  "Número de tarjeta inválido.": "Invalid card number.",
  "Vencimiento inválido.": "Invalid expiry date.",
  "CVV inválido.": "Invalid CVV.",
  "El titular debe tener entre 3 y 80 caracteres.":
      "Cardholder name must have 3 to 80 characters.",
  "Ingresa un correo válido de hasta 120 caracteres.":
      "Enter a valid email with up to 120 characters.",
  "Documento inválido para {0}.": "Invalid ID document for {0}.",
  "El usuario debe tener entre 3 y 50 caracteres.":
      "Username must have 3 to 50 characters.",
  "La contraseña es obligatoria.": "Password is required.",
  "La edad debe ser un número entero entre 18 y 90.":
      "Age must be an integer between 18 and 90.",
  "La presión sistólica debe ser mayor que la diastólica.":
      "Systolic pressure must be higher than diastolic pressure.",
  "{0} es obligatorio.": "{0} is required.",
  "{0} es obligatoria.": "{0} is required.",
  "{0} debe ser un número entero.": "{0} must be an integer.",
  "{0} debe ser un número válido.": "{0} must be a valid number.",
  "{0} debe estar entre {1} y {2}.": "{0} must be between {1} and {2}.",
  "{0} admite hasta {1} caracteres.": "{0} allows up to {1} characters.",
  "{0} debe tener entre {1} y {2} caracteres.":
      "{0} must have {1} to {2} characters.",
  "Usuario o contraseña incorrectos.": "Incorrect username or password.",
  "Credenciales inválidas.": "Invalid credentials.",
  "La conexión con el servidor demoró demasiado. Intenta de nuevo.":
      "The server connection timed out. Try again.",
  "No se pudo conectar con el servidor. Verifica tu conexión.":
      "Could not connect to the server. Check your connection.",
  "No tienes permisos para realizar esta acción.":
      "You do not have permission to perform this action.",
  "El recurso solicitado no existe.": "The requested resource does not exist.",
  "Ya existe un registro con esos datos.":
      "A record with those details already exists.",
  "Inicia sesión de nuevo.": "Sign in again.",
  "Error inesperado.": "Unexpected error.",
};

const _additionalMessages = <String, String>{
  'Seguimiento': 'Monitoring',
  "Volver": "Back",
  "Generada por: {0}": "Generated by: {0}",
  "Ver alertas": "View alerts",
  "Ver auditoría": "View audit",
  "Ver pacientes": "View patients",
  "Ver reportes": "View reports",
  "años": "years",
  "Entero": "Integer",
  "{0}–{1} caracteres": "{0}–{1} characters",
  "{0}–{1} · Entero": "{0}–{1} · Integer",
  "{0} movimientos en total": "{0} total entries",
  "Actividad registrada: {0}": "Recorded activity: {0}",
  "Cuenta creada para {0}.": "Account created for {0}.",
  "Te enviamos un correo para confirmarla. Abre el enlace antes de iniciar sesión.":
      "We sent you a confirmation email. Open the link before signing in.",
  "FC": "HR",
  "FR": "RR",
  "Temperatura": "Temperature",
  "teléfono": "phone",
  "Documento inválido.": "Invalid ID document.",
  "El DNI debe tener 8 dígitos y el RUC 11.":
      "DNI must have 8 digits and RUC 11.",
  "La descripción debe tener entre 5 y 255 caracteres.":
      "Description must have 5 to 255 characters.",
  "El título debe tener entre 4 y 120 caracteres.":
      "Title must have 4 to 120 characters.",
  "Crear cuenta clínica": "Create clinical account",
  "Completa tus datos para solicitar acceso a NursePulse":
      "Enter your details to request access to NursePulse",
  "Creando cuenta…": "Creating account…",
  "Ya tengo cuenta": "I already have an account",
  "Ir a iniciar sesión": "Go to sign in",
  "Equipo clínico": "Clinical team",
  "Rol clínico": "Clinical role",
  "Teléfono": "Phone",
  "12–20 caracteres, una mayúscula, un número y un símbolo.":
      "12–20 characters, an uppercase letter, a number and a symbol.",
  "Usa solo letras y espacios, con un máximo de 20 caracteres.":
      "Use letters and spaces only, up to 20 characters.",
  "El teléfono debe tener exactamente 9 dígitos.":
      "Phone number must have exactly 9 digits.",
  "Ingresa un correo válido de hasta 254 caracteres.":
      "Enter a valid email with up to 254 characters.",
  "Usa de 12 a 20 caracteres, una mayúscula, un número y un símbolo.":
      "Use 12 to 20 characters, an uppercase letter, a number and a symbol.",
  "La contraseña de acceso debe tener entre 8 y 72 caracteres.":
      "Sign-in password must have 8 to 72 characters.",
  "Las contraseñas deben coincidir.": "Passwords must match.",
  "Selecciona Enfermería o Medicina.": "Select Nursing or Medical staff.",
  "Ese correo ya está registrado.": "That email is already registered.",
  "Ese nombre de usuario no está disponible.": "That username is unavailable.",
  "Ese teléfono ya está registrado.":
      "That phone number is already registered.",
  "No se pudo crear la cuenta. Intenta de nuevo.":
      "Could not create the account. Try again.",
  "Ocurrió un error en el servidor. Intenta más tarde.":
      "A server error occurred. Try later.",
  "Ocurrió un error inesperado.": "An unexpected error occurred.",
  "El servidor rechazó los datos. Revisa los campos del formulario.":
      "The server rejected the data. Check the form fields.",
  "El servidor demoró demasiado. Intenta de nuevo.":
      "The server timed out. Try again.",
  "El documento debe tener entre 8 y 20 dígitos.":
      "ID document must have 8 to 20 digits.",
  "Selecciona la fecha de nacimiento.": "Select the date of birth.",
  "El nacimiento debe estar entre 01/01/1930 y hoy.":
      "Date of birth must be between 01/01/1930 and today.",
  "Selecciona la fecha de ingreso.": "Select the admission date.",
  "La fecha de ingreso no puede ser futura.":
      "Admission date cannot be in the future.",
  "Selecciona un género válido.": "Select a valid gender.",
  "{0} solo admite letras y espacios.": "{0} allows letters and spaces only.",
  "El paciente seleccionado no está disponible.":
      "The selected patient is unavailable.",
  "El paciente seleccionado ya no está disponible.":
      "The selected patient is no longer available.",
  "El paciente ya no está disponible. Actualiza el listado.":
      "The patient is no longer available. Refresh the list.",
  "Ya existe un paciente con ese documento. Actualiza el listado.":
      "A patient with that ID document already exists. Refresh the list.",
  "Selecciona ambas fechas del periodo.": "Select both dates for the period.",
  "El fin del periodo no puede ser anterior al inicio.":
      "End of the period cannot be before its start.",
  "El historial contiene datos de otro paciente. Recarga el historial.":
      "History contains data for another patient. Reload history.",
  "El contador del historial no coincide con sus registros.":
      "History count does not match its entries.",
  "Detalle de alerta": "Alert details",
  "Solo Doctor o Admin pueden cerrar alertas.":
      "Only doctors and administrators can close alerts.",
  "No tienes permiso para gestionar alertas.":
      "You do not have permission to manage alerts.",
  "No tienes permiso para consultar alertas.":
      "You do not have permission to view alerts.",
  "No tienes permiso para registrar alertas.":
      "You do not have permission to create alerts.",
  "No tienes permiso para consultar el directorio.":
      "You do not have permission to view the directory.",
  "No tienes permiso para consultar eventos clínicos.":
      "You do not have permission to view clinical events.",
  "No tienes permiso para consultar pacientes.":
      "You do not have permission to view patients.",
  "No tienes permiso para consultar signos vitales.":
      "You do not have permission to view vital signs.",
  "No tienes permiso para registrar eventos clínicos.":
      "You do not have permission to record clinical events.",
  "No tienes permiso para consultar traspasos.":
      "You do not have permission to view handovers.",
  "No tienes permiso para registrar o recibir traspasos.":
      "You do not have permission to create or acknowledge handovers.",
  "No tienes permiso para registrar traspasos.":
      "You do not have permission to create handovers.",
  "Sin permiso para consultar Auditoría.": "No permission to view Audit.",
  "Selecciona un tipo de alerta válido.": "Select a valid alert type.",
  "Selecciona una severidad válida.": "Select a valid severity.",
  "Selecciona un identificador válido.": "Select a valid ID.",
  "Selecciona {0} válido.": "Select a valid {0}.",
  "El usuario debe tener 1–120 caracteres.":
      "Username must have 1–120 characters.",
  "Las notas deben tener 1–255 caracteres.":
      "Notes must have 1–255 characters.",
  "Estado: {0}": "Status: {0}",
  "Para: {0}": "To: {0}",
  "Recibido por: {0}": "Received by: {0}",
  "Tipo: {0}": "Type: {0}",
  "Severidad de alerta desconocida: {0}": "Unknown alert severity: {0}",
  "Estado de alerta desconocido: {0}": "Unknown alert status: {0}",
  "La alerta se guardó, pero no se pudo confirmar su auditoría.":
      "Alert saved, but its audit entry could not be confirmed.",
  "El cambio de alerta fue confirmado, pero no se pudo leer el detalle. Recarga; no repitas la operación.": "Alert change confirmed, but details could not be read. Reload; do not repeat the operation.",
  "La API devolvió otra alerta.": "The API returned a different alert.",
  "Respuesta de alerta inconsistente.": "Inconsistent alert response.",
  "Nuevo traspaso SBAR": "New SBAR handover",
  "Detalle del traspaso SBAR": "SBAR handover details",
  "Entrega de turno SBAR": "SBAR shift handover",
  "Personal receptor": "Receiving staff",
  "Recargar receptores": "Reload recipients",
  "No hay receptores Nurse distintos del usuario actual.":
      "No receiving nurses other than the current user are available.",
  "Selecciona un receptor Nurse disponible.":
      "Select an available receiving nurse.",
  "Selecciona un receptor distinto del usuario actual.":
      "Select a recipient other than the current user.",
  "El receptor seleccionado ya no es un usuario Nurse disponible.":
      "The selected recipient is no longer an available nurse.",
  "Notas de atención": "Care notes",
  "S — Situación": "S — Situation",
  "B — Antecedentes": "B — Background",
  "A — Evaluación": "A — Assessment",
  "R — Recomendación": "R — Recommendation",
  "El traspaso fue confirmado, pero no se pudo leer el detalle. Recarga el listado; no vuelvas a registrarlo.": "Handover confirmed, but details could not be read. Reload the list; do not create it again.",
  "La recepción fue confirmada, pero no se pudo leer el detalle. Recarga el listado; no repitas la recepción.": "Receipt confirmed, but details could not be read. Reload the list; do not acknowledge it again.",
  "La respuesta no corresponde al traspaso solicitado.":
      "The response does not match the requested handover.",
  "El detalle no corresponde al traspaso solicitado.":
      "Details do not match the requested handover.",
  "Complicación": "Complication",
  "Medicación administrada": "Medication administered",
  "Procedimiento realizado": "Procedure performed",
  "Evento clínico guardado.": "Clinical event saved.",
  "Selecciona un tipo de evento válido.": "Select a valid event type.",
  "El título debe tener entre 1 y 255 caracteres.":
      "Title must have 1 to 255 characters.",
  "El evento se guardó, pero no se pudo confirmar la alerta. Revisa Alertas.":
      "Event saved, but its alert could not be confirmed. Check Alerts.",
  "El evento se guardó, pero no se pudo confirmar su auditoría.":
      "Event saved, but its audit entry could not be confirmed.",
  "Revisa el aviso en Alertas; no repitas el evento.":
      "Check the notice in Alerts; do not repeat the event.",
  "Buscar paciente, documento o riesgo": "Search patient, ID or risk",
  "TA diastólica": "Diastolic BP",
  "TA sistólica": "Systolic BP",
  "Los signos se guardaron, pero no se pudo confirmar su auditoría.":
      "Vital signs saved, but their audit entry could not be confirmed.",
  "Los signos se guardaron, pero no se pudo confirmar la alerta. Revisa el aviso en Alertas; no repitas los signos.": "Vital signs saved, but their alert could not be confirmed. Check the notice in Alerts; do not repeat the vital signs.",
  "Selecciona un tipo de reporte válido.": "Select a valid report type.",
  "Reporte guardado. No se pudo completar su auditoría; no vuelvas a generarlo por este aviso.": "Report saved. Its audit could not be completed; do not regenerate it because of this notice.",
  "No se pudieron leer los reportes guardados. Reintenta.":
      "Could not read stored reports. Try again.",
  "No se pudo guardar el reporte en este dispositivo. Reintenta.":
      "Could not save the report on this device. Try again.",
  "Reporte local inválido.": "Invalid local report.",
  "Sin alertas activas": "No active alerts",
  "{0} · {1} · por {2}": "{0} · {1} · by {2}",
  "{0} - {1} · por {2}": "{0} - {1} · by {2}",
  "Selecciona una página disponible de la auditoría general.":
      "Select an available audit page.",
  "Espera a que se complete la consulta antes de exportar.":
      "Wait for the query to finish before exporting.",
  "Espera a que termine la exportación antes de cambiar el filtro.":
      "Wait for export to finish before changing the filter.",
  "El documento PDF está incompleto o es inválido.":
      "The PDF document is incomplete or invalid.",
  "El guardado de PDF no está disponible en esta plataforma.":
      "Saving PDFs is unavailable on this platform.",
  "Guardado cancelado. Puedes elegir un destino de nuevo.":
      "Save cancelled. You can choose a destination again.",
  "No se pudo confirmar el guardado del PDF.":
      "Could not confirm that the PDF was saved.",
  "No se pudo guardar el PDF. Puedes volver a elegir un destino.":
      "Could not save the PDF. You can choose a destination again.",
  "La API no devolvió un documento PDF válido.":
      "The API did not return a valid PDF document.",
  "El historial contiene auditoría de otro paciente.":
      "History contains audit entries for another patient.",
  "El historial de auditoría no corresponde al paciente.":
      "Audit history does not match the patient.",
  "La auditoría no contiene un ID y fecha válidos.":
      "The audit entry does not contain a valid ID and date.",
  "La página de auditoría contiene registros duplicados o excede su tamaño.":
      "The audit page contains duplicate entries or exceeds its size.",
  "La página no puede ser negativa y su tamaño debe estar entre 1 y 200.":
      "Page cannot be negative and size must be between 1 and 200.",
  "La API no devolvió una página válida de auditoría.":
      "The API did not return a valid audit page.",
  "Página {0} de {1}": "Page {0} of {1}",
  "Total: {0} movimientos": "Total: {0} entries",
  "Mostrando {0} de {1} movimientos": "Showing {0} of {1} entries",
  "Selecciona un rol Nurse, Doctor o Admin.":
      "Select a Nurse, Doctor or Admin role.",
  "El usuario o rol ya no está disponible. Actualiza el listado.":
      "The user or role is no longer available. Refresh the list.",
  "El usuario ya no está disponible. Actualiza el listado.":
      "The user is no longer available. Refresh the list.",
  "El cambio fue confirmado, pero no se pudo verificar el rol solicitado. Actualiza el listado; no repitas el cambio.": "Change confirmed, but the requested role could not be verified. Refresh the list; do not repeat the change.",
  "El cambio fue confirmado. Actualiza el listado antes de modificarlo de nuevo.":
      "Change confirmed. Refresh the list before changing it again.",
  "El cambio se guardó, pero no se pudo confirmar su auditoría.":
      "Change saved, but its audit entry could not be confirmed.",
  "La lista contiene usuarios duplicados.":
      "The list contains duplicate users.",
  "La API devolvió otro usuario. Recarga el listado.":
      "The API returned a different user. Reload the list.",
  "La API devolvió un usuario sin nombre.":
      "The API returned a user without a username.",
  "Esencial": "Essential",
  "Profesional": "Professional",
  "Empresarial": "Enterprise",
  "Lo justo para empezar a digitalizar el seguimiento clínico.":
      "Start digitizing clinical monitoring.",
  "Para equipos clínicos que necesitan traspasos y reportes.":
      "For clinical teams that need handovers and reports.",
  "Para instituciones con necesidades de auditoría y soporte prioritario.":
      "For institutions that need audit and priority support.",
  "Gestión de pacientes": "Patient management",
  "Alertas clínicas": "Clinical alerts",
  "Soporte prioritario": "Priority support",
  "Completa primero el pago simulado del plan.":
      "Complete the plan's simulated payment first.",
  "Espera o guarda el plan pendiente antes de enviar otro pago simulado.": "Wait or save the pending plan before submitting another simulated payment.",
  "Guarda primero el plan pendiente antes de seleccionar otro.":
      "Save the pending plan before selecting another.",
  "Selecciona otro plan de pago.": "Select another paid plan.",
  "No se pudo cargar el plan guardado. Reintenta.":
      "Could not load the saved plan. Try again.",
  "No se pudo completar el pago simulado. Reintenta.":
      "Could not complete the simulated payment. Try again.",
  "No se pudo guardar el plan. Reintenta el guardado; el pago simulado no se repetirá.": "Could not save the plan. Retry saving; the simulated payment will not be repeated.",
  "No se pudo verificar el recibo simulado.":
      "Could not verify the simulated receipt.",
  "La sesión cambió. Inicia el registro de nuevo.":
      "Session changed. Start recording again.",
  "La sesión cambió. Inicia la operación de nuevo.":
      "Session changed. Start the operation again.",
  "La sesión cambió. Recarga Auditoría.": "Session changed. Reload Audit.",
  "La sesión cambió. Recarga Reportes.": "Session changed. Reload Reports.",
  "La sesión cambió. Recarga Suscripciones.":
      "Session changed. Reload Subscriptions.",
  "La sesión cambió. Recarga el Dashboard.":
      "Session changed. Reload Dashboard.",
  "La sesión cambió. Recarga el listado.": "Session changed. Reload the list.",
  "La sesión cambió. Recarga los traspasos.":
      "Session changed. Reload handovers.",
  "La sesión cambió después del cambio confirmado.":
      "Session changed after the confirmed change.",
  "La sesión no contiene un usuario válido. Inicia sesión de nuevo.":
      "Session does not contain a valid user. Sign in again.",
  "La respuesta no contiene una sesión válida.":
      "Response does not contain a valid session.",
  "La API no devolvió un usuario con roles válidos.":
      "The API did not return a user with valid roles.",
  "La API devolvió un identificador inválido.":
      "The API returned an invalid ID.",
  "El servidor confirmó la creación sin devolver un identificador válido.":
      "The server confirmed creation without returning a valid ID.",
  "La API devolvió otro paciente. Recarga el detalle.":
      "The API returned a different patient. Reload details.",
  "Espera a que termine el registro en curso.": "Wait for recording to finish.",
  "Espera a que termine la operación en curso.":
      "Wait for the operation to finish.",
  "Ya hay una operación en curso.": "An operation is already in progress.",
  "La operación se canceló antes de guardar.":
      "The operation was cancelled before saving.",
  "Debes confirmar tu correo antes de iniciar sesión. Revisa tu bandeja de entrada.":
      "Confirm your email before signing in. Check your inbox.",
};
