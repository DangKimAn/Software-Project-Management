import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/date/booking_date.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../villas/domain/entities/villa.dart';
import '../../../villas/presentation/widgets/property_specs_row.dart';

/// Complete port of `Source goc/frontend/src/views/pages/AiSearch/AiSearchPage.tsx`.
class AiSearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const AiSearchScreen({
    super.key,
    this.initialQuery,
  });

  @override
  ConsumerState<AiSearchScreen> createState() => _AiSearchScreenState();
}

class _AiSearchScreenState extends ConsumerState<AiSearchScreen> {
  /// Exact 8 `SUGGESTION_QUERIES` from `AiSearchPage.tsx:8-17`.
  static const List<String> suggestionQueries = [
    'villa sát biển Bãi Sau có hồ bơi cho 6 người từ 18/4 đến 20/4',
    'homestay yên tĩnh gần biển tầm 1-2 triệu cuối tuần này',
    'chỗ ở lãng mạn cho cặp đôi có bồn tắm và ban công nhìn biển',
    'căn hộ gia đình 4 người gần trung tâm có bếp và chỗ đậu xe',
    'villa cho nhóm 10 người có BBQ, hồ bơi riêng ở Bãi Trước',
    'nhà nghỉ giá tốt gần Thùy Vân đi bộ ra biển',
    'chỗ nghỉ pet friendly có sân vườn cho gia đình nhỏ',
    'villa view biển đẹp cho kỳ nghỉ 3 ngày 2 đêm',
  ];

