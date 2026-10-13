/// Mức độ quyền truy cập tài liệu
enum PermissionLevel {
  view,   // Chỉ xem
  edit,   // Xem và chỉnh sửa
}

extension PermissionLevelX on PermissionLevel {
  String get label {
    switch (this) {
      case PermissionLevel.view: return 'Chỉ xem';
      case PermissionLevel.edit: return 'Chỉnh sửa';
    }
  }
  String get key {
    switch (this) {
      case PermissionLevel.view: return 'view';
      case PermissionLevel.edit: return 'edit';
    }
  }
  static PermissionLevel fromKey(String? key) {
    switch (key) {
      case 'edit': return PermissionLevel.edit;
      default: return PermissionLevel.view;
    }
  }
}

/// Model quyền chia sẻ tài liệu (bảng document_permissions trong Supabase)
class DocumentPermission {
  final String id;
  final String documentId;   // FK -> documents.id
  final String ownerUid;     // UID chủ sở hữu
  final String sharedWithUid; // UID người được chia sẻ
  final String sharedWithEmail;
  final PermissionLevel permission;
  final DateTime createdAt;

  const DocumentPermission({
    required this.id,
    required this.documentId,
    required this.ownerUid,
    required this.sharedWithUid,
    required this.sharedWithEmail,
    required this.permission,
    required this.createdAt,
  });

  factory DocumentPermission.fromMap(Map<String, dynamic> map) {
    return DocumentPermission(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      ownerUid: map['owner_uid'] as String,
      sharedWithUid: map['shared_with_uid'] as String,
      sharedWithEmail: map['shared_with_email'] as String? ?? '',
      permission: PermissionLevelX.fromKey(map['permission'] as String?),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'owner_uid': ownerUid,
      'shared_with_uid': sharedWithUid,
      'shared_with_email': sharedWithEmail,
      'permission': permission.key,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
