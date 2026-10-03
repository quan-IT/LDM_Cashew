import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../colors.dart';
import '../struct/models/doc_type.dart';
import '../struct/models/study_document.dart';
import '../struct/state/document_provider.dart';

class AddEditDocumentPage extends StatefulWidget {
  final StudyDocument? document;

  const AddEditDocumentPage({super.key, this.document});

  @override
  State<AddEditDocumentPage> createState() => _AddEditDocumentPageState();
}

class _AddEditDocumentPageState extends State<AddEditDocumentPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _urlController;
  late final TextEditingController _tagInputController;

  String? _selectedSubjectFk;
  DocType _selectedDocType = DocType.lecture;
  bool _isFavorite = false;
  final List<String> _tags = [];

  bool get isEditing => widget.document != null;

  @override
  void initState() {
    super.initState();
    final doc = widget.document;
    if (doc != null) {
      _titleController = TextEditingController(text: doc.title);
      _descController = TextEditingController(text: doc.description);
      _urlController = TextEditingController(text: doc.fileUrl);
      _selectedSubjectFk = doc.subjectFk;
      _selectedDocType = doc.docType;
      _isFavorite = doc.isFavorite;
      _tags.addAll(doc.tags);
    } else {
      _titleController = TextEditingController();
      _descController = TextEditingController();
      _urlController = TextEditingController();
    }
    _tagInputController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _urlController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  void _addTag() {
    final text = _tagInputController.text.trim();
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() {
        _tags.add(text);
        _tagInputController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSubjectFk == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn môn học phù hợp.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final provider = context.read<DocumentProvider>();

    try {
      if (isEditing) {
        await provider.updateDocument(
          documentPk: widget.document!.documentPk,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          subjectFk: _selectedSubjectFk!,
          docType: _selectedDocType,
          fileUrl: _urlController.text.trim(),
          tags: _tags,
          isFavorite: _isFavorite,
          dateCreated: widget.document!.dateCreated,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật tài liệu thành công!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        await provider.addDocument(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          subjectFk: _selectedSubjectFk!,
          docType: _selectedDocType,
          fileUrl: _urlController.text.trim(),
          tags: _tags,
          isFavorite: _isFavorite,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thêm tài liệu mới thành công!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();
    final subjects = provider.subjects;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Thiết lập môn học mặc định nếu chưa chọn
    if (_selectedSubjectFk == null && subjects.isNotEmpty) {
      _selectedSubjectFk = subjects.first.subjectPk;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Chỉnh sửa Tài liệu' : 'Thêm Tài liệu Mới',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _isFavorite ? AppColors.favorite : null,
            ),
            tooltip: 'Yêu thích',
            onPressed: () {
              setState(() {
                _isFavorite = !_isFavorite;
              });
            },
          ),
          TextButton(
            onPressed: _saveDocument,
            child: const Text(
              'LƯU',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Tiêu đề
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Tiêu đề tài liệu *',
                hintText: 'Ví dụ: Bài giảng Chương 1 - Lập trình Di động',
                prefixIcon: const Icon(Icons.title_rounded, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Tiêu đề không được để trống';
                }
                if (value.trim().length < 3) {
                  return 'Tiêu đề phải từ 3 ký tự trở lên';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Chọn Môn học
            DropdownButtonFormField<String>(
              initialValue: _selectedSubjectFk,
              decoration: InputDecoration(
                labelText: 'Môn học / Học phần *',
                prefixIcon: const Icon(Icons.bookmark_rounded, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: subjects.map((subj) {
                return DropdownMenuItem<String>(
                  value: subj.subjectPk,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: subj.colorValue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${subj.name} (${subj.code})',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSubjectFk = value;
                });
              },
            ),
            const SizedBox(height: 18),

            // Loại tài liệu
            const Text(
              'Loại tài liệu:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: DocType.values.map((type) {
                final isSelected = _selectedDocType == type;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(type.icon, size: 14, color: isSelected ? Colors.white : type.color),
                      const SizedBox(width: 6),
                      Text(type.label),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: type.color,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedDocType = type;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Liên kết / Đường dẫn tài liệu
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Liên kết / Tệp tài liệu kèm theo (Tùy chọn)',
                hintText: 'https://github.com/... hoặc /storage/docs/slide.pdf',
                prefixIcon: const Icon(Icons.link_rounded, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 18),

            // Thẻ Tags
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagInputController,
                    decoration: InputDecoration(
                      labelText: 'Thêm thẻ phân loại (Tags)',
                      hintText: 'Ví dụ: Flutter, SQLite, Đề_cương',
                      prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTag,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Thêm'),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text('#$tag'),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => _removeTag(tag),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 18),

            // Ghi chú / Mô tả chi tiết
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Nội dung tóm tắt / Ghi chú',
                hintText: 'Nhập tóm tắt các điểm trọng tâm cần lưu ý...',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 50),
                  child: Icon(Icons.description_rounded, color: AppColors.primary),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),

            // Nút Lưu hoàn thành
            ElevatedButton.icon(
              onPressed: _saveDocument,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(
                isEditing ? 'CẬP NHẬT TÀI LIỆU' : 'LƯU TÀI LIỆU',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
