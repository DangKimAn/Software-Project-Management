import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../villas/presentation/screens/villa_list_screen.dart';

/// Điểm vào định tuyến của các đường dẫn `/search`, `/tim-kiem` và `/noi-luu-tru`, ủy quyền hiển thị cho `VillaListScreen`.
///
/// `/search` and `/noi-luu-tru` render the full Search & Filter screen (`SearchPage.tsx`).
class SearchScreen extends ConsumerWidget {
  /// Khởi tạo màn hình tìm kiếm `SearchScreen`.
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const VillaListScreen();
  }
}
