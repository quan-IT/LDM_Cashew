import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../colors.dart';
import '../struct/models/cloud_document.dart';
import '../struct/models/document_permission.dart';
import '../struct/state/cloud_provider.dart';
import 'add_edit_cloud_document_page.dart';
import 'share_document_page.dart';

/// Trang chi tiết tài liệu Cloud
class CloudDocumentDetailPage extends StatefulWidget {
  final CloudDocument document;
  const CloudDocumentDetailPage({super.key, required this.document});

  @override
  State<CloudDocumentDetailPage> createState() => _CloudDocumentDetailPageState();
}

class _CloudDocumentDetailPageState extends State<CloudDocumentDetailPage> {
  late CloudDocument _doc;
  PermissionLevel? _permissionLevel;

  @override
  void initState() {
    super.initState();
    _doc = widget.document;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPermission());
  }

  Future<void> _loadPermission() async {
    final provider = context.read<CloudProvider>();
    try {
      final permission = await provider.permissionForDocument(_doc);
      if (!mounted) return;
      setState(() => _permissionLevel = permission);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xác minh quyền tài liệu: $e')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tài liệu?'),
        content: Text('Xóa "${_doc.title}" và file trên Storage?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('XÓA'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<CloudProvider>().deleteDocument(_doc);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa tài liệu'), backgroundColor: AppColors.danger),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CloudProvider>();
    final isOwner = provider.currentUser?.uid == _doc.ownerUid;
    final canEdit = isOwner || _permissionLevel == PermissionLevel.edit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết tài liệu', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (canEdit)
            IconButton(
              icon: Icon(
                _doc.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _doc.isFavorite ? Colors.amber : null,
              ),
              onPressed: () async {
                await provider.toggleFavorite(_doc);
                setState(() => _doc = _doc.copyWith(isFavorite: !_doc.isFavorite));
              },
            ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ShareDocumentPage(document: _doc)),
              ),
            ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => AddEditCloudDocumentPage(document: _doc)),
                );
                if (result == true && mounted) {
                  Navigator.pop(context, true);
                }
              },
            ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: AppColors.danger),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Card ──
            _HeaderCard(doc: _doc),
            const SizedBox(height: 20),

            // ── Mô tả ──
            if (_doc.description.isNotEmpty) ...[
              _SectionTitle('Mô tả / Ghi chú'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(_doc.description, style: const TextStyle(height: 1.5)),
              ),
              const SizedBox(height: 20),
            ],

            // ── Tags ──
            if (_doc.tags.isNotEmpty) ...[
              _SectionTitle('Thẻ phân loại'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 4,
                children: _doc.tags.map((t) => Chip(
                  label: Text('#$t', style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                )).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // ── File Info ──
            if (_doc.fileName.isNotEmpty) ...[
              _SectionTitle('Tệp đính kèm'),
              const SizedBox(height: 8),
              _FileInfoCard(doc: _doc),
              const SizedBox(height: 20),
            ],

            // ── Metadata ──
            _SectionTitle('Thông tin'),
            const SizedBox(height: 8),
            _MetadataCard(doc: _doc, canEdit: canEdit, isOwner: isOwner),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final CloudDocument doc;
  const _HeaderCard({required this.doc});

  static const _docTypeColors = {
    'lecture': Color(0xFF3949AB),
    'assignment': Color(0xFF2E7D32),
    'reference': Color(0xFFE65100),
    'exam': Color(0xFFC62828),
  };

  static const _docTypeIcons = {
    'lecture': Icons.class_rounded,
    'assignment': Icons.assignment_rounded,
    'reference': Icons.book_rounded,
    'exam': Icons.quiz_rounded,
  };

  static const _docTypeLabels = {
    'lecture': 'Bài giảng',
    'assignment': 'Bài tập',
    'reference': 'Tài liệu tham khảo',
    'exam': 'Đề thi',
  };

  Color get _color => _docTypeColors[doc.docType] ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color.withOpacity(0.9), _color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_docTypeIcons[doc.docType] ?? Icons.description_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _docTypeLabels[doc.docType] ?? doc.docType,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if (doc.isFavorite) ...[
            const SizedBox(width: 8),
            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
          ],
        ]),
        const SizedBox(height: 12),
        Text(doc.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(doc.subject, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14)),
      ]),
    );
  }
}

class _FileInfoCard extends StatelessWidget {
  final CloudDocument doc;
  const _FileInfoCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    Future<void> downloadFile() async {
      try {
        final provider = context.read<CloudProvider>();
        final signedUrl = await provider.storageService
            .createDocumentDownloadUrl(
              documentId: doc.id,
              ownerUid: doc.ownerUid,
              storagePath: doc.storagePath,
            );
        if (!context.mounted) return;
        final uri = Uri.tryParse(signedUrl);
        if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
          throw StateError('Supabase trả về liên kết tải tệp không hợp lệ.');
        }
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở liên kết tải tệp.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể mở tệp: $e')),
          );
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.attach_file_rounded, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc.fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(doc.formattedFileSize, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
          if (doc.storagePath.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Tải xuống'),
              onPressed: downloadFile,
            ),
        ]),
      ]),
    );
  }
}

class _MetadataCard extends StatelessWidget {
  final CloudDocument doc;
  final bool canEdit;
  final bool isOwner;
  const _MetadataCard({
    required this.doc,
    required this.canEdit,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        _MetaRow(Icons.calendar_today_rounded, 'Ngày tạo', _fmt(doc.createdAt)),
        _MetaRow(Icons.update_rounded, 'Cập nhật', _fmt(doc.updatedAt)),
        _MetaRow(
          isOwner ? Icons.person_rounded : Icons.people_rounded,
          isOwner ? 'Của bạn' : 'Được chia sẻ',
          isOwner ? 'Chủ sở hữu' : canEdit ? 'Có quyền chỉnh sửa' : 'Quyền xem',
        ),
      ]),
    );
  }

  String _fmt(DateTime dt) => '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
  );
}