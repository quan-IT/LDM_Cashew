import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'colors.dart';
import 'database/database_global.dart';
import 'pages/home_page.dart';
import 'struct/state/document_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo CSDL cục bộ theo triết lý Local-First Core của Cashew
  await database.init();

  runApp(const StudyMaterialApp());
}

class StudyMaterialApp extends StatelessWidget {
  const StudyMaterialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DocumentProvider>(
          create: (_) => DocumentProvider(database),
        ),
      ],
      child: MaterialApp(
        title: 'Quản lý Tài liệu Học tập - Kiến trúc Cashew',
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
        home: const HomePage(),
      ),
    );
  }
}
