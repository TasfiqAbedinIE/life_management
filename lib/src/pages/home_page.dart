import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sign_in_page.dart';
import 'task_page.dart';
import 'settings_page.dart';
import 'dart:async';

import '../coupled/coupled_request_page.dart';
import '../habits/presentation/habits_page.dart';
import '../habits/widget/habit_widget_service.dart';
import '../notes/pages/notes_list_page.dart';
import '../ebook/data/ebook_reading_repository.dart';
import '../ebook/ui/ebook_library_page.dart';
import '../budgeting/presentation/budgeting_page.dart';
import '../project_management/presentation/project_management_page.dart';
import '../theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _generatedIconBase = 'assets/generated_icons/manual_pack';

  late Future<_EfficiencySummary> _efficiencyFuture;

  late DateTime _now;
  Timer? _clockTimer;

  List<MotivationalQuote> _quotes = [];
  int _currentQuoteIndex = 0;
  Timer? _quoteTimer;

  String _selectedLabel = 'OFFICE'; // OFFICE | PERSONAL

  void _advanceQuote() {
    if (_quotes.isEmpty) return;
    _currentQuoteIndex = (_currentQuoteIndex + 1) % _quotes.length;
  }

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HabitWidgetService.consumeLaunchIntent(context);
      unawaited(HabitWidgetService.sync());
    });

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });

    // Load all quotes
    _fetchAllQuotes().then((_) {
      if (_quotes.isNotEmpty && mounted) {
        setState(() {
          _quotes.shuffle(); // 🔀 random order each time app opens
          _currentQuoteIndex = 0; // start at first of shuffled list
        });

        _quoteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
          if (!mounted || _quotes.isEmpty) return;
          setState(() {
            _advanceQuote(); // ⏱ go to next
          });
        });
      }
    });

    _efficiencyFuture = _fetchEfficiencySummary(_selectedLabel);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _quoteTimer?.cancel();
    super.dispose();
  }

  String _greetingForHour(int hour) {
    if (hour >= 6 && hour < 9) return 'Good morning';
    if (hour >= 9 && hour < 12) return 'Good day';
    if (hour >= 12 && hour < 16) return 'Good afternoon';
    if (hour >= 16 && hour < 19) return 'Good evening';
    if (hour >= 19 && hour <= 23) return 'Good night';
    return 'You’re up late';
  }

  IconData _iconForTime(int hour) {
    if (hour >= 5 && hour < 9)
      return Icons.wb_sunny_rounded; // Early Morning 🌅
    if (hour >= 9 && hour < 12) return Icons.light_mode_rounded; // Morning ☀️
    if (hour >= 12 && hour < 16) return Icons.wb_sunny_outlined; // Noon 🌞
    if (hour >= 16 && hour < 19) return Icons.wb_sunny_sharp; // Evening 🌆
    if (hour >= 19 && hour < 22) return Icons.nights_stay_rounded; // Night 🌙
    return Icons.bedtime_rounded; // Late Night 🌃
  }

  String _firstNameFromUser() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 'there';

    final fullName =
        (user.userMetadata?['full_name'] ??
                user.userMetadata?['name'] ??
                user.email ??
                '')
            as String;
    if (fullName.isEmpty) return 'there';
    final parts = fullName.trim().split(' ');
    return parts.first;
  }

  String _weekdayShortLabel(DateTime d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[d.weekday - 1];
  }

  String _monthShortLabel(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }

  String _formatCompactTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final meridiem = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $meridiem';
  }

  String _formatCompactDate(DateTime value) {
    return '${_weekdayShortLabel(value)}, ${value.day} ${_monthShortLabel(value.month)}';
  }

  String _timeContextLabel(int hour) {
    if (hour >= 6 && hour < 10) return 'Fresh start';
    if (hour >= 10 && hour < 13) return 'In flow';
    if (hour >= 13 && hour < 17) return 'Deep work';
    if (hour >= 17 && hour < 21) return 'Wind down';
    return 'Quiet hours';
  }

  String _headerSupportText(int hour) {
    if (hour >= 6 && hour < 10) {
      return 'Clear the small tasks early and keep space for the important ones.';
    }
    if (hour >= 10 && hour < 13) {
      return 'Your day is in motion now. Protect a little room for focused work.';
    }
    if (hour >= 13 && hour < 17) {
      return 'A steady afternoon rhythm beats rushing the rest of the list.';
    }
    if (hour >= 17 && hour < 21) {
      return 'Wrap up the essentials and leave tomorrow a cleaner start.';
    }
    return 'Keep it light right now. A calm reset is productive too.';
  }

  Widget _headerPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeader(
    BuildContext context, {
    required String greeting,
    required String name,
    required ThemeData theme,
  }) {
    final hour = _now.hour;
    final displayName = name == 'there' ? 'Friend' : name;
    final spotlight = hour >= 18 || hour < 6 ? 'Reset' : 'Today';
    final accentLine = hour >= 18 || hour < 6
        ? 'Close the day with one thing done well.'
        : 'Make the next hour count.';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppPalette.heroGradient(context),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -2,
            child: Text(
              spotlight.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.08),
                fontSize: 56,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                height: 1,
              ),
            ),
          ),
          Positioned(
            right: 28,
            top: 22,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD66B).withValues(alpha: 0.95),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD66B).withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _formatCompactDate(_now),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatCompactTime(_now),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                greeting,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$displayName\n',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 0.95,
                      ),
                    ),
                    TextSpan(
                      text: accentLine,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _actionsExpanded = true;

  Widget _actionDivider() {
    final isDark = AppTheme.themeMode.value == ThemeMode.dark;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.grey.shade300;
    final labelColor = isDark ? const Color(0xFFB4C2DF) : Colors.grey.shade800;
    return InkWell(
      onTap: () {
        setState(() {
          _actionsExpanded = !_actionsExpanded;
        });
      },
      child: Row(
        children: [
          Expanded(child: Divider(color: dividerColor, thickness: 0.7)),
          const SizedBox(width: 8),
          Text(
            'MENU',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: labelColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: dividerColor, thickness: 0.7)),
        ],
      ),
    );
  }

  Widget _actionsSection() {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      crossFadeState: _actionsExpanded
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: Padding(
        padding: const EdgeInsets.only(top: 12.0, bottom: 12),
        child: _quickActionsRow(), // your row of icons
      ),
      secondChild: const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final now = DateTime.now();
    final greeting = _greetingForHour(_now.hour);
    final name = _firstNameFromUser();
    final theme = Theme.of(context);
    final surface = AppPalette.surface(context);

    return Scaffold(
      backgroundColor: AppPalette.background(context),
      appBar: AppBar(
        backgroundColor: AppPalette.background(context),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(Icons.access_time_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Dashboard',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.logout_rounded,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: _signOut,
            tooltip: 'Logout',
          ),
        ],
      ),
      // drawer: const _AppDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefreshDashboard,
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Main content – rounded white container
              Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    _quotes.isEmpty
                        ? _skeletonCard(height: 140)
                        : GestureDetector(
                            onTap: () {
                              if (_quotes.isEmpty) return;
                              setState(() {
                                _advanceQuote(); // 👆 tap = go to next
                              });
                            },
                            child: _QuoteCard(
                              quote: _quotes[_currentQuoteIndex],
                            ),
                          ),

                    const SizedBox(height: 16),

                    _actionDivider(),
                    _actionsSection(),
                    const SizedBox(height: 16),

                    // LAST 7 DAYS EFFICIENCY CARD + WEEKLY GRAPH
                    FutureBuilder<_EfficiencySummary>(
                      future: _efficiencyFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _skeletonCard(height: 200);
                        }

                        if (snapshot.hasError) {
                          return _errorCard(
                            title: 'Could not load efficiency',
                            message: snapshot.error.toString(),
                            onRetry: () => setState(() {
                              _efficiencyFuture = _fetchEfficiencySummary(
                                _selectedLabel,
                              );
                            }),
                          );
                        }

                        final summary = snapshot.data!;
                        if (!summary.hasActivityHours) {
                          return _infoCard(
                            title: 'Set your activity hours',
                            message:
                                'Go to Settings → Focus Hours to set your daily activity hours. Once you save it, your efficiency for the last week will appear here.',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsPage(),
                                ),
                              );
                            },
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _labelFilterChips(),
                            const SizedBox(height: 12),
                            _EfficiencyCard(
                              summary: summary,
                              selectedLabel: _selectedLabel,
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    _HabitsDashboardSection(
                      onOpenHabits: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HabitsPage()),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    _ReaderDashboardSection(
                      onOpenReader: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EbookLibraryPage(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onRefreshDashboard() async {
    // Re-fetch quotes from Supabase
    await _fetchAllQuotes();

    if (!mounted) return;

    setState(() {
      if (_quotes.isNotEmpty) {
        _quotes.shuffle(); // keep it random
        _currentQuoteIndex = 0;
      }

      // Rebuild efficiency chart (it will fetch fresh data from Supabase)
      _efficiencyFuture = _fetchEfficiencySummary(_selectedLabel);
    });
  }

  Widget _quickActionsRow() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        _MinimalActionButton(
          icon: Image.asset("assets/icon/tasks_icon.png", fit: BoxFit.contain),
          label: "Tasks",
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TaskPage()));
          },
        ),
        _MinimalActionButton(
          icon: SvgPicture.asset(
            "$_generatedIconBase/coupled.svg",
            fit: BoxFit.contain,
          ),
          label: "Coupled",
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CoupledRequestPage()),
            );
          },
        ),
        _MinimalActionButton(
          icon: SvgPicture.asset(
            "$_generatedIconBase/habits.svg",
            fit: BoxFit.contain,
          ),
          label: "Habits",
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const HabitsPage()));
          },
        ),
        _MinimalActionButton(
          icon: Image.asset("assets/icon/notes_icon.png", fit: BoxFit.contain),
          label: "Notes",
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const NotesListPage()));
          },
        ),
        _MinimalActionButton(
          icon: SvgPicture.asset(
            "$_generatedIconBase/budget.svg",
            fit: BoxFit.contain,
          ),
          label: "Budget",
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const BudgetingPage()));
          },
        ),
        _MinimalActionButton(
          icon: SvgPicture.asset(
            "$_generatedIconBase/reader.svg",
            fit: BoxFit.contain,
          ),
          label: "Reader",
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const EbookLibraryPage()));
          },
        ),
        _MinimalActionButton(
          icon: SvgPicture.asset(
            "$_generatedIconBase/projects.svg",
            fit: BoxFit.contain,
          ),
          label: "Projects",
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => ProjectManagementPage()));
          },
        ),
        _MinimalActionButton(
          icon: SvgPicture.asset(
            "$_generatedIconBase/settings.svg",
            fit: BoxFit.contain,
          ),
          label: "Setting",
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
          },
        ),
      ],
    );
  }

  Widget _labelFilterChips() {
    final labels = ['OFFICE', 'PERSONAL'];
    final pretty = {'OFFICE': 'Office', 'PERSONAL': 'Personal'};

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: labels.map((label) {
        final selected = _selectedLabel == label;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text(pretty[label]!),
            selected: selected,
            onSelected: (_) {
              if (!selected) {
                setState(() {
                  _selectedLabel = label;
                  _efficiencyFuture = _fetchEfficiencySummary(_selectedLabel);
                });
              }
            },
          ),
        );
      }).toList(),
    );
  }

  void _signOut() async {
    await Supabase.instance.client.auth.signOut();
    await HabitWidgetService.sync();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInPage()),
      (route) => false,
    );
  }

  Widget _skeletonCard({double height = 120}) {
    final isDark = AppTheme.themeMode.value == ThemeMode.dark;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF172338) : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _errorCard({
    required String title,
    required String message,
    required VoidCallback onRetry,
  }) {
    final isDark = AppTheme.themeMode.value == ThemeMode.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF361920) : Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF7F3340) : Colors.red[100]!,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required String message,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.themeMode.value == ThemeMode.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF142844) : Colors.blue[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2A4D7A) : Colors.blue[100]!,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(message, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }

  TimeOfDay? _parseTimeFromStorage(String? text) {
    if (text == null || text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  int _minutesBetween(TimeOfDay start, TimeOfDay end) {
    final startDt = DateTime(0, 1, 1, start.hour, start.minute);
    final endDt = DateTime(0, 1, 1, end.hour, end.minute);
    final diff = endDt.difference(startDt).inMinutes;
    return diff > 0 ? diff : 0;
  }

  Future<void> _fetchAllQuotes() async {
    final supabase = Supabase.instance.client;

    final rows = await supabase
        .from('motivational_quotes')
        .select('text, author')
        .eq('is_active', true)
        .order('id', ascending: false);

    // Convert rows to List<MotivationalQuote>
    _quotes = rows.map<MotivationalQuote>((row) {
      return MotivationalQuote(
        text: row['text'] as String,
        author: row['author'] as String?,
      );
    }).toList();
  }

  Future<_EfficiencySummary> _fetchEfficiencySummary(String label) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      return const _EfficiencySummary.noHours();
    }

    // 1) Load office + personal hours from user_settings
    final settingsRow = await supabase
        .from('user_settings')
        .select('office_start, office_end, personal_start, personal_end')
        .eq('user_id', user.id)
        .maybeSingle();

    final startOfficeStr = settingsRow?['office_start'] as String?;
    final endOfficeStr = settingsRow?['office_end'] as String?;
    final startPersonalStr = settingsRow?['personal_start'] as String?;
    final endPersonalStr = settingsRow?['personal_end'] as String?;

    final officeStart = _parseTimeFromStorage(startOfficeStr);
    final officeEnd = _parseTimeFromStorage(endOfficeStr);
    final personalStart = _parseTimeFromStorage(startPersonalStr);
    final personalEnd = _parseTimeFromStorage(endPersonalStr);

    if (officeStart == null || officeEnd == null) {
      // No office hours set → treat as no config
      return const _EfficiencySummary.noHours();
    }

    final officeMinutes = _minutesBetween(officeStart, officeEnd);
    final personalMinutes = (personalStart != null && personalEnd != null)
        ? _minutesBetween(personalStart, personalEnd)
        : 0;

    int plannedMinutesPerDay;
    switch (label) {
      case 'OFFICE':
        plannedMinutesPerDay = officeMinutes;
        break;
      case 'PERSONAL':
        plannedMinutesPerDay = personalMinutes;
        break;
      default:
        plannedMinutesPerDay = officeMinutes + personalMinutes;
    }

    if (plannedMinutesPerDay <= 0) {
      return const _EfficiencySummary.noHours();
    }

    // 2) For last 7 days, compute daily spent minutes from tasks table
    final now = DateTime.now();
    final List<_DailyEfficiency> days = [];

    for (int i = 6; i >= 0; i--) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      final dayStr = day.toIso8601String().split('T').first;

      final query = supabase
          .from('tasks')
          .select('total_spent_minutes')
          .eq('user_id', user.id)
          .eq('start_date', dayStr);

      final rows = label == 'PERSONAL'
          ? await query.inFilter('label', ['PERSONAL', 'HOME'])
          : await query.eq('label', label);

      int totalSeconds = 0;
      for (final row in rows) {
        totalSeconds += (row['total_spent_minutes'] as num?)?.toInt() ?? 0;
      }

      // 🔁 convert SECONDS → MINUTES (double)
      final spentMinutes = totalSeconds / 60.0;

      days.add(
        _DailyEfficiency(
          date: day,
          spentMinutes: spentMinutes,
          plannedMinutes: plannedMinutesPerDay,
        ),
      );
    }

    return _EfficiencySummary(hasActivityHours: true, days: days);
  }
}

