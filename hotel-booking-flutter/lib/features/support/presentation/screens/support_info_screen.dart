import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../domain/entities/support_page_models.dart';
import '../../domain/support_catalog.dart';
import '../widgets/support_api_forms.dart';
import '../widgets/support_interactive_panels.dart';
import '../widgets/support_page_shell.dart';
import '../widgets/support_section_cards.dart';

/// Màn hình đích thống nhất cho các mục Hỗ trợ, Chính sách, Giới thiệu & Khám phá từ Footer.
class SupportInfoScreen extends StatelessWidget {
  final SupportPageType pageType;

  const SupportInfoScreen({
    super.key,
    required this.pageType,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    switch (pageType) {
      case SupportPageType.bookingGuide:
        return SupportPageShell(
          currentPath: '/ho-tro/huong-dan-dat-phong',
          eyebrow: l10n.supportBookingGuideEyebrow,
          title: l10n.supportBookingGuideTitle,
          subtitle: l10n.supportBookingGuideSubtitle,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final step in SupportCatalog.bookingGuideStepsOf(l10n)) ...[
                SupportStepTimelineCard(step: step),
                const SizedBox(height: AppSpacing.md),
              ],
              _InfoHighlightNote(
                icon: LucideIcons.info,
                title: l10n.supportBookingGuideNoteTitle,
                content: l10n.supportBookingGuideNoteBody,
              ),
            ],
          ),
          ctaTitle: l10n.supportBookingGuideCtaTitle,
          ctaDescription: l10n.supportBookingGuideCtaDesc,
          primaryActionLabel: l10n.supportBookingGuidePrimaryAction,
          onPrimaryAction: () => context.push('/tim-kiem'),
          secondaryActionLabel: l10n.supportBookingGuideSecondaryAction,
          onSecondaryAction: () => context.push('/lien-he'),
        );