  late final TextEditingController _queryCtrl;
  int _topK = 12;
  bool _isLoading = false;
  String? _error;
  SemanticSearchResponse? _response;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(preferencesServiceProvider).getLastAiSearchQuery();
    final initial =
        (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty)
            ? widget.initialQuery!.trim()
            : saved;
    _queryCtrl = TextEditingController(text: initial);
    if (initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch());
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AiSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextQuery = widget.initialQuery?.trim() ?? '';
    if (nextQuery.isNotEmpty &&
        nextQuery != (oldWidget.initialQuery?.trim() ?? '')) {
      _queryCtrl.text = nextQuery;
      _runSearch();
    }
  }

  Future<void> _runSearch([String? customQuery]) async {
    final q = (customQuery ?? _queryCtrl.text).trim();
    if (customQuery != null) {
      _queryCtrl.text = q;
    }
    if (q.isEmpty) {
      setState(
          () => _error = 'Vui lòng nhập mô tả nhu cầu lưu trú để tìm kiếm.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await ref.read(preferencesServiceProvider).setLastAiSearchQuery(q);
    try {
      final res = await ref
          .read(villaRepositoryProvider)
          .semanticSearch(query: q, topK: _topK);
      if (mounted) {
        setState(() {
          _response = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _openNormalSearch() {
    final q = _queryCtrl.text.trim();
    final dateIntent = _response?.dateIntent;
    final parsedCheckIn = dateIntent?.checkIn != null
        ? BookingDate.tryParseIso(dateIntent!.checkIn!)
        : null;
    final parsedCheckOut = dateIntent?.checkOut != null
        ? BookingDate.tryParseIso(dateIntent!.checkOut!)
        : null;

    ref.read(villaFilterProvider.notifier).update(
          (s) => s.copyWith(
            searchQuery: q,
            checkIn: parsedCheckIn ?? s.checkIn,
            checkOut: parsedCheckOut ?? s.checkOut,
            page: 1,
          ),
        );
    context.push('/tim-kiem');
  }

  void _openListingDetail(Villa villa) {
    final dateIntent = _response?.dateIntent;
    final parsedCheckIn = dateIntent?.checkIn != null
        ? BookingDate.tryParseIso(dateIntent!.checkIn!)
        : null;
    final parsedCheckOut = dateIntent?.checkOut != null
        ? BookingDate.tryParseIso(dateIntent!.checkOut!)
        : null;

    if (parsedCheckIn != null && parsedCheckOut != null) {
      ref.read(villaFilterProvider.notifier).update(
            (s) => s.copyWith(
              checkIn: parsedCheckIn,
              checkOut: parsedCheckOut,
            ),
          );
    }
    context.push('/villa/${villa.id}');
  }

  String _roomTypeVi(String? type) {
    switch (type) {
      case 'bedroom':
        return 'Phòng ngủ';
      case 'living_room':
        return 'Phòng khách';
      case 'kitchen':
        return 'Phòng bếp';
      case 'bathroom':
        return 'Phòng tắm';
      case 'pool':
        return 'Hồ bơi';
      case 'exterior':
        return 'Ngoại thất';
      case 'view':
        return 'Tầm nhìn';
      case 'dining':
        return 'Phòng ăn';
      default:
        return type ?? 'Đa không gian';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const AppTopHeader(currentPath: '/ai-search'),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceBase,
                      border: Border(
                        bottom: BorderSide(color: AppColors.borderSoft),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 36,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  LucideIcons.search,
                                  size: 20,
                                  color: AppColors.iconStrong,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'AI VISUAL & SEMANTIC SEARCH (CLIP + QDRANT)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tìm chỗ nghỉ bằng ngôn ngữ tự nhiên',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Mô tả nhu cầu thực tế của bạn bằng một câu hoàn chỉnh: đi mấy người, thích khu nào, cần tiện nghi gì, ngân sách khoảng bao nhiêu hoặc đi ngày nào.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: _queryCtrl,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Ví dụ: villa sát biển Bãi Sau có hồ bơi cho 6 người từ 18/4 đến 20/4...',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                    ),
                                    onSubmitted: (_) => _runSearch(),
                                  ),
                                  const Divider(
                                    height: 16,
                                    color: AppColors.divider,
                                  ),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 10,
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          const Text(
                                            'Số kết quả tối đa:',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          for (final k in const [3, 6, 9, 12])
                                            ChoiceChip(
                                              showCheckmark: false,
                                              selectedColor: AppColors.primary,
                                              label: Text(
                                                '$k',
                                                style: TextStyle(
                                                  fontWeight: _topK == k
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: _topK == k
                                                      ? Colors.white
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                              selected: _topK == k,
                                              onSelected: (_) =>
                                                  setState(() => _topK = k),
                                            ),
                                        ],
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: _isLoading
                                            ? null
                                            : () => _runSearch(),
                                        icon: const Icon(
                                          LucideIcons.search,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        label: Text(
                                          _isLoading
                                              ? 'Đang phân tích AI...'
                                              : 'Tìm với AI',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(120, 48),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: suggestionQueries.map((prompt) {
                                return ActionChip(
                                  label: Text(
                                    prompt,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () => _runSearch(prompt),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Results Section
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _buildResultsBody(context),
                      ),
                    ),
                  ),

                  const AppFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsBody(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return AppErrorView(
        message: _error!,
        onRetry: _runSearch,
      );
    }

    if (_response == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: AppEmptyView(
          title: 'Nhập mô tả để bắt đầu tìm kiếm AI',
          description:
              'Chọn một gợi ý phía trên hoặc nhập mô tả chi tiết về không gian phòng bạn yêu thích.',
        ),
      );
    }

    final response = _response!;
    final items = response.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Summary + Normal Search Handoff (`AiSearchPage.tsx:206-243`)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KẾT QUẢ ĐỀ XUẤT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        response.isRejected
                            ? 'Truy vấn cần mô tả rõ hơn'
                            : 'Tìm thấy ${items.length} chỗ nghỉ phù hợp',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (_queryCtrl.text.trim().isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _openNormalSearch,
                      icon: const Icon(
                        LucideIcons.arrowRight,
                        size: 15,
                        color: AppColors.iconStrong,
                      ),
                      label: const Text('Chuyển sang tìm kiếm thường'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(120, 48),
                      ),
                    ),
                ],
              ),
              if (response.dateIntent?.checkIn != null &&
                  response.dateIntent?.checkOut != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.calendar,
                      size: 15,
                      color: AppColors.iconStrong,
                    ),
                    Text(
                      'Lịch trống áp dụng: ${response.dateIntent!.label ?? '${response.dateIntent!.checkIn} → ${response.dateIntent!.checkOut}'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
              if (response.availabilityNotice != null &&
                  response.availabilityNotice!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          LucideIcons.calendar,
                          size: 16,
                          color: AppColors.iconStrong,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          response.availabilityNotice!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        if (response.detectedRoomType != null &&
            response.detectedRoomType!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.bedDouble,
                  size: 16,
                  color: AppColors.iconStrong,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'AI nhận diện loại phòng ưu tiên: ${_roomTypeVi(response.detectedRoomType)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Rejected or Empty State (`AiSearchPage.tsx:321-355`)
        if (items.isEmpty)
          _buildRejectionCard(context, response)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 960
                  ? 3
                  : (constraints.maxWidth >= 640 ? 2 : 1);
              const gap = 20.0;
              final cardWidth =
                  (constraints.maxWidth - gap * (cols - 1)) / cols;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: items.map((villa) {
                  return SizedBox(
                    width: cardWidth,
                    child: _buildAiResultCard(context, villa),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRejectionCard(
    BuildContext context,
    SemanticSearchResponse response,
  ) {
    final copy = AiSearchRejectionCopy.resolve(
      response.reason,
      response.message,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  LucideIcons.circleAlert,
                  size: 22,
                  color: AppColors.iconStrong,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      copy.description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GỢI Ý CẢI THIỆN TRUY VẤN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final tip in copy.tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $tip',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestionQueries.take(4).map((sample) {
              return ActionChip(
                label: Text(
                  sample,
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () => _runSearch(sample),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAiResultCard(BuildContext context, Villa villa) {
    final imgUrl = villa.matchedImageUrl?.isNotEmpty == true
        ? villa.matchedImageUrl!
        : (villa.imageUrls.isNotEmpty
            ? villa.imageUrls.first
            : 'assets/images/NDT05929-HDR1.jpg');
    final scorePct = villa.similarityScore != null
        ? (villa.similarityScore! * 100).clamp(1, 99).round()
        : null;

    return InkWell(
      onTap: () => _openListingDetail(villa),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: AppImage(url: imgUrl, fit: BoxFit.cover),
                ),
                if (scorePct != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Độ khớp AI: $scorePct%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (villa.matchedRoomType != null)
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _roomTypeVi(villa.matchedRoomType),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    villa.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.mapPin,
                        size: 13,
                        color: AppColors.iconMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          villa.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  PropertySpecsRow(
                    specs: villa.specs,
                    showBeachDistance: false,
                  ),
                  if (villa.matchedReasons.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: villa.matchedReasons.take(4).map((reason) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            reason,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${CurrencyFormatter.formatVnd(villa.basePriceVnd ?? 0)} / đêm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.star,
                            size: 14,
                            color: AppColors.iconStrong,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            villa.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
