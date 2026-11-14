import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/config/app_config.dart';
import '../../features/admin/presentation/screens/admin_portal_screens.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/view_models/auth_notifier.dart';
import '../../features/blog/presentation/screens/blog_detail_screen.dart';
import '../../features/blog/presentation/screens/blog_screen.dart';
import '../../features/support/presentation/screens/contact_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/host/presentation/screens/host_onboarding_screens.dart';
import '../../features/host/presentation/screens/host_portal_screens.dart';
import '../../features/host/presentation/screens/host_listing_form_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/support/domain/entities/support_page_models.dart';
import '../../features/support/presentation/screens/support_info_screen.dart';
import '../../features/trips/presentation/screens/guest_payment_screen.dart';
import '../../features/trips/presentation/screens/payment_result_screen.dart';
import '../../features/trips/presentation/screens/trips_screen.dart';
import '../../features/villa_detail/presentation/screens/villa_detail_screen.dart';
import '../../features/villas/presentation/screens/villa_list_screen.dart';
import '../../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../shared/widgets/app_semantic_icons.dart';
import 'not_found_screen.dart';

export 'not_found_screen.dart';

/// Cấp độ phân quyền truy cập của từng tuyến đường trong ứng dụng.
///
/// Phân tách rõ bốn miền quyền hạn: công khai (`public`), đã đăng nhập (`authenticated`),
/// dành riêng cho Chủ nhà không kiêm Quản trị viên (`hostOnly`) và dành riêng cho Quản trị viên (`adminOnly`).
enum RouteAccessLevel {
  public,
  authenticated,
  hostOnly,
  adminOnly,
}

/// Bộ phát tín hiệu `ChangeNotifier` cầu nối trạng thái xác thực Riverpod sang `GoRouter.refreshListenable`.
class _RouterRefreshListenable extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}

/// Kiểm tra xem `path` có phải là trang cổng xác thực (đăng nhập, đăng ký, quên mật khẩu) hay không.
bool _isAuthEntryPath(String path) {
  return path == '/dang-nhap' ||
      path == '/login' ||
      path == '/dang-ky' ||
      path == '/register' ||
      path == '/quen-mat-khau' ||
      path == '/forgot-password';
}

/// Kiểm tra xem `path` có thuộc phân hệ Quản trị viên (`/admin` hoặc `/admin/*`) hay không.
bool _isAdminRoutePath(String path) {
  return path == '/admin' || path.startsWith('/admin/');
}

/// Kiểm tra xem `path` có thuộc cổng Chủ nhà (`/chu-nha/*` hoặc `/host/*`) hay không.
bool _isHostRoutePath(String path) {
  return path == '/chu-nha' ||
      path.startsWith('/chu-nha/') ||
      path == '/host' ||
      path.startsWith('/host/');
}

/// Giải thuật nhận diện tuyến đường yêu cầu xác thực bắt buộc:
/// Bao gồm toàn bộ tuyến đường Admin, tuyến đường Host, danh sách yêu thích, chuyến đi,
/// hồ sơ tài khoản, tin nhắn, đăng ký làm chủ nhà và luồng thanh toán đơn đặt phòng.
bool _isProtectedRoutePath(String path) {
  if (_isAdminRoutePath(path) || _isHostRoutePath(path)) {
    return true;
  }
  return path == '/favorites' ||
      path == '/yeu-thich' ||
      path == '/trips' ||
      path == '/account/trips' ||
      path == '/settings' ||
      path == '/account/profile' ||
      path == '/gio-cho-dat' ||
      path == '/messages' ||
      path == '/tin-nhan' ||
      path == '/tro-thanh-host/dang-ky' ||
      path == '/tro-thanh-host/trang-thai' ||
      path == '/thanh-toan/ket-qua' ||
      path.startsWith('/thanh-toan/') ||
      (path.startsWith('/villa/') && path.endsWith('/nhan-tin-host'));
}

