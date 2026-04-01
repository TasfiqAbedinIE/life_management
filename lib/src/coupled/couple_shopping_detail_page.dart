import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'couple_repository.dart';

class CoupleShoppingDetailPage extends StatefulWidget {
  final String listId;
  final CoupleRepository repo;

  const CoupleShoppingDetailPage({
    super.key,
    required this.listId,
    required this.repo,
  });

  @override
  State<CoupleShoppingDetailPage> createState() => _CoupleShoppingDetailPageState();
}

class _CoupleShoppingDetailPageState extends State<CoupleShoppingDetailPage> {
  Map<String, dynamic>? _listMeta;
  List<Map<String, dynamic>> _items = [];
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
      final listMeta = await widget.repo.fetchShoppingList(widget.listId);
      final items = await widget.repo.fetchShoppingItems(widget.listId);

      final userIds = <String>{};
      final ownerId = listMeta['owner_id'] as String?;
      if (ownerId != null) userIds.add(ownerId);

      for (final item in items) {
        final createdBy = item['created_by'];
        if (createdBy != null) userIds.add(createdBy as String);
      }

      final profileMap = userIds.isEmpty
          ? <String, Map<String, dynamic>>{}
          : await widget.repo.fetchProfilesByIds(userIds);

      if (!mounted) return;
      setState(() {
        _listMeta = listMeta;
        _items = items;
        _userProfiles = profileMap;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load list: $e')));
    }
  }

  Future<void> _toggleItemDone(Map<String, dynamic> item) async {
    final itemId = item['id'] as String;
    final newValue = !(item['is_done'] as bool? ?? false);

    final error = await widget.repo.setShoppingItemDone(
      itemId: itemId,
      isDone: newValue,
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() {
      final index = _items.indexWhere((it) => it['id'] == itemId);
      if (index != -1) {
        _items[index] = {..._items[index], 'is_done': newValue};
      }
    });
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _AddOrEditItemSheet(
            listId: widget.listId,
            repo: widget.repo,
            existingItem: item,
          ),
        );
      },
    );

    if (saved == true) {
      await _loadAll();
    }
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
      final error = await widget.repo.deleteShoppingItem(item['id'] as String);
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      setState(() {
        _items.removeWhere((it) => it['id'] == item['id']);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _listMeta?['name']?.toString() ?? 'Shopping List';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                          padding: EdgeInsets.all(24),
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
                        return _ShoppingItemTile(
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

class _ShoppingItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final Map<String, dynamic>? creatorProfile;
  final VoidCallback onToggleDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ShoppingItemTile({
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
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: isDone,
              onChanged: (_) => onToggleDone(),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              qty.isNotEmpty ? '$name - $qty' : name,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                      Row(
                        children: [
                          Text(
                            tag,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[700],
                                ),
                          ),
                          if (targetDate != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 2),
                            Text(
                              '${targetDate.day.toString().padLeft(2, '0')}-'
                              '${targetDate.month.toString().padLeft(2, '0')}-'
                              '${targetDate.year}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                            ),
                          ],
                        ],
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          note,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (addedByLabel != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          addedByLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[500],
                                fontSize: 10,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Ribbon(color: urgencyColor),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
      size: const Size(12, 26),
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

class _AddOrEditItemSheet extends StatefulWidget {
  final String listId;
  final CoupleRepository repo;
  final Map<String, dynamic>? existingItem;

  const _AddOrEditItemSheet({
    required this.listId,
    required this.repo,
    this.existingItem,
  });

  @override
  State<_AddOrEditItemSheet> createState() => _AddOrEditItemSheetState();
}

class _AddOrEditItemSheetState extends State<_AddOrEditItemSheet> {
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
  String _urgency = 'medium';
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

    final error = widget.existingItem == null
        ? await widget.repo.addShoppingItem(
            listId: widget.listId,
            name: _nameCtrl.text.trim(),
            quantity: _qtyCtrl.text.trim().isEmpty ? null : _qtyCtrl.text.trim(),
            tag: _selectedTag,
            urgency: _urgency,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            targetDate: _targetDate,
          )
        : await widget.repo.updateShoppingItem(
            itemId: widget.existingItem!['id'] as String,
            name: _nameCtrl.text.trim(),
            quantity: _qtyCtrl.text.trim().isEmpty ? null : _qtyCtrl.text.trim(),
            tag: _selectedTag,
            urgency: _urgency,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            targetDate: _targetDate,
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
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
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
                    items: _tags.map((tag) => DropdownMenuItem(value: tag, child: Text(tag))).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedTag = value);
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
                      label: Text(_isSaving ? 'Saving...' : (isEdit ? 'Update' : 'Save')),
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
