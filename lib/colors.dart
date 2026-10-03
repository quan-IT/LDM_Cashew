import 'package:flutter/material.dart';

/// Bảng màu thiết kế chuẩn theo phong cách kiến trúc Cashew
/// Tối ưu cho cả Light Mode và Dark Mode với phong cách hiện đại, thanh lịch.
class AppColors {
  // Primary Palette
  static const Color primary = Color(0xFF1E88E5);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFFBBDEFB);
  static const Color accent = Color(0xFF00BFA5);

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color cardLight = Colors.white;
  static const Color backgroundDark = Color(0xFF121212);
  static const Color cardDark = Color(0xFF1E1E1E);

  // Document Type Semantic Colors
  static const Color lectureColor = Color(0xFF3F51B5);     // Xanh dương: Bài giảng
  static const Color assignmentColor = Color(0xFFE65100);  // Cam đậm: Bài tập
  static const Color referenceColor = Color(0xFF2E7D32);   // Xanh lá: Tài liệu tham khảo
  static const Color examColor = Color(0xFFC2185B);        // Hồng đậm: Đề thi / Đề cương

  // Neutral Colors
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF757575);
  static const Color textPrimaryDark = Color(0xFFEEEEEE);
  static const Color textSecondaryDark = Color(0xFF9E9E9E);
  static const Color dividerLight = Color(0xFFEEEEEE);
  static const Color dividerDark = Color(0xFF2C2C2C);

  // Status & Actions
  static const Color danger = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFFFA000);
  static const Color favorite = Color(0xFFFFB300);

  // Danh sách màu sắc cho Môn học (Subjects)
  static const List<Color> subjectPalette = [
    Color(0xFF1E88E5), // Blue
    Color(0xFF00897B), // Teal
    Color(0xFF43A047), // Green
    Color(0xFFFB8C00), // Orange
    Color(0xFFE53935), // Red
    Color(0xFF8E24AA), // Purple
    Color(0xFF3949AB), // Indigo
    Color(0xFF00ACC1), // Cyan
    Color(0xFFD81B60), // Pink
    Color(0xFF6D4C41), // Brown
  ];
}