class MotivationalQuote {
  final String text;
  final String? author;

  const MotivationalQuote({required this.text, this.author});
}

class _QuoteCard extends StatelessWidget {
  final MotivationalQuote quote;
  const _QuoteCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = AppPalette.isDark(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppPalette.quoteGradient(context),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${quote.text}"',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (quote.author != null && quote.author!.trim().isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '— ${quote.author}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DailyEfficiency {
  final DateTime date;
  final double spentMinutes;
  final int plannedMinutes;

  const _DailyEfficiency({
    required this.date,
    required this.spentMinutes,
    required this.plannedMinutes,
  });

  double get percent {
    if (plannedMinutes == 0) return 0;
    return (spentMinutes / plannedMinutes) * 100.0;
  }
}

class _EfficiencySummary {
  final bool hasActivityHours;
  final List<_DailyEfficiency> days;

  const _EfficiencySummary({
    required this.hasActivityHours,
    required this.days,
  });

  const _EfficiencySummary.noHours()
    : hasActivityHours = false,
      days = const [];

  double get averagePercent {
    if (days.isEmpty) return 0;
    final valid = days.where((d) => d.plannedMinutes > 0).toList();
    if (valid.isEmpty) return 0;
    final sum = valid.fold<double>(
      0,
      (prev, e) => prev + e.percent.clamp(0, 150),
    );
    return sum / valid.length;
  }

