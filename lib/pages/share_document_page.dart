import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../colors.dart';
import '../struct/models/cloud_document.dart';
import '../struct/models/document_permission.dart';
import '../struct/state/cloud_provider.dart';

/// Trang quản lý chia sẻ tài liệu
class ShareDocumentPage extends StatefulWidget {
  final CloudDocument document;
  const ShareDocumentPage({super.key, required this.document});

  @override
  State<ShareDocumentPage> createState() => _ShareDocumentPageState();
}

class _ShareDocumentPageState extends State<ShareDocumentPage> {
  final _emailController = TextEditingController();
  PermissionLevel _selectedPermission = PermissionLevel.view;
  bool _isSharing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    await context.read<CloudProvider>().loadDocumentPermissions(widget.document.id);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _shareDocument() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ email'), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _isSharing = true);
    try {
      final msg = await context.read<CloudProvider>().shareDocument(
        documentId: widget.document.id,
        targetEmail: email,
        permission: _selectedPermission,
      );
      if (mounted) {
        _emailController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _revokePermission(DocumentPermission perm) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi quyền truy cập?'),
        content: Text('Thu hồi quyền của ${perm.sharedWithEmail}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('THU HỒI'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<CloudProvider>().revokePermission(widget.document.id, perm.sharedWithUid);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CloudProvider>();
    final permissions = provider.currentDocPermissions;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chia sẻ tài liệu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.document.title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Thông tin tài liệu ──
                  _DocumentInfoCard(document: widget.document),
                  const SizedBox(height: 24),

                  // ── Chia sẻ mới ──
                  const Text(
                    'Chia sẻ cho người dùng khác',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email người nhận',
                            hintText: 'example@gmail.com',
                            prefixIcon: const Icon(Icons.email_rounded, color: AppColors.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Quyền truy cập: ', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SegmentedButton<PermissionLevel>(
                                segments: PermissionLevel.values.map((p) {
                                  return ButtonSegment<PermissionLevel>(
                                    value: p,
                                    label: Text(p.label, style: const TextStyle(fontSize: 12)),
                                    icon: Icon(
                                      p == PermissionLevel.view ? Icons.visibility_rounded : Icons.edit_rounded,
                                      size: 14,
                                    ),
                                  );
                                }).toList(),
                                selected: {_selectedPermission},
                                onSelectionChanged: (s) => setState(() => _selectedPermission = s.first),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSharing ? null : _shareDocument,
                            icon: _isSharing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.share_rounded),
                            label: Text(_isSharing ? 'Đang chia sẻ...' : 'Chia sẻ'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Danh sách quyền hiện tại ──
                  Row(
                    children: [
                      const Text(
                        'Đang chia sẻ với',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${permissions.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (permissions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.group_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Chưa chia sẻ với ai', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...permissions.map((perm) => _PermissionTile(
                          permission: perm,
                          onRevoke: () => _revokePermission(perm),
                        )),
                ],
              ),
            ),
    );
  }
}

class _DocumentInfoCard extends StatelessWidget {
  final CloudDocument document;
  const _DocumentInfoCard({required this.document});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_rounded, color: AppColors.primary, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${document.subject} • ${document.docType}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (document.fileName.isNotEmpty)
                  Text(document.fileName, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final DocumentPermission permission;
  final VoidCallback onRevoke;
  const _PermissionTile({required this.permission, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final isEdit = permission.permission == PermissionLevel.edit;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            permission.sharedWithEmail.isNotEmpty
                ? permission.sharedWithEmail[0].toUpperCase()
                : '?',
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(permission.sharedWithEmail, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Được chia sẻ lúc ${_formatDate(permission.createdAt)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isEdit ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isEdit ? Icons.edit_rounded : Icons.visibility_rounded,
                    size: 12,
                    color: isEdit ? Colors.orange : Colors.blue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    permission.permission.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isEdit ? Colors.orange : Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger, size: 20),
              tooltip: 'Thu hồi quyền',
              onPressed: onRevoke,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}