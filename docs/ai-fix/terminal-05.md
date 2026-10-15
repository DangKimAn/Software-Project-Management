# Báo Cáo Triển Khai — TERMINAL 05 (Admin Portal, Realtime Socket.IO, Notifications, Design System & Blog)

## 1. Tóm tắt từng Bug đã xử lý

| Mã Bug | Mức độ | Mô tả vấn đề gốc | Giải pháp đã triển khai |
| :--- | :---: | :--- | :--- |
| **BUG-05** | P0 | Backend gửi sự kiện `message:new` theo envelope `{ conversationId, message: {...}, conversation: {...} }`, nhưng Flutter parse nhầm toàn bộ envelope thành `ChatMessageItem` dẫn đến mất `id`, `senderId`, `content`, `createdAt`. | Bổ sung `SocketMessageEnvelope` và cập nhật `ChatMessageItem.fromJson` để bóc tách đúng `payload['message']`, kiểm tra `conversationId`, lọc bỏ tin nhắn khác hội thoại, khử trùng lặp ID sau reconnect (`mergeAndSortMessages`), sắp xếp theo `(createdAt, id)`, gỡ listener khi `dispose` và đồng bộ lại qua `socket.onConnected`. |
| **BUG-06** | P0 | `ConversationItem.fromJson` đọc nhầm trường `guest`/`host` thay vì `otherParticipant`, `guestUserId`, `hostUserId` của backend; thiếu gọi `PATCH /api/conversations/:id/read`. | Ánh xạ đầy đủ `otherParticipant` (`userId`, `fullName`, `avatarUrl`), `guestUserId`, `hostUserId`, `lastMessagePreview`, `lastMessageAt`, `unreadCount`. Bổ sung `displayNameFor(currentUserId)` và `avatarFor(currentUserId)` để không bao giờ fallback mù quáng mọi cuộc trò chuyện thành `"Chủ nhà"`. Hoàn thiện `markConversationRead(conversationId)` gọi `PATCH /api/conversations/:id/read` và cập nhật `unreadCount` theo kết quả server. |
| **BUG-28** | P1 | `SocketService` gắn trực tiếp JWT vào URL query string (`?token=...`), có nguy cơ lộ token qua access log/proxy và không xử lý đổi token hoặc dọn sạch sau logout. | Loại bỏ hoàn toàn `token` khỏi URL query string (`buildSocketUri` chỉ giữ `EIO=4&transport=websocket`). Chuyển sang xác thực qua Socket.IO CONNECT namespace packet (`40{"token":"..."}`) tương thích với `socket.handshake.auth.token` của Express middleware (`socket.ts`). Hỗ trợ `refreshAuthToken()` khi token thay đổi, phát sự kiện `onConnected` khi kết nối/kết nối lại và xóa sạch trạng thái khi `disconnect()` / logout. |
| **BUG-21** | P1 | `AppNotificationItem` đọc nhầm `message` thay vì `body`, bỏ sót `eventType`, `actionUrl`, `targetType`, `targetId`; chưa kết nối realtime `notification:new` chuẩn vòng đời đăng nhập/đăng xuất. | Cập nhật `AppNotificationItem.fromJson` parse đầy đủ `notificationLogId`, `eventType`, `targetType`, `targetId`, `title`, `body`, `actionUrl`, `payload`, `isRead`, `readAt`, `createdAt`, `updatedAt`. Bổ sung `isSafeInternalRoute` và `resolveInternalRoute` chặn mọi URL ngoài không tin cậy (`http://`, `https://`, `//`, `javascript:`). Kết nối `notification:new` qua `SocketService`, đồng bộ lại khi reconnect, hỗ trợ đánh dấu đã đọc (`PATCH /api/notifications/:id/read`), đọc tất cả (`PATCH /api/notifications/read-all`) và xóa sạch state khi logout (`clearForLogout`). |
| **BUG-14** | P0 | `getAdminUsers` có nguy cơ gửi `limit > 100` gây lỗi 422 từ `listUsersQuerySchema`; khóa tài khoản gửi `'blocked'` không khớp enum DB MySQL (`suspended`); thông báo lỗi chung chung. | Clamp `limit.clamp(1, 100)` trong `getAdminUsersPaginated` & `getAdminUsers`. Chuẩn hóa trạng thái khóa tài khoản sang `'suspended'` (hỗ trợ lọc `all`, `active`, `suspended`, `inactive` và lọc theo `role`). Giữ phân trang đầy đủ (`page`, `totalPages`, `total`), kiểm tra không cho tự khóa chính mình, trích xuất thông báo lỗi chi tiết 400/403/422 qua `AdminRepository.extractErrorMessage` và chỉ hiện `AppToast` khi API thành công. |
| **BUG-30** | P1 | Admin Overview luôn hiển thị `Host = 0` do đọc `totalHosts` thay vì `hostsCreated`/`activeHosts`; thiếu biểu đồ doanh thu & bộ lọc thời gian; Listing Moderation thiếu hiển thị AI Image Analysis và nút phân tích lại AI; Hồ sơ Host thiếu bảng Legacy Verifications; Phân quyền thiếu role `moderator`. | **Overview**: Đọc đầy đủ `hostsCreated`/`activeHosts`/`verifiedHosts`, thêm bộ lọc `7/30/90 ngày` + `Theo ngày/tháng` và biểu đồ doanh thu (`revenueSeries`). **Moderation**: Hiển thị chi tiết AI Image Analysis (`aiAnalysisStatus`, `aiImageType`, `aiConfidence`, `aiSceneTags`, `aiAmenityTags`, `aiQualityWarnings`, `aiErrorMessage`) kèm nút phân tích lại AI từng ảnh (`POST /api/admin/images/:imageId/reanalyze`) và toàn bộ ảnh (`POST /api/ai/listings/:listingId/analyze-images?force=true`). **Host Applications**: Bổ sung bảng **Legacy Verifications** (`/api/admin/verifications` + approve/reject). **Role Management**: Bổ sung `moderator` (`guest`, `host`, `moderator`, `admin`), kiểm tra quyền Admin và xác nhận từ server trước khi báo thành công. |
| **BUG-25** | P1 | Nhiều semantic token trong `app_colors.dart` bị gán đè thành `#FFFFFF`, làm mất khả năng phân biệt trạng thái chọn, cảnh báo và làm `ShimmerLoading` bị trắng trên trắng. | Khôi phục chính xác bộ semantic tokens trong `app_colors.dart` theo quy chuẩn thiết kế (`brandSoft`, `rangeBackground`, `surfaceMuted`, `surfaceSecondary`, `surfaceWarmSand`, `successSoft`, `warningSoft`, `errorSoft`), giúp `ShimmerLoading`, hội thoại đang chọn, dải ngày và hộp cảnh báo hiển thị rõ ràng. |
| **BUG-26** | P1 | Quy tắc hệ thống icon nghiêm ngặt: cấm nền màu trang trí quanh icon, cấm tô màu thương hiệu lên icon khi active, touch target tối thiểu `48x48px`. | Cập nhật `AppTheme.navigationBarTheme`, `AnimatedHeartButton`, `AppTopHeader`, `NotificationBell`, `AccountMenu`, `_SocialIconButton`, `AdminPortalScreen`, `MessagesScreen`, `BlogDetailScreen` giữ icon trung tính (`AppColors.iconStrong` / `AppColors.iconMuted`), thể hiện trạng thái chọn bằng chữ đậm/viền/thanh chỉ báo và đảm bảo vùng chạm tối thiểu `48x48px`. |
| **BUG-27** | P1 | Responsive & Accessibility trên màn hình hẹp (`320px–375px`) và desktop (`1024px–1440px`). | Bọc `Flexible`/`Expanded` cho brand header trong `AppTopHeader`, nâng toàn bộ nút icon đóng/mở/hành động lên `>= 48x48px`, bổ sung `Tooltip`/label ngữ nghĩa và bố cục đáp ứng (`LayoutBuilder` / `Wrap`) cho Admin Portal, Messages và Blog Detail. |
| **BUG-34** | P2 | Nhiều shared animations trong `source_animations.dart` (`CalFadeIn`, `SearchPopIn`, `MonthInSwitcher`, `MapMarkerPulse`) và `FadeSlideIn` chưa được gắn thực tế hoặc thiếu kiểm tra reduce motion. | Bổ sung kiểm tra `MediaQuery.disableAnimationsOf(context)` cho `FadeSlideIn`, `PressableScale`, `ShimmerLoading`, `AnimatedHeartButton`, `MonthInSwitcher`. Xây dựng `AppModal` (dùng `CalFadeIn`) và `AppToast` (dùng `SearchPopIn`) và gắn trực tiếp vào `AppDialog`, `MessagesScreen`, `AdminPortalScreen`, `BlogDetailScreen`. |
| **BUG-40** | P2 | `BlogDetailScreen` thiếu khu vực **Bài viết liên quan / Gợi ý đọc tiếp** như `BlogDetailPage.tsx`. | Bổ sung `BlogDetailScreen.selectRelatedPosts` và khu vực **Bài viết liên quan / Gợi ý đọc tiếp** lấy dữ liệu thực từ `blogListProvider(null)`, loại trừ bài hiện tại, ưu tiên cùng chuyên mục, tối đa 3 bài, điều hướng `/blog/:slug` và xử lý an toàn khi danh sách rỗng hoặc lỗi mạng. |

