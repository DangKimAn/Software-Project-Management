import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/trips/presentation/screens/trips_screen.dart';
import '../../features/villa_detail/presentation/screens/villa_detail_screen.dart';
import '../../features/villas/presentation/screens/villa_list_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // Stateful Navigation Shell for 4-Tab Bottom Navigation Bar
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithBottomNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home Discovery
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Branch 1: Wishlist / Favorites
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
          // Branch 2: Guest Trips / My Bookings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trips',
                builder: (context, state) => const TripsScreen(),
              ),
            ],
          ),
          // Branch 3: Settings & Account
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Standalone Full-screen Routes with Smooth Transitions
      GoRoute(
        path: '/villas',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const VillaListScreen(),
        ),
      ),
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
        path: '/search',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const SearchScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => _buildSlideTransitionPage(
          state: state,
          child: const ForgotPasswordScreen(),
        ),
      ),
    ],
  );
});

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

class ScaffoldWithBottomNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithBottomNavBar({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        backgroundColor: AppColors.surfaceBase,
        indicatorColor: AppColors.brandSoft,
        elevation: 2,
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.compass),
            selectedIcon: Icon(LucideIcons.compass, color: AppColors.primary),
            label: 'Khám phá',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.heart),
            selectedIcon: Icon(LucideIcons.heart, color: AppColors.primary),
            label: 'Yêu thích',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.calendarCheck),
            selectedIcon:
                Icon(LucideIcons.calendarCheck, color: AppColors.primary),
            label: 'Chuyến đi',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.settings),
            selectedIcon: Icon(LucideIcons.settings, color: AppColors.primary),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
