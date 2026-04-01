import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';
import 'sign_in_page.dart';
import 'update_password_page.dart';

/// Place this file at: lib/src/pages/auth_gate_page.dart
///
/// Keeps the existing authentication routing intact:
/// - password recovery -> update password
/// - signed-in users -> home
/// - signed-out users -> sign in / sign up flow
class AuthGatePage extends StatelessWidget {
  const AuthGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final supa = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supa.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final event = snapshot.data?.event;
        final session = supa.auth.currentSession;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (event == AuthChangeEvent.passwordRecovery) {
          return const UpdatePasswordPage();
        }

        if (session != null) {
          return const HomePage();
        }

        return const SignInPage();
      },
    );
  }
}
