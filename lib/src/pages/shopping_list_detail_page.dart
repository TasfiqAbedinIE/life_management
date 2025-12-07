import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class ShoppingListDetailPage extends StatefulWidget {
  final String listId;

  const ShoppingListDetailPage({super.key, required this.listId});

  @override
  State<ShoppingListDetailPage> createState() => _ShoppingListDetailPageState();
}

class _ShoppingListDetailPageState extends State<ShoppingListDetailPage> {
  Map<String, dynamic>? _listMeta;
  List<Map<String, dynamic>> _items = [];

  // 👇 NEW: profile cache by userId
  Map<String, Map<String, dynamic>> _userProfiles = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    try {
      // 1) list meta (including owner_id)
      final listRes = await _supabase
          .from('shopping_lists')
          .select('id, name, description, is_shared, owner_id')
          .eq('id', widget.listId)
          .single();

      final listMeta = Map<String, dynamic>.from(listRes as Map);

      // 2) items (including created_by)
      final itemsRes = await _supabase
          .from('shopping_items')
          .select(
            'id, name, quantity, tag, target_date, urgency, note, is_done, created_at, created_by',
          )
          .eq('list_id', widget.listId)
          .order('is_done', ascending: true)
          .order('target_date', ascending: true);

      final items = List<Map<String, dynamic>>.from(itemsRes as List);

      // 3) collect userIds (owner + creators)
      final userIds = <String>{};
      final ownerId = listMeta['owner_id'] as String?;
      if (ownerId != null) userIds.add(ownerId);

      for (final it in items) {
        final cb = it['created_by'];
        if (cb != null) userIds.add(cb as String);
      }

      Map<String, Map<String, dynamic>> profileMap = {};
      if (userIds.isNotEmpty) {
        final profRes = await _supabase
            .from('profiles')
            .select('id, full_name, email')
            .inFilter('id', userIds.toList());

        final profs = List<Map<String, dynamic>>.from(profRes as List);
        profileMap = {for (final p in profs) p['id'] as String: p};
      }

      setState(() {
        _listMeta = listMeta;
        _items = items;
        _userProfiles = profileMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load list: $e')));
    }
  }

  Future<void> _toggleItemDone(Map<String, dynamic> item) async {
    final id = item['id'];
    final newValue = !(item['is_done'] as bool? ?? false);

    try {
      await _supabase
          .from('shopping_items')
          .update({'is_done': newValue})
          .eq('id', id);

      setState(() {
        final idx = _items.indexWhere((it) => it['id'] == id);
        if (idx != -1) {
          _items[idx] = {..._items[idx], 'is_done': newValue};
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update item: $e')));
    }
  }

  Future<void> _openAddOrEditItemSheet({Map<String, dynamic>? item}) async {
    final saved = await showModalBottomSheet<bool>(
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
          child: AddOrEditItemSheet(listId: widget.listId, existingItem: item),
        );
      },
    );

    if (saved == true) {
      await _loadAll();
    }
  }

  Future<void> _showInviteFriendDialog() async {
    final emailCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Invite friend'),
          content: TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Friend\'s email'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty) return;

                try {
                  await _inviteByEmail(email);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Friend added to this list!'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text('Invite'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _inviteByEmail(String email) async {
    // 1) Look up the user in profiles by email
    final profilesRes = await _supabase
        .from('profiles')
        .select('id, email, full_name')
        .eq('email', email);

    final profiles = List<Map<String, dynamic>>.from(profilesRes as List);

    if (profiles.isEmpty) {
      throw Exception(
        'No user found with this email. '
        'Make sure they have signed up in the app.',
      );
    }

    final friend = profiles.first;
    final friendId = friend['id'] as String;

    // 2) Add as member (user_id is Supabase Auth user.id)
    await _supabase.from('shopping_list_members').insert({
      'list_id': widget.listId,
      'user_id': friendId,
      'role': 'editor',
    });

    // 3) Ensure list is marked as shared
    await _supabase
        .from('shopping_lists')
        .update({'is_shared': true})
        .eq('id', widget.listId);

    // 4) Refresh UI
    await _loadAll();
  }

  Future<void> _confirmAndDeleteItem(Map<String, dynamic> item) async {
    final name = item['name']?.toString() ?? 'this item';

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete item?'),
          content: Text('Are you sure you want to delete "$name"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteItem(item);
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final id = item['id'];
    try {
      await _supabase.from('shopping_items').delete().eq('id', id);

      setState(() {
        _items.removeWhere((it) => it['id'] == id);
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item deleted')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete item: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _listMeta?['name']?.toString() ?? 'Shopping List';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Invite friend',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _showInviteFriendDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddOrEditItemSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              'No items yet.\nTap "Add item" to start.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ShoppingItemTile(
                          item: item,
                          creatorProfile: _userProfiles[item['created_by']],
                          onToggleDone: () => _toggleItemDone(item),
                          onEdit: () => _openAddOrEditItemSheet(item: item),
                          onDelete: () => _confirmAndDeleteItem(item),
                        );
                      },
                    ),
            ),
    );
  }
}

class ShoppingItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final Map<String, dynamic>? creatorProfile;
  final VoidCallback onToggleDone;
  final VoidCallback onEdit;

  // 👇 NEW
  final VoidCallback onDelete;

  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.creatorProfile,
    required this.onToggleDone,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = item['is_done'] as bool? ?? false;
    final name = item['name']?.toString() ?? '';
    final qty = item['quantity']?.toString() ?? '';
    final tag = item['tag']?.toString() ?? 'Others';
    final urgency = item['urgency']?.toString() ?? 'medium';
    final note = item['note']?.toString() ?? '';

