# Báo Cáo Kiến Trúc: Ứng Dụng Quản Lý Tài Liệu Học Tập
## Áp dụng Kiến Trúc Cashew

---

## 1. Giới Thiệu Kiến Trúc Cashew

**Cashew** là kiến trúc ứng dụng theo triết lý **Local-First**, nơi dữ liệu được lưu trữ và xử lý cục bộ trước tiên, đảm bảo ứng dụng hoạt động được ngay cả khi không có kết nối mạng. Các nguyên lý cốt lõi được áp dụng trong dự án này:

| Nguyên lý | Mô tả | Triển khai trong dự án |
|-----------|-------|----------------------|
| **Local-First Storage** | Dữ liệu lưu vào SQLite cục bộ trước | `AppDatabase` + `sqflite` |
| **Reactive Streams** | UI cập nhật tự động khi dữ liệu thay đổi | `StreamController.broadcast()` + `Provider` |
| **Tombstone DeleteLogs** | Xóa mềm ghi log để hỗ trợ đồng bộ phân tán | Bảng `DeleteLogs`, `tableType` flag |
| **BYOS (Backup)** | Người dùng tự quản lý bản sao lưu | `exportBackupJson()` / `importBackupJson()` |
| **Schema Versioning** | Hỗ trợ nâng cấp lược đồ CSDL | `schemaVersion`, `onUpgrade` callback |

---

## 2. Sơ Đồ Kiến Trúc Phân Lớp

```
┌─────────────────────────────────────────────────────────────────┐
│                    TẦNG GIAO DIỆN (UI Layer)                    │
│  HomePage │ AddEditDocumentPage │ DocumentDetailPage │ ...       │
│  Widgets: DocumentCard, SearchBarWidget, StatsHeaderCard, ...   │
│                      [Chỉ đọc State, không có Logic]            │
└───────────────────────────┬─────────────────────────────────────┘
                            │ watch / notify (Provider Pattern)
┌───────────────────────────▼─────────────────────────────────────┐
│                  TẦNG TRẠNG THÁI (State Layer)                  │
│  DocumentProvider (ChangeNotifier)                               │
│  • Lắng nghe Reactive Streams từ AppDatabase                    │
│  • Áp dụng bộ lọc tìm kiếm qua DocumentService                 │
│  • Cầu nối giữa UI và Business Logic                            │
└──────────┬──────────────────────────────────┬───────────────────┘
           │ gọi                              │ đăng ký stream
┌──────────▼──────────────┐     ┌────────────▼──────────────────┐
│  TẦNG NGHIỆP VỤ (BLL)  │     │   REACTIVE STREAMS ENGINE     │
│  DocumentService        │     │   watchAllDocuments()          │
│  • validateDocument()   │     │   watchAllSubjects()           │
│  • createDocument()     │     │   StreamController.broadcast() │
│  • filterAndSort...()   │     └────────────┬──────────────────┘
│  • calculateStatistics()│                  │ emit khi DB thay đổi
│  • exportBackupJson()   │     ┌────────────▼──────────────────┐
│  SubjectService         │     │  TẦNG DỮ LIỆU (Data Layer)   │
│  SyncClient             │     │  AppDatabase (SQLite / FFI)   │
└──────────┬──────────────┘     │  • getAllDocuments()           │
           │ CRUD               │  • insertDocument()            │
           └────────────────────│  • updateDocument()            │
                                │  • deleteDocument() + Tombstone│
                                │  • getAllDeleteLogs()           │
                                └───────────────────────────────┘
```

---

## 3. Cấu Trúc Thư Mục Dự Án

```
lib/
├── main.dart                    # Điểm vào app, khởi tạo DB
├── colors.dart                  # Design tokens
├── database/
│   ├── app_database.dart        # Data Layer: CRUD + Reactive Streams
│   ├── database_global.dart     # Singleton DB instance toàn cục
│   ├── tables.dart              # SQL schema definitions
│   └── default_data.dart        # Dữ liệu mẫu khởi tạo
├── struct/                      # Nhân lõi theo kiến trúc Cashew
│   ├── models/
│   │   ├── study_document.dart  # Model tài liệu học tập
│   │   ├── subject.dart         # Model môn học
│   │   ├── doc_type.dart        # Enum loại tài liệu
│   │   └── delete_log.dart      # Model Tombstone log
│   ├── services/
│   │   ├── document_service.dart  # BLL: validate, filter, stats, backup
│   │   ├── subject_service.dart   # BLL: quản lý môn học
│   │   └── sync_client.dart       # BLL: mô phỏng đồng bộ BYOS
│   ├── helpers/
│   │   └── date_formats.dart    # Helper định dạng ngày giờ
│   └── state/
│       └── document_provider.dart  # State Layer: ChangeNotifier
├── pages/
│   ├── home_page.dart           # Màn hình chính
│   ├── add_edit_document_page.dart  # Thêm/sửa tài liệu
│   ├── document_detail_page.dart    # Chi tiết tài liệu
│   ├── subject_management_page.dart # Quản lý môn học
│   └── sync_backup_page.dart        # Sao lưu & Kiến trúc Cashew
└── widgets/
    ├── document_card.dart        # Card hiển thị tài liệu
    ├── stats_header_card.dart    # Thống kê dashboard
    ├── search_bar_widget.dart    # Thanh tìm kiếm
    ├── subject_chip.dart         # Chip lọc môn học
    └── empty_state_widget.dart   # UI trống

test/
├── database_test.dart           # Test Tầng Dữ Liệu
├── document_service_test.dart   # Test Tầng Nghiệp Vụ
└── widget_test.dart             # Test Tầng Giao Diện
```