      case SupportPageType.cancellationPolicy:
        return SupportPageShell(
          currentPath: '/ho-tro/chinh-sach-huy-phong',
          eyebrow: l10n.supportCancelEyebrow,
          title: l10n.supportCancelTitle,
          subtitle: l10n.supportCancelSubtitle,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final tier in SupportCatalog.cancellationTiersOf(l10n)) ...[
                CancellationPolicyTierCard(tier: tier),
                const SizedBox(height: AppSpacing.md),
              ],
              _InfoHighlightNote(
                icon: LucideIcons.shieldCheck,
                title: l10n.supportCancelHostProtectTitle,
                content: l10n.supportCancelHostProtectBody,
              ),
            ],
          ),
          ctaTitle: l10n.supportCancelCtaTitle,
          ctaDescription: l10n.supportCancelCtaDesc,
          primaryActionLabel: l10n.supportCancelPrimaryAction,
          onPrimaryAction: () => context.go('/account/trips'),
          secondaryActionLabel: l10n.supportCancelSecondaryAction,
          onSecondaryAction: () => context.push('/ho-tro/cau-hoi-thuong-gap'),
        );

      case SupportPageType.complaintsFeedback:
        return SupportPageShell(
          currentPath: '/ho-tro/khieu-nai-gop-y',
          eyebrow: l10n.supportComplaintsEyebrow,
          title: l10n.supportComplaintsTitle,
          subtitle: l10n.supportComplaintsSubtitle,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final step
                  in SupportCatalog.complaintProcessStepsOf(l10n)) ...[
                SupportStepTimelineCard(step: step),
                const SizedBox(height: AppSpacing.md),
              ],
              const SizedBox(height: AppSpacing.sm),
              const FeedbackReportFormCard(),
            ],
          ),
          ctaTitle: l10n.supportComplaintsCtaTitle,
          ctaDescription: l10n.supportComplaintsCtaDesc,
          primaryActionLabel: l10n.supportComplaintsPrimaryAction,
          onPrimaryAction: () => context.push('/lien-he'),
          secondaryActionLabel: l10n.supportComplaintsSecondaryAction,
          onSecondaryAction: () => context.go('/messages'),
        );

      case SupportPageType.faq:
        return SupportPageShell(
          currentPath: '/ho-tro/cau-hoi-thuong-gap',
          eyebrow: l10n.supportFaqEyebrow,
          title: l10n.supportFaqPageTitle,
          subtitle: l10n.supportFaqSubtitle,
          body: SupportFaqAccordionPanel(
            categories: SupportCatalog.faqCategoriesOf(l10n),
            items: SupportCatalog.faqItemsOf(l10n),
          ),
          ctaTitle: l10n.supportFaqCtaTitle,
          ctaDescription: l10n.supportFaqCtaDesc,
          primaryActionLabel: l10n.supportFaqPrimaryAction,
          onPrimaryAction: () => context.push('/lien-he'),
          secondaryActionLabel: l10n.supportFaqSecondaryAction,
          onSecondaryAction: () => context.push('/ho-tro/huong-dan-dat-phong'),
        );

      case SupportPageType.aboutUs:
        return SupportPageShell(
          currentPath: '/ve-chung-toi',
          eyebrow: l10n.supportAboutEyebrow,
          title: l10n.supportAboutTitle,
          subtitle: l10n.supportAboutSubtitle,
          body: const _AboutUsContentBody(),
          ctaTitle: l10n.supportAboutCtaTitle,
          ctaDescription: l10n.supportAboutCtaDesc,
          primaryActionLabel: l10n.supportAboutPrimaryAction,
          onPrimaryAction: () => context.push('/tim-kiem'),
          secondaryActionLabel: l10n.supportAboutSecondaryAction,
          onSecondaryAction: () => context.push('/tro-thanh-host'),
        );

      case SupportPageType.exploreVungTau:
        return SupportPageShell(
          currentPath: '/kham-pha-vung-tau',
          eyebrow: l10n.supportExploreVtEyebrow,
          title: l10n.supportExploreVtTitle,
          subtitle: l10n.supportExploreVtSubtitle,
          body: VungTauZoneExplorerGrid(
            zones: SupportCatalog.vungTauZonesOf(l10n),
          ),
          ctaTitle: l10n.supportExploreVtCtaTitle,
          ctaDescription: l10n.supportExploreVtCtaDesc,
          primaryActionLabel: l10n.supportExploreVtPrimaryAction,
          onPrimaryAction: () => context.push('/cam-nang'),
          secondaryActionLabel: l10n.supportExploreVtSecondaryAction,
          onSecondaryAction: () => context.push('/tim-kiem'),
        );

      case SupportPageType.addonServices:
        return SupportPageShell(
          currentPath: '/dich-vu-di-kem',
          eyebrow: l10n.supportAddonEyebrow,
          title: l10n.supportAddonTitle,
          subtitle: l10n.supportAddonSubtitle,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AddonServiceExplorerGrid(
                services: SupportCatalog.addonServicesOf(l10n),
              ),
              const SizedBox(height: AppSpacing.lg),
              _InfoHighlightNote(
                icon: LucideIcons.messageSquare,
                title: l10n.supportAddonNoteTitle,
                content: l10n.supportAddonNoteBody,
              ),
            ],
          ),
          ctaTitle: l10n.supportAddonCtaTitle,
          ctaDescription: l10n.supportAddonCtaDesc,
          primaryActionLabel: l10n.supportAddonPrimaryAction,
          onPrimaryAction: () => context.push('/tim-kiem'),
          secondaryActionLabel: l10n.supportAddonSecondaryAction,
          onSecondaryAction: () => context.push('/lien-he'),
        );

      case SupportPageType.memberOffers:
        return SupportPageShell(
          currentPath: '/uu-dai-thanh-vien',
          eyebrow: l10n.supportMemberEyebrow,
          title: l10n.supportMemberTitle,
          subtitle: l10n.supportMemberSubtitle,
          body: const _MemberOffersContentBody(),
          ctaTitle: l10n.supportMemberCtaTitle,
          ctaDescription: l10n.supportMemberCtaDesc,
          primaryActionLabel: l10n.supportMemberPrimaryAction,
          onPrimaryAction: () => context.push('/tim-kiem'),
          secondaryActionLabel: l10n.supportMemberSecondaryAction,
          onSecondaryAction: () => context.push('/yeu-thich'),
        );
    }
  }
}

class _AboutUsContentBody extends StatelessWidget {
  const _AboutUsContentBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pillars = <(IconData, String, String)>[
      (
        LucideIcons.badgeCheck,
        l10n.supportAboutPillar1Title,
        l10n.supportAboutPillar1Body,
      ),
      (
        LucideIcons.lock,
        l10n.supportAboutPillar2Title,
        l10n.supportAboutPillar2Body,
      ),
      (
        LucideIcons.receiptText,
        l10n.supportAboutPillar3Title,
        l10n.supportAboutPillar3Body,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ClipRRect(
          borderRadius: AppRadii.roundedCard,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: AppImage(
              url: 'assets/images/NDT05929-HDR1.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final p in pillars) ...[
          _InfoHighlightNote(
            icon: p.$1,
            title: p.$2,
            content: p.$3,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _MemberOffersContentBody extends StatelessWidget {
  const _MemberOffersContentBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoHighlightNote(
          icon: LucideIcons.ticket,
          title: l10n.supportMemberNote1Title,
          content: l10n.supportMemberNote1Body,
        ),
        const SizedBox(height: AppSpacing.md),
        _InfoHighlightNote(
          icon: LucideIcons.heart,
          title: l10n.supportMemberNote2Title,
          content: l10n.supportMemberNote2Body,
        ),
        const SizedBox(height: AppSpacing.lg),
        const MemberCouponCheckerCard(),
      ],
    );
  }
}

class _InfoHighlightNote extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _InfoHighlightNote({
    required this.icon,
    required this.title,
    required this.content,
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
          Icon(icon, size: 20, color: AppColors.iconStrong),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 16,
                    color: AppColors.textStrong,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  content,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.52,
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
