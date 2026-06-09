import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';

void main() async {
  // Ensure engine bindings are active
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase using native files
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase Initialization Error: $e');
  }

  runApp(
    // ProviderScope is required for Riverpod state stores
    const ProviderScope(
      child: SheGuardApp(),
    ),
  );
}

class SheGuardApp extends StatelessWidget {
  const SheGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHEGUARD AI',
      debugShowCheckedModeBanner: false,
      
      // Theme configs
      theme: AppTheme.darkTheme, // Slate/Midnight theme
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Defaulting to Dark mode for futuristic cyber feel

      // Navigation
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