  int get plannedMinutesPerDay {
    if (days.isEmpty) return 0;
    // Assume same plan each day; take first non-zero
    final withPlan = days.firstWhere(
      (d) => d.plannedMinutes > 0,
      orElse: () => days.first,
    );
    return withPlan.plannedMinutes;
  }
}

class EfficiencyBar {
  final String label;
  final double value; // 0–1 fraction
  const EfficiencyBar({required this.label, required this.value});
}

class _EfficiencyCard extends StatelessWidget {
  final _EfficiencySummary summary;
  final String selectedLabel;

  const _EfficiencyCard({required this.summary, required this.selectedLabel});

  String _weekdayShortLabel(DateTime d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avgPercent = summary.averagePercent.clamp(0.0, 150.0);
    final plannedMinutes = summary.plannedMinutesPerDay;
    final isDark = AppPalette.isDark(context);

    String prettyLabel;
    switch (selectedLabel) {
      case 'OFFICE':
        prettyLabel = 'Office';
        break;
      case 'PERSONAL':
        prettyLabel = 'Personal';
        break;
      default:
        prettyLabel = selectedLabel;
    }

    String plannedLabel;
    if (selectedLabel == 'OFFICE') {
      plannedLabel = 'office';
    } else if (selectedLabel == 'PERSONAL') {
      plannedLabel = 'personal';
    } else {
      plannedLabel = 'office + personal';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppPalette.softShadow(context),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 7 days performance',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Avg ${avgPercent.toStringAsFixed(0)}% of your planned focus time',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppPalette.mutedText(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Planned: $plannedMinutes min/day $plannedLabel',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? const Color(0xFF8798B7) : Colors.grey[500],
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (avgPercent / 100).clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 16),
          _EfficiencyChart(days: summary.days),
        ],
      ),
    );
  }
}

