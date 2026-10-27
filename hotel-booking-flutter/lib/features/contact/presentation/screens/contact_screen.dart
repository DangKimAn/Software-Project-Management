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

/// Payload for consultation inquiry / draft creation.
class ContactInquiryPayload {
  final String fullName;
  final String phone;
  final String email;
  final String topic;
  final String message;
  final bool userConsented;

  const ContactInquiryPayload({
    required this.fullName,
    required this.phone,
    required this.email,
    required this.topic,
    required this.message,
    required this.userConsented,
  });
}

/// Port of `Source goc/frontend/src/views/pages/Contact/ContactPage.tsx`
/// adhering to The Palm Light Luxury Design System (FLUTTER_RULES.md):
/// - Validates Hotline & Zalo OA from [AppConfig] and never claims sample/example numbers (`0901234567`) are real.
/// - `tel:` launcher falls back to copying the phone number to clipboard when dialer cannot open.
/// - Zalo OA only opens verified official `https://zalo.me/...` / `https://oa.zalo.me/...` URLs without pretending
///   to auto-fill message text.
/// - When no backend contact submission endpoint is configured, provides a consent-based Consultation Draft Builder
///   to copy/share without ever faking server submission success.
class ContactScreen extends StatefulWidget {
  final String? hotlineOverride;
  final String? zaloOaUrlOverride;
  final Future<void> Function(ContactInquiryPayload payload)?
      onSubmitInquiryEndpoint;

