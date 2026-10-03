import 'dart:convert';
import 'doc_type.dart';

/// Đại diện cho tài liệu học tập (Tương đương bảng Transactions trong Cashew)
class StudyDocument {
  final String documentPk;
  final String title;
  final String description;
  final String subjectFk;
  final DocType docType;
  final String fileUrl;
  final List<String> tags;
  final bool isFavorite;
  final DateTime dateCreated;
  final DateTime dateTimeModified;

  StudyDocument({
    required this.documentPk,
    required this.title,
    required this.description,
    required this.subjectFk,
    required this.docType,
    required this.fileUrl,
    required this.tags,
    this.isFavorite = false,
    required this.dateCreated,
    required this.dateTimeModified,
  });

  StudyDocument copyWith({
    String? documentPk,
    String? title,
    String? description,
    String? subjectFk,
    DocType? docType,
    String? fileUrl,
    List<String>? tags,
    bool? isFavorite,
    DateTime? dateCreated,
    DateTime? dateTimeModified,
  }) {
    return StudyDocument(
      documentPk: documentPk ?? this.documentPk,
      title: title ?? this.title,
      description: description ?? this.description,
      subjectFk: subjectFk ?? this.subjectFk,
      docType: docType ?? this.docType,
      fileUrl: fileUrl ?? this.fileUrl,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      dateCreated: dateCreated ?? this.dateCreated,
      dateTimeModified: dateTimeModified ?? this.dateTimeModified,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'documentPk': documentPk,
      'title': title,
      'description': description,
      'subjectFk': subjectFk,
      'docType': docType.key,
      'fileUrl': fileUrl,
      'tags': jsonEncode(tags),
      'isFavorite': isFavorite ? 1 : 0,
      'dateCreated': dateCreated.toIso8601String(),
      'dateTimeModified': dateTimeModified.toIso8601String(),
    };
  }

  factory StudyDocument.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = [];
    final rawTags = map['tags'];
    if (rawTags is String && rawTags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) {
          parsedTags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        parsedTags = [];
      }
    } else if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    }

    return StudyDocument(
      documentPk: map['documentPk'] as String,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      subjectFk: map['subjectFk'] as String,
      docType: DocType.fromKey(map['docType'] as String?),
      fileUrl: (map['fileUrl'] as String?) ?? '',
      tags: parsedTags,
      isFavorite: (map['isFavorite'] as int? ?? 0) == 1,
      dateCreated: DateTime.tryParse(map['dateCreated'] as String? ?? '') ?? DateTime.now(),
      dateTimeModified: DateTime.tryParse(map['dateTimeModified'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
