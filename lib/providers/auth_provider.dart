import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/errors/failures.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/auth_repository_impl.dart';

// Class to hold Auth State for the UI
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isPasswordResetSent;
  final bool isSignUpSuccessful;

  AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isPasswordResetSent = false,
    this.isSignUpSuccessful = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool? isPasswordResetSent,
    bool? isSignUpSuccessful,
    bool clearError = false,
    bool clearResetSent = false,
    bool clearSignUpSuccess = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isPasswordResetSent: clearResetSent ? false : (isPasswordResetSent ?? this.isPasswordResetSent),
      isSignUpSuccessful: clearSignUpSuccess ? false : (isSignUpSuccessful ?? this.isSignUpSuccessful),
    );
  }
}

// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

// Stream Provider to listen to auth state changes from Firebase
final authStateChangesProvider = StreamProvider<UserModel?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// NotifierProvider for UI interaction and state management
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<UserModel?>? _authSubscription;

  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);
    
    // Listen to Firebase Auth state stream changes to update user object reactively
    _authSubscription = repository.authStateChanges.listen(
      (user) {
        state = state.copyWith(user: user, isLoading: false, clearError: true);
      },
      onError: (error) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error is Failure ? error.message : error.toString(),
        );
      },
    );

    // Register a callback to cancel the subscription when provider is disposed
    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    return AuthState();
  }

  // Clear current error message from state
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // Clear the password reset success indicator
  void clearResetSent() {
    state = state.copyWith(clearResetSent: true);
  }

  // Clear the sign up success indicator
  void clearSignUpSuccess() {
    state = state.copyWith(clearSignUpSuccess: true);
  }

  // Email and Password Registration
  Future<void> signUpWithEmailAndPassword({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, isSignUpSuccessful: false);
    _authSubscription?.pause();
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.signUpWithEmailAndPassword(
        fullName: fullName,
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false, isSignUpSuccessful: true, user: null);
    } on Failure catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    } finally {
      _authSubscription?.resume();
    }
  }

  // Email and Password Sign In
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(user: user, isLoading: false);
    } on Failure catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // Google Sign In
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.signInWithGoogle();
      state = state.copyWith(user: user, isLoading: false);
    } on Failure catch (e) {
      if (e.code == 'sign_in_canceled') {
        state = state.copyWith(isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, errorMessage: e.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // Send Password Reset Link
  Future<void> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, clearError: true, isPasswordResetSent: false);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.sendPasswordResetEmail(email);
      state = state.copyWith(isLoading: false, isPasswordResetSent: true);
    } on Failure catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // Log Out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.signOut();
      state = AuthState(); // Reset auth state to initial defaults
    } on Failure catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
