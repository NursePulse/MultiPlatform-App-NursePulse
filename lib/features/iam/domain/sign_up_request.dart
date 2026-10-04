class RegistrationValidators {
  static String? username(String? value) {
    final text = value?.trim() ?? '';
    return text.length >= 3 && text.length <= 50
        ? null
        : 'El usuario debe tener entre 3 y 50 caracteres.';
  }

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    return text.isNotEmpty &&
            text.length <= 20 &&
            RegExp(r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+(?: [A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*$')
                .hasMatch(text)
        ? null
        : 'Usa solo letras y espacios, con un máximo de 20 caracteres.';
  }

  static String? phone(String? value) =>
      RegExp(r'^[0-9]{9}$').hasMatch(value?.trim() ?? '')
      ? null
      : 'El teléfono debe tener exactamente 9 dígitos.';

  static String? age(String? value) {
    final text = value?.trim() ?? '';
    final number = int.tryParse(text);
    return RegExp(r'^[0-9]+$').hasMatch(text) &&
            number != null &&
            number >= 18 &&
            number <= 90
        ? null
        : 'La edad debe ser un número entero entre 18 y 90.';
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    return text.length <= 254 &&
            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)
        ? null
        : 'Ingresa un correo válido de hasta 254 caracteres.';
  }

  static String? password(String? value) =>
      RegExp(r'^(?=.*[A-Z])(?=.*[0-9])(?=.*[^A-Za-z0-9\s]).{12,20}$')
          .hasMatch(value ?? '')
      ? null
      : 'Usa de 12 a 20 caracteres, una mayúscula, un número y un símbolo.';

  static String? signInPassword(String? value) =>
      value != null &&
          value.trim().isNotEmpty &&
          value.length >= 8 &&
          value.length <= 72
      ? null
      : 'La contraseña de acceso debe tener entre 8 y 72 caracteres.';

  static String? confirmPassword(String? value, String password) =>
      value != null && value.isNotEmpty && value == password
      ? null
      : 'Las contraseñas deben coincidir.';

  static String? role(String? value) =>
      value == 'ROLE_NURSE' || value == 'ROLE_DOCTOR'
      ? null
      : 'Selecciona Enfermería o Medicina.';
}

class SignUpRequest {
  const SignUpRequest._({
    required this.username,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.age,
    required this.email,
    required this.role,
  });

  factory SignUpRequest.fromForm({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String age,
    required String email,
    required String role,
  }) {
    final errors = [
      RegistrationValidators.username(username),
      RegistrationValidators.name(firstName),
      RegistrationValidators.name(lastName),
      RegistrationValidators.phone(phone),
      RegistrationValidators.age(age),
      RegistrationValidators.email(email),
      RegistrationValidators.password(password),
      RegistrationValidators.role(role),
    ].whereType<String>();

    if (errors.isNotEmpty) throw FormatException(errors.first);

    return SignUpRequest._(
      username: username.trim(),
      password: password,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phone: phone.trim(),
      age: int.parse(age.trim()),
      email: email.trim(),
      role: role,
    );
  }

  final String username, password, firstName, lastName, phone, email, role;
  final int age;

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    'age': age,
    'email': email,
    'role': role,
  };
}