class _EfficiencyChart extends StatelessWidget {
  final List<_DailyEfficiency> days;
  const _EfficiencyChart({required this.days});

  String _weekdayShortLabel(DateTime d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const Text(
        'No activity logged yet.',
        style: TextStyle(fontSize: 12),
      );
    }
    final isDark = AppPalette.isDark(context);

    // Convert percents to 0–1 for height; cap at 150%
    final percents = days
        .map((d) => d.percent.clamp(0.0, 150.0))
        .toList(growable: false);
    final maxPercent = percents.fold<double>(0.0, (a, b) => math.max(a, b));
    final effectiveMax = maxPercent == 0 ? 100.0 : maxPercent;

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < days.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  final d = days[i];
                  final percent = d.percent.clamp(0.0, 999.0);
                  final dateLabel =
                      '${d.date.day.toString().padLeft(2, '0')}-${d.date.month.toString().padLeft(2, '0')}';

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '$dateLabel • ${percent.toStringAsFixed(0)}% • '
                        '${d.spentMinutes.toStringAsFixed(0)} / ${d.plannedMinutes} min',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Percentage label above bar
                    Text(
                      '${percents[i].round()}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFFA8B7D3)
                            : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Animated bar
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          height:
                              (percents[i] / effectiveMax).clamp(0.0, 1.0) *
                              120.0,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.85),
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.4),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.softShadow(context),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _weekdayShortLabel(days[i].date),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFFA8B7D3)
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Habit {
  final String id;
  final String name;
  final int frequencyPerDay;

  const _Habit({
    required this.id,
    required this.name,
    required this.frequencyPerDay,
  });
}

