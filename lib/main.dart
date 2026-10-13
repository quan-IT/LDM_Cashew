import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'colors.dart';
import 'database/database_global.dart';
import 'firebase_options.dart';
import 'pages/cloud_home_page.dart';
import 'pages/home_page.dart';
import 'struct/state/cloud_provider.dart';
import 'struct/state/document_provider.dart';

/// Điểm khởi động ứng dụng - Tích hợp Firebase + Supabase
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Khởi tạo CSDL cục bộ (Local-First)
  await database.init();

  // 2. Khởi tạo Firebase
  if (kIsWeb) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  } else {
    await Firebase.initializeApp();
  }

  // 3. Khởi tạo Supabase khi đã có cấu hình; nếu chưa, app vẫn chạy local.
  final cloudEnabled = AppConfig.isSupabaseConfigured;
  if (cloudEnabled) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
      accessToken: _firebaseSupabaseAccessToken,
    );
  }

  runApp(StudyMaterialApp(cloudEnabled: cloudEnabled));
}

Future<String?> _firebaseSupabaseAccessToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError(
      'Đăng nhập Firebase trước khi truy cập dữ liệu Supabase.',
    );
  }

  final tokenResult = await user.getIdTokenResult();
  if (tokenResult.claims?['role'] != 'authenticated') {
    throw StateError(
      'Firebase ID token chưa có claim role=authenticated. '
      'Hãy hoàn tất ensureSupabaseRole rồi đăng nhập lại.',
    );
  }
  return tokenResult.token;
}

class StudyMaterialApp extends StatelessWidget {
  const StudyMaterialApp({super.key, required this.cloudEnabled});

  final bool cloudEnabled;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provider cục bộ (Local SQLite)
        ChangeNotifierProvider<DocumentProvider>(
          create: (_) => DocumentProvider(database),
        ),
        // Provider Cloud (Firebase + Supabase)
        if (cloudEnabled)
          ChangeNotifierProvider<CloudProvider>(
            create: (_) => CloudProvider(),
          ),
      ],
      child: MaterialApp(
        title: 'DocCloud - Quản lý Tài liệu',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.light,
            primary: AppColors.primary,
            surface: AppColors.backgroundLight,
          ),
          scaffoldBackgroundColor: AppColors.backgroundLight,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: false,
            backgroundColor: AppColors.backgroundLight,
            foregroundColor: AppColors.textPrimaryLight,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.dark,
            primary: AppColors.primary,
            surface: AppColors.backgroundDark,
          ),
          scaffoldBackgroundColor: AppColors.backgroundDark,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: false,
            backgroundColor: AppColors.backgroundDark,
            foregroundColor: AppColors.textPrimaryDark,
          ),
        ),
        themeMode: ThemeMode.system,
        home: cloudEnabled
            ? const CloudHomePage()
            : const HomePage(localOnly: true),
      ),
    );
  }
}