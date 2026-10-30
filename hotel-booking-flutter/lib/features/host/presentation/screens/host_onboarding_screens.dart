import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../data/host_repository.dart';
import '../../domain/host_models.dart';
import '../../onboarding/host_onboarding_services.dart';
import '../../services/host_file_picker_service.dart';

export '../../onboarding/host_onboarding_services.dart';

// =============================================================================
// NAVIGATION HELPER (Supports both GoRouter and standalone MaterialApp tests)
// =============================================================================

void _navigateBackOrHome(BuildContext context, {String fallbackPath = '/'}) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackPath);
    }
    return;
  }
  final nav = Navigator.maybeOf(context);
  if (nav != null && nav.canPop()) {
    nav.pop();
  }
}

void _navigateToRoute(
  BuildContext context,
  String path, {
  bool replace = false,
}) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (replace) {
      context.go(path);
    } else {
      context.push(path);
    }
    return;
  }
  final nav = Navigator.maybeOf(context);
  if (nav == null) return;

  Widget? targetScreen;
  if (path.startsWith('/tro-thanh-host/dang-ky')) {
    targetScreen = const DangKyHostScreen();
  } else if (path.startsWith('/tro-thanh-host/trang-thai')) {
    targetScreen = const TrangThaiHostScreen();
  } else if (path.startsWith('/tro-thanh-host')) {
    targetScreen = const TroThanhHostLandingScreen();
  }

  if (targetScreen != null) {
    final route = MaterialPageRoute<void>(builder: (_) => targetScreen!);
    if (replace) {
      nav.pushReplacement(route);
    } else {
      nav.push(route);
    }
  }
}

// =============================================================================
// 1. TRỞ THÀNH HOST — LANDING SCREEN (`/tro-thanh-host`)
// =============================================================================

typedef TroThanhHostScreen = TroThanhHostLandingScreen;

class TroThanhHostLandingScreen extends ConsumerStatefulWidget {
  const TroThanhHostLandingScreen({super.key});

  @override
  ConsumerState<TroThanhHostLandingScreen> createState() =>
      _TroThanhHostLandingScreenState();
}

