import 'dart:async';
import 'package:flutter/material.dart';

import '../../database/app_database.dart';
import '../models/doc_type.dart';
import '../models/study_document.dart';
import '../models/subject.dart';
import '../services/document_service.dart';
import '../services/subject_service.dart';
import '../services/sync_client.dart';

/// Provider quản lý trạng thái ứng dụng theo mô hình Provider trong kiến trúc Cashew
class DocumentProvider extends ChangeNotifier {
  final AppDatabase _db;
  late final DocumentService _documentService;
  late final SubjectService _subjectService;
  late final SyncClient _syncClient;

  StreamSubscription<List<StudyDocument>>? _docsSub;
  StreamSubscription<List<Subject>>? _subjectsSub;

  List<StudyDocument> _allDocuments = [];
  List<Subject> _subjects = [];
  bool _isLoading = true;

  /// Completer cho phép test await khi dữ liệu ban đầu đã load xong
  final Completer<void> _readyCompleter = Completer<void>();
  Future<void> get ready => _readyCompleter.future;

  // Trạng thái lọc và tìm kiếm (Filters & Search)
  String _searchQuery = '';
  String? _selectedSubjectFk;
  DocType? _selectedDocType;
  bool _onlyFavorites = false;

  DocumentProvider(this._db) {
    _documentService = DocumentService(_db);
    _subjectService = SubjectService(_db);
    _syncClient = SyncClient(_db);
    _initStreams();
  }

  DocumentService get documentService => _documentService;
  SubjectService get subjectService => _subjectService;
  SyncClient get syncClient => _syncClient;

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get selectedSubjectFk => _selectedSubjectFk;
  DocType? get selectedDocType => _selectedDocType;
  bool get onlyFavorites => _onlyFavorites;
  List<Subject> get subjects => _subjects;
  List<StudyDocument> get allDocuments => _allDocuments;

  /// Danh sách tài liệu sau khi áp dụng bộ lọc và tìm kiếm
  List<StudyDocument> get filteredDocuments {
    return _documentService.filterAndSortDocuments(
      allDocs: _allDocuments,
      query: _searchQuery,
      subjectFk: _selectedSubjectFk,
      docType: _selectedDocType,
      onlyFavorites: _onlyFavorites,
    );
  }

  /// Thống kê tổng quan
  Map<String, int> get statistics {
    return _documentService.calculateStatistics(_allDocuments);
  }

  /// Khởi tạo đăng ký lắng nghe Reactive Streams từ CSDL
  void _initStreams() {
    _docsSub = _db.watchAllDocuments().listen((docs) {
      _allDocuments = docs;
      _isLoading = false;
      notifyListeners();
    });

    _subjectsSub = _db.watchAllSubjects().listen((subjs) {
      _subjects = subjs;
      notifyListeners();
    });

    // Tải dữ liệu ban đầu phòng khi chưa có sự kiện stream
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _allDocuments = await _db.getAllDocuments();
    _subjects = await _db.getAllSubjects();
    _isLoading = false;
    notifyListeners();
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
  }

  // ==================== BỘ LỌC VÀ TÌM KIẾM ====================

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectSubject(String? subjectPk) {
    if (_selectedSubjectFk == subjectPk) {
      _selectedSubjectFk = null; // Bấm lần 2 để bỏ chọn
    } else {
      _selectedSubjectFk = subjectPk;
    }
    notifyListeners();
  }

  void selectDocType(DocType? type) {
    if (_selectedDocType == type) {
      _selectedDocType = null; // Bấm lần 2 để bỏ chọn
    } else {
      _selectedDocType = type;
    }
    notifyListeners();
  }

  void toggleOnlyFavorites() {
    _onlyFavorites = !_onlyFavorites;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedSubjectFk = null;
    _selectedDocType = null;
    _onlyFavorites = false;
    notifyListeners();
  }

  // ==================== TÁC VỤ NGHIỆP VỤ CRUD TÀI LIỆU ====================

  Future<void> addDocument({
    required String title,
    required String description,
    required String subjectFk,
    required DocType docType,
    required String fileUrl,
    required List<String> tags,
    bool isFavorite = false,
  }) async {
    await _documentService.createDocument(
      title: title,
      description: description,
      subjectFk: subjectFk,
      docType: docType,
      fileUrl: fileUrl,
      tags: tags,
      isFavorite: isFavorite,
    );
  }

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
    await _documentService.updateDocument(
      documentPk: documentPk,
      title: title,
      description: description,
      subjectFk: subjectFk,
      docType: docType,
      fileUrl: fileUrl,
      tags: tags,
      isFavorite: isFavorite,
      dateCreated: dateCreated,
    );
  }

  Future<void> deleteDocument(String documentPk) async {
    await _documentService.deleteDocument(documentPk);
  }

  Future<void> toggleFavorite(String documentPk) async {
    await _documentService.toggleFavorite(documentPk);
  }

  // ==================== TÁC VỤ MÔN HỌC ====================

  Future<void> addSubject({
    required String name,
    required String code,
    required String colour,
    required String iconName,
  }) async {
    await _subjectService.createSubject(
      name: name,
      code: code,
      colour: colour,
      iconName: iconName,
    );
  }

  Future<void> updateSubject({
    required String subjectPk,
    required String name,
    required String code,
    required String colour,
    required String iconName,
  }) async {
    await _subjectService.updateSubject(
      subjectPk: subjectPk,
      name: name,
      code: code,
      colour: colour,
      iconName: iconName,
    );
  }

  Future<void> deleteSubject(String subjectPk) async {
    await _subjectService.deleteSubject(subjectPk);
  }

  Subject? getSubjectByPk(String subjectFk) {
    try {
      return _subjects.firstWhere((s) => s.subjectPk == subjectFk);
    } catch (_) {
      return null;
    }
  }

  // ==================== SAO LƯU & PHỤC HỒI ====================

  Future<String> exportBackup() async {
    return await _documentService.exportBackupJson();
  }

  Future<int> importBackup(String jsonContent) async {
    final count = await _documentService.importBackupJson(jsonContent);
    await _loadInitialData();
    return count;
  }

  @override
  void dispose() {
    _docsSub?.cancel();
    _subjectsSub?.cancel();
    super.dispose();
  }
}
