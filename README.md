# Learning Document Manager – Cashew Architecture

Ứng dụng Flutter đa nền tảng hỗ trợ quản lý tài liệu học tập theo kiến trúc
Cashew. Dự án kết hợp lưu trữ cục bộ với dịch vụ đám mây để người dùng có thể
tổ chức, tìm kiếm và chia sẻ tài liệu.

## Chức năng chính

- Quản lý tài liệu học tập cục bộ bằng SQLite.
- Đăng nhập Google thông qua Firebase Authentication.
- Tải tệp lên Supabase Storage (bucket private `learning-documents`) theo cấu trúc:
  `documents/{userUid}/{documentId}/original.{extension}`.
- Lưu metadata và quyền chia sẻ tài liệu trong Supabase.
- Tìm kiếm, cập nhật tài liệu và chia sẻ theo quyền xem/chỉnh sửa.
- Sử dụng Supabase Row Level Security để kiểm soát truy cập dữ liệu.

> Các chức năng cloud cần cấu hình Firebase và Supabase riêng trước khi chạy.
> Mã nguồn hoặc test local không đồng nghĩa dịch vụ cloud đã được cấu hình hoặc
> triển khai/xác minh.

## Công nghệ

- Flutter / Dart
- SQLite (`sqflite`)
- Firebase Core, Firebase Authentication, Google Sign-In
- Firebase Cloud Functions
- Supabase Flutter / PostgreSQL
- Provider

## Cấu trúc repository

```text
lib/
  database/       SQLite và dữ liệu cục bộ
  pages/          Màn hình quản lý tài liệu
  struct/
    models/       Model dữ liệu
    services/     Firebase, Supabase và nghiệp vụ
    state/        State management
  widgets/        Thành phần giao diện dùng lại
functions/        Firebase Cloud Functions
storage.rules     Quy tắc truy cập Firebase Storage
supabase/         Schema và kiểm thử RLS
test/             Unit/widget tests
```

## Bắt đầu

### Cài dependency và chạy test local

```powershell
flutter pub get
flutter test
```

### Chạy ứng dụng với các dịch vụ cloud

Trước khi chạy cần:

1. Cấu hình Firebase Android/iOS, bật Google Sign-In và kiểm tra Authorized
   domains cho Web.
2. Deploy Cloud Functions cần thiết cho custom claim Supabase; không cần
   Firebase Storage Rules cho các tệp mới của luồng này.
3. Trong Supabase Dashboard, cấu hình Firebase làm third-party Auth provider
   để Supabase xác thực Firebase ID token. Tài khoản và mật khẩu vẫn do Firebase
   Auth quản lý; bảng `public.users` chỉ lưu hồ sơ, không lưu mật khẩu.
4. Trong Supabase Dashboard → SQL Editor, kiểm tra schema/policy hiện có rồi
   chạy `supabase/schema.sql`. Script bật RLS và tạo policy cho `users`,
   `documents` và `document_permissions`. Chủ tài liệu đọc/sửa/xóa tài liệu của
   mình; người được chia sẻ có thể đọc; quyền `edit` cho phép cập nhật metadata;
   chỉ chủ sở hữu mới có thể xóa tài liệu hoặc thay tệp. Người dùng chỉ được
   đọc/cập nhật hồ sơ của chính mình, còn quyền chia sẻ chỉ do chủ tài liệu
   quản lý. Script không xóa hồ sơ, tài liệu, quyền chia sẻ hoặc URL đang lưu;
   các ràng buộc quan hệ mới dùng `NOT VALID` để không xóa/chặn dữ liệu cũ khi
   cài đặt.
5. Sau khi xem trước, chạy
   `supabase/migrations/20261014000000_learning_documents_storage.sql` để tạo
   bucket private `learning-documents` (tối đa 50 MiB) và các policy Storage.
   Policy Storage chỉ cho chủ sở hữu upload, thay thế và xóa object trong
   `documents/{uid}/{documentId}/...`; chủ tài liệu và người được chia sẻ mới
   được đọc object tương ứng. Script dừng nếu bucket cùng tên đã tồn tại nhưng
   cấu hình khác. Việc đổi luồng ứng dụng không tự di chuyển các tệp đang nằm
   trong Firebase Storage; các tệp cũ cần được chuyển sang bucket này trước
   khi tải lại.
6. Cung cấp Supabase URL và publishable key cho ứng dụng bằng `--dart-define`.

Các script chỉ được chuẩn bị trong repository, không tự kết nối/chạy trên
project Supabase thật. Trước khi áp dụng, kiểm tra lại các bảng và chính sách
đang có. Có thể xem danh sách policy bằng:

```sql
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname IN ('public', 'storage')
ORDER BY schemaname, tablename, policyname;
```

Các policy trên chỉ tồn tại trong project thật sau khi chạy hai script SQL ở
trên; chúng không được áp dụng tự động từ repository. Tải lên/tải xuống/xóa
tệp qua Supabase Storage còn cần Firebase ID token có claim
`role=authenticated`, và cấu hình Supabase third-party Firebase Auth ở bước
trên. Signed URL tải xuống có thời hạn 5 phút; quyền truy cập được kiểm tra
bởi policy private bucket khi tạo URL. Các tệp cũ trong Firebase Storage không
được tự động chuyển hoặc xóa.

Kiểm thử RLS bằng `supabase/tests/rls_three_users.sql` sau khi cài schema. Bộ
kiểm thử dùng UID giả trong transaction và `ROLLBACK`, không tạo tài khoản
Firebase/Supabase thật.

Hướng dẫn triển khai và kiểm thử chi tiết được ghi trong
[Báo cáo 1](<./Báo cáo 1.md>). Báo cáo đánh giá hiện trạng checklist nằm tại
[Báo cáo 2](<./Báo cáo 2.md>).

## Kiểm thử

```powershell
flutter test
flutter analyze
npm.cmd --prefix functions run build
```

Các bài `flutter test` hiện tập trung vào logic cục bộ và kiểm thử đơn vị.
Chúng không thay thế kiểm thử tích hợp với Firebase/Supabase hoặc kiểm thử
phân quyền bằng các tài khoản người dùng thật.
