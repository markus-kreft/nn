// Data model for a single note.
class Note {
  final int id;
  final String etag;
  final String title;
  final String content;
  final int modified;
  final bool favorite;

  Note({
    required this.id,
    required this.etag,
    required this.title,
    this.content = '',
    required this.modified,
    required this.favorite,
  });

  // Factory constructor to create a Note from JSON (API response)
  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      etag: json['etag'],
      title: json['title'],
      content: json['content'] ?? '',
      modified: json['modified'],
      favorite: json['favorite'] ?? false,
    );
  }
  
  // Factory constructor to create a Note from a database map
  factory Note.fromDbMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      etag: map['etag'],
      title: map['title'],
      content: map['content'],
      modified: map['modified'],
      favorite: map['favorite'] == 1,
    );
  }

  // Method to convert a Note instance to a JSON map for API update requests
  Map<String, dynamic> toJsonForUpdate() {
    return {
      'title': title,
      'content': content,
      'favorite': favorite,
    };
  }
  
  // Method to convert a Note instance to a map for database storage
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'etag': etag,
      'title': title,
      'content': content,
      'modified': modified,
      'favorite': favorite ? 1 : 0,
    };
  }

  // Creates a new Note instance with updated content.
  Note copyWith({
    String? title,
    String? content,
    bool? favorite,
    String? etag,
    int? modified,
  }) {
    return Note(
      id: id,
      etag: etag ?? this.etag,
      title: title ?? this.title,
      content: content ?? this.content,
      modified: modified ?? this.modified,
      favorite: favorite ?? this.favorite,
    );
  }
}