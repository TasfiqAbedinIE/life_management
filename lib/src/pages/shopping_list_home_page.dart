import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'shopping_list_detail_page.dart';

final _supabase = Supabase.instance.client;

class ShoppingListHomePage extends StatefulWidget {
  const ShoppingListHomePage({super.key});

  @override
  State<ShoppingListHomePage> createState() => _ShoppingListHomePageState();
}

class _ShoppingListHomePageState extends State<ShoppingListHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openCreateListSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _CreateListSheet(
            onCreated: () {
              // refresh after create
              setState(() {});
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Lists'),
            Tab(text: 'Shared'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_MyShoppingListsView(), _SharedShoppingListsView()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreating ? null : _openCreateListSheet,
        icon: const Icon(Icons.add),
        label: Text(_isCreating ? 'Saving...' : 'New List'),
      ),
    );
  }
}

class _MyShoppingListsView extends StatefulWidget {
  const _MyShoppingListsView({Key? key}) : super(key: key);

  @override
  State<_MyShoppingListsView> createState() => _MyShoppingListsViewState();
}

class _MyShoppingListsViewState extends State<_MyShoppingListsView> {
  late Future<List<Map<String, dynamic>>> _futureLists;

  @override
  void initState() {
    super.initState();
    _futureLists = _fetchMyLists();
  }

  Future<List<Map<String, dynamic>>> _fetchMyLists() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final res = await _supabase
        .from('shopping_lists')
        .select('id, name, description, created_at, is_shared')
        .eq('owner_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> _refresh() async {
    setState(() {
      _futureLists = _fetchMyLists();
    });
    await _futureLists; // wait so RefreshIndicator shows properly
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureLists,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Failed to load lists\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          }

          final lists = snapshot.data ?? [];

          if (lists.isEmpty) {
            // Use ListView so pull-to-refresh works even when empty
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                ListEmptyState(
                  message:
                      'You don\'t have any shopping list yet.\nTap the + button to create one.',
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
              return ShoppingListCard(listData: list);
            },
          );
        },
      ),
    );
  }
}

class _SharedShoppingListsView extends StatefulWidget {
  const _SharedShoppingListsView({Key? key}) : super(key: key);

  @override
  State<_SharedShoppingListsView> createState() =>
      _SharedShoppingListsViewState();
}

class _SharedShoppingListsViewState extends State<_SharedShoppingListsView> {
  late Future<List<_SharedListWithCollabs>> _futureShared;

  @override
  void initState() {
    super.initState();
    _futureShared = _loadSharedLists();
  }

  Future<List<_SharedListWithCollabs>> _loadSharedLists() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    // 1) membership rows for this user
    final memRes = await _supabase
        .from('shopping_list_members')
        .select('list_id')
        .eq('user_id', user.id);

    final memRows = List<Map<String, dynamic>>.from(memRes as List);
    if (memRows.isEmpty) return [];

    final listIds = memRows.map((e) => e['list_id'] as String).toList();

    // 2) lists (exclude lists where the user is owner → those are in My Lists)
    final listRes = await _supabase
        .from('shopping_lists')
        .select('id, name, description, owner_id, is_shared, created_at')
        .inFilter('id', listIds)
        .neq('owner_id', user.id)
        .order('created_at', ascending: false);

    final lists = List<Map<String, dynamic>>.from(listRes as List);
    if (lists.isEmpty) return [];

    // 3) all members for these lists
    final memberRes = await _supabase
        .from('shopping_list_members')
        .select('list_id, user_id')
        .inFilter('list_id', lists.map((e) => e['id']).toList());

    final members = List<Map<String, dynamic>>.from(memberRes as List);

    // 4) unique user ids → profiles
    final userIds = <String>{
      for (final m in members) m['user_id'] as String,
      for (final l in lists) l['owner_id'] as String,
    }.toList();

    final profileRes = await _supabase
        .from('profiles')
        .select('id, full_name, email')
        .inFilter('id', userIds);

    final profiles = List<Map<String, dynamic>>.from(profileRes as List);
    final profileMap = {for (final p in profiles) p['id'] as String: p};

