import 'dart:async';
import '../../database/app_database.dart';

/// Mô phỏng Sync Engine Client theo kiến trúc Cashew (syncClient.dart)
/// Áp dụng cơ chế Change Detection, Tombstone Pattern và BYOS (Bring Your Own Storage)
class SyncClient {
  final AppDatabase _db;
  DateTime? _lastSyncTime;
  bool _isSyncing = false;

  SyncClient(this._db);

  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isSyncing => _isSyncing;

  /// Kiểm tra các thay đổi cục bộ cần đồng bộ
  Future<Map<String, dynamic>> checkPendingChanges() async {
    final deleteLogs = await _db.getAllDeleteLogs();
    final allDocs = await _db.getAllDocuments();
    final allSubjects = await _db.getAllSubjects();

    return {
      'pendingDeletions': deleteLogs.length,
      'totalLocalDocuments': allDocs.length,
      'totalLocalSubjects': allSubjects.length,
      'lastSyncTime': _lastSyncTime?.toIso8601String() ?? 'Chưa đồng bộ',
    };
  }

  /// Mô phỏng chu trình đồng bộ đám mây cá nhân (Google Drive appDataFolder theo Cashew)
  Future<bool> triggerSync() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      // 1. Thu thập Tombstone logs
      final deleteLogs = await _db.getAllDeleteLogs();

      // Giả lập độ trễ truyền dữ liệu mạng an toàn
      await Future.delayed(const Duration(milliseconds: 600));

      // 2. Cập nhật mốc thời gian đồng bộ thành công
      _lastSyncTime = DateTime.now();

      // Trong kịch bản thực tế, sau khi remote server xác nhận tombstone đã nhận, xóa local delete logs
      if (deleteLogs.isNotEmpty) {
        await _db.clearDeleteLogs();
      }

      return true;
    } catch (_) {
      return false;
    } finally {
      _isSyncing = false;
    }
  }
}
