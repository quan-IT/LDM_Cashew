import 'package:flutter/material.dart';
import '../../colors.dart';

/// Các phân loại tài liệu học tập
enum DocType {
  lecture('lecture', 'Bài giảng', Icons.menu_book_rounded, AppColors.lectureColor),
  assignment('assignment', 'Bài tập', Icons.assignment_rounded, AppColors.assignmentColor),
  reference('reference', 'Tham khảo', Icons.auto_stories_rounded, AppColors.referenceColor),
  exam('exam', 'Đề thi / Ôn tập', Icons.quiz_rounded, AppColors.examColor);

  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const DocType(this.key, this.label, this.icon, this.color);

  static DocType fromKey(String? key) {
    return DocType.values.firstWhere(
      (element) => element.key == key,
      orElse: () => DocType.lecture,
    );
  }
}