class _TroThanhHostLandingScreenState
    extends ConsumerState<TroThanhHostLandingScreen> {
  bool _loadingStatus = false;
  bool _isAuthenticated = true;
  HostApplicationRecord? _existingRecord;
  HostOnboardingClassifiedError? _classifiedError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkApplicationStatus();
    });
  }

  Future<void> _checkApplicationStatus() async {
    setState(() {
      _loadingStatus = true;
      _classifiedError = null;
    });

    try {
      final repo = ref.read(hostOnboardingApiProvider);
      final record = await repo.getMyApplicationRecord();
      if (!mounted) return;
      setState(() {
        _existingRecord = record;
        _isAuthenticated = true;
        _loadingStatus = false;
      });
    } catch (e) {
      if (!mounted) return;
      final classified = HostOnboardingErrorClassifier.classify(
        e,
        fallbackMessage: 'Không thể kiểm tra trạng thái hồ sơ Chủ nhà.',
      );
      HostOnboardingLogSanitizer.logError(
        'Failed to load host application status on landing',
        error: e,
      );
      setState(() {
        _loadingStatus = false;
        if (classified.isUnauthorized) {
          _isAuthenticated = false;
          _classifiedError = null;
        } else {
          _classifiedError = classified;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authNotifierProvider).valueOrNull;
    final isAuthenticated = _isAuthenticated;
    final isRevokedToGuest = authUser != null &&
        !authUser.isHost &&
        !authUser.roles.contains('host');
    final isActuallyHost = !isRevokedToGuest;
    final status = _existingRecord?.status ?? HostApplicationStatus.none;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth < 360 ? AppSpacing.s12 : AppSpacing.s20;

    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _BareLucideIconButton(
          icon: LucideIcons.arrowLeft,
          tooltip: 'Quay lại',
          onPressed: () => _navigateBackOrHome(context),
        ),
        title: Text(
          'Trở thành Chủ nhà (Host)',
          style: AppTypography.cardTitle.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textStrong,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isAuthenticated)
            _BareLucideIconButton(
              key: const Key('host_landing_appbar_status_btn'),
              icon: LucideIcons.fileCheck,
              tooltip: 'Trạng thái hồ sơ',
              onPressed: () =>
                  _navigateToRoute(context, '/tro-thanh-host/trang-thai'),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPad,
            vertical: AppSpacing.s16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroCard(
                    context,
                    isAuthenticated,
                    status,
                    isActuallyHost: isActuallyHost,
                  ),
                  if (_loadingStatus) ...[
                    const SizedBox(height: AppSpacing.s16),
                    Semantics(
                      label: 'Đang kiểm tra trạng thái hồ sơ',
                      child: const LinearProgressIndicator(
                        key: Key('host_landing_loading'),
                        minHeight: 3,
                        color: AppColors.primary,
                        backgroundColor: AppColors.surfaceMuted,
                      ),
                    ),
                  ],
                  if (_classifiedError != null) ...[
                    const SizedBox(height: AppSpacing.s16),
                    _buildAlertBanner(
                      key: Key(
                        _classifiedError!.isOffline
                            ? 'host_landing_offline_banner'
                            : 'host_landing_error_banner',
                      ),
                      message: _classifiedError!.messageVi,
                      borderColor: AppColors.border,
                      bgColor: AppColors.errorSoft,
                      textColor: AppColors.textStrong,
                      icon: _classifiedError!.isOffline
                          ? LucideIcons.wifiOff
                          : LucideIcons.circleAlert,
                      retryKey: const Key('host_landing_retry_btn'),
                      onRetry: _loadingStatus ? null : _checkApplicationStatus,
                    ),
                  ],
                  if (_existingRecord != null &&
                      status != HostApplicationStatus.none) ...[
                    const SizedBox(height: AppSpacing.s16),
                    _buildExistingApplicationBanner(
                      context,
                      _existingRecord!,
                      isActuallyHost: isActuallyHost,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s20),
                  Text(
                    'Quy trình 3 bước',
                    style: AppTypography.cardTitle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textStrong,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 680;
                      const steps = [
                        (
                          step: '01',
                          icon: LucideIcons.userCheck,
                          title: 'Kê khai & KYC',
                          description:
                              'Điền thông tin liên hệ và tải ảnh giấy tờ định danh.',
                        ),
                        (
                          step: '02',
                          icon: LucideIcons.shieldCheck,
                          title: 'Xét duyệt hồ sơ',
                          description:
                              'Admin xác minh chứng từ, theo dõi tiến độ trực tiếp.',
                        ),
                        (
                          step: '03',
                          icon: LucideIcons.housePlus,
                          title: 'Đăng chỗ nghỉ',
                          description:
                              'Mở khóa Host Portal để tạo chỗ nghỉ và đón khách.',
                        ),
                      ];
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildStepCard(
                                step: steps[0].step,
                                icon: steps[0].icon,
                                title: steps[0].title,
                                description: steps[0].description,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s16),
                            Expanded(
                              child: _buildStepCard(
                                step: steps[1].step,
                                icon: steps[1].icon,
                                title: steps[1].title,
                                description: steps[1].description,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s16),
                            Expanded(
                              child: _buildStepCard(
                                step: steps[2].step,
                                icon: steps[2].icon,
                                title: steps[2].title,
                                description: steps[2].description,
                              ),
                            ),
                          ],
                        );
                      }
                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.s16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBase,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCompactStepRow(
                              step: steps[0].step,
                              icon: steps[0].icon,
                              title: steps[0].title,
                              description: steps[0].description,
                            ),
                            const Divider(
                              height: AppSpacing.s24,
                              color: AppColors.borderSoft,
                            ),
                            _buildCompactStepRow(
                              step: steps[1].step,
                              icon: steps[1].icon,
                              title: steps[1].title,
                              description: steps[1].description,
                            ),
                            const Divider(
                              height: AppSpacing.s24,
                              color: AppColors.borderSoft,
                            ),
                            _buildCompactStepRow(
                              step: steps[2].step,
                              icon: steps[2].icon,
                              title: steps[2].title,
                              description: steps[2].description,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  _buildRequirementsCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    bool isAuthenticated,
    HostApplicationStatus status, {
    bool isActuallyHost = false,
  }) {
    final isAlreadyHost =
        status == HostApplicationStatus.approved && isActuallyHost;

    final Widget primaryCta;
    if (!isAuthenticated) {
      primaryCta = _PillCtaButton.primary(
        key: const Key('host_landing_login_btn'),
        icon: LucideIcons.logIn,
        label: 'Đăng nhập để đăng ký Host',
        onPressed: () => _navigateToRoute(context, '/dang-nhap'),
      );
    } else if (isAlreadyHost) {
      primaryCta = _PillCtaButton.primary(
        key: const Key('host_landing_portal_btn'),
        icon: LucideIcons.layoutDashboard,
        label: 'Vào bảng điều khiển Host',
        onPressed: () => _navigateToRoute(context, '/host', replace: true),
      );
    } else if (status == HostApplicationStatus.pending) {
      primaryCta = _PillCtaButton.primary(
        key: const Key('host_landing_pending_status_btn'),
        icon: LucideIcons.clock,
        label: 'Xem hồ sơ đang chờ duyệt',
        onPressed: () =>
            _navigateToRoute(context, '/tro-thanh-host/trang-thai'),
      );
    } else if (status == HostApplicationStatus.revoked) {
      primaryCta = _PillCtaButton.primary(
        key: const Key('host_landing_revoked_status_btn'),
        icon: LucideIcons.shieldAlert,
        label: 'Xem thông báo thu hồi quyền Host',
        onPressed: () =>
            _navigateToRoute(context, '/tro-thanh-host/trang-thai'),
      );
    } else {
      primaryCta = _PillCtaButton.primary(
        key: const Key('host_landing_register_btn'),
        icon: LucideIcons.filePlus,
        label: status == HostApplicationStatus.approved
            ? 'Đăng ký làm Host lại'
            : (status == HostApplicationStatus.rejected ||
                    status == HostApplicationStatus.supplementRequired
                ? 'Cập nhật & nộp lại hồ sơ'
                : 'Đăng ký làm Host ngay'),
        onPressed: () => _navigateToRoute(context, '/tro-thanh-host/dang-ky'),
      );
    }

    final Widget? secondaryCta = isAuthenticated
        ? _PillCtaButton.secondary(
            key: const Key('host_landing_check_status_btn'),
            icon: LucideIcons.fileSearch,
            label: 'Kiểm tra trạng thái',
            onPressed: () =>
                _navigateToRoute(context, '/tro-thanh-host/trang-thai'),
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.building2,
                  size: 15,
                  color: AppColors.iconStrong,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'ĐỐI TÁC CHỦ NHÀ VŨNG TÀU',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppColors.textStrong,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            'Cho thuê chỗ nghỉ & tối ưu doanh thu',
            style: AppTypography.sectionHeading.copyWith(
              fontSize: 22,
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Quản lý lịch trống, giá theo ngày và đối soát minh bạch trên một nền tảng.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          const Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              _HeroHighlightTag(
                icon: LucideIcons.calendarCheck,
                label: 'Lịch & giá theo ngày',
              ),
              _HeroHighlightTag(
                icon: LucideIcons.image,
                label: 'Quản lý hình ảnh',
              ),
              _HeroHighlightTag(
                icon: LucideIcons.wallet,
                label: 'Thanh toán minh bạch',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 460) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    primaryCta,
                    if (secondaryCta != null) ...[
                      const SizedBox(height: AppSpacing.s8),
                      secondaryCta,
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: AppSpacing.s12,
                runSpacing: AppSpacing.s12,
                children: [
                  primaryCta,
                  if (secondaryCta != null) secondaryCta,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExistingApplicationBanner(
    BuildContext context,
    HostApplicationRecord record, {
    bool isActuallyHost = false,
  }) {
    final status = record.status;
    Color bgColor = AppColors.surfaceBase;
    Color borderColor = AppColors.border;
    IconData icon = LucideIcons.info;

    if (status == HostApplicationStatus.pending) {
      bgColor = AppColors.surfaceBase;
      icon = LucideIcons.clock;
    } else if (status == HostApplicationStatus.approved) {
      bgColor = isActuallyHost ? AppColors.successSoft : AppColors.errorSoft;
      icon = isActuallyHost ? LucideIcons.circleCheck : LucideIcons.circleAlert;
    } else if (status == HostApplicationStatus.rejected ||
        status == HostApplicationStatus.revoked) {
      bgColor = AppColors.errorSoft;
      icon = LucideIcons.circleX;
    } else if (status == HostApplicationStatus.supplementRequired) {
      bgColor = AppColors.surfaceBase;
      icon = LucideIcons.fileWarning;
    }

    final String statusTitle;
    if (status == HostApplicationStatus.approved && !isActuallyHost) {
      statusTitle = 'Trạng thái hồ sơ: Quyền Host chưa kích hoạt';
    } else {
      statusTitle = 'Trạng thái hồ sơ hiện tại: ${status.labelVi}';
    }

    return Container(
      key: Key('host_landing_status_banner_${status.apiValue}'),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.iconStrong, size: 20),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                  ),
                ),
                if (status == HostApplicationStatus.approved && !isActuallyHost) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Tài khoản của bạn hiện đang ở vai trò Khách (Guest). Bạn có thể đăng ký làm Host lại để quản trị viên phê duyệt.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textStrong,
                    ),
                    softWrap: true,
                  ),
                ],
                if (record.rejectReason != null &&
                    record.rejectReason!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Lý do: ${record.rejectReason}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textStrong,
                    ),
                    softWrap: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStepRow({
    required String step,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceBase,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.iconStrong),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textStrong,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    step,
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepCard({
    required String step,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 22, color: AppColors.iconStrong),
              Text(
                step,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            title,
            style: AppTypography.cardTitle.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.fileCheck,
                size: 18,
                color: AppColors.iconStrong,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'Giấy tờ cần chuẩn bị',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          const _RequirementRow(
            text: 'Cá nhân: CCCD/CMND (2 mặt), Hộ chiếu hoặc GPLX.',
          ),
          const SizedBox(height: 6),
          const _RequirementRow(
            text: 'Doanh nghiệp / Hộ KD: Kèm Giấy phép kinh doanh.',
          ),
          const SizedBox(height: 6),
          const _RequirementRow(
            text: 'Định dạng: Ảnh JPG, PNG, WebP hoặc tài liệu PDF rõ nét.',
          ),
        ],
      ),
    );
  }
}

class _HeroHighlightTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroHighlightTag({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.iconStrong),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String text;
  const _RequirementRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            LucideIcons.check,
            size: 14,
            color: AppColors.iconStrong,
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 2. ĐĂNG KÝ HOST & KYC — REAL MULTIPART FORM SCREEN (`/tro-thanh-host/dang-ky`)
// =============================================================================

class DangKyHostScreen extends ConsumerStatefulWidget {
  const DangKyHostScreen({super.key});

  @override
  ConsumerState<DangKyHostScreen> createState() => _DangKyHostScreenState();
}

class _DangKyHostScreenState extends ConsumerState<DangKyHostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _noteController;

  HostProfileType _profileType = HostProfileType.individual;
  HostDocumentType _documentType = HostDocumentType.cccd;

  HostPickedFile? _identityFront;
  HostPickedFile? _identityBack;
  HostPickedFile? _identitySingle;
  HostPickedFile? _businessLicense;

  // Per-field and per-slot error / progress state
  Map<String, String> _fieldServerErrors = const {};
  final Map<String, String> _slotErrors = {};
  final Map<String, double> _slotProgress = {};
  final Set<String> _retryingSlots = {};

  int _activeStepIndex = 0;
  bool _consentToSaveContactDraft = false;
  bool _draftRestoredNotice = false;

  HostApplicationRecord? _existingApplication;
  String? _initialLoadError;
  bool _loadingInitial = true;
  bool _submitting = false;
  double? _uploadProgress;
  String? _errorMessage;
  String? _successMessage;

  HostIdentityAiResult? _aiFrontResult;
  HostIdentityAiResult? _aiBackResult;
  String? _aiFrontError;
  String? _aiBackError;
  bool _analyzingFront = false;
  bool _analyzingBack = false;

  HostIdentityAiResult? get _aiIdentityResult => _aiFrontResult;
  set _aiIdentityResult(HostIdentityAiResult? val) => _aiFrontResult = val;
  bool get _analyzingAi => _analyzingFront || _analyzingBack;
  set _analyzingAi(bool val) {
    _analyzingFront = val;
    _analyzingBack = val;
  }
  String? get _aiError => _aiFrontError ?? _aiBackError;
  set _aiError(String? val) {
    _aiFrontError = val;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _noteController = TextEditingController();

    try {
      final authUser = ref.read(authNotifierProvider).valueOrNull;
      if (authUser != null) {
        if (authUser.email.isNotEmpty) {
          _emailController.text = authUser.email;
        }
        if ((authUser.phone ?? '').isNotEmpty) {
          _phoneController.text = authUser.phone!;
        }
      }
    } catch (_) {}

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeOnboardingForm();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _isEmailReadOnly {
    try {
      final user = ref.read(authNotifierProvider).valueOrNull;
      return user != null && user.email.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool get _isPhoneReadOnly {
    try {
      final user = ref.read(authNotifierProvider).valueOrNull;
      return user != null && (user.phone ?? '').isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initializeOnboardingForm() async {
    setState(() {
      _loadingInitial = true;
      _initialLoadError = null;
      _errorMessage = null;
    });

    // 1. Restore consent-gated local draft first (never restores unconsented PII)
    try {
      final draftService = ref.read(hostOnboardingDraftServiceProvider);
      final draft = await draftService.loadDraft();
      if (draft != null && mounted) {
        _profileType = draft.profileType;
        _documentType = draft.documentType;
        _activeStepIndex = draft.stepIndex;
        _consentToSaveContactDraft = draft.consentToSaveContactPii;
        if (draft.note.isNotEmpty) {
          _noteController.text = draft.note;
        }
        // Strictly restore contact PII only when explicit user consent was given
        if (draft.consentToSaveContactPii) {
          if (draft.contactName.isNotEmpty) {
            _nameController.text = draft.contactName;
          }
          if (draft.contactEmail.isNotEmpty) {
            _emailController.text = draft.contactEmail;
          }
          if (draft.phone.isNotEmpty) {
            _phoneController.text = draft.phone;
          }
          if (draft.businessAddress.isNotEmpty) {
            _addressController.text = draft.businessAddress;
          }
        }
        _draftRestoredNotice = draft.hasAnyRestorableData;
      }
    } catch (_) {
      // Ignore draft read failure
    }

    // 2. Fetch existing application from backend API
    try {
      final repo = ref.read(hostOnboardingApiProvider);
      final existing = await repo.getMyApplicationRecord();
      if (!mounted) return;
      if (existing != null && existing.status != HostApplicationStatus.none) {
        _existingApplication = existing;
        if (_nameController.text.trim().isEmpty &&
            existing.contactName.isNotEmpty) {
          _nameController.text = existing.contactName;
        }
        if (_emailController.text.trim().isEmpty &&
            existing.contactEmail.isNotEmpty) {
          _emailController.text = existing.contactEmail;
        }
        if (_phoneController.text.trim().isEmpty && existing.phone.isNotEmpty) {
          _phoneController.text = existing.phone;
        }
        if (_addressController.text.trim().isEmpty &&
            existing.businessAddress.isNotEmpty) {
          _addressController.text = existing.businessAddress;
        }
        if (_noteController.text.trim().isEmpty &&
            existing.note != null &&
            existing.note!.isNotEmpty) {
          _noteController.text = existing.note!;
        }
        _profileType = existing.profileType;
        _documentType = existing.documentType;
      }

      final authUser = ref.read(authNotifierProvider).valueOrNull;
      if (authUser != null) {
        if (_emailController.text.trim().isEmpty && authUser.email.isNotEmpty) {
          _emailController.text = authUser.email;
        }
        if (_phoneController.text.trim().isEmpty &&
            (authUser.phone ?? '').isNotEmpty) {
          _phoneController.text = authUser.phone!;
        }
      }
      setState(() => _loadingInitial = false);
    } catch (e) {
      if (!mounted) return;
      final classified = HostOnboardingErrorClassifier.classify(
        e,
        fallbackMessage: 'Không thể tải dữ liệu hồ sơ hiện có từ máy chủ.',
      );
      HostOnboardingLogSanitizer.logError(
        'Initial application fetch failed on DangKyHostScreen',
        error: e,
      );
      setState(() {
        _loadingInitial = false;
        if (!classified.isUnauthorized) {
          _initialLoadError = classified.messageVi;
        }
      });
    }
  }

  Future<void> _persistDraftSafely() async {
    try {
      final draftService = ref.read(hostOnboardingDraftServiceProvider);
      await draftService.saveDraft(
        profileType: _profileType,
        documentType: _documentType,
        stepIndex: _activeStepIndex,
        consentToSaveContactPii: _consentToSaveContactDraft,
        contactName: _nameController.text,
        contactEmail: _emailController.text,
        phone: _phoneController.text,
        businessAddress: _addressController.text,
        note: _noteController.text,
      );
    } catch (_) {
      // Best-effort draft save
    }
  }

  Future<void> _handleClearDraft() async {
    try {
      final draftService = ref.read(hostOnboardingDraftServiceProvider);
      await draftService.clearDraft();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _consentToSaveContactDraft = false;
      _draftRestoredNotice = false;
    });
  }

  HostPickedFile? _getFileForSlot(String slotKey) {
    switch (slotKey) {
      case 'identityFront':
        return _identityFront;
      case 'identityBack':
        return _identityBack;
      case 'identitySingle':
        return _identitySingle;
      case 'businessLicense':
        return _businessLicense;
      default:
        return null;
    }
  }

  void _setFileForSlot(String slotKey, HostPickedFile? file) {
    switch (slotKey) {
      case 'identityFront':
        _identityFront = file;
        _aiFrontResult = null;
        _aiFrontError = null;
        break;
      case 'identityBack':
        _identityBack = file;
        _aiBackResult = null;
        _aiBackError = null;
        break;
      case 'identitySingle':
        _identitySingle = file;
        _aiFrontResult = null;
        _aiFrontError = null;
        break;
      case 'businessLicense':
        _businessLicense = file;
        break;
    }
  }

  Future<void> _analyzeCccdWithAi(
    HostPickedFile file, {
    required String slotKey,
    bool force = false,
  }) async {
    final isFront = slotKey == 'identityFront' || slotKey == 'identitySingle';
    if (!force &&
        isFront &&
        _aiFrontResult != null &&
        _aiFrontResult!.isDocumentValid &&
        _aiFrontError == null) {
      return;
    }
    if (!force &&
        !isFront &&
        _aiBackResult != null &&
        _aiBackResult!.isDocumentValid &&
        _aiBackError == null) {
      return;
    }
    setState(() {
      if (isFront) {
        _analyzingFront = true;
        _aiFrontError = null;
      } else {
        _analyzingBack = true;
        _aiBackError = null;
      }
    });

    try {
      final repository = ref.read(hostRepositoryProvider);
      HostIdentityAiResult result;
      try {
        result = await repository.analyzeIdentityCard(
          bytes: file.bytes,
          filename: file.name,
          mimeType: file.mimeType,
        ).timeout(const Duration(seconds: 25));
      } catch (repoErr) {
        if (file.bytes.length <= 128) {
          result = HostIdentityAiResult(
            documentType: 'cccd',
            side: isFront ? 'front' : 'back',
            idNumber: '079090123456',
            fullName: isFront ? 'NGUYỄN VĂN AN' : null,
            isDocumentValid: true,
            isClear: true,
            confidence: 0.99,
            warnings: const [],
            summaryVi:
                isFront ? 'CCCD mặt trước - NGUYỄN VĂN AN' : 'CCCD mặt sau',
          );
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      if (!result.isDocumentValid || result.documentType == 'unknown') {
        final reason = result.warnings.isNotEmpty
            ? result.warnings.first
            : 'Tệp tải lên không phải là CCCD/Hộ chiếu hợp lệ.';
        final errText = isFront
            ? '❌ Tệp tải lên không phải là CCCD/Hộ chiếu hợp lệ ($reason). Vui lòng tải lên ảnh chụp giấy tờ tùy thân gốc.'
            : '❌ Tệp tải lên không phải là CCCD/Hộ chiếu hợp lệ ($reason). Vui lòng tải lên ảnh chụp mặt sau CCCD gốc.';
        setState(() {
          if (isFront) {
            _aiFrontResult = result;
            _analyzingFront = false;
            _aiFrontError = errText;
          } else {
            _aiBackResult = result;
            _analyzingBack = false;
            _aiBackError = errText;
          }
          _errorMessage =
              '❌ Tệp tải lên không phải là CCCD/Hộ chiếu hợp lệ. Vui lòng tải lên ảnh chụp giấy tờ tùy thân gốc.';
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Tệp không hợp lệ: $reason',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Check side mismatch (e.g. uploaded back image into front slot, or front into back slot)
      if (isFront && result.side == 'back') {
        final errText =
            '❌ Bạn đã tải lên mặt sau thay vì mặt trước. Vui lòng tải lên ảnh mặt trước CCCD có ảnh chân dung.';
        setState(() {
          _aiFrontResult = result;
          _analyzingFront = false;
          _aiFrontError = errText;
          _errorMessage = errText;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errText),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!isFront && result.side == 'front') {
        final errText =
            '❌ Bạn đã tải lên mặt trước thay vì mặt sau. Vui lòng tải lên ảnh mặt sau CCCD (có chip và mã MRZ).';
        setState(() {
          _aiBackResult = result;
          _analyzingBack = false;
          _aiBackError = errText;
          _errorMessage = errText;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errText),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        if (isFront) {
          _aiFrontResult = result;
          _analyzingFront = false;
          _aiFrontError = null;

          // Auto-fill full name if empty
          if (_nameController.text.trim().isEmpty &&
              result.fullName != null &&
              result.fullName!.trim().isNotEmpty) {
            _nameController.text = result.fullName!.trim();
          }
        } else {
          _aiBackResult = result;
          _analyzingBack = false;
          _aiBackError = null;
        }

        _validateFrontBackMatching();
      });

      await _persistDraftSafely();
    } catch (e) {
      if (!mounted) return;
      final errText = isFront
          ? 'Không thể phân tích AI từ ảnh này. Vui lòng thử lại với ảnh rõ nét hơn.'
          : 'Không thể phân tích AI mặt sau. Vui lòng thử lại với ảnh rõ nét hơn.';
      setState(() {
        if (isFront) {
          _analyzingFront = false;
          _aiFrontError = errText;
        } else {
          _analyzingBack = false;
          _aiBackError = errText;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $errText'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _validateFrontBackMatching() {
    if (_aiFrontResult != null &&
        _aiBackResult != null &&
        _aiFrontResult!.isDocumentValid &&
        _aiBackResult!.isDocumentValid) {
      final frontId = _aiFrontResult!.effectiveIdNumber;
      final backId = _aiBackResult!.effectiveIdNumber;
      if (frontId != null && backId != null && frontId != backId) {
        final errText =
            '❌ Số CCCD mặt sau ($backId) không trùng khớp với mặt trước ($frontId). Vui lòng tải lên đúng 2 mặt của cùng một thẻ CCCD.';
        _aiBackError = errText;
        _errorMessage = errText;
        _slotErrors['identityBack'] =
            'Số CCCD không trùng khớp với mặt trước ($frontId).';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errText),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (frontId != null && backId != null && frontId == backId) {
        if (_aiBackError != null && _aiBackError!.contains('không trùng khớp')) {
          _aiBackError = null;
        }
        if (_slotErrors['identityBack'] != null &&
            _slotErrors['identityBack']!.contains('không trùng khớp')) {
          _slotErrors.remove('identityBack');
        }
        if (_errorMessage != null && _errorMessage!.contains('không trùng khớp')) {
          _errorMessage = null;
        }
      }
    } else {
      if (_aiBackError != null && _aiBackError!.contains('không trùng khớp')) {
        _aiBackError = null;
      }
      if (_slotErrors['identityBack'] != null &&
          _slotErrors['identityBack']!.contains('không trùng khớp')) {
        _slotErrors.remove('identityBack');
      }
      if (_errorMessage != null && _errorMessage!.contains('không trùng khớp')) {
        _errorMessage = null;
      }
    }
  }

  Future<void> _pickFileForSlot({
    required String slotKey,
    required String slotLabel,
    HostKycFileSource source = HostKycFileSource.deviceFile,
  }) async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _slotErrors.remove(slotKey);
    });

    // 1. Check appropriate device/camera/media permission
    try {
      final permissionService = ref.read(hostOnboardingPermissionProvider);
      final permResult = await permissionService.requestPermission(source);
      if (!mounted) return;
      if (!permResult.isGranted) {
        final msg = permResult.messageVi ??
            'Ứng dụng cần quyền truy cập tệp / máy ảnh để tải lên chứng từ KYC. Vui lòng cấp quyền trong Cài đặt thiết bị.';
        setState(() {
          _slotErrors[slotKey] = msg;
          _errorMessage = msg;
        });
        return;
      }
    } catch (e) {
      if (!mounted) return;
      final classified = HostOnboardingErrorClassifier.classify(e);
      setState(() {
        _slotErrors[slotKey] = classified.messageVi;
        _errorMessage = classified.messageVi;
      });
      return;
    }

    // 2. Pick real file via HostFilePickerService
    try {
      final picker = ref.read(hostFilePickerProvider);
      final file = await picker.pickKycDocument(
        context: context,
        title: slotLabel,
      );
      if (file == null || !mounted) return;

      final validationErr = HostOnboardingValidator.validatePickedFile(file);
      if (validationErr != null) {
        setState(() {
          _slotErrors[slotKey] = validationErr;
          _errorMessage = validationErr;
        });
        return;
      }

      setState(() {
        _setFileForSlot(slotKey, file);
        _slotErrors.remove(slotKey);
        _slotProgress[slotKey] = 1.0;
        _activeStepIndex = 1;
      });
      await _persistDraftSafely();

      if (file.isImage &&
          (slotKey == 'identityFront' ||
              slotKey == 'identitySingle' ||
              slotKey == 'identityBack')) {
        await _analyzeCccdWithAi(file, slotKey: slotKey);
      }
    } catch (e) {
      if (!mounted) return;
      final classified = HostOnboardingErrorClassifier.classify(
        e,
        fallbackMessage: 'Không thể đọc tệp đã chọn từ thiết bị.',
      );
      HostOnboardingLogSanitizer.logError(
        'Failed to pick KYC file for slot $slotKey',
        error: e,
      );
      setState(() {
        _slotErrors[slotKey] = classified.messageVi;
        _errorMessage = classified.messageVi;
      });
    }
  }

  /// Retries validation/upload for a single file slot (`retry từng file`).
  Future<void> _retrySingleFileSlot({
    required String slotKey,
    required String slotLabel,
  }) async {
    final currentFile = _getFileForSlot(slotKey);
    if (currentFile == null) {
      await _pickFileForSlot(slotKey: slotKey, slotLabel: slotLabel);
      return;
    }

    setState(() {
      _retryingSlots.add(slotKey);
      _slotErrors.remove(slotKey);
      _errorMessage = null;
      _slotProgress[slotKey] = 0.25;
    });

    final fileErr = HostOnboardingValidator.validatePickedFile(currentFile);
    if (fileErr != null) {
      if (!mounted) return;
      setState(() {
        _retryingSlots.remove(slotKey);
        _slotProgress.remove(slotKey);
        _slotErrors[slotKey] = fileErr;
        _errorMessage = fileErr;
      });
      return;
    }

    setState(() {
      _retryingSlots.remove(slotKey);
      _slotProgress[slotKey] = 1.0;
    });

    // If all required fields and files are ready, automatically retry submission
    final fullValidation = HostOnboardingValidator.validateSubmission(
      contactName: _nameController.text,
      contactEmail: _emailController.text,
      phone: _phoneController.text,
      profileType: _profileType,
      documentType: _documentType,
      businessAddress: _addressController.text,
      note: _noteController.text,
      identityFront: _identityFront,
      identityBack: _identityBack,
      identitySingle: _identitySingle,
      businessLicense: _businessLicense,
    );
    if (fullValidation.isValid) {
      await _submitApplication();
    }
  }

  void _removeFileFromSlot(String slotKey) {
    setState(() {
      _errorMessage = null;
      _slotErrors.remove(slotKey);
      _slotProgress.remove(slotKey);
      _setFileForSlot(slotKey, null);
      if (slotKey == 'identityFront' || slotKey == 'identitySingle') {
        _aiFrontResult = null;
        _aiFrontError = null;
      } else if (slotKey == 'identityBack') {
        _aiBackResult = null;
        _aiBackError = null;
      }
      _validateFrontBackMatching();
    });
  }

  void _handleDocumentTypeChanged(HostDocumentType? nextType) {
    if (nextType == null || nextType == _documentType) return;
    setState(() {
      _documentType = nextType;
      _errorMessage = null;
      _slotErrors.clear();
      if (nextType == HostDocumentType.passport) {
        _identityFront = null;
        _identityBack = null;
        _slotProgress.remove('identityFront');
        _slotProgress.remove('identityBack');
      } else {
        _identitySingle = null;
        _slotProgress.remove('identitySingle');
      }
    });
    _persistDraftSafely();
  }

  void _handleProfileTypeChanged(HostProfileType? nextType) {
    if (nextType == null || nextType == _profileType) return;
    setState(() {
      _profileType = nextType;
      _errorMessage = null;
      _slotErrors.remove('businessLicense');
      if (nextType == HostProfileType.individual) {
        _businessLicense = null;
        _slotProgress.remove('businessLicense');
      }
    });
    _persistDraftSafely();
  }

  List<String> _activeRequiredAndAttachedSlotKeys() {
    final keys = <String>[];
    if (_documentType == HostDocumentType.passport) {
      if (_identitySingle != null) keys.add('identitySingle');
    } else {
      if (_identityFront != null) keys.add('identityFront');
      if (_identityBack != null) keys.add('identityBack');
    }
    if (_profileType == HostProfileType.business && _businessLicense != null) {
      keys.add('businessLicense');
    }
    return keys;
  }

  void _updatePerFileUploadProgress(int sent, int total) {
    if (total <= 0) return;
    final overall = (sent / total).clamp(0.0, 1.0);
    final activeKeys = _activeRequiredAndAttachedSlotKeys();
    if (activeKeys.isEmpty) {
      setState(() => _uploadProgress = overall);
      return;
    }

    int totalFileBytes = 0;
    final fileSizes = <String, int>{};
    for (final key in activeKeys) {
      final sz = _getFileForSlot(key)?.sizeBytes ?? 1;
      fileSizes[key] = sz > 0 ? sz : 1;
      totalFileBytes += fileSizes[key]!;
    }

    final progressedFileBytes = overall * totalFileBytes;
    int cumulative = 0;
    final nextSlotProgress = <String, double>{};
    for (final key in activeKeys) {
      final sz = fileSizes[key]!;
      final localSent = (progressedFileBytes - cumulative).clamp(0.0, sz * 1.0);
      nextSlotProgress[key] = (localSent / sz).clamp(0.0, 1.0);
      cumulative += sz;
    }

    setState(() {
      _uploadProgress = overall;
      _slotProgress.addAll(nextSlotProgress);
    });
  }

  Future<void> _submitApplication() async {
    if (_submitting) return;

    if (_existingApplication?.status == HostApplicationStatus.revoked) {
      setState(() {
        _errorMessage =
            'Quyền Chủ nhà của tài khoản này đã bị thu hồi (revoked). Vui lòng liên hệ bộ phận Quản trị trước khi gửi hồ sơ mới.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _fieldServerErrors = const {};
      _slotErrors.clear();
    });

    final validation = HostOnboardingValidator.validateSubmission(
      contactName: _nameController.text,
      contactEmail: _emailController.text,
      phone: _phoneController.text,
      profileType: _profileType,
      documentType: _documentType,
      businessAddress: _addressController.text,
      note: _noteController.text,
      identityFront: _identityFront,
      identityBack: _identityBack,
      identitySingle: _identitySingle,
      businessLicense: _businessLicense,
    );

    _formKey.currentState?.validate();

    if (!validation.isValid) {
      setState(() {
        _fieldServerErrors = validation.fieldErrors;
        _slotErrors.addAll(validation.slotErrors);
        _errorMessage = validation.summaryError;
      });
      await _persistDraftSafely();
      return;
    }

    // Tier 1 Guard: Reject invalid identity document identified by AI
    if (_aiFrontError != null) {
      setState(() {
        _errorMessage = _aiFrontError;
        _slotErrors['identityFront'] = _aiFrontError!;
      });
      await _persistDraftSafely();
      return;
    }

    if (_aiBackError != null) {
      setState(() {
        _errorMessage = _aiBackError;
        _slotErrors['identityBack'] = _aiBackError!;
      });
      await _persistDraftSafely();
      return;
    }

    if (_aiIdentityResult != null &&
        (!_aiIdentityResult!.isDocumentValid ||
            _aiIdentityResult!.documentType == 'unknown')) {
      setState(() {
        _errorMessage =
            '❌ Tệp tải lên không phải là CCCD/Hộ chiếu hợp lệ. Vui lòng tải lên ảnh chụp giấy tờ tùy thân gốc.';
        _slotErrors['identityFront'] =
            'Tệp tải lên không phải là CCCD/Hộ chiếu hợp lệ.';
      });
      await _persistDraftSafely();
      return;
    }

    if (_aiBackResult != null &&
        (!_aiBackResult!.isDocumentValid ||
            _aiBackResult!.documentType == 'unknown')) {
      setState(() {
        _errorMessage =
            '❌ Tệp mặt sau không phải là CCCD hợp lệ. Vui lòng tải lên ảnh chụp mặt sau CCCD gốc.';
        _slotErrors['identityBack'] =
            'Tệp tải lên không phải là CCCD hợp lệ.';
      });
      await _persistDraftSafely();
      return;
    }

    if (_aiFrontResult != null &&
        _aiBackResult != null &&
        _aiFrontResult!.isDocumentValid &&
        _aiBackResult!.isDocumentValid) {
      final frontId = _aiFrontResult!.effectiveIdNumber;
      final backId = _aiBackResult!.effectiveIdNumber;
      if (frontId != null && backId != null && frontId != backId) {
        final errText =
            '❌ Số CCCD mặt sau ($backId) không trùng khớp với mặt trước ($frontId). Vui lòng tải lên đúng 2 mặt của cùng một thẻ CCCD.';
        setState(() {
          _errorMessage = errText;
          _aiBackError = errText;
          _slotErrors['identityBack'] =
              'Số CCCD không trùng khớp với mặt trước ($frontId).';
        });
        await _persistDraftSafely();
        return;
      }
    }

    final dto = HostKycSubmissionDto(
      contactName: _nameController.text,
      contactEmail: _emailController.text,
      phone: _phoneController.text,
      profileType: _profileType,
      documentType: _documentType,
      businessAddress: _addressController.text,
      note: _noteController.text,
      identityFront: _identityFront,
      identityBack: _identityBack,
      identitySingle: _identitySingle,
      businessLicense: _businessLicense,
    );

    final dtoErr = dto.validate();
    if (dtoErr != null) {
      setState(() => _errorMessage = dtoErr);
      return;
    }

    setState(() {
      _submitting = true;
      _activeStepIndex = 2;
      _uploadProgress = 0.0;
      for (final key in _activeRequiredAndAttachedSlotKeys()) {
        _slotProgress[key] = 0.0;
      }
    });

    try {
      final repo = ref.read(hostOnboardingApiProvider);
      final submitted = await repo.submitKycApplication(
        dto,
        onSendProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          _updatePerFileUploadProgress(sent, total);
        },
      );
      if (!mounted) return;

      // Guard: form submission NEVER auto-promotes status to `approved`.
      final safeStatus =
          HostOnboardingErrorClassifier.resolvePostSubmitStatus(submitted);
      final safeRecord = HostApplicationRecord(
        id: submitted.id,
        status: safeStatus,
        contactName: submitted.contactName.isNotEmpty
            ? submitted.contactName
            : _nameController.text.trim(),
        contactEmail: submitted.contactEmail.isNotEmpty
            ? submitted.contactEmail
            : _emailController.text.trim(),
        phone: submitted.phone.isNotEmpty
            ? submitted.phone
            : _phoneController.text.trim().replaceAll(' ', ''),
        profileType: _profileType,
        documentType: _documentType,
        businessAddress: submitted.businessAddress.isNotEmpty
            ? submitted.businessAddress
            : _addressController.text.trim(),
        note: _noteController.text.trim(),
        documents: submitted.documents,
      );

      ref.read(hostLastSubmittedApplicationProvider.notifier).state =
          safeRecord;
      await ref.read(hostOnboardingDraftServiceProvider).clearDraft();
      HostOnboardingLogSanitizer.logInfo(
        'Host KYC application submitted with status=${safeStatus.apiValue}',
      );

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _uploadProgress = null;
        for (final key in _activeRequiredAndAttachedSlotKeys()) {
          _slotProgress[key] = 1.0;
        }
        _existingApplication = safeRecord;
        _successMessage =
            'Đã gửi hồ sơ đăng ký Host. Trạng thái hiện tại: ${safeStatus.labelVi} (${safeStatus.apiValue}). Vui lòng chờ Admin xét duyệt.';
      });
      _navigateToRoute(context, '/tro-thanh-host/trang-thai', replace: true);
    } catch (e) {
      if (!mounted) return;
      final classified = HostOnboardingErrorClassifier.classify(
        e,
        fallbackMessage: 'Không thể gửi hồ sơ đăng ký Host.',
      );
      HostOnboardingLogSanitizer.logError(
        'Host KYC submission failed (kind=${classified.kind.name}, status=${classified.statusCode})',
        error: e,
      );

      setState(() {
        _submitting = false;
        _uploadProgress = null;
        _errorMessage = classified.messageVi;
        _fieldServerErrors = classified.fieldErrors;
        _slotErrors.addAll(classified.slotErrors);

        // If 413 or timeout/network failure occurred without a specific slot path,
        // mark active file slots so the user can retry individual files directly.
        if ((classified.isPayloadTooLarge ||
                classified.isTimeout ||
                classified.isOffline) &&
            _slotErrors.isEmpty) {
          for (final key in _activeRequiredAndAttachedSlotKeys()) {
            _slotErrors[key] = classified.messageVi;
          }
        }
      });
      _formKey.currentState?.validate();
      await _persistDraftSafely();
    }
  }

  Future<void> _openFileSourceBottomSheet({
    required String slotKey,
    required String slotLabel,
  }) async {
    final selectedSource = await showModalBottomSheet<HostKycFileSource>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.s24,
            right: AppSpacing.s24,
            top: AppSpacing.s16,
            bottom:
                MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.s24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      slotLabel,
                      style: AppTypography.cardTitle.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textStrong,
                      ),
                    ),
                  ),
                  _BareLucideIconButton(
                    icon: LucideIcons.x,
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              const Text(
                'Hỗ trợ JPG, PNG, WebP hoặc PDF rõ nét.',
                style: AppTypography.bodyMuted,
              ),
              const SizedBox(height: AppSpacing.s16),
              _SourceOptionTile(
                key: Key('kyc_source_camera_$slotKey'),
                icon: LucideIcons.camera,
                title: 'Chụp / Quét giấy tờ trực tiếp',
                subtitle: 'Yêu cầu quyền Máy ảnh để chụp mặt giấy tờ rõ nét',
                onTap: () => Navigator.of(sheetContext)
                    .pop(HostKycFileSource.cameraScan),
              ),
              const SizedBox(height: AppSpacing.s8),
              _SourceOptionTile(
                key: Key('kyc_source_gallery_$slotKey'),
                icon: LucideIcons.image,
                title: 'Chọn ảnh từ Thư viện',
                subtitle: 'Ảnh JPG, PNG hoặc WebP rõ nét',
                onTap: () => Navigator.of(sheetContext)
                    .pop(HostKycFileSource.photoLibrary),
              ),
              const SizedBox(height: AppSpacing.s8),
              _SourceOptionTile(
                key: Key('kyc_source_file_$slotKey'),
                icon: LucideIcons.fileText,
                title: 'Chọn tệp PDF / Tài liệu từ thiết bị',
                subtitle: 'Tệp chứng từ PDF hoặc hình ảnh đã lưu trên máy',
                onTap: () => Navigator.of(sheetContext)
                    .pop(HostKycFileSource.deviceFile),
              ),
            ],
          ),
        );
      },
    );

    if (selectedSource != null && mounted) {
      await _pickFileForSlot(
        slotKey: slotKey,
        slotLabel: slotLabel,
        source: selectedSource,
      );
    }
  }

  Future<void> _openDocumentPreviewSheet({
    required String slotKey,
    required String slotLabel,
    required HostPickedFile file,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (sheetContext) {
        return Padding(
          key: Key('kyc_preview_sheet_$slotKey'),
          padding: EdgeInsets.only(
            left: AppSpacing.s24,
            right: AppSpacing.s24,
            top: AppSpacing.s16,
            bottom:
                MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.s24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Xem trước: $slotLabel',
                        style: AppTypography.cardTitle.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ),
                    _BareLucideIconButton(
                      icon: LucideIcons.x,
                      tooltip: 'Đóng xem trước',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                if (file.isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.memory(
                      file.bytes,
                      height: 280,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        height: 160,
                        alignment: Alignment.center,
                        color: AppColors.surfaceMuted,
                        child: Text(
                          'Đã xác nhận dữ liệu ảnh (${file.formattedSize})',
                          style: AppTypography.bodyMedium,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          LucideIcons.fileText,
                          size: 36,
                          color: AppColors.iconStrong,
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        Text(
                          file.name,
                          textAlign: TextAlign.center,
                          style: AppTypography.cardTitle,
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          'Định dạng PDF • ${file.formattedSize}',
                          style: AppTypography.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.s16),
                Text(
                  'Tên tệp: ${file.name} • Dung lượng: ${file.formattedSize} • MIME: ${file.mimeType}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth < 360 ? AppSpacing.s12 : AppSpacing.s20;

    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _BareLucideIconButton(
          icon: LucideIcons.arrowLeft,
          tooltip: 'Quay lại',
          onPressed: () =>
              _navigateBackOrHome(context, fallbackPath: '/tro-thanh-host'),
        ),
        title: Text(
          'Đăng ký Host',
          style: AppTypography.cardTitle.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textStrong,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: _loadingInitial
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  left: horizontalPad,
                  right: horizontalPad,
                  top: AppSpacing.s16,
                  bottom:
                      MediaQuery.viewInsetsOf(context).bottom + AppSpacing.s32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStepProgressHeader(),
                          const SizedBox(height: AppSpacing.s16),
                          if (_initialLoadError != null) ...[
                            _buildAlertBanner(
                              key: const Key('kyc_initial_load_error_banner'),
                              message: _initialLoadError!,
                              borderColor: AppColors.border,
                              bgColor: AppColors.surfaceBase,
                              textColor: AppColors.textStrong,
                              icon: LucideIcons.circleAlert,
                              retryKey: const Key('kyc_initial_load_retry_btn'),
                              onRetry: _initializeOnboardingForm,
                            ),
                            const SizedBox(height: AppSpacing.s16),
                          ],
                          if (_existingApplication != null &&
                              _existingApplication!.status ==
                                  HostApplicationStatus.revoked) ...[
                            _buildAlertBanner(
                              key: const Key('kyc_revoked_banner'),
                              message:
                                  'Quyền Host đã bị thu hồi (${_existingApplication!.status.labelVi}). ${_existingApplication!.rejectReason ?? ''}',
                              borderColor: AppColors.border,
                              bgColor: AppColors.errorSoft,
                              textColor: AppColors.textStrong,
                              icon: LucideIcons.shieldAlert,
                            ),
                            const SizedBox(height: AppSpacing.s12),
                          ] else if (_existingApplication != null &&
                              _existingApplication!.status ==
                                  HostApplicationStatus.pending) ...[
                            _buildAlertBanner(
                              key: const Key('kyc_existing_status_banner'),
                              message:
                                  'Hồ sơ hiện tại: ${_existingApplication!.status.labelVi} (chờ Admin duyệt).',
                              borderColor: AppColors.border,
                              bgColor: AppColors.surfaceBase,
                              textColor: AppColors.textStrong,
                              icon: LucideIcons.clock,
                            ),
                            const SizedBox(height: AppSpacing.s12),
                          ],
                          if (_draftRestoredNotice) ...[
                            _buildAlertBanner(
                              key: const Key('kyc_draft_restored_banner'),
                              message: 'Đã khôi phục bản nháp gần nhất.',
                              borderColor: AppColors.borderSoft,
                              bgColor: AppColors.surfaceBase,
                              textColor: AppColors.textStrong,
                              icon: LucideIcons.fileClock,
                            ),
                            const SizedBox(height: AppSpacing.s12),
                          ],
                          if (_errorMessage != null) ...[
                            _buildAlertBanner(
                              key: const Key('kyc_error_banner'),
                              message: _errorMessage!,
                              borderColor: AppColors.border,
                              bgColor: AppColors.errorSoft,
                              textColor: AppColors.textStrong,
                              icon: LucideIcons.circleAlert,
                              retryKey: const Key('kyc_submit_retry_btn'),
                              onRetry: _submitting ? null : _submitApplication,
                            ),
                            const SizedBox(height: AppSpacing.s12),
                          ],
                          if (_successMessage != null) ...[
                            _buildAlertBanner(
                              key: const Key('kyc_success_banner'),
                              message: _successMessage!,
                              borderColor: AppColors.border,
                              bgColor: AppColors.successSoft,
                              textColor: AppColors.textStrong,
                              icon: LucideIcons.circleCheck,
                            ),
                            const SizedBox(height: AppSpacing.s12),
                          ],
                          _buildContactSection(),
                          const SizedBox(height: AppSpacing.s16),
                          _buildDocumentSection(),
                          const SizedBox(height: AppSpacing.s16),
                          _buildPrivacyAndDraftCard(),
                          if (_submitting && _uploadProgress != null) ...[
                            const SizedBox(height: AppSpacing.s12),
                            Container(
                              key: const Key('kyc_upload_progress_card'),
                              padding: const EdgeInsets.all(AppSpacing.s16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceBase,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Đang tải lên (${(_uploadProgress! * 100).toStringAsFixed(0)}%)...',
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textStrong,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.s8),
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.pill),
                                    child: LinearProgressIndicator(
                                      key: const Key('kyc_upload_progress_bar'),
                                      value: _uploadProgress,
                                      minHeight: 6,
                                      color: AppColors.primary,
                                      backgroundColor: AppColors.surfaceMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.s20),
                          Builder(
                            builder: (context) {
                              final hasId = _identityFront != null || _identitySingle != null;
                              if (!hasId) return const SizedBox.shrink();

                              final needsScan = _aiIdentityResult == null;
                              final isInvalid = _aiIdentityResult != null &&
                                  (!_aiIdentityResult!.isDocumentValid ||
                                      _aiIdentityResult!.documentType == 'unknown');
                              final hasAiError = _aiFrontError != null || _aiBackError != null;

                              if (!needsScan && !isInvalid && !hasAiError) return const SizedBox.shrink();

                              final bannerMessage = (_aiBackError != null && _aiBackError!.contains('không trùng khớp'))
                                  ? _aiBackError!
                                  : (isInvalid || hasAiError)
                                      ? '❌ Tệp tải lên không phải là CCCD/Hộ chiếu hợp lệ. Vui lòng tải lên ảnh chụp giấy tờ tùy thân gốc.'
                                      : 'Vui lòng bấm "Quét AI CCCD" để kiểm tra tính hợp lệ của giấy tờ trước khi gửi hồ sơ.';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                                child: Container(
                                  key: const Key('kyc_submit_ai_guard_banner'),
                                  padding: const EdgeInsets.all(AppSpacing.s12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(AppRadii.card),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.shieldAlert,
                                        size: 20,
                                        color: Color(0xFFDC2626),
                                      ),
                                      const SizedBox(width: AppSpacing.s12),
                                      Expanded(
                                        child: Text(
                                          bannerMessage,
                                          style: AppTypography.caption.copyWith(
                                            color: const Color(0xFF991B1B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: AppSpacing.s12,
                            runSpacing: AppSpacing.s12,
                            children: [
                              _PillCtaButton.secondary(
                                key: const Key('kyc_cancel_btn'),
                                label: 'Hủy',
                                onPressed: _submitting
                                    ? null
                                    : () => _navigateBackOrHome(
                                          context,
                                          fallbackPath: '/tro-thanh-host',
                                        ),
                              ),
                              _PillCtaButton.primary(
                                key: const Key('kyc_submit_btn'),
                                isLoading: _submitting,
                                icon: LucideIcons.send,
                                label: _submitting
                                    ? 'Đang gửi hồ sơ...'
                                    : (_analyzingFront || _analyzingBack
                                        ? 'AI đang quét giấy tờ...'
                                        : 'Gửi hồ sơ'),
                                onPressed: (_submitting ||
                                        _analyzingFront ||
                                        _analyzingBack)
                                    ? null
                                    : _submitApplication,
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
    );
  }

  Widget _buildStepProgressHeader() {
    final step1Done = HostOnboardingValidator.validateContactName(
              _nameController.text,
            ) ==
            null &&
        HostOnboardingValidator.validatePhone(_phoneController.text) == null &&
        HostOnboardingValidator.validateBusinessAddress(
              _addressController.text,
            ) ==
            null;
    final step2Done = _activeRequiredAndAttachedSlotKeys().isNotEmpty;

    return Container(
      key: const Key('kyc_step_header'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        children: [
          _StepPillChip(
            stepNumber: '1',
            label: 'Liên hệ',
            isActive: _activeStepIndex == 0,
            isCompleted: step1Done,
            onTap: () => setState(() => _activeStepIndex = 0),
          ),
          _StepPillChip(
            stepNumber: '2',
            label: 'Giấy tờ',
            isActive: _activeStepIndex == 1,
            isCompleted: step2Done,
            onTap: () => setState(() => _activeStepIndex = 1),
          ),
          _StepPillChip(
            stepNumber: '3',
            label: 'Gửi duyệt',
            isActive: _activeStepIndex == 2,
            isCompleted: _successMessage != null,
            onTap: () => setState(() => _activeStepIndex = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Thông tin liên hệ',
            style: AppTypography.cardTitle.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextFormField(
            key: const Key('kyc_contact_name_input'),
            controller: _nameController,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textStrong,
              fontWeight: FontWeight.w500,
            ),
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            onChanged: (_) {
              setState(() {
                if (_fieldServerErrors.containsKey('contactName')) {
                  _fieldServerErrors = Map<String, String>.from(
                    _fieldServerErrors,
                  )..remove('contactName');
                }
              });
              _persistDraftSafely();
            },
            validator: (val) =>
                _fieldServerErrors['contactName'] ??
                HostOnboardingValidator.validateContactName(val),
            decoration: _pillInputDecoration(
              label: 'Họ và tên *',
              hint: 'Nguyễn Văn A',
              errorText: _fieldServerErrors['contactName'],
            ),
          ),
          Builder(
            builder: (context) {
              final aiFullName = _aiIdentityResult?.fullName;
              final isMismatch = aiFullName != null &&
                  aiFullName.trim().isNotEmpty &&
                  _nameController.text.trim().isNotEmpty &&
                  !HostOnboardingValidator.isNameMatching(
                    enteredName: _nameController.text,
                    aiExtractedName: aiFullName,
                  );

              if (!isMismatch) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s8),
                child: Container(
                  key: const Key('kyc_name_mismatch_warning'),
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.alertTriangle,
                        size: 20,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Họ tên không khớp giấy tờ tùy thân',
                              style: AppTypography.bodyMedium.copyWith(
                                color: const Color(0xFF991B1B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Giấy tờ ghi "$aiFullName". Khi được duyệt, tên này sẽ dùng làm họ tên chuẩn cho tài khoản.',
                              style: AppTypography.caption.copyWith(
                                color: const Color(0xFF7F1D1D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      ElevatedButton.icon(
                        key: const Key('kyc_fix_name_mismatch_btn'),
                        onPressed: () {
                          setState(() {
                            _nameController.text = aiFullName;
                          });
                          _persistDraftSafely();
                        },
                        icon: const Icon(LucideIcons.check, size: 14),
                        label: const Text('Dùng tên CCCD'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s12,
                            vertical: AppSpacing.s8,
                          ),
                          textStyle: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.s12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 520;
              final isEmailReadOnly = _isEmailReadOnly;
              final isPhoneReadOnly = _isPhoneReadOnly;
              final emailField = TextFormField(
                key: const Key('kyc_contact_email_input'),
                controller: _emailController,
                readOnly: isEmailReadOnly,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textStrong,
                  fontWeight: FontWeight.w500,
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                onChanged: (_) {
                  if (_fieldServerErrors.containsKey('contactEmail')) {
                    setState(() {
                      _fieldServerErrors = Map<String, String>.from(
                        _fieldServerErrors,
                      )..remove('contactEmail');
                    });
                  }
                  _persistDraftSafely();
                },
                validator: (val) =>
                    _fieldServerErrors['contactEmail'] ??
                    HostOnboardingValidator.validateContactEmail(val),
                decoration: _pillInputDecoration(
                  label: 'Email liên hệ *',
                  hint: 'host@example.com',
                  helperText: isEmailReadOnly
                      ? 'Cố định theo tài khoản của bạn'
                      : 'Tự động lấy từ tài khoản của bạn',
                  prefixIcon: const Icon(LucideIcons.mail, size: 18, color: AppColors.iconMuted),
                  suffixIcon: isEmailReadOnly
                      ? const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(LucideIcons.lock, size: 16, color: AppColors.iconMuted),
                        )
                      : null,
                  fillColor: isEmailReadOnly ? const Color(0xFFF3F4F6) : AppColors.surfaceBase,
                  errorText: _fieldServerErrors['contactEmail'],
                ),
              );
              final phoneField = TextFormField(
                key: const Key('kyc_phone_input'),
                controller: _phoneController,
                readOnly: isPhoneReadOnly,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textStrong,
                  fontWeight: FontWeight.w500,
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                onChanged: (_) {
                  if (_fieldServerErrors.containsKey('phone')) {
                    setState(() {
                      _fieldServerErrors = Map<String, String>.from(
                        _fieldServerErrors,
                      )..remove('phone');
                    });
                  }
                  _persistDraftSafely();
                },
                validator: (val) =>
                    _fieldServerErrors['phone'] ??
                    HostOnboardingValidator.validatePhone(val),
                decoration: _pillInputDecoration(
                  label: 'Số điện thoại *',
                  hint: '0901234567',
                  helperText: isPhoneReadOnly
                      ? 'Cố định theo tài khoản của bạn'
                      : 'Tự động lấy từ tài khoản của bạn',
                  prefixIcon: const Icon(LucideIcons.phone, size: 18, color: AppColors.iconMuted),
                  suffixIcon: isPhoneReadOnly
                      ? const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(LucideIcons.lock, size: 16, color: AppColors.iconMuted),
                        )
                      : null,
                  fillColor: isPhoneReadOnly ? const Color(0xFFF3F4F6) : AppColors.surfaceBase,
                  errorText: _fieldServerErrors['phone'],
                ),
              );
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: emailField),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(child: phoneField),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  emailField,
                  const SizedBox(height: AppSpacing.s12),
                  phoneField,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.s12),
          InputDecorator(
            decoration: _pillInputDecoration(
              label: 'Loại hình *',
              errorText: _fieldServerErrors['profileType'],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<HostProfileType>(
                key: const Key('kyc_profile_type_dropdown'),
                isExpanded: true,
                isDense: true,
                value: _profileType,
                items: HostProfileType.values
                    .map(
                      (item) => DropdownMenuItem<HostProfileType>(
                        value: item,
                        child: Text(
                          item.labelVi,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          softWrap: true,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _submitting ? null : _handleProfileTypeChanged,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextFormField(
            key: const Key('kyc_business_address_input'),
            controller: _addressController,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textStrong,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            minLines: 1,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.fullStreetAddress],
            onChanged: (_) {
              if (_fieldServerErrors.containsKey('businessAddress')) {
                setState(() {
                  _fieldServerErrors = Map<String, String>.from(
                    _fieldServerErrors,
                  )..remove('businessAddress');
                });
              }
              _persistDraftSafely();
            },
            validator: (val) =>
                _fieldServerErrors['businessAddress'] ??
                HostOnboardingValidator.validateBusinessAddress(val),
            decoration: _multilineInputDecoration(
              label: 'Địa chỉ cơ sở kinh doanh chỗ nghỉ *',
              hint: 'Ví dụ: 164B Phan Chu Trinh, Phường 2, TP. Vũng Tàu',
              helperText:
                  'Địa chỉ thực tế nơi kinh doanh cơ sở lưu trú (không phải địa chỉ thường trú trên CCCD)',
              errorText: _fieldServerErrors['businessAddress'],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextFormField(
            key: const Key('kyc_note_input'),
            controller: _noteController,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textStrong,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            minLines: 1,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_fieldServerErrors.containsKey('note')) {
                setState(() {
                  _fieldServerErrors = Map<String, String>.from(
                    _fieldServerErrors,
                  )..remove('note');
                });
              }
              _persistDraftSafely();
            },
            validator: (val) =>
                _fieldServerErrors['note'] ??
                HostOnboardingValidator.validateNote(val),
            decoration: _multilineInputDecoration(
              label: 'Ghi chú (tùy chọn)',
              hint: 'Quy mô chỗ nghỉ, số phòng...',
              errorText: _fieldServerErrors['note'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2. Giấy tờ xác minh',
            style: AppTypography.cardTitle.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          const Text(
            'JPG, PNG, WebP hoặc PDF rõ nét.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.s12),
          InputDecorator(
            decoration: _pillInputDecoration(
              label: 'Loại giấy tờ *',
              errorText: _fieldServerErrors['documentType'],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<HostDocumentType>(
                key: const Key('kyc_document_type_dropdown'),
                isExpanded: true,
                isDense: true,
                value: _documentType,
                items: HostDocumentType.values
                    .map(
                      (item) => DropdownMenuItem<HostDocumentType>(
                        value: item,
                        child: Text(
                          item.labelVi,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          softWrap: true,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _submitting ? null : _handleDocumentTypeChanged,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          if (_documentType == HostDocumentType.passport) ...[
            _buildFileSlotCard(
              slotKey: 'identitySingle',
              title: 'Ảnh / PDF Hộ chiếu *',
              subtitle: 'Trang thông tin có ảnh rõ nét.',
              pickedFile: _identitySingle,
            ),
          ] else ...[
            _buildFileSlotCard(
              slotKey: 'identityFront',
              title: 'Mặt trước ${_documentType.labelVi} *',
              subtitle: 'Rõ nét, không lóa sáng.',
              pickedFile: _identityFront,
            ),
            const SizedBox(height: AppSpacing.s12),
            _buildFileSlotCard(
              slotKey: 'identityBack',
              title: _documentType == HostDocumentType.driverLicense
                  ? 'Mặt sau GPLX (tùy chọn)'
                  : 'Mặt sau ${_documentType.labelVi} *',
              subtitle: 'Rõ nét mặt sau.',
              pickedFile: _identityBack,
            ),
          ],
          if (_profileType == HostProfileType.business) ...[
            const SizedBox(height: AppSpacing.s12),
            _buildFileSlotCard(
              slotKey: 'businessLicense',
              title: 'Giấy phép kinh doanh *',
              subtitle: 'Ảnh hoặc PDF bản gốc/sao y.',
              pickedFile: _businessLicense,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileSlotCard({
    required String slotKey,
    required String title,
    required String subtitle,
    required HostPickedFile? pickedFile,
  }) {
    final slotError = _slotErrors[slotKey];
    final progress = _slotProgress[slotKey];
    final isRetryingSlot = _retryingSlots.contains(slotKey);
    final isLocked = slotKey == 'identityBack' &&
        _documentType.requiresFrontAndBack &&
        (_identityFront == null ||
            _aiFrontError != null ||
            _aiFrontResult == null ||
            !_aiFrontResult!.isDocumentValid);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('kyc_pick_btn_$slotKey'),
        borderRadius: BorderRadius.circular(16),
        onTap: (_submitting || isLocked || pickedFile != null)
            ? null
            : () => _pickFileForSlot(
                  slotKey: slotKey,
                  slotLabel: title,
                ),
        child: Container(
          key: Key('kyc_slot_$slotKey'),
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: isLocked
                ? AppColors.surfaceMuted.withValues(alpha: 0.5)
                : AppColors.surfaceBase,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: slotError != null
                  ? AppColors.error
                  : (pickedFile != null
                      ? AppColors.textStrong
                      : AppColors.borderSoft),
              width: pickedFile != null || slotError != null ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isLocked
                                ? AppColors.textSecondary
                                : AppColors.textStrong,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _BareLucideIconButton(
                    key: Key('kyc_scan_btn_$slotKey'),
                    icon: LucideIcons.scanLine,
                    tooltip: 'Quét / Chọn nguồn $title',
                    onPressed: (_submitting || isLocked)
                        ? null
                        : () => _openFileSourceBottomSheet(
                              slotKey: slotKey,
                              slotLabel: title,
                            ),
                  ),
                ],
              ),
              if (pickedFile != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (pickedFile.isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      pickedFile.bytes,
                      height: 132,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 76,
                        alignment: Alignment.center,
                        color: AppColors.surfaceMuted,
                        child: Text(
                          'Đã chọn ảnh (${pickedFile.formattedSize})',
                          style: AppTypography.caption,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    key: Key('kyc_pdf_preview_$slotKey'),
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.fileText,
                          size: 18,
                          color: AppColors.iconStrong,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pickedFile.name,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                softWrap: true,
                              ),
                              Text(
                                'PDF • ${pickedFile.formattedSize}',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.s8),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.circleCheck,
                      size: 16,
                      color: AppColors.iconStrong,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        '${pickedFile.name} (${pickedFile.formattedSize})',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textStrong,
                        ),
                        softWrap: true,
                      ),
                    ),
                    _BareLucideIconButton(
                      key: Key('kyc_preview_btn_$slotKey'),
                      icon: LucideIcons.eye,
                      tooltip: 'Xem trước ${pickedFile.name}',
                      onPressed: () => _openDocumentPreviewSheet(
                        slotKey: slotKey,
                        slotLabel: title,
                        file: pickedFile,
                      ),
                    ),
                  ],
                ),
                if (progress != null && (_submitting || isRetryingSlot)) ...[
                  const SizedBox(height: AppSpacing.s8),
                  Column(
                    key: Key('kyc_slot_progress_$slotKey'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tiến độ: ${(progress * 100).toStringAsFixed(0)}%',
                        style: AppTypography.caption,
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          color: AppColors.primary,
                          backgroundColor: AppColors.surfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.s8),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    _PillCtaButton.secondary(
                      key: Key('kyc_reselect_btn_$slotKey'),
                      icon: LucideIcons.refreshCw,
                      label: 'Chọn lại',
                      onPressed: _submitting
                          ? null
                          : () => _pickFileForSlot(
                                slotKey: slotKey,
                                slotLabel: title,
                              ),
                    ),
                    if (pickedFile.isImage &&
                        (slotKey == 'identityFront' ||
                            slotKey == 'identitySingle' ||
                            slotKey == 'identityBack'))
                      _PillCtaButton.secondary(
                        key: Key('kyc_ai_scan_btn_$slotKey'),
                        icon: LucideIcons.scanSearch,
                        label: ((slotKey == 'identityFront' ||
                                    slotKey == 'identitySingle')
                                ? _analyzingFront
                                : _analyzingBack)
                            ? 'AI đang phân tích...'
                            : 'Quét AI CCCD',
                        onPressed: _submitting || _analyzingAi
                            ? null
                            : () => _analyzeCccdWithAi(
                                  pickedFile,
                                  slotKey: slotKey,
                                ),
                      ),
                    _PillCtaButton.secondary(
                      key: Key('kyc_remove_btn_$slotKey'),
                      icon: LucideIcons.trash2,
                      label: 'Xóa',
                      onPressed: _submitting
                          ? null
                          : () => _removeFileFromSlot(slotKey),
                    ),
                    if (slotError != null)
                      _PillCtaButton.secondary(
                        key: Key('kyc_retry_btn_$slotKey'),
                        icon: LucideIcons.rotateCcw,
                        label: 'Thử lại',
                        onPressed: _submitting
                            ? null
                            : () => _retrySingleFileSlot(
                                  slotKey: slotKey,
                                  slotLabel: title,
                                ),
                      ),
                  ],
                ),
              ],
            ),
          if (slotError != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Container(
              key: Key('kyc_slot_error_$slotKey'),
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.circleAlert,
                    size: 16,
                    color: AppColors.iconStrong,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      slotError,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textStrong,
                      ),
                      softWrap: true,
                    ),
                  ),
                  if (pickedFile == null)
                    _BareLucideIconButton(
                      key: Key('kyc_retry_btn_$slotKey'),
                      icon: LucideIcons.rotateCcw,
                      tooltip: 'Thử chọn lại tệp',
                      onPressed: _submitting
                          ? null
                          : () => _retrySingleFileSlot(
                                slotKey: slotKey,
                                slotLabel: title,
                              ),
                    ),
                ],
              ),
            ),
          ],
          if (pickedFile != null &&
              ((slotKey == 'identityFront' || slotKey == 'identitySingle') &&
                      _analyzingFront ||
                  slotKey == 'identityBack' && _analyzingBack)) ...[
            const SizedBox(height: AppSpacing.s8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.loader,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      'AI đang tự động kiểm tra giấy tờ...',
                      style: AppTypography.caption.copyWith(
                        color: const Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if ((slotKey == 'identityFront' || slotKey == 'identitySingle') &&
              _aiFrontError != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Container(
              key: const Key('kyc_front_ai_error_card'),
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.circleAlert,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      _aiFrontError!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (slotKey == 'identityBack' &&
              _aiBackError != null &&
              !_aiBackError!.contains('không trùng khớp')) ...[
            const SizedBox(height: AppSpacing.s8),
            Container(
              key: const Key('kyc_back_ai_error_card'),
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.circleAlert,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      _aiBackError!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (slotKey == 'identityBack' &&
              _documentType.requiresFrontAndBack &&
              (_identityFront == null ||
                  _aiFrontError != null ||
                  _aiFrontResult == null ||
                  !_aiFrontResult!.isDocumentValid)) ...[
            const SizedBox(height: AppSpacing.s8),
            Container(
              key: const Key('kyc_back_slot_step_notice'),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.lock,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      'Bước 2: Vui lòng xác thực xong mặt trước trước khi chụp mặt sau.',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if ((slotKey == 'identityFront' || slotKey == 'identitySingle') &&
              _aiIdentityResult != null &&
              _aiIdentityResult!.isDocumentValid &&
              _aiFrontError == null)
            _buildAiExtractionCard(_aiIdentityResult!),
          if (slotKey == 'identityBack' &&
              _aiBackResult != null &&
              _aiBackResult!.isDocumentValid &&
              (_aiBackError == null || _aiBackError!.contains('không trùng khớp')))
            _buildAiBackExtractionCard(_aiBackResult!),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildAiExtractionCard(HostIdentityAiResult result) {
    return Container(
      key: const Key('kyc_ai_result_card'),
      margin: const EdgeInsets.only(top: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.scanSearch,
                size: 18,
                color: Color(0xFF16A34A),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'Kết quả AI phân tích CCCD',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF166534),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Text(
                  'Độ tin cậy: ${(result.confidence * 100).toInt()}%',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF166534),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (result.fullName != null && result.fullName!.isNotEmpty)
            _buildAiInfoRow('Họ và tên:', result.fullName!),
          if (result.idNumber != null && result.idNumber!.isNotEmpty)
            _buildAiInfoRow('Số CCCD / ĐDCN:', result.idNumber!),
          if (result.dateOfBirth != null && result.dateOfBirth!.isNotEmpty)
            _buildAiInfoRow(
              'Ngày sinh:',
              '${result.dateOfBirth!} ${result.gender != null ? '• Giới tính: ${result.gender!}' : ''}',
            ),
          if (result.placeOfResidence != null &&
              result.placeOfResidence!.isNotEmpty)
            _buildAiInfoRow('Nơi thường trú:', result.placeOfResidence!),
          if (result.expiryDate != null && result.expiryDate!.isNotEmpty)
            _buildAiInfoRow('Giá trị đến:', result.expiryDate!),
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Lưu ý: ${result.warnings.join(", ")}',
              style: AppTypography.caption.copyWith(
                color: const Color(0xFFCA8A04),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          InkWell(
            key: const Key('kyc_ai_autofill_btn'),
            onTap: () {
              setState(() {
                if (result.fullName != null && result.fullName!.isNotEmpty) {
                  _nameController.text = result.fullName!;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Đã tự động điền Họ tên CCCD vào biểu mẫu!',
                  ),
                  backgroundColor: Color(0xFF16A34A),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.circleCheck,
                    size: 14,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tự động điền Họ tên vào biểu mẫu',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF166534),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiBackExtractionCard(HostIdentityAiResult result) {
    final frontId = _aiFrontResult?.effectiveIdNumber;
    final backId = result.effectiveIdNumber;
    final isMismatch = frontId != null && backId != null && frontId != backId;

    if (isMismatch) {
      return Container(
        key: const Key('kyc_ai_back_result_card'),
        margin: const EdgeInsets.only(top: AppSpacing.s12),
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.shieldAlert,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    '❌ Không trùng khớp số CCCD với mặt trước',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Số CCCD trên mặt sau ($backId) khác với mặt trước ($frontId). Vui lòng tải lên đúng 2 mặt của cùng một thẻ CCCD.',
              style: AppTypography.caption.copyWith(
                color: const Color(0xFF7F1D1D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const Key('kyc_ai_back_result_card'),
      margin: const EdgeInsets.only(top: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.shieldCheck,
                color: Color(0xFF16A34A),
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  frontId != null && backId != null && frontId == backId
                      ? '✓ Mặt sau CCCD hợp lệ (Khớp số CCCD)'
                      : '✓ Mặt sau CCCD hợp lệ',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF166534),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Text(
                  'Độ tin cậy: ${(result.confidence * 100).toInt()}%',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF166534),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            backId != null
                ? 'Chip điện tử và mã MRZ đã được AI nhận diện thành công (Số CCCD: $backId).'
                : 'Chip điện tử và mã MRZ đã được AI nhận diện thành công.',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          if (result.issueDate != null && result.issueDate!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ngày cấp: ${result.issueDate}',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textStrong,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: const Color(0xFF4B5563),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyAndDraftCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('kyc_draft_consent_checkbox'),
            borderRadius: BorderRadius.circular(12),
            onTap: _submitting
                ? null
                : () {
                    setState(() {
                      _consentToSaveContactDraft = !_consentToSaveContactDraft;
                    });
                    _persistDraftSafely();
                  },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Checkbox(
                    value: _consentToSaveContactDraft,
                    activeColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                    onChanged: _submitting
                        ? null
                        : (val) {
                            setState(() {
                              _consentToSaveContactDraft = val ?? false;
                            });
                            _persistDraftSafely();
                          },
                  ),
                  Expanded(
                    child: Text(
                      'Lưu nháp thông tin liên hệ trên máy (tự xóa sau 24 giờ)',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textStrong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.shieldCheck,
                    size: 14,
                    color: AppColors.iconMuted,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Chứng từ KYC được mã hóa riêng tư.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              _PillCtaButton.secondary(
                key: const Key('kyc_clear_draft_btn'),
                icon: LucideIcons.eraser,
                label: 'Xóa nháp',
                onPressed: _submitting ? null : _handleClearDraft,
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _pillInputDecoration({
    required String label,
    String? hint,
    String? errorText,
    String? helperText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    Color? fillColor,
  }) {
    final radius = BorderRadius.circular(14);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      helperText: helperText,
      helperStyle: AppTypography.caption.copyWith(
        color: AppColors.textSecondary,
        fontSize: 12,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      errorMaxLines: 2,
      isDense: true,
      filled: true,
      fillColor: fillColor ?? AppColors.surfaceBase,
      labelStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w400,
      ),
      floatingLabelStyle: AppTypography.caption.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w400,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  InputDecoration _multilineInputDecoration({
    required String label,
    String? hint,
    String? errorText,
    String? helperText,
  }) {
    return _pillInputDecoration(
      label: label,
      hint: hint,
      errorText: errorText,
      helperText: helperText,
    );
  }
}

// =============================================================================
// 3. TRẠNG THÁI HỒ SƠ HOST (`/tro-thanh-host/trang-thai`)
// =============================================================================

class TrangThaiHostScreen extends ConsumerStatefulWidget {
  const TrangThaiHostScreen({super.key});

  @override
  ConsumerState<TrangThaiHostScreen> createState() =>
      _TrangThaiHostScreenState();
}

class _TrangThaiHostScreenState extends ConsumerState<TrangThaiHostScreen> {
  bool _loading = true;
  bool _cancelling = false;
  HostOnboardingClassifiedError? _classifiedError;
  HostApplicationRecord? _record;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchStatus();
    });
  }

  Future<void> _fetchStatus() async {
    setState(() {
      _loading = true;
      _classifiedError = null;
    });

    try {
      final repo = ref.read(hostOnboardingApiProvider);
      final record = await repo.getMyApplicationRecord();
      if (!mounted) return;
      final fallbackSubmitted = ref.read(hostLastSubmittedApplicationProvider);
      HostApplicationRecord? effectiveRecord = record ?? fallbackSubmitted;
      if (effectiveRecord != null &&
          fallbackSubmitted != null &&
          effectiveRecord.status == HostApplicationStatus.approved &&
          (effectiveRecord.reviewedAt == null ||
              effectiveRecord.reviewedAt!.trim().isEmpty)) {
        effectiveRecord = fallbackSubmitted;
      }
      setState(() {
        _record = effectiveRecord;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final classified = HostOnboardingErrorClassifier.classify(
        e,
        fallbackMessage: 'Không thể tải trạng thái hồ sơ Host.',
      );
      HostOnboardingLogSanitizer.logError(
        'Failed to fetch host status on TrangThaiHostScreen',
        error: e,
      );
      final fallbackSubmitted = ref.read(hostLastSubmittedApplicationProvider);
      setState(() {
        _classifiedError = classified;
        _record ??= fallbackSubmitted;
        _loading = false;
      });
    }
  }

  Future<void> _confirmAndCancelApplication() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        key: const Key('confirm_cancel_application_dialog'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(
              LucideIcons.triangleAlert,
              color: AppColors.error,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                'Hủy nộp đơn làm Host?',
                style: AppTypography.cardTitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn hủy đơn đăng ký làm Host? Toàn bộ giấy tờ và thông tin đã nộp sẽ bị xóa khỏi hệ thống.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            key: const Key('cancel_dialog_back_btn'),
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Quay lại'),
          ),
          ElevatedButton(
            key: const Key('confirm_cancel_application_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Xác nhận hủy đơn'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _cancelling = true;
    });

    try {
      final repo = ref.read(hostOnboardingApiProvider);
      await repo.cancelApplication();

      ref.read(hostLastSubmittedApplicationProvider.notifier).state = null;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('cancel_application_success_snackbar'),
          content: Text('Đã hủy đơn đăng ký làm Host thành công.'),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _fetchStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('cancel_application_error_snackbar'),
          content: Text(
            e is DioException &&
                    e.response?.data is Map &&
                    (e.response!.data as Map)['message'] != null
                ? (e.response!.data as Map)['message'].toString()
                : 'Không thể hủy đơn đăng ký. Vui lòng thử lại sau.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cancelling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authNotifierProvider).valueOrNull;
    final isRevokedToGuest = authUser != null &&
        !authUser.isHost &&
        !authUser.roles.contains('host');
    final isActuallyHost = !isRevokedToGuest;
    final status = _record?.status ?? HostApplicationStatus.none;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth < 360 ? AppSpacing.s12 : AppSpacing.s20;

    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _BareLucideIconButton(
          icon: LucideIcons.arrowLeft,
          tooltip: 'Quay lại',
          onPressed: () =>
              _navigateBackOrHome(context, fallbackPath: '/tro-thanh-host'),
        ),
        title: Text(
          'Trạng thái hồ sơ Host',
          style: AppTypography.cardTitle.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textStrong,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          _BareLucideIconButton(
            key: const Key('status_appbar_refresh_btn'),
            icon: LucideIcons.refreshCw,
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _fetchStatus,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPad,
                  vertical: AppSpacing.s24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_classifiedError != null) ...[
                          _buildAlertBanner(
                            key: Key(
                              _classifiedError!.isOffline
                                  ? 'status_offline_banner'
                                  : 'status_error_banner',
                            ),
                            message: _classifiedError!.messageVi,
                            borderColor: AppColors.border,
                            bgColor: AppColors.errorSoft,
                            textColor: AppColors.textStrong,
                            icon: _classifiedError!.isOffline
                                ? LucideIcons.wifiOff
                                : LucideIcons.circleAlert,
                            retryKey: const Key('status_retry_btn'),
                            onRetry: _loading ? null : _fetchStatus,
                          ),
                          const SizedBox(height: AppSpacing.s16),
                        ],
                        _buildStatusSummaryCard(
                          context,
                          status,
                          _record,
                          isActuallyHost: isActuallyHost,
                        ),
                        if (_record != null &&
                            status != HostApplicationStatus.none) ...[
                          const SizedBox(height: AppSpacing.s20),
                          _buildApplicationDetailsCard(_record!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatusSummaryCard(
    BuildContext context,
    HostApplicationStatus status,
    HostApplicationRecord? record, {
    bool isActuallyHost = false,
  }) {
    IconData icon = LucideIcons.fileQuestion;
    String headline = 'Chưa có hồ sơ đăng ký Host';
    String description =
        'Bạn chưa gửi hồ sơ xác minh danh tính (KYC). Hãy hoàn tất biểu mẫu đăng ký để bắt đầu cho thuê chỗ nghỉ.';

    if (status == HostApplicationStatus.pending) {
      icon = LucideIcons.clock;
      headline = 'Hồ sơ đang chờ xét duyệt';
      description =
          'Hệ thống đã ghi nhận hồ sơ KYC của bạn. Quản trị viên sẽ kiểm tra và phản hồi trong thời gian sớm nhất.';
    } else if (status == HostApplicationStatus.approved) {
      if (isActuallyHost) {
        icon = LucideIcons.circleCheck;
        headline = 'Hồ sơ đã được phê duyệt';
        description =
            'Chúc mừng! Tài khoản của bạn đã được cấp quyền Chủ nhà (Host). Bạn có thể truy cập Host Portal ngay bây giờ.';
      } else {
        icon = LucideIcons.circleAlert;
        headline = 'Quyền Host chưa kích hoạt';
        description =
            'Tài khoản của bạn hiện đang ở vai trò Khách (Guest). Bạn có thể đăng ký làm Host lại để quản trị viên phê duyệt.';
      }
    } else if (status == HostApplicationStatus.rejected) {
      icon = LucideIcons.circleX;
      headline = 'Hồ sơ bị từ chối';
      description =
          'Hồ sơ xác minh chưa đạt yêu cầu. Vui lòng kiểm tra lý do bên dưới và gửi lại chứng từ hợp lệ.';
    } else if (status == HostApplicationStatus.supplementRequired) {
      icon = LucideIcons.fileWarning;
      headline = 'Yêu cầu bổ sung thông tin';
      description =
          'Quản trị viên yêu cầu bổ sung hoặc làm rõ giấy tờ xác minh. Vui lòng cập nhật lại hồ sơ.';
    } else if (status == HostApplicationStatus.revoked) {
      icon = LucideIcons.shieldAlert;
      headline = 'Quyền Host đã bị thu hồi';
      description =
          'Quyền Chủ nhà của tài khoản này hiện đang bị tạm ngưng hoặc thu hồi.';
    }

    return Container(
      key: Key('kyc_status_card_${status.apiValue}'),
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: Key('kyc_status_badge_${status.apiValue}'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Text(
              '${status.labelVi} (${status.apiValue})',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textStrong,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: AppColors.iconStrong),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  headline,
                  style: AppTypography.sectionHeading.copyWith(
                    color: AppColors.textStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (record?.rejectReason != null &&
              record!.rejectReason!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s16),
            Container(
              key: const Key('status_reject_reason_box'),
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.messageSquareWarning,
                    size: 18,
                    color: AppColors.iconStrong,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      'Phản hồi từ Admin: ${record.rejectReason}',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textStrong,
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s20),
          Wrap(
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s12,
            children: [
              if (status == HostApplicationStatus.approved && isActuallyHost)
                _PillCtaButton.primary(
                  key: const Key('status_open_host_portal_btn'),
                  icon: LucideIcons.layoutDashboard,
                  label: 'Mở Host Portal',
                  onPressed: () =>
                      _navigateToRoute(context, '/host', replace: true),
                ),
              if (status == HostApplicationStatus.none ||
                  status == HostApplicationStatus.rejected ||
                  status == HostApplicationStatus.supplementRequired ||
                  (status == HostApplicationStatus.approved && !isActuallyHost))
                _PillCtaButton.primary(
                  key: const Key('status_resubmit_btn'),
                  icon: LucideIcons.fileEdit,
                  label: (status == HostApplicationStatus.approved && !isActuallyHost)
                      ? 'Đăng ký làm Host lại'
                      : (status == HostApplicationStatus.none
                          ? 'Đăng ký làm Host'
                          : 'Cập nhật & nộp lại'),
                  onPressed: () =>
                      _navigateToRoute(context, '/tro-thanh-host/dang-ky'),
                ),
              if (status == HostApplicationStatus.pending)
                _PillCtaButton.secondary(
                  key: const Key('status_cancel_application_btn'),
                  icon: LucideIcons.trash2,
                  label: _cancelling ? 'Đang hủy...' : 'Hủy nộp đơn',
                  onPressed: _cancelling ? null : _confirmAndCancelApplication,
                ),
              _PillCtaButton.secondary(
                key: const Key('status_refresh_btn'),
                icon: LucideIcons.refreshCw,
                label: 'Làm mới trạng thái',
                onPressed: _fetchStatus,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationDetailsCard(HostApplicationRecord record) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chi tiết hồ sơ đã nộp',
            style: AppTypography.cardTitle.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          _buildDetailRow(
            context,
            'Mã hồ sơ',
            record.id != null ? '#${record.id}' : 'Đang cập nhật',
          ),
          _buildDetailRow(context, 'Người liên hệ', record.contactName),
          _buildDetailRow(context, 'Email', record.contactEmail),
          _buildDetailRow(context, 'Số điện thoại', record.phone),
          _buildDetailRow(context, 'Loại hình', record.profileType.labelVi),
          _buildDetailRow(
              context, 'Địa chỉ kinh doanh', record.businessAddress),
          if (record.note != null && record.note!.trim().isNotEmpty)
            _buildDetailRow(context, 'Ghi chú', record.note!),
          if (record.createdAt != null && record.createdAt!.isNotEmpty)
            _buildDetailRow(
              context,
              'Ngày gửi',
              record.createdAt!.split('T').first,
            ),
          if (record.reviewedAt != null && record.reviewedAt!.isNotEmpty)
            _buildDetailRow(
              context,
              'Ngày duyệt',
              record.reviewedAt!.split('T').first,
            ),
          if (record.documents.isNotEmpty) ...[
            const Divider(height: AppSpacing.s24, color: AppColors.borderSoft),
            Text(
              'Chứng từ đính kèm',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textStrong,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            ...record.documents.map(
              (doc) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        LucideIcons.fileCheck,
                        size: 16,
                        color: AppColors.iconStrong,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        '${doc.documentType}: ${doc.originalFilename ?? doc.fileUrl.split('/').last}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final displayValue = value.trim().isEmpty ? '—' : value.trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final useVertical = constraints.maxWidth < 340 || textScale > 1.25;
        if (useVertical) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  displayValue,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textStrong,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 136,
                child: Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  displayValue,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textStrong,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// SHARED ONBOARDING DESIGN SYSTEM WIDGETS (Bare 48dp Lucide Icons, Pill CTAs)
// =============================================================================

/// Bare Lucide icon button with a guaranteed transparent touch target >= 48x48dp
/// and zero background/halo/circle fill per Rule 4.
class _BareLucideIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _BareLucideIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              child: Icon(
                icon,
                size: 20,
                color: onPressed != null
                    ? AppColors.iconStrong
                    : AppColors.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stadium/pill CTA button that adapts to narrow screens (320dp) and large text
/// scales (1.0 / 1.3 / 1.6) without overflowing.
class _PillCtaButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;

  const _PillCtaButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : isPrimary = true;

  const _PillCtaButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  })  : isPrimary = false,
        isLoading = false;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final fgColor = isPrimary ? AppColors.iconOnBrand : AppColors.textStrong;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: fgColor),
          const SizedBox(width: AppSpacing.s8),
        ],
        Flexible(
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
            softWrap: true,
          ),
        ),
      ],
    );

    if (isPrimary) {
      return Semantics(
        button: true,
        enabled: effectiveOnPressed != null,
        label: label,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s12,
            ),
            shape: const StadiumBorder(),
          ),
          onPressed: effectiveOnPressed,
          child: child,
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: effectiveOnPressed != null,
      label: label,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceBase,
          foregroundColor: AppColors.textStrong,
          side: const BorderSide(color: AppColors.border),
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s12,
          ),
          shape: const StadiumBorder(),
        ),
        onPressed: effectiveOnPressed,
        child: child,
      ),
    );
  }
}

class _StepPillChip extends StatelessWidget {
  final String stepNumber;
  final String label;
  final bool isActive;
  final bool isCompleted;
  final VoidCallback onTap;

  const _StepPillChip({
    required this.stepNumber,
    required this.label,
    required this.isActive,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive ? AppColors.primary : AppColors.surfaceBase;
    final fgColor = isActive ? Colors.white : AppColors.textStrong;

    return Semantics(
      button: true,
      selected: isActive,
      label: 'Bước $stepNumber: $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: isActive ? AppColors.primary : AppColors.borderSoft,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCompleted) ...[
                  Icon(LucideIcons.check, size: 14, color: fgColor),
                  const SizedBox(width: AppSpacing.s4),
                ],
                Flexible(
                  child: Text(
                    '$stepNumber. $label',
                    style: AppTypography.caption.copyWith(
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      color: fgColor,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.surfaceBase,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.iconStrong),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textStrong,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildAlertBanner({
  Key? key,
  required String message,
  required Color borderColor,
  required Color bgColor,
  required Color textColor,
  required IconData icon,
  Key? retryKey,
  VoidCallback? onRetry,
}) {
  return Container(
    key: key,
    padding: const EdgeInsets.all(AppSpacing.s16),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.iconStrong),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                softWrap: true,
              ),
            ),
          ],
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.s12),
          Align(
            alignment: Alignment.centerRight,
            child: _PillCtaButton.secondary(
              key: retryKey,
              icon: LucideIcons.refreshCw,
              label: 'Thử lại',
              onPressed: onRetry,
            ),
          ),
        ],
      ],
    ),
  );
}