---

## 4. Các Chức Năng Cốt Lõi

### 4.1 CRUD Tài Liệu Học Tập
- **Thêm**: `DocumentService.createDocument()` → validate → `AppDatabase.insertDocument()` → stream emit
- **Sửa**: `DocumentService.updateDocument()` → validate → `AppDatabase.updateDocument()` → stream emit
- **Xóa**: `AppDatabase.deleteDocument()` → ghi `DeleteLog` (Tombstone) → xóa vật lý → stream emit
- **Tìm kiếm**: `DocumentService.filterAndSortDocuments()` — lọc theo keyword, môn học, loại tài liệu, yêu thích

### 4.2 Tombstone DeleteLogs (Cashew Pattern)
Khi xóa tài liệu, thay vì xóa thẳng, hệ thống:
1. Ghi một bản ghi vào bảng `DeleteLogs` với timestamp
2. Mới thực sự xóa bản ghi khỏi bảng chính
3. `DeleteLog` được dùng để giải quyết xung đột khi đồng bộ đa thiết bị

### 4.3 Reactive Streams
`AppDatabase` sử dụng `StreamController.broadcast()`:
- Mỗi khi insert/update/delete → gọi `_notifyDocumentsChanged()` → phát luồng
- `DocumentProvider` lắng nghe stream qua `watchAllDocuments().listen()`
- UI được rebuild tự động thông qua `ChangeNotifier.notifyListeners()`

### 4.4 BYOS Backup (Bring Your Own Storage)
- **Xuất**: `DocumentService.exportBackupJson()` → JSON gồm subjects + documents + deleteLogs
- **Nhập**: `DocumentService.importBackupJson()` → parse JSON → restore vào DB cục bộ
- Format: `{"app":"StudyMaterialsCashew","version":"1.0.0","exportedAt":"...","subjects":[...],"documents":[...],"deleteLogs":[...]}`

---

## 5. Luồng Dữ Liệu (Data Flow Diagram)

```
[Người dùng nhập]
      │
      ▼
[UI Widget (TextField / Button)]
      │ callback
      ▼
[DocumentProvider.addDocument() / setSearchQuery()]
      │ gọi service
      ▼
[DocumentService.validateDocument() → createDocument()]
      │ nếu hợp lệ
      ▼
[AppDatabase.insertDocument()] ──→ [SQLite DB]
      │ sau khi lưu
      ▼
[_notifyDocumentsChanged()] ──→ [StreamController.add(docs)]
      │ reactive emit
      ▼
[DocumentProvider._docsSub.listen()] ──→ [notifyListeners()]
      │ rebuild UI
      ▼
[HomePage rebuild với dữ liệu mới]
```

---

## 6. Kết Quả Kiểm Thử

```
✅ 11/11 tests PASS  (flutter test --reporter expanded)
✅ 0 issues  (flutter analyze)

Tầng Dữ Liệu (database_test.dart):
  ✅ Khởi tạo CSDL in-memory và kiểm tra dữ liệu mẫu
  ✅ CRUD Tài liệu học tập (Insert, Read, Update, Delete)
  ✅ Chuyển đổi trạng thái Yêu thích (toggleFavorite)
  ✅ Reactive Streams phát tín hiệu khi có thay đổi dữ liệu

Tầng Nghiệp Vụ (document_service_test.dart):
  ✅ Xác thực hợp lệ khi thêm tài liệu (Validation logic)
  ✅ Thuật toán tìm kiếm và lọc đa tiêu chí (Search & Multi-criteria Filtering)
  ✅ Tính toán số liệu thống kê Dashboard (calculateStatistics)
  ✅ Xuất và Nhập Gói Sao Lưu JSON (BYOS Backup & Restore)

Tầng Giao Diện (widget_test.dart):
  ✅ Khởi chạy ứng dụng và hiển thị màn hình chính với dữ liệu
  ✅ Tìm kiếm tài liệu học tập theo từ khóa
  ✅ Màn hình hiển thị empty state khi không có kết quả
```

---

## 7. Công Nghệ Sử Dụng

| Package | Mục đích |
|---------|----------|
| `sqflite` + `sqflite_common_ffi` | Local SQLite database (Local-First) |
| `path_provider` | Tìm thư mục lưu DB theo platform |
| `provider` | State management (ChangeNotifier pattern) |
| `uuid` | Tạo Primary Key UUID v4 |
| `path` | Xây dựng đường dẫn file |
| `flutter_test` | Unit + Widget testing framework |

---

*Báo cáo này đáp ứng đầy đủ 5 tiêu chí của checklist:*
1. ✅ **Phân tích yêu cầu & sơ đồ luồng dữ liệu** — Xem mục 4, 5
2. ✅ **Cấu trúc thư mục & phân lớp Cashew** — Xem mục 2, 3
3. ✅ **CRUD + Tìm kiếm** — Xem mục 4.1
4. ✅ **Kiểm thử phân tách logic giữa các lớp** — 11/11 tests PASS
5. ✅ **Báo cáo kiến trúc Cashew** — Tài liệu này