/// Giải thuật làm sạch tham số `redirectTo` chống lỗ hổng chuyển hướng mở (Open Redirect):
/// Loại bỏ khoảng trắng thừa và kiểm định qua `AuthNotifier.isSafeRedirectPath`, trả về `null` nếu đường dẫn không an toàn.
String? _sanitizeRedirectParam(String? rawRedirectTo) {
  if (rawRedirectTo == null) return null;
  final trimmed = rawRedirectTo.trim();
  if (!AuthNotifier.isSafeRedirectPath(trimmed)) {
    return null;
  }
  return trimmed;
}

/// Normalizes custom-scheme deep links (e.g. `minhthanhvilla://thanh-toan/ket-qua?bookingId=123`)
/// into internal application paths (`/thanh-toan/ket-qua?bookingId=123`).
/// Giải thuật chuẩn hóa URI Deep Link đầu vào:
/// 1. Kiểm tra lược đồ (`scheme`): Chỉ xử lý khi `uri.hasScheme` và `scheme` trùng khớp không phân biệt hoa thường
///    với `AppConfig.deepLinkScheme` (ví dụ `minhthanhvilla://`), trả về `null` cho các đường dẫn nội bộ thông thường.
/// 2. Tái cấu trúc đường dẫn chuẩn tắc (Path Canonicalization): Trên URI custom-scheme dạng
///    `minhthanhvilla://thanh-toan/ket-qua?bookingId=123`, phần `thanh-toan` nằm ở `uri.host` còn `/ket-qua` nằm ở `uri.path`.
///    Hàm ghép nối an toàn `/${hostPart}${suffix}` hoặc chuẩn hóa dấu `/` đầu cho `rawPath` khi `host` rỗng.
/// 3. Bảo toàn `queryParameters` hợp lệ, loại bỏ tự động `fragment` / `userInfo` qua `Uri(path: ..., queryParameters: ...)`.
/// 4. Kiểm định an toàn chống Open Redirect qua `AuthNotifier.isSafeRedirectPath`; nếu không đạt chuẩn sẽ đưa về trang chủ `'/'`.
String? normalizeIncomingDeepLinkUri(Uri uri) {
  if (!uri.hasScheme) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != AppConfig.deepLinkScheme.toLowerCase()) {
    return null;
  }

  final hostPart = uri.host.trim();
  final rawPath = uri.path.trim();
  String combinedPath;
  if (hostPart.isNotEmpty) {
    final suffix = rawPath.isEmpty
        ? ''
        : (rawPath.startsWith('/') ? rawPath : '/$rawPath');
    combinedPath = '/$hostPart$suffix';
  } else {
    combinedPath = rawPath.isEmpty
        ? '/'
        : (rawPath.startsWith('/') ? rawPath : '/$rawPath');
  }

  final normalizedUri = Uri(
    path: combinedPath,
    queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
  ).toString();

  if (combinedPath == '/') return '/';
  return AuthNotifier.isSafeRedirectPath(normalizedUri) ? normalizedUri : '/';
}

