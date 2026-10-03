import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../struct/models/delete_log.dart';
import '../struct/models/doc_type.dart';
import '../struct/models/study_document.dart';
import '../struct/models/subject.dart';
import 'default_data.dart';
import 'tables.dart';

/// Lớp quản lý CSDL cục bộ theo triết lý Local-First & Reactive của Cashew
class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  /// Tạo instance riêng biệt cho kiểm thử (không dùng singleton)
  factory AppDatabase.newInstance() => AppDatabase._internal();

  Database? _db;
  static const String _dbName = 'study_documents.db';
  static const int _schemaVersion = 1;

  // StreamControllers mô phỏng cơ chế Reactive Streams (watchAll...) của Drift ORM trong Cashew
  StreamController<List<StudyDocument>> _documentsStreamController =
      StreamController<List<StudyDocument>>.broadcast();

  StreamController<List<Subject>> _subjectsStreamController =
      StreamController<List<Subject>>.broadcast();

  Stream<List<StudyDocument>> watchAllDocuments() => _documentsStreamController.stream;
  Stream<List<Subject>> watchAllSubjects() => _subjectsStreamController.stream;

  /// Khởi tạo và mở database
  Future<void> init({bool isInMemory = false}) async {
    if (_db != null && _db!.isOpen) return;

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (isInMemory) {
      path = inMemoryDatabasePath;
    } else {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      path = p.join(documentsDirectory.path, _dbName);
    }

    _db = await openDatabase(
      path,
      version: _schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Kích hoạt phát luồng dữ liệu ban đầu
    await _notifyDocumentsChanged();
    await _notifySubjectsChanged();
  }

  /// Tạo bảng khi lần đầu khởi tạo
  Future<void> _onCreate(Database db, int version) async {
    await db.execute(Tables.createSubjectsTable);
    await db.execute(Tables.createStudyDocumentsTable);
    await db.execute(Tables.createDeleteLogsTable);
    await db.execute(Tables.createSubjectIndex);
    await db.execute(Tables.createDateCreatedIndex);

    // Seed dữ liệu mẫu mặc định
    for (final subject in DefaultData.getInitialSubjects()) {
      await db.insert(Tables.subjectsTable, subject.toMap());
    }

    for (final doc in DefaultData.getInitialDocuments()) {
      await db.insert(Tables.studyDocumentsTable, doc.toMap());
    }
  }

  /// Nâng cấp lược đồ database (Schema Migration như Cashew schemaVersionGlobal)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Sẵn sàng cho việc migration dữ liệu khi nâng cấp app
  }

  Database get db {
    if (_db == null || !_db!.isOpen) {
      throw Exception('Database chưa được khởi tạo. Vui lòng gọi AppDatabase.init() trước.');
    }
    return _db!;
  }

  // ==================== THÔNG BÁO REACTIVE STREAMS ====================

  Future<void> _notifyDocumentsChanged() async {
    if (_documentsStreamController.hasListener) {
      final docs = await getAllDocuments();
      _documentsStreamController.add(docs);
    }
  }

  Future<void> _notifySubjectsChanged() async {
    if (_subjectsStreamController.hasListener) {
      final subjects = await getAllSubjects();
      _subjectsStreamController.add(subjects);
    }
  }

  // ==================== CRUD TÀI LIỆU HỌC TẬP (STUDY DOCUMENTS) ====================

  /// Thêm tài liệu mới
  Future<int> insertDocument(StudyDocument document) async {
    final result = await db.insert(
      Tables.studyDocumentsTable,
      document.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _notifyDocumentsChanged();
    return result;
  }

  /// Sửa / Cập nhật tài liệu
  Future<int> updateDocument(StudyDocument document) async {
    final updatedDoc = document.copyWith(dateTimeModified: DateTime.now());
    final result = await db.update(
      Tables.studyDocumentsTable,
      updatedDoc.toMap(),
      where: 'documentPk = ?',
      whereArgs: [document.documentPk],
    );
    await _notifyDocumentsChanged();
    return result;
  }

  /// Xóa tài liệu học tập & Ghi log Tombstone theo chuẩn Cashew
  Future<int> deleteDocument(String documentPk) async {
    return await db.transaction((txn) async {
      // 1. Ghi vết vào DeleteLogs phục vụ đồng bộ phân tán
      final deleteLog = DeleteLog(
        deleteLogPk: const Uuid().v4(),
        entryPk: documentPk,
        tableType: 1, // Document
        dateTimeModified: DateTime.now(),
      );
      await txn.insert(Tables.deleteLogsTable, deleteLog.toMap());

      // 2. Xóa bản ghi vật lý
      final deletedRows = await txn.delete(
        Tables.studyDocumentsTable,
        where: 'documentPk = ?',
        whereArgs: [documentPk],
      );

      // 3. Thông báo cho UI cập nhật
      _notifyDocumentsChanged();
      return deletedRows;
    });
  }

  /// Lấy toàn bộ tài liệu (Sắp xếp mới nhất lên đầu)
  Future<List<StudyDocument>> getAllDocuments() async {
    final result = await db.query(
      Tables.studyDocumentsTable,
      orderBy: 'isFavorite DESC, dateCreated DESC',
    );
    return result.map((e) => StudyDocument.fromMap(e)).toList();
  }

  /// Lấy tài liệu theo Primary Key
  Future<StudyDocument?> getDocumentById(String documentPk) async {
    final result = await db.query(
      Tables.studyDocumentsTable,
      where: 'documentPk = ?',
      whereArgs: [documentPk],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return StudyDocument.fromMap(result.first);
  }

  /// Chuyển đổi trạng thái Yêu thích
  Future<void> toggleFavorite(String documentPk) async {
    final doc = await getDocumentById(documentPk);
    if (doc != null) {
      final updated = doc.copyWith(isFavorite: !doc.isFavorite);
      await updateDocument(updated);
    }
  }

  /// Tìm kiếm và lọc tài liệu học tập
  Future<List<StudyDocument>> searchDocuments({
    String query = '',
    String? subjectFk,
    DocType? docType,
    bool? onlyFavorites,
  }) async {
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (query.trim().isNotEmpty) {
      final cleanQuery = '%${query.trim()}%';
      whereClauses.add('(title LIKE ? OR description LIKE ? OR tags LIKE ?)');
      whereArgs.addAll([cleanQuery, cleanQuery, cleanQuery]);
    }

    if (subjectFk != null && subjectFk.isNotEmpty) {
      whereClauses.add('subjectFk = ?');
      whereArgs.add(subjectFk);
    }

    if (docType != null) {
      whereClauses.add('docType = ?');
      whereArgs.add(docType.key);
    }

    if (onlyFavorites == true) {
      whereClauses.add('isFavorite = 1');
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final result = await db.query(
      Tables.studyDocumentsTable,
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'isFavorite DESC, dateCreated DESC',
    );

    return result.map((e) => StudyDocument.fromMap(e)).toList();
  }

  // ==================== CRUD MÔN HỌC (SUBJECTS) ====================

  Future<int> insertSubject(Subject subject) async {
    final result = await db.insert(
      Tables.subjectsTable,
      subject.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _notifySubjectsChanged();
    return result;
  }

  Future<int> updateSubject(Subject subject) async {
    final updated = subject.copyWith(dateTimeModified: DateTime.now());
    final result = await db.update(
      Tables.subjectsTable,
      updated.toMap(),
      where: 'subjectPk = ?',
      whereArgs: [subject.subjectPk],
    );
    await _notifySubjectsChanged();
    return result;
  }

  Future<int> deleteSubject(String subjectPk) async {
    return await db.transaction((txn) async {
      // Ghi log xóa
      final deleteLog = DeleteLog(
        deleteLogPk: const Uuid().v4(),
        entryPk: subjectPk,
        tableType: 0, // Subject
        dateTimeModified: DateTime.now(),
      );
      await txn.insert(Tables.deleteLogsTable, deleteLog.toMap());

      // Xóa tất cả tài liệu thuộc môn này
      await txn.delete(
        Tables.studyDocumentsTable,
        where: 'subjectFk = ?',
        whereArgs: [subjectPk],
      );

      final result = await txn.delete(
        Tables.subjectsTable,
        where: 'subjectPk = ?',
        whereArgs: [subjectPk],
      );

      _notifySubjectsChanged();
      _notifyDocumentsChanged();
      return result;
    });
  }

  Future<List<Subject>> getAllSubjects() async {
    final result = await db.query(
      Tables.subjectsTable,
      orderBy: 'name ASC',
    );
    return result.map((e) => Subject.fromMap(e)).toList();
  }

  Future<Subject?> getSubjectById(String subjectPk) async {
    final result = await db.query(
      Tables.subjectsTable,
      where: 'subjectPk = ?',
      whereArgs: [subjectPk],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Subject.fromMap(result.first);
  }

  // ==================== TOMBSTONE DELETE LOGS ====================

  Future<List<DeleteLog>> getAllDeleteLogs() async {
    final result = await db.query(
      Tables.deleteLogsTable,
      orderBy: 'dateTimeModified DESC',
    );
    return result.map((e) => DeleteLog.fromMap(e)).toList();
  }

  Future<void> clearDeleteLogs() async {
    await db.delete(Tables.deleteLogsTable);
  }

  /// Đóng cơ sở dữ liệu
  Future<void> close() async {
    if (!_documentsStreamController.isClosed) {
      await _documentsStreamController.close();
    }
    if (!_subjectsStreamController.isClosed) {
      await _subjectsStreamController.close();
    }
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _db = null;
    // Tái tạo StreamControllers để instance có thể được dùng lại
    _documentsStreamController = StreamController<List<StudyDocument>>.broadcast();
    _subjectsStreamController = StreamController<List<Subject>>.broadcast();
  }
}
