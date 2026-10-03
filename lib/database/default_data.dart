import 'package:uuid/uuid.dart';
import '../struct/models/subject.dart';
import '../struct/models/study_document.dart';
import '../struct/models/doc_type.dart';

class DefaultData {
  static const uuid = Uuid();

  static final String subjectMobilePk = 'subj-mobile-001';
  static final String subjectArchPk = 'subj-arch-002';
  static final String subjectDbPk = 'subj-db-003';
  static final String subjectAiPk = 'subj-ai-004';

  static List<Subject> getInitialSubjects() {
    final now = DateTime.now();
    return [
      Subject(
        subjectPk: subjectMobilePk,
        name: 'Lập trình Thiết bị Di động',
        code: 'MOB301',
        colour: '#1E88E5',
        iconName: 'smartphone',
        dateTimeModified: now,
      ),
      Subject(
        subjectPk: subjectArchPk,
        name: 'Kiến trúc & Thiết kế Phần mềm',
        code: 'SWE302',
        colour: '#00897B',
        iconName: 'architecture',
        dateTimeModified: now,
      ),
      Subject(
        subjectPk: subjectDbPk,
        name: 'Cơ sở Dữ liệu & Lưu trữ',
        code: 'DAT201',
        colour: '#FB8C00',
        iconName: 'storage',
        dateTimeModified: now,
      ),
      Subject(
        subjectPk: subjectAiPk,
        name: 'Trí tuệ Nhân tạo Ứng dụng',
        code: 'AIE401',
        colour: '#8E24AA',
        iconName: 'psychology',
        dateTimeModified: now,
      ),
    ];
  }

  static List<StudyDocument> getInitialDocuments() {
    final now = DateTime.now();
    return [
      StudyDocument(
        documentPk: 'doc-001',
        title: 'Slide Bài giảng Kiến trúc Ứng dụng Cashew',
        description: 'Phân tích chi tiết mô hình Local-First, Drift ORM, Tombstone Sync và BYOS Cloud.',
        subjectFk: subjectArchPk,
        docType: DocType.lecture,
        fileUrl: 'https://github.com/jameskokoska/Cashew',
        tags: ['Cashew', 'Architecture', 'Local-First', 'Clean-Architecture'],
        isFavorite: true,
        dateCreated: now.subtract(const Duration(days: 3)),
        dateTimeModified: now.subtract(const Duration(days: 3)),
      ),
      StudyDocument(
        documentPk: 'doc-002',
        title: 'Lab 1: Xây dựng App Quản lý Tài liệu theo Kiến trúc Cashew',
        description: 'Đặc tả yêu cầu 5 mục checklist, phân tách 3 lớp UI - Logic - Persistence.',
        subjectFk: subjectMobilePk,
        docType: DocType.assignment,
        fileUrl: 'https://github.com/quan-IT/LDM_Cashew.git',
        tags: ['Flutter', 'Lab1', 'Cashew', 'SQLite'],
        isFavorite: true,
        dateCreated: now.subtract(const Duration(days: 1)),
        dateTimeModified: now,
      ),
      StudyDocument(
        documentPk: 'doc-003',
        title: 'Giáo trình Thiết kế Schema & Migration trong SQLite',
        description: 'Kỹ thuật đánh version schema, viết câu lệnh OnUpgrade và tối ưu truy vấn Indexing.',
        subjectFk: subjectDbPk,
        docType: DocType.reference,
        fileUrl: 'https://sqlite.org/docs.html',
        tags: ['Database', 'SQLite', 'SchemaMigration'],
        isFavorite: false,
        dateCreated: now.subtract(const Duration(days: 5)),
        dateTimeModified: now.subtract(const Duration(days: 5)),
      ),
      StudyDocument(
        documentPk: 'doc-004',
        title: 'Tổng hợp Bộ đề thi Trắc nghiệm Lập trình Flutter & Dart',
        description: 'Ngân hàng câu hỏi State Management (Provider, Bloc), Widget Lifecycle và Asynchronous Dart.',
        subjectFk: subjectMobilePk,
        docType: DocType.exam,
        fileUrl: '',
        tags: ['Flutter', 'DeThi', 'StateManagement'],
        isFavorite: false,
        dateCreated: now.subtract(const Duration(days: 2)),
        dateTimeModified: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
}
