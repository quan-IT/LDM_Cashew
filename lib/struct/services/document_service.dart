import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../models/doc_type.dart';
import '../models/study_document.dart';
import '../models/subject.dart';

/// Lớp nghiệp vụ xử lý logic Tài liệu Học tập (Tầng Business Logic theo kiến trúc Cashew)
class DocumentService {
  final AppDatabase _db;
  static const _uuid = Uuid();

  DocumentService(this._db);

  /// Kiểm tra tính hợp lệ của tài liệu trước khi lưu (Business Validation)
  String? validateDocument({
    required String title,
    required String subjectFk,
    String? fileUrl,
  }) {
    if (title.trim().isEmpty) {
      return 'Tiêu đề tài liệu không được để trống.';
    }
    if (title.trim().length < 3) {
      return 'Tiêu đề tài liệu phải có ít nhất 3 ký tự.';
    }
    if (subjectFk.trim().isEmpty) {
      return 'Vui lòng chọn môn học phù hợp.';
    }
    if (fileUrl != null && fileUrl.trim().isNotEmpty) {
      final uri = Uri.tryParse(fileUrl.trim());
      final isUrl = uri != null && (uri.isScheme('http') || uri.isScheme('https') || uri.isScheme('file'));
      if (!isUrl && !fileUrl.contains('.') && !fileUrl.startsWith('/')) {
        return 'Đường dẫn liên kết / tệp tin không hợp lệ.';
      }
    }
    return null;
  }

  /// Tạo mới tài liệu học tập
  Future<StudyDocument> createDocument({
    required String title,
    required String description,
    required String subjectFk,
    required DocType docType,
    required String fileUrl,
    required List<String> tags,
    bool isFavorite = false,
  }) async {
    final validationError = validateDocument(
      title: title,
      subjectFk: subjectFk,
      fileUrl: fileUrl,
    );
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final now = DateTime.now();
    final document = StudyDocument(
      documentPk: _uuid.v4(),
      title: title.trim(),
      description: description.trim(),
      subjectFk: subjectFk,
      docType: docType,
      fileUrl: fileUrl.trim(),
      tags: tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      isFavorite: isFavorite,
      dateCreated: now,
      dateTimeModified: now,
    );

    await _db.insertDocument(document);
    return document;
  }

  /// Cập nhật tài liệu học tập
  Future<void> updateDocument({
    required String documentPk,
    required String title,
    required String description,
    required String subjectFk,
    required DocType docType,
    required String fileUrl,
    required List<String> tags,
    required bool isFavorite,
    required DateTime dateCreated,
  }) async {
    final validationError = validateDocument(
      title: title,
      subjectFk: subjectFk,
      fileUrl: fileUrl,
    );
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final document = StudyDocument(
      documentPk: documentPk,
      title: title.trim(),
      description: description.trim(),
      subjectFk: subjectFk,
      docType: docType,
      fileUrl: fileUrl.trim(),
      tags: tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      isFavorite: isFavorite,
      dateCreated: dateCreated,
      dateTimeModified: DateTime.now(),
    );

    await _db.updateDocument(document);
  }

  /// Xóa tài liệu (kèm Tombstone log tự động ghi nhận trong persistence layer)
  Future<void> deleteDocument(String documentPk) async {
    await _db.deleteDocument(documentPk);
  }

  /// Đảo trạng thái yêu thích
  Future<void> toggleFavorite(String documentPk) async {
    await _db.toggleFavorite(documentPk);
  }

  /// Lọc và tìm kiếm tài liệu với thuật toán xếp hạng
  List<StudyDocument> filterAndSortDocuments({
    required List<StudyDocument> allDocs,
    String query = '',
    String? subjectFk,
    DocType? docType,
    bool onlyFavorites = false,
  }) {
    final cleanQuery = query.trim().toLowerCase();

    return allDocs.where((doc) {
      // Lọc theo yêu thích
      if (onlyFavorites && !doc.isFavorite) return false;

      // Lọc theo môn học
      if (subjectFk != null && subjectFk.isNotEmpty && doc.subjectFk != subjectFk) {
        return false;
      }

      // Lọc theo loại tài liệu
      if (docType != null && doc.docType != docType) {
        return false;
      }

      // Tìm kiếm từ khóa (Tiêu đề, Mô tả, Tags)
      if (cleanQuery.isNotEmpty) {
        final matchesTitle = doc.title.toLowerCase().contains(cleanQuery);
        final matchesDesc = doc.description.toLowerCase().contains(cleanQuery);
        final matchesTag = doc.tags.any((t) => t.toLowerCase().contains(cleanQuery));
        if (!matchesTitle && !matchesDesc && !matchesTag) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Tính toán số liệu thống kê tổng quan (Dashboard Metrics)
  Map<String, int> calculateStatistics(List<StudyDocument> documents) {
    int total = documents.length;
    int lectures = 0;
    int assignments = 0;
    int references = 0;
    int exams = 0;
    int favorites = 0;

    for (final doc in documents) {
      if (doc.isFavorite) favorites++;
      switch (doc.docType) {
        case DocType.lecture:
          lectures++;
          break;
        case DocType.assignment:
          assignments++;
          break;
        case DocType.reference:
          references++;
          break;
        case DocType.exam:
          exams++;
          break;
      }
    }

    return {
      'total': total,
      'lectures': lectures,
      'assignments': assignments,
      'references': references,
      'exams': exams,
      'favorites': favorites,
    };
  }

  /// Xuất gói dữ liệu sao lưu định dạng JSON (Chiến lược Local Backup Zero-Knowledge của Cashew)
  Future<String> exportBackupJson() async {
    final docs = await _db.getAllDocuments();
    final subjects = await _db.getAllSubjects();
    final deleteLogs = await _db.getAllDeleteLogs();

    final data = {
      'app': 'StudyMaterialsCashew',
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'subjects': subjects.map((s) => s.toMap()).toList(),
      'documents': docs.map((d) => d.toMap()).toList(),
      'deleteLogs': deleteLogs.map((l) => l.toMap()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Phục hồi dữ liệu từ chuỗi JSON sao lưu
  Future<int> importBackupJson(String jsonString) async {
    final dynamic data = jsonDecode(jsonString);
    if (data is! Map<String, dynamic> || !data.containsKey('documents')) {
      throw const FormatException('Định dạng tệp sao lưu không hợp lệ.');
    }

    int importedCount = 0;
    if (data['subjects'] is List) {
      for (final sMap in data['subjects']) {
        final subject = Subject.fromMap(sMap as Map<String, dynamic>);
        await _db.insertSubject(subject);
      }
    }

    if (data['documents'] is List) {
      for (final dMap in data['documents']) {
        final doc = StudyDocument.fromMap(dMap as Map<String, dynamic>);
        await _db.insertDocument(doc);
        importedCount++;
      }
    }

    return importedCount;
  }
}
