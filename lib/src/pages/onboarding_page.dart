import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth_gate_page.dart';
import '../services/onboarding_preferences.dart';

/// Place this file at: lib/src/pages/onboarding_page.dart
///
/// To add more onboarding cards later, edit the `_pages` list inside
/// `_OnboardingPageState`.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();

  late final List<_OnboardingData> _pages = [
    const _OnboardingData(
      icon: Icons.dashboard_customize_rounded,
      title: 'Plan everything from one calm space',
      description:
          'Manage tasks, routines, and everyday priorities with a focused workspace designed to keep your day clear and under control.',
      accent: Color(0xFF4361EE),
      secondaryAccent: Color(0xFF7B8CFF),
      chips: ['Task planning', 'Daily priorities', 'Smart focus'],
    ),
    const _OnboardingData(
      icon: Icons.auto_awesome_rounded,
      title: 'Build momentum with habits and helpful tools',
      description:
          'Track habits, collect notes, and stay on top of small essentials without jumping between separate apps.',
      accent: Color(0xFF0F9D8A),
      secondaryAccent: Color(0xFF61D5C2),
      chips: ['Habits', 'Notes', 'Useful utilities'],
    ),
    const _OnboardingData(
      icon: Icons.shopping_bag_rounded,
      title: 'Organize life beyond tasks',
      description:
          'Keep shopping lists, personal reminders, and other productivity helpers close by so your routine stays smooth.',
      accent: Color(0xFFE76F51),
      secondaryAccent: Color(0xFFF4A261),
      chips: ['Shopping', 'Reminders', 'Daily flow'],
    ),
  ];

  int _currentPage = 0;
  bool _isCompleting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;

    setState(() => _isCompleting = true);
    await OnboardingPreferences.markOnboardingSeen();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const AuthGatePage(),
        ),
      ),
    );
  }

  Future<void> _handlePrimaryAction() async {
    final isLastPage = _currentPage == _pages.length - 1;
    if (isLastPage) {
      await _completeOnboarding();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final cardWidth = math.min(size.width - 32, 560.0);
    final isCompactHeight = size.height < 760;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF6F8FF),
              Color(0xFFEAF0FF),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const _SoftBackgroundOrb(
                alignment: Alignment.topLeft,
                size: 220,
                colors: [Color(0x334361EE), Color(0x114361EE)],
              ),
              const _SoftBackgroundOrb(
                alignment: Alignment.bottomRight,
                size: 260,
                colors: [Color(0x22F4A261), Color(0x08F4A261)],
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardWidth),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _BrandHeader(
                          onSkip: _isCompleting ? null : _completeOnboarding,
                        ),
                        SizedBox(height: isCompactHeight ? 12 : 20),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _pages.length,
                            onPageChanged: (index) {
                              setState(() => _currentPage = index);
                            },
                            itemBuilder: (context, index) {
                              final page = _pages[index];
                              return AnimatedPadding(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _OnboardingCard(page: page),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: isCompactHeight ? 10 : 18),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          child: _BottomActions(
                            key: ValueKey(_currentPage),
                            pageCount: _pages.length,
                            currentPage: _currentPage,
                            isCompleting: _isCompleting,
                            onContinue: _handlePrimaryAction,
                            onSkip: _completeOnboarding,
                            theme: theme,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.onSkip});

  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3146A8), Color(0xFF5D73E6)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x223146A8),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.grid_view_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SPARROW',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: const Color(0xFF213056),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Productivity, habits, notes, and more in one place',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onSkip,
          child: const Text('Skip'),
        ),
      ],
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    super.key,
    required this.pageCount,
    required this.currentPage,
    required this.isCompleting,
    required this.onContinue,
    required this.onSkip,
    required this.theme,
  });

  final int pageCount;
  final int currentPage;
  final bool isCompleting;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isLastPage = currentPage == pageCount - 1;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            pageCount,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: index == currentPage ? 28 : 9,
              height: 9,
              decoration: BoxDecoration(
                color: index == currentPage
                    ? const Color(0xFF3146A8)
                    : const Color(0xFFD2DBF3),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isCompleting ? null : onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3146A8),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: isCompleting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(isLastPage ? 'Get Started' : 'Continue'),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: isCompleting ? null : onSkip,
          child: Text(isLastPage ? 'Back to sign in' : 'Skip intro'),
        ),
      ],
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.page});

  final _OnboardingData page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        final heroHeight = compact ? 180.0 : constraints.maxHeight * 0.32;
        final iconSize = compact ? 72.0 : 94.0;
        final outerRadius = compact ? 26.0 : 32.0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(outerRadius),
            border: Border.all(color: const Color(0xFFE0E8FA)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 40,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: heroHeight,
                child: Container(
                  margin: EdgeInsets.all(compact ? 12 : 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [page.accent, page.secondaryAccent],
                    ),
                    borderRadius: BorderRadius.circular(compact ? 22 : 26),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -28,
                        right: -18,
                        child: Container(
                          height: compact ? 90 : 120,
                          width: compact ? 90 : 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -40,
                        left: -12,
                        child: Container(
                          height: compact ? 110 : 140,
                          width: compact ? 110 : 140,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: iconSize,
                                width: iconSize,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(
                                    compact ? 22 : 28,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.24),
                                  ),
                                ),
                                child: Icon(
                                  page.icon,
                                  size: compact ? 36 : 44,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: compact ? 12 : 18),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: page.chips
                                    .map((chip) => _FeatureChip(label: chip))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 24,
                    compact ? 4 : 8,
                    compact ? 18 : 24,
                    compact ? 20 : 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Modern productivity',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF3146A8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 14 : 18),
                      Text(
                        page.title,
                        style: (compact
                                ? theme.textTheme.titleLarge
                                : theme.textTheme.headlineSmall)
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF172033),
                              height: 1.15,
                            ),
                      ),
                      SizedBox(height: compact ? 10 : 14),
                      Text(
                        page.description,
                        style: (compact
                                ? theme.textTheme.bodyMedium
                                : theme.textTheme.bodyLarge)
                            ?.copyWith(
                              color: const Color(0xFF5B6782),
                              height: 1.6,
                            ),
                      ),
                      SizedBox(height: compact ? 16 : 22),
                      const _FeatureBullet(
                        icon: Icons.check_circle_rounded,
                        text: 'Designed for a clean daily flow without clutter',
                      ),
                      const SizedBox(height: 12),
                      const _FeatureBullet(
                        icon: Icons.check_circle_rounded,
                        text: 'Keeps essential tools together in one app',
                      ),
                      const SizedBox(height: 12),
                      const _FeatureBullet(
                        icon: Icons.check_circle_rounded,
                        text:
                            'Simple enough to start quickly, flexible enough to grow',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            color: Color(0xFF3146A8),
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5B6782),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _SoftBackgroundOrb extends StatelessWidget {
  const _SoftBackgroundOrb({
    required this.alignment,
    required this.size,
    required this.colors,
  });

  final Alignment alignment;
  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors),
          ),
        ),
      ),
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.secondaryAccent,
    required this.chips,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final Color secondaryAccent;
  final List<String> chips;
}
