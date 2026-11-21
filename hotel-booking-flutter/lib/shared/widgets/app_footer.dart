import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../features/support/domain/services/contact_service.dart';
import '../../l10n/l10n.dart';
import 'app_semantic_icons.dart';

/// Chân trang (Footer) thống nhất toàn hệ thống The Palm Villa.
/// - Phân nhóm đúng ngữ nghĩa: Hỗ trợ, Khám phá & Dịch vụ, Liên hệ, Social.
/// - Mọi liên kết đều trỏ tới đúng trang đích nội bộ hoặc mở kênh ngoài an toàn có dự phòng sao chép.
/// - Khu vực Social chỉ hiển thị biểu tượng (icon-only) với vùng chạm chuẩn >= 48x48dp và Semantics/Tooltip.
class AppFooter extends StatelessWidget {
  /// Khởi tạo chân trang thống nhất cho các màn hình dành cho khách.
  const AppFooter({super.key});

  /// Địa chỉ hộp thư điện tử hỗ trợ khách hàng chính thức.
  static const String supportEmail = 'bookingvillavtdl@gmail.com';

  /// Địa chỉ văn phòng giao dịch chính thức tại TP. Vũng Tàu.
  static const String officeAddress = '28 Thi Sách, TP. Vũng Tàu';

  /// Đường dẫn tìm kiếm Google Maps trỏ tới địa chỉ văn phòng giao dịch.
  static const String officeMapUrl =
      'https://www.google.com/maps/search/?api=1&query=28%20Thi%20Sach%20Vung%20Tau';

