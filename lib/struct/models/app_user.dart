/// Model đại diện cho người dùng trong hệ thống (bảng users trong Supabase)
class AppUser {
  final String uid;          // Firebase UID
  final String email;
  final String displayName;
  final String? photoUrl;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['display_name'] as String? ?? map['email'] as String,
      photoUrl: map['photo_url'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'AppUser(uid: $uid, email: $email, displayName: $displayName)';
}
