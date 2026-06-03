import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'services/firestore_service.dart';
import 'services/theme_provider.dart';

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF5F6FA),
  cardColor: Colors.white,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4A90E2),
    brightness: Brightness.light,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF4A90E2),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: const Color(0xFF4A90E2).withValues(alpha: 0.15),
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF121212),
  cardColor: const Color(0xFF1E1E1E),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4A90E2),
    brightness: Brightness.dark,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1A1A2E),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: const Color(0xFF1A1A2E),
    indicatorColor: const Color(0xFF4A90E2).withValues(alpha: 0.3),
  ),
);

class MyApp extends StatelessWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return ListenableBuilder(

      listenable: ThemeProvider.instance,

      builder: (context, _) {

        return MaterialApp(

          debugShowCheckedModeBanner: false,

          title: 'Kiosco Escolar',

          theme: lightTheme,

          darkTheme: darkTheme,

          themeMode: ThemeProvider.instance.themeMode,

          home: const LoginScreen(),
        );
      },
    );
  }
}

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  try {
    await FirestoreService.instance.seedFromLocal();
  } catch (e) {
    debugPrint('Seed/migration error: $e');
  }

  runApp(
    const MyApp(),
  );
}
