import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../colors.dart';
import '../struct/models/subject.dart';
import '../struct/state/document_provider.dart';

class SubjectManagementPage extends StatelessWidget {
  const SubjectManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();
    final subjects = provider.subjects;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Môn học / Học phần'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSubjectDialog(context, provider, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm Môn học'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: subjects.isEmpty
          ? const Center(child: Text('Chưa có môn học nào được tạo.'))
          : ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final subject = subjects[index];
                final docCount = provider.allDocuments
                    .where((d) => d.subjectFk == subject.subjectPk)
                    .length;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: subject.colorValue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.bookmark_rounded, color: subject.colorValue),
                    ),
                    title: Text(
                      subject.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      '${subject.code.isNotEmpty ? 'Mã: ${subject.code} • ' : ''}$docCount tài liệu',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 20),
                          tooltip: 'Chỉnh sửa',
                          onPressed: () => _showAddEditSubjectDialog(context, provider, subject),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_rounded, size: 20, color: AppColors.danger),
                          tooltip: 'Xóa môn học',
                          onPressed: () => _confirmDeleteSubject(context, provider, subject, docCount),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddEditSubjectDialog(
    BuildContext context,
    DocumentProvider provider,
    Subject? subject,
  ) {
    final isEditing = subject != null;
    final nameController = TextEditingController(text: subject?.name ?? '');
    final codeController = TextEditingController(text: subject?.code ?? '');
    String selectedColor = subject?.colour ?? '#1E88E5';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isEditing ? 'Sửa Môn học' : 'Thêm Môn học Mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên môn học *',
                    hintText: 'Ví dụ: Lập trình Di động',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Mã môn học',
                    hintText: 'Ví dụ: MOB301',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chọn màu đại diện:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppColors.subjectPalette.map((color) {
                    final hex = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                    final isSelected = selectedColor.toUpperCase() == hex;
                    return InkWell(
                      onTap: () => setState(() => selectedColor = hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 18, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('HỦY'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final code = codeController.text.trim();
                if (name.isEmpty) return;

                if (isEditing) {
                  await provider.updateSubject(
                    subjectPk: subject.subjectPk,
                    name: name,
                    code: code,
                    colour: selectedColor,
                    iconName: 'bookmark',
                  );
                } else {
                  await provider.addSubject(
                    name: name,
                    code: code,
                    colour: selectedColor,
                    iconName: 'bookmark',
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('LƯU'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSubject(
    BuildContext context,
    DocumentProvider provider,
    Subject subject,
    int docCount,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa môn học?'),
        content: Text(
          'Nếu xóa môn "${subject.name}", toàn bộ $docCount tài liệu liên kết sẽ bị xóa theo (Cascade Delete) và hệ thống sẽ tạo Tombstone DeleteLogs.\n\nBạn có muốn tiếp tục?',
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
              await provider.deleteSubject(subject.subjectPk);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa môn học và dữ liệu liên quan!')),
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
