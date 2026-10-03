import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_material_app/database/app_database.dart';
import 'package:study_material_app/pages/home_page.dart';
import 'package:study_material_app/struct/state/document_provider.dart';
import 'package:study_material_app/widgets/document_card.dart';
import 'package:study_material_app/colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late DocumentProvider provider;

  setUp(() async {
    db = AppDatabase.newInstance();
    await db.init(isInMemory: true);
    provider = DocumentProvider(db);
    // Đợi _loadInitialData() hoàn tất thực sự (real async I/O)
    await testerReady(provider);
  });

  tearDown(() async {
    provider.dispose();
    await db.close();
  });

  Widget buildApp() {
    return ChangeNotifierProvider<DocumentProvider>.value(
      value: provider,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
          ),
        ),
        home: const HomePage(),
      ),
    );
  }

  group('Tầng Giao Diện & Tương Tác (Presentation Layer Tests)', () {
    testWidgets('Khởi chạy ứng dụng và hiển thị màn hình chính với dữ liệu',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      // Một frame để rebuild sau provider.ready
      await tester.pump();

      // Kiểm tra tiêu đề ứng dụng
      expect(find.text('Tài liệu Học tập'), findsOneWidget);
      // Kiểm tra thống kê tổng số tài liệu
      expect(find.text('TỔNG SỐ TÀI LIỆU'), findsOneWidget);
      // Kiểm tra thanh tìm kiếm
      expect(find.byType(TextField), findsOneWidget);
      // Kiểm tra các thẻ tài liệu - dữ liệu seeded sẵn
      expect(find.byType(DocumentCard), findsWidgets);
      // Kiểm tra nút FAB Thêm tài liệu
      expect(find.text('Thêm tài liệu'), findsOneWidget);
    });

    testWidgets('Tìm kiếm tài liệu học tập theo từ khóa',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.text('TỔNG SỐ TÀI LIỆU'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Nhập từ khóa tìm kiếm "Cashew"
      await tester.enterText(find.byType(TextField), 'Cashew');
      await tester.pump();

      // Kiểm tra có ít nhất 1 kết quả DocumentCard
      expect(find.byType(DocumentCard), findsWidgets);
    });

    testWidgets('Màn hình hiển thị empty state khi không có kết quả',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.text('TỔNG SỐ TÀI LIỆU'), findsOneWidget);

      // Tìm kiếm từ khóa không tồn tại
      await tester.enterText(find.byType(TextField), 'xyz_kq_rong_12345');
      await tester.pump();

      // Phải hiển thị thông báo empty state
      expect(find.text('Không tìm thấy tài liệu phù hợp'), findsOneWidget);
    });
  });
}

// Helper dùng ngoài tester context (setUp chạy real async)
Future<void> testerReady(DocumentProvider provider) => provider.ready;
