import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

/// Service xác thực người dùng qua Firebase + Google Sign-In
class AuthService {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn = GoogleSignIn();
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Stream trạng thái đăng nhập Firebase
  Stream<fb.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Người dùng Firebase hiện tại
  fb.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// UID hiện tại
  String? get currentUid => _firebaseAuth.currentUser?.uid;

  /// Đăng nhập bằng Google Account
  Future<AppUser?> signInWithGoogle() async {
    try {
      final fb.UserCredential userCredential;
      if (kIsWeb) {
        userCredential = await _firebaseAuth.signInWithPopup(
          fb.GoogleAuthProvider(),
        );
      } else {
        final GoogleSignInAccount? googleAccount = await _googleSignIn.signIn();
        if (googleAccount == null) return null;

        final GoogleSignInAuthentication googleAuth =
            await googleAccount.authentication;
        final fb.OAuthCredential credential = fb.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _firebaseAuth.signInWithCredential(credential);
      }

      final fb.User? firebaseUser = userCredential.user;
      if (firebaseUser == null) return null;

      return appUserFromFirebase(firebaseUser);
    } catch (e) {
      throw Exception('Đăng nhập Google thất bại: $e');
    }
  }

  /// Cấp claim ở backend rồi đồng bộ hồ sơ sau khi Firebase đăng nhập thành công.
  Future<void> syncUserProfileToSupabase(AppUser user) async {
    await FirebaseFunctions.instance.httpsCallable('ensureSupabaseRole').call();
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null || firebaseUser.uid != user.uid) {
      throw StateError(
        'Phiên Firebase không còn khớp với người dùng hiện tại.',
      );
    }

    final tokenResult = await firebaseUser.getIdTokenResult(true);
    if (tokenResult.claims?['role'] != 'authenticated') {
      throw StateError(
        'ensureSupabaseRole chưa cấp claim role=authenticated cho người dùng.',
      );
    }
    await _upsertUserToSupabase(user);
  }

  AppUser appUserFromFirebase(fb.User firebaseUser) {
    return AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email?.trim().toLowerCase() ?? '',
      displayName:
          firebaseUser.displayName ?? firebaseUser.email ?? 'Người dùng',
      photoUrl: firebaseUser.photoURL,
      createdAt: DateTime.now(),
    );
  }

  /// Đăng xuất
  Future<void> signOut({bool clearSupabaseSession = true}) async {
    if (!kIsWeb) await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
    if (clearSupabaseSession) {
      await _supabase.auth.signOut();
    }
  }

  /// Lấy thông tin AppUser hiện tại từ Supabase
  Future<AppUser?> getCurrentUserFromSupabase() async {
    final uid = currentUid;
    if (uid == null) return null;
    final response = await _supabase
        .from('users')
        .select()
        .eq('uid', uid)
        .maybeSingle();
    if (response == null) return null;
    return AppUser.fromMap(response);
  }

  /// Tìm kiếm người dùng theo email (để chia sẻ tài liệu)
  Future<AppUser?> findUserByEmail(String email) async {
    final response = await _supabase
        .from('users')
        .select()
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();
    if (response == null) return null;
    return AppUser.fromMap(response);
  }

  /// Upsert hồ sơ người dùng vào Supabase
  Future<void> _upsertUserToSupabase(AppUser user) async {
    await _supabase.from('users').upsert(user.toMap(), onConflict: 'uid');
  }

  /// Lấy Firebase ID Token
  Future<String?> getIdToken() async {
    return await _firebaseAuth.currentUser?.getIdToken();
  }
}
