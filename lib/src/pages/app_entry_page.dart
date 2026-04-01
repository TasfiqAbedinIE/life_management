import 'package:flutter/material.dart';

import 'auth_gate_page.dart';
import '../services/onboarding_preferences.dart';
import 'onboarding_page.dart';

/// Place this file at: lib/src/pages/app_entry_page.dart
///
/// This page decides where the app should go on startup:
/// - onboarding for first launch
/// - existing login/signup flow for later launches
class AppEntryPage extends StatefulWidget {
  const AppEntryPage({super.key});

  @override
  State<AppEntryPage> createState() => _AppEntryPageState();
}

class _AppEntryPageState extends State<AppEntryPage> {
  late final Future<bool> _hasSeenOnboardingFuture;

  @override
  void initState() {
    super.initState();
    _hasSeenOnboardingFuture = OnboardingPreferences.hasSeenOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<bool>(
      future: _hasSeenOnboardingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF2F5FF),
                    Color(0xFFE7ECFF),
                    Color(0xFFF9FBFF),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 72,
                      width: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E2E78).withValues(
                              alpha: 0.14,
                            ),
                            blurRadius: 30,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.dashboard_customize_rounded,
                        size: 34,
                        color: Color(0xFF3146A8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Preparing your workspace...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF24345F),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.data == true) {
          return const AuthGatePage();
        }

        return const OnboardingPage();
      },
    );
  }
}
