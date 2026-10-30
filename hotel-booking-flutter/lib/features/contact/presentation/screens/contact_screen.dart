import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../blog/presentation/screens/blog_screen.dart';
import '../../../booking_inquiry/domain/services/contact_service.dart';

/// Port of `Source goc/frontend/src/views/pages/Contact/ContactPage.tsx`
/// adhering to The Palm Light Luxury Design System (FLUTTER_RULES.md):
/// - Validates Hotline & Zalo OA from [AppConfig] and never claims sample/example numbers (`0901234567`) are real.
/// - `tel:` launcher falls back to copying the phone number to clipboard when dialer cannot open.
/// - Zalo OA only opens verified official `https://zalo.me/...` / `https://oa.zalo.me/...` URLs without pretending
///   to auto-fill message text.
class ContactScreen extends StatefulWidget {
  final String? hotlineOverride;
  final String? zaloOaUrlOverride;

  const ContactScreen({
    super.key,
    this.hotlineOverride,
    this.zaloOaUrlOverride,
  });

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  String get _effectiveHotline =>
      (widget.hotlineOverride ?? AppConfig.hotlineNumber).trim();

  String get _effectiveZaloUrl =>
      (widget.zaloOaUrlOverride ?? AppConfig.zaloOaUrl).trim();

  void _showStatusSnackBar(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _handleCallHotline() async {
    final result = await ContactService.callHotlineDetailed(
      customNumber: _effectiveHotline,
      rejectPlaceholder: false,
      copyOnPlaceholder: true,
    );
    if (!mounted) return;
    _showStatusSnackBar(result.message);
  }

  Future<void> _handleCopyHotline() async {
    final clean = ContactService.normalizePhone(_effectiveHotline);
    final copied = await ContactService.copyTextToClipboard(clean);
    if (!mounted) return;
    final msg = copied
        ? 'Đã sao chép số hotline ${ContactService.formatDisplayPhone(clean)} vào bộ nhớ tạm.'
        : 'Không thể sao chép số hotline trên thiết bị này.';
    _showStatusSnackBar(msg);
  }

  Future<void> _handleOpenZalo() async {
    final result = await ContactService.openZaloInquiryDetailed(
      customZaloUrl: _effectiveZaloUrl,
      rejectPlaceholder: false,
    );
    if (!mounted) return;
    _showStatusSnackBar(result.message);
  }

  Future<void> _handleOpenOfficeMap() async {
    final result = await ContactService.openExternalHttpsUrl(
      'https://www.google.com/maps/search/?api=1&query=28%20Thi%20Sach%20Vung%20Tau',
      fallbackCopyText: '28 Thi Sách, TP. Vũng Tàu',
    );
    if (!mounted) return;
    _showStatusSnackBar(result.message);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1024;
    final horizontalPad = width >= 640
        ? AppSpacing.xl
        : (width < 360 ? AppSpacing.sm : AppSpacing.md);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopHeader(currentPath: '/lien-he'),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Column(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPad,
                            isDesktop ? AppSpacing.xxl : AppSpacing.lg,
                            horizontalPad,
                            AppSpacing.xxl,
                          ),
                          child: isDesktop
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 105,
                                      child: _buildHeroInfo(context),
                                    ),
                                    const SizedBox(width: AppSpacing.xxl),
                                    Expanded(
                                      flex: 95,
                                      child: _buildHeroImage(),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildHeroInfo(context),
                                    const SizedBox(height: AppSpacing.lg),
                                    _buildHeroImage(),
                                  ],
                                ),
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
      ),
    );
  }

  Widget _buildHeroInfo(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hotlineVerified = ContactService.isVerifiedHotline(_effectiveHotline);
    final hotlineValidFormat =
        ContactService.isValidPhoneFormat(_effectiveHotline);
    final zaloVerified = ContactService.isVerifiedZaloUrl(_effectiveZaloUrl);
    final normalizedZaloUri =
        ContactService.parseAndValidateZaloUri(_effectiveZaloUrl);

    final formattedPhone = ContactService.formatDisplayPhone(_effectiveHotline);
    final hotlineDisplayValue =
        hotlineValidFormat ? formattedPhone : 'Chưa cấu hình số hotline';

    final zaloDisplayValue = normalizedZaloUri != null
        ? '${normalizedZaloUri.host}/${normalizedZaloUri.pathSegments.first}'
        : 'Chưa cấu hình Zalo OA';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'LIÊN HỆ THE PALM VILLA',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: AppColors.primary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push('/tim-kiem'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textStrong,
                minimumSize: const Size(48, 36),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              ),
              icon: const Icon(
                LucideIcons.search,
                size: 14,
                color: AppColors.iconStrong,
              ),
              label: Text(
                'Xem villa',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textStrong,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Liên hệ & Hỗ trợ đặt phòng',
          style: AppTypography.displayLarge.copyWith(
            fontSize: screenWidth < 360 ? 22 : 26,
            color: AppColors.textStrong,
            height: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Kết nối nhanh qua Hotline, Zalo OA hoặc ghé trực tiếp văn phòng tại Vũng Tàu (08:00 – 22:00).',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Column(
          children: [
            _ContactChannelCard(
              cardKey: const ValueKey('contact-card-hotline'),
              primaryActionKey: const ValueKey('contact-call-hotline-btn'),
              icon: LucideIcons.phone,
              title: 'Hotline tư vấn',
              value: hotlineDisplayValue,
              badgeText: hotlineVerified ? 'Đã xác minh cấu hình' : null,
              isVerified: hotlineVerified,
              primaryActionLabel: 'Gọi ngay',
              onPrimaryTap: _handleCallHotline,
              trailingIconButton: AppIconButton(
                key: const ValueKey('contact-copy-hotline-btn'),
                tooltip: 'Sao chép số hotline',
                icon: const Icon(
                  LucideIcons.copy,
                  size: 17,
                  color: AppColors.iconStrong,
                ),
                onPressed: _handleCopyHotline,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ContactChannelCard(
              cardKey: const ValueKey('contact-card-zalo'),
              primaryActionKey: const ValueKey('contact-card-zalo-btn'),
              icon: LucideIcons.messageCircle,
              title: 'Zalo OA',
              value: zaloDisplayValue,
              badgeText: zaloVerified ? 'Đã xác minh cấu hình' : null,
              isVerified: zaloVerified,
              primaryActionLabel: 'Mở Zalo OA',
              onPrimaryTap: _handleOpenZalo,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ContactChannelCard(
              cardKey: const ValueKey('contact-card-address'),
              primaryActionKey: const ValueKey('contact-card-map-btn'),
              icon: LucideIcons.mapPin,
              title: 'Văn phòng Vũng Tàu',
              value: '28 Thi Sách, TP. Vũng Tàu',
              badgeText: '08:00 – 22:00',
              isVerified: true,
              primaryActionLabel: 'Bản đồ',
              onPrimaryTap: _handleOpenOfficeMap,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroImage() {
    return const BlogCoverImage(
      rawUrl: 'assets/images/NDT05929-HDR1.jpg',
      aspectRatio: 16 / 9,
      borderRadius: AppRadii.roundedCard,
    );
  }
}

class _ContactChannelCard extends StatelessWidget {
  final Key? cardKey;
  final Key? primaryActionKey;
  final IconData icon;
  final String title;
  final String value;
  final String? badgeText;
  final bool isVerified;
  final String primaryActionLabel;
  final VoidCallback onPrimaryTap;
  final Widget? trailingIconButton;

  const _ContactChannelCard({
    this.cardKey,
    this.primaryActionKey,
    required this.icon,
    required this.title,
    required this.value,
    this.badgeText,
    required this.isVerified,
    required this.primaryActionLabel,
    required this.onPrimaryTap,
    this.trailingIconButton,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14.0;
    return Container(
      key: cardKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isHorizontal = constraints.maxWidth >= 360 && textScale <= 1.25;

          final infoContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTypography.cardTitle.copyWith(
                      fontSize: 15,
                      color: AppColors.textStrong,
                    ),
                  ),
                  if (badgeText != null && badgeText!.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBase,
                        borderRadius: AppRadii.roundedPill,
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Text(
                        badgeText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: AppTypography.bodyMuted.copyWith(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );

          final actionButton = OutlinedButton(
            key: primaryActionKey,
            onPressed: onPrimaryTap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: const StadiumBorder(),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Text(
              primaryActionLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          );

          if (isHorizontal) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: AppColors.iconStrong,
                ),
                const SizedBox(width: 14),
                Expanded(child: infoContent),
                const SizedBox(width: 10),
                if (trailingIconButton != null) ...[
                  trailingIconButton!,
                  const SizedBox(width: 4),
                ],
                actionButton,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      icon,
                      size: 20,
                      color: AppColors.iconStrong,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: infoContent),
                  if (trailingIconButton != null) trailingIconButton!,
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: actionButton,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Port of `NotFoundPage.tsx` (kept backward-compatible for any direct imports).
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopHeader(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBase,
                        borderRadius: AppRadii.roundedCard,
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.compass,
                            size: 32,
                            color: AppColors.iconMuted,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            '404 — KHÔNG TÌM THẤY TRANG',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Xin lỗi, chúng tôi không tìm thấy trang bạn cần.',
                            textAlign: TextAlign.center,
                            style: AppTypography.displayMedium.copyWith(
                              color: AppColors.textStrong,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Liên kết này có thể đã thay đổi hoặc không còn tồn tại. Bạn có thể quay về trang chủ hoặc tiếp tục khám phá các chỗ ở đang mở.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMuted.copyWith(
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton(
                                onPressed: () => context.go('/'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(48, 48),
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xl,
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text('Về trang chủ'),
                              ),
                              OutlinedButton(
                                onPressed: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/');
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  shape: const StadiumBorder(),
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xl,
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text('Quay lại trang trước'),
                              ),
                            ],
                          ),
                        ],
                      ),
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
}