---

## 2. Danh sách File đã sửa / tạo mới (Thuộc phạm vi Terminal 05)

1. `lib/app/theme/app_colors.dart`
2. `lib/app/theme/app_theme.dart`
3. `lib/core/network/socket_service.dart`
4. `lib/features/admin/data/admin_repository.dart`
5. `lib/features/admin/presentation/screens/admin_portal_screens.dart`
6. `lib/features/blog/presentation/screens/blog_detail_screen.dart`
7. `lib/features/messages/data/conversations_repository.dart`
8. `lib/features/messages/presentation/screens/messages_screen.dart`
9. `lib/shared/animations/animated_heart_button.dart`
10. `lib/shared/animations/fade_slide_in.dart`
11. `lib/shared/animations/pressable_scale.dart`
12. `lib/shared/animations/shimmer_loading.dart`
13. `lib/shared/animations/source_animations.dart`
14. `lib/shared/widgets/app_dialog.dart`
15. `lib/shared/widgets/app_header_footer.dart`
16. `test/features/terminal_05_admin_realtime_design_test.dart`
17. `docs/ai-fix/terminal-05.md`

---

## 3. Cơ chế Bảo mật Socket.IO (BUG-28) & Đối chiếu Backend

- **Phân tích Backend (`Source goc/backend/src/realtime/socket.ts`)**:
  Middleware xác thực Socket.IO của Express đọc token theo thứ tự ưu tiên:
  1. `socket.handshake.auth?.token`
  2. Header `Authorization: Bearer <token>`
  3. Cookie `access_token`
  4. `socket.handshake.query?.token`
