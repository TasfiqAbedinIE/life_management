import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/notes_repository.dart';
import '../models/note.dart';
import '../services/smart_note_assistant.dart';

class NoteEditorPage extends StatefulWidget {
  final Note? note;

  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _repo = NotesRepository.instance;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  static const _palette = [
    0xFFFFF7E8,
    0xFFE8F7EE,
    0xFFE9F0FF,
    0xFFFFE7F1,
    0xFFFCEBDA,
    0xFFEDE7FF,
  ];

  bool _saving = false;
  late bool _isPinned;
  late int _selectedColor;
  late NoteType _selectedType;
  late List<String> _tags;
  late List<_ChecklistItemState> _checklistItems;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleCtrl.text = note?.title ?? '';
    _contentCtrl.text = note?.content ?? '';
    _isPinned = note?.isPinned ?? false;
    _selectedColor = note?.colorValue ?? _palette.first;
    _selectedType = note?.type ?? NoteType.rich;
    _tags = [...?note?.tags];
    _checklistItems = _selectedType == NoteType.checklist
        ? _parseChecklistItems(_contentCtrl.text)
        : <_ChecklistItemState>[];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    for (final item in _checklistItems) {
      item.controller.dispose();
    }
    super.dispose();
  }

  bool get _hasText =>
      _titleCtrl.text.trim().isNotEmpty ||
      (_selectedType == NoteType.checklist
          ? _checklistItems.any(
              (item) => item.controller.text.trim().isNotEmpty,
            )
          : _contentCtrl.text.trim().isNotEmpty);

  Future<void> _saveIfNeeded() async {
    if (_saving || !_hasText) return;

    setState(() => _saving = true);

    final now = DateTime.now();
    if (_selectedType == NoteType.checklist) {
      _contentCtrl.text = _serializeChecklistItems();
    }

    final note = Note(
      id: widget.note?.id,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      createdAt: widget.note?.createdAt ?? now,
      updatedAt: now,
      isPinned: _isPinned,
      colorValue: _selectedColor,
      tags: _tags,
      type: _selectedType,
    );

    if (widget.note?.id == null) {
      await _repo.insertNote(note);
    } else {
      await _repo.updateNote(note);
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<bool> _onWillPop() async {
    await _saveIfNeeded();
    return true;
  }

  List<_ChecklistItemState> _parseChecklistItems(String raw) {
    final lines = raw
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return [_ChecklistItemState(text: '')];
    }

    return lines.map((line) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('- [x] ')) {
        return _ChecklistItemState(
          text: trimmed.substring(6).trim(),
          checked: true,
        );
      }
      if (trimmed.startsWith('- [ ] ')) {
        return _ChecklistItemState(text: trimmed.substring(6).trim());
      }
      return _ChecklistItemState(text: trimmed);
    }).toList();
  }

  String _serializeChecklistItems() {
    return _checklistItems
        .where((item) => item.controller.text.trim().isNotEmpty)
        .map(
          (item) =>
              '- [${item.checked ? 'x' : ' '}] ${item.controller.text.trim()}',
        )
        .join('\n');
  }

  void _toggleChecklistItem(int index, bool? value) {
    setState(() {
      _checklistItems[index].checked = value ?? false;
    });
  }

  void _addChecklistItem() {
    setState(() {
      _checklistItems = [..._checklistItems, _ChecklistItemState(text: '')];
    });
  }

  void _removeChecklistItem(int index) {
    final item = _checklistItems[index];
    item.controller.dispose();
    setState(() {
      _checklistItems = [
        for (int i = 0; i < _checklistItems.length; i++)
          if (i != index) _checklistItems[i],
      ];
    });
    if (_checklistItems.isEmpty) {
      _addChecklistItem();
    }
  }

  Future<void> _openSmartAssist() async {
    final sourceContent = _selectedType == NoteType.checklist
        ? _serializeChecklistItems()
        : _contentCtrl.text;
    final insight = SmartNoteAssistant.generate(
      title: _titleCtrl.text,
      content: sourceContent,
      type: _selectedType,
    );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'On-device smart assist',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'These suggestions are generated locally from your note content.',
                    style: TextStyle(color: AppPalette.mutedText(context)),
                  ),
                  const SizedBox(height: 18),
                  _AssistCard(
                    title: 'Summary',
                    body: insight.summary,
                    actionLabel: 'Use as intro',
                    onApply: () {
                      if (_selectedType == NoteType.checklist) {
                        Navigator.pop(context);
                        return;
                      }
                      final current = _contentCtrl.text.trim();
                      setState(() {
                        _contentCtrl.text = current.isEmpty
                            ? insight.summary
                            : '${insight.summary}\n\n$current';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  _AssistCard(
                    title: 'Suggested title',
                    body: insight.suggestedTitle,
                    actionLabel: 'Apply title',
                    onApply: () {
                      setState(() => _titleCtrl.text = insight.suggestedTitle);
                      Navigator.pop(context);
                    },
                  ),
                  _AssistCard(
                    title: 'Suggested tags',
                    body: insight.suggestedTags
                        .map((tag) => '#$tag')
                        .join('  '),
                    actionLabel: 'Add tags',
                    onApply: () {
                      setState(() {
                        _tags = {..._tags, ...insight.suggestedTags}.toList();
                      });
                      Navigator.pop(context);
                    },
                  ),
                  _AssistCard(
                    title: 'Detected action items',
                    body: insight.actionItems.isEmpty
                        ? 'No clear action items detected yet.'
                        : insight.actionItems.join('\n'),
                    actionLabel: insight.actionItems.isEmpty
                        ? null
                        : 'Append checklist',
                    onApply: insight.actionItems.isEmpty
                        ? null
                        : () {
                            setState(() {
                              for (final item in insight.actionItems) {
                                _checklistItems = [
                                  ..._checklistItems,
                                  _ChecklistItemState(text: item),
                                ];
                              }
                            });
                            Navigator.pop(context);
                          },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppPalette.surfaceAlt(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppPalette.border(context)),
                    ),
                    child: Text(
                      'Tone: ${insight.tone} | Estimated read: ${insight.estimatedReadingMinutes} min',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectCanvasColor() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Canvas color',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: _palette.map((color) {
                  final selected = color == _selectedColor;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedColor = color);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? Colors.black.withValues(alpha: 0.8)
                              : Colors.black.withValues(alpha: 0.15),
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      child: selected ? const Icon(Icons.check_rounded) : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope keeps the existing save-before-back behavior.
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Color(_selectedColor),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              onPressed: () => setState(() => _isPinned = !_isPinned),
              tooltip: _isPinned ? 'Unpin' : 'Pin',
              icon: Icon(
                _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              ),
            ),
            IconButton(
              onPressed: _openSmartAssist,
              tooltip: 'Smart assist',
              icon: const Icon(Icons.auto_awesome_rounded),
            ),
            IconButton(
              onPressed: _selectCanvasColor,
              tooltip: 'Canvas color',
              icon: const Icon(Icons.palette_outlined),
            ),
            IconButton(
              onPressed: () async {
                await _saveIfNeeded();
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              tooltip: 'Save',
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.56),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.52),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Give this note a strong title',
                              labelText: 'Title',
                            ),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 14),
                          if (_selectedType == NoteType.checklist)
                            _ChecklistEditor(
                              items: _checklistItems,
                              onChanged: () => setState(() {}),
                              onToggle: _toggleChecklistItem,
                              onAdd: _addChecklistItem,
                              onRemove: _removeChecklistItem,
                            )
                          else
                            TextField(
                              controller: _contentCtrl,
                              minLines: 24,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              decoration: const InputDecoration(
                                hintText:
                                    'Capture the details, outline, or next steps...',
                                labelText: 'Content',
                                alignLabelWithHint: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistCard extends StatelessWidget {
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onApply;

  const _AssistCard({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(height: 1.35)),
          if (actionLabel != null && onApply != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onApply, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _ChecklistItemState {
  bool checked;
  final TextEditingController controller;

  _ChecklistItemState({required String text, this.checked = false})
    : controller = TextEditingController(text: text);
}

class _ChecklistEditor extends StatelessWidget {
  final List<_ChecklistItemState> items;
  final VoidCallback onChanged;
  final void Function(int index, bool? value) onToggle;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const _ChecklistEditor({
    required this.items,
    required this.onChanged,
    required this.onToggle,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        ...List.generate(items.length, (index) {
          final item = items[index];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: item.checked,
                onChanged: (value) => onToggle(index, value),
                shape: const CircleBorder(),
                visualDensity: VisualDensity.compact,
                side: BorderSide(
                  color: colors.onSurface.withValues(alpha: 0.45),
                  width: 1.6,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: item.controller,
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) {
                    if (index == items.length - 1) onAdd();
                  },
                  textInputAction: TextInputAction.next,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    decoration: item.checked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: item.checked
                        ? colors.onSurface.withValues(alpha: 0.5)
                        : colors.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'List item',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: colors.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: colors.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onRemove(index),
                tooltip: 'Remove item',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 19,
                  color: colors.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 8),
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.add_rounded, color: colors.primary),
                const SizedBox(width: 12),
                Text(
                  'Add item',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 280),
      ],
    );
  }
}
