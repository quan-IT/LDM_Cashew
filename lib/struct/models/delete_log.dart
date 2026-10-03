/// Ghi nhận nhật ký xóa phục vụ Tombstone Pattern theo chuẩn kiến trúc Cashew
class DeleteLog {
  final String deleteLogPk;
  final String entryPk;
  final int tableType; // 0: Subject, 1: Document
  final DateTime dateTimeModified;

  DeleteLog({
    required this.deleteLogPk,
    required this.entryPk,
    required this.tableType,
    required this.dateTimeModified,
  });

  Map<String, dynamic> toMap() {
    return {
      'deleteLogPk': deleteLogPk,
      'entryPk': entryPk,
      'tableType': tableType,
      'dateTimeModified': dateTimeModified.toIso8601String(),
    };
  }

  factory DeleteLog.fromMap(Map<String, dynamic> map) {
    return DeleteLog(
      deleteLogPk: map['deleteLogPk'] as String,
      entryPk: map['entryPk'] as String,
      tableType: map['tableType'] as int? ?? 1,
      dateTimeModified: DateTime.tryParse(map['dateTimeModified'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
