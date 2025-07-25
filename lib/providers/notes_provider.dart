// State management for notes using Provider.
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note.dart';
import '../services/auth_service.dart';
import '../api/api_service.dart';
import '../db/database_helper.dart';

enum SyncResult { success, failure }
enum FetchResult { success, notModified, failure }
enum UpdateResult { success, conflict, networkError }

class NotesProvider with ChangeNotifier {
  AuthService _authService;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  ApiService? _apiService;

  List<Note> _notes = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  NotesProvider(this._authService) {
    _initApiService();
  }

  void _initApiService() {
    if (_authService.isLoggedIn) {
      _apiService = ApiService(
        baseUrl: _authService.url!,
        username: _authService.username!,
        password: _authService.password!,
      );
    } else {
      _apiService = null;
    }
  }

  // Called by ChangeNotifierProxyProvider when AuthService changes.
  void updateAuth(AuthService authService) {
    _authService = authService;
    _initApiService();
  }

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;

  Future<SyncResult> initialize() async {
    if (_isInitialized || !_authService.isLoggedIn) return SyncResult.failure;
    _isLoading = true;
    notifyListeners();

    // Load notes from local DB first for a fast startup
    _notes = await _dbHelper.getAllNotes();
    _sortNotes();
    notifyListeners();

    // Then, trigger a sync with the server
    final result = await syncNotes();
    _isInitialized = true;
    return result;
  }
  
  Future<SyncResult> syncNotes() async {
    if (_apiService == null) return SyncResult.failure;

    _isLoading = true;
    notifyListeners();

    try {
      final serverNotes = await _apiService!
          .fetchNotes()
          .timeout(const Duration(seconds: 10));
      final serverNotesMap = { for (var note in serverNotes) note.id: note };
      
      final localNotes = await _dbHelper.getAllNotes();
      final localNotesMap = { for (var note in localNotes) note.id: note };

      final List<Note> notesToUpsert = [];
      
      for (final serverNote in serverNotes) {
        final localNote = localNotesMap[serverNote.id];
        if (localNote != null) {
          if (localNote.etag != serverNote.etag) {
            // Note has changed on server. Update metadata and clear content to force a re-download on open.
            notesToUpsert.add(serverNote.copyWith(content: ''));
          }
        } else {
          // Note is new from the server, add it as a stub
          notesToUpsert.add(serverNote);
        }
      }
      
      if (notesToUpsert.isNotEmpty) {
        await _dbHelper.batchInsertOrUpdate(notesToUpsert);
      }

      // Delete local notes that are no longer on the server
      for (final localNote in localNotes) {
        if (!serverNotesMap.containsKey(localNote.id)) {
          await _dbHelper.deleteNote(localNote.id);
        }
      }
      
      _notes = await _dbHelper.getAllNotes();
      _sortNotes();
      return SyncResult.success;
    } catch (e) {
      debugPrint("Sync failed: $e");
      return SyncResult.failure;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<FetchResult> fetchLatestNote(int noteId) async {
    final localNote = await _dbHelper.getNoteById(noteId);
    if (_apiService == null || localNote == null) return FetchResult.failure;

    // If local content is empty, we must fetch the full note, ignoring the etag.
    final etagToCompare = localNote.content.isEmpty ? '' : localNote.etag;

    try {
      final serverNote = await _apiService!.fetchNoteDetails(noteId, etagToCompare);
      if (serverNote != null) {
        // New version fetched, update local DB
        await _dbHelper.insertOrUpdateNote(serverNote);
        return FetchResult.success;
      } else {
        // 304 Not Modified, local version is current
        return FetchResult.notModified;
      }
    } catch (e) {
      debugPrint("Fetching latest note failed: $e");
      return FetchResult.failure;
    }
  }

  Future<Note?> getLocalNote(int noteId) async {
    return await _dbHelper.getNoteById(noteId);
  }

  Future<UpdateResult> updateNote(Note updatedNote) async {
    // Update locally first for instant UI feedback
    await _dbHelper.insertOrUpdateNote(updatedNote);
    final index = _notes.indexWhere((n) => n.id == updatedNote.id);
    if (index != -1) {
      _notes[index] = updatedNote;
      _sortNotes();
      notifyListeners();
    }

    if (_apiService == null) return UpdateResult.networkError;

    try {
      final syncedNote = await _apiService!.updateNote(updatedNote);
      await _dbHelper.insertOrUpdateNote(syncedNote);
      final syncedIndex = _notes.indexWhere((n) => n.id == syncedNote.id);
      if (syncedIndex != -1) {
        _notes[syncedIndex] = syncedNote;
      }
      return UpdateResult.success;
    } on NoteConflictException catch (e) {
      debugPrint("Conflict detected while updating note.");
      // The server sent back its version of the note. We save it.
      await _dbHelper.insertOrUpdateNote(e.serverNote);
      return UpdateResult.conflict;
    } catch (e) {
      debugPrint("Failed to sync updated note: $e");
      return UpdateResult.networkError;
    }
  }

  Future<Note?> createNote(String title) async {
    if (_apiService == null) return null;
    try {
      final newNote = await _apiService!.createNote(title);
      await _dbHelper.insertOrUpdateNote(newNote);
      _notes.add(newNote);
      _sortNotes();
      notifyListeners();
      return newNote;
    } catch (e) {
      debugPrint("Failed to create note: $e");
      return null;
    }
  }

  Future<void> deleteNote(int noteId) async {
    // Delete locally first
    await _dbHelper.deleteNote(noteId);
    _notes.removeWhere((note) => note.id == noteId);
    notifyListeners();

    // Then delete on the server
    if (_apiService != null) {
      try {
        await _apiService!.deleteNote(noteId);
      } catch (e) {
        debugPrint("Failed to delete note on server: $e");
        // Optionally, handle this error (e.g., mark for deletion later)
      }
    }
  }

  Future<void> forceGetNoteFromServer(int noteId) async {
    if (_apiService == null) return;
    try {
      final note = await _apiService!.fetchNoteDetails(noteId, ''); // Fetch without ETag to force download
      if (note != null) {
        await _dbHelper.insertOrUpdateNote(note);
      }
    } catch (e) {
      debugPrint("Failed to force get note from server: $e");
    }
  }

  void _sortNotes() {
    _notes.sort((a, b) {
      if (a.favorite && !b.favorite) return -1;
      if (!a.favorite && b.favorite) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
  }
  
  Future<void> clearLocalData() async {
    await _dbHelper.clearAllData();
    _notes = [];
    _isInitialized = false;
    notifyListeners();
  }
}