class _HabitsDashboardData {
  final List<_Habit> habits;

  /// today done_count map by habit_id
  final Map<String, int> todayDone;

  /// last 7 days sum(done_count) map by habit_id (kept if you need later)
  final Map<String, int> weekDone;

  /// Heatmap: entry_date -> completion fraction (0.0 to 1.0)
  final Map<String, double> dayCompletion;

  const _HabitsDashboardData({
    required this.habits,
    required this.todayDone,
    required this.weekDone,
    required this.dayCompletion,
  });

  int get totalHabits => habits.length;

  double get overall7DayPercent {
    if (dayCompletion.isEmpty) return 0;
    // Use only last 7 days from available heatmap data
    final keys = dayCompletion.keys.toList()..sort();
    final last7 = keys.length <= 7 ? keys : keys.sublist(keys.length - 7);
    final avg =
        last7.fold<double>(0, (p, k) => p + (dayCompletion[k] ?? 0.0)) /
        last7.length;
    return avg * 100.0;
  }
}

class _MinimalActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _MinimalActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 24, width: 24, child: icon),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderDashboardSection extends StatefulWidget {
  const _ReaderDashboardSection({required this.onOpenReader});

  final VoidCallback onOpenReader;

  @override
  State<_ReaderDashboardSection> createState() =>
      _ReaderDashboardSectionState();
}

class _ReaderDashboardSectionState extends State<_ReaderDashboardSection> {
  final EbookReadingRepository _readingRepository = EbookReadingRepository();
  late Future<EbookReadingStats> _future;

  static const int _weeklyGoalSeconds = 6 * 60 * 60;

  @override
  void initState() {
    super.initState();
    _future = _readingRepository.fetchStats();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _readingRepository.fetchStats();
    });
  }

  String _formatReadTime(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours <= 0) return '${minutes}m';
    if (minutes <= 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  List<DateTime> _currentWeekDays() {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    return List.generate(7, (index) => start.add(Duration(days: index)));
  }

  Widget _buildError(Object error) {
    final isDark = AppPalette.isDark(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF361920) : Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF7F3340) : Colors.red[100]!,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(error.toString())),
          TextButton(onPressed: _refresh, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: AppPalette.isDark(context)
            ? const Color(0xFF172338)
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EbookReadingStats>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }
        if (snapshot.hasError) {
          return _buildError(snapshot.error!);
        }

        final stats =
            snapshot.data ??
            const EbookReadingStats(
              totalSecondsByBook: {},
              currentWeekSeconds: 0,
              previousWeekSeconds: 0,
            );
        final weekDays = _currentWeekDays();
        final dailySeconds = {
          for (final day in weekDays)
            day: stats.currentWeekDailySeconds[day] ?? 0,
        };
        final goalProgress = (stats.currentWeekSeconds / _weeklyGoalSeconds)
            .clamp(0.0, 1.0);
        final maxDailySeconds = math.max(
          60 * 60,
          dailySeconds.values.fold<int>(0, math.max),
        );

        return _ReaderPerformanceCard(
          stats: stats,
          dailySeconds: dailySeconds,
          goalProgress: goalProgress,
          maxDailySeconds: maxDailySeconds,
          weeklyGoalText:
              '${(goalProgress * 100).clamp(0, 100).toStringAsFixed(0)}% of weekly goal',
          formatReadTime: _formatReadTime,
          onTap: widget.onOpenReader,
        );
      },
    );
  }
}

class _ReaderPerformanceCard extends StatelessWidget {
  final EbookReadingStats stats;
  final Map<DateTime, int> dailySeconds;
  final double goalProgress;
  final int maxDailySeconds;
  final String weeklyGoalText;
  final String Function(int seconds) formatReadTime;
  final VoidCallback onTap;

