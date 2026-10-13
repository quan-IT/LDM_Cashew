import 'dart:convert';

/// Model tài liệu trên Supabase (bảng documents)
class CloudDocument {
  final String id; // UUID - PK
  final String ownerUid; // Firebase UID chủ sở hữu
  final String title;
  final String description;
  final String subject;
  final String docType; // lecture, assignment, reference, exam
  final String storageUrl; // Legacy bearer URL; kept empty for new uploads
  final String storagePath; // Object path trong bucket Supabase Storage private
  final String fileName;
  final int fileSize; // bytes
  final List<String> tags;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CloudDocument({
    required this.id,
    required this.ownerUid,
    required this.title,
    required this.description,
    required this.subject,
    required this.docType,
    required this.storageUrl,
    required this.storagePath,
    required this.fileName,
    required this.fileSize,
    required this.tags,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CloudDocument.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = [];
    final rawTags = map['tags'];
    if (rawTags is String && rawTags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) {
          parsedTags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    } else if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    }

    return CloudDocument(
      id: map['id'] as String,
      ownerUid: map['owner_uid'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      docType: map['doc_type'] as String? ?? 'reference',
      storageUrl: map['storage_url'] as String? ?? '',
      storagePath: map['storage_path'] as String? ?? '',
      fileName: map['file_name'] as String? ?? '',
      fileSize: (map['file_size'] as num?)?.toInt() ?? 0,
      tags: parsedTags,
      isFavorite: map['is_favorite'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_uid': ownerUid,
      'title': title,
      'description': description,
      'subject': subject,
      'doc_type': docType,
      'storage_url': storageUrl,
      'storage_path': storagePath,
      'file_name': fileName,
      'file_size': fileSize,
      'tags': jsonEncode(tags),
      'is_favorite': isFavorite,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CloudDocument copyWith({
    String? id,
    String? ownerUid,
    String? title,
    String? description,
    String? subject,
    String? docType,
    String? storageUrl,
    String? storagePath,
    String? fileName,
    int? fileSize,
    List<String>? tags,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CloudDocument(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      docType: docType ?? this.docType,
      storageUrl: storageUrl ?? this.storageUrl,
      storagePath: storagePath ?? this.storagePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Dung lượng file được định dạng đẹp
  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024)
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