/// Provider cấu hình bộ định tuyến trung tâm `GoRouter` cho toàn bộ ứng dụng đa nền tảng.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _RouterRefreshListenable();
  ref.onDispose(refreshListenable.dispose);

  ref.listen<AsyncValue<User?>>(authNotifierProvider, (_, __) {
    refreshListenable.notify();
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      // Giải thuật điều hướng và bảo vệ phân quyền tuyến đường (RBAC Route Guard):
      // Bước 1: Chuẩn hóa URI Deep Link bên ngoài (`minhthanhvilla://...`) về đường dẫn nội bộ trước khi xét quyền.
      // Bước 2: Nếu phiên xác thực đang được xác minh bất đồng bộ (`authState.isLoading`), tạm giữ nguyên URL hiện tại
      //         để không làm mất Deep Link; lớp bọc `RouteAuthGuard` sẽ hiển thị màn chờ và ngăn dựng nội dung nhạy cảm.
      // Bước 3: Khi người dùng chưa đăng nhập (`user == null`):
      //         - Chặn mọi tuyến đường bảo vệ (`_isProtectedRoutePath`) và chuyển hướng sang `/dang-nhap?redirectTo=...` đã khử độc.
      //         - Trên các trang đăng nhập/đăng ký, loại bỏ tham số `redirectTo` nếu phát hiện dấu hiệu Open Redirect.
      // Bước 4: Khi người dùng đã xác thực (`user != null`):
      //         - Nếu truy cập lại trang đăng nhập/đăng ký, điều hướng về đích an toàn theo vai trò qua `resolvePostAuthRedirectPath`.
      //         - Chặn truy cập trái phép vào `/admin/*` nếu `!user.isAdmin` và vào `/chu-nha/*` hoặc `/host/*`
      //           nếu không phải Host hợp lệ (`!user.isHost || user.isAdmin`), đẩy về trang mặc định của vai trò tương ứng.
      final normalizedDeepLink = normalizeIncomingDeepLinkUri(state.uri);
      if (normalizedDeepLink != null) {
        return normalizedDeepLink;
      }

      final path = state.uri.path.isEmpty ? '/' : state.uri.path;
      final fullLocation = state.uri.toString();
      final authState = ref.read(authNotifierProvider);

      // While session verification is in flight, keep the current location so
      // deep links are preserved; RouteAuthGuard prevents protected widgets
      // from rendering until verification finishes.
      if (authState.isLoading) {
        return null;
      }

      final user = authState.valueOrNull;

      if (user == null) {
        if (_isProtectedRoutePath(path)) {
          final safeRedirect = AuthNotifier.isSafeRedirectPath(fullLocation)
              ? fullLocation
              : path;
          return Uri(
            path: '/dang-nhap',
            queryParameters: <String, String>{'redirectTo': safeRedirect},
          ).toString();
        }

        if (_isAuthEntryPath(path)) {
          final rawRedirect = state.uri.queryParameters['redirectTo'];
          if (rawRedirect != null &&
              !AuthNotifier.isSafeRedirectPath(rawRedirect)) {
            return path;
          }
        }
        return null;
      }

      // User is authenticated and verified
      if (_isAuthEntryPath(path)) {
        return AuthNotifier.resolvePostAuthRedirectPath(
          user,
          redirectTo: state.uri.queryParameters['redirectTo'],
        );
      }

      if (_isAdminRoutePath(path) && !user.isAdmin) {
        return AuthNotifier.defaultRouteForUser(user);
      }

      if (_isHostRoutePath(path) && (!user.isHost || user.isAdmin)) {
        return AuthNotifier.defaultRouteForUser(user);
      }

      return null;
    },
    errorBuilder: (context, state) => NotFoundScreen(
      requestedLocation: state.uri.toString(),
    ),
    routes: [
      // Stateful Navigation Shell for 4-Tab Mobile Navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithBottomNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home Discovery (/)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Branch 1: Guest Messages (/messages, /tin-nhan)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                builder: (context, state) {
                  final convId = state.uri.queryParameters['conversationId'];
                  return RouteAuthGuard(
                    accessLevel: RouteAccessLevel.authenticated,
                    child: MessagesScreen(initialConversationId: convId),
                  );
                },
              ),
              GoRoute(
                path: '/tin-nhan',
                builder: (context, state) {
                  final convId = state.uri.queryParameters['conversationId'];
                  return RouteAuthGuard(
                    accessLevel: RouteAccessLevel.authenticated,
                    child: MessagesScreen(initialConversationId: convId),
                  );
                },
              ),
            ],
          ),
          // Branch 2: Guest Trips / My Bookings (/trips, /account/trips)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trips',
                builder: (context, state) => const RouteAuthGuard(
                  accessLevel: RouteAccessLevel.authenticated,
                  child: TripsScreen(),
                ),
              ),
              GoRoute(
                path: '/account/trips',
                builder: (context, state) => const RouteAuthGuard(
                  accessLevel: RouteAccessLevel.authenticated,
                  child: TripsScreen(),
                ),
              ),
            ],
          ),
          // Branch 3: Account Profile & Settings (/settings, /account/profile)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const RouteAuthGuard(
                  accessLevel: RouteAccessLevel.authenticated,
                  child: SettingsScreen(),
                ),
              ),
              GoRoute(
                path: '/account/profile',
                builder: (context, state) => const RouteAuthGuard(
                  accessLevel: RouteAccessLevel.authenticated,
                  child: SettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Discovery, Search, Blog & Contact ──
      GoRoute(
        path: '/villas',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: VillaListScreen(
            initialQueryParameters: state.uri.queryParameters,
          ),
        ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: SearchScreen(
            initialQueryParameters: state.uri.queryParameters,
          ),
        ),
      ),
      GoRoute(
        path: '/noi-luu-tru',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: SearchScreen(
            initialQueryParameters: state.uri.queryParameters,
          ),
        ),
      ),
      GoRoute(
        path: '/tim-kiem',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: SearchScreen(
            initialQueryParameters: state.uri.queryParameters,
          ),
        ),
      ),
      GoRoute(
        path: '/blog',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const BlogScreen(),
        ),
      ),
      GoRoute(
        path: '/cam-nang',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const BlogScreen(),
        ),
      ),
      GoRoute(
        path: '/blog/:slug',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return _buildSlideTransitionPage(
            state: state,
            child: BlogDetailScreen(slug: slug),
          );
        },
      ),
      GoRoute(
        path: '/cam-nang/:slug',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return _buildSlideTransitionPage(
            state: state,
            child: BlogDetailScreen(slug: slug),
          );
        },
      ),
      GoRoute(
        path: '/lien-he',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const ContactScreen(),
        ),
      ),
      GoRoute(
        path: '/ho-tro/huong-dan-dat-phong',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const SupportInfoScreen(
            pageType: SupportPageType.bookingGuide,
          ),
        ),
      ),
      GoRoute(
        path: '/ho-tro/chinh-sach-huy-phong',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const SupportInfoScreen(
            pageType: SupportPageType.cancellationPolicy,
          ),
        ),
      ),
      GoRoute(
        path: '/ho-tro/khieu-nai-gop-y',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const SupportInfoScreen(
            pageType: SupportPageType.complaintsFeedback,
          ),
        ),
      ),
      GoRoute(
        path: '/ho-tro/cau-hoi-thuong-gap',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const SupportInfoScreen(
            pageType: SupportPageType.faq,
          ),
        ),
      ),
      GoRoute(
        path: '/faq',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const SupportInfoScreen(
            pageType: SupportPageType.faq,
          ),
        ),
      ),
      GoRoute(
        path: '/ve-chung-toi',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const SupportInfoScreen(
            pageType: SupportPageType.aboutUs,
          ),
        ),
      ),
      GoRoute(
        path: '/kham-pha-vung-tau',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const SupportInfoScreen(
            pageType: SupportPageType.exploreVungTau,
          ),
        ),
      ),
      GoRoute(
        path: '/dich-vu-di-kem',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const SupportInfoScreen(
            pageType: SupportPageType.addonServices,
          ),
        ),
      ),
      GoRoute(
        path: '/uu-dai-thanh-vien',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const SupportInfoScreen(
            pageType: SupportPageType.memberOffers,
          ),
        ),
      ),
      GoRoute(
        path: '/news',
        redirect: (context, state) => '/lien-he',
      ),

      // ── Villa Detail & Host Messaging ──
      GoRoute(
        path: '/villas/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _buildSlideTransitionPage(
            state: state,
            child: VillaDetailScreen(villaId: id),
          );
        },
      ),
      GoRoute(
        path: '/villa/:villaId',
        pageBuilder: (context, state) {
          final id = state.pathParameters['villaId'] ?? '';
          return _buildSlideTransitionPage(
            state: state,
            child: VillaDetailScreen(villaId: id),
          );
        },
      ),
      GoRoute(
        path: '/villa/:villaId/nhan-tin-host',
        pageBuilder: (context, state) {
          final villaId = state.pathParameters['villaId'] ?? '';
          return _buildSlideTransitionPage(
            state: state,
            child: HostMessageScreen(villaId: villaId),
          );
        },
      ),

      // ── Auth Routes (Source goc + Legacy aliases) ──
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) {
          final redirectTo = _sanitizeRedirectParam(
            state.uri.queryParameters['redirectTo'],
          );
          return _buildSlideTransitionPage(
            state: state,
            child: LoginScreen(redirectTo: redirectTo),
          );
        },
      ),
      GoRoute(
        path: '/dang-nhap',
        pageBuilder: (context, state) {
          final redirectTo = _sanitizeRedirectParam(
            state.uri.queryParameters['redirectTo'],
          );
          return _buildSlideTransitionPage(
            state: state,
            child: LoginScreen(redirectTo: redirectTo),
          );
        },
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) {
          final redirectTo = _sanitizeRedirectParam(
            state.uri.queryParameters['redirectTo'],
          );
          return _buildSlideTransitionPage(
            state: state,
            child: RegisterScreen(redirectTo: redirectTo),
          );
        },
      ),
      GoRoute(
        path: '/dang-ky',
        pageBuilder: (context, state) {
          final redirectTo = _sanitizeRedirectParam(
            state.uri.queryParameters['redirectTo'],
          );
          return _buildSlideTransitionPage(
            state: state,
            child: RegisterScreen(redirectTo: redirectTo),
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/quen-mat-khau',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const ForgotPasswordScreen(),
        ),
      ),

      // ── Booking Queue, Payments & Wishlist / Favorites (Authenticated) ──
      GoRoute(
        path: '/gio-cho-dat',
        // Retired queue: old links must not reopen its UI.
        redirect: (context, state) => '/account/trips',
      ),
      GoRoute(
        path: '/favorites',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.authenticated,
          child: const FavoritesScreen(),
        ),
      ),
      GoRoute(
        path: '/yeu-thich',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.authenticated,
          child: const FavoritesScreen(),
        ),
      ),
      GoRoute(
        path: '/thanh-toan/ket-qua',
        pageBuilder: (context, state) {
          final qp = state.uri.queryParameters;
          return _buildProtectedSlidePage(
            state: state,
            accessLevel: RouteAccessLevel.authenticated,
            child: PaymentResultScreen(
              bookingId: qp['bookingId'],
              paymentId: qp['paymentId'],
              status: qp['status'] ?? 'pending',
              method: qp['method'] ?? qp['provider'],
              amount: int.tryParse(qp['amount'] ?? ''),
            ),
          );
        },
      ),
      GoRoute(
        path: '/thanh-toan/:bookingId',
        pageBuilder: (context, state) {
          final bookingId = state.pathParameters['bookingId'] ?? '';
          return _buildProtectedSlidePage(
            state: state,
            accessLevel: RouteAccessLevel.authenticated,
            child: GuestPaymentScreen(bookingId: bookingId),
          );
        },
      ),

      // ── Host Onboarding (/tro-thanh-host/*) ──
      GoRoute(
        path: '/tro-thanh-host',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const TroThanhHostLandingScreen(),
        ),
      ),
      GoRoute(
        path: '/tro-thanh-host/dang-ky',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.authenticated,
          child: const DangKyHostScreen(),
        ),
      ),
      GoRoute(
        path: '/tro-thanh-host/trang-thai',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.authenticated,
          child: const TrangThaiHostScreen(),
        ),
      ),

      // ── Host Portal (/chu-nha/* & /host/*) — Host-only ──
      GoRoute(
        path: '/chu-nha',
        redirect: (context, state) => '/chu-nha/tong-quan',
      ),
      GoRoute(
        path: '/chu-nha/tong-quan',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.hostOnly,
          child: const HostPortalScreen(section: 'tong-quan'),
        ),
      ),
      GoRoute(
        path: '/chu-nha/cho-nghi',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.hostOnly,
          child: const HostPortalScreen(section: 'cho-nghi'),
        ),
      ),
      GoRoute(
        path: '/chu-nha/cho-nghi/them-moi',
        pageBuilder: (context, state) {
          final listingId = state.uri.queryParameters['listingId'];
          return _buildProtectedSlidePage(
            state: state,
            accessLevel: RouteAccessLevel.hostOnly,
            child: HostListingFormScreen(listingId: listingId),
          );
        },
      ),
      GoRoute(
        path: '/chu-nha/dat-phong',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.hostOnly,
          child: const HostPortalScreen(section: 'dat-phong'),
        ),
      ),
      GoRoute(
        path: '/chu-nha/lich-luu-tru',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.hostOnly,
          child: const HostPortalScreen(section: 'lich-luu-tru'),
        ),
      ),
      GoRoute(
        path: '/chu-nha/khach-luu-tru',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.hostOnly,
          child: const HostPortalScreen(section: 'khach-luu-tru'),
        ),
      ),
      GoRoute(
        path: '/chu-nha/tin-nhan',
        redirect: (context, state) => '/host/tin-nhan',
      ),
      GoRoute(
        path: '/host',
        redirect: (context, state) => '/chu-nha/khach-luu-tru',
      ),
      GoRoute(
        path: '/host/khach',
        redirect: (context, state) => '/chu-nha/khach-luu-tru',
      ),
      GoRoute(
        path: '/host/tin-nhan',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.hostOnly,
          child: const HostPortalScreen(section: 'tin-nhan'),
        ),
      ),
      GoRoute(
        path: '/chu-nha/thanh-toan',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.hostOnly,
          child: const HostPortalScreen(section: 'thanh-toan'),
        ),
      ),
      GoRoute(
        path: '/chu-nha/danh-gia',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.hostOnly,
          child: const HostPortalScreen(section: 'danh-gia'),
        ),
      ),
      GoRoute(
        path: '/chu-nha/bao-cao',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.hostOnly,
          child: const HostPortalScreen(section: 'bao-cao'),
        ),
      ),
      GoRoute(
        path: '/chu-nha/ho-tro',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.hostOnly,
          child: const HostPortalScreen(section: 'ho-tro'),
        ),
      ),
      GoRoute(
        path: '/chu-nha/cai-dat',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.hostOnly,
          child: const HostPortalScreen(section: 'cai-dat'),
        ),
      ),

      // ── Admin Portal (/admin/*) — Admin-only ──
      GoRoute(
        path: '/admin',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.adminOnly,
          child: const AdminPortalScreen(activeTab: 'tong-quan'),
        ),
      ),
      GoRoute(
        path: '/admin/nguoi-dung',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.adminOnly,
          child: const AdminPortalScreen(activeTab: 'nguoi-dung'),
        ),
      ),
      GoRoute(
        path: '/admin/kiem-duyet',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.adminOnly,
          child: const AdminPortalScreen(activeTab: 'kiem-duyet'),
        ),
      ),
      GoRoute(
        path: '/admin/ho-so-host',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.adminOnly,
          child: const AdminPortalScreen(activeTab: 'ho-so-host'),
        ),
      ),
      GoRoute(
        path: '/admin/phan-quyen',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.adminOnly,
          child: const AdminPortalScreen(activeTab: 'phan-quyen'),
        ),
      ),
      GoRoute(
        path: '/admin/phi-nen-tang',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.adminOnly,
          child: const AdminPortalScreen(activeTab: 'phi-nen-tang'),
        ),
      ),
      GoRoute(
        path: '/admin/chi-tra',
        pageBuilder: (context, state) => _buildProtectedSlidePage(
          state: state,
          accessLevel: RouteAccessLevel.adminOnly,
          child: const AdminPortalScreen(activeTab: 'chi-tra'),
        ),
      ),
      GoRoute(
        path: '/admin/tin-nhan',
        pageBuilder: (context, state) {
          final convId = state.uri.queryParameters['conversationId'];
          return _buildProtectedSlidePage(
            state: state,
            accessLevel: RouteAccessLevel.adminOnly,
            child: AdminPortalScreen(
              activeTab: 'tin-nhan',
              initialConversationId: convId,
            ),
          );
        },
      ),
    ],
  );
});

