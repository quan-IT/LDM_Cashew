import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_material_app/database/app_database.dart';
import 'package:study_material_app/struct/models/doc_type.dart';
import 'package:study_material_app/struct/models/study_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.newInstance();
    await db.init(isInMemory: true);
  });

  tearDown(() async {
    await db.close();
  });

  group('Tầng Lưu Trữ Dữ Liệu Cục Bộ (Data Persistence Layer Tests)', () {
    test('Khởi tạo CSDL in-memory và kiểm tra dữ liệu mẫu (Default Data Seeding)', () async {
      final subjects = await db.getAllSubjects();
      final docs = await db.getAllDocuments();

      expect(subjects.isNotEmpty, isTrue);
      expect(docs.isNotEmpty, isTrue);
      expect(subjects.length, greaterThanOrEqualTo(4));
    });

    test('CRUD Tài liệu học tập (Insert, Read, Update, Delete)', () async {
      final now = DateTime.now();
      final newDoc = StudyDocument(
        documentPk: 'test-doc-001',
        title: 'Tài liệu Kiểm thử Kiến trúc Cashew',
        description: 'Mô tả kiểm thử tầng persistence',
        subjectFk: 'subj-mobile-001',
        docType: DocType.lecture,
        fileUrl: 'https://example.com/test.pdf',
        tags: ['Test', 'Cashew'],
        isFavorite: false,
        dateCreated: now,
        dateTimeModified: now,
      );

      // 1. Thêm (Insert)
      await db.insertDocument(newDoc);
      final fetched = await db.getDocumentById('test-doc-001');
      expect(fetched, isNotNull);
      expect(fetched!.title, equals('Tài liệu Kiểm thử Kiến trúc Cashew'));
      expect(fetched.tags, contains('Cashew'));

      // 2. Sửa (Update)
      final updated = fetched.copyWith(title: 'Tài liệu Kiểm thử Đã Cập Nhật', isFavorite: true);
      await db.updateDocument(updated);
      final refetched = await db.getDocumentById('test-doc-001');
      expect(refetched!.title, equals('Tài liệu Kiểm thử Đã Cập Nhật'));
      expect(refetched.isFavorite, isTrue);

      // 3. Xóa (Delete) và kiểm tra Tombstone DeleteLogs theo chuẩn Cashew
      await db.deleteDocument('test-doc-001');
      final deletedDoc = await db.getDocumentById('test-doc-001');
      expect(deletedDoc, isNull);

      final deleteLogs = await db.getAllDeleteLogs();
      expect(deleteLogs.any((log) => log.entryPk == 'test-doc-001'), isTrue);
    });

    test('Chuyển đổi trạng thái Yêu thích (toggleFavorite)', () async {
      final docs = await db.getAllDocuments();
      final target = docs.first;
      final originalFavorite = target.isFavorite;

      await db.toggleFavorite(target.documentPk);
      final updated = await db.getDocumentById(target.documentPk);

      expect(updated!.isFavorite, equals(!originalFavorite));
    });

    test('Reactive Streams phát tín hiệu khi có thay đổi dữ liệu', () async {
      final completer = Completer<List<StudyDocument>>();
      final sub = db.watchAllDocuments().listen((data) {
        if (!completer.isCompleted) completer.complete(data);
      });

      final doc = StudyDocument(
        documentPk: 'stream-doc-123',
        title: 'Stream Test',
        description: 'Desc',
        subjectFk: 'subj-mobile-001',
        docType: DocType.assignment,
        fileUrl: '',
        tags: [],
        dateCreated: DateTime.now(),
        dateTimeModified: DateTime.now(),
      );

      await db.insertDocument(doc);
      final emittedDocs = await completer.future.timeout(const Duration(seconds: 2));
      expect(emittedDocs.any((d) => d.documentPk == 'stream-doc-123'), isTrue);
      await sub.cancel();
    });
  });
}
