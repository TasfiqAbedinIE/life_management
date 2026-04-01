import 'package:flutter/material.dart';

import 'couple_repository.dart';
import 'couple_shopping_detail_page.dart';

class CoupleShoppingPage extends StatefulWidget {
  final String coupleId;
  final CoupleRepository repo;

  const CoupleShoppingPage({
    super.key,
    required this.coupleId,
    required this.repo,
  });

  @override
  State<CoupleShoppingPage> createState() => _CoupleShoppingPageState();
}

class _CoupleShoppingPageState extends State<CoupleShoppingPage> {
  late Future<List<Map<String, dynamic>>> _futureLists;

  @override
  void initState() {
    super.initState();
    _futureLists = _fetchLists();
  }

  Future<List<Map<String, dynamic>>> _fetchLists() {
    return widget.repo.fetchShoppingLists(widget.coupleId);
  }

  Future<void> _refresh() async {
    setState(() {
      _futureLists = _fetchLists();
    });
    await _futureLists;
  }

  Future<void> _openCreateListSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _CreateListSheet(
            repo: widget.repo,
            coupleId: widget.coupleId,
          ),
        );
      },
    );

    if (created == true) {
      await _refresh();
    }
  }

  Future<void> _openList(Map<String, dynamic> list) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoupleShoppingDetailPage(
          listId: list['id'] as String,
          repo: widget.repo,
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shopping Together')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateListSheet,
        icon: const Icon(Icons.add),
        label: const Text('New List'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futureLists,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to load shopping lists\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            final lists = snapshot.data ?? [];
            if (lists.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  _ListEmptyState(
                    message: 'No shopping lists yet.\nCreate one and both partners will be able to update it.',
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: lists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final list = lists[index];
                return _ShoppingListCard(
                  listData: list,
                  onTap: () => _openList(list),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ShoppingListCard extends StatelessWidget {
  final Map<String, dynamic> listData;
  final VoidCallback onTap;

  const _ShoppingListCard({
    required this.listData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = listData['name']?.toString() ?? '';
    final description = listData['description']?.toString() ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                child: Icon(Icons.favorite_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.people_alt_outlined, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Shared with your better half',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateListSheet extends StatefulWidget {
  final CoupleRepository repo;
  final String coupleId;

  const _CreateListSheet({
    required this.repo,
    required this.coupleId,
  });

  @override
  State<_CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends State<_CreateListSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isSaving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final error = await widget.repo.createShoppingList(
      coupleId: widget.coupleId,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      setState(() => _isSaving = false);
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Text('Create Shopping List', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'List name',
                    hintText: 'e.g. Monthly Groceries',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'e.g. Kitchen and home items',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'This list will be visible and editable by both partners.',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(_isSaving ? 'Creating...' : 'Create'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListEmptyState extends StatelessWidget {
  final String message;

  const _ListEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 56),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
