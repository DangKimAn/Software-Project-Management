import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/host_repository.dart';
import '../../domain/host_models.dart';
import '../../services/host_file_picker_service.dart';

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
  bool _isAuthenticated = false;
  HostApplicationRecord? _existingRecord;
  String? _statusError;

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
      _statusError = null;
    });

    try {
      final repo = ref.read(hostRepositoryProvider);
      final record = await repo.getMyApplicationRecord();
      if (!mounted) return;
      setState(() {
        _existingRecord = record;
        _isAuthenticated = record != null;
        _loadingStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = _isAuthenticated;
    final status = _existingRecord?.status ?? HostApplicationStatus.none;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBase,
        elevation: 0,
        leading: IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
          tooltip: 'Quay lại',
        ),
        title: const Text(
          'Trở thành Chủ nhà (Host)',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (isAuthenticated)
            TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: AppColors.primary,
              ),
              onPressed: () => context.push('/tro-thanh-host/trang-thai'),
              icon: const Icon(LucideIcons.fileCheck, size: 18),
              label: const Text('Trạng thái hồ sơ'),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroCard(context, isAuthenticated, status),
                  if (_loadingStatus) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                  if (_statusError != null) ...[
                    const SizedBox(height: 16),
                    _buildAlertBanner(
                      message: _statusError!,
                      borderColor: const Color(0xFFFECDD3),
                      bgColor: const Color(0xFFFFF1F2),
                      textColor: const Color(0xFFBE123C),
                      icon: LucideIcons.circleAlert,
                    ),
                  ],
                  if (_existingRecord != null &&
                      status != HostApplicationStatus.none) ...[
                    const SizedBox(height: 16),
                    _buildExistingApplicationBanner(context, _existingRecord!),
                  ],
                  const SizedBox(height: 28),
                  const Text(
                    'Quy trình xét duyệt minh bạch',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                            const SizedBox(width: 16),
                            Expanded(child: cards[1]),
                            const SizedBox(width: 16),
                            Expanded(child: cards[2]),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          cards[0],
                          const SizedBox(height: 12),
                          cards[1],
                          const SizedBox(height: 12),
                          cards[2],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                LucideIcons.building2,
                size: 22,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ĐỐI TÁC CHỦ NHÀ VŨNG TÀU',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Chia sẻ không gian nghỉ dưỡng và tối ưu doanh thu cho thuê',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Quản lý tập trung chỗ nghỉ, lịch trống, giá theo ngày, phân tích ảnh bằng AI, đối soát doanh thu và thanh toán minh bạch.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!isAuthenticated)
                ElevatedButton.icon(
                  key: const Key('host_landing_login_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => context.push('/dang-nhap'),
                  icon: const Icon(LucideIcons.logIn, size: 18),
                  label: const Text(
                    'Đăng nhập để đăng ký Host',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                )
              else if (isAlreadyHost)
                ElevatedButton.icon(
                  key: const Key('host_landing_portal_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => context.go('/host'),
                  icon: const Icon(LucideIcons.layoutDashboard, size: 18),
                  label: const Text(
                    'Vào bảng điều khiển Host',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                )
              else if (status == HostApplicationStatus.pending)
                ElevatedButton.icon(
                  key: const Key('host_landing_pending_status_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => context.push('/tro-thanh-host/trang-thai'),
                  icon: const Icon(LucideIcons.clock, size: 18),
                  label: const Text(
                    'Xem hồ sơ đang chờ duyệt',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                )
              else
                ElevatedButton.icon(
                  key: const Key('host_landing_register_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => context.push('/tro-thanh-host/dang-ky'),
                  icon: const Icon(LucideIcons.filePlus, size: 18),
                  label: Text(
                    status == HostApplicationStatus.rejected ||
                            status == HostApplicationStatus.supplementRequired
                        ? 'Cập nhật & nộp lại hồ sơ'
                        : 'Đăng ký làm Host ngay',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              if (isAuthenticated)
                OutlinedButton.icon(
                  key: const Key('host_landing_check_status_btn'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size(160, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => context.push('/tro-thanh-host/trang-thai'),
                  icon: const Icon(LucideIcons.fileSearch, size: 18),
                  label: const Text(
                    'Kiểm tra trạng thái',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
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
    Color bgColor = const Color(0xFFF8FAFC);
    Color borderColor = AppColors.border;
    Color textColor = AppColors.textPrimary;
    IconData icon = LucideIcons.info;

    if (status == HostApplicationStatus.pending) {
      bgColor = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFFDE68A);
      textColor = const Color(0xFFB45309);
      icon = LucideIcons.clock;
    } else if (status == HostApplicationStatus.approved) {
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFFA7F3D0);
      textColor = const Color(0xFF047857);
      icon = LucideIcons.circleCheck;
    } else if (status == HostApplicationStatus.rejected ||
        status == HostApplicationStatus.revoked) {
      bgColor = const Color(0xFFFFF1F2);
      borderColor = const Color(0xFFFECDD3);
      textColor = const Color(0xFFBE123C);
      icon = LucideIcons.circleX;
    } else if (status == HostApplicationStatus.supplementRequired) {
      bgColor = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFFED7AA);
      textColor = const Color(0xFFC2410C);
      icon = LucideIcons.fileWarning;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trạng thái hồ sơ hiện tại: ${status.labelVi}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
                if (record.rejectReason != null &&
                    record.rejectReason!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Lý do: ${record.rejectReason}',
                    style: TextStyle(color: textColor, fontSize: 13),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 22, color: AppColors.textPrimary),
              Text(
                step,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hồ sơ xác minh danh tính (KYC) cần chuẩn bị',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          _RequirementRow(
            text:
                'CCCD hoặc CMND: Bắt buộc ảnh mặt trước và mặt sau rõ nét.',
          ),
          SizedBox(height: 8),
          _RequirementRow(
            text:
                'Hộ chiếu (Passport): 1 tệp ảnh hoặc PDF trang thông tin cá nhân.',
          ),
          SizedBox(height: 8),
          _RequirementRow(
            text:
                'Giấy phép lái xe (GPLX): Bắt buộc mặt trước, mặt sau tùy chọn.',
          ),
          SizedBox(height: 8),
          _RequirementRow(
            text:
                'Đối với Doanh nghiệp / Hộ kinh doanh: Bắt buộc đính kèm Giấy phép kinh doanh.',
          ),
          SizedBox(height: 8),
          _RequirementRow(
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
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
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
      _loadExistingApplication();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingApplication() async {
    setState(() {
      _loadingInitial = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(hostRepositoryProvider);
      final existing = await repo.getMyApplicationRecord();
      if (!mounted) return;
      if (existing != null && existing.status != HostApplicationStatus.none) {
        if (existing.contactName.isNotEmpty) {
          _nameController.text = existing.contactName;
        }
        if (existing.contactEmail.isNotEmpty) {
          _emailController.text = existing.contactEmail;
        }
        if (existing.phone.isNotEmpty) {
          _phoneController.text = existing.phone;
        }
        if (existing.businessAddress.isNotEmpty) {
          _addressController.text = existing.businessAddress;
        }
        if (existing.note != null && existing.note!.isNotEmpty) {
          _noteController.text = existing.note!;
        }
        _profileType = existing.profileType;
        _documentType = existing.documentType;
      }
      setState(() => _loadingInitial = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingInitial = false);
    }
  }

  Future<void> _pickFileForSlot({
    required String slotKey,
    required String slotLabel,
  }) async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final picker = ref.read(hostFilePickerProvider);
      final file = await picker.pickKycDocument(
        context: context,
        title: slotLabel,
      );
      if (file == null || !mounted) return;

      final validationErr = validateKycPickedFile(file);
      if (validationErr != null) {
        setState(() => _errorMessage = validationErr);
        return;
      }

      setState(() {
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
      });
    } catch (e) {
      if (!mounted) return;
      final repo = ref.read(hostRepositoryProvider);
      setState(() {
        _errorMessage = repo.extractErrorMessage(
          e,
          'Không thể đọc tệp đã chọn từ thiết bị.',
        );
      });
    }
  }

  void _removeFileFromSlot(String slotKey) {
    setState(() {
      _errorMessage = null;
      switch (slotKey) {
        case 'identityFront':
          _identityFront = null;
          break;
        case 'identityBack':
          _identityBack = null;
          break;
        case 'identitySingle':
          _identitySingle = null;
          break;
        case 'businessLicense':
          _businessLicense = null;
          break;
      }
    });
  }

  void _handleDocumentTypeChanged(HostDocumentType? nextType) {
    if (nextType == null || nextType == _documentType) return;
    setState(() {
      _documentType = nextType;
      _errorMessage = null;
      if (nextType == HostDocumentType.passport) {
        _identityFront = null;
        _identityBack = null;
      } else {
        _identitySingle = null;
      }
    });
  }

  void _handleProfileTypeChanged(HostProfileType? nextType) {
    if (nextType == null || nextType == _profileType) return;
    setState(() {
      _profileType = nextType;
      _errorMessage = null;
      if (nextType == HostProfileType.individual) {
        _businessLicense = null;
      }
    });
  }

  Future<void> _submitApplication() async {
    if (_submitting) return;
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

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

    final validationErr = dto.validate();
    if (validationErr != null) {
      setState(() => _errorMessage = validationErr);
      return;
    }

    setState(() {
      _submitting = true;
      _uploadProgress = 0;
    });

    try {
      final repo = ref.read(hostRepositoryProvider);
      await repo.submitKycApplication(
        dto,
        onSendProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() {
            _uploadProgress = (sent / total).clamp(0.0, 1.0);
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _uploadProgress = null;
        _successMessage = 'Đã gửi hồ sơ đăng ký Host thành công.';
      });
      context.go('/tro-thanh-host/trang-thai');
    } catch (e) {
      if (!mounted) return;
      final repo = ref.read(hostRepositoryProvider);
      setState(() {
        _submitting = false;
        _uploadProgress = null;
        _errorMessage = repo.extractErrorMessage(
          e,
          'Không thể gửi hồ sơ đăng ký Host.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBase,
        elevation: 0,
        leading: IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/tro-thanh-host'),
          tooltip: 'Quay lại',
        ),
        title: const Text(
          'Đăng ký Host & Xác minh KYC',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: _loadingInitial
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_errorMessage != null) ...[
                            _buildAlertBanner(
                              key: const Key('kyc_error_banner'),
                              message: _errorMessage!,
                              borderColor: const Color(0xFFFECDD3),
                              bgColor: const Color(0xFFFFF1F2),
                              textColor: const Color(0xFFBE123C),
                              icon: LucideIcons.circleAlert,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_successMessage != null) ...[
                            _buildAlertBanner(
                              key: const Key('kyc_success_banner'),
                              message: _successMessage!,
                              borderColor: const Color(0xFFA7F3D0),
                              bgColor: const Color(0xFFECFDF5),
                              textColor: const Color(0xFF047857),
                              icon: LucideIcons.circleCheck,
                            ),
                            const SizedBox(height: 16),
                          ],
                          _buildContactSection(),
                          const SizedBox(height: 20),
                          _buildDocumentSection(),
                          if (_submitting && _uploadProgress != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceBase,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Đang tải hồ sơ lên máy chủ (${(_uploadProgress! * 100).toStringAsFixed(0)}%)...',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: _uploadProgress,
                                    minHeight: 6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(120, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _submitting
                                    ? null
                                    : () => context.canPop()
                                        ? context.pop()
                                        : context.go('/tro-thanh-host'),
                                child: const Text('Hủy'),
                              ),
                              ElevatedButton.icon(
                                key: const Key('kyc_submit_btn'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(180, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed:
                                    _submitting ? null : _submitApplication,
                                icon: _submitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(LucideIcons.send, size: 18),
                                label: Text(
                                  _submitting
                                      ? 'Đang gửi hồ sơ...'
                                      : 'Nộp hồ sơ xác minh',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Thông tin liên hệ & Chủ thể kinh doanh',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('kyc_contact_name_input'),
            controller: _nameController,
            decoration: _inputDecoration(
              label: 'Họ và tên người liên hệ *',
              hint: 'Ví dụ: Nguyễn Văn A',
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 520;
              final emailField = TextFormField(
                key: const Key('kyc_contact_email_input'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  label: 'Email liên hệ',
                  hint: 'host@example.com',
                ),
              );
              final phoneField = TextFormField(
                key: const Key('kyc_phone_input'),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(
                  label: 'Số điện thoại *',
                  hint: '0901234567 hoặc +84901234567',
                ),
              );
              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: emailField),
                    const SizedBox(width: 14),
                    Expanded(child: phoneField),
                  ],
                );
              }
              return Column(
                children: [
                  emailField,
                  const SizedBox(height: 14),
                  phoneField,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          InputDecorator(
            decoration: _inputDecoration(label: 'Loại hình đăng ký *'),
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
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _handleProfileTypeChanged,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('kyc_business_address_input'),
            controller: _addressController,
            maxLines: 2,
            decoration: _inputDecoration(
              label: 'Địa chỉ kinh doanh / Chỗ nghỉ tại Vũng Tàu *',
              hint: 'Ví dụ: 164B Phan Chu Trinh, Phường 2, TP. Vũng Tàu',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('kyc_note_input'),
            controller: _noteController,
            maxLines: 3,
            decoration: _inputDecoration(
              label: 'Ghi chú / Giới thiệu thêm (không bắt buộc)',
              hint: 'Thông tin bổ sung về quy mô chỗ nghỉ của bạn...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2. Giấy tờ định danh & Pháp lý (Tệp thật từ thiết bị)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Định dạng hỗ trợ: JPG, PNG, WebP hoặc PDF. Tối đa 5MB mỗi tệp.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: _inputDecoration(label: 'Loại giấy tờ định danh *'),
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
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _handleDocumentTypeChanged,
              ),
            ),
          ),
          const SizedBox(height: 16),
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
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
    return Container(
      key: Key('kyc_slot_$slotKey'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pickedFile != null ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (pickedFile == null)
            OutlinedButton.icon(
              key: Key('kyc_pick_btn_$slotKey'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(160, 48),
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _submitting
                  ? null
                  : () => _pickFileForSlot(
                        slotKey: slotKey,
                        slotLabel: title,
                      ),
              icon: const Icon(LucideIcons.upload, size: 18),
              label: const Text('Chọn tệp từ thiết bị'),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pickedFile.isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      pickedFile.bytes,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 80,
                        alignment: Alignment.center,
                        color: const Color(0xFFE2E8F0),
                        child: const Text(
                          'Đã chọn tệp ảnh',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBase,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.fileText,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pickedFile.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.circleCheck,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${pickedFile.name} (${pickedFile.formattedSize})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: Key('kyc_reselect_btn_$slotKey'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(110, 48),
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      onPressed: _submitting
                          ? null
                          : () => _pickFileForSlot(
                                slotKey: slotKey,
                                slotLabel: title,
                              ),
                      icon: const Icon(LucideIcons.refreshCw, size: 16),
                      label: const Text('Chọn lại'),
                    ),
                    OutlinedButton.icon(
                      key: Key('kyc_remove_btn_$slotKey'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(100, 48),
                        foregroundColor: const Color(0xFFBE123C),
                        side: const BorderSide(color: Color(0xFFFECDD3)),
                      ),
                      onPressed: _submitting
                          ? null
                          : () => _removeFileFromSlot(slotKey),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      label: const Text('Xóa'),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
  String? _error;
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
      _error = null;
    });

    try {
      final repo = ref.read(hostRepositoryProvider);
      final record = await repo.getMyApplicationRecord();
      if (!mounted) return;
      setState(() {
        _record = record;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final repo = ref.read(hostRepositoryProvider);
      setState(() {
        _error = repo.extractErrorMessage(
          e,
          'Không thể tải trạng thái hồ sơ Host.',
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _record?.status ?? HostApplicationStatus.none;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBase,
        elevation: 0,
        leading: IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/tro-thanh-host'),
          tooltip: 'Quay lại',
        ),
        title: const Text(
          'Trạng thái hồ sơ Host',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: _loading ? null : _fetchStatus,
            icon: const Icon(
              LucideIcons.refreshCw,
              size: 18,
              color: AppColors.textPrimary,
            ),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) ...[
                          _buildAlertBanner(
                            message: _error!,
                            borderColor: const Color(0xFFFECDD3),
                            bgColor: const Color(0xFFFFF1F2),
                            textColor: const Color(0xFFBE123C),
                            icon: LucideIcons.circleAlert,
                          ),
                          const SizedBox(height: 16),
                        ],
                        _buildStatusSummaryCard(context, status, _record),
                        if (_record != null &&
                            status != HostApplicationStatus.none) ...[
                          const SizedBox(height: 20),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: AppColors.textPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (record?.rejectReason != null &&
              record!.rejectReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.messageSquareWarning,
                    size: 18,
                    color: Color(0xFFBE123C),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Phản hồi từ Admin: ${record.rejectReason}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFBE123C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (status == HostApplicationStatus.approved)
                ElevatedButton.icon(
                  key: const Key('status_open_host_portal_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => context.go('/host'),
                  icon: const Icon(LucideIcons.layoutDashboard, size: 18),
                  label: const Text('Mở Host Portal'),
                ),
              if (status == HostApplicationStatus.none ||
                  status == HostApplicationStatus.rejected ||
                  status == HostApplicationStatus.supplementRequired)
                ElevatedButton.icon(
                  key: const Key('status_resubmit_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => context.push('/tro-thanh-host/dang-ky'),
                  icon: const Icon(LucideIcons.fileEdit, size: 18),
                  label: Text(
                    status == HostApplicationStatus.none
                        ? 'Đăng ký làm Host'
                        : 'Cập nhật & Nộp lại hồ sơ',
                  ),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(140, 48),
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _fetchStatus,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Làm mới trạng thái'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationDetailsCard(HostApplicationRecord record) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi tiết hồ sơ đã nộp',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _buildDetailRow('Mã hồ sơ', record.id != null ? '#${record.id}' : 'Đang cập nhật'),
          _buildDetailRow('Người liên hệ', record.contactName),
          _buildDetailRow('Email', record.contactEmail),
          _buildDetailRow('Số điện thoại', record.phone),
          _buildDetailRow('Loại hình', record.profileType.labelVi),
          _buildDetailRow('Địa chỉ kinh doanh', record.businessAddress),
          if (record.note != null && record.note!.trim().isNotEmpty)
            _buildDetailRow('Ghi chú', record.note!),
          if (record.createdAt != null && record.createdAt!.isNotEmpty)
            _buildDetailRow('Ngày gửi', record.createdAt!.split('T').first),
          if (record.reviewedAt != null && record.reviewedAt!.isNotEmpty)
            _buildDetailRow('Ngày duyệt', record.reviewedAt!.split('T').first),
          if (record.documents.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'Chứng từ đính kèm',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...record.documents.map(
              (doc) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.fileCheck,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${doc.documentType}: ${doc.originalFilename ?? doc.fileUrl.split('/').last}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
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
}) {
  return Container(
    key: key,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: textColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    ),
  );
}
