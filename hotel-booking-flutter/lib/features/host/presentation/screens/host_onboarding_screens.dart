import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
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
    final isAuthenticated = _isAuthenticated;
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
            vertical: AppSpacing.s24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroCard(context, isAuthenticated, status),
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
                    _buildExistingApplicationBanner(context, _existingRecord!),
                  ],
                  const SizedBox(height: AppSpacing.s24),
                  Text(
                    'Quy trình xét duyệt minh bạch',
                    style: AppTypography.sectionHeading.copyWith(
                      color: AppColors.textStrong,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 680;
                      final cards = [
                        _buildStepCard(
                          step: '01',
                          icon: LucideIcons.userCheck,
                          title: 'Kê khai thông tin & KYC',
                          description:
                              'Cung cấp thông tin liên hệ, địa chỉ kinh doanh và tải lên giấy tờ định danh thật (CCCD, CMND, Hộ chiếu hoặc GPLX).',
                        ),
                        _buildStepCard(
                          step: '02',
                          icon: LucideIcons.shieldCheck,
                          title: 'Xét duyệt hồ sơ',
                          description:
                              'Bộ phận quản trị kiểm tra tính hợp lệ của chứng từ. Bạn có thể theo dõi trạng thái hồ sơ theo thời gian thực.',
                        ),
                        _buildStepCard(
                          step: '03',
                          icon: LucideIcons.housePlus,
                          title: 'Đăng chỗ nghỉ & Đón khách',
                          description:
                              'Sau khi được duyệt, truy cập Host Portal để tạo chỗ nghỉ, tải ảnh lên R2, phân tích nhãn AI và quản lý lịch đặt phòng.',
                        ),
                      ];
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: AppSpacing.s16),
                            Expanded(child: cards[1]),
                            const SizedBox(width: AppSpacing.s16),
                            Expanded(child: cards[2]),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          cards[0],
                          const SizedBox(height: AppSpacing.s12),
                          cards[1],
                          const SizedBox(height: AppSpacing.s12),
                          cards[2],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s24),
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
    HostApplicationStatus status,
  ) {
    final isAlreadyHost = status == HostApplicationStatus.approved;

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
          Row(
            children: [
              const Icon(
                LucideIcons.building2,
                size: 20,
                color: AppColors.iconStrong,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'ĐỐI TÁC CHỦ NHÀ VŨNG TÀU',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            'Chia sẻ không gian nghỉ dưỡng và tối ưu doanh thu cho thuê',
            style: AppTypography.displayMedium.copyWith(
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Quản lý tập trung chỗ nghỉ, lịch trống, giá theo ngày, phân tích ảnh bằng AI, đối soát doanh thu và thanh toán minh bạch.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s20),
          Wrap(
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s12,
            children: [
              if (!isAuthenticated)
                _PillCtaButton.primary(
                  key: const Key('host_landing_login_btn'),
                  icon: LucideIcons.logIn,
                  label: 'Đăng nhập để đăng ký Host',
                  onPressed: () => _navigateToRoute(context, '/dang-nhap'),
                )
              else if (isAlreadyHost)
                _PillCtaButton.primary(
                  key: const Key('host_landing_portal_btn'),
                  icon: LucideIcons.layoutDashboard,
                  label: 'Vào bảng điều khiển Host',
                  onPressed: () =>
                      _navigateToRoute(context, '/host', replace: true),
                )
              else if (status == HostApplicationStatus.pending)
                _PillCtaButton.primary(
                  key: const Key('host_landing_pending_status_btn'),
                  icon: LucideIcons.clock,
                  label: 'Xem hồ sơ đang chờ duyệt',
                  onPressed: () =>
                      _navigateToRoute(context, '/tro-thanh-host/trang-thai'),
                )
              else if (status == HostApplicationStatus.revoked)
                _PillCtaButton.primary(
                  key: const Key('host_landing_revoked_status_btn'),
                  icon: LucideIcons.shieldAlert,
                  label: 'Xem thông báo thu hồi quyền Host',
                  onPressed: () =>
                      _navigateToRoute(context, '/tro-thanh-host/trang-thai'),
                )
              else
                _PillCtaButton.primary(
                  key: const Key('host_landing_register_btn'),
                  icon: LucideIcons.filePlus,
                  label: status == HostApplicationStatus.rejected ||
                          status == HostApplicationStatus.supplementRequired
                      ? 'Cập nhật & nộp lại hồ sơ'
                      : 'Đăng ký làm Host ngay',
                  onPressed: () =>
                      _navigateToRoute(context, '/tro-thanh-host/dang-ky'),
                ),
              if (isAuthenticated)
                _PillCtaButton.secondary(
                  key: const Key('host_landing_check_status_btn'),
                  icon: LucideIcons.fileSearch,
                  label: 'Kiểm tra trạng thái',
                  onPressed: () =>
                      _navigateToRoute(context, '/tro-thanh-host/trang-thai'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExistingApplicationBanner(
    BuildContext context,
    HostApplicationRecord record,
  ) {
    final status = record.status;
    Color bgColor = AppColors.surfaceWarmSand;
    Color borderColor = AppColors.border;
    IconData icon = LucideIcons.info;

    if (status == HostApplicationStatus.pending) {
      bgColor = AppColors.warningSoft;
      icon = LucideIcons.clock;
    } else if (status == HostApplicationStatus.approved) {
      bgColor = AppColors.successSoft;
      icon = LucideIcons.circleCheck;
    } else if (status == HostApplicationStatus.rejected ||
        status == HostApplicationStatus.revoked) {
      bgColor = AppColors.errorSoft;
      icon = LucideIcons.circleX;
    } else if (status == HostApplicationStatus.supplementRequired) {
      bgColor = AppColors.warningSoft;
      icon = LucideIcons.fileWarning;
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
                  'Trạng thái hồ sơ hiện tại: ${status.labelVi}',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                  ),
                ),
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
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hồ sơ xác minh danh tính (KYC) cần chuẩn bị',
            style: AppTypography.cardTitle.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          const _RequirementRow(
            text: 'CCCD hoặc CMND: Bắt buộc ảnh mặt trước và mặt sau rõ nét.',
          ),
          const SizedBox(height: AppSpacing.s8),
          const _RequirementRow(
            text:
                'Hộ chiếu (Passport): 1 tệp ảnh hoặc PDF trang thông tin cá nhân.',
          ),
          const SizedBox(height: AppSpacing.s8),
          const _RequirementRow(
            text:
                'Giấy phép lái xe (GPLX): Bắt buộc mặt trước, mặt sau tùy chọn.',
          ),
          const SizedBox(height: AppSpacing.s8),
          const _RequirementRow(
            text:
                'Đối với Doanh nghiệp / Hộ kinh doanh: Bắt buộc đính kèm Giấy phép kinh doanh.',
          ),
          const SizedBox(height: AppSpacing.s8),
          const _RequirementRow(
            text:
                'Định dạng hỗ trợ: JPG, PNG, WebP hoặc PDF. Dung lượng tối đa 5MB mỗi tệp.',
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
            size: 16,
            color: AppColors.iconStrong,
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _noteController = TextEditingController();

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
        break;
      case 'identityBack':
        _identityBack = file;
        break;
      case 'identitySingle':
        _identitySingle = file;
        break;
      case 'businessLicense':
        _businessLicense = file;
        break;
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
                'Hỗ trợ JPG, PNG, WebP hoặc PDF (tối đa 5MB mỗi tệp).',
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
                subtitle: 'Ảnh JPG, PNG hoặc WebP dung lượng <= 5MB',
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
          'Đăng ký Host & Xác minh KYC',
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
                              bgColor: AppColors.warningSoft,
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
                                  'Quyền Chủ nhà (Host) của tài khoản này đã bị thu hồi (${_existingApplication!.status.labelVi}). ${_existingApplication!.rejectReason ?? ''}',
                              borderColor: AppColors.border,
                              bgColor: AppColors.errorSoft,
                              textColor: AppColors.textStrong,
                              icon: LucideIcons.shieldAlert,
                            ),
                            const SizedBox(height: AppSpacing.s16),
                          ] else if (_existingApplication != null &&
                              _existingApplication!.status ==
                                  HostApplicationStatus.pending) ...[
                            _buildAlertBanner(
                              key: const Key('kyc_existing_status_banner'),
                              message:
                                  'Hồ sơ của bạn hiện đang ở trạng thái: ${_existingApplication!.status.labelVi}. Không tự chuyển sang Đã phê duyệt khi chưa có xác nhận từ Admin.',
                              borderColor: AppColors.border,
                              bgColor: AppColors.warningSoft,
                              textColor: AppColors.textStrong,
                              icon: LucideIcons.clock,
                            ),
                            const SizedBox(height: AppSpacing.s16),
                          ],
                          if (_draftRestoredNotice) ...[
                            _buildAlertBanner(
                              key: const Key('kyc_draft_restored_banner'),
                              message: _consentToSaveContactDraft
                                  ? 'Đã khôi phục bản nháp thông tin liên hệ theo sự đồng ý của bạn (không lưu tệp giấy tờ nhạy cảm).'
                                  : 'Đã khôi phục tùy chọn loại hình từ bản nháp (dữ liệu cá nhân nhạy cảm không được lưu khi chưa có sự đồng ý).',
                              borderColor: AppColors.borderSoft,
                              bgColor: AppColors.surfaceWarmSand,
                              textColor: AppColors.textStrong,
                              icon: LucideIcons.fileClock,
                            ),
                            const SizedBox(height: AppSpacing.s16),
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
                            const SizedBox(height: AppSpacing.s16),
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
                            const SizedBox(height: AppSpacing.s16),
                          ],
                          _buildContactSection(),
                          const SizedBox(height: AppSpacing.s20),
                          _buildDocumentSection(),
                          const SizedBox(height: AppSpacing.s20),
                          _buildPrivacyAndDraftCard(),
                          if (_submitting && _uploadProgress != null) ...[
                            const SizedBox(height: AppSpacing.s16),
                            Container(
                              key: const Key('kyc_upload_progress_card'),
                              padding: const EdgeInsets.all(AppSpacing.s20),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceBase,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Đang tải hồ sơ lên máy chủ (${(_uploadProgress! * 100).toStringAsFixed(0)}%)...',
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
                          const SizedBox(height: AppSpacing.s24),
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
                                    : 'Nộp hồ sơ xác minh',
                                onPressed:
                                    _submitting ? null : _submitApplication,
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
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Wrap(
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        children: [
          _StepPillChip(
            stepNumber: '1',
            label: 'Thông tin liên hệ',
            isActive: _activeStepIndex == 0,
            isCompleted: step1Done,
            onTap: () => setState(() => _activeStepIndex = 0),
          ),
          _StepPillChip(
            stepNumber: '2',
            label: 'Chứng từ KYC',
            isActive: _activeStepIndex == 1,
            isCompleted: step2Done,
            onTap: () => setState(() => _activeStepIndex = 1),
          ),
          _StepPillChip(
            stepNumber: '3',
            label: 'Xác nhận & Gửi duyệt',
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
            '1. Thông tin liên hệ & Chủ thể kinh doanh',
            style: AppTypography.cardTitle.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          TextFormField(
            key: const Key('kyc_contact_name_input'),
            controller: _nameController,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            onChanged: (_) {
              if (_fieldServerErrors.containsKey('contactName')) {
                setState(() {
                  _fieldServerErrors = Map<String, String>.from(
                    _fieldServerErrors,
                  )..remove('contactName');
                });
              }
              _persistDraftSafely();
            },
            validator: (val) =>
                _fieldServerErrors['contactName'] ??
                HostOnboardingValidator.validateContactName(val),
            decoration: _pillInputDecoration(
              label: 'Họ và tên người liên hệ *',
              hint: 'Ví dụ: Nguyễn Văn A',
              errorText: _fieldServerErrors['contactName'],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 520;
              final emailField = TextFormField(
                key: const Key('kyc_contact_email_input'),
                controller: _emailController,
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
                  label: 'Email liên hệ',
                  hint: 'host@example.com',
                  errorText: _fieldServerErrors['contactEmail'],
                ),
              );
              final phoneField = TextFormField(
                key: const Key('kyc_phone_input'),
                controller: _phoneController,
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
                  hint: '0901234567 hoặc +84901234567',
                  errorText: _fieldServerErrors['phone'],
                ),
              );
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: emailField),
                    const SizedBox(width: AppSpacing.s16),
                    Expanded(child: phoneField),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  emailField,
                  const SizedBox(height: AppSpacing.s16),
                  phoneField,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.s16),
          InputDecorator(
            decoration: _pillInputDecoration(
              label: 'Loại hình đăng ký *',
              errorText: _fieldServerErrors['profileType'],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<HostProfileType>(
                key: const Key('kyc_profile_type_dropdown'),
                isExpanded: true,
                isDense: false,
                itemHeight: null,
                value: _profileType,
                items: HostProfileType.values
                    .map(
                      (item) => DropdownMenuItem<HostProfileType>(
                        value: item,
                        child: Text(
                          item.labelVi,
                          style: AppTypography.bodyMedium,
                          softWrap: true,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _submitting ? null : _handleProfileTypeChanged,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          TextFormField(
            key: const Key('kyc_business_address_input'),
            controller: _addressController,
            maxLines: 2,
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
              label: 'Địa chỉ kinh doanh / Chỗ nghỉ tại Vũng Tàu *',
              hint: 'Ví dụ: 164B Phan Chu Trinh, Phường 2, TP. Vũng Tàu',
              errorText: _fieldServerErrors['businessAddress'],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          TextFormField(
            key: const Key('kyc_note_input'),
            controller: _noteController,
            maxLines: 3,
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
              label: 'Ghi chú / Giới thiệu thêm (không bắt buộc)',
              hint: 'Thông tin bổ sung về quy mô chỗ nghỉ của bạn...',
              errorText: _fieldServerErrors['note'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection() {
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
            '2. Giấy tờ định danh & Pháp lý (Tệp thật từ thiết bị)',
            style: AppTypography.cardTitle.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          const Text(
            'Định dạng hỗ trợ: JPG, PNG, WebP hoặc PDF. Tối đa 5MB mỗi tệp.',
            style: AppTypography.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.s16),
          InputDecorator(
            decoration: _pillInputDecoration(
              label: 'Loại giấy tờ định danh *',
              errorText: _fieldServerErrors['documentType'],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<HostDocumentType>(
                key: const Key('kyc_document_type_dropdown'),
                isExpanded: true,
                isDense: false,
                itemHeight: null,
                value: _documentType,
                items: HostDocumentType.values
                    .map(
                      (item) => DropdownMenuItem<HostDocumentType>(
                        value: item,
                        child: Text(
                          item.labelVi,
                          style: AppTypography.bodyMedium,
                          softWrap: true,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _submitting ? null : _handleDocumentTypeChanged,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          if (_documentType == HostDocumentType.passport) ...[
            _buildFileSlotCard(
              slotKey: 'identitySingle',
              title: 'Ảnh / PDF Hộ chiếu (Passport) *',
              subtitle: 'Trang thông tin có ảnh và số hộ chiếu rõ nét.',
              pickedFile: _identitySingle,
            ),
          ] else ...[
            _buildFileSlotCard(
              slotKey: 'identityFront',
              title: 'Ảnh mặt trước ${_documentType.labelVi} *',
              subtitle: 'Chụp rõ nét toàn bộ mặt trước, không bị lóa sáng.',
              pickedFile: _identityFront,
            ),
            const SizedBox(height: AppSpacing.s12),
            _buildFileSlotCard(
              slotKey: 'identityBack',
              title: _documentType == HostDocumentType.driverLicense
                  ? 'Ảnh mặt sau GPLX (Tùy chọn)'
                  : 'Ảnh mặt sau ${_documentType.labelVi} *',
              subtitle: 'Chụp rõ nét mặt sau giấy tờ định danh.',
              pickedFile: _identityBack,
            ),
          ],
          if (_profileType == HostProfileType.business) ...[
            const SizedBox(height: AppSpacing.s12),
            _buildFileSlotCard(
              slotKey: 'businessLicense',
              title: 'Giấy phép đăng ký kinh doanh *',
              subtitle:
                  'Bắt buộc đối với hồ sơ Doanh nghiệp / Hộ kinh doanh (Ảnh hoặc PDF).',
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

    return Container(
      key: Key('kyc_slot_$slotKey'),
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: slotError != null
              ? AppColors.error
              : (pickedFile != null ? AppColors.textStrong : AppColors.border),
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
              _BareLucideIconButton(
                key: Key('kyc_scan_btn_$slotKey'),
                icon: LucideIcons.scanLine,
                tooltip: 'Quét / Chọn nguồn $title',
                onPressed: _submitting
                    ? null
                    : () => _openFileSourceBottomSheet(
                          slotKey: slotKey,
                          slotLabel: title,
                        ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (pickedFile == null)
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                _PillCtaButton.secondary(
                  key: Key('kyc_pick_btn_$slotKey'),
                  icon: LucideIcons.upload,
                  label: 'Chọn tệp từ thiết bị',
                  onPressed: _submitting
                      ? null
                      : () => _pickFileForSlot(
                            slotKey: slotKey,
                            slotLabel: title,
                          ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pickedFile.isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.memory(
                      pickedFile.bytes,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 88,
                        alignment: Alignment.center,
                        color: AppColors.surfaceMuted,
                        child: Text(
                          'Đã chọn tệp ảnh (${pickedFile.formattedSize})',
                          style: AppTypography.caption,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    key: Key('kyc_pdf_preview_$slotKey'),
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.fileText,
                          size: 20,
                          color: AppColors.iconStrong,
                        ),
                        const SizedBox(width: AppSpacing.s12),
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
                              const SizedBox(height: AppSpacing.s4),
                              Text(
                                'Tài liệu PDF • ${pickedFile.formattedSize}',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.s12),
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
                        'Tiến độ tải tệp: ${(progress * 100).toStringAsFixed(0)}%',
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
                        label: 'Thử lại tệp này',
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
            const SizedBox(height: AppSpacing.s12),
            Container(
              key: Key('kyc_slot_error_$slotKey'),
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(20),
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
        ],
      ),
    );
  }

  Widget _buildPrivacyAndDraftCard() {
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
            children: [
              const Icon(
                LucideIcons.shieldCheck,
                size: 18,
                color: AppColors.iconStrong,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'Bảo mật dữ liệu cá nhân & Lưu nháp',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Tệp giấy tờ định danh (CCCD/Hộ chiếu/GPKD) được tải trực tiếp lên kho lưu trữ riêng tư qua kết nối bảo mật và không bao giờ lưu plaintext lâu dài trên thiết bị.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          InkWell(
            key: const Key('kyc_draft_consent_checkbox'),
            borderRadius: BorderRadius.circular(16),
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
                      'Tôi đồng ý lưu nháp tạm thời thông tin liên hệ trên thiết bị này (tự động xóa sau 24 giờ hoặc ngay khi nộp hồ sơ).',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textStrong,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _PillCtaButton.secondary(
              key: const Key('kyc_clear_draft_btn'),
              icon: LucideIcons.eraser,
              label: 'Xóa bản nháp trên máy',
              onPressed: _submitting ? null : _handleClearDraft,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _pillInputDecoration({
    required String label,
    String? hint,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      errorMaxLines: 3,
      filled: true,
      fillColor: AppColors.surfaceBase,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  InputDecoration _multilineInputDecoration({
    required String label,
    String? hint,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      errorMaxLines: 3,
      filled: true,
      fillColor: AppColors.surfaceBase,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
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

  @override
  Widget build(BuildContext context) {
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
                        _buildStatusSummaryCard(context, status, _record),
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
    HostApplicationRecord? record,
  ) {
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
      icon = LucideIcons.circleCheck;
      headline = 'Hồ sơ đã được phê duyệt';
      description =
          'Chúc mừng! Tài khoản của bạn đã được cấp quyền Chủ nhà (Host). Bạn có thể truy cập Host Portal ngay bây giờ.';
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
              color: AppColors.surfaceWarmSand,
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
              if (status == HostApplicationStatus.approved)
                _PillCtaButton.primary(
                  key: const Key('status_open_host_portal_btn'),
                  icon: LucideIcons.layoutDashboard,
                  label: 'Mở Host Portal',
                  onPressed: () =>
                      _navigateToRoute(context, '/host', replace: true),
                ),
              if (status == HostApplicationStatus.none ||
                  status == HostApplicationStatus.rejected ||
                  status == HostApplicationStatus.supplementRequired)
                _PillCtaButton.primary(
                  key: const Key('status_resubmit_btn'),
                  icon: LucideIcons.fileEdit,
                  label: status == HostApplicationStatus.none
                      ? 'Đăng ký làm Host'
                      : 'Cập nhật & Nộp lại hồ sơ',
                  onPressed: () =>
                      _navigateToRoute(context, '/tro-thanh-host/dang-ky'),
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
    final bgColor = isActive ? AppColors.textStrong : AppColors.surfaceBase;
    final fgColor = isActive ? Colors.white : AppColors.textStrong;

    return Semantics(
      button: true,
      selected: isActive,
      label: 'Bước $stepNumber: $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: isActive ? AppColors.textStrong : AppColors.borderSoft,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCompleted) ...[
                  Icon(LucideIcons.check, size: 16, color: fgColor),
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
