import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:undo/undo.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class NoteViewScreen extends StatefulWidget {
  final int noteId;
  const NoteViewScreen({super.key, required this.noteId});

  @override
  State<NoteViewScreen> createState() => _NoteViewScreenState();
}

class _NoteViewScreenState extends State<NoteViewScreen> {
  final _contentController = TextEditingController();
  late final SimpleStack<TextEditingValue> _undoStack;
  Note? _currentNote;
  bool _isInitialized = false;
  bool _isEditMode = true;

  @override
  void initState() {
    super.initState();
    _loadNoteContent();
  }

  Future<void> _loadNoteContent({bool isRetry = false}) async {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    
    if (!isRetry) {
      setState(() {
        _isInitialized = false;
      });
    }

    final result = await provider.fetchLatestNote(widget.noteId);
    if (result == FetchResult.failure && mounted) {
      await _showOfflineDialog();
    }
    
    // Whether fetch succeeded, was not modified, or user chose offline, load from DB
    final note = await provider.getLocalNote(widget.noteId);
    if (note == null) return; // Should not happen

    if (!_isInitialized) {
      _contentController.text = note.content;
      _undoStack = SimpleStack<TextEditingValue>(
        TextEditingValue(text: note.content),
        onUpdate: (value) => _contentController.value = value,
      );
      _contentController.addListener(_onTextChanged);
    }
    
    setState(() {
      _currentNote = note;
      _isInitialized = true;
    });
  }

  Future<void> _showOfflineDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sync Failed'),
        content: const Text('Could not fetch the latest version of this note. Work with the local version?'),
        actions: [
          TextButton(
            child: const Text('Retry'),
            onPressed: () {
              Navigator.of(context).pop();
              _loadNoteContent(isRetry: true);
            },
          ),
          TextButton(
            child: const Text('Work Offline'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _onTextChanged() {
    if (_contentController.value != _undoStack.state) {
      _undoStack.modify(_contentController.value);
    }
  }

  @override
  void dispose() {
    _contentController.removeListener(_onTextChanged);
    _contentController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_isInitialized) return true;

    final provider = Provider.of<NotesProvider>(context, listen: false);
    final originalNote = await provider.getLocalNote(widget.noteId);

    // Check if anything has changed
    if (_contentController.text != originalNote!.content ||
        _currentNote!.title != originalNote.title ||
        _currentNote!.favorite != originalNote.favorite) {
      
      final updatedNote = originalNote.copyWith(
        title: _currentNote!.title,
        content: _contentController.text,
        favorite: _currentNote!.favorite,
        modified: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      
      // Show blocking loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final result = await provider.updateNote(updatedNote);
      
      Navigator.of(context).pop(); // Dismiss loading indicator

      if (result == UpdateResult.conflict && mounted) {
        await _showConflictDialog();
        return false; // Don't pop, stay on the page
      } else if (result == UpdateResult.networkError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved locally. Could not sync with server.')),
        );
      }
    }
    return true; // Allow pop
  }

  Future<void> _showConflictDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sync Conflict'),
        content: const Text('This note was changed on the server. Discard your changes and load the server version, or continue editing?'),
        actions: [
          TextButton(
            child: const Text('Discard Changes'),
            onPressed: () async {
              final provider = Provider.of<NotesProvider>(context, listen: false);
              await provider.forceGetNoteFromServer(widget.noteId);
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to list
            },
          ),
          TextButton(
            child: const Text('Edit'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showEditTitleDialog() {
    final titleController = TextEditingController(text: _currentNote!.title);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Title'),
          content: TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter new title'),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                setState(() {
                  _currentNote = _currentNote!.copyWith(title: titleController.text);
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Note?'),
          content: const Text('Are you sure you want to delete this note? This action cannot be undone.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                final provider = Provider.of<NotesProvider>(context, listen: false);
                await provider.deleteNote(widget.noteId);
                if (mounted) {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to list
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentNote?.title ?? 'Loading...'),
          actions: [
            if (_isInitialized) ...[
              IconButton(
                icon: Icon(_isEditMode ? Icons.visibility : Icons.edit),
                onPressed: () {
                  setState(() {
                    _isEditMode = !_isEditMode;
                  });
                },
              ),
              if (_isEditMode) ...[
                IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: _undoStack.canUndo ? _undoStack.undo : null,
                ),
                IconButton(
                  icon: const Icon(Icons.redo),
                  onPressed: _undoStack.canRedo ? _undoStack.redo : null,
                ),
                PopupMenuButton<int>(
                  onSelected: (value) {
                    if (value == 0) { // Favorite
                      setState(() {
                        _currentNote = _currentNote!.copyWith(favorite: !_currentNote!.favorite);
                      });
                    } else if (value == 1) { // Edit Title
                      _showEditTitleDialog();
                    } else if (value == 2) { // Delete
                      _showDeleteDialog();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<int>(
                      value: 0,
                      child: Row(
                        children: [
                          Icon(
                            _currentNote!.favorite
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          const SizedBox(width: 16),
                          const Text('Favorite'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<int>(
                      value: 1,
                      child: Text('Edit Title'),
                    ),
                    const PopupMenuItem<int>(
                      value: 2,
                      child: Text('Delete Note'),
                    ),
                  ],
                ),
              ]
            ]
          ],
        ),
        body: SafeArea(
          child: !_isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _isEditMode
                      ? TextField(
                          controller: _contentController,
                          maxLines: null,
                          expands: true,
                          style: GoogleFonts.notoSansMono(
                            letterSpacing: 0.0,
                            fontSize: themeProvider.fontSize,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Start writing your note...',
                          ),
                        )
                      : MarkdownWidget(
                          data: _contentController.text,
                          config: MarkdownConfig(
                            configs: [
                              PreConfig(theme: isDarkMode ? a11yDarkTheme : githubTheme),
                              CodeConfig(
                                style: GoogleFonts.notoSansMono(
                                  backgroundColor: isDarkMode ? const Color(0xff2b2b2b) : Colors.grey[200],
                                  fontSize: themeProvider.fontSize,
                                ),
                              ),
                              PConfig(
                                textStyle: TextStyle(
                                  fontSize: themeProvider.fontSize,
                                ),
                              ),
                              H1Config(
                                style: TextStyle(
                                  fontSize: themeProvider.fontSize * 1.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              H2Config(
                                style: TextStyle(
                                  fontSize: themeProvider.fontSize * 1.3,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              H3Config(
                                style: TextStyle(
                                  fontSize: themeProvider.fontSize * 1.1,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
        ),
      ),
    );
  }
}
