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
  bool _thumbnailView = true;

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
              _ViewModeToggle(
                thumbnailView: _thumbnailView,
                onChanged: (value) => setState(() => _thumbnailView = value),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_notes.isEmpty)
                const _EmptyNotes()
              else ...[
                if (_thumbnailView)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _notes.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 1.05,
                        ),
                    itemBuilder: (context, index) =>
                        _buildNoteCard(_notes[index], thumbnail: true),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildNoteCard(_notes[index], thumbnail: false),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteCard(Note note, {required bool thumbnail}) {
    return _NoteCard(
      note: note,
      subtitleDate: _formatDate(note.updatedAt),
      thumbnail: thumbnail,
      onTap: () => _openEditor(note: note),
      onDelete: () => _deleteNote(note),
      onPin: () async {
        if (note.id == null) return;
        await _repo.setPinned(id: note.id!, pinned: !note.isPinned);
        await _load();
      },
    );
  }
}

class _ViewModeToggle extends StatelessWidget {
  final bool thumbnailView;
  final ValueChanged<bool> onChanged;

  const _ViewModeToggle({required this.thumbnailView, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Your notes',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: true,
              icon: Icon(Icons.grid_view_rounded),
              tooltip: 'Thumbnail view',
            ),
            ButtonSegment(
              value: false,
              icon: Icon(Icons.view_list_rounded),
              tooltip: 'List view',
            ),
          ],
          selected: {thumbnailView},
          onSelectionChanged: (value) => onChanged(value.first),
        ),
      ],
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
  final bool thumbnail;

  const _NoteCard({
    required this.note,
    required this.subtitleDate,
    required this.onTap,
    required this.onDelete,
    required this.onPin,
    required this.thumbnail,
  });

  @override
  Widget build(BuildContext context) {
    final title = note.title.trim().isEmpty ? 'Untitled' : note.title.trim();
    return Material(
      color: Color(note.colorValue),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(thumbnail ? 14 : 16),
          child: thumbnail
              ? _ThumbnailCardContent(
                  note: note,
                  title: title,
                  date: subtitleDate,
                  onPin: onPin,
                  onDelete: onDelete,
                )
              : _ListCardContent(
                  note: note,
                  title: title,
                  date: subtitleDate,
                  onPin: onPin,
                  onDelete: onDelete,
                ),
        ),
      ),
    );
  }
}

class _ThumbnailCardContent extends StatelessWidget {
  final Note note;
  final String title;
  final String date;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  const _ThumbnailCardContent({
    required this.note,
    required this.title,
    required this.date,
    required this.onPin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NoteTypeBadge(type: note.type),
        const SizedBox(height: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          date,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.black.withValues(alpha: 0.58),
          ),
        ),
        const SizedBox(height: 4),
        _NoteActions(note: note, onPin: onPin, onDelete: onDelete),
      ],
    );
  }
}

class _ListCardContent extends StatelessWidget {
  final Note note;
  final String title;
  final String date;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  const _ListCardContent({
    required this.note,
    required this.title,
    required this.date,
    required this.onPin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NoteTypeBadge(type: note.type),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                date,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _NoteActions(note: note, onPin: onPin, onDelete: onDelete),
      ],
    );
  }
}

class _NoteTypeBadge extends StatelessWidget {
  final NoteType type;

  const _NoteTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _NoteActions extends StatelessWidget {
  final Note note;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  const _NoteActions({
    required this.note,
    required this.onPin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPin,
          tooltip: note.isPinned ? 'Unpin note' : 'Pin note',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            size: 20,
          ),
        ),
        IconButton(
          onPressed: onDelete,
          tooltip: 'Delete note',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
        ),
      ],
    );
  }
}