- **Giải pháp trên Flutter (`lib/core/network/socket_service.dart`)**:
  - Đã **loại bỏ hoàn toàn** tham số `token` khỏi URL query string trong `SocketService.buildSocketUri(baseUrl)` (chỉ gửi `EIO=4&transport=websocket`).
  - Khi nhận Engine.IO OPEN packet (`0{...}`), client gửi gói Socket.IO CONNECT handshake `40{"token":"<jwt>"}` (tương ứng `socket.handshake.auth.token` trên server Socket.IO v4).
  - Không ghi log JWT ở bất kỳ bước nào.
  - Khi người dùng đăng xuất (`clearForLogout()` / `disconnect()`), đóng kết nối WebSocket, hủy timer reconnect và xóa `_activeToken`.
  - Khi access token thay đổi (`refreshAuthToken()`), tự động ngắt kết nối cũ và xác thực lại với token mới.

---

## 4. Danh sách Semantic Theme Tokens đã khôi phục (`lib/app/theme/app_colors.dart`)

| Token | Giá trị lỗi trước đó | Giá trị chuẩn đã khôi phục | Mục đích sử dụng |
| :--- | :---: | :---: | :--- |
| `AppColors.brandSoft` | `#FFFFFF` | `#FFF1F3` (`0xFFFFF1F3`) | Nền nhấn nhẹ thương hiệu, dải lịch chọn |
| `AppColors.rangeBackground` | `#FFFFFF` | `#FFF1F3` (`0xFFFFF1F3`) | Dải ngày (date range) được chọn trên lịch |
| `AppColors.surfaceMuted` | `#FFFFFF` | `#F1F5F9` (`0xFFF1F5F9`) | Nền skeleton/shimmer, chip trung tính, thanh tiến độ |
| `AppColors.surfaceSecondary` | `#FFFFFF` | `#F1F5F9` (`0xFFF1F5F9`) | Nền bề mặt phụ phân tách khối nội dung |
| `AppColors.surfaceWarmSand` | `#FFFFFF` | `#F7F6F3` (`0xFFF7F6F3`) | Nền hội thoại/menu đang chọn, tag bài viết, trạng thái trung tính |
| `AppColors.successSoft` | `#FFFFFF` | `#ECFDF5` (`0xFFECFDF5`) | Nền thông báo/nhãn trạng thái thành công |
| `AppColors.warningSoft` | `#FFFFFF` | `#FFFBEB` (`0xFFFFFBEB`) | Nền cảnh báo chất lượng ảnh AI, lưu ý phân quyền |
| `AppColors.errorSoft` | `#FFFFFF` | `#FFF1F2` (`0xFFFFF1F2`) | Nền hộp thông báo lỗi, trạng thái bị khóa/từ chối |

