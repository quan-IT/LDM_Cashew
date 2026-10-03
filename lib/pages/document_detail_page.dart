import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../colors.dart';
import '../struct/helpers/date_formats.dart';
import '../struct/models/study_document.dart';
import '../struct/state/document_provider.dart';
import 'add_edit_document_page.dart';

class DocumentDetailPage extends StatelessWidget {
  final String documentPk;

  const DocumentDetailPage({super.key, required this.documentPk});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    StudyDocument? document;
    try {
      document = provider.allDocuments.firstWhere((d) => d.documentPk == documentPk);
    } catch (_) {
      document = null;
    }

    if (document == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết tài liệu')),
        body: const Center(child: Text('Tài liệu không tồn tại hoặc đã bị xóa.')),
      );
    }

    final subject = provider.getSubjectByPk(document.subjectFk);
    final subjectColor = subject?.colorValue ?? AppColors.primary;
    final docType = document.docType;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết Tài liệu'),
        actions: [
          IconButton(
            icon: Icon(
              document.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: document.isFavorite ? AppColors.favorite : null,
            ),
            tooltip: 'Yêu thích',
            onPressed: () => provider.toggleFavorite(document!.documentPk),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Chỉnh sửa',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditDocumentPage(document: document),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: AppColors.danger),
            tooltip: 'Xóa tài liệu',
            onPressed: () => _confirmDelete(context, provider, document!),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Môn học Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: subjectColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_rounded, size: 14, color: subjectColor),
                          const SizedBox(width: 4),
                          Text(
                            subject?.name ?? 'Môn học',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: subjectColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Loại tài liệu Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: docType.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(docType.icon, size: 13, color: docType.color),
                          const SizedBox(width: 4),
                          Text(
                            docType.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: docType.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Tiêu đề
                Text(
                  document.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                // Thời gian
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Tạo ngày: ${DateFormats.formatDate(document.dateCreated)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                if (document.dateTimeModified != document.dateCreated) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.update_rounded, size: 13, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Cập nhật: ${DateFormats.formatDate(document.dateTimeModified)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tệp đính kèm / Liên kết
          if (document.fileUrl.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ĐƯỜNG DẪN TÀI LIỆU KÈM THEO',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.link_rounded, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          document.fileUrl,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: 'Sao chép đường dẫn',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: document!.fileUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã sao chép liên kết vào bộ nhớ tạm!')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Thẻ phân loại Tags
          if (document.tags.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'THẺ PHÂN LOẠI (TAGS)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: document.tags.map((tag) {
                      return Chip(
                        label: Text('#$tag'),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                        labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Nội dung / Ghi chú
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NỘI DUNG TÓM TẮT & GHI CHÚ',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Text(
                  document.description.isNotEmpty
                      ? document.description
                      : 'Không có ghi chú bổ sung cho tài liệu này.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, DocumentProvider provider, StudyDocument doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa tài liệu?'),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${doc.title}" không? Hành động này sẽ được ghi vào DeleteLogs để hỗ trợ đồng bộ phân tán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('HỦY BỎ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteDocument(doc.documentPk);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã xóa tài liệu và tạo bản ghi Tombstone!'),
                  ),
                );
              }
            },
            child: const Text('XÓA'),
          ),
        ],
      ),
    );
  }
}
