import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../villas/presentation/screens/villa_list_screen.dart';

/// `/search` and `/noi-luu-tru` render the full Search & Filter screen (`SearchPage.tsx`).
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const VillaListScreen();
  }
}
