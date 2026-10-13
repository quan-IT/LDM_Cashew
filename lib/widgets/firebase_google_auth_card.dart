import 'package:flutter/material.dart';

import '../struct/models/app_user.dart';
import '../struct/services/auth_service.dart';

class FirebaseGoogleAuthCard extends StatefulWidget {
  const FirebaseGoogleAuthCard({super.key});

  @override
  State<FirebaseGoogleAuthCard> createState() => _FirebaseGoogleAuthCardState();
}

class _FirebaseGoogleAuthCardState extends State<FirebaseGoogleAuthCard> {
  AppUser? _user;
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService().signInWithGoogle();
      if (!mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn đã hủy đăng nhập Google.')),
        );
      } else {
        setState(() => _user = user);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã đăng nhập Firebase: ${user.email}')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng nhập Firebase thất bại: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await AuthService().signOut(clearSupabaseSession: false);
      if (mounted) setState(() => _user = null);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng xuất Firebase thất bại: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.verified_user_outlined),
        title: Text(
          _user == null ? 'Kiểm tra Firebase Google Sign-In' : 'Đã đăng nhập Firebase',
        ),
        subtitle: Text(
          _user?.email ??
              'Đăng nhập độc lập để kiểm tra Firebase Authentication.',
        ),
        trailing: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: _user == null ? _signIn : _signOut,
                child: Text(_user == null ? 'Đăng nhập Google' : 'Đăng xuất'),
              ),
      ),
    );
  }
}
