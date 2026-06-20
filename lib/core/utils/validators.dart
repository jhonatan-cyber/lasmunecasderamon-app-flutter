




class Validators {
  
  
  
  
  
  
  
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

  
  
  
  static String? required(String? value, {String fieldName = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es obligatorio';
    }
    return null;
  }

  
  
  
  
  
  
  
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

  
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.trim().isEmpty) {
      return 'Confirma tu contraseña';
    }

    if (value != password) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }

  
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
