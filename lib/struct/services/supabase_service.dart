import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/app_user.dart';
import '../models/cloud_document.dart';
import '../models/document_permission.dart';

/// Service quản lý CSDL quan hệ trên Supabase
/// Bao gồm: tài liệu, quyền chia sẻ, tìm kiếm
class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  static const _uuid = Uuid();

  // ============================================================
  // TÀI LIỆU (DOCUMENTS)
  // ============================================================

  /// Tạo tài liệu mới trên Supabase
  Future<CloudDocument> createDocument(CloudDocument doc) async {
    final data = doc.toMap();
    await _client.from('documents').insert(data);
    return doc;
  }

  /// Cập nhật thông tin tài liệu
  Future<void> updateDocument(CloudDocument doc) async {
    final updated = await _client
        .from('documents')
        .update({
          'title': doc.title,
          'description': doc.description,
          'subject': doc.subject,
          'doc_type': doc.docType,
          'storage_url': doc.storageUrl,
          'storage_path': doc.storagePath,
          'file_name': doc.fileName,
          'file_size': doc.fileSize,
          'tags': doc.toMap()['tags'],
          'is_favorite': doc.isFavorite,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', doc.id)
        .select('id');
    if ((updated as List).isEmpty) {
      throw StateError('Không có quyền cập nhật tài liệu này.');
    }
  }

  /// Xóa tài liệu (chỉ chủ sở hữu)
  Future<void> deleteDocument(String documentId, String ownerUid) async {
    final deleted = await _client
        .from('documents')
        .delete()
        .eq('id', documentId)
        .eq('owner_uid', ownerUid)
        .select('id');
    if ((deleted as List).isEmpty) {
      throw StateError('Không có quyền xóa tài liệu này.');
    }
  }

  /// Lấy tất cả tài liệu của người dùng hiện tại (tài liệu sở hữu)
  Future<List<CloudDocument>> getMyDocuments(String ownerUid) async {
    final response = await _client
        .from('documents')
        .select()
        .eq('owner_uid', ownerUid)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => CloudDocument.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Lấy tài liệu được chia sẻ với người dùng
  Future<List<CloudDocument>> getSharedWithMeDocuments(String userUid) async {
    // JOIN document_permissions với documents
    final response = await _client
        .from('document_permissions')
        .select('document_id, permission, documents(*)')
        .eq('shared_with_uid', userUid);

    final List<CloudDocument> docs = [];
    for (final row in response as List) {
      if (row['documents'] != null) {
        docs.add(CloudDocument.fromMap(row['documents'] as Map<String, dynamic>));
      }
    }
    return docs;
  }

  /// Tìm kiếm tài liệu (theo tiêu đề, mô tả, tags)
  Future<List<CloudDocument>> searchDocuments({
    required String ownerUid,
    String query = '',
    String? subject,
    String? docType,
    bool onlyFavorites = false,
    bool includeShared = false,
  }) async {
    var queryBuilder = _client
        .from('documents')
        .select();

    final normalizedQuery = query.trim();
    if (normalizedQuery.isNotEmpty) {
      final safeQuery = normalizedQuery.replaceAll('%', '\\%');
      queryBuilder = queryBuilder.or(
        'title.ilike.%$safeQuery%,description.ilike.%$safeQuery%,tags::text.ilike.%$safeQuery%',
      );
    }

    if (subject != null && subject.isNotEmpty) {
      queryBuilder = queryBuilder.eq('subject', subject);
    }

    if (docType != null && docType.isNotEmpty) {
      queryBuilder = queryBuilder.eq('doc_type', docType);
    }

    if (onlyFavorites) {
      queryBuilder = queryBuilder.eq('is_favorite', true);
    }

    // RLS limits shared results to the current user even when owner filtering
    // is disabled.
    if (!includeShared) {
      queryBuilder = queryBuilder.eq('owner_uid', ownerUid);
    }

    final response = await queryBuilder.order('created_at', ascending: false);

    return (response as List)
        .map((e) => CloudDocument.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Đảo trạng thái yêu thích
  Future<void> toggleFavorite(String documentId, bool currentValue) async {
    final updated = await _client
        .from('documents')
        .update({'is_favorite': !currentValue, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', documentId)
        .select('id');
    if ((updated as List).isEmpty) {
      throw StateError('Không có quyền cập nhật mục yêu thích này.');
    }
  }

  // ============================================================
  // QUYỀN CHIA SẺ (DOCUMENT PERMISSIONS)
  // ============================================================

  /// Chia sẻ tài liệu cho người dùng khác
  Future<DocumentPermission> shareDocument({
    required String documentId,
    required String ownerUid,
    required String sharedWithUid,
    required String sharedWithEmail,
    required PermissionLevel permission,
  }) async {
    final perm = DocumentPermission(
      id: _uuid.v4(),
      documentId: documentId,
      ownerUid: ownerUid,
      sharedWithUid: sharedWithUid,
      sharedWithEmail: sharedWithEmail,
      permission: permission,
      createdAt: DateTime.now(),
    );

    final saved = await _client
        .from('document_permissions')
        .upsert(
          perm.toMap(),
          onConflict: 'document_id,shared_with_uid',
        )
        .select()
        .single();
    return DocumentPermission.fromMap(saved);
  }

  /// Thu hồi quyền chia sẻ
  Future<void> revokePermission(String documentId, String sharedWithUid) async {
    final revoked = await _client
        .from('document_permissions')
        .delete()
        .eq('document_id', documentId)
        .eq('shared_with_uid', sharedWithUid)
        .select('id');
    if ((revoked as List).isEmpty) {
      throw StateError('Không có quyền thu hồi chia sẻ này.');
    }
  }

  /// Lấy danh sách người được chia sẻ tài liệu
  Future<List<DocumentPermission>> getDocumentPermissions(String documentId) async {
    final response = await _client
        .from('document_permissions')
        .select()
        .eq('document_id', documentId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => DocumentPermission.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Kiểm tra quyền của người dùng trên tài liệu
  Future<PermissionLevel?> checkPermission(String documentId, String userUid) async {
    // Chủ sở hữu có toàn quyền
    final doc = await _client
        .from('documents')
        .select('owner_uid')
        .eq('id', documentId)
        .maybeSingle();

    if (doc != null && doc['owner_uid'] == userUid) {
      return PermissionLevel.edit;
    }

    // Kiểm tra quyền chia sẻ
    final perm = await _client
        .from('document_permissions')
        .select('permission')
        .eq('document_id', documentId)
        .eq('shared_with_uid', userUid)
        .maybeSingle();

    if (perm == null) return null;
    return PermissionLevelX.fromKey(perm['permission'] as String?);
  }

  // ============================================================
  // NGƯỜI DÙNG (USERS)
  // ============================================================

  /// Lấy danh sách tất cả người dùng (để chia sẻ)
  Future<List<AppUser>> searchUsers(String emailQuery) async {
    final response = await _client
        .from('users')
        .select()
        .ilike('email', '%$emailQuery%')
        .limit(10);

    return (response as List)
        .map((e) => AppUser.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Lấy thông tin người dùng theo UID
  Future<AppUser?> getUserByUid(String uid) async {
    final response = await _client
        .from('users')
        .select()
        .eq('uid', uid)
        .maybeSingle();

    if (response == null) return null;
    return AppUser.fromMap(response);
  }
}