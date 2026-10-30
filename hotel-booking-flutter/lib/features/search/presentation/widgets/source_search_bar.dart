import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/date/booking_date.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/animations/source_animations.dart';
import '../../../../shared/widgets/app_semantic_icons.dart';
import '../../../../shared/widgets/vung_tau_map_picker.dart';
import '../../../villas/data/repositories/villa_repository_impl.dart';

/// Complete port of `SearchBar.tsx`, `BookingWidget.tsx`, `DatePickerPanel.tsx`, `Guest.tsx`, and `StayFilterModal`.
class SourceSearchBar extends ConsumerStatefulWidget {
  final bool isCompact;
  final bool isInHeader;
  final VoidCallback? onSearchSubmitted;
  final VoidCallback? onOpenAiSearch;

  const SourceSearchBar({
    super.key,
    this.isCompact = false,
    this.isInHeader = false,
    this.onSearchSubmitted,
    this.onOpenAiSearch,
  });

  @override
  ConsumerState<SourceSearchBar> createState() => _SourceSearchBarState();
}

class _SourceSearchBarState extends ConsumerState<SourceSearchBar> {
  void _openSearchModal(BuildContext context, {int initialTab = 0}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => _SearchPopoverSheet(
        initialTab: initialTab,
        onSubmitted: () {
          Navigator.of(ctx).pop();
          if (widget.onSearchSubmitted != null) {
            widget.onSearchSubmitted!();
          } else {
            context.push('/tim-kiem');
          }
        },
      ),
    );
  }

  String _locationSummary(VillaFilterState filter) {
    if (filter.locationGroup != null && filter.locationGroup!.isNotEmpty) {
      final match = VungTauMapConstants.findLocationGroup(filter.locationGroup);
      if (match != null) return match.label;
    }
    if (filter.searchQuery.trim().isNotEmpty) {
      return filter.searchQuery.trim();
    }
    if (filter.lat != null && filter.lng != null) {
      return 'Vị trí bản đồ (${filter.radius ?? 800}m)';
    }
    return 'Bạn muốn đi đâu?';
  }

  String _checkInSummary(VillaFilterState filter) {
    if (filter.dateMode == 'months' && filter.selectedMonths.isNotEmpty) {
      final sorted = [...filter.selectedMonths]..sort();
      return 'Tháng ${sorted.join(', ')}';
    }
    if (filter.dateMode == 'flexible') {
      final label = switch (filter.flexDuration) {
        'week' => '1 tuần',
        'month' => '1 tháng',
        _ => 'Cuối tuần',
      };
      return 'Linh hoạt ($label)';
    }
    if (filter.checkIn != null) {
      return filter.checkIn!.toDisplayVi();
    }
    return 'Chọn ngày';
  }

  String _checkOutSummary(VillaFilterState filter) {
    if (filter.dateMode == 'months' && filter.selectedMonths.isNotEmpty) {
      return 'Theo tháng';
    }
    if (filter.dateMode == 'flexible') {
      return 'Linh hoạt';
    }
    if (filter.checkOut != null) {
      final suffix =
          filter.exactnessDays > 0 ? ' (±${filter.exactnessDays}N)' : '';
      return '${filter.checkOut!.toDisplayVi()}$suffix';
    }
    return 'Chọn ngày';
  }

  String _dateSummary(VillaFilterState filter) {
    if (filter.dateMode == 'months' && filter.selectedMonths.isNotEmpty) {
      final sorted = [...filter.selectedMonths]..sort();
      return 'Tháng ${sorted.join(', ')}';
    }
    if (filter.dateMode == 'flexible') {
      final label = switch (filter.flexDuration) {
        'week' => '1 tuần',
        'month' => '1 tháng',
        _ => 'Cuối tuần',
      };
      return 'Linh hoạt • $label';
    }
    if (filter.checkIn != null && filter.checkOut != null) {
      final suffix =
          filter.exactnessDays > 0 ? ' (±${filter.exactnessDays}N)' : '';
      return '${filter.checkIn!.toDisplayVi()} - ${filter.checkOut!.toDisplayVi()}$suffix';
    }
    return 'Chọn ngày';
  }

  String _guestSummary(VillaFilterState filter) {
    final total = filter.effectiveGuests;
    if (total <= 0 && filter.infants <= 0 && filter.pets <= 0) {
      return 'Thêm khách';
    }
    final parts = <String>[];
    if (total > 0) parts.add('$total khách');
    if (filter.infants > 0) parts.add('${filter.infants} em bé');
    if (filter.pets > 0) parts.add('${filter.pets} thú cưng');
    return parts.join(', ');
  }

  void _triggerSubmit(BuildContext context) {
    if (widget.onSearchSubmitted != null) {
      widget.onSearchSubmitted!();
    } else {
      context.push('/tim-kiem');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(villaFilterProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide =
        screenWidth >= 768 && !widget.isCompact && !widget.isInHeader;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    final Widget searchBarChild;
    if (!isWide || widget.isInHeader) {
      final inHeader = widget.isInHeader;
      // Pill Search Bar matching reference design (left mapPin + content + right circular search button, no AI button)
      searchBarChild = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSearchModal(context, initialTab: 0),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            key: ValueKey<String>(
              inHeader ? 'header-search-bar' : 'compact-search-bar',
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: inHeader ? 1.0 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x120F172A),
                  blurRadius: inHeader ? 10 : 16,
                  offset: Offset(0, inHeader ? 2 : 6),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              inHeader ? (screenWidth < 420 ? 10 : 12) : 14,
              inHeader ? 4 : 6,
              inHeader ? 4 : 6,
              inHeader ? 4 : 6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.mapPin,
                  size: inHeader ? (screenWidth < 420 ? 16 : 18) : 20,
                  color: AppColors.iconStrong,
                ),
                SizedBox(width: inHeader ? (screenWidth < 420 ? 6 : 8) : 10),
                Expanded(
                  child: inHeader
                      ? Text(
                          _locationSummary(filter),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: screenWidth < 420 ? 13.0 : 14.0,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _locationSummary(filter),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: screenWidth < 420 ? 12.0 : 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_dateSummary(filter)} • ${_guestSummary(filter)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: screenWidth < 420 ? 10.0 : 11.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                ),
                SizedBox(width: inHeader ? 4 : 8),
                Semantics(
                  button: true,
                  label: 'Tìm kiếm',
                  child: InkWell(
                    onTap: () => _triggerSubmit(context),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: inHeader ? (screenWidth < 420 ? 32 : 36) : 44,
                      height: inHeader ? (screenWidth < 420 ? 32 : 36) : 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          LucideIcons.search,
                          size: inHeader ? (screenWidth < 420 ? 14 : 16) : 19,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Desktop / Wide 4-segment Pill Search Bar (without "Tìm AI")
      searchBarChild = ConstrainedBox(
        key: const ValueKey<String>('wide-search-bar'),
        constraints: const BoxConstraints(maxWidth: 920),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          child: Row(
            children: [
              const Icon(
                LucideIcons.mapPin,
                size: 20,
                color: AppColors.iconStrong,
              ),
              Expanded(
                flex: 12,
                child: _SegmentTrigger(
                  title: 'Địa điểm',
                  subtitle: _locationSummary(filter),
                  onTap: () => _openSearchModal(context, initialTab: 0),
                ),
              ),
              Container(width: 1, height: 34, color: const Color(0xFFE2E8F0)),
              Expanded(
                flex: 9,
                child: _SegmentTrigger(
                  title: 'Nhận phòng',
                  subtitle: _checkInSummary(filter),
                  onTap: () => _openSearchModal(context, initialTab: 1),
                ),
              ),
              Container(width: 1, height: 34, color: const Color(0xFFE2E8F0)),
              Expanded(
                flex: 9,
                child: _SegmentTrigger(
                  title: 'Trả phòng',
                  subtitle: _checkOutSummary(filter),
                  onTap: () => _openSearchModal(context, initialTab: 1),
                ),
              ),
              Container(width: 1, height: 34, color: const Color(0xFFE2E8F0)),
              Expanded(
                flex: 11,
                child: InkWell(
                  onTap: () => _openSearchModal(context, initialTab: 2),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 4,
                      top: 4,
                      bottom: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Khách',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _guestSummary(filter),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: filter.effectiveGuests > 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: filter.effectiveGuests > 0
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          label: 'Tìm kiếm',
                          child: InkWell(
                            onTap: () => _triggerSubmit(context),
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  LucideIcons.search,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (disableAnimations) {
      return searchBarChild;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: const Cubic(0.22, 1.0, 0.36, 1.0),
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: searchBarChild,
    );
  }
}

class _SegmentTrigger extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SegmentTrigger({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = subtitle == 'Bạn muốn đi đâu?' ||
        subtitle == 'Chọn ngày' ||
        subtitle == 'Thêm khách';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isPlaceholder ? FontWeight.w400 : FontWeight.w600,
                color: isPlaceholder
                    ? const Color(0xFF64748B)
                    : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive Search Popover Sheet (`SearchPopover.tsx` + `DatePickerPanel.tsx` + `Guest.tsx` + `LocationMapPicker.tsx`).
class _SearchPopoverSheet extends ConsumerStatefulWidget {
  final int initialTab; // 0 = Địa điểm, 1 = Thời gian, 2 = Khách
  final VoidCallback onSubmitted;

  const _SearchPopoverSheet({
    required this.initialTab,
    required this.onSubmitted,
  });

  @override
  ConsumerState<_SearchPopoverSheet> createState() =>
      _SearchPopoverSheetState();
}

class _SearchPopoverSheetState extends ConsumerState<_SearchPopoverSheet> {
  late int _activeTab;
  late TextEditingController _queryCtrl;
  bool _showMapPicker = false;
  late int _calendarMonth;
  late int _calendarYear;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    final filter = ref.read(villaFilterProvider);
    _queryCtrl = TextEditingController(text: filter.searchQuery);
    _showMapPicker = filter.lat != null && filter.lng != null;
    final now = DateTime.now();
    _calendarMonth = filter.checkIn?.month ?? now.month;
    _calendarYear = filter.checkIn?.year ?? now.year;
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  void _stepCalendarMonth(int delta) {
    setState(() {
      final next = DateTime(_calendarYear, _calendarMonth + delta, 1);
      _calendarYear = next.year;
      _calendarMonth = next.month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(villaFilterProvider);
    final history = ref.watch(searchHistoryProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.86,
          maxChildSize: 0.95,
          minChildSize: 0.55,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Top tab switcher (responsive on 320px, 48x48 close button)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _TabPill(
                                label: 'Địa điểm',
                                selected: _activeTab == 0,
                                onTap: () => setState(() => _activeTab = 0),
                              ),
                              const SizedBox(width: 8),
                              _TabPill(
                                label: 'Thời gian',
                                selected: _activeTab == 1,
                                onTap: () => setState(() => _activeTab = 1),
                              ),
                              const SizedBox(width: 8),
                              _TabPill(
                                label: 'Khách',
                                selected: _activeTab == 2,
                                onTap: () => setState(() => _activeTab = 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(12),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Icon(
                              LucideIcons.x,
                              size: 20,
                              color: AppColors.iconStrong,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_activeTab == 0)
                        SearchPopIn(
                          child: _buildLocationTab(filter, history),
                        )
                      else if (_activeTab == 1)
                        CalFadeIn(
                          child: _buildDateTab(filter),
                        )
                      else
                        SearchPopIn(
                          child: _buildGuestTab(filter),
                        ),
                    ],
                  ),
                ),
                // Bottom Action Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          _queryCtrl.clear();
                          ref.read(villaFilterProvider.notifier).state =
                              const VillaFilterState();
                        },
                        child: const Text(
                          'Xóa tất cả',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Flexible(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final q = _queryCtrl.text.trim();
                            if (q.isNotEmpty) {
                              ref
                                  .read(searchHistoryProvider.notifier)
                                  .addTerm(q);
                            }
                            ref.read(villaFilterProvider.notifier).update(
                                  (s) => s.copyWith(searchQuery: q, page: 1),
                                );
                            widget.onSubmitted();
                          },
                          icon: const Icon(
                            LucideIcons.search,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Áp dụng & Tìm kiếm',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLocationTab(VillaFilterState filter, List<String> history) {
    final isGeoActive = filter.lat != null && filter.lng != null;
    const groups = VungTauMapConstants.locationGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _queryCtrl,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Tìm tên villa, đường, khu vực...',
            hintStyle: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.textPrimary,
                width: 1.3,
              ),
            ),
            prefixIcon: const Icon(
              LucideIcons.search,
              size: 18,
              color: AppColors.iconMuted,
            ),
            suffixIcon: _queryCtrl.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      setState(() => _queryCtrl.clear());
                      ref.read(villaFilterProvider.notifier).update(
                            (s) => s.copyWith(searchQuery: ''),
                          );
                    },
                    icon: const Icon(
                      LucideIcons.x,
                      size: 16,
                      color: AppColors.iconMuted,
                    ),
                  )
                : null,
          ),
          onChanged: (val) {
            setState(() {});
            ref
                .read(villaFilterProvider.notifier)
                .update((s) => s.copyWith(searchQuery: val));
          },
        ),
        const SizedBox(height: 12),

        // Quick Actions: Gần tôi & Chọn trên bản đồ (compact 1-line pills)
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  ref.read(villaFilterProvider.notifier).update(
                        (s) => s.copyWith(
                          lat: VungTauMapConstants.defaultLat,
                          lng: VungTauMapConstants.defaultLng,
                          radius: VungTauMapConstants.defaultRadiusMeters,
                          clearLocationGroup: true,
                          page: 1,
                        ),
                      );
                  setState(() => _showMapPicker = true);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isGeoActive
                          ? AppColors.primary
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.navigation,
                        size: 15,
                        color: AppColors.iconStrong,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Gần tôi (800m)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isGeoActive
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _showMapPicker = !_showMapPicker),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _showMapPicker
                          ? AppColors.primary
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.map,
                        size: 15,
                        color: AppColors.iconStrong,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _showMapPicker ? 'Ẩn bản đồ' : 'Chọn trên bản đồ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _showMapPicker
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_showMapPicker) ...[
          const SizedBox(height: 14),
          VungTauMapPicker(
            initialLat: filter.lat ?? VungTauMapConstants.defaultLat,
            initialLng: filter.lng ?? VungTauMapConstants.defaultLng,
            radiusMeters:
                filter.radius ?? VungTauMapConstants.defaultRadiusMeters,
            height: 260,
            onLocationChanged: (lat, lng, label) {
              ref.read(villaFilterProvider.notifier).update(
                    (s) => s.copyWith(
                      lat: lat,
                      lng: lng,
                      radius: VungTauMapConstants.defaultRadiusMeters,
                      clearLocationGroup: true,
                      page: 1,
                    ),
                  );
            },
          ),
        ],

        // Search History (`searchHistoryStorage.ts`)
        if (history.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tìm kiếm gần đây',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(searchHistoryProvider.notifier).clear(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Xóa',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: history.map((term) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() => _queryCtrl.text = term);
                        ref.read(villaFilterProvider.notifier).update(
                              (s) => s.copyWith(searchQuery: term, page: 1),
                            );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.clock,
                            size: 13,
                            color: AppColors.iconMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            term,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => ref
                          .read(searchHistoryProvider.notifier)
                          .removeTerm(term),
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          LucideIcons.x,
                          size: 13,
                          color: AppColors.iconMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],

        // 8 VUNG_TAU_LOCATION_GROUPS in a clean 2-column grid
        const SizedBox(height: 18),
        const Text(
          'Khu vực nổi bật',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < groups.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildAreaChipCard(groups[i], filter),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: i + 1 < groups.length
                    ? _buildAreaChipCard(groups[i + 1], filter)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAreaChipCard(
    VungTauLocationGroup group,
    VillaFilterState filter,
  ) {
    final isSelected = filter.locationGroup == group.key ||
        filter.locationGroup == group.id ||
        filter.locationGroup == group.label;

    return InkWell(
      onTap: () {
        ref.read(villaFilterProvider.notifier).update(
              (s) => s.copyWith(
                locationGroup: group.key,
                searchQuery: '',
                clearGeo: true,
                page: 1,
              ),
            );
        setState(() {
          _queryCtrl.clear();
          _activeTab = 1; // Advance to Date tab
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.mapPin,
              size: 16,
              color: isSelected ? Colors.white : AppColors.iconMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                group.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              const Icon(
                LucideIcons.check,
                size: 14,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _switchDateMode(String nextMode, VillaFilterState current) {
    if (nextMode == 'months') {
      final computed =
          SearchDateModeHelper.computeForMonths(current.selectedMonths);
      ref.read(villaFilterProvider.notifier).update(
            (s) => s.copyWith(
              dateMode: 'months',
              selectedMonths: computed.months,
              checkIn: computed.checkIn,
              checkOut: computed.checkOut,
              exactnessDays: 0,
            ),
          );
    } else if (nextMode == 'flexible') {
      final computed =
          SearchDateModeHelper.computeForFlexible(current.flexDuration);
      ref.read(villaFilterProvider.notifier).update(
            (s) => s.copyWith(
              dateMode: 'flexible',
              selectedMonths: const [],
              checkIn: computed.checkIn,
              checkOut: computed.checkOut,
              exactnessDays: 0,
            ),
          );
    } else {
      final today = BookingDate.todayVn();
      final nextIn =
          (current.checkIn != null && !current.checkIn!.isBefore(today))
              ? current.checkIn!
              : today.addDays(1);
      final nextOut =
          (current.checkOut != null && current.checkOut!.isAfter(nextIn))
              ? current.checkOut!
              : nextIn.addDays(2);
      ref.read(villaFilterProvider.notifier).update(
            (s) => s.copyWith(
              dateMode: 'dates',
              selectedMonths: const [],
              checkIn: nextIn,
              checkOut: nextOut,
            ),
          );
    }
  }

  Widget _buildDateTab(VillaFilterState filter) {
    final mode = filter.dateMode == 'months' ? 'months' : 'dates';
    final currentMonth = DateTime.now().month;
    final availableMonths = [
      for (int m = currentMonth; m <= 12; m++) m,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2-mode Switcher (`Ngày` | `Tháng` — no `Linh hoạt`, no gray background)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              for (final entry in const [
                ('dates', 'Ngày'),
                ('months', 'Tháng'),
              ])
                Expanded(
                  child: InkWell(
                    onTap: () => _switchDateMode(entry.$1, filter),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: mode == entry.$1
                            ? AppColors.primary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: mode == entry.$1
                            ? Border.all(color: AppColors.primary, width: 1.4)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        entry.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: mode == entry.$1
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: mode == entry.$1
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (mode == 'dates') ...[
          // Month Header with MonthInSwitcher (48x48 touch targets)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => _stepCalendarMonth(-1),
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Icon(
                      LucideIcons.chevronLeft,
                      size: 18,
                      color: AppColors.iconStrong,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  'Tháng $_calendarMonth / $_calendarYear',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _stepCalendarMonth(1),
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: AppColors.iconStrong,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MonthInSwitcher(
            monthKey: '$_calendarYear-$_calendarMonth',
            child: _SimpleMonthGrid(
              year: _calendarYear,
              month: _calendarMonth,
              checkIn: filter.checkIn,
              checkOut: filter.checkOut,
              onDayTapped: (date) {
                final currentIn = filter.checkIn;
                final currentOut = filter.checkOut;
                if (currentIn == null ||
                    currentOut != null ||
                    date.isBefore(currentIn)) {
                  ref.read(villaFilterProvider.notifier).update(
                        (s) => s.copyWith(
                          checkIn: date,
                          checkOut: date.addDays(1),
                        ),
                      );
                } else if (date.isAfter(currentIn)) {
                  ref.read(villaFilterProvider.notifier).update(
                        (s) => s.copyWith(checkOut: date),
                      );
                }
              },
            ),
          ),
        ] else ...[
          const Text(
            'Chọn các tháng dự kiến đi Vũng Tàu',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: availableMonths.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
            ),
            itemBuilder: (context, idx) {
              final m = availableMonths[idx];
              final selected = filter.selectedMonths.contains(m);
              return InkWell(
                onTap: () {
                  final next = [...filter.selectedMonths]
                    ..removeWhere((item) => item < currentMonth);
                  if (selected) {
                    next.remove(m);
                  } else {
                    next.add(m);
                  }
                  final computed = SearchDateModeHelper.computeForMonths(next);
                  ref.read(villaFilterProvider.notifier).update(
                        (s) => s.copyWith(
                          selectedMonths: computed.months,
                          checkIn: computed.checkIn,
                          checkOut: computed.checkOut,
                        ),
                      );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 1.5 : 1.0,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.calendar,
                        size: 16,
                        color: selected ? Colors.white : AppColors.iconStrong,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tháng $m',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildGuestTab(VillaFilterState filter) {
    void updateGuestCounts({
      int? adults,
      int? children,
      int? infants,
      int? pets,
    }) {
      var nextAdults = adults ?? filter.adults;
      final nextChildren = children ?? filter.children;
      final nextInfants = infants ?? filter.infants;
      final nextPets = pets ?? filter.pets;

      // Source goc rule: if children/infants/pets > 0 and adults == 0, auto-set adults = 1
      if ((nextChildren > 0 || nextInfants > 0 || nextPets > 0) &&
          nextAdults == 0) {
        nextAdults = 1;
      }

      ref.read(villaFilterProvider.notifier).update(
            (s) => s.copyWith(
              adults: nextAdults,
              children: nextChildren,
              infants: nextInfants,
              pets: nextPets,
            ),
          );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Số lượng khách lưu trú',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _GuestCounterRow(
          title: 'Người lớn',
          subtitle: 'Từ 13 tuổi trở lên',
          value: filter.adults,
          onChanged: (v) => updateGuestCounts(adults: v),
        ),
        const Divider(height: 24, color: AppColors.divider),
        _GuestCounterRow(
          title: 'Trẻ em',
          subtitle: 'Độ tuổi 2 – 12',
          value: filter.children,
          onChanged: (v) => updateGuestCounts(children: v),
        ),
        const Divider(height: 24, color: AppColors.divider),
        _GuestCounterRow(
          title: 'Em bé',
          subtitle: 'Dưới 2 tuổi',
          value: filter.infants,
          onChanged: (v) => updateGuestCounts(infants: v),
        ),
        const Divider(height: 24, color: AppColors.divider),
        _GuestCounterRow(
          title: 'Thú cưng',
          subtitle: 'Mang theo thú cưng đi cùng',
          value: filter.pets,
          onChanged: (v) => updateGuestCounts(pets: v),
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2.5,
              width: selected ? 28 : 0,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestCounterRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final int value;
  final ValueChanged<int> onChanged;

  const _GuestCounterRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            InkWell(
              onTap: value > 0 ? () => onChanged(value - 1) : null,
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(
                    LucideIcons.minus,
                    size: 18,
                    color:
                        value > 0 ? AppColors.iconStrong : AppColors.textMuted,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 32,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            InkWell(
              onTap: value < 40 ? () => onChanged(value + 1) : null,
              borderRadius: BorderRadius.circular(999),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(
                    LucideIcons.plus,
                    size: 18,
                    color: AppColors.iconStrong,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SimpleMonthGrid extends StatelessWidget {
  final int year;
  final int month;
  final BookingDate? checkIn;
  final BookingDate? checkOut;
  final ValueChanged<BookingDate> onDayTapped;

  const _SimpleMonthGrid({
    required this.year,
    required this.month,
    required this.checkIn,
    required this.checkOut,
    required this.onDayTapped,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startOffset = (firstDay.weekday - 1) % 7;
    final today = BookingDate.today();

    return Column(
      children: [
        Row(
          children: [
            for (final w in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: startOffset + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            if (index < startOffset) return const SizedBox.shrink();
            final day = index - startOffset + 1;
            final date = BookingDate(year: year, month: month, day: day);
            final isPast = date.isBefore(today);
            final isStart = checkIn == date;
            final isEnd = checkOut == date;
            final isInRange = checkIn != null &&
                checkOut != null &&
                date.isAfter(checkIn!) &&
                date.isBefore(checkOut!);

            return InkWell(
              onTap: isPast ? null : () => onDayTapped(date),
              customBorder: const CircleBorder(),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: (isStart || isEnd)
                          ? AppColors.primary
                          : isInRange
                              ? AppColors.rangeBackground
                              : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: (isStart || isEnd || isInRange)
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isPast
                            ? AppColors.textMuted
                            : (isStart || isEnd)
                                ? Colors.white
                                : isInRange
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Opens the StayFilterModal (`stays/filter/StayFilterModal.tsx`) for advanced filtering.
Future<void> showStayFilterModal(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _StayFilterModalSheet(),
  );
}

class _StayFilterModalSheet extends ConsumerStatefulWidget {
  const _StayFilterModalSheet();

  @override
  ConsumerState<_StayFilterModalSheet> createState() =>
      _StayFilterModalSheetState();
}

class _StayFilterModalSheetState extends ConsumerState<_StayFilterModalSheet> {
  static const List<(String, String)> _propertyTypes = [
    ('all', 'Tất cả loại hình'),
    ('villa', 'Biệt thự (Villa)'),
    ('apartment', 'Căn hộ (Apartment)'),
    ('homestay', 'Homestay'),
    ('hotel', 'Khách sạn (Hotel)'),
  ];

  static const List<(String, String)> _sortOptions = [
    ('newest', 'Mới nhất'),
    ('price_asc', 'Giá thấp đến cao'),
    ('price_desc', 'Giá cao đến thấp'),
    ('rating_desc', 'Đánh giá cao nhất'),
  ];

  /// Exact 12 canonical amenity codes & Vietnamese labels from
  /// `Source goc/frontend/src/views/components/stays/filter/filterOptions.ts`.
  static const List<(String, String)> _amenityOptions = [
    ('pool', 'Hồ bơi'),
    ('wifi', 'Wifi'),
    ('kitchen', 'Bếp'),
    ('air_conditioner', 'Điều hòa'),
    ('washer', 'Máy giặt'),
    ('parking', 'Chỗ đậu xe'),
    ('pet_friendly', 'Cho mang thú cưng'),
    ('near_beach', 'Gần biển'),
    ('bbq', 'Có BBQ'),
    ('balcony', 'Ban công'),
    ('nice_view', 'View đẹp'),
    ('self_checkin', 'Tự check-in'),
  ];

  late String _propertyType;
  late RangeValues _priceRange;
  late int _bedrooms;
  late int _beds;
  late int _bathrooms;
  late Set<String> _amenities;
  late String _sort;

  @override
  void initState() {
    super.initState();
    final f = ref.read(villaFilterProvider);
    _propertyType = f.propertyType;
    _priceRange = RangeValues(
      (f.priceMin ?? 500000).clamp(500000, 20000000).toDouble(),
      (f.priceMax ?? 20000000).clamp(500000, 20000000).toDouble(),
    );
    _bedrooms = f.bedrooms ?? 0;
    _beds = f.beds ?? 0;
    _bathrooms = f.bathrooms ?? 0;
    _amenities =
        f.amenities.map(VillaRepositoryImpl.normalizeAmenityCode).toSet();
    _sort = f.sort;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Bộ lọc tìm kiếm nâng cao',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(12),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Icon(
                              LucideIcons.x,
                              size: 20,
                              color: AppColors.iconStrong,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Sort
                      const Text(
                        'Sắp xếp theo',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _sortOptions.map((opt) {
                          final selected = _sort == opt.$1;
                          return ChoiceChip(
                            avatar: opt.$1 == 'newest'
                                ? null
                                : Icon(
                                    AppSemanticIcons.resolveSortIcon(opt.$1),
                                    size: 15,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.iconStrong,
                                  ),
                            showCheckmark: false,
                            selectedColor: AppColors.primary,
                            label: Text(
                              opt.$2,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: selected,
                            onSelected: (_) => setState(() => _sort = opt.$1),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Property Type
                      const Text(
                        'Loại hình lưu trú',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _propertyTypes.map((t) {
                          final selected = _propertyType == t.$1;
                          return ChoiceChip(
                            showCheckmark: false,
                            selectedColor: AppColors.primary,
                            label: Text(
                              t.$2,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _propertyType = t.$1),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Price Range Slider (500k .. 20M VND, responsive Wrap at 320px)
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'Khoảng giá mỗi đêm',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${CurrencyFormatter.formatVnd(_priceRange.start.round())} - ${CurrencyFormatter.formatVnd(_priceRange.end.round())}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      RangeSlider(
                        values: _priceRange,
                        min: 500000,
                        max: 20000000,
                        divisions: 39,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => _priceRange = v),
                      ),
                      const SizedBox(height: 20),

                      // Rooms & Beds
                      const Text(
                        'Phòng và giường',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _RoomCountPills(
                        label: 'Phòng ngủ',
                        value: _bedrooms,
                        onChanged: (v) => setState(() => _bedrooms = v),
                      ),
                      const SizedBox(height: 12),
                      _RoomCountPills(
                        label: 'Số giường',
                        value: _beds,
                        onChanged: (v) => setState(() => _beds = v),
                      ),
                      const SizedBox(height: 12),
                      _RoomCountPills(
                        label: 'Phòng tắm',
                        value: _bathrooms,
                        onChanged: (v) => setState(() => _bathrooms = v),
                      ),
                      const SizedBox(height: 24),

                      // Amenities (12 canonical stayAmenityOptions)
                      const Text(
                        'Tiện nghi nổi bật',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _amenityOptions.map((opt) {
                          final code = opt.$1;
                          final label = opt.$2;
                          final selected = _amenities.contains(code);
                          return FilterChip(
                            avatar: Icon(
                              AppSemanticIcons.resolveAmenityIcon(label),
                              size: 15,
                              color: selected
                                  ? Colors.white
                                  : AppColors.iconStrong,
                            ),
                            showCheckmark: false,
                            selectedColor: AppColors.primary,
                            label: Text(
                              label,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: selected,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _amenities.add(code);
                                } else {
                                  _amenities.remove(code);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _propertyType = 'all';
                            _priceRange = const RangeValues(500000, 20000000);
                            _bedrooms = 0;
                            _beds = 0;
                            _bathrooms = 0;
                            _amenities.clear();
                            _sort = 'newest';
                          });
                        },
                        child: const Text('Đặt lại bộ lọc'),
                      ),
                      Flexible(
                        child: ElevatedButton(
                          onPressed: () {
                            final minP = _priceRange.start.round();
                            final maxP = _priceRange.end.round();
                            ref.read(villaFilterProvider.notifier).update(
                                  (s) => s.copyWith(
                                    propertyType: _propertyType,
                                    priceMin: minP > 500000 ? minP : null,
                                    priceMax: maxP < 20000000 ? maxP : null,
                                    clearPrice:
                                        minP <= 500000 && maxP >= 20000000,
                                    bedrooms: _bedrooms > 0 ? _bedrooms : null,
                                    beds: _beds > 0 ? _beds : null,
                                    bathrooms:
                                        _bathrooms > 0 ? _bathrooms : null,
                                    amenities: _amenities.toList(),
                                    sort: _sort,
                                    page: 1,
                                  ),
                                );
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          child: const Text(
                            'Hiển thị kết quả',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RoomCountPills extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _RoomCountPills({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final count in const [0, 1, 2, 3, 4, 5, 6])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => onChanged(count),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: value == count
                            ? AppColors.primary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        count == 0 ? 'Bất kỳ' : '$count+',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: value == count
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens the AI Search Quick Overlay Modal (`SearchBar.tsx` AI overlay).
Future<void> showAiSearchQuickModal(
  BuildContext context,
  WidgetRef ref,
) async {
  final prefs = ref.read(preferencesServiceProvider);
  final ctrl = TextEditingController(text: prefs.getLastAiSearchQuery());

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.search,
                    size: 20,
                    color: AppColors.iconStrong,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tìm kiếm chỗ nghỉ bằng AI (CLIP Semantic Search)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(ctx).pop(),
                    borderRadius: BorderRadius.circular(12),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Icon(
                          LucideIcons.x,
                          size: 20,
                          color: AppColors.iconStrong,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Mô tả không gian phòng ngủ, hồ bơi, tầm nhìn biển hoặc phong cách thiết kế bạn mong muốn.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText:
                      'VD: Villa gần biển có hồ bơi cho 8 người cuối tuần này...',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final suggestion in const [
                    'Villa gần biển có hồ bơi cho 8 người cuối tuần này',
                    'Chỗ nghỉ yên tĩnh gần Bãi Trước cho cặp đôi dưới 1tr5',
                    'Homestay có bếp và chỗ đậu xe cho gia đình 6 người',
                  ])
                    ActionChip(
                      label: Text(
                        suggestion,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        ctrl.text = suggestion;
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final q = ctrl.text.trim();
                    if (q.isNotEmpty) {
                      prefs.setLastAiSearchQuery(q);
                    }
                    Navigator.of(ctx).pop();
                    context.push(
                      '/tim-kiem-ai${q.isNotEmpty ? '?q=${Uri.encodeComponent(q)}' : ''}',
                    );
                  },
                  icon: const Icon(
                    LucideIcons.search,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text('Khám phá bằng AI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