  const ContactScreen({
    super.key,
    this.hotlineOverride,
    this.zaloOaUrlOverride,
    this.onSubmitInquiryEndpoint,
  });

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  static const List<String> _supportTopics = [
    'Tư vấn chọn villa theo số khách',
    'Kiểm tra lịch trống và giá theo ngày',
    'Hỗ trợ thanh toán hoặc đổi lịch',
    'Góp ý trải nghiệm lưu trú',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  String _selectedTopic = _supportTopics.first;
  bool _userConsented = false;
  bool _isSubmitting = false;

  String _generatedDraft = '';
  String _feedbackBannerMessage = '';
  bool _isFeedbackError = false;

  String get _effectiveHotline =>
      (widget.hotlineOverride ?? AppConfig.hotlineNumber).trim();

  String get _effectiveZaloUrl =>
      (widget.zaloOaUrlOverride ?? AppConfig.zaloOaUrl).trim();

  bool get _hasRealEndpoint => widget.onSubmitInquiryEndpoint != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

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
      rejectPlaceholder: true,
      copyOnPlaceholder: false,
    );
    if (!mounted) return;
    setState(() {
      _feedbackBannerMessage = result.message;
      _isFeedbackError =
          result.status == ContactActionStatus.unverifiedConfig ||
              result.status == ContactActionStatus.invalidInput ||
              result.status == ContactActionStatus.failed;
    });
    _showStatusSnackBar(result.message);
  }

  Future<void> _handleCopyHotline() async {
    if (!ContactService.isVerifiedHotline(_effectiveHotline)) {
      const msg =
          'Số hotline hiện tại là cấu hình mẫu chưa xác minh thực tế nên không sao chép.';
      setState(() {
        _feedbackBannerMessage = msg;
        _isFeedbackError = true;
      });
      _showStatusSnackBar(msg);
      return;
    }
    final clean = ContactService.normalizePhone(_effectiveHotline);
    final copied = await ContactService.copyTextToClipboard(clean);
    if (!mounted) return;
    final msg = copied
        ? 'Đã sao chép số hotline ${ContactService.formatDisplayPhone(clean)} vào bộ nhớ tạm.'
        : 'Không thể sao chép số hotline trên thiết bị này.';
    setState(() {
      _feedbackBannerMessage = msg;
      _isFeedbackError = !copied;
    });
    _showStatusSnackBar(msg);
  }

  Future<void> _handleOpenZalo() async {
    final hasDraftToCopy = _userConsented && _generatedDraft.trim().isNotEmpty;
    final result = await ContactService.openZaloInquiryDetailed(
      customZaloUrl: _effectiveZaloUrl,
      messageText: hasDraftToCopy ? _generatedDraft : null,
      userConsentedToCopyDraft: hasDraftToCopy,
      rejectPlaceholder: true,
    );
    if (!mounted) return;
    setState(() {
      _feedbackBannerMessage = result.message;
      _isFeedbackError =
          result.status == ContactActionStatus.unverifiedConfig ||
              result.status == ContactActionStatus.invalidInput ||
              result.status == ContactActionStatus.failed;
    });
    _showStatusSnackBar(result.message);
  }

  Future<void> _handleOpenOfficeMap() async {
    final result = await ContactService.openExternalHttpsUrl(
      'https://www.google.com/maps/search/?api=1&query=28%20Thi%20Sach%20Vung%20Tau',
      fallbackCopyText: '28 Thi Sách, TP. Vũng Tàu',
    );
    if (!mounted) return;
    setState(() {
      _feedbackBannerMessage = result.message;
      _isFeedbackError = result.status == ContactActionStatus.invalidInput ||
          result.status == ContactActionStatus.failed;
    });
    _showStatusSnackBar(result.message);
  }

  Future<void> _handleFormAction() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_userConsented) {
      const msg =
          'Vui lòng tích chọn đồng ý trước khi tạo hoặc chia sẻ nội dung tư vấn.';
      setState(() {
        _feedbackBannerMessage = msg;
        _isFeedbackError = true;
      });
      _showStatusSnackBar(msg);
      return;
    }

    final draft = ContactService.buildConsultationDraftMessage(
      fullName: _nameCtrl.text,
      phone: _phoneCtrl.text,
      email: _emailCtrl.text,
      topic: _selectedTopic,
      messageContent: _messageCtrl.text,
    );

    if (_hasRealEndpoint) {
      setState(() {
        _isSubmitting = true;
        _feedbackBannerMessage = '';
        _isFeedbackError = false;
      });
      try {
        await widget.onSubmitInquiryEndpoint!(
          ContactInquiryPayload(
            fullName: _nameCtrl.text.trim(),
            phone: ContactService.normalizePhone(_phoneCtrl.text),
            email: _emailCtrl.text.trim(),
            topic: _selectedTopic,
            message: _messageCtrl.text.trim(),
            userConsented: _userConsented,
          ),
        );
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _generatedDraft = draft;
          _feedbackBannerMessage =
              'Yêu cầu tư vấn đã được gửi tới hệ thống thành công.';
          _isFeedbackError = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _feedbackBannerMessage = 'Không thể gửi yêu cầu: $e';
          _isFeedbackError = true;
        });
      }
      return;
    }

    // Consent-based draft generation & clipboard copy (no fake backend submission)
    final copied = await ContactService.copyTextToClipboard(draft);
    if (!mounted) return;
    setState(() {
      _generatedDraft = draft;
      _isFeedbackError = !copied;
      _feedbackBannerMessage = copied
          ? 'Đã tạo và sao chép bản nháp tư vấn vào bộ nhớ tạm. Zalo không hỗ trợ tự điền tin nhắn — bạn hãy dán (Paste) nội dung này khi mở cuộc trò chuyện.'
          : 'Đã tạo bản nháp bên dưới nhưng không thể tự động sao chép vào bộ nhớ tạm.';
    });
    _showStatusSnackBar(_feedbackBannerMessage);
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
                                      flex: 95,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildHeroInfo(context),
                                          const SizedBox(height: AppSpacing.lg),
                                          _buildHeroImage(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xxl),
                                    Expanded(
                                      flex: 105,
                                      child: _buildConsultationCard(context),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildHeroInfo(context),
                                    const SizedBox(height: AppSpacing.lg),
                                    _buildConsultationCard(context),
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
    final hotlineDisplayValue = hotlineVerified
        ? formattedPhone
        : (hotlineValidFormat
            ? '$formattedPhone (Số mẫu)'
            : 'Chưa cấu hình số hotline');

    final zaloDisplayValue = normalizedZaloUri != null
        ? (zaloVerified
            ? '${normalizedZaloUri.host}/${normalizedZaloUri.pathSegments.first}'
            : '${normalizedZaloUri.host}/${normalizedZaloUri.pathSegments.first} (Mẫu)')
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
          'Kết nối nhanh qua Hotline, Zalo OA hoặc gửi yêu cầu tư vấn (08:00 – 22:00).',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!hotlineVerified || !zaloVerified)
          Container(
            key: const ValueKey('contact-config-warning-banner'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 10,
            ),
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  LucideIcons.info,
                  size: 16,
                  color: AppColors.iconMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Đang hiển thị cấu hình mẫu (Hotline & Zalo OA chưa xác minh).',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Column(
          children: [
            _ContactChannelCard(
              cardKey: const ValueKey('contact-card-hotline'),
              primaryActionKey: const ValueKey('contact-call-hotline-btn'),
              icon: LucideIcons.phone,
              title: 'Hotline tư vấn',
              value: hotlineDisplayValue,
              badgeText: hotlineVerified
                  ? 'Đã xác minh cấu hình'
                  : 'Cấu hình mẫu — Chưa xác minh',
              isVerified: hotlineVerified,
              primaryActionLabel:
                  hotlineVerified ? 'Gọi ngay' : 'Kiểm tra hotline',
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
              badgeText: zaloVerified
                  ? 'Đã xác minh cấu hình'
                  : 'Cấu hình mẫu — Chưa xác minh',
              isVerified: zaloVerified,
              primaryActionLabel:
                  zaloVerified ? 'Mở Zalo OA' : 'Kiểm tra Zalo OA',
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

  Widget _buildTopicSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chủ đề quan tâm',
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textStrong,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: _supportTopics.map((topic) {
            final selected = _selectedTopic == topic;
            return Semantics(
              button: true,
              selected: selected,
              label: 'Chủ đề $topic',
              child: InkWell(
                key: ValueKey('contact-topic-$topic'),
                onTap: () => setState(() => _selectedTopic = topic),
                borderRadius: AppRadii.roundedPill,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.textStrong
                          : AppColors.surfaceBase,
                      borderRadius: AppRadii.roundedPill,
                      border: Border.all(
                        color: selected
                            ? AppColors.textStrong
                            : AppColors.borderSoft,
                      ),
                    ),
                    child: Text(
                      topic,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? AppColors.textInverse
                            : AppColors.textStrong,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildConsultationCard(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Container(
      padding: EdgeInsets.all(
        screenWidth < 360 ? AppSpacing.md : AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: AppRadii.roundedCard,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _hasRealEndpoint ? 'Gửi yêu cầu tư vấn' : 'Soạn nội dung tư vấn',
              style: AppTypography.sectionHeading.copyWith(
                fontSize: 20,
                color: AppColors.textStrong,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _hasRealEndpoint
                  ? 'Điền thông tin liên hệ để gửi trực tiếp tới hệ thống hỗ trợ The Palm.'
                  : 'Chọn chủ đề và điền nhu cầu để tạo nhanh bản nháp gửi qua Zalo hoặc Hotline.',
              style: AppTypography.bodyMuted.copyWith(height: 1.45),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildTopicSelector(),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCols = constraints.maxWidth >= 480;
                if (twoCols) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildNameField()),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _buildPhoneField()),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildNameField(),
                    const SizedBox(height: AppSpacing.md),
                    _buildPhoneField(),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _buildEmailField(),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nhu cầu của bạn',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textStrong,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              key: const ValueKey('contact-message-input'),
              controller: _messageCtrl,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText:
                    'Ví dụ: nhóm 10 khách, cần villa hồ bơi gần Bãi Sau, đi 2N1Đ...',
                filled: true,
                fillColor: AppColors.surfaceBase,
                contentPadding: const EdgeInsets.all(AppSpacing.md),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: AppColors.borderFocus,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.errorRed),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: AppColors.errorRed,
                    width: 1.5,
                  ),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập nội dung cần hỗ trợ'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            // Explicit User Consent Toggle (>=48dp touch height)
            Semantics(
              checked: _userConsented,
              label:
                  'Tôi đồng ý tạo và sao chép bản nháp thông tin trên để chủ động liên hệ tư vấn',
              child: InkWell(
                key: const ValueKey('contact-consent-checkbox'),
                onTap: () => setState(() => _userConsented = !_userConsented),
                borderRadius: BorderRadius.circular(14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 48,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(
                            _userConsented
                                ? LucideIcons.squareCheck
                                : LucideIcons.square,
                            size: 20,
                            color: AppColors.iconStrong,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Đồng ý tạo bản nháp từ thông tin đã nhập để chủ động liên hệ.',
                          style: AppTypography.bodyMedium.copyWith(
                            fontSize: 13,
                            color: AppColors.textStrong,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_feedbackBannerMessage.isNotEmpty)
              Container(
                key: const ValueKey('contact-feedback-banner'),
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isFeedbackError
                        ? AppColors.errorRed
                        : AppColors.borderSoft,
                  ),
                ),
                child: Text(
                  _feedbackBannerMessage,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _isFeedbackError
                        ? AppColors.errorRed
                        : AppColors.textStrong,
                  ),
                ),
              ),
            if (_generatedDraft.isNotEmpty)
              Container(
                key: const ValueKey('contact-draft-preview'),
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Bản nháp đã tạo:',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textStrong,
                            ),
                          ),
                        ),
                        AppIconButton(
                          key: const ValueKey('contact-copy-draft-again-btn'),
                          tooltip: 'Sao chép lại bản nháp',
                          icon: const Icon(
                            LucideIcons.copy,
                            size: 18,
                            color: AppColors.iconStrong,
                          ),
                          onPressed: () async {
                            final copied =
                                await ContactService.copyTextToClipboard(
                              _generatedDraft,
                            );
                            if (copied) {
                              _showStatusSnackBar(
                                'Đã sao chép lại bản nháp vào bộ nhớ tạm.',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    SelectableText(
                      _generatedDraft,
                      style: AppTypography.bodyMedium.copyWith(
                        height: 1.5,
                        color: AppColors.textStrong,
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  key: const ValueKey('contact-submit-button'),
                  onPressed: _isSubmitting ? null : _handleFormAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                    shape: const StadiumBorder(),
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          screenWidth < 360 ? AppSpacing.md : AppSpacing.lg,
                      vertical: 14,
                    ),
                  ),
                  icon: Icon(
                    _hasRealEndpoint ? LucideIcons.send : LucideIcons.copy,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    _hasRealEndpoint
                        ? 'Gửi yêu cầu'
                        : 'Tạo & Sao chép bản nháp',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('contact-open-zalo-btn'),
                  onPressed: _handleOpenZalo,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    shape: const StadiumBorder(),
                    side: const BorderSide(color: AppColors.border),
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          screenWidth < 360 ? AppSpacing.md : AppSpacing.lg,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(
                    LucideIcons.messageCircle,
                    size: 16,
                    color: AppColors.iconStrong,
                  ),
                  label: const Text(
                    'Mở Zalo OA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildPillInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: AppColors.surfaceBase,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
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
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadii.roundedPill,
        borderSide: BorderSide(color: AppColors.errorRed),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadii.roundedPill,
        borderSide: BorderSide(color: AppColors.errorRed, width: 1.5),
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Họ và tên',
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textStrong,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          key: const ValueKey('contact-name-input'),
          controller: _nameCtrl,
          autofillHints: const [AutofillHints.name],
          textInputAction: TextInputAction.next,
          decoration: _buildPillInputDecoration('Tên của bạn'),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Vui lòng nhập họ và tên'
              : null,
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Số điện thoại',
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textStrong,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          key: const ValueKey('contact-phone-input'),
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          textInputAction: TextInputAction.next,
          decoration: _buildPillInputDecoration('09...'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Vui lòng nhập số điện thoại';
            }
            if (!ContactService.isValidPhoneFormat(v)) {
              return 'Số điện thoại không đúng định dạng';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _hasRealEndpoint ? 'Email liên hệ' : 'Email (tùy chọn)',
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textStrong,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          key: const ValueKey('contact-email-input'),
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: _buildPillInputDecoration('ban@example.com'),
          validator: (v) {
            final trimmed = v?.trim() ?? '';
            if (trimmed.isEmpty) {
              return _hasRealEndpoint
                  ? 'Vui lòng nhập email để nhận phản hồi'
                  : null;
            }
            if (!ContactService.isValidEmail(trimmed)) {
              return 'Email không đúng định dạng';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _ContactChannelCard extends StatelessWidget {
  final Key? cardKey;
  final Key? primaryActionKey;
  final IconData icon;
  final String title;
  final String value;
  final String badgeText;
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
    required this.badgeText,
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
                      badgeText,
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
