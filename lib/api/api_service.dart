// This file will handle all network requests to the Nextcloud API.
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/note.dart';

// Custom exception for handling 412 Precondition Failed errors.
class NoteConflictException implements Exception {
  final Note serverNote;
  NoteConflictException(this.serverNote);
}

class ApiService {
  final String baseUrl;
  final String username;
  final String password;

  ApiService({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  String get _apiEndpoint => '$baseUrl/index.php/apps/notes/api/v1/notes';
  String get _authHeader =>
      'Basic ${base64.encode(utf8.encode('$username:$password'))}';

  // Method to verify credentials by fetching notes.
  Future<bool> verifyCredentials() async {
    try {
      final response = await http.get(
        Uri.parse(_apiEndpoint),
        headers: {HttpHeaders.authorizationHeader: _authHeader},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Fetches all notes from the server.
  Future<List<Note>> fetchNotes() async {
    final response = await http.get(
      Uri.parse('$_apiEndpoint?exclude=content'), // Exclude content for faster list loading
      headers: {HttpHeaders.authorizationHeader: _authHeader},
    );

    if (response.statusCode == 200) {
      final List<dynamic> notesJson = json.decode(response.body);
      return notesJson.map((json) => Note.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load notes from server');
    }
  }
  
  // Fetches the full content of a single note.
  Future<Note?> fetchNoteDetails(int noteId, String localEtag) async {
    final response = await http.get(
      Uri.parse('$_apiEndpoint/$noteId'),
      headers: {
        HttpHeaders.authorizationHeader: _authHeader,
        'If-None-Match': '"$localEtag"',
      },
    );

    if (response.statusCode == 200) {
      return Note.fromJson(json.decode(response.body));
    } else if (response.statusCode == 304) {
      // 304 Not Modified means our local version is up-to-date.
      return null;
    } else {
      throw Exception('Failed to load note details');
    }
  }

  // Updates a note on the server.
  Future<Note> updateNote(Note note) async {
    final response = await http.put(
      Uri.parse('$_apiEndpoint/${note.id}'),
      headers: {
        HttpHeaders.authorizationHeader: _authHeader,
        HttpHeaders.contentTypeHeader: 'application/json',
        'If-Match': '"${note.etag}"', // ETags must be quoted
      },
      body: json.encode(note.toJsonForUpdate()),
    );

    if (response.statusCode == 200) {
      return Note.fromJson(json.decode(response.body));
    } else if (response.statusCode == 412) {
      // If there's a conflict, throw a custom exception with the server's version of the note.
      final serverNote = Note.fromJson(json.decode(response.body));
      throw NoteConflictException(serverNote);
    } else {
      throw Exception('Failed to update note.');
    }
  }

  // Creates a new note on the server.
  Future<Note> createNote(String title) async {
    final response = await http.post(
      Uri.parse(_apiEndpoint),
      headers: {
        HttpHeaders.authorizationHeader: _authHeader,
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: json.encode({'title': title, 'content': ''}),
    );

    if (response.statusCode == 200) {
      return Note.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create note.');
    }
  }

  // Deletes a note from the server.
  Future<void> deleteNote(int noteId) async {
    final response = await http.delete(
      Uri.parse('$_apiEndpoint/$noteId'),
      headers: {HttpHeaders.authorizationHeader: _authHeader},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete note.');
    }
  }
}