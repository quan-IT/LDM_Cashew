import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../colors.dart';
import '../struct/models/cloud_document.dart';
import '../struct/state/cloud_provider.dart';

/// Trang thêm / chỉnh sửa tài liệu Cloud
class AddEditCloudDocumentPage extends StatefulWidget {
  final CloudDocument? document;
  const AddEditCloudDocumentPage({super.key, this.document});

  @override
  State<AddEditCloudDocumentPage> createState() =>
      _AddEditCloudDocumentPageState();
}

class _AddEditCloudDocumentPageState extends State<AddEditCloudDocumentPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _tagCtrl;

  String _selectedDocType = 'lecture';
  bool _isFavorite = false;
  final List<String> _tags = [];

  // File pick
  PlatformFile? _pickedFile;
  bool _isSaving = false;

  bool get isEditing => widget.document != null;

  static const _docTypes = [
    {'key': 'lecture', 'label': 'Bài giảng', 'icon': Icons.class_rounded},
    {'key': 'assignment', 'label': 'Bài tập', 'icon': Icons.assignment_rounded},
    {'key': 'reference', 'label': 'Tham khảo', 'icon': Icons.book_rounded},
    {'key': 'exam', 'label': 'Đề thi', 'icon': Icons.quiz_rounded},
  ];

  @override
  void initState() {
    super.initState();
    final doc = widget.document;
    _titleCtrl = TextEditingController(text: doc?.title ?? '');
    _descCtrl = TextEditingController(text: doc?.description ?? '');
    _subjectCtrl = TextEditingController(text: doc?.subject ?? '');
    _tagCtrl = TextEditingController();
    if (doc != null) {
      _selectedDocType = doc.docType;
      _isFavorite = doc.isFavorite;
      _tags.addAll(doc.tags);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _subjectCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'ppt',
        'pptx',
        'xls',
        'xlsx',
        'txt',
        'zip',
        'png',
        'jpg',
      ],
      withData: kIsWeb, // Lấy bytes trên Web
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagCtrl.clear();
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<CloudProvider>();
    final uid = provider.currentUser?.uid;
    if (uid == null) return;
    final isOwner = !isEditing || widget.document!.ownerUid == uid;

    setState(() {
      _isSaving = true;
    });

    String? newlyUploadedPath;
    final documentId = widget.document?.id ?? const Uuid().v4();
    try {
      final originalStoragePath = widget.document?.storagePath ?? '';
      String storageUrl = widget.document?.storageUrl ?? '';
      String storagePath = widget.document?.storagePath ?? '';
      String fileName = widget.document?.fileName ?? '';
      int fileSize = widget.document?.fileSize ?? 0;

      // Upload file nếu có chọn file mới
      if (_pickedFile != null) {
        if (!isOwner) {
          throw StateError('Chỉ chủ sở hữu mới có thể thay tệp đính kèm.');
        }
        final storageService = provider.storageService;

        if (kIsWeb && _pickedFile!.bytes != null) {
          // Web: dùng bytes
          final result = await storageService.uploadDocumentBytes(
            documentId: documentId,
            bytes: _pickedFile!.bytes!,
            fileName: _pickedFile!.name,
          );
          storagePath = result.fullPath;
          newlyUploadedPath = storagePath;
          fileName = result.fileName;
          fileSize = result.fileSize;
        } else if (_pickedFile!.path != null) {
          // Mobile/Desktop: dùng File
          final result = await storageService.uploadDocument(
            documentId: documentId,
            file: File(_pickedFile!.path!),
          );
          storagePath = result.fullPath;
          newlyUploadedPath = storagePath;
          fileName = result.fileName;
          fileSize = result.fileSize;
        }
      }

      final now = DateTime.now();
      final doc = CloudDocument(
        id: documentId,
        ownerUid: widget.document?.ownerUid ?? uid,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        subject: _subjectCtrl.text.trim(),
        docType: _selectedDocType,
        storageUrl: storageUrl,
        storagePath: storagePath,
        fileName: fileName,
        fileSize: fileSize,
        tags: List.from(_tags),
        isFavorite: _isFavorite,
        createdAt: widget.document?.createdAt ?? now,
        updatedAt: now,
      );

      if (isEditing) {
        await provider.updateDocument(doc);
      } else {
        await provider.addDocument(doc);
      }

      String? cleanupWarning;
      if (originalStoragePath.isNotEmpty &&
          originalStoragePath != storagePath) {
        try {
          await provider.storageService.deleteDocument(
            documentId: documentId,
            storagePath: originalStoragePath,
          );
        } catch (e) {
          cleanupWarning = ' Tệp cũ chưa xóa được: $e';
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isEditing ? 'Cập nhật tài liệu thành công!' : 'Thêm tài liệu thành công!'}'
              '${cleanupWarning ?? ''}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      var errorMessage = e.toString();
      if (newlyUploadedPath != null &&
          newlyUploadedPath != (widget.document?.storagePath ?? '')) {
        try {
          await provider.storageService.deleteDocument(
            documentId: documentId,
            storagePath: newlyUploadedPath,
          );
        } catch (cleanupError) {
          errorMessage += '\nKhông thể dọn tệp vừa tải lên: $cleanupError';
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $errorMessage'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<CloudProvider>().currentUser?.uid;
    final canReplaceFile = !isEditing || widget.document!.ownerUid == uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Chỉnh sửa tài liệu' : 'Thêm tài liệu mới',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _isFavorite ? Colors.amber : null,
            ),
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
          ),
          if (!_isSaving)
            TextButton(
              onPressed: _save,
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
      body: _isSaving
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _pickedFile != null
                        ? 'Đang tải file lên Cloud...'
                        : 'Đang lưu...',
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Tiêu đề
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: _inputDeco(
                      'Tiêu đề tài liệu *',
                      Icons.title_rounded,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Tiêu đề không được để trống';
                      }
                      if (v.trim().length < 3) return 'Tiêu đề phải từ 3 ký tự';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Môn học
                  TextFormField(
                    controller: _subjectCtrl,
                    decoration: _inputDeco(
                      'Môn học / Học phần *',
                      Icons.school_rounded,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập môn học'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Loại tài liệu
                  const Text(
                    'Loại tài liệu:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _docTypes.map((t) {
                      final selected = _selectedDocType == t['key'];
                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              t['icon'] as IconData,
                              size: 14,
                              color: selected
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(t['label'] as String),
                          ],
                        ),
                        selected: selected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : null,
                          fontWeight: selected ? FontWeight.bold : null,
                        ),
                        onSelected: (s) {
                          if (s) {
                            setState(
                              () => _selectedDocType = t['key'] as String,
                            );
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Upload file
                  InkWell(
                    onTap: canReplaceFile ? _pickFile : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _pickedFile != null
                              ? AppColors.success
                              : Colors.grey.shade400,
                          width: 2,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: _pickedFile != null
                            ? AppColors.success.withOpacity(0.05)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _pickedFile != null
                                ? Icons.check_circle_rounded
                                : Icons.cloud_upload_rounded,
                            color: _pickedFile != null
                                ? AppColors.success
                                : AppColors.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _pickedFile != null
                                      ? _pickedFile!.name
                                      : 'Chọn file tài liệu',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _pickedFile != null
                                        ? AppColors.success
                                        : null,
                                  ),
                                ),
                                Text(
                                  _pickedFile != null
                                      ? '${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB'
                                      : 'PDF, Word, PowerPoint, Excel, ảnh...',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (isEditing &&
                                    widget.document!.fileName.isNotEmpty &&
                                    _pickedFile == null)
                                  Text(
                                    canReplaceFile
                                        ? 'File hiện tại: ${widget.document!.fileName}'
                                        : 'Tệp chỉ có thể được thay bởi chủ sở hữu.',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_pickedFile != null)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  setState(() => _pickedFile = null),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tags
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagCtrl,
                          decoration: _inputDeco(
                            'Thêm thẻ (Tags)',
                            Icons.tag_rounded,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 17,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Thêm'),
                      ),
                    ],
                  ),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _tags
                          .map(
                            (t) => Chip(
                              label: Text('#$t'),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () => setState(() => _tags.remove(t)),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Mô tả
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Mô tả / Ghi chú',
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 50),
                        child: Icon(
                          Icons.description_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Nút lưu
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: Text(
                      isEditing ? 'CẬP NHẬT TÀI LIỆU' : 'LƯU LÊN CLOUD',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