    DateTime? targetDate;
    final rawDate = item['target_date'];
    if (rawDate != null) {
      targetDate = DateTime.tryParse(rawDate.toString());
    }

    String? addedByLabel;
    if (creatorProfile != null) {
      final fullName = (creatorProfile!['full_name'] as String?)?.trim();
      final email = creatorProfile!['email'] as String?;
      final currentUserId = _supabase.auth.currentUser?.id;
      final creatorId = creatorProfile!['id'] as String?;

      if (creatorId != null && creatorId == currentUserId) {
        addedByLabel = 'Added by you';
      } else if (fullName != null && fullName.isNotEmpty) {
        addedByLabel = 'Added by $fullName';
      } else if (email != null && email.isNotEmpty) {
        addedByLabel = 'Added by $email';
      }
    }

    Color urgencyColor;
    switch (urgency) {
      case 'high':
        urgencyColor = Colors.red;
        break;
      case 'low':
        urgencyColor = Colors.green;
        break;
      default:
        urgencyColor = Colors.orange;
    }

    // 🔹 COMPACT CARD
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Checkbox
            Checkbox(
              value: isDone,
              onChanged: (_) => onToggleDone(),
              visualDensity: VisualDensity.compact,
            ),

            // Main content
            Expanded(
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First row: name + qty
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              qty.isNotEmpty ? '$name · $qty' : name,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 2),

                      // Second row: tag, date
                      Row(
                        children: [
                          // Tag
                          Text(
                            tag,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[700]),
                          ),
                          if (targetDate != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${targetDate.day.toString().padLeft(2, '0')}-'
                              '${targetDate.month.toString().padLeft(2, '0')}-'
                              '${targetDate.year}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[700]),
                            ),
                          ],
                        ],
                      ),

                      // Optional note / added by (smaller, single line each)
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          note,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (addedByLabel != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          addedByLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[500], fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Right side: urgency dot + edit/delete icons
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // urgency dot
                _Ribbon(color: urgencyColor),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  final Color color;

  const _Ribbon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(12, 26), // ribbon size
      painter: _RibbonPainter(color),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  final Color color;

  _RibbonPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.7)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height * 0.7)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AddOrEditItemSheet extends StatefulWidget {
  final String listId;
  final Map<String, dynamic>? existingItem;

  const AddOrEditItemSheet({
    super.key,
    required this.listId,
    this.existingItem,
  });

  @override
  State<AddOrEditItemSheet> createState() => _AddOrEditItemSheetState();
}

class _AddOrEditItemSheetState extends State<AddOrEditItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  final _tags = const [
    'Groceries',
    'Home appliance',
    'Electronics',
    'Personal care',
    'Office',
    'Others',
  ];

  String _selectedTag = 'Groceries';
  String _urgency = 'medium'; // low, medium, high
  DateTime? _targetDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    if (item != null) {
      _nameCtrl.text = item['name']?.toString() ?? '';
      _qtyCtrl.text = item['quantity']?.toString() ?? '';
      _noteCtrl.text = item['note']?.toString() ?? '';
      _selectedTag = item['tag']?.toString() ?? _selectedTag;
      _urgency = item['urgency']?.toString() ?? _urgency;

      final rawDate = item['target_date'];
      if (rawDate != null) {
        _targetDate = DateTime.tryParse(rawDate.toString());
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _targetDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );

    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Not logged in');
      }

      final payload = <String, dynamic>{
        'list_id': widget.listId,
        'name': _nameCtrl.text.trim(),
        'quantity': _qtyCtrl.text.trim().isEmpty ? null : _qtyCtrl.text.trim(),
        'tag': _selectedTag,
        'urgency': _urgency,
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        'target_date': _targetDate?.toIso8601String().split('T').first,
        'created_by': user.id,
      };

      if (widget.existingItem == null) {
        // insert
        await _supabase.from('shopping_items').insert(payload);
      } else {
        // update
        await _supabase
            .from('shopping_items')
            .update(payload)
            .eq('id', widget.existingItem!['id']);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save item: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingItem != null;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: SingleChildScrollView(
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
            Text(
              isEdit ? 'Edit item' : 'Add item',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Item name',
                      hintText: 'e.g. Rice, Electric kettle',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _qtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quantity (optional)',
                      hintText: 'e.g. 2 kg, 3 pcs',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedTag,
                    items: _tags
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedTag = v);
                    },
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Urgency', style: theme.textTheme.bodyMedium),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Low'),
                        selected: _urgency == 'low',
                        onSelected: (_) => setState(() => _urgency = 'low'),
                      ),
                      ChoiceChip(
                        label: const Text('Medium'),
                        selected: _urgency == 'medium',
                        onSelected: (_) => setState(() => _urgency = 'medium'),
                      ),
                      ChoiceChip(
                        label: const Text('High'),
                        selected: _urgency == 'high',
                        onSelected: (_) => setState(() => _urgency = 'high'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _targetDate == null
                              ? 'No date selected'
                              : 'Purchase on: '
                                    '${_targetDate!.day.toString().padLeft(2, '0')}-'
                                    '${_targetDate!.month.toString().padLeft(2, '0')}-'
                                    '${_targetDate!.year}',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Pick date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      hintText: 'Any extra info',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: const Icon(Icons.check),
                      label: Text(
                        _isSaving ? 'Saving...' : (isEdit ? 'Update' : 'Save'),
                      ),
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