/// Dựng trang chuyển cảnh trượt mượt kết hợp lớp bảo vệ phân quyền `RouteAuthGuard`.
CustomTransitionPage<void> _buildProtectedSlidePage({
  required GoRouterState state,
  required RouteAccessLevel accessLevel,
  required Widget child,
}) {
  return _buildSlideTransitionPage(
    state: state,
    child: RouteAuthGuard(
      accessLevel: accessLevel,
      child: child,
    ),
  );
}

/// Dựng hiệu ứng chuyển trang trượt nhẹ từ dưới lên kết hợp mờ dần theo đường cong `Curves.easeOutCubic`.
CustomTransitionPage<void> _buildSlideTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: curved,
          child: child,
        ),
      );
    },
  );
}

/// Prevents protected screens from mounting or rendering while the auth session
/// is still unverified (`authState.isLoading`) or when the current user lacks
/// the required role while a redirect is scheduled.
/// Widget bảo vệ cấp độ cây giao diện ngăn chặn dựng màn hình nhạy cảm khi phiên chưa xác minh xong hoặc thiếu quyền hạn.
class RouteAuthGuard extends ConsumerWidget {
  final RouteAccessLevel accessLevel;
  final Widget child;

  const RouteAuthGuard({
    super.key,
    required this.accessLevel,
    required this.child,
  });