  const _ReaderPerformanceCard({
    required this.stats,
    required this.dailySeconds,
    required this.goalProgress,
    required this.maxDailySeconds,
    required this.weeklyGoalText,
    required this.formatReadTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppPalette.isDark(context);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final accent = isDark ? const Color(0xFF8B7BFF) : const Color(0xFF6F62FF);
    final softAccent = isDark
        ? const Color(0xFF6B5FE8)
        : const Color(0xFF8A7CFF);
    final cardColor = isDark ? const Color(0xFF171D26) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE1E4EC);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.28)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Weekly Reading Performance',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                  label: const Text(
                    'Open Reader',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 128,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 118,
                        width: 118,
                        child: _ReadingGoalRing(
                          progress: goalProgress,
                          accent: accent,
                          softAccent: softAccent,
                          trackColor: isDark
                              ? const Color(0xFF3A405A)
                              : const Color(0xFFE9E6FF),
                          center: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                formatReadTime(stats.currentWeekSeconds),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Time Read',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        weeklyGoalText,
                        style: TextStyle(
                          color: accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 150,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: dailySeconds.entries.map((entry) {
                        return _ReadingDayBar(
                          day: entry.key,
                          seconds: entry.value,
                          maxSeconds: maxDailySeconds,
                          accent: accent,
                          softAccent: softAccent,
                          textColor: textColor,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE6E9F1),
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _ReaderMetric(
                      icon: Icons.menu_book_rounded,
                      label: 'Books Read',
                      value: stats.currentWeekBooksRead.toString(),
                      unit: 'Books',
                      iconColor: isDark
                          ? const Color(0xFF9A84FF)
                          : const Color(0xFF6F62FF),
                    ),
                  ),
                  VerticalDivider(
                    width: 24,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFDDE2EC),
                  ),
                  Expanded(
                    child: _ReaderMetric(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Reading Streak',
                      value: stats.readingStreakDays.toString(),
                      unit: 'Days',
                      iconColor: const Color(0xFFFF8A2A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingGoalRing extends StatelessWidget {
  final double progress;
  final Color accent;
  final Color softAccent;
  final Color trackColor;
  final Widget center;

  const _ReadingGoalRing({
    required this.progress,
    required this.accent,
    required this.softAccent,
    required this.trackColor,
    required this.center,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ReadingGoalRingPainter(
        progress: progress,
        accent: accent,
        softAccent: softAccent,
        trackColor: trackColor,
      ),
      child: Center(child: center),
    );
  }
}

class _ReadingGoalRingPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final Color softAccent;
  final Color trackColor;

  const _ReadingGoalRingPainter({
    required this.progress,
    required this.accent,
    required this.softAccent,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 8.0;
    final rect = Offset.zero & size;
    final ringRect = rect.deflate(strokeWidth / 2);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [softAccent, accent, softAccent],
        stops: const [0.0, 0.58, 1.0],
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
      ).createShader(ringRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(ringRect, 0, math.pi * 2, false, trackPaint);
    canvas.drawArc(
      ringRect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReadingGoalRingPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        accent != oldDelegate.accent ||
        softAccent != oldDelegate.softAccent ||
        trackColor != oldDelegate.trackColor;
  }
}

class _ReadingDayBar extends StatelessWidget {
  final DateTime day;
  final int seconds;
  final int maxSeconds;
  final Color accent;
  final Color softAccent;
  final Color textColor;

  const _ReadingDayBar({
    required this.day,
    required this.seconds,
    required this.maxSeconds,
    required this.accent,
    required this.softAccent,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final ratio = maxSeconds <= 0
        ? 0.0
        : (seconds / maxSeconds).clamp(0.0, 1.0);
    final height = 22.0 + (84.0 * ratio);

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            seconds == 0 ? '0m' : _compactDuration(seconds),
            maxLines: 1,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            width: 16,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [softAccent, accent.withValues(alpha: 0.72)],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.26),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            labels[day.weekday - 1],
            maxLines: 1,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _compactDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours <= 0) return '${math.max(minutes, 1)}m';
    if (minutes <= 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }
}

class _ReaderMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color iconColor;

  const _ReaderMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          unit,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.72),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Added this section for separating the Habit ---->
class _HabitsDashboardSection extends StatefulWidget {
  const _HabitsDashboardSection({required this.onOpenHabits});

  final VoidCallback onOpenHabits;

  @override
  State<_HabitsDashboardSection> createState() =>
      _HabitsDashboardSectionState();
}

class _HabitsDashboardSectionState extends State<_HabitsDashboardSection> {
  late Future<_HabitsDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchHabitsDashboardData();
    _future.then((data) {
      if (!mounted) return;
      setState(() => _cache = data);
    });
  }

  _HabitsDashboardData? _cache; // local cached dashboard data
  int _pendingSaves = 0;
  bool get _saving => _pendingSaves > 0;

  Future<void> refresh() async {
    setState(() {
      _future = _fetchHabitsDashboardData();
    });

    final data = await _future;
    if (!mounted) return;
    setState(() {
      _cache = data;
    });
  }

  Future<_HabitsDashboardData> _fetchHabitsDashboardData() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      return const _HabitsDashboardData(
        habits: [],
        todayDone: {},
        weekDone: {},
        dayCompletion: {},
      );
    }

    final habitsRows = await supabase
        .from('habits')
        .select('id, name, frequency_per_day')
        .eq('user_id', user.id)
        .isFilter('archived_at', null)
        .order('created_at');

    final habits = (habitsRows as List)
        .map(
          (r) => _Habit(
            id: r['id'].toString(),
            name: (r['name'] ?? '').toString(),
            frequencyPerDay: (r['frequency_per_day'] as num?)?.toInt() ?? 1,
          ),
        )
        .toList();

    if (habits.isEmpty) {
      return const _HabitsDashboardData(
        habits: [],
        todayDone: {},
        weekDone: {},
        dayCompletion: {},
      );
    }

    final habitIds = habits.map((h) => h.id).toList();

    final now = DateTime.now();
    final todayStr = DateTime(
      now.year,
      now.month,
      now.day,
    ).toIso8601String().split('T').first;

    // heatmap range (28 days)
    final start28 = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 27));
    final start28Str = start28.toIso8601String().split('T').first;

    final start7 = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final start7Str = start7.toIso8601String().split('T').first;

    final entriesRows = await supabase
        .from('habit_entries')
        .select('habit_id, entry_date, done_count')
        .inFilter('habit_id', habitIds)
        .gte('entry_date', start28Str)
        .lte('entry_date', todayStr);

    final Map<String, int> todayDone = {};
    final Map<String, int> weekDone = {};

    // date -> (habit_id -> done_count)
    final Map<String, Map<String, int>> doneByDate = {};

    for (final e in (entriesRows as List)) {
      final hid = e['habit_id'].toString();
      final d = e['entry_date'].toString(); // YYYY-MM-DD
      final done = (e['done_count'] as num?)?.toInt() ?? 0;

      doneByDate.putIfAbsent(d, () => {});
      doneByDate[d]![hid] = done;

      if (d == todayStr) {
        todayDone[hid] = done;
      }
      if (d.compareTo(start7Str) >= 0) {
        weekDone[hid] = (weekDone[hid] ?? 0) + done;
      }
    }

    // compute dayCompletion for last 28 days
    final Map<String, double> dayCompletion = {};
    final habitFreq = {for (final h in habits) h.id: h.frequencyPerDay};

    for (int i = 0; i < 28; i++) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 27 - i));
      final ds = day.toIso8601String().split('T').first;

