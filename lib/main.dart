import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/bootstrap/app_bootstrap.dart';
import 'src/bootstrap/settings_bootstrap.dart';
import 'src/coupled/coupled_request_page.dart';
import 'src/coupled/couple_repository.dart';
import 'src/coupled/love_pill_page.dart';
import 'src/habits/presentation/habits_page.dart';
import 'src/habits/widget/habit_widget_service.dart';
import 'src/pages/app_entry_page.dart';
import 'src/services/habit_notification_service.dart';
import 'src/services/push_notification_service.dart';
import 'src/theme/app_theme.dart';

/// Place this file at: lib/main.dart
///
/// The app now starts through [AppEntryPage], which handles first-launch
/// onboarding before handing off to the existing auth flow.
Future<void> main() async {
  await AppBootstrap.ensureInitialized();
  await HabitWidgetService.initialize();
  PushNotificationService.registerBackgroundHandler();

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
    unawaited(PushNotificationService.initialize(_navigatorKey));
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
    if (!mounted ||
        (destination != 'habits' &&
            destination != 'coupled' &&
            destination != 'love_pills')) {
      return;
    }
    if (Supabase.instance.client.auth.currentSession == null) return;

    final navigator = _navigatorKey.currentState;
    final context = _navigatorKey.currentContext;
    if (navigator == null || context == null) return;

    Widget page;
    if (destination == 'love_pills') {
      final repo = CoupleRepository(Supabase.instance.client);
      final couple = await repo.fetchExistingCouple();
      final coupleId = couple?['id']?.toString();
      page = couple?['status'] == 'active' && coupleId != null
          ? LovePillPage(coupleId: coupleId, repo: repo)
          : const CoupledRequestPage();
    } else {
      page = destination == 'coupled'
          ? const CoupledRequestPage()
          : const HabitsPage();
    }

    navigator.push(MaterialPageRoute(builder: (_) => page));
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
              title: 'WrapCo.',
              theme: AppTheme.lightTheme(font),
              darkTheme: AppTheme.darkTheme(font),
              themeMode: mode,
              home: const SettingsBootstrap(child: AppEntryPage()),
            );
          },
        );
      },
    );
  }
}
