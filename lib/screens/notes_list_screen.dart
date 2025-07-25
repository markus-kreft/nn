import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notes_provider.dart';
import 'note_view_screen.dart';
import 'settings_screen.dart';
import '../models/note.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialLoad();
    });
  }

  Future<void> _handleInitialLoad() async {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final result = await provider.initialize();

    if (result == SyncResult.failure && mounted) {
      await _showFailureDialog();
    }
  }

  Future<void> _handleRefresh() async {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final result = await provider.syncNotes();

    if (result == SyncResult.failure && mounted) {
      await _showFailureDialog();
    }
  }
  
  Future<void> _showFailureDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sync Failed'),
        content: const Text('Could not connect to the server. Would you like to retry or work with the locally saved notes?'),
        actions: [
          TextButton(
            child: const Text('Work Offline'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Retry'),
            onPressed: () {
              Navigator.of(context).pop();
              _handleRefresh();
            },
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog() async {
    final titleController = TextEditingController();
    final String? newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New Note'),
          content: TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter note title'),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  Navigator.of(dialogContext).pop(titleController.text);
                }
              },
            ),
          ],
        );
      },
    );

    if (newTitle != null && mounted) {
      final provider = Provider.of<NotesProvider>(context, listen: false);
      final Note? newNote = await provider.createNote(newTitle);
      if (newNote != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NoteViewScreen(noteId: newNote.id),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          Consumer<NotesProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink(); // Return an empty widget when not loading
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNoteDialog,
        child: const Icon(Icons.add),
      ),
      body: Consumer<NotesProvider>(
        builder: (context, provider, child) {
          // This handles the very first launch when DB is empty.
          if (provider.notes.isEmpty && provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.notes.isEmpty) {
            return const Center(child: Text('No notes found.'));
          }
          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: ListView.builder(
              itemCount: provider.notes.length,
              itemBuilder: (context, index) {
                final note = provider.notes[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  title: Text(note.title),
                  leading: note.favorite
                      ? const Icon(Icons.star, color: Colors.amber)
                      : const Icon(Icons.star_border, color: Colors.grey),
                  onTap: provider.isLoading ? null : () { // Disable tap while loading
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NoteViewScreen(noteId: note.id),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}