  bool _isAuthorized(User? user) {
    if (accessLevel == RouteAccessLevel.public) return true;
    if (user == null) return false;
    switch (accessLevel) {
      case RouteAccessLevel.public:
        return true;
      case RouteAccessLevel.authenticated:
        return true;
      case RouteAccessLevel.hostOnly:
        return user.isHost && !user.isAdmin;
      case RouteAccessLevel.adminOnly:
        return user.isAdmin;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    if (authState.isLoading) {
      return const SessionVerificationLoadingView();
    }
    final user = authState.valueOrNull;
    if (!_isAuthorized(user)) {
      return const SessionVerificationLoadingView();
    }
    return child;
  }
}

/// Màn hình chờ tối giản hiển thị trong lúc đang xác minh phiên đăng nhập hoặc đang thực thi chuyển hướng phân quyền.
class SessionVerificationLoadingView extends StatelessWidget {
  const SessionVerificationLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surfaceBase,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.iconStrong,
          ),
        ),
      ),
    );
  }
}

/// Khung giao diện `Scaffold` chứa thanh điều hướng đáy 4 tab cho thiết bị di động và tự động ẩn thanh đáy trên màn hình rộng (`>= 1024dp`).
class ScaffoldWithBottomNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithBottomNavBar({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 1024;
    if (isWide) {
      return Scaffold(body: navigationShell);
    }

    final l10n = context.l10n;
    final tabs = [
      (icon: LucideIcons.compass, label: l10n.navDiscover),
      (icon: AppSemanticIcons.messageHost, label: l10n.navMessages),
      (icon: AppSemanticIcons.bookings, label: l10n.navTrips),
      (icon: AppSemanticIcons.userProfile, label: l10n.navAccount),
    ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceBase,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(tabs.length, (index) {
                final tab = tabs[index];
                final isSelected = navigationShell.currentIndex == index;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      navigationShell.goBranch(
                        index,
                        initialLocation: index == navigationShell.currentIndex,
                      );
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            tab.icon,
                            size: 20,
                            color: isSelected
                                ? AppColors.iconStrong
                                : AppColors.iconMuted,
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              tab.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: AppTypography.textFontFamily,
                                fontFamilyFallback: AppTypography.fontFallbacks,
                                fontSize: 10.5,
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                                letterSpacing: -0.02,
                                height: 1.35,
                                color: isSelected
                                    ? AppColors.textStrong
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                          Container(
                            width: 24,
                            height: 2,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
