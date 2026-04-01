import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'couple_repository.dart';
import 'couple_shopping_page.dart';

class ShoppingHubSection extends StatefulWidget {
  final String coupleId;
  final CoupleRepository repo;

  const ShoppingHubSection({
    super.key,
    required this.coupleId,
    required this.repo,
  });

  @override
  State<ShoppingHubSection> createState() => _ShoppingHubSectionState();
}

class _ShoppingHubSectionState extends State<ShoppingHubSection> {
  bool _loading = true;
  List<Map<String, dynamic>> _lists = const [];

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    setState(() => _loading = true);
    final lists = await widget.repo.fetchShoppingLists(widget.coupleId);
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _loading = false;
    });
  }

  Future<void> _openShoppingPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoupleShoppingPage(
          coupleId: widget.coupleId,
          repo: widget.repo,
        ),
      ),
    );
    await _loadLists();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppPalette.isDark(context);
    final accent = isDark ? const Color(0xFFFF8FB1) : Colors.pink.shade600;
    final muted = isDark ? const Color(0xFFD8B9CB) : Colors.grey.shade700;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF2A1830), Color(0xFF1E1425)]
              : [Colors.white.withValues(alpha: 0.97), const Color(0xFFFFF1F4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF6B466F) : Colors.pinkAccent.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: 1,
            color: Colors.black.withValues(alpha: 0.14),
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x33FF8FB1)
                      : Colors.pinkAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.shopping_bag_outlined, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shopping Together',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lists created here belong to both partners only.',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _openShoppingPage,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.favorite_border_rounded,
                label: _lists.isEmpty ? 'No lists yet' : '${_lists.length} shared lists',
              ),
              const _InfoChip(
                icon: Icons.edit_note_rounded,
                label: 'Both can edit',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_lists.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.8),
              ),
              child: Text(
                'No shopping list yet. Create your first couple list and it will show here.',
                style: TextStyle(color: muted, height: 1.4),
              ),
            )
          else
            Column(
              children: _lists.take(3).map((list) {
                final description = list['description']?.toString() ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.85),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.list_alt_rounded, color: accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              list['name']?.toString() ?? 'Untitled list',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: muted, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _openShoppingPage,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppPalette.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
