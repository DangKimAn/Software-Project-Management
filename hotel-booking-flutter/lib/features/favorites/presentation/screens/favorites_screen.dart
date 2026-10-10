import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../villas/presentation/widgets/property_card.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final villasAsync = ref.watch(villaListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách yêu thích'),
      ),
      body: villasAsync.when(
        data: (allVillas) {
          final savedVillas =
              allVillas.where((v) => favorites.contains(v.id)).toList();

          if (savedVillas.isEmpty) {
            return AppEmptyView(
              icon: LucideIcons.heart,
              title: 'Chưa có biệt thự nào được lưu',
              description:
                  'Bấm vào biểu tượng trái tim ở góc ảnh biệt thự để thêm vào danh sách yêu thích.',
              actionText: 'Khám phá biệt thự',
              onAction: () => context.go('/'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: savedVillas.length,
            itemBuilder: (context, index) {
              final villa = savedVillas[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: PropertyCard(
                  villa: villa,
                  isFavorite: true,
                  onFavoriteToggle: () {
                    ref
                        .read(favoritesProvider.notifier)
                        .toggleFavorite(villa.id);
                  },
                  onTap: () => context.push('/villas/${villa.id}'),
                ),
              );
            },
          );
        },
        loading: () =>
            const AppLoading(message: 'Đang tải danh sách yêu thích...'),
        error: (err, _) => Center(child: Text('Lỗi: $err')),
      ),
    );
  }
}