      int completed = 0;
      for (final h in habits) {
        final done = doneByDate[ds]?[h.id] ?? 0;
        if (done >= (habitFreq[h.id] ?? 1)) completed++;
      }

      final total = habits.isEmpty ? 0 : habits.length;
      dayCompletion[ds] = total == 0 ? 0.0 : (completed / total);
    }

    return _HabitsDashboardData(
      habits: habits,
      todayDone: todayDone,
      weekDone: weekDone,
      dayCompletion: dayCompletion,
    );
  }

  Future<void> _changeHabitDoneOptimistic({
    required String habitId,
    required String entryDate,
    required int delta,
    required int maxPerDay,
  }) async {
    final supabase = Supabase.instance.client;

    if (_cache == null) {
      await refresh();
      return;
    }

    final oldToday = _cache!.todayDone[habitId] ?? 0;
    final oldWeek = _cache!.weekDone[habitId] ?? 0;

    final newToday = (oldToday + delta).clamp(0, maxPerDay);
    final appliedDelta = newToday - oldToday;
    if (appliedDelta == 0) return;

    setState(() {
      _pendingSaves += 1;

      final newTodayDone = {..._cache!.todayDone, habitId: newToday};
      final newWeekDone = {
        ..._cache!.weekDone,
        habitId: (oldWeek + appliedDelta),
      };

      final now = DateTime.now();
      final todayKey = DateTime(
        now.year,
        now.month,
        now.day,
      ).toIso8601String().split('T').first;

      int completedCount = 0;
      for (final h in _cache!.habits) {
        final done = (h.id == habitId) ? newToday : (newTodayDone[h.id] ?? 0);
        if (done >= h.frequencyPerDay) completedCount++;
      }

      final totalHabits = _cache!.habits.isEmpty ? 0 : _cache!.habits.length;
      final todayFraction = totalHabits == 0
          ? 0.0
          : (completedCount / totalHabits);

      final newDayCompletion = {
        ..._cache!.dayCompletion,
        todayKey: todayFraction,
      };

      _cache = _HabitsDashboardData(
        habits: _cache!.habits,
        todayDone: newTodayDone,
        weekDone: newWeekDone,
        dayCompletion: newDayCompletion,
      );
    });

    try {
      final existing = await supabase
          .from('habit_entries')
          .select('id, done_count')
          .eq('habit_id', habitId)
          .eq('entry_date', entryDate)
          .maybeSingle();

      if (existing == null) {
        if (newToday != 0) {
          await supabase.from('habit_entries').insert({
            'habit_id': habitId,
            'entry_date': entryDate,
            'done_count': newToday,
          });
        }
      } else {
        final id = existing['id'];
        await supabase
            .from('habit_entries')
            .update({'done_count': newToday})
            .eq('id', id);
      }

      await HabitWidgetService.sync();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        final rolledTodayDone = {..._cache!.todayDone, habitId: oldToday};
        final rolledWeekDone = {..._cache!.weekDone, habitId: oldWeek};

        final now = DateTime.now();
        final todayKey = DateTime(
          now.year,
          now.month,
          now.day,
        ).toIso8601String().split('T').first;

        int completedCount = 0;
        for (final h in _cache!.habits) {
          final done = (h.id == habitId)
              ? oldToday
              : (rolledTodayDone[h.id] ?? 0);
          if (done >= h.frequencyPerDay) completedCount++;
        }

        final totalHabits = _cache!.habits.isEmpty ? 0 : _cache!.habits.length;
        final todayFraction = totalHabits == 0
            ? 0.0
            : (completedCount / totalHabits);

        final rolledDayCompletion = {
          ..._cache!.dayCompletion,
          todayKey: todayFraction,
        };

        _cache = _HabitsDashboardData(
          habits: _cache!.habits,
          todayDone: rolledTodayDone,
          weekDone: rolledWeekDone,
          dayCompletion: rolledDayCompletion,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to update habit. Please try again.\n$e"),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _pendingSaves = (_pendingSaves - 1).clamp(0, 999999);
      });
    }
  }

  Widget _miniCircleButton({required IconData icon, VoidCallback? onTap}) {
    final disabled = onTap == null;
    final isDark = AppTheme.themeMode.value == ThemeMode.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isDark
              ? (disabled ? const Color(0xFF1A2740) : const Color(0xFF22314D))
              : (disabled ? Colors.grey[200] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF314564) : Colors.grey[300]!,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDark
              ? (disabled ? const Color(0xFF60708E) : const Color(0xFFAEC1FF))
              : (disabled ? Colors.grey[400] : Colors.indigo[700]),
        ),
      ),
    );
  }

  Widget _habitsTodayCard(_HabitsDashboardData data) {
    final now = DateTime.now();
    final todayStr = DateTime(
      now.year,
      now.month,
      now.day,
    ).toIso8601String().split('T').first;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppPalette.softShadow(context),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Today's habits",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),

              // ⏳ syncing indicator (only while saving)
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (data.habits.isEmpty)
            Text(
              "No habits yet. Add habits to start tracking.",
              style: TextStyle(color: AppPalette.mutedText(context)),
            )
          else
            ...data.habits.map((h) {
              final done = data.todayDone[h.id] ?? 0;
              final max = h.frequencyPerDay;

              final canAdd = done < max;
              final canRemove = done > 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        h.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      "$done/$max",
                      style: TextStyle(
                        color: AppPalette.mutedText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _miniCircleButton(
                      icon: Icons.remove,
                      onTap: canRemove
                          ? () => _changeHabitDoneOptimistic(
                              habitId: h.id,
                              entryDate: todayStr,
                              delta: -1,
                              maxPerDay: max,
                            )
                          : null,
                    ),

                    const SizedBox(width: 6),

                    // plus
                    _miniCircleButton(
                      icon: Icons.add,
                      onTap: canAdd
                          ? () => _changeHabitDoneOptimistic(
                              habitId: h.id,
                              entryDate: todayStr,
                              delta: 1,
                              maxPerDay: max,
                            )
                          : null,
                    ),
                  ],
                ),
              );
            }).toList(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onOpenHabits,
              child: const Text("Open habits"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _habitsPerformanceCard(_HabitsDashboardData data) {
    final overall = data.overall7DayPercent.clamp(0.0, 100.0);
    final totalHabits = data.totalHabits;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppPalette.softShadow(context),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Habit performance",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            "Overall (last 7 days): ${overall.toStringAsFixed(0)}%  •  $totalHabits habits",
            style: TextStyle(color: AppPalette.mutedText(context)),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (overall / 100).clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 14),
          _HabitsHeatmap(dayCompletion: data.dayCompletion),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HabitsDashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppTheme.themeMode.value == ThemeMode.dark
                  ? const Color(0xFF172338)
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
          );
        }
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.themeMode.value == ThemeMode.dark
                  ? const Color(0xFF361920)
                  : Colors.red[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.themeMode.value == ThemeMode.dark
                    ? const Color(0xFF7F3340)
                    : Colors.red[100]!,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(child: Text(snapshot.error.toString())),
                TextButton(onPressed: refresh, child: const Text('Retry')),
              ],
            ),
          );
        }

        final data = _cache ?? snapshot.data!;
        return Column(
          children: [
            _habitsTodayCard(data),
            const SizedBox(height: 12),
            _habitsPerformanceCard(data),
          ],
        );
      },
    );
  }
}

