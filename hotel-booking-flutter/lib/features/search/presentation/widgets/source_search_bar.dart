import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/date/booking_date.dart';

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
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _SearchPopoverSheet(
        initialTab: initialTab,
        onSubmitted: () {
          Navigator.of(ctx).pop();
          if (widget.onSearchSubmitted != null) {
            widget.onSearchSubmitted!();
          } else if (context.mounted) {
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

String _normalizeViSearch(String input) {
  var s = input.toLowerCase().trim();
  const diacritics = <String, String>{
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  diacritics.forEach((ascii, chars) {
    for (final rune in chars.runes) {
      s = s.replaceAll(String.fromCharCode(rune), ascii);
    }
  });
  return s;
}

class _SearchPopoverSheetState extends ConsumerState<_SearchPopoverSheet> {
  late int _activeTab;
  late TextEditingController _queryCtrl;
  bool _showMapPicker = false;
  bool _selectingCheckOut = false;
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

  void _submitSearch() {
    final q = _queryCtrl.text.trim();
    if (q.isNotEmpty) {
      ref.read(searchHistoryProvider.notifier).addTerm(q);
    }
    ref.read(villaFilterProvider.notifier).update(
          (s) => s.copyWith(
            searchQuery: q,
            page: 1,
          ),
        );
    widget.onSubmitted();
  }

  String? _activeLocationBadge(VillaFilterState filter) {
    if (filter.locationGroup != null && filter.locationGroup!.isNotEmpty) {
      final match = VungTauMapConstants.findLocationGroup(filter.locationGroup);
      if (match != null) return match.label;
    }
    if (filter.searchQuery.trim().isNotEmpty) {
      return filter.searchQuery.trim();
    }
    if (filter.lat != null && filter.lng != null) {
      return 'Gần tôi (${filter.radius ?? 800}m)';
    }
    return null;
  }

  String? _activeDateBadge(VillaFilterState filter) {
    if (filter.dateMode == 'months' && filter.selectedMonths.isNotEmpty) {
      final sorted = [...filter.selectedMonths]..sort();
      return 'Tháng ${sorted.join(', ')}';
    }
    if (filter.checkIn != null && filter.checkOut != null) {
      return '${filter.checkIn!.toDisplayVi()} → ${filter.checkOut!.toDisplayVi()}';
    }
    return null;
  }

  String? _activeGuestBadge(VillaFilterState filter) {
    final total = filter.effectiveGuests;
    if (total <= 0 && filter.infants <= 0 && filter.pets <= 0) {
      return null;
    }
    final parts = <String>[];
    if (total > 0) parts.add('$total khách');
    if (filter.infants > 0) parts.add('${filter.infants} bé');
    if (filter.pets > 0) parts.add('${filter.pets} thú cưng');
    return parts.join(', ');
  }

  String _shortAreaSubtitle(VungTauLocationGroup group, {String query = ''}) {
    final parts = group.subtitle
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Vũng Tàu';

    final normalizedQuery = _normalizeViSearch(query);
    if (normalizedQuery.isNotEmpty) {
      for (final street in parts) {
        if (_normalizeViSearch(street).contains(normalizedQuery) &&
            street != parts.first) {
          return '$street · ${parts.first}';
        }
      }
    }

    if (parts.length == 1) {
      return parts.first == group.label
          ? 'Trục biển ${group.label}'
          : parts.first;
    }
    return '${parts[0]} · ${parts[1]}';
  }

  bool _groupMatchesQuery(VungTauLocationGroup group, String rawQuery) {
    final q = _normalizeViSearch(rawQuery);
    if (q.isEmpty) return true;
    if (_normalizeViSearch(group.label).contains(q)) return true;
    if (_normalizeViSearch(group.subtitle).contains(q)) return true;
    return false;
  }

  IconData _areaSemanticIcon(VungTauLocationGroup group) {
    switch (group.key) {
      case 'trung_tam':
      case 'chi_linh':
        return LucideIcons.building2;
      default:
        return LucideIcons.waves;
    }
  }

  void _clearLocationOnly() {
    setState(() {
      _queryCtrl.clear();
      _showMapPicker = false;
    });
    ref.read(villaFilterProvider.notifier).update(
          (s) => s.copyWith(
            searchQuery: '',
            clearLocationGroup: true,
            clearGeo: true,
            page: 1,
          ),
        );
  }

  void _clearDatesOnly() {
    setState(() => _selectingCheckOut = false);
    ref.read(villaFilterProvider.notifier).update(
          (s) => s.copyWith(
            clearDates: true,
            dateMode: 'dates',
            selectedMonths: const [],
            exactnessDays: 0,
            page: 1,
          ),
        );
  }

  void _clearGuestsOnly() {
    ref.read(villaFilterProvider.notifier).update(
          (s) => s.copyWith(
            adults: 0,
            children: 0,
            infants: 0,
            pets: 0,
            page: 1,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(villaFilterProvider);
    final history = ref.watch(searchHistoryProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final horizontalPad = screenWidth < 360 ? 14.0 : 18.0;

    final locBadge = _activeLocationBadge(filter);
    final dateBadge = _activeDateBadge(filter);
    final guestBadge = _activeGuestBadge(filter);
    final hasAnySelection =
        locBadge != null || dateBadge != null || guestBadge != null;

    final tabs = [
      (label: 'Địa điểm', icon: LucideIcons.mapPin, hasValue: locBadge != null),
      (
        label: 'Thời gian',
        icon: LucideIcons.calendar,
        hasValue: dateBadge != null,
      ),
      (label: 'Khách', icon: LucideIcons.users, hasValue: guestBadge != null),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          maxChildSize: 0.95,
          minChildSize: 0.58,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    10,
                    horizontalPad - 6,
                    hasAnySelection ? 8 : 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final useEqualSegments =
                                constraints.maxWidth >= 232 &&
                                    textScale <= 1.18;
                            final isCompactTrack = constraints.maxWidth < 275;
                            final showStepIcon = constraints.maxWidth >= 305 &&
                                textScale <= 1.12;
                            return Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: useEqualSegments
                                  ? Row(
                                      children: List.generate(
                                        tabs.length,
                                        (idx) => Expanded(
                                          child: _TabPill(
                                            label: tabs[idx].label,
                                            icon: showStepIcon
                                                ? tabs[idx].icon
                                                : null,
                                            selected: _activeTab == idx,
                                            hasActiveValue: tabs[idx].hasValue,
                                            compact: isCompactTrack,
                                            onTap: () => setState(
                                              () => _activeTab = idx,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: List.generate(
                                          tabs.length,
                                          (idx) => Padding(
                                            padding: EdgeInsets.only(
                                              right:
                                                  idx < tabs.length - 1 ? 4 : 0,
                                            ),
                                            child: _TabPill(
                                              label: tabs[idx].label,
                                              selected: _activeTab == idx,
                                              hasActiveValue:
                                                  tabs[idx].hasValue,
                                              onTap: () => setState(
                                                () => _activeTab = idx,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Semantics(
                        button: true,
                        label: 'Đóng tìm kiếm',
                        child: Tooltip(
                          message: 'Đóng',
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            customBorder: const CircleBorder(),
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
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasAnySelection) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                      child: Row(
                        children: [
                          if (locBadge != null)
                            _buildSummaryPill(
                              icon: LucideIcons.mapPin,
                              text: locBadge,
                              isFocusedTab: _activeTab == 0,
                              onTap: () => setState(() => _activeTab = 0),
                              onClear: _clearLocationOnly,
                              clearTooltip: 'Bỏ chọn địa điểm',
                            ),
                          if (dateBadge != null)
                            _buildSummaryPill(
                              icon: LucideIcons.calendar,
                              text: dateBadge,
                              isFocusedTab: _activeTab == 1,
                              onTap: () => setState(() => _activeTab = 1),
                              onClear: _clearDatesOnly,
                              clearTooltip: 'Bỏ chọn ngày',
                            ),
                          if (guestBadge != null)
                            _buildSummaryPill(
                              icon: LucideIcons.users,
                              text: guestBadge,
                              isFocusedTab: _activeTab == 2,
                              onTap: () => setState(() => _activeTab = 2),
                              onClear: _clearGuestsOnly,
                              clearTooltip: 'Bỏ chọn khách',
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const Divider(height: 1, color: AppColors.borderSoft),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPad,
                      16,
                      horizontalPad,
                      24,
                    ),
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
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    10,
                    horizontalPad,
                    12,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceBase,
                    border: Border(
                      top: BorderSide(color: AppColors.borderSoft),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, footerConstraints) {
                      final tightFooter =
                          footerConstraints.maxWidth < 320 || textScale > 1.25;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            flex: tightFooter ? 4 : 0,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                padding: EdgeInsets.symmetric(
                                  horizontal: tightFooter ? 6 : 10,
                                ),
                                foregroundColor: hasAnySelection
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () {
                                setState(() {
                                  _queryCtrl.clear();
                                  _showMapPicker = false;
                                  _selectingCheckOut = false;
                                });
                                ref.read(villaFilterProvider.notifier).state =
                                    const VillaFilterState();
                              },
                              child: Text(
                                'Xóa tất cả',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  decoration: hasAnySelection
                                      ? TextDecoration.underline
                                      : TextDecoration.none,
                                  fontWeight: hasAnySelection
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: hasAnySelection
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: tightFooter ? 7 : 1,
                            child: ElevatedButton.icon(
                              key: const Key('search_sheet_submit_btn'),
                              onPressed: _submitSearch,
                              icon: const Icon(
                                LucideIcons.search,
                                size: 16,
                                color: AppColors.iconOnBrand,
                              ),
                              label: const Text(
                                'Áp dụng & Tìm kiếm',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.textInverse,
                                minimumSize: const Size(48, 48),
                                elevation: 0,
                                shape: const StadiumBorder(),
                                padding: EdgeInsets.symmetric(
                                  horizontal: tightFooter ? 14 : 20,
                                  vertical: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryPill({
    required IconData icon,
    required String text,
    required bool isFocusedTab,
    required VoidCallback onTap,
    required VoidCallback onClear,
    required String clearTooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isFocusedTab ? AppColors.brandSoft : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isFocusedTab
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.borderSoft,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 6, 6, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: AppColors.iconStrong),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 165),
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Semantics(
              button: true,
              label: clearTooltip,
              child: Tooltip(
                message: clearTooltip,
                child: InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(4, 6, 9, 6),
                    child: Icon(
                      LucideIcons.circleX,
                      size: 14,
                      color: AppColors.iconMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionPill({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: active ? AppColors.brandSoft : AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? AppColors.primary : AppColors.border,
                width: active ? 1.4 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: AppColors.iconStrong,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationTab(VillaFilterState filter, List<String> history) {
    final isGeoActive = filter.lat != null && filter.lng != null;
    const allGroups = VungTauMapConstants.locationGroups;
    final trimmedQuery = _queryCtrl.text.trim();
    final filteredGroups = trimmedQuery.isEmpty
        ? allGroups
        : allGroups
            .where((g) => _groupMatchesQuery(g, trimmedQuery))
            .toList();
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bạn muốn nghỉ dưỡng ở đâu?',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Chọn khu vực tại Vũng Tàu hoặc nhập tên villa, tên đường',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _queryCtrl,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _submitSearch(),
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
            fillColor: AppColors.surfaceBase,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.borderFocus,
                width: 1.4,
              ),
            ),
            prefixIcon: const Icon(
              LucideIcons.search,
              size: 18,
              color: AppColors.iconStrong,
            ),
            suffixIcon: _queryCtrl.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Xóa từ khóa',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () {
                      setState(() => _queryCtrl.clear());
                      ref.read(villaFilterProvider.notifier).update(
                            (s) => s.copyWith(searchQuery: ''),
                          );
                    },
                    icon: const Icon(
                      LucideIcons.circleX,
                      size: 16,
                      color: AppColors.iconMuted,
                    ),
                  )
                : null,
          ),
          onChanged: (val) {
            setState(() {});
            ref.read(villaFilterProvider.notifier).update(
                  (s) => s.copyWith(
                    searchQuery: val,
                    clearLocationGroup: val.trim().isNotEmpty,
                    page: 1,
                  ),
                );
          },
        ),
        if (trimmedQuery.isNotEmpty) ...[
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ref.read(searchHistoryProvider.notifier).addTerm(trimmedQuery);
                setState(() => _activeTab = 1);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.search,
                      size: 15,
                      color: AppColors.iconStrong,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Tìm chỗ nghỉ với từ khóa "$trimmedQuery"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      LucideIcons.arrowRight,
                      size: 15,
                      color: AppColors.iconMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),

        // Quick Actions: Gần tôi & Chọn trên bản đồ
        LayoutBuilder(
          builder: (context, constraints) {
            final nearPill = _buildQuickActionPill(
              icon: LucideIcons.navigation,
              label: 'Gần tôi (800m)',
              active: isGeoActive,
              onTap: () {
                if (isGeoActive) {
                  ref.read(villaFilterProvider.notifier).update(
                        (s) => s.copyWith(clearGeo: true, page: 1),
                      );
                  setState(() => _showMapPicker = false);
                } else {
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
                }
              },
            );
            final mapPill = _buildQuickActionPill(
              icon: LucideIcons.map,
              label: _showMapPicker ? 'Ẩn bản đồ' : 'Chọn trên bản đồ',
              active: _showMapPicker,
              onTap: () => setState(() => _showMapPicker = !_showMapPicker),
            );

            if (constraints.maxWidth >= 312 && textScale <= 1.22) {
              return Row(
                children: [
                  Expanded(flex: 10, child: nearPill),
                  const SizedBox(width: 8),
                  Expanded(flex: 12, child: mapPill),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                nearPill,
                const SizedBox(height: 8),
                mapPill,
              ],
            );
          },
        ),

        if (_showMapPicker) ...[
          const SizedBox(height: 12),
          VungTauMapPicker(
            initialLat: filter.lat ?? VungTauMapConstants.defaultLat,
            initialLng: filter.lng ?? VungTauMapConstants.defaultLng,
            radiusMeters:
                filter.radius ?? VungTauMapConstants.defaultRadiusMeters,
            height: 250,
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
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tìm kiếm gần đây',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(searchHistoryProvider.notifier).clear(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(48, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Xóa',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
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
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() => _queryCtrl.text = term);
                        ref.read(villaFilterProvider.notifier).update(
                              (s) => s.copyWith(
                                searchQuery: term,
                                clearLocationGroup: true,
                                page: 1,
                              ),
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
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 190),
                            child: Text(
                              term,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
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
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          LucideIcons.circleX,
                          size: 13.5,
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

        // Curated Vũng Tàu destination cards (equal-height, 2-line street hints, calm selection)
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Khu vực nổi bật',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                trimmedQuery.isEmpty
                    ? 'Vũng Tàu'
                    : '${filteredGroups.length} khu vực',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (filteredGroups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: const Text(
              'Không có khu vực trùng tên — nhấn "Áp dụng & Tìm kiếm" để tìm trực tiếp theo tên villa hoặc địa chỉ.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final useTwoColumns =
                  constraints.maxWidth >= 300 && textScale <= 1.35;
              const spacing = 10.0;
              if (!useTwoColumns) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < filteredGroups.length; i++) ...[
                      if (i > 0) const SizedBox(height: spacing),
                      _buildAreaChipCard(
                        filteredGroups[i],
                        filter,
                        query: trimmedQuery,
                      ),
                    ],
                  ],
                );
              }

              final rows = <Widget>[];
              for (var i = 0; i < filteredGroups.length; i += 2) {
                if (i > 0) rows.add(const SizedBox(height: spacing));
                final leftGroup = filteredGroups[i];
                final rightGroup =
                    i + 1 < filteredGroups.length ? filteredGroups[i + 1] : null;
                rows.add(
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildAreaChipCard(
                            leftGroup,
                            filter,
                            query: trimmedQuery,
                          ),
                        ),
                        const SizedBox(width: spacing),
                        Expanded(
                          child: rightGroup != null
                              ? _buildAreaChipCard(
                                  rightGroup,
                                  filter,
                                  query: trimmedQuery,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(children: rows);
            },
          ),
      ],
    );
  }

  Widget _buildAreaChipCard(
    VungTauLocationGroup group,
    VillaFilterState filter, {
    String query = '',
  }) {
    final isSelected = filter.locationGroup == group.key ||
        filter.locationGroup == group.id ||
        filter.locationGroup == group.label;
    final streetHint = _shortAreaSubtitle(group, query: query);

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isSelected) {
              ref.read(villaFilterProvider.notifier).update(
                    (s) => s.copyWith(clearLocationGroup: true, page: 1),
                  );
              return;
            }
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
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brandSoft : AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.borderSoft,
                  width: isSelected ? 1.6 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _areaSemanticIcon(group),
                        size: 15,
                        color: isSelected
                            ? AppColors.iconStrong
                            : AppColors.iconMuted,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          group.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          LucideIcons.check,
                          size: 15,
                          color: AppColors.iconStrong,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    streetHint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.32,
                      fontWeight:
                          isSelected ? FontWeight.w500 : FontWeight.w400,
                      color: isSelected
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
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

  void _applyQuickStay(BookingDate checkIn, BookingDate checkOut) {
    ref.read(villaFilterProvider.notifier).update(
          (s) => s.copyWith(
            dateMode: 'dates',
            selectedMonths: const [],
            checkIn: checkIn,
            checkOut: checkOut,
            page: 1,
          ),
        );
    setState(() {
      _selectingCheckOut = false;
      _calendarMonth = checkIn.month;
      _calendarYear = checkIn.year;
    });
  }

  void _switchDateMode(String nextMode, VillaFilterState current) {
    setState(() => _selectingCheckOut = false);
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
    final today = BookingDate.todayVn();
    final wd = today.toDateTime().weekday;
    final daysUntilSat = (DateTime.saturday - wd + 7) % 7;
    final upcomingSat = today.addDays(daysUntilSat);
    final upcomingFri = daysUntilSat == 0 ? today : upcomingSat.addDays(-1);
    final nights = (filter.checkIn != null && filter.checkOut != null)
        ? filter.checkIn!.differenceInNights(filter.checkOut!)
        : 0;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thời gian lưu trú',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        // 2-mode Switcher (`Ngày` | `Tháng`)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(999),
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
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: mode == entry.$1
                              ? AppColors.surfaceBase
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          border: mode == entry.$1
                              ? Border.all(color: AppColors.borderSoft)
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
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (mode == 'dates') ...[
          // Quick 1-tap stay presets
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip(
                label: 'Đêm mai',
                selected: filter.checkIn == today.addDays(1) &&
                    filter.checkOut == today.addDays(2),
                onTap: () =>
                    _applyQuickStay(today.addDays(1), today.addDays(2)),
              ),
              _buildPresetChip(
                label: 'Cuối tuần này',
                selected: filter.checkIn == upcomingSat &&
                    filter.checkOut == upcomingSat.addDays(1),
                onTap: () =>
                    _applyQuickStay(upcomingSat, upcomingSat.addDays(1)),
              ),
              if (!upcomingFri.isBefore(today))
                _buildPresetChip(
                  label: 'Thứ 6 – CN (2 đêm)',
                  selected: filter.checkIn == upcomingFri &&
                      filter.checkOut == upcomingSat.addDays(1),
                  onTap: () =>
                      _applyQuickStay(upcomingFri, upcomingSat.addDays(1)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Live Check-in / Check-out overview card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: LayoutBuilder(
              builder: (context, boxConstraints) {
                final stackDates =
                    boxConstraints.maxWidth < 285 || textScale > 1.35;
                final checkInSlot = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nhận phòng',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      filter.checkIn != null
                          ? filter.checkIn!.toDisplayVi()
                          : 'Chưa chọn',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: filter.checkIn != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                );
                final checkOutSlot = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectingCheckOut ? 'Chọn ngày trả phòng' : 'Trả phòng',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _selectingCheckOut
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectingCheckOut
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      filter.checkOut != null
                          ? filter.checkOut!.toDisplayVi()
                          : 'Chưa chọn',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: filter.checkOut != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                );
                final nightPill = nights > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBase,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: Text(
                          '$nights đêm',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      )
                    : null;

                if (stackDates) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      checkInSlot,
                      const SizedBox(height: 8),
                      checkOutSlot,
                      if (nightPill != null) ...[
                        const SizedBox(height: 8),
                        nightPill,
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: checkInSlot),
                    Container(
                      width: 1,
                      height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: AppColors.border,
                    ),
                    Expanded(child: checkOutSlot),
                    if (nightPill != null) ...[
                      const SizedBox(width: 8),
                      nightPill,
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Tháng trước',
                      child: InkWell(
                        onTap: () => _stepCalendarMonth(-1),
                        borderRadius: BorderRadius.circular(999),
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
                    ),
                    Flexible(
                      child: Text(
                        'Tháng $_calendarMonth / $_calendarYear',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Tháng sau',
                      child: InkWell(
                        onTap: () => _stepCalendarMonth(1),
                        borderRadius: BorderRadius.circular(999),
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
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                MonthInSwitcher(
                  monthKey: '$_calendarYear-$_calendarMonth',
                  child: _SimpleMonthGrid(
                    year: _calendarYear,
                    month: _calendarMonth,
                    checkIn: filter.checkIn,
                    checkOut: filter.checkOut,
                    onDayTapped: (date) {
                      final currentIn = filter.checkIn;
                      if (!_selectingCheckOut ||
                          currentIn == null ||
                          !date.isAfter(currentIn)) {
                        ref.read(villaFilterProvider.notifier).update(
                              (s) => s.copyWith(
                                checkIn: date,
                                checkOut: date.addDays(1),
                                page: 1,
                              ),
                            );
                        setState(() => _selectingCheckOut = true);
                      } else {
                        ref.read(villaFilterProvider.notifier).update(
                              (s) => s.copyWith(
                                checkOut: date,
                                page: 1,
                              ),
                            );
                        setState(() => _selectingCheckOut = false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const Text(
            'Chọn các tháng dự kiến đi Vũng Tàu',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: availableMonths.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: textScale > 1.35 ? 2 : 3,
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
                    color: selected
                        ? AppColors.brandSoft
                        : AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          selected ? AppColors.primary : AppColors.borderSoft,
                      width: selected ? 1.6 : 1.0,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.calendar,
                        size: 16,
                        color: selected
                            ? AppColors.iconStrong
                            : AppColors.iconMuted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tháng $m',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: AppColors.textPrimary,
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

  Widget _buildPresetChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandSoft : AppColors.surfaceBase,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
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

    const groupPresets = <(int, String)>[
      (2, '2 khách'),
      (6, '6 khách'),
      (10, '10 khách'),
      (15, '15 khách'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Số lượng khách lưu trú',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Chọn nhanh quy mô đoàn hoặc tùy chỉnh từng nhóm khách',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in groupPresets)
              _buildPresetChip(
                label: preset.$2,
                selected: filter.adults == preset.$1 && filter.children == 0,
                onTap: () => updateGuestCounts(
                  adults: preset.$1,
                  children: 0,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceBase,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            children: [
              _GuestCounterRow(
                title: 'Người lớn',
                subtitle: 'Từ 13 tuổi trở lên',
                value: filter.adults,
                onChanged: (v) => updateGuestCounts(adults: v),
              ),
              const Divider(height: 16, color: AppColors.divider),
              _GuestCounterRow(
                title: 'Trẻ em',
                subtitle: 'Độ tuổi 2 – 12',
                value: filter.children,
                onChanged: (v) => updateGuestCounts(children: v),
              ),
              const Divider(height: 16, color: AppColors.divider),
              _GuestCounterRow(
                title: 'Em bé',
                subtitle: 'Dưới 2 tuổi',
                value: filter.infants,
                onChanged: (v) => updateGuestCounts(infants: v),
              ),
              const Divider(height: 16, color: AppColors.divider),
              _GuestCounterRow(
                title: 'Thú cưng',
                subtitle: 'Mang theo thú cưng đi cùng',
                value: filter.pets,
                onChanged: (v) => updateGuestCounts(pets: v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Em bé dưới 2 tuổi không tính vào sức chứa tiêu chuẩn của villa.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final bool hasActiveValue;
  final bool compact;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.hasActiveValue = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 11,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.surfaceBase : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border:
                    selected ? Border.all(color: AppColors.borderSoft) : null,
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 13.5,
                      color:
                          selected ? AppColors.iconStrong : AppColors.iconMuted,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 12.5 : 13.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (hasActiveValue && !selected) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
    final canDecrement = value > 0;
    final canIncrement = value < 40;
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
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              enabled: canDecrement,
              label: 'Giảm $title',
              child: InkWell(
                onTap: canDecrement ? () => onChanged(value - 1) : null,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBase,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: canDecrement
                              ? AppColors.border
                              : AppColors.borderSoft,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.minus,
                        size: 16,
                        color: canDecrement
                            ? AppColors.iconStrong
                            : AppColors.iconMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: value > 0
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              enabled: canIncrement,
              label: 'Tăng $title',
              child: InkWell(
                onTap: canIncrement ? () => onChanged(value + 1) : null,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBase,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: canIncrement
                              ? AppColors.border
                              : AppColors.borderSoft,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.plus,
                        size: 16,
                        color: canIncrement
                            ? AppColors.iconStrong
                            : AppColors.iconMuted,
                      ),
                    ),
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
    final hasRange =
        checkIn != null && checkOut != null && checkOut!.isAfter(checkIn!);

    return Column(
      children: [
        Row(
          children: [
            for (final w in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
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
            crossAxisSpacing: 0,
          ),
          itemBuilder: (context, index) {
            if (index < startOffset) return const SizedBox.shrink();
            final day = index - startOffset + 1;
            final date = BookingDate(year: year, month: month, day: day);
            final isPast = date.isBefore(today);
            final isToday = date == today;
            final isStart = checkIn == date;
            final isEnd = checkOut == date;
            final isInRange = hasRange &&
                date.isAfter(checkIn!) &&
                date.isBefore(checkOut!);

            return InkWell(
              onTap: isPast ? null : () => onDayTapped(date),
              customBorder: const CircleBorder(),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (hasRange && (isInRange || isStart || isEnd))
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 3,
                          bottom: 3,
                          left: isStart ? 6 : 0,
                          right: isEnd ? 6 : 0,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.rangeBackground,
                            borderRadius: BorderRadius.horizontal(
                              left: isStart
                                  ? const Radius.circular(999)
                                  : Radius.zero,
                              right: isEnd
                                  ? const Radius.circular(999)
                                  : Radius.zero,
                            ),
                          ),
                        ),
                      ),
                    ),
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: (isStart || isEnd)
                            ? AppColors.primary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isToday && !(isStart || isEnd)
                            ? Border.all(color: AppColors.borderStrong)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: (isStart ||
                                    isEnd ||
                                    isInRange ||
                                    isToday)
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isPast
                                ? AppColors.textTertiary
                                : (isStart || isEnd)
                                    ? Colors.white
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceBase,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                          Text(
                            ref
                                .watch(moneyFormatterProvider)
                                .l10n
                                .fxPriceRangePerNight,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${ref.watch(moneyFormatterProvider).format(_priceRange.start.round(), context: MoneyDisplayContext.villaCard).formatted} - ${ref.watch(moneyFormatterProvider).format(_priceRange.end.round(), context: MoneyDisplayContext.villaCard).formatted}',
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
                        color:
                            value == count ? AppColors.primary : Colors.white,
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
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceBase,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
