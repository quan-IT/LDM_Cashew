import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/cloud_document.dart';
import '../models/document_permission.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

enum LoadingStatus { idle, loading, loaded, error }

/// Provider quản lý trạng thái Cloud (Auth + Documents + Permissions)
class CloudProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService();
  final StorageService _storageService = StorageService();

  StreamSubscription<fb.User?>? _authSub;

  AppUser? _currentUser;
  bool _isAuthLoading = true;
  bool _isCompletingSignIn = false;

  List<CloudDocument> _myDocuments = [];
  List<CloudDocument> _sharedDocuments = [];
  LoadingStatus _docStatus = LoadingStatus.idle;
  String? _error;

  String _searchQuery = '';
  String? _selectedSubject;
  String? _selectedDocType;
  bool _onlyFavorites = false;
  bool _showShared = false;

  List<DocumentPermission> _currentDocPermissions = [];

  CloudProvider() {
    _listenToAuthChanges();
  }

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAuthLoading => _isAuthLoading;
  List<CloudDocument> get myDocuments => _myDocuments;
  List<CloudDocument> get sharedDocuments => _sharedDocuments;
  LoadingStatus get docStatus => _docStatus;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get selectedSubject => _selectedSubject;
  String? get selectedDocType => _selectedDocType;
  bool get onlyFavorites => _onlyFavorites;
  bool get showShared => _showShared;
  List<DocumentPermission> get currentDocPermissions => _currentDocPermissions;

  AuthService get authService => _authService;
  StorageService get storageService => _storageService;
  SupabaseService get supabaseService => _supabaseService;

  List<CloudDocument> get filteredDocuments {
    final source = _showShared ? _sharedDocuments : _myDocuments;
    return source.where((doc) {
      if (_onlyFavorites && !doc.isFavorite) {
        return false;
      }
      if (_selectedSubject != null &&
          _selectedSubject!.isNotEmpty &&
          doc.subject != _selectedSubject) {
        return false;
      }
      if (_selectedDocType != null &&
          _selectedDocType!.isNotEmpty &&
          doc.docType != _selectedDocType) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = doc.title.toLowerCase().contains(q);
        final matchDesc = doc.description.toLowerCase().contains(q);
        final matchTag = doc.tags.any((t) => t.toLowerCase().contains(q));
        if (!matchTitle && !matchDesc && !matchTag) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Map<String, int> get statistics {
    return {
      'total': _myDocuments.length,
      'shared': _sharedDocuments.length,
      'favorites': _myDocuments.where((d) => d.isFavorite).length,
      'lecture': _myDocuments.where((d) => d.docType == 'lecture').length,
      'assignment': _myDocuments.where((d) => d.docType == 'assignment').length,
      'reference': _myDocuments.where((d) => d.docType == 'reference').length,
      'exam': _myDocuments.where((d) => d.docType == 'exam').length,
    };
  }

  // ── Auth ──

  void _listenToAuthChanges() {
    _authSub = _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        if (_isCompletingSignIn) {
          _currentUser = _authService.appUserFromFirebase(firebaseUser);
        } else {
          try {
            _currentUser =
                await _authService.getCurrentUserFromSupabase() ??
                _authService.appUserFromFirebase(firebaseUser);
            await loadDocuments();
          } catch (e) {
            _currentUser = _authService.appUserFromFirebase(firebaseUser);
            _error = 'Không thể tải hồ sơ người dùng: $e';
            _docStatus = LoadingStatus.error;
          }
        }
      } else {
        _currentUser = null;
        _myDocuments = [];
        _sharedDocuments = [];
        _error = null;
      }
      _isAuthLoading = false;
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle() async {
    _isCompletingSignIn = true;
    _isAuthLoading = true;
    notifyListeners();
    try {
      _currentUser = await _authService.signInWithGoogle();
      _error = null;
      if (_currentUser != null) {
        try {
          await _authService.syncUserProfileToSupabase(_currentUser!);
          await loadDocuments();
        } catch (e) {
          _error = 'Đăng nhập Firebase thành công nhưng Supabase chưa sẵn sàng: $e';
          _docStatus = LoadingStatus.error;
          _myDocuments = [];
          _sharedDocuments = [];
        }
      }
    } finally {
      _isCompletingSignIn = false;
      _isAuthLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _myDocuments = [];
    _sharedDocuments = [];
    notifyListeners();
  }

  // ── Documents ──

  Future<void> loadDocuments() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    _docStatus = LoadingStatus.loading;
    notifyListeners();

    try {
      _myDocuments = await _supabaseService.getMyDocuments(uid);
      _sharedDocuments = await _supabaseService.getSharedWithMeDocuments(uid);
      _docStatus = LoadingStatus.loaded;
      _error = null;
    } catch (e) {
      _docStatus = LoadingStatus.error;
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<CloudDocument> addDocument(CloudDocument doc) async {
    final created = await _supabaseService.createDocument(doc);
    _myDocuments.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<void> updateDocument(CloudDocument doc) async {
    await _supabaseService.updateDocument(doc);
    final idx = _myDocuments.indexWhere((d) => d.id == doc.id);
    if (idx >= 0) {
      _myDocuments[idx] = doc.copyWith(updatedAt: DateTime.now());
    } else {
      final sharedIdx = _sharedDocuments.indexWhere((d) => d.id == doc.id);
      if (sharedIdx >= 0) {
        _sharedDocuments[sharedIdx] = doc.copyWith(updatedAt: DateTime.now());
      }
    }
    notifyListeners();
  }

  Future<void> deleteDocument(CloudDocument doc) async {
    await _supabaseService.deleteDocument(doc.id, doc.ownerUid);
    if (doc.storagePath.isNotEmpty) {
      await _storageService.deleteDocument(
        documentId: doc.id,
        storagePath: doc.storagePath,
      );
    }
    _myDocuments.removeWhere((d) => d.id == doc.id);
    notifyListeners();
  }

  Future<void> toggleFavorite(CloudDocument doc) async {
    await _supabaseService.toggleFavorite(doc.id, doc.isFavorite);
    final idx = _myDocuments.indexWhere((d) => d.id == doc.id);
    if (idx >= 0) {
      _myDocuments[idx] = doc.copyWith(isFavorite: !doc.isFavorite);
    } else {
      final sharedIdx = _sharedDocuments.indexWhere((d) => d.id == doc.id);
      if (sharedIdx >= 0) {
        _sharedDocuments[sharedIdx] = doc.copyWith(isFavorite: !doc.isFavorite);
      }
    }
    notifyListeners();
  }

  Future<PermissionLevel?> permissionForDocument(CloudDocument doc) async {
    final uid = _currentUser?.uid;
    if (uid == null) return null;
    if (doc.ownerUid == uid) return PermissionLevel.edit;
    return _supabaseService.checkPermission(doc.id, uid);
  }

  // ── Permissions ──

  Future<void> loadDocumentPermissions(String documentId) async {
    _currentDocPermissions = await _supabaseService.getDocumentPermissions(
      documentId,
    );
    notifyListeners();
  }

  Future<String> shareDocument({
    required String documentId,
    required String targetEmail,
    required PermissionLevel permission,
  }) async {
    final uid = _currentUser?.uid;
    if (uid == null) throw Exception('Chưa đăng nhập');

    final normalizedEmail = targetEmail.trim();
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (normalizedEmail.isEmpty || !emailPattern.hasMatch(normalizedEmail)) {
      return 'Vui lòng nhập địa chỉ email hợp lệ.';
    }

    final normalizedCurrentEmail = (_currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    final normalizedTargetEmail = normalizedEmail.toLowerCase();
    if (normalizedTargetEmail == normalizedCurrentEmail) {
      return 'Không thể chia sẻ tài liệu với chính mình!';
    }

    final targetUser = await _authService.findUserByEmail(normalizedEmail);
    if (targetUser == null) {
      return 'Không tìm thấy người dùng với email: $normalizedEmail';
    }

    final duplicatePermission = _currentDocPermissions.any(
      (perm) =>
          perm.documentId == documentId && perm.sharedWithUid == targetUser.uid,
    );
    if (duplicatePermission) {
      return 'Tài liệu đã được chia sẻ cho người dùng này.';
    }

    await _supabaseService.shareDocument(
      documentId: documentId,
      ownerUid: uid,
      sharedWithUid: targetUser.uid,
      sharedWithEmail: targetUser.email,
      permission: permission,
    );

    await loadDocumentPermissions(documentId);
    return 'Đã chia sẻ tài liệu với ${targetUser.displayName}';
  }

  Future<void> revokePermission(String documentId, String sharedWithUid) async {
    await _supabaseService.revokePermission(documentId, sharedWithUid);
    _currentDocPermissions.removeWhere((p) => p.sharedWithUid == sharedWithUid);
    notifyListeners();
  }

  // ── Filters ──

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedSubject(String? subject) {
    _selectedSubject = subject == _selectedSubject ? null : subject;
    notifyListeners();
  }

  void setSelectedDocType(String? type) {
    _selectedDocType = type == _selectedDocType ? null : type;
    notifyListeners();
  }

  void toggleFavoriteFilter() {
    _onlyFavorites = !_onlyFavorites;
    notifyListeners();
  }

  void setShowShared(bool value) {
    _showShared = value;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedSubject = null;
    _selectedDocType = null;
    _onlyFavorites = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