class _HabitsHeatmap extends StatelessWidget {
  final Map<String, double> dayCompletion; // dateStr -> 0..1

  const _HabitsHeatmap({required this.dayCompletion});

  @override
  Widget build(BuildContext context) {
    if (dayCompletion.isEmpty) {
      return Text(
        "No habit activity yet.",
        style: TextStyle(color: AppPalette.mutedText(context), fontSize: 12),
      );
    }

    final keys = dayCompletion.keys.toList()..sort(); // chronological
    final primary = Theme.of(context).colorScheme.primary;

    // 28 squares = 4 weeks x 7 days
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Last 28 days",
          style: TextStyle(
            color: AppPalette.mutedText(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: keys.map((k) {
            final v = (dayCompletion[k] ?? 0.0).clamp(0.0, 1.0);

            // intensity color
            final c =
                Color.lerp(
                  AppPalette.isDark(context)
                      ? const Color(0xFF22314D)
                      : Colors.grey[200],
                  primary,
                  v,
                ) ??
                primary;

            return GestureDetector(
              onTap: () {
                final pct = (v * 100).toStringAsFixed(0);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("$k • $pct% habits completed"),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppPalette.border(context)),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              "Less",
              style: TextStyle(
                color: AppPalette.mutedText(context),
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 6),
            _legendBox(context, 0.0),
            const SizedBox(width: 4),
            _legendBox(context, 0.33),
            const SizedBox(width: 4),
            _legendBox(context, 0.66),
            const SizedBox(width: 4),
            _legendBox(context, 1.0),
            const SizedBox(width: 6),
            Text(
              "More",
              style: TextStyle(
                color: AppPalette.mutedText(context),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendBox(BuildContext context, double v) {
    final primary = Theme.of(context).colorScheme.primary;
    final c =
        Color.lerp(
          AppPalette.isDark(context)
              ? const Color(0xFF22314D)
              : Colors.grey[200],
          primary,
          v,
        ) ??
        primary;

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppPalette.border(context)),
      ),
    );
  }
}