  void _showFeedback(BuildContext context, String message) {
    if (!context.mounted || message.trim().isEmpty) return;
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

  Future<void> _openHttpsWithFallback(
    BuildContext context,
    String url, {
    String? fallbackText,
  }) async {
    final result = await ContactService.openExternalHttpsUrl(
      url,
      fallbackCopyText: fallbackText,
    );
    if (!result.launched && context.mounted) {
      _showFeedback(context, result.message);
    }
  }

  Future<void> _openHotlineWithFallback(
    BuildContext context,
    String hotline,
  ) async {
    final result = await ContactService.callHotlineDetailed(
      customNumber: hotline,
      rejectPlaceholder: false,
      copyOnPlaceholder: true,
    );
    if (!result.launched && context.mounted) {
      _showFeedback(context, result.message);
    }
  }

  Future<void> _openEmailWithFallback(BuildContext context) async {
    final subject = context.l10n.footerEmailSubject;
    final result = await ContactService.openEmailDetailed(
      supportEmail,
      subject: subject,
    );
    if (!result.launched && context.mounted) {
      _showFeedback(context, result.message);
    }
  }

  // Giải thuật tính toán số cột thích ứng theo chiều rộng khung nhìn (Responsive Column Allocation):
  // >= 960dp chia 4 cột ngang; >= 560dp chia 2 cột; < 560dp xếp 1 cột dọc toàn chiều rộng để tránh cắt chữ.
  static int resolveColumnCount(double maxWidth) {
    if (maxWidth >= 960) return 4;
    if (maxWidth >= 560) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = width >= 1024 ? 80.0 : (width >= 768 ? 24.0 : 16.0);
    final verifiedHotline = AppConfig.verifiedHotlineOrNull;

    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: EdgeInsets.fromLTRB(horizontalPad, 40, horizontalPad, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = resolveColumnCount(constraints.maxWidth);
                  final colWidth =
                      (constraints.maxWidth - ((cols - 1) * 32)) / cols;

                  return Wrap(
                    spacing: 32,
                    runSpacing: 32,
                    children: [
                      SizedBox(
                        width: colWidth,
                        child: _FooterColumn(
                          title: l10n.footerSupportTitle,
                          links: [
                            (
                              l10n.footerLinkBookingGuide,
                              () => context.push('/ho-tro/huong-dan-dat-phong'),
                            ),
                            (
                              l10n.footerLinkCancellationPolicy,
                              () =>
                                  context.push('/ho-tro/chinh-sach-huy-phong'),
                            ),
                            (
                              l10n.footerLinkComplaintsFeedback,
                              () => context.push('/ho-tro/khieu-nai-gop-y'),
                            ),
                            (
                              l10n.footerLinkFaq,
                              () => context.push('/ho-tro/cau-hoi-thuong-gap'),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: colWidth,
                        child: _FooterColumn(
                          title: l10n.footerExploreTitle,
                          links: [
                            (
                              l10n.footerLinkAboutUs,
                              () => context.push('/ve-chung-toi'),
                            ),
                            (
                              l10n.footerLinkExploreVungTau,
                              () => context.push('/kham-pha-vung-tau'),
                            ),
                            (
                              l10n.footerLinkTravelGuide,
                              () => context.push('/cam-nang'),
                            ),
                            (
                              l10n.footerLinkAddonServices,
                              () => context.push('/dich-vu-di-kem'),
                            ),
                            (
                              l10n.footerLinkMemberOffers,
                              () => context.push('/uu-dai-thanh-vien'),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: colWidth,
                        child: _FooterColumn(
                          title: l10n.footerContactTitle,
                          links: [
                            if (verifiedHotline != null)
                              (
                                l10n.footerHotlineLabel(
                                  ContactService.formatDisplayPhone(
                                    verifiedHotline,
                                  ),
                                ),
                                () => _openHotlineWithFallback(
                                      context,
                                      verifiedHotline,
                                    ),
                              ),
                            (
                              l10n.footerOnlineConsultLink,
                              () => context.push('/lien-he'),
                            ),
                            (
                              l10n.footerAddressLabel(officeAddress),
                              () => _openHttpsWithFallback(
                                    context,
                                    officeMapUrl,
                                    fallbackText: officeAddress,
                                  ),
                            ),
                            (
                              l10n.footerEmailLabel(supportEmail),
                              () => _openEmailWithFallback(context),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: colWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.footerSocialTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _SocialIconOnlyButton(
                                  buttonKey:
                                      const ValueKey('footer-social-facebook'),
                                  tooltip: 'Facebook',
                                  icon: const AppBrandIcon.facebook(
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  onTap: () => _openHttpsWithFallback(
                                    context,
                                    'https://www.facebook.com/villavungtauuytin',
                                  ),
                                ),
                                _SocialIconOnlyButton(
                                  buttonKey:
                                      const ValueKey('footer-social-threads'),
                                  tooltip: 'Threads',
                                  icon: const AppBrandIcon.threads(
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  onTap: () => _openHttpsWithFallback(
                                    context,
                                    'https://www.threads.com/athanhnee',
                                  ),
                                ),
                                _SocialIconOnlyButton(
                                  buttonKey:
                                      const ValueKey('footer-social-tiktok'),
                                  tooltip: 'TikTok',
                                  icon: const AppBrandIcon.tiktok(
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  onTap: () => _openHttpsWithFallback(
                                    context,
                                    'https://www.tiktok.com/@minhthanh.villavungtau',
                                  ),
                                ),
                                _SocialIconOnlyButton(
                                  buttonKey:
                                      const ValueKey('footer-social-youtube'),
                                  tooltip: 'YouTube',
                                  icon: const AppBrandIcon.youtube(
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  onTap: () => _openHttpsWithFallback(
                                    context,
                                    'https://www.youtube.com/@VillaVungTau-MinhThanh',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 48),
              const Divider(color: Color(0xFF374151), height: 1),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  l10n.footerCopyright,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<(String, VoidCallback)> links;

  const _FooterColumn({
    required this.title,
    required this.links,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        for (final item in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              onTap: item.$2,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.$1,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SocialIconOnlyButton extends StatelessWidget {
  final Key? buttonKey;
  final Widget icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SocialIconOnlyButton({
    this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          key: buttonKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: icon,
          ),
        ),
      ),
    );
  }
}
