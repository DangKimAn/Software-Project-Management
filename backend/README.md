# Booking Backend

Backend hien tai dung `Express 5 + TypeScript + Sequelize + mysql2` va ket noi MySQL bang bien moi truong. API response thong nhat:

```json
{ "success": true, "message": "...", "data": {} }
```

Loi:

```json
{ "success": false, "message": "...", "errors": [] }
```

## Env

Tao `backend/.env` tu `backend/.env.example`.

Bien chinh:

- `MYSQLHOST`, `MYSQLPORT`, `MYSQLDATABASE` hoac `MYSQL_DATABASE`, `MYSQLUSER`, `MYSQLPASSWORD`
- `MYSQL_SSL`, `MYSQL_SSL_CA`
- `JWT_SECRET_KEY`, `JWT_REFRESH_SECRET`, `TOKEN_HASH_SECRET`, `OTP_HASH_SECRET`
- `ACCESS_TOKEN_TTL_MINUTES`, `REFRESH_TOKEN_TTL_DAYS`
- `OTP_TTL_MINUTES`, `OTP_RATE_LIMIT_MAX`, `OTP_RATE_LIMIT_WINDOW_MINUTES`
- `VNPAY_TMN_CODE`, `VNPAY_HASH_SECRET`, `VNPAY_PAYMENT_URL`, `VNPAY_RETURN_URL`, `VNPAY_LOCALE`

## Database

Runtime boot se chay schema patch idempotent:

- dam bao `users.username` ton tai va unique
- role há»‡ thá»‘ng `guest`, `host`, `admin` Ä‘Æ°á»£c Ä‘áº£m báº£o bá»Ÿi migration schema
- tao/patch `auth_otp_tokens` cho OTP `sign_up` va `forgot_password`
- tao `audit_logs` cho hanh dong auth/admin nhay cam

Co the chay thu cong:

```bash
npm run db:check
npm run db:ensure-runtime-schema
npm run db:ensure-final-modules
```

Health check:

- `GET /api/health/db`

## Endpoints

Auth:

- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/logout`
- `POST /api/auth/refresh`
- `POST /api/auth/send-otp`
- `POST /api/auth/forgot-password`
- `POST /api/auth/reset-password`
- `POST /api/auth/google`
- `GET /api/auth/me`

Auth security:

- Password hash bang `bcryptjs` voi salt rounds 12.
- Access token JWT mac dinh het han sau 15 phut (`ACCESS_TOKEN_TTL_MINUTES`).
- Refresh token chi set qua cookie HttpOnly `refreshToken` mac dinh path `/api/auth`; DB chi luu token hash.
- Response user khong bao gom `password_hash`/`passwordHash`.
- `send-otp` nhan `purpose: "sign_up" | "forgot_password"`; OTP luu hash va `expires_at`.

Users:

- `GET /api/users/me`
- `PATCH /api/users/me`
- `GET /api/users/:userId` admin only
- `PATCH /api/users/:userId` admin only
- `PATCH /api/users/:userId/status` admin only

Public listings:

- `GET /api/listings`
  - Query: `city`, `district`, `checkIn`, `checkOut`, `guests`, `propertyType`, `roomType`, `minPrice`, `maxPrice`, `amenities`, `sort`, `page`, `limit`
  - Chi tra listing `published` (internal `active`) va `deletedAt = null`
  - Neu co `checkIn/checkOut`, API loai listing co ngay bi block trong `availability_calendars` hoac booking overlap active
- `GET /api/listings/:listingId`
- `GET /api/listings/:listingId/availability`
- `GET /api/listings/:listingId/reviews`
- `GET /api/listings/:listingId/rules`
- `GET /api/amenities`

Host listings:

- `POST /api/host/listings`
- `GET /api/host/listings/mine`
- `GET /api/host/listings/:listingId`
- `PATCH /api/host/listings/:listingId`
- `DELETE /api/host/listings/:listingId`
- `POST /api/host/listings/:listingId/images`
- `DELETE /api/host/listings/:listingId/images/:imageId`
- `PUT /api/host/listings/:listingId/amenities`
- `PATCH /api/host/listings/:listingId/rules`
- `GET /api/host/listings/:listingId/calendar`
- `PATCH /api/host/listings/:listingId/calendar/bulk`
  - Khong cho dong ngay da co booking `pending_payment`, `confirmed`, `paid`, `checked_in`
  - Host chi thao tac listing cua minh; admin duoc bypass owner guard
  - Sua thong tin nhay cam cua listing da published (anh, dia chi, gia, mo ta) se dua ve `pending_approval`

Admin amenities:

- `GET /api/admin/amenities`
- `POST /api/admin/amenities`
- `PATCH /api/admin/amenities/:amenityId`
- `DELETE /api/admin/amenities/:amenityId`
  - `name` unique, xoa mem bang `isActive=false`, `active=false`, `deletedAt`
  - Cac thao tac admin amenity ghi `audit_logs`

Payments, reviews, conversations, verifications, payouts:

- `POST /api/payments`
- `GET /api/payments/:paymentId`
- `GET /api/payments/my`
- `GET /api/payments/vnpay/return`
- `POST /api/payments/webhooks/vnpay`
- `POST /api/reviews`
- `PATCH /api/reviews/:reviewId`
- `DELETE /api/reviews/:reviewId`
- `POST /api/reviews/:reviewId/reply`
- `GET /api/conversations`
- `POST /api/conversations`
- `GET /api/conversations/:conversationId/messages`
- `POST /api/conversations/:conversationId/messages`
- `POST /api/host/verifications`
- `GET /api/host/verifications/me`
- `GET /api/admin/verifications`
- `PATCH /api/admin/verifications/:verificationId/approve`
- `PATCH /api/admin/verifications/:verificationId/reject`
- `GET /api/host/payout-accounts`
- `POST /api/host/payout-accounts`
- `PATCH /api/host/payout-accounts/:payoutAccountId`
- `DELETE /api/host/payout-accounts/:payoutAccountId`
- `GET /api/host/payouts`
- `GET /api/admin/host-payouts`
- `POST /api/admin/host-payouts`
- `PATCH /api/admin/host-payouts/:payoutId/paid`

## Run

```bash
npm run dev
npm run build
npm test
```

`npm test` hien build backend va chay smoke/integration test cho auth flow: register, login, refresh, logout.