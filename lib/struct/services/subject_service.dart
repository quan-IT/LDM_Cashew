import 'package:uuid/uuid.dart';
import '../../database/app_database.dart';
import '../models/subject.dart';

/// Lớp nghiệp vụ quản lý Môn học / Học phần (Tương đương Wallets trong Cashew)
class SubjectService {
  final AppDatabase _db;
  static const _uuid = Uuid();

  SubjectService(this._db);

  String? validateSubject({required String name, required String code}) {
    if (name.trim().isEmpty) {
      return 'Tên môn học không được để trống.';
    }
    if (name.trim().length < 2) {
      return 'Tên môn học phải có ít nhất 2 ký tự.';
    }
    return null;
  }

  Future<Subject> createSubject({
    required String name,
    required String code,
    required String colour,
    required String iconName,
  }) async {
    final error = validateSubject(name: name, code: code);
    if (error != null) {
      throw ArgumentError(error);
    }

    final subject = Subject(
      subjectPk: _uuid.v4(),
      name: name.trim(),
      code: code.trim().toUpperCase(),
      colour: colour,
      iconName: iconName,
      dateTimeModified: DateTime.now(),
    );

    await _db.insertSubject(subject);
    return subject;
  }

  Future<void> updateSubject({
    required String subjectPk,
    required String name,
    required String code,
    required String colour,
    required String iconName,
  }) async {
    final error = validateSubject(name: name, code: code);
    if (error != null) {
      throw ArgumentError(error);
    }

    final subject = Subject(
      subjectPk: subjectPk,
      name: name.trim(),
      code: code.trim().toUpperCase(),
      colour: colour,
      iconName: iconName,
      dateTimeModified: DateTime.now(),
    );

    await _db.updateSubject(subject);
  }

  Future<void> deleteSubject(String subjectPk) async {
    await _db.deleteSubject(subjectPk);
  }

  Future<Map<String, int>> countDocumentsPerSubject() async {
    final docs = await _db.getAllDocuments();
    final counts = <String, int>{};
    for (final doc in docs) {
      counts[doc.subjectFk] = (counts[doc.subjectFk] ?? 0) + 1;
    }
    return counts;
  }
}
