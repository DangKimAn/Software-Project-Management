import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/date/booking_date.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../widgets/booking_date_range_picker.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  BookingDate? _checkIn;
  BookingDate? _checkOut;
  int _guests = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    ref.read(villaFilterProvider.notifier).state = VillaFilterState(
      searchQuery: _searchController.text.trim(),
      minGuests: _guests > 0 ? _guests : null,
      checkIn: _checkIn,
      checkOut: _checkOut,
    );
    context.push('/villas');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm biệt thự'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _checkIn = null;
                _checkOut = null;
                _guests = 10;
              });
            },
            child: const Text('Xóa tất cả',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Keyword / Destination input
            AppTextField(
              controller: _searchController,
              labelText: 'Địa điểm hoặc tên biệt thự',
              hintText: 'VD: Bãi Sau, Bãi Trước, Thùy Vân...',
              prefixIcon: const Icon(LucideIcons.mapPin,
                  size: 18, color: AppColors.primary),
            ),

            const SizedBox(height: 24),

            // Date Range Selection
            Text(
              'Chọn thời gian lưu trú',
              style: AppTypography.cardTitle.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSoft),
                boxShadow: const [AppColors.shadowGlass],
              ),
              child: BookingDateRangePicker(
                initialCheckIn: _checkIn,
                initialCheckOut: _checkOut,
                onRangeSelected: (range) {
                  setState(() {
                    _checkIn = range.$1;
                    _checkOut = range.$2;
                  });
                },
              ),
            ),

            const SizedBox(height: 24),

            // Guest Count Selector
            Text(
              'Số lượng khách lưu trú',
              style: AppTypography.cardTitle.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_guests khách',
                        style: AppTypography.cardTitle.copyWith(fontSize: 16),
                      ),
                      Text(
                        'Phù hợp cho đoàn từ 1 - 30 người',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton.outlined(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: _guests > 1
                            ? () => setState(() => _guests--)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          '$_guests',
                          style: AppTypography.cardTitle.copyWith(fontSize: 16),
                        ),
                      ),
                      IconButton.outlined(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: _guests < 30
                            ? () => setState(() => _guests++)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Search Submit CTA Button
            AppButton(
              text: 'Tìm kiếm ngay',
              icon: const Icon(LucideIcons.search, size: 18),
              onPressed: _onSearch,
            ),
          ],
        ),
      ),
    );
  }
}
