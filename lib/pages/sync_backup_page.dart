import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../colors.dart';
import '../struct/models/delete_log.dart';
import '../struct/state/document_provider.dart';
import '../database/database_global.dart';

class SyncBackupPage extends StatefulWidget {
  const SyncBackupPage({super.key});

  @override
  State<SyncBackupPage> createState() => _SyncBackupPageState();
}

class _SyncBackupPageState extends State<SyncBackupPage> {
  List<DeleteLog> _deleteLogs = [];
  bool _isLoadingLogs = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoadingLogs = true);
    final logs = await database.getAllDeleteLogs();
    if (mounted) {
      setState(() {
        _deleteLogs = logs;
        _isLoadingLogs = false;
      });
    }
  }

  Future<void> _triggerSync(DocumentProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await provider.syncClient.triggerSync();
    await _loadLogs();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Đồng bộ BYOS hoàn tất! Các tombstone logs đã được xử lý.'
              : 'Đồng bộ thất bại hoặc đang diễn ra.',
        ),
        backgroundColor: success ? AppColors.success : AppColors.danger,
      ),
    );
  }

  Future<void> _exportBackup(DocumentProvider provider) async {
    final json = await provider.exportBackup();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xuất Gói Sao Lưu JSON (BYOS)'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dữ liệu sao lưu hoàn toàn cục bộ và bảo vệ quyền riêng tư (Zero-Knowledge):',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    json,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ĐÓNG'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã sao chép chuỗi JSON sao lưu!')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('SAO CHÉP'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(DocumentProvider provider) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập Dữ Liệu Sao Lưu JSON'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Dán chuỗi JSON đã sao lưu để khôi phục cơ sở dữ liệu SQLite:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '{\n  "app": "StudyMaterialsCashew",\n  ...\n}',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            onPressed: () async {
              final json = textController.text.trim();
              if (json.isEmpty) return;

              try {
                final count = await provider.importBackup(json);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Khôi phục thành công $count tài liệu!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi định dạng: $e'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('KHÔI PHỤC'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiến trúc Cashew & Đồng bộ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Banner giải thích kiến trúc
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.layers_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Cashew Architecture Pillars',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  '1. Local-First Core: Toàn bộ dữ liệu được lưu trữ và phản ứng tức thời qua SQLite.\n'
                  '2. Reactive Streams: Tự động cập nhật UI khi dữ liệu thay đổi (watchAll...).\n'
                  '3. Tombstone Pattern: Bảng DeleteLogs lưu vết xóa giúp chống xung đột đa thiết bị.\n'
                  '4. BYOS & Privacy-First: Đồng bộ phi tập trung trên hạ tầng lưu trữ của người dùng.',
                  style: TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Khối thao tác đồng bộ & sao lưu
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
                  'THAO TÁC ĐỒNG BỘ & SAO LƯU (BYOS)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.sync_rounded, color: AppColors.primary),
                  ),
                  title: const Text('Kích hoạt Đồng bộ (Sync Simulation)'),
                  subtitle: Text(
                    provider.syncClient.lastSyncTime != null
                        ? 'Lần cuối: ${provider.syncClient.lastSyncTime}'
                        : 'Chưa chạy đồng bộ',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _triggerSync(provider),
                    child: const Text('Chạy'),
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _exportBackup(provider),
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Xuất JSON'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showImportDialog(provider),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Nhập JSON'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tombstone DeleteLogs Table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOMBSTONE DELETE LOGS (${_deleteLogs.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      onPressed: _loadLogs,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isLoadingLogs)
                  const Center(child: CircularProgressIndicator())
                else if (_deleteLogs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Không có bản ghi xóa nào đang chờ đồng bộ.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _deleteLogs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final log = _deleteLogs[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.delete_sweep_rounded, color: AppColors.danger, size: 20),
                        title: Text(
                          '${log.tableType == 0 ? "Môn học" : "Tài liệu"}: ${log.entryPk}',
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                        subtitle: Text(
                          'Thời điểm: ${log.dateTimeModified.toIso8601String()}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
