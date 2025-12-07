import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/pages/home_page.dart';
import 'src/pages/sign_in_page.dart';
import 'src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    // You can include authOptions if you want, but it's optional
    // authOptions: const FlutterAuthClientOptions(
    //   autoRefreshToken: true, // this is true by default
    // ),
  );

  runApp(const TaskApp());
}

class TaskApp extends StatelessWidget {
  const TaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppTheme.themeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder(
          valueListenable: AppTheme.fontFamily,
          builder: (context, font, _) {
            return MaterialApp(
              title: 'Task Management App',
              theme: AppTheme.lightTheme(font),
              darkTheme: AppTheme.darkTheme(font),
              themeMode: mode,
              home: const AuthGate(),
            );
          },
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final supa = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supa.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supa.auth.currentSession;

        // Optional loading state for first build
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (session != null && session.user != null) {
          // ✅ User stays logged in across app restarts
          return const HomePage();
        } else {
          return const SignInPage();
        }
      },
    );
  }
}
