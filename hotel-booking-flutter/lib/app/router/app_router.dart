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
import '../../features/contact/presentation/screens/contact_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/host/presentation/screens/host_onboarding_screens.dart';
import '../../features/host/presentation/screens/host_portal_screens.dart';
import '../../features/host/presentation/screens/them_cho_nghi_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/search/presentation/screens/ai_search_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/trips/presentation/screens/guest_payment_screen.dart';
import '../../features/trips/presentation/screens/payment_result_screen.dart';
import '../../features/trips/presentation/screens/trips_screen.dart';
import '../../features/villa_detail/presentation/screens/villa_detail_screen.dart';
import '../../features/villas/presentation/screens/villa_list_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../../shared/widgets/app_semantic_icons.dart';

enum RouteAccessLevel {
  public,
  authenticated,
  hostOnly,
  adminOnly,
}

class _RouterRefreshListenable extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}

bool _isAuthEntryPath(String path) {
  return path == '/dang-nhap' ||
      path == '/login' ||
      path == '/dang-ky' ||
      path == '/register' ||
      path == '/quen-mat-khau' ||
      path == '/forgot-password';
}

bool _isAdminRoutePath(String path) {
  return path == '/admin' || path.startsWith('/admin/');
}

bool _isHostRoutePath(String path) {
  return path == '/chu-nha' ||
      path.startsWith('/chu-nha/') ||
      path == '/host' ||
      path.startsWith('/host/');
}

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

      // ── Discovery, Search, AI Search, Blog & Contact ──
      GoRoute(
        path: '/villas',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const VillaListScreen(),
        ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const SearchScreen(),
        ),
      ),
      GoRoute(
        path: '/noi-luu-tru',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const SearchScreen(),
        ),
      ),
      GoRoute(
        path: '/tim-kiem',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const SearchScreen(),
        ),
      ),
      GoRoute(
        path: '/ai-search',
        pageBuilder: (context, state) {
          final query = state.uri.queryParameters['q'];
          return _buildSlideTransitionPage(
            state: state,
            child: AiSearchScreen(initialQuery: query),
          );
        },
      ),
      GoRoute(
        path: '/tim-kiem-ai',
        pageBuilder: (context, state) {
          final query = state.uri.queryParameters['q'];
          return _buildSlideTransitionPage(
            state: state,
            child: AiSearchScreen(initialQuery: query),
          );
        },
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
        redirect: (context, state) => '/chu-nha/cho-nghi',
      ),
      GoRoute(
        path: '/chu-nha/tong-quan',
        redirect: (context, state) => '/chu-nha/cho-nghi',
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
            child: ThemChoNghiScreen(listingId: listingId),
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
        redirect: (context, state) => '/host/tin-nhan',
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
    ],
  );
});

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

class NotFoundScreen extends StatelessWidget {
  final String? requestedLocation;

  const NotFoundScreen({
    super.key,
    this.requestedLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.compass,
                    size: 40,
                    color: AppColors.iconMuted,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    '404 — Không tìm thấy trang',
                    textAlign: TextAlign.center,
                    style: AppTypography.display.copyWith(
                      color: AppColors.textStrong,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'Đường dẫn bạn truy cập không tồn tại hoặc đã được di chuyển.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () => context.go('/'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(160, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Về trang chủ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScaffoldWithBottomNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithBottomNavBar({
    super.key,
    required this.navigationShell,
  });

  static const _tabs = [
    (icon: LucideIcons.compass, label: 'Khám phá'),
    (icon: AppSemanticIcons.messageHost, label: 'Tin nhắn'),
    (icon: AppSemanticIcons.bookings, label: 'Chuyến đi'),
    (icon: AppSemanticIcons.userProfile, label: 'Tài khoản'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 1024;
    if (isWide) {
      return Scaffold(body: navigationShell);
    }

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
              children: List.generate(_tabs.length, (index) {
                final tab = _tabs[index];
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
