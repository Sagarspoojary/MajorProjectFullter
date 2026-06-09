import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Stream of firebase User changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Get current firebase user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Sign Up with Email and Password
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign In with Email and Password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign In with Google
  Future<UserCredential> signInWithGoogle() async {
    // 1. Ensure the Google Sign-in plugin is initialized
    try {
      await GoogleSignIn.instance.initialize();
    } catch (_) {
      // Ignore if already initialized
    }

    // 2. Trigger the Google Authentication flow
    final googleUser = await GoogleSignIn.instance.authenticate();

    // 3. Obtain the auth details from the request
    final googleAuth = googleUser.authentication;

    // 4. Create a new credential using the ID Token
    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    // 5. Once signed in, return the UserCredential
    return await _firebaseAuth.signInWithCredential(credential);
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Ignore errors if Google Sign In wasn't active
    }
  }
}
