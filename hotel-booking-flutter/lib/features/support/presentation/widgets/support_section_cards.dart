import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/entities/support_page_models.dart';

/// Thẻ hiển thị từng bước quy trình rõ ràng, tự động co giãn khi chữ phóng to.
class SupportStepTimelineCard extends StatelessWidget {
  final SupportStepItem step;

  const SupportStepTimelineCard({
    super.key,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${step.stepNumber}',
              style: AppTypography.cardTitle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 8),
                      child: Icon(
                        step.icon,
                        size: 18,
                        color: AppColors.iconStrong,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        step.title,
                        style: AppTypography.cardTitle.copyWith(
                          fontSize: 16,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  step.description,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ trình bày từng bậc chính sách hủy phòng (`flexible` / `moderate` / `strict`).
class CancellationPolicyTierCard extends StatelessWidget {
  final CancellationTierSpec tier;

  const CancellationPolicyTierCard({
    super.key,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                tier.name,
                style: AppTypography.cardTitle.copyWith(
                  fontSize: 16,
                  color: AppColors.textStrong,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: AppRadii.roundedPill,
                ),
                child: Text(
                  tier.summaryBadge,
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final rule in tier.rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      LucideIcons.check,
                      size: 16,
                      color: AppColors.iconStrong,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rule,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.48,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bảng câu hỏi thường gặp (FAQ) có ô tìm kiếm, chip lọc chủ đề và accordion đóng/mở chuẩn FLUTTER_RULES 8.2.
class SupportFaqAccordionPanel extends StatefulWidget {
  final List<String> categories;
  final List<FaqTopicItem> items;

  const SupportFaqAccordionPanel({
    super.key,
    required this.categories,
    required this.items,
  });

  @override
  State<SupportFaqAccordionPanel> createState() =>
      _SupportFaqAccordionPanelState();
}

class _SupportFaqAccordionPanelState extends State<SupportFaqAccordionPanel> {
  String _selectedCategory = '';
  final Set<String> _expandedIds = <String>{};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) {
      _selectedCategory = widget.categories.first;
    }
  }

  @override
  void didUpdateWidget(covariant SupportFaqAccordionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Giải thuật đồng bộ lại chip chủ đề đang chọn khi người dùng đổi ngôn ngữ giao diện:
    // Nếu nhãn danh mục cũ không còn nằm trong danh sách ngôn ngữ mới, tự động đưa về nhóm đầu tiên ("Tất cả").
    if (widget.categories.isNotEmpty &&
        !widget.categories.contains(_selectedCategory)) {
      _selectedCategory = widget.categories.first;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFaq(String id) {
    setState(() {
      if (!_expandedIds.remove(id)) {
        _expandedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeCategory =
        _selectedCategory.isEmpty && widget.categories.isNotEmpty
            ? widget.categories.first
            : _selectedCategory;
    final filtered = SupportPageResolver.filterFaqs(
      items: widget.items,
      selectedCategory: activeCategory,
      searchQuery: _searchController.text,
      allCategoryLabel: l10n.supportFaqCatAll,
    );
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('faq-search-input'),
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: l10n.supportFaqSearchHint,
            prefixIcon: const Icon(
              LucideIcons.search,
              size: 18,
              color: AppColors.iconMuted,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    tooltip: l10n.supportFaqClearSearchTooltip,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(
                      LucideIcons.x,
                      size: 18,
                      color: AppColors.iconStrong,
                    ),
                  )
                : null,
            border: const OutlineInputBorder(
              borderRadius: AppRadii.roundedPill,
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadii.roundedPill,
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppRadii.roundedPill,
              borderSide: BorderSide(color: AppColors.borderFocus, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: widget.categories.map((cat) {
            final isSelected = activeCategory == cat;
            return Semantics(
              button: true,
              selected: isSelected,
              child: InkWell(
                borderRadius: AppRadii.roundedPill,
                onTap: () => setState(() => _selectedCategory = cat),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.textStrong
                        : AppColors.surfaceBase,
                    borderRadius: AppRadii.roundedPill,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.textStrong
                          : AppColors.borderSoft,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: AppTypography.caption.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textStrong,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Text(
              l10n.supportFaqEmptyResult,
              style: AppTypography.bodyMuted.copyWith(height: 1.5),
            ),
          )
        else
          for (final item in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _FaqAccordionItemCard(
                item: item,
                isExpanded: _expandedIds.contains(item.id),
                disableAnimations: disableAnimations,
                onTap: () => _toggleFaq(item.id),
              ),
            ),
      ],
    );
  }
}

class _FaqAccordionItemCard extends StatelessWidget {
  final FaqTopicItem item;
  final bool isExpanded;
  final bool disableAnimations;
  final VoidCallback onTap;

  const _FaqAccordionItemCard({
    required this.item,
    required this.isExpanded,
    required this.disableAnimations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final animDuration =
        disableAnimations ? Duration.zero : const Duration(milliseconds: 200);

    return Semantics(
      button: true,
      toggled: isExpanded,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceBase,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              key: ValueKey('faq-item-${item.id}'),
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.question,
                          style: AppTypography.cardTitle.copyWith(
                            fontSize: 15,
                            color: AppColors.textStrong,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0.0,
                        duration: animDuration,
                        curve: Curves.easeOutCubic,
                        child: const Icon(
                          LucideIcons.chevronRight,
                          size: 18,
                          color: AppColors.iconStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: animDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(color: AppColors.borderSoft, height: 1),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            item.answer,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
