import 'package:flutter/material.dart';
import '../data/notes_repository.dart';
import '../models/note.dart';

class NoteEditorPage extends StatefulWidget {
  final Note? note;
  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _repo = NotesRepository.instance;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  bool get _hasText =>
      _titleCtrl.text.trim().isNotEmpty || _contentCtrl.text.trim().isNotEmpty;

  Future<void> _saveIfNeeded() async {
    if (_saving) return;

    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    // If user didn't type anything, don't create empty note
    if (!_hasText) return;

    setState(() => _saving = true);

    final now = DateTime.now();
    if (widget.note == null) {
      await _repo.insertNote(
        Note(title: title, content: content, createdAt: now, updatedAt: now),
      );
    } else {
      await _repo.updateNote(
        widget.note!.copyWith(title: title, content: content, updatedAt: now),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<bool> _onWillPop() async {
    await _saveIfNeeded();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
          actions: [
            IconButton(
              onPressed: () async {
                await _saveIfNeeded();
                if (!mounted) return;
                Navigator.pop(context);
              },
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              tooltip: 'Save',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                textInputAction: TextInputAction.next,
              ),
              const Divider(height: 12),
              Expanded(
                child: TextField(
                  controller: _contentCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Start writing...',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
