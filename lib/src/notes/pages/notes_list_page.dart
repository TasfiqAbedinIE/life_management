import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../data/notes_repository.dart';
import '../models/note.dart';
import 'note_editor_page.dart';

class NotesListPage extends StatefulWidget {
  const NotesListPage({super.key});

  @override
  State<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends State<NotesListPage> {
  final _repo = NotesRepository.instance;
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  List<Note> _notes = [];
  NoteType? _selectedType;
  bool _pinnedOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_load);
  }

  @override
  void dispose() {
    _searchCtrl
      ..removeListener(_load)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _repo.searchNotes(
      query: _searchCtrl.text,
      type: _selectedType,
      pinnedOnly: _pinnedOnly,
    );
    if (!mounted) return;
    setState(() {
      _notes = data;
      _loading = false;
    });
  }

  Future<void> _openEditor({Note? note, NoteType? templateType}) async {
    final seed = templateType == null
        ? note
        : Note(
            title: '',
            content: _starterForType(templateType),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            type: templateType,
            colorValue: _paletteForType(templateType),
            tags: _defaultTagsForType(templateType),
          );

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorPage(note: seed)),
    );
    await _load();
  }

  Future<void> _deleteNote(Note note) async {
    if (note.id == null) return;
    await _repo.deleteNote(note.id!);
    await _load();
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd MMM | hh:mm a').format(dt);
  }

  int _paletteForType(NoteType type) {
    return switch (type) {
      NoteType.rich => 0xFFFFF7E8,
      NoteType.checklist => 0xFFE8F7EE,
      NoteType.meeting => 0xFFE9F0FF,
      NoteType.idea => 0xFFFFE7F1,
    };
  }

  List<String> _defaultTagsForType(NoteType type) {
    return switch (type) {
      NoteType.rich => const ['capture'],
      NoteType.checklist => const ['to-do'],
      NoteType.meeting => const ['meeting'],
      NoteType.idea => const ['idea'],
    };
  }

  String _starterForType(NoteType type) {
    return switch (type) {
      NoteType.rich => '',
      NoteType.checklist =>
        '- [ ] First task\n- [ ] Second task\n- [ ] Third task',
      NoteType.meeting =>
        'Agenda\n- \n\nKey discussion points\n- \n\nDecisions\n- \n\nFollow-ups\n- [ ] ',
      NoteType.idea => 'Concept\n\nWhy it matters\n\nNext experiment\n- ',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      appBar: AppBar(title: const Text('Notes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.auto_awesome_outlined),
        label: const Text('New note'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
            children: [
              _SearchBar(
                controller: _searchCtrl,
                onClear: () {
                  _searchCtrl.clear();
                  _load();
                },
              ),
              const SizedBox(height: 16),
              _QuickCaptureRow(
                onSelect: (type) => _openEditor(templateType: type),
              ),
              const SizedBox(height: 16),
              _FilterChips(
                selectedType: _selectedType,
                pinnedOnly: _pinnedOnly,
                onTypeChanged: (type) {
                  setState(() => _selectedType = type);
                  _load();
                },
                onPinnedChanged: (value) {
                  setState(() => _pinnedOnly = value);
                  _load();
                },
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_notes.isEmpty)
                const _EmptyNotes()
              else ...[
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _notes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.88,
                  ),
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return _NoteCard(
                      note: note,
                      subtitleDate: _formatDate(note.updatedAt),
                      onTap: () => _openEditor(note: note),
                      onDelete: () => _deleteNote(note),
                      onPin: () async {
                        if (note.id == null) return;
                        await _repo.setPinned(
                          id: note.id!,
                          pinned: !note.isPinned,
                        );
                        await _load();
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;

  const _SearchBar({required this.controller, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
        hintText: 'Search by title, content, or tags',
      ),
    );
  }
}

class _QuickCaptureRow extends StatelessWidget {
  final ValueChanged<NoteType> onSelect;

  const _QuickCaptureRow({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final items = [
      (type: NoteType.rich, icon: Icons.notes_rounded, label: 'Quick note'),
      (
        type: NoteType.checklist,
        icon: Icons.checklist_rounded,
        label: 'Checklist',
      ),
      (type: NoteType.meeting, icon: Icons.groups_rounded, label: 'Meeting'),
      (
        type: NoteType.idea,
        icon: Icons.lightbulb_outline_rounded,
        label: 'Idea',
      ),
    ];

    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => onSelect(item.type),
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPalette.surface(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppPalette.border(context)),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.softShadow(context),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      item.icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final NoteType? selectedType;
  final bool pinnedOnly;
  final ValueChanged<NoteType?> onTypeChanged;
  final ValueChanged<bool> onPinnedChanged;

  const _FilterChips({
    required this.selectedType,
    required this.pinnedOnly,
    required this.onTypeChanged,
    required this.onPinnedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: selectedType == null,
            onSelected: (_) => onTypeChanged(null),
          ),
          const SizedBox(width: 8),
          ...NoteType.values.expand(
            (type) => [
              ChoiceChip(
                label: Text(type.label),
                selected: selectedType == type,
                onSelected: (_) => onTypeChanged(type),
              ),
              const SizedBox(width: 8),
            ],
          ),
          FilterChip(
            label: const Text('Pinned only'),
            selected: pinnedOnly,
            onSelected: onPinnedChanged,
          ),
        ],
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppPalette.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppPalette.border(context)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_stories_outlined,
              size: 34,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nothing matches yet',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Start with a quick note, meeting recap, or checklist to build your workspace.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppPalette.mutedText(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final String subtitleDate;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPin;

  const _NoteCard({
    required this.note,
    required this.subtitleDate,
    required this.onTap,
    required this.onDelete,
    required this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    final title = note.title.trim().isEmpty ? 'Untitled' : note.title.trim();
    final content = note.content.trim();

    return Material(
      color: Color(note.colorValue),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
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
                      color: Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      note.type.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (note.isPinned)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.push_pin_rounded, size: 18),
                    ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'pin') onPin();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: Text(note.isPinned ? 'Unpin note' : 'Pin note'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete note'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  content.isEmpty ? 'Tap to keep writing.' : content,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
              ),
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: note.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                subtitleDate,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
