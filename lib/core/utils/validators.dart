/// Form validation helpers.
///
/// Mirrors Expo's `packages/validations/` (Zod schemas) — provides
/// reusable validation functions for form fields, with the same business
/// rules as the shared validation package.
class Validators {
  /// Validates a Chilean RUN / RUT number.
  ///
  /// Rules:
  /// - Must be 7-9 digits followed by an optional dash and verifier digit (0-9 or K).
  /// - Normalizes input (removes dots, uppercase K).
  ///
  /// Returns `null` if valid, or an error message string if invalid.
  static String? run(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El RUN es obligatorio';
    }

    final cleaned = value
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '')
        .toUpperCase();

    final regex = RegExp(r'^\d{7,9}-?[\dK]$');
    if (!regex.hasMatch(cleaned)) {
      return 'RUN inválido — debe tener 7-9 dígitos y dígito verificador';
    }

    return null;
  }

  /// Validates an email address.
  ///
  /// Returns `null` if valid, or an error message if invalid.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El email es obligatorio';
    }

    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Email inválido';
    }

    return null;
  }

  /// Validates a required field.
  ///
  /// Returns `null` if the field has a non-empty value, or an error message.
  static String? required(String? value, {String fieldName = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es obligatorio';
    }
    return null;
  }

  /// Validates a password field.
  ///
  /// Rules:
  /// - Minimum 6 characters.
  /// - Must contain at least one letter and one number.
  ///
  /// Returns `null` if valid, or an error message.
  static String? password(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La contraseña es obligatoria';
    }

    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }

    if (!RegExp(r'(?=.*[a-zA-Z])(?=.*\d)').hasMatch(value)) {
      return 'La contraseña debe contener al menos una letra y un número';
    }

    return null;
  }

  /// Validates that two password fields match.
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.trim().isEmpty) {
      return 'Confirma tu contraseña';
    }

    if (value != password) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }

  /// Validates a phone number (minimum 7 digits, digits only).
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El teléfono es obligatorio';
    }

    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length < 7 || !RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'Teléfono inválido — debe tener al menos 7 dígitos';
    }

    return null;
  }

  /// Validates a numeric value is positive.
  static String? positiveNumber(num? value, {String fieldName = 'El valor'}) {
    if (value == null) {
      return '$fieldName es obligatorio';
    }

    if (value <= 0) {
      return '$fieldName debe ser mayor a 0';
    }

    return null;
  }
}
