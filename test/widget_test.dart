import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:major_project_flutter/main.dart';
import 'package:major_project_flutter/models/user_model.dart';
import 'package:major_project_flutter/repositories/auth_repository.dart';
import 'package:major_project_flutter/providers/auth_provider.dart';

// A mock repository to decouple tests from Firebase SDK
class FakeAuthRepository implements AuthRepository {
  @override
  Stream<UserModel?> get authStateChanges => Stream.value(null);

  @override
  Future<UserModel?> getCurrentUserData() async => null;

  @override
  Future<UserModel> signUpWithEmailAndPassword({
    required String fullName,
    required String email,
    required String password,
  }) async {
    return UserModel.empty();
  }

  @override
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return UserModel.empty();
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    return UserModel.empty();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('Splash Screen smoke test', (WidgetTester tester) async {
    // Build our app overriding the Firebase repository with our mock double
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: const SheGuardApp(),
      ),
    );

    // Verify that the App name and custom painters are loaded on the Splash Screen
    expect(find.text('SHEGUARD AI'), findsOneWidget);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(2));

    // Simulate elapsed time to resolve the pending Future.delayed timer
    await tester.pump(const Duration(seconds: 3));
  });
}
