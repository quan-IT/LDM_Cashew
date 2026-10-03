/// Định nghĩa cấu trúc các bảng SQLite theo chuẩn kiến trúc Cashew
class Tables {
  static const String subjectsTable = 'Subjects';
  static const String studyDocumentsTable = 'StudyDocuments';
  static const String deleteLogsTable = 'DeleteLogs';

  static const String createSubjectsTable = '''
    CREATE TABLE IF NOT EXISTS $subjectsTable (
      subjectPk TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      code TEXT,
      colour TEXT NOT NULL,
      iconName TEXT NOT NULL,
      dateTimeModified TEXT NOT NULL
    );
  ''';

  static const String createStudyDocumentsTable = '''
    CREATE TABLE IF NOT EXISTS $studyDocumentsTable (
      documentPk TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT,
      subjectFk TEXT NOT NULL,
      docType TEXT NOT NULL,
      fileUrl TEXT,
      tags TEXT NOT NULL,
      isFavorite INTEGER NOT NULL DEFAULT 0,
      dateCreated TEXT NOT NULL,
      dateTimeModified TEXT NOT NULL,
      FOREIGN KEY (subjectFk) REFERENCES $subjectsTable (subjectPk) ON DELETE CASCADE
    );
  ''';

  static const String createDeleteLogsTable = '''
    CREATE TABLE IF NOT EXISTS $deleteLogsTable (
      deleteLogPk TEXT PRIMARY KEY,
      entryPk TEXT NOT NULL,
      tableType INTEGER NOT NULL,
      dateTimeModified TEXT NOT NULL
    );
  ''';

  // Chỉ mục tối ưu tốc độ tìm kiếm và liên kết khóa ngoại
  static const String createSubjectIndex = '''
    CREATE INDEX IF NOT EXISTS idx_documents_subject ON $studyDocumentsTable (subjectFk);
  ''';

  static const String createDateCreatedIndex = '''
    CREATE INDEX IF NOT EXISTS idx_documents_dateCreated ON $studyDocumentsTable (dateCreated DESC);
  ''';
}
