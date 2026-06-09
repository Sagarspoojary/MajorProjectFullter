import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../core/errors/failures.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_service.dart';
import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthService _authService;
  final FirestoreService _firestoreService;

  AuthRepositoryImpl({
    FirebaseAuthService? authService,
    FirestoreService? firestoreService,
  })  : _authService = authService ?? FirebaseAuthService(),
        _firestoreService = firestoreService ?? FirestoreService();

  @override
  Stream<UserModel?> get authStateChanges {
    return _authService.authStateChanges.asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      try {
        final userData = await _firestoreService.getUser(firebaseUser.uid);
        if (userData != null) {
          return userData;
        }
        // Fallcard: If user exists in Firebase but not in Firestore, create default model
        final newUser = UserModel(
          uid: firebaseUser.uid,
          fullName: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
          email: firebaseUser.email ?? '',
          profileImage: firebaseUser.photoURL ?? '',
          provider: 'email',
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
          accountStatus: 'active',
          role: 'user',
        );
        await _firestoreService.createUser(newUser);
        return newUser;
      } catch (_) {
        // Return basic details from Firebase if Firestore fails temporarily
        return UserModel(
          uid: firebaseUser.uid,
          fullName: firebaseUser.displayName ?? 'User',
          email: firebaseUser.email ?? '',
          profileImage: firebaseUser.photoURL ?? '',
          provider: 'email',
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
          accountStatus: 'active',
          role: 'user',
        );
      }
    });
  }

  @override
  Future<UserModel?> getCurrentUserData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return null;
      return await _firestoreService.getUser(user.uid);
    } catch (e) {
      throw Failure('Failed to get current user data: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> signUpWithEmailAndPassword({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthFailure('Registration succeeded but user details were not returned.');
      }

      // Update name inside Firebase Auth
      await firebaseUser.updateDisplayName(fullName);

      final newUser = UserModel(
        uid: firebaseUser.uid,
        fullName: fullName,
        email: email,
        profileImage: '',
        provider: 'email',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        accountStatus: 'active',
        role: 'user',
      );

      // Store in firestore
      await _firestoreService.createUser(newUser);

      // Sign out immediately to prevent auto-login
      await _authService.signOut();

      return newUser;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebaseException(e.code, e.message ?? 'Sign up failed.');
    } catch (e) {
      throw Failure(e.toString());
    }
  }

  @override
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthFailure('Login succeeded but user details were empty.');
      }

      // Check user in firestore, update lastLogin
      final exists = await _firestoreService.userExists(firebaseUser.uid);
      if (exists) {
        await _firestoreService.updateLastLogin(firebaseUser.uid);
        final userModel = await _firestoreService.getUser(firebaseUser.uid);
        if (userModel != null) return userModel;
      }

      // Fallback: create database record if it didn't exist
      final fallbackUser = UserModel(
        uid: firebaseUser.uid,
        fullName: firebaseUser.displayName ?? email.split('@').first,
        email: firebaseUser.email ?? email,
        profileImage: firebaseUser.photoURL ?? '',
        provider: 'email',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        accountStatus: 'active',
        role: 'user',
      );
      await _firestoreService.createUser(fallbackUser);
      return fallbackUser;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebaseException(e.code, e.message ?? 'Sign in failed.');
    } catch (e) {
      throw Failure(e.toString());
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      final credential = await _authService.signInWithGoogle();
      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw const AuthFailure('Google authentication succeeded but user details were empty.');
      }

      final exists = await _firestoreService.userExists(firebaseUser.uid);
      if (exists) {
        await _firestoreService.updateLastLogin(firebaseUser.uid);
        final userModel = await _firestoreService.getUser(firebaseUser.uid);
        if (userModel != null) return userModel;
      }

      // Create new Google Auth user record in Firestore
      final googleUser = UserModel(
        uid: firebaseUser.uid,
        fullName: firebaseUser.displayName ?? 'Google User',
        email: firebaseUser.email ?? '',
        profileImage: firebaseUser.photoURL ?? '',
        provider: 'google',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        accountStatus: 'active',
        role: 'user',
      );

      await _firestoreService.createUser(googleUser);
      return googleUser;
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'sign_in_canceled') {
        throw const AuthFailure('Sign-in cancelled by user.', code: 'sign_in_canceled');
      }
      throw AuthFailure.fromFirebaseException(e.code, e.message ?? 'Google Sign in failed.');
    } catch (e) {
      throw Failure(e.toString());
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebaseException(e.code, e.message ?? 'Password reset failed.');
    } catch (e) {
      throw Failure(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      throw Failure('Log out failed: ${e.toString()}');
    }
  }
}