    // 5) build result objects
    return lists.map((l) {
      final id = l['id'] as String;

      final listMembers = members
          .where((m) => m['list_id'] == id)
          .map((m) => m['user_id'] as String)
          .toSet();

      // include owner as collaborator too
      listMembers.add(l['owner_id'] as String);

      final initials = <String>[];
      for (final uid in listMembers) {
        final prof = profileMap[uid];
        if (prof == null) continue;
        final fullName = (prof['full_name'] as String?)?.trim();
        final email = prof['email'] as String?;
        initials.add(_buildInitials(fullName, email));
        if (initials.length >= 3) break;
      }

      return _SharedListWithCollabs(
        data: l,
        collaboratorInitials: initials,
        totalCollaborator: listMembers.length,
      );
    }).toList();
  }

  static String _buildInitials(String? fullName, String? email) {
    if (fullName != null && fullName.isNotEmpty) {
      final parts = fullName.trim().split(RegExp(r'\s+'));
      if (parts.length == 1) {
        return parts.first.substring(0, 1).toUpperCase();
      } else {
        return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
            .toUpperCase();
      }
    }
    if (email != null && email.isNotEmpty) {
      return email.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  Future<void> _refresh() async {
    setState(() {
      _futureShared = _loadSharedLists();
    });
    await _futureShared;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<_SharedListWithCollabs>>(
        future: _futureShared,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Failed to load shared lists\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          }

          final sharedLists = snapshot.data ?? [];
          if (sharedLists.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No shared lists yet.\nAsk someone to invite you, or share your list with others.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: sharedLists.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final l = sharedLists[index];
              return ShoppingListCard(
                listData: l.data,
                collaboratorInitials: l.collaboratorInitials,
                totalCollaborators: l.totalCollaborator,
              );
            },
          );
        },
      ),
    );
  }
}

class _SharedListWithCollabs {
  final Map<String, dynamic> data;
  final List<String> collaboratorInitials;
  final int totalCollaborator;

  _SharedListWithCollabs({
    required this.data,
    required this.collaboratorInitials,
    required this.totalCollaborator,
  });
}

class ShoppingListCard extends StatelessWidget {
  final Map<String, dynamic> listData;

  // 👇 NEW (optional) fields
  final List<String>? collaboratorInitials;
  final int? totalCollaborators;

  const ShoppingListCard({
    super.key,
    required this.listData,
    this.collaboratorInitials,
    this.totalCollaborators,
  });

  @override
  Widget build(BuildContext context) {
    final name = listData['name']?.toString() ?? '';
    final description = listData['description']?.toString() ?? '';
    final isShared = (listData['is_shared'] as bool?) ?? false;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ShoppingListDetailPage(listId: listData['id'] as String),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                child: Icon(isShared ? Icons.group : Icons.person),
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
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isShared
                                ? 'Shared with ${totalCollaborators ?? 1} people'
                                : 'Private list',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[700]),
                          ),
                        ),
                        if ((collaboratorInitials?.isNotEmpty ?? false))
                          _CollaboratorAvatars(initials: collaboratorInitials!),
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

class _CollaboratorAvatars extends StatelessWidget {
  final List<String> initials;

  const _CollaboratorAvatars({required this.initials});

  @override
  Widget build(BuildContext context) {
    final toShow = initials.take(3).toList();

    return SizedBox(
      width: 24.0 + (toShow.length - 1) * 16.0,
      height: 28,
      child: Stack(
        children: [
          for (int i = 0; i < toShow.length; i++)
            Positioned(
              left: i * 16.0,
              child: CircleAvatar(
                radius: 12,
                child: Text(toShow[i], style: const TextStyle(fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }
}

class _CreateListSheet extends StatefulWidget {
  final VoidCallback onCreated;

  const _CreateListSheet({required this.onCreated});

  @override
  State<_CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends State<_CreateListSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isShared = false;
  bool _isSaving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      // 1) Insert into shopping_lists
      final inserted = await _supabase
          .from('shopping_lists')
          .insert({
            'owner_id': user.id,
            'name': _nameCtrl.text.trim(),
            'description': _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            'is_shared': _isShared,
          })
          .select()
          .single();

      final listId = inserted['id'];

      // 2) Add owner as member (role: owner)
      await _supabase.from('shopping_list_members').insert({
        'list_id': listId,
        'user_id': user.id,
        'role': 'owner',
      });

      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create list: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'e.g. All regular kitchen & home items',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isShared,
                  onChanged: (v) {
                    setState(() => _isShared = v);
                  },
                  title: const Text('Shared list'),
                  subtitle: const Text(
                    'If ON, you\'ll be able to invite friends later.',
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

class ListEmptyState extends StatelessWidget {
  final String message;

  const ListEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
