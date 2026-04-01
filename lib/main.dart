import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/bootstrap/app_bootstrap.dart';
import 'src/bootstrap/settings_bootstrap.dart';
import 'src/habits/presentation/habits_page.dart';
import 'src/habits/widget/habit_widget_service.dart';
import 'src/pages/app_entry_page.dart';
import 'src/services/habit_notification_service.dart';
import 'src/theme/app_theme.dart';

/// Place this file at: lib/main.dart
///
/// The app now starts through [AppEntryPage], which handles first-launch
/// onboarding before handing off to the existing auth flow.
Future<void> main() async {
  await AppBootstrap.ensureInitialized();
  await HabitWidgetService.initialize();

  runApp(const TaskApp());
}

class TaskApp extends StatefulWidget {
  const TaskApp({super.key});

  @override
  State<TaskApp> createState() => _TaskAppState();
}

class _TaskAppState extends State<TaskApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingLaunch();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handlePendingLaunch();
    }
  }

  Future<void> _handlePendingLaunch() async {
    final destination =
        await HabitNotificationService.consumeLaunchDestination();
    if (!mounted || destination != 'habits') return;
    if (Supabase.instance.client.auth.currentSession == null) return;

    final navigator = _navigatorKey.currentState;
    final context = _navigatorKey.currentContext;
    if (navigator == null || context == null) return;

    navigator.push(
      MaterialPageRoute(builder: (_) => const HabitsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppTheme.themeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder(
          valueListenable: AppTheme.fontFamily,
          builder: (context, font, _) {
            return MaterialApp(
              navigatorKey: _navigatorKey,
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);

                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: mediaQuery.textScaler.clamp(
                      minScaleFactor: 1.0,
                      maxScaleFactor: 1.0,
                    ),
                  ),
                  child: child!,
                );
              },
              title: 'Task Management App',
              theme: AppTheme.lightTheme(font),
              darkTheme: AppTheme.darkTheme(font),
              themeMode: mode,
              home: const SettingsBootstrap(
                child: AppEntryPage(),
              ),
            );
          },
        );
      },
    );
  }
}
