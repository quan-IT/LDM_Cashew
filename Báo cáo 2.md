# Learning Document Manager – Cashew Architecture

## Phát triển hệ thống quản lý tài liệu đa nền tảng với Flutter, Firebase và Supabase

## A. Tổng quan

- **Dự án:** Learning Document Manager – Cashew Architecture, ứng dụng Flutter quản lý tài liệu học tập.
- **Thư mục:** `D:\CLASS\mobile\lab1`
- **Công nghệ:** Flutter/Dart, Firebase Authentication, Google Sign-In, Firebase Storage, Cloud Functions, Supabase/PostgreSQL.
- **Ngày kiểm tra:** 13/10/2026.
- **Phạm vi:** Đánh giá mã nguồn, cấu hình trong repository và các kiểm thử có thể chạy an toàn. Không đăng nhập tài khoản thật, không kết nối hay thay đổi dữ liệu trên Firebase/Supabase thật.

### Lệnh đã chạy

| Lệnh | Kết quả |
|---|---|
| `flutter test` | Đạt: 11 bài kiểm thử unit/widget hiện có. Các bài tập trung vào SQLite cục bộ và giao diện; không kiểm thử dịch vụ cloud. |
| `flutter analyze` | Không phát hiện lỗi compile, nhưng thoát mã lỗi 1 do 25 thông tin/cảnh báo lint, chủ yếu về API deprecated và quy tắc sử dụng `BuildContext`. |
| `npm.cmd --prefix functions run build` | Đạt: TypeScript Cloud Functions biên dịch thành công. |
| Kiểm tra cấu hình Firebase | Không tìm thấy `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, hoặc `lib/firebase_options.dart`. |
| Kiểm tra CLI/backend | Không có Firebase CLI hoặc `psql` trong môi trường kiểm tra; không có bằng chứng project Firebase/Supabase thật đã được cấu hình. |

## B. Bảng đánh giá 6 checklist

> **PASS** chỉ dùng khi đã có bằng chứng đáp ứng yêu cầu trong môi trường thực tế. Việc có mã nguồn hoặc test mô phỏng không tự nó chứng minh dịch vụ thật đã hoạt động.

### 1. Thiết lập Firebase và đăng nhập Google

- **Trạng thái:** **PARTIAL**
- **Bằng chứng mã nguồn:**
  - Các dependency Firebase Auth và Google Sign-In được khai báo trong [`pubspec.yaml`](pubspec.yaml).
  - Firebase được khởi tạo trong [`lib/main.dart`](lib/main.dart).
  - [`lib/struct/services/auth_service.dart`](lib/struct/services/auth_service.dart) có luồng Google Sign-In, Firebase credential, đăng xuất và upsert hồ sơ vào Supabase.
  - Android đã khai báo plugin Google Services trong [`android/app/build.gradle.kts`](android/app/build.gradle.kts) và [`android/settings.gradle.kts`](android/settings.gradle.kts).
- **Cách/lệnh xác minh:** Kiểm tra dependency, mã nguồn, Gradle và sự hiện diện của file cấu hình Firebase.
- **Vấn đề còn tồn tại:** Thiếu file cấu hình Firebase Android/iOS và cấu hình web; chưa có bằng chứng OAuth, SHA-1 hoặc bundle ID đã được thiết lập trên Firebase Console. Chưa đăng nhập bằng Google thật để kiểm tra.
- **Việc cần làm:** Đăng ký từng ứng dụng với đúng package/bundle ID, bật Google provider, cài file cấu hình thích hợp và thử đăng nhập/đăng xuất trên thiết bị thật.

### 2. Firebase Storage và metadata trên Supabase

- **Trạng thái:** **PARTIAL**
- **Bằng chứng mã nguồn:**
  - [`lib/struct/services/storage_service.dart`](lib/struct/services/storage_service.dart) tải file lên Firebase Storage theo cấu trúc `documents/{ownerUid}/{documentId}/{fileName}`.
  - [`lib/struct/models/cloud_document.dart`](lib/struct/models/cloud_document.dart) và [`supabase/schema.sql`](supabase/schema.sql) có các trường metadata như chủ sở hữu, đường dẫn, tên file, kích thước, thời gian tạo/cập nhật.
  - [`functions/src/index.ts`](functions/src/index.ts) định nghĩa callable Function kiểm tra quyền chia sẻ trước khi cấp signed URL có thời hạn.
  - Quy tắc Storage trong [`storage.rules`](storage.rules) giới hạn truy cập trực tiếp theo UID chủ sở hữu.
- **Cách/lệnh xác minh:** Đọc luồng upload/delete, Functions và Storage Rules; build Functions bằng `npm.cmd --prefix functions run build`.
- **Vấn đề còn tồn tại:** Chưa deploy hoặc kiểm thử trên Firebase thật. Khi xóa tài liệu, app xóa metadata Supabase trước rồi mới xóa file; nếu bước xóa file thất bại, file có thể bị mồ côi. Schema có xóa URL cũ khỏi bản ghi nhưng không thể thu hồi URL token đã bị sao chép trước đó. Signed URL đã cấp vẫn hoạt động đến khi hết hạn.
- **Việc cần làm:** Deploy Functions/Storage Rules; kiểm thử upload, tải xuống, cập nhật và xóa; thiết kế quy trình retry/dọn file khi thao tác nhiều dịch vụ thất bại.

### 3. Thiết kế cơ sở dữ liệu Supabase

- **Trạng thái:** **PARTIAL**
- **Bằng chứng mã nguồn:**
  - [`supabase/schema.sql`](supabase/schema.sql) định nghĩa các bảng `users`, `documents`, `document_permissions`, khóa ngoại, index và các ràng buộc loại quyền.
  - [`lib/struct/services/supabase_service.dart`](lib/struct/services/supabase_service.dart) triển khai các truy vấn tạo, đọc, cập nhật, xóa, tìm kiếm và chia sẻ.
- **Cách/lệnh xác minh:** Đối chiếu schema với models/services và kiểm tra kiểu dữ liệu, khóa ngoại, unique constraint.
- **Vấn đề còn tồn tại:** Chưa chạy schema trên Supabase thật; chưa xác minh bảng, dữ liệu hoặc truy vấn bằng tài khoản đã xác thực. Policy SELECT bảng `users` cho phép mọi người dùng đã xác thực đọc hồ sơ, bao gồm email; cần đánh giá mức dữ liệu tối thiểu cần thiết.
- **Việc cần làm:** Chạy migration trên môi trường thử nghiệm trước; xác nhận cấu trúc thực tế và rà soát quyền đọc hồ sơ người dùng.

### 4. Tìm kiếm, cập nhật và chia sẻ tài liệu

- **Trạng thái:** **PARTIAL**
- **Bằng chứng mã nguồn:**
  - Tìm kiếm/lọc có trong [`lib/struct/services/supabase_service.dart`](lib/struct/services/supabase_service.dart) và trạng thái lọc tại [`lib/struct/state/cloud_provider.dart`](lib/struct/state/cloud_provider.dart).
  - Giao diện chỉnh sửa nằm ở [`lib/pages/add_edit_cloud_document_page.dart`](lib/pages/add_edit_cloud_document_page.dart).
  - Chia sẻ và thu hồi quyền nằm trong [`lib/pages/share_document_page.dart`](lib/pages/share_document_page.dart) và service Supabase.
  - Giao diện chi tiết phân biệt chủ sở hữu và người có quyền sửa trong [`lib/pages/cloud_document_detail_page.dart`](lib/pages/cloud_document_detail_page.dart).
- **Cách/lệnh xác minh:** Rà soát luồng UI → provider → service và chạy test Flutter hiện có.
- **Vấn đề còn tồn tại:** Chưa có integration test với Supabase/Storage thật; chưa xác minh hành vi lỗi mạng, dữ liệu không tồn tại, hoặc quyền bị thu hồi khi người dùng đang mở tài liệu.
- **Việc cần làm:** Kiểm thử trên staging bằng tài khoản A/B/C, bao gồm cập nhật metadata, sửa quyền, thu hồi quyền và thử gọi API trực tiếp.

### 5. Chính sách bảo mật Supabase RLS

- **Trạng thái:** **PARTIAL**
- **Bằng chứng mã nguồn:**
  - [`supabase/schema.sql`](supabase/schema.sql) bật RLS cho cả ba bảng và định nghĩa policies cho SELECT/INSERT/UPDATE/DELETE.
  - Policies lấy UID từ Firebase JWT đã được Supabase xác thực, thay vì tin UID do client tự khai báo.
  - Có trigger ngăn thay đổi chủ sở hữu tài liệu và giới hạn thay file đính kèm cho chủ sở hữu.
- **Cách/lệnh xác minh:** Kiểm tra schema và đọc test SQL ba danh tính tại [`supabase/tests/rls_three_users.sql`](supabase/tests/rls_three_users.sql).
- **Vấn đề còn tồn tại:** Chưa áp dụng schema lên Supabase thật hoặc kiểm thử RLS qua API thật. Test SQL hiện có lỗi phạm vi biến: `insert_rejected` được dùng nhưng không khai báo trong block người xem; `ownership_change_rejected` và `file_change_rejected` được dùng ở block người sửa nhưng không khai báo trong block đó. Vì vậy test này chưa thể được coi là đã chạy đạt. Thêm nữa, policy đọc bảng users đang mở cho mọi người dùng đã xác thực.
- **Việc cần làm:** Sửa biến và xác nhận script chạy trên môi trường thử nghiệm; xác minh trực tiếp rằng người xem không thể sửa, người sửa không thể xóa/đổi owner/thay file, và người chưa được chia sẻ không thể đọc.

### 6. Kiểm thử với ít nhất 3 tài khoản người dùng

- **Trạng thái:** **NOT VERIFIED**
- **Bằng chứng hiện có:** Có 11 unit/widget tests local, nhưng không có integration test Firebase/Supabase và không có biên bản/kết quả kiểm thử với ba tài khoản Google thật.
- **Cách/lệnh xác minh:** `flutter test` đạt 11 bài; kiểm tra thư mục [`test/`](test/) cho thấy các bài hiện tại tập trung vào SQLite và giao diện.
- **Vấn đề còn tồn tại:** Chưa tạo hoặc sử dụng tài khoản thật (không tự ý làm điều đó); test RLS SQL mô phỏng chưa chạy và hiện có lỗi biến.
- **Kế hoạch kiểm thử cần thực hiện:**
  1. **A:** đăng nhập, tạo tài liệu, upload file, xác nhận metadata; chia sẻ tài liệu 1 cho B quyền xem và tài liệu 2 cho C quyền sửa.
  2. **B:** đăng nhập và xác nhận chỉ thấy tài liệu được chia sẻ; thử sửa/xóa qua UI và API, xác nhận backend từ chối; mở file khi còn quyền, thử lại sau khi bị thu hồi.
  3. **C:** xác nhận chỉ thấy tài liệu được chia sẻ cho C; sửa metadata thành công; thử xóa tài liệu, thay file và đổi owner, xác nhận backend từ chối.
  4. **A:** xác nhận vẫn quản lý được tài liệu, thay đổi/thu hồi quyền; kiểm tra B/C không lấy được signed URL mới sau khi thu hồi.
  5. Đăng xuất/đổi tài khoản và xác nhận dữ liệu tài khoản trước không còn hiển thị.
- **Bằng chứng nghiệm thu:** Lưu kết quả từng bước, UID đã che một phần, thời điểm thử, ảnh/chụp phản hồi UI và kết quả API/RLS; không ghi token hoặc khóa bí mật.

## C. Lỗi và mức độ ưu tiên

| Mức độ | Vấn đề | Bằng chứng / nguyên nhân | Hướng xử lý |
|---|---|---|---|
| **High** | Chưa có cấu hình Firebase của các nền tảng | Các file `google-services.json`, `GoogleService-Info.plist` và `firebase_options.dart` không tồn tại tại các vị trí dự kiến. Do đó chưa thể khởi tạo/xác nhận Firebase thật. | Tạo/cấu hình app trong Firebase Console và cung cấp file phù hợp; không đưa bí mật backend vào Flutter. |
| **High** | Test RLS ba tài khoản mô phỏng có lỗi scope biến | [`supabase/tests/rls_three_users.sql`](supabase/tests/rls_three_users.sql): các cờ `insert_rejected`, `ownership_change_rejected`, `file_change_rejected` không được khai báo đúng block sử dụng. | Khai báo từng biến trong block `DO` tương ứng, rồi chạy trên Supabase staging. |
| **Medium** | Nguy cơ file mồ côi khi xóa tài liệu lỗi giữa chừng | [`lib/struct/state/cloud_provider.dart`](lib/struct/state/cloud_provider.dart): xóa metadata trước, file Storage sau. | Thêm trạng thái xóa/retry hoặc job dọn file; ghi nhận lỗi thay vì bỏ qua. |
| **Medium** | Hồ sơ người dùng có thể bị đọc rộng | [`supabase/schema.sql`](supabase/schema.sql): SELECT policy `users` cho phép mọi tài khoản xác thực đọc hồ sơ. | Giới hạn trường/profile có thể truy cập, hoặc chuyển tra cứu chia sẻ qua backend tin cậy. |
| **Medium** | Chưa có xác minh vận hành RLS và chia sẻ file | Schema/Functions mới được kiểm tra tĩnh và build; chưa deploy hoặc gọi dịch vụ thật. | Deploy staging, chạy test RLS và thử truy cập trực tiếp bằng các tài khoản riêng biệt. |
| **Low** | Flutter analyzer còn 25 thông tin/cảnh báo | `flutter analyze` không báo lỗi compile nhưng trả mã lỗi 1 do lint/info, chủ yếu `withOpacity` deprecated và cảnh báo async context. | Dọn cảnh báo sau khi xử lý các vấn đề xác thực và bảo mật. |
| **Low** | Functions khai báo Node 20 nhưng môi trường build dùng Node 24 | `npm install` trước đó báo `EBADENGINE`; TypeScript build vẫn thành công. | Dùng Node 20 để khớp runtime Functions hoặc xác nhận tương thích theo cấu hình Firebase triển khai. |

## D. Kế hoạch hoàn thiện theo thứ tự ưu tiên

1. **Firebase:** cấu hình project, Google provider, Android SHA-1, iOS bundle ID và file cấu hình; kiểm tra đăng nhập/đăng xuất trên thiết bị.
2. **Supabase/Auth:** cấu hình Firebase làm third-party auth provider, cấp project URL và publishable key cho app, cấu hình secret chỉ trong môi trường Cloud Functions.
3. **Sửa và chạy test RLS:** sửa lỗi khai báo biến trong `rls_three_users.sql`; chạy schema/test trên staging; xác nhận các hành vi từ chối/cho phép bằng request đã xác thực.
4. **Deploy Storage/Functions:** deploy `storage.rules`, `ensureSupabaseRole` và `getAuthorizedDocumentUrl`; kiểm tra quyền service account để ký signed URL.
5. **Kiểm thử tích hợp:** thử upload, metadata, search, update, share/revoke, tải file, xóa file và xử lý lỗi giữa các dịch vụ.
6. **Kiểm thử A/B/C:** chạy ma trận quyền trong checklist 6; kiểm tra API trực tiếp, URL tải file, đổi tài khoản và đăng xuất; lưu bằng chứng.
7. **Ổn định và nghiệm thu:** xử lý file mồ côi, rà soát phạm vi đọc bảng users, giảm lint và chạy lại `flutter test`, `flutter analyze`, Functions build.

## E. Kết luận

1. **Số checklist được xác minh hoàn tất end-to-end: 0/6.**
2. **Checklist có phần triển khai trong mã nguồn nhưng chưa xác minh trên dịch vụ thật:** 1, 2, 3, 4 và 5.
3. **Checklist còn thiếu bằng chứng kiểm thử thực tế:** 6; test SQL mô phỏng cần sửa lỗi scope trước khi dùng.
4. **Chưa kiểm thử với đủ ba tài khoản Google thật.**
5. Để đủ điều kiện nghiệm thu cần cấu hình và deploy Firebase/Supabase staging, sửa và chạy test RLS, kiểm thử trực tiếp API và file bằng A/B/C, rồi lưu kết quả. `flutter test` đạt và Functions build thành công chỉ xác nhận một phần mã nguồn; chúng không chứng minh dịch vụ thật hoặc chính sách RLS đã hoạt động.
