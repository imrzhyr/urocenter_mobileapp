import 'dart:convert';

/// Represents a document uploaded by a user.
class DocumentModel {
  final String id;
  final String userId; // ID of the user who uploaded the document
  final String name; // Original filename
  final String type; // File extension or MIME type (e.g., 'pdf', 'jpg', 'png')
  final String url; // URL to access/download the document
  final DateTime uploadDate;
  final int? size; // File size in bytes (optional)

  DocumentModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.url,
    required this.uploadDate,
    this.size,
  });

  /// Create a copy with updated fields.
  DocumentModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    String? url,
    DateTime? uploadDate,
    int? size,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      url: url ?? this.url,
      uploadDate: uploadDate ?? this.uploadDate,
      size: size ?? this.size,
    );
  }

  /// Convert DocumentModel object to a Map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'type': type,
      'url': url,
      'upload_date': uploadDate.toIso8601String(),
      'size': size,
    };
  }

  /// Create DocumentModel object from a Map.
  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      name: map['name'] ?? 'Untitled Document',
      type: map['type'] ?? '',
      url: map['url'] ?? '',
      uploadDate: map['upload_date'] != null
          ? DateTime.parse(map['upload_date'])
          : DateTime.now(), // Consider a default or error handling
      size: map['size'],
    );
  }

  /// Convert DocumentModel object to JSON string.
  String toJson() => json.encode(toMap());

  /// Create DocumentModel object from JSON string.
  factory DocumentModel.fromJson(String source) =>
      DocumentModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'DocumentModel(id: $id, userId: $userId, name: $name, type: $type, url: $url, uploadDate: $uploadDate, size: $size)';
  }
} 