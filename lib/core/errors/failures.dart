class Failure {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  String toString() => message;
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});

  factory AuthFailure.fromFirebaseException(String code, String defaultMessage) {
    switch (code) {
      case 'invalid-email':
        return const AuthFailure('The email address is badly formatted.', code: 'invalid-email');
      case 'user-disabled':
        return const AuthFailure('This user account has been disabled.', code: 'user-disabled');
      case 'user-not-found':
        return const AuthFailure('No user found with this email.', code: 'user-not-found');
      case 'wrong-password':
        return const AuthFailure('Incorrect password. Please try again.', code: 'wrong-password');
      case 'email-already-in-use':
        return const AuthFailure('An account already exists with this email address.', code: 'email-already-in-use');
      case 'operation-not-allowed':
        return const AuthFailure('Operation not allowed. Contact administrator.', code: 'operation-not-allowed');
      case 'weak-password':
        return const AuthFailure('The password is too weak. Please use a stronger password.', code: 'weak-password');
      case 'network-request-failed':
        return const AuthFailure('Network error. Please check your internet connection.', code: 'network-request-failed');
      case 'invalid-credential':
        return const AuthFailure('Invalid credentials provided.', code: 'invalid-credential');
      case 'account-exists-with-different-credential':
        return const AuthFailure('An account already exists with a different credential (e.g. Google).', code: 'account-exists-with-different-credential');
      case 'requires-recent-login':
        return const AuthFailure('Please re-authenticate before performing this operation.', code: 'requires-recent-login');
      default:
        return AuthFailure(defaultMessage, code: code);
    }
  }
}
