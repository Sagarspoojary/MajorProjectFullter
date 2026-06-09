import '../models/user_model.dart';

abstract class AuthRepository {
  /// Stream to listen to real-time authentication state changes
  Stream<UserModel?> get authStateChanges;

  /// Retrieves the current authenticated user's profile details
  Future<UserModel?> getCurrentUserData();

  /// User Registration using Name, Email, and Password
  Future<UserModel> signUpWithEmailAndPassword({
    required String fullName,
    required String email,
    required String password,
  });

  /// User Login using Email and Password
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Google Authentication Sign-In Flow
  Future<UserModel> signInWithGoogle();

  /// Send password reset link to user's registered email
  Future<void> sendPasswordResetEmail(String email);

  /// Signs the current user out of their session
  Future<void> signOut();
}
