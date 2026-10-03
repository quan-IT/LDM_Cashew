import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_material_app/database/app_database.dart';
import 'package:study_material_app/struct/models/doc_type.dart';
import 'package:study_material_app/struct/models/study_document.dart';
import 'package:study_material_app/struct/services/document_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late DocumentService service;

  setUp(() async {
    db = AppDatabase.newInstance();
    await db.init(isInMemory: true);
    service = DocumentService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Tầng Nghiệp Vụ (Business Logic Layer Tests)', () {
    test('Xác thực hợp lệ khi thêm tài liệu (Validation logic)', () {
      // Tiêu đề rỗng
      final err1 = service.validateDocument(
        title: '   ',
        subjectFk: 'subj-001',
      );
      expect(err1, isNotNull);
      expect(err1!.toLowerCase(), contains('tiêu đề'));

      // Môn học rỗng
      final err2 = service.validateDocument(
        title: 'Hợp lệ',
        subjectFk: '   ',
      );
      expect(err2, isNotNull);
      expect(err2!.toLowerCase(), contains('môn học'));

      // Dữ liệu hợp lệ
      final err3 = service.validateDocument(
        title: 'Lập trình Flutter nâng cao',
        subjectFk: 'subj-001',
        fileUrl: 'https://flutter.dev',
      );
      expect(err3, isNull);
    });

    test('Thuật toán tìm kiếm và lọc đa tiêu chí (Search & Multi-criteria Filtering)', () {
      final now = DateTime.now();
      final sampleDocs = [
        StudyDocument(
          documentPk: '1',
          title: 'Bài giảng Kiến trúc Cashew',
          description: 'Local-first architecture',
          subjectFk: 'arch',
          docType: DocType.lecture,
          fileUrl: '',
          tags: ['Cashew', 'Architecture'],
          isFavorite: true,
          dateCreated: now,
          dateTimeModified: now,
        ),
        StudyDocument(
          documentPk: '2',
          title: 'Bài tập SQLite',
          description: 'CRUD operations in Dart',
          subjectFk: 'mobile',
          docType: DocType.assignment,
          fileUrl: '',
          tags: ['Dart', 'Database'],
          isFavorite: false,
          dateCreated: now,
          dateTimeModified: now,
        ),
      ];

      // Tìm kiếm theo từ khóa
      final resTitle = service.filterAndSortDocuments(
        allDocs: sampleDocs,
        query: 'Cashew',
      );
      expect(resTitle.length, equals(1));
      expect(resTitle.first.documentPk, equals('1'));

      // Tìm kiếm theo tag
      final resTag = service.filterAndSortDocuments(
        allDocs: sampleDocs,
        query: 'Database',
      );
      expect(resTag.length, equals(1));
      expect(resTag.first.documentPk, equals('2'));

      // Lọc theo loại tài liệu
      final resType = service.filterAndSortDocuments(
        allDocs: sampleDocs,
        docType: DocType.assignment,
      );
      expect(resType.length, equals(1));
      expect(resType.first.title, contains('Bài tập'));

      // Lọc chỉ tài liệu yêu thích
      final resFav = service.filterAndSortDocuments(
        allDocs: sampleDocs,
        onlyFavorites: true,
      );
      expect(resFav.length, equals(1));
      expect(resFav.first.isFavorite, isTrue);
    });

    test('Tính toán số liệu thống kê Dashboard (calculateStatistics)', () {
      final now = DateTime.now();
      final sampleDocs = [
        StudyDocument(
          documentPk: '1',
          title: 'A',
          description: '',
          subjectFk: 's1',
          docType: DocType.lecture,
          fileUrl: '',
          tags: [],
          isFavorite: true,
          dateCreated: now,
          dateTimeModified: now,
        ),
        StudyDocument(
          documentPk: '2',
          title: 'B',
          description: '',
          subjectFk: 's1',
          docType: DocType.assignment,
          fileUrl: '',
          tags: [],
          isFavorite: false,
          dateCreated: now,
          dateTimeModified: now,
        ),
        StudyDocument(
          documentPk: '3',
          title: 'C',
          description: '',
          subjectFk: 's2',
          docType: DocType.reference,
          fileUrl: '',
          tags: [],
          isFavorite: true,
          dateCreated: now,
          dateTimeModified: now,
        ),
      ];

      final stats = service.calculateStatistics(sampleDocs);
      expect(stats['total'], equals(3));
      expect(stats['lectures'], equals(1));
      expect(stats['assignments'], equals(1));
      expect(stats['references'], equals(1));
      expect(stats['favorites'], equals(2));
    });

    test('Xuất và Nhập Gói Sao Lưu JSON (BYOS Backup & Restore)', () async {
      final jsonBackup = await service.exportBackupJson();
      expect(jsonBackup, contains('StudyMaterialsCashew'));
      expect(jsonBackup, contains('subjects'));
      expect(jsonBackup, contains('documents'));

      final importedCount = await service.importBackupJson(jsonBackup);
      expect(importedCount, greaterThan(0));
    });
  });
}
