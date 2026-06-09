class Validators {
  // Email validator regex
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
  );

  // Validate Name
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name cannot be empty';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  // Validate Email
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email cannot be empty';
    }
    if (!_emailRegExp.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // Validate Password Strength
  // Minimum 8 characters, at least 1 uppercase, 1 lowercase, 1 number, and 1 special character.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password cannot be empty';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'[!@#\$&*~^%()_+={}\[\]|\\:;"<>,.?/-]').hasMatch(value)) {
      return 'Password must contain at least one special character (e.g., !@#\$&*)';
    }
    return null;
  }

  // Validate Confirm Password
  static String? validateConfirmPassword(String? confirmPassword, String? password) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Please confirm your password';
    }
    if (confirmPassword != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  // Password Strength Score for visual meter
  // Returns value between 0.0 and 1.0 representing strength level
  static double getPasswordStrength(String value) {
    if (value.isEmpty) return 0.0;
    
    double strength = 0.0;
    
    // Length check
    if (value.length >= 6) strength += 0.2;
    if (value.length >= 8) strength += 0.2;
    
    // Complexity checks
    if (RegExp(r'[A-Z]').hasMatch(value)) strength += 0.15;
    if (RegExp(r'[a-z]').hasMatch(value)) strength += 0.15;
    if (RegExp(r'[0-9]').hasMatch(value)) strength += 0.15;
    if (RegExp(r'[!@#\$&*~^%()_+={}\[\]|\\:;"<>,.?/-]').hasMatch(value)) strength += 0.15;
    
    return strength;
  }

  // Get string label for strength
  static String getPasswordStrengthLabel(double strength) {
    if (strength <= 0.2) return 'Very Weak';
    if (strength <= 0.4) return 'Weak';
    if (strength <= 0.6) return 'Fair';
    if (strength <= 0.8) return 'Strong';
    return 'Very Strong';
  }
}