---

## 5. Danh sách Shared Animations đã hoàn thiện & gắn vào UI (BUG-34)

- **`CalFadeIn` & `AppModal`** (`lib/shared/animations/source_animations.dart`, `lib/shared/widgets/app_dialog.dart`):
  - Gắn vào `AppDialog` và các hộp thoại xác nhận/từ chối/chỉnh sửa trong `AdminPortalScreen` (`_AdminUsersTab`, `_AdminModerationTab`, `_AdminHostApplicationsTab`).
- **`SearchPopIn` & `AppToast`** (`lib/shared/animations/source_animations.dart`):
  - Gắn vào thông báo phản hồi thao tác trong `MessagesScreen` và `AdminPortalScreen`.
- **`FadeSlideIn`** (`lib/shared/animations/fade_slide_in.dart`):
  - Gắn vào danh sách KPI cards của `AdminPortalScreen`, danh sách hội thoại của `MessagesScreen`, và lưới bài viết liên quan của `BlogDetailScreen`.
- **Hỗ trợ Reduce Motion (`MediaQuery.disableAnimationsOf(context)`)**:
  - Đã cập nhật `FadeSlideIn`, `PressableScale`, `ShimmerLoading`, `AnimatedHeartButton`, `CalFadeIn`, `SearchPopIn`, `MonthInSwitcher`, `MapMarkerPulse` để bỏ qua hiệu ứng chuyển động khi thiết bị bật chế độ giảm chuyển động.

---

## 6. Ghi nhận Vi phạm Icon / Token ở File thuộc Terminal 01–04 (Không tự ý sửa theo quy tắc phân quyền)

Trong quá trình rà soát toàn dự án, phát hiện một số vị trí thuộc phạm vi của các Terminal 01–04 cần lưu ý (Terminal 05 **không** tự sửa để tôn trọng ranh giới sở hữu file):

1. `lib/features/home/presentation/screens/home_screen.dart` & `lib/features/search/presentation/widgets/`:
   - Một số nút điều hướng/bộ lọc nhỏ trên mobile sử dụng `SizedBox(width: 36, height: 36)` hoặc `40x40` (nhỏ hơn chuẩn touch target `48x48px`).
2. `lib/features/host/presentation/screens/host_portal_screens.dart`:
   - Một số nút đóng drawer / thao tác nhanh trên bảng Host dùng kích thước `44x44px` thay vì `48x48px`.
3. `lib/features/trips/presentation/screens/trips_screen.dart`:
   - Một vài icon trạng thái đơn đặt phòng dùng màu trạng thái trực tiếp trên `Icon` thay vì giữ icon trung tính `AppColors.iconStrong` và chỉ đổi màu chữ/viền badge.

---

## 7. Kết quả Kiểm tra (`flutter analyze` & `flutter test`)

- **`flutter analyze`** trên toàn bộ các file thuộc phạm vi Terminal 05: **0 lỗi, 0 cảnh báo**.
- **`flutter test test/features/terminal_05_admin_realtime_design_test.dart test/features/router_and_icon_rules_test.dart`**: **Tất cả 19 nhóm kịch bản kiểm thử của Terminal 05 và bộ kiểm thử quy tắc Icon/Theme đều PASS 100%**.

---

## 8. Rủi ro còn lại & Khuyến nghị

- **AI Image Analysis phụ thuộc dịch vụ Vision phía Backend**: Khi môi trường local/staging chưa cấu hình khóa API Vision hoặc Qdrant, API `/api/admin/images/:imageId/reanalyze` hoặc `/api/ai/listings/:listingId/analyze-images` có thể trả lỗi từ server; giao diện Flutter đã bắt và hiển thị rõ thông báo lỗi từ backend trong modal mà không làm văng màn hình kiểm duyệt.
- **Socket.IO Reconnect**: Đã có cơ chế tự động kết nối lại kèm `onConnected` để đồng bộ lại danh sách hội thoại, tin nhắn đang mở và thông báo chưa đọc, kết hợp polling dự phòng chu kỳ 60 giây cho thông báo khi mất kết nối mạng dài hạn.
