# BẢNG ÁNH XẠ API BACKEND ↔ FLUTTER (API_MAPPING)

**Dự án:** `hotel-booking-flutter`  
**Backend Host Mặc định:**
- Android Emulator: `http://10.0.2.2:5000/api`
- iOS Simulator / Local: `http://localhost:5000/api`
- Staging / Production: `https://api.minhthanhvilla.com/api`

---

## BẢNG ÁNH XẠ CHI TIẾT

| Endpoint | Method | Tham số / Body | Auth | Model Response Flutter | File Flutter sử dụng | Trạng thái |
|---|---|---|---|---|---|---|
| `/api/listings` | `GET` | `q`, `city`, `checkIn`, `checkOut`, `guests`, `priceMin`, `priceMax`, `page`, `limit` | Không | `List<Villa>`, `PaginationMeta` | `villa_repository_impl.dart` | Đang cập nhật |
| `/api/listings/:id` | `GET` | `id` (listingId) | Không | `Villa` (kèm full specs, amenities, host) | `villa_repository_impl.dart` | Đang cập nhật |
| `/api/listings/:id/availability` | `GET` | `month`, `year` | Không | `List<NightlyPrice>` | `villa_repository_impl.dart` | Đang cập nhật |
| `/api/listings/:id/reviews` | `GET` | `page`, `limit`, `rating` | Không | `List<ReviewItem>` | `review_repository_impl.dart` | Triển khai mới |
| `/api/auth/login` | `POST` | `{ "identifier": "...", "password": "..." }` | Không | `AuthSession` (token, user) | `auth_repository_impl.dart` | Triển khai mới |
| `/api/auth/register` | `POST` | `{ "email": "...", "password": "...", "firstName": "...", "lastName": "..." }` | Không | `AuthSession` (token, user) | `auth_repository_impl.dart` | Triển khai mới |
| `/api/auth/forgot-password` | `POST` | `{ "identifier": "..." }` | Không | `{ "message": "..." }` | `auth_repository_impl.dart` | Triển khai mới |
| `/api/auth/reset-password` | `POST` | `{ "identifier": "...", "otp": "...", "newPassword": "..." }` | Không | `{ "message": "..." }` | `auth_repository_impl.dart` | Triển khai mới |
| `/api/auth/me` | `GET` | Không | Có (`Bearer <token>`) | `User` | `auth_repository_impl.dart` | Triển khai mới |
| `/api/auth/logout` | `POST` | `{ "refreshToken": "..." }` (hoặc rỗng) | Có (`Bearer <token>`) | `{ "message": "..." }` | `auth_repository_impl.dart` | Triển khai mới |
| `/api/bookings/mine` | `GET` | `status`, `page`, `limit` | Có (`Bearer <token>`) | `List<Booking>` | `booking_repository_impl.dart` | Triển khai mới |
| `/api/bookings/:id` | `GET` | `id` (bookingId) | Có (`Bearer <token>`) | `Booking` | `booking_repository_impl.dart` | Triển khai mới |
| `/api/bookings/:id/cancel` | `POST` | `{ "cancellationReason": "..." }` | Có (`Bearer <token>`) | `Booking` | `booking_repository_impl.dart` | Triển khai mới |
| `/api/wishlist` | `GET` | Không | Có (`Bearer <token>`) | `List<WishlistItem>` | `wishlist_repository_impl.dart` | Triển khai mới |
| `/api/wishlist/:id` | `POST` | `id` (listingId) | Có (`Bearer <token>`) | `{ "success": true }` | `wishlist_repository_impl.dart` | Triển khai mới |
| `/api/wishlist/:id` | `DELETE` | `id` (listingId) | Có (`Bearer <token>`) | `{ "success": true }` | `wishlist_repository_impl.dart` | Triển khai mới |

---

## QUY TẮC BẢO MẬT & XỬ LÝ LỖI
1. **Envelope Unpacking:** Mọi phản hồi thành công từ Backend Express đều có dạng `{ success: true, data: ... }`. Flutter client tự động bóc tách trường `data`.
2. **Error Translation:** Khi Backend trả về lỗi (400, 401, 403, 404, 422, 423), Interceptor của `DioClient` chuyển đổi sang `AppFailure` tương ứng với thông điệp rõ ràng cho người dùng tiếng Việt.
3. **Token Management:** Token được lưu trong `flutter_secure_storage` với cờ `encryptedSharedPreferences: true` trên Android và `KeychainAccessibility.first_unlock` trên iOS.
