import 'package:flutter/material.dart';
import 'couple_repository.dart';
import 'tour_plan_bottom_sheet.dart';
import '../theme/app_theme.dart';

class TourPlanSection extends StatefulWidget {
  final String coupleId;
  final CoupleRepository repo;

  const TourPlanSection({
    super.key,
    required this.coupleId,
    required this.repo,
  });

  @override
  State<TourPlanSection> createState() => _TourPlanSectionState();
}

class _TourPlanSectionState extends State<TourPlanSection> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _loading = true);
    final list = await widget.repo.fetchTourPlans(widget.coupleId);
    if (!mounted) return;
    setState(() {
      _plans = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppPalette.isDark(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark ? const Color(0xFF221729) : Colors.white.withValues(alpha: 0.95),
        border: Border.all(
          color: isDark ? const Color(0xFF6B466F) : Colors.pinkAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.travel_explore,
                color: isDark ? const Color(0xFFFF8FB1) : Colors.pink,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Next Tour Plan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.add_circle,
                  color: isDark ? const Color(0xFFFF8FB1) : Colors.pink,
                ),
                onPressed: () async {
                  await showTourPlanBottomSheet(
                    context: context,
                    repo: widget.repo,
                    coupleId: widget.coupleId,
                  );
                  _loadPlans();
                },
              ),
            ],
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_plans.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'No tour planned yet.\nStart dreaming together 🌍💞',
                style: TextStyle(
                  color: AppPalette.isDark(context)
                      ? const Color(0xFFD8B9CB)
                      : Colors.grey.shade700,
                ),
              ),
            )
          else
            Column(children: _plans.map((p) => _planCard(p)).toList()),
        ],
      ),
    );
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final status = plan['status'] ?? 'PLANNED';

    Color statusColor = switch (status) {
      'COMPLETED' => Colors.green,
      'CONFIRMED' => Colors.blue,
      _ => Colors.orange,
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.place, color: Colors.pink.shade400),
      title: GestureDetector(
        onTap: () async {
          await showTourPlanBottomSheet(
            context: context,
            repo: widget.repo,
            coupleId: widget.coupleId,
            existing: plan,
          );
          _loadPlans();
        },
        child: Text(
          plan['title'],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      subtitle: plan['probable_date'] != null
          ? Text('📅 ${plan['probable_date']}')
          : const Text('Date not set'),
      trailing: Chip(
        label: Text(status),
        backgroundColor: statusColor.withOpacity(0.15),
        labelStyle: TextStyle(color: statusColor),
      ),
    );
  }
}
