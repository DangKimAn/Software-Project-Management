import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../../booking_inquiry/domain/services/contact_service.dart';

/// Complete port of `Source goc/frontend/src/views/pages/Trips/index.tsx` (`ProfilePage`, `ProfileSummaryCard`,
/// `ProfileInfoList`, `EditProfileModal`) + App Settings & Language switcher.
///
/// Fixes BUG-22:
/// - Persists `school`, `location`, `job`, `dreamDestination`, `languages`, `bio`, `phone`, `fullName` to backend via `PATCH /api/users/me`.
/// - Updates avatar via `PATCH /api/users/me/avatar` (`authNotifier.updateAvatar`) and renders backend `user.avatarUrl`.
/// - Displays real identity verification status from `user.isVerified` (`Đã xác minh` vs `Chưa xác minh`), never hardcoded.
/// - Never fakes success via SharedPreferences when backend API fails; shows real error and preserves user's draft input for retry.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _ProfileDraftData {
  final String userId;
  final String fullName;
  final String phone;
  final String bio;
  final String location;
  final String dreamDestination;
  final String job;
  final String school;
  final String languages;
  final String avatarUrl;

  const _ProfileDraftData({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.bio,
    required this.location,
    required this.dreamDestination,
    required this.job,
    required this.school,
    required this.languages,
    required this.avatarUrl,
  });
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _ProfileDraftData? _unsavedDraft;

  List<String> _parseLanguagesInput(String raw) {
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _openAvatarUpdateModal(User user) async {
    final avatarCtrl = TextEditingController(
      text: _unsavedDraft?.userId == user.id
          ? _unsavedDraft!.avatarUrl
          : (user.avatarUrl ?? ''),
    );
    bool isSaving = false;
    String? modalError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submitAvatar() async {
              final url = avatarCtrl.text.trim();
              if (url.isEmpty) {
                setModalState(() {
                  modalError = 'Vui lòng nhập URL ảnh đại diện hợp lệ.';
                });
                return;
              }
              setModalState(() {
                isSaving = true;
                modalError = null;
              });

              try {
                await ref
                    .read(authNotifierProvider.notifier)
                    .updateAvatar(url: url);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã cập nhật ảnh đại diện thành công.'),
                    ),
                  );
                }
              } catch (e) {
                if (!ctx.mounted) return;
                setModalState(() {
                  isSaving = false;
                  modalError = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Cập nhật ảnh đại diện',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton(
                            onPressed:
                                isSaving ? null : () => Navigator.of(ctx).pop(),
                            icon: const Icon(
                              LucideIcons.x,
                              size: 20,
                              color: AppColors.iconStrong,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (modalError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.errorSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Text(
                          modalError!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    TextField(
                      controller: avatarCtrl,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'URL ảnh đại diện (https://...)',
                        hintText: 'https://example.com/avatar.jpg',
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: ElevatedButton(
                          onPressed: isSaving ? null : submitAvatar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            isSaving ? 'Đang tải lên...' : 'Lưu ảnh đại diện',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openEditProfileModal(User user) async {
    final draft = (_unsavedDraft != null && _unsavedDraft!.userId == user.id)
        ? _unsavedDraft
        : null;

    final fullNameCtrl = TextEditingController(
      text: draft?.fullName ?? user.fullName,
    );
    final phoneCtrl = TextEditingController(
      text: draft?.phone ?? user.phoneNumber ?? '',
    );
    final bioCtrl = TextEditingController(
      text: draft?.bio ?? user.bio ?? '',
    );
    final locationCtrl = TextEditingController(
      text: draft?.location ?? user.location ?? '',
    );
    final dreamDestinationCtrl = TextEditingController(
      text: draft?.dreamDestination ?? user.dreamDestination ?? '',
    );
    final jobCtrl = TextEditingController(
      text: draft?.job ?? user.job ?? '',
    );
    final schoolCtrl = TextEditingController(
      text: draft?.school ?? user.school ?? '',
    );
    final languagesCtrl = TextEditingController(
      text: draft?.languages ??
          (user.languages.isNotEmpty ? user.languages.join(', ') : ''),
    );
    final avatarUrlCtrl = TextEditingController(
      text: draft?.avatarUrl ?? user.avatarUrl ?? '',
    );

    bool isSubmitting = false;
    String? errorMessage;

    void snapshotDraft() {
      _unsavedDraft = _ProfileDraftData(
        userId: user.id,
        fullName: fullNameCtrl.text,
        phone: phoneCtrl.text,
        bio: bioCtrl.text,
        location: locationCtrl.text,
        dreamDestination: dreamDestinationCtrl.text,
        job: jobCtrl.text,
        school: schoolCtrl.text,
        languages: languagesCtrl.text,
        avatarUrl: avatarUrlCtrl.text,
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> handleSave() async {
              final trimmedName = fullNameCtrl.text.trim();
              if (trimmedName.isEmpty) {
                setModalState(() {
                  errorMessage = 'Họ và tên không được để trống.';
                });
                return;
              }

              snapshotDraft();
              setModalState(() {
                isSubmitting = true;
                errorMessage = null;
              });

              try {
                final newAvatarUrl = avatarUrlCtrl.text.trim();
                final oldAvatarUrl = (user.avatarUrl ?? '').trim();
                final parsedLanguages =
                    _parseLanguagesInput(languagesCtrl.text);

                if (newAvatarUrl.isNotEmpty && newAvatarUrl != oldAvatarUrl) {
                  await ref
                      .read(authNotifierProvider.notifier)
                      .updateAvatar(url: newAvatarUrl);
                }

                final updatedUser = await ref
                    .read(authNotifierProvider.notifier)
                    .updateProfile(
                      fullName: trimmedName,
                      phone: phoneCtrl.text.trim(),
                      bio: bioCtrl.text.trim(),
                      location: locationCtrl.text.trim(),
                      job: jobCtrl.text.trim(),
                      dreamDestination: dreamDestinationCtrl.text.trim(),
                      school: schoolCtrl.text.trim(),
                      languages: parsedLanguages,
                      avatarUrl: newAvatarUrl.isNotEmpty ? newAvatarUrl : null,
                    );

                final prefs = ref.read(preferencesServiceProvider);
                await prefs.saveAccountProfile(updatedUser.id, {
                  'fullName': updatedUser.fullName,
                  'phone': updatedUser.phone ?? '',
                  'bio': updatedUser.bio ?? '',
                  'location': updatedUser.location ?? '',
                  'job': updatedUser.job ?? '',
                  'dreamDestination': updatedUser.dreamDestination ?? '',
                  'school': updatedUser.school ?? '',
                  'languages': updatedUser.languages.join(', '),
                });

                _unsavedDraft = null;
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã cập nhật hồ sơ thành công.'),
                    ),
                  );
                }
              } catch (e) {
                if (!ctx.mounted) return;
                setModalState(() {
                  isSubmitting = false;
                  errorMessage = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Chỉnh sửa hồ sơ cá nhân',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton(
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    snapshotDraft();
                                    Navigator.of(ctx).pop();
                                  },
                            icon: const Icon(
                              LucideIcons.x,
                              size: 20,
                              color: AppColors.iconStrong,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.errorSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              LucideIcons.circleAlert,
                              size: 18,
                              color: AppColors.iconStrong,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    TextField(
                      controller: fullNameCtrl,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Họ và tên *',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: avatarUrlCtrl,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'URL ảnh đại diện (Avatar URL)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationCtrl,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Nơi sinh sống',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dreamDestinationCtrl,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Nơi tôi luôn muốn đến',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: jobCtrl,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Công việc / Nghề nghiệp',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: schoolCtrl,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Trường học',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: languagesCtrl,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText:
                            'Ngôn ngữ giao tiếp (phân cách bằng dấu phẩy)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bioCtrl,
                      enabled: !isSubmitting,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Giới thiệu bản thân',
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            isSubmitting ? 'Đang lưu...' : 'Lưu thay đổi',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _displayValue(String? primary, [String fallback = 'Chưa cập nhật']) {
    if (primary != null && primary.trim().isNotEmpty) {
      return primary.trim();
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(localeProvider);
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hồ sơ & Tài khoản'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Account Profile Section (`ProfileSummaryCard` + `ProfileInfoList`)
            _buildSectionHeader('Hồ sơ cá nhân'),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: user != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(32),
                                  onTap: () => _openAvatarUpdateModal(user),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        alignment: Alignment.center,
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceWarmSand,
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          border: Border.all(
                                              color: AppColors.borderWarm),
                                        ),
                                        child: (user.avatarUrl != null &&
                                                user.avatarUrl!
                                                    .trim()
                                                    .isNotEmpty)
                                            ? AppImage(
                                                url: user.avatarUrl!.trim(),
                                                fit: BoxFit.cover,
                                              )
                                            : Text(
                                                user.firstName.isNotEmpty
                                                    ? user.firstName[0]
                                                        .toUpperCase()
                                                    : 'U',
                                                style: AppTypography
                                                    .displayMedium
                                                    .copyWith(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 22,
                                                ),
                                              ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(11),
                                            border: Border.all(
                                              color: AppColors.borderSoft,
                                            ),
                                          ),
                                          child: const Icon(
                                            LucideIcons.camera,
                                            size: 12,
                                            color: AppColors.iconStrong,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 220),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.fullName,
                                        style: AppTypography.cardTitle,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user.email,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceWarmSand,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          user.isAdmin
                                              ? 'Quản trị viên (Admin)'
                                              : (user.isHost
                                                  ? 'Chủ nhà (Host)'
                                                  : 'Khách lưu trú'),
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(minHeight: 48),
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _openAvatarUpdateModal(user),
                                    icon: const Icon(
                                      LucideIcons.camera,
                                      size: 15,
                                      color: AppColors.iconStrong,
                                    ),
                                    label: const Text('Đổi ảnh'),
                                  ),
                                ),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(minHeight: 48),
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _openEditProfileModal(user),
                                    icon: const Icon(
                                      LucideIcons.pencil,
                                      size: 15,
                                      color: AppColors.iconStrong,
                                    ),
                                    label: const Text('Sửa hồ sơ'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: AppColors.divider),
                        _ProfileDetailRow(
                          icon: LucideIcons.phone,
                          label: 'Điện thoại',
                          value: _displayValue(user.phoneNumber),
                        ),
                        _ProfileDetailRow(
                          icon: LucideIcons.mapPin,
                          label: 'Nơi sinh sống',
                          value: _displayValue(user.location),
                        ),
                        _ProfileDetailRow(
                          icon: LucideIcons.briefcaseBusiness,
                          label: 'Công việc của tôi',
                          value: _displayValue(user.job),
                        ),
                        _ProfileDetailRow(
                          icon: LucideIcons.mapPinned,
                          label: 'Nơi tôi luôn muốn đến',
                          value: _displayValue(user.dreamDestination),
                        ),
                        _ProfileDetailRow(
                          icon: LucideIcons.graduationCap,
                          label: 'Nơi tôi từng theo học',
                          value: _displayValue(user.school),
                        ),
                        _ProfileDetailRow(
                          icon: LucideIcons.languages,
                          label: 'Ngôn ngữ của tôi',
                          value: user.languages.isNotEmpty
                              ? user.languages.join(', ')
                              : 'Chưa cập nhật',
                        ),
                        _ProfileDetailRow(
                          icon: user.isVerified
                              ? LucideIcons.badgeCheck
                              : LucideIcons.shieldAlert,
                          label: 'Xác minh danh tính',
                          value:
                              user.isVerified ? 'Đã xác minh' : 'Chưa xác minh',
                        ),
                        if (user.bio != null &&
                            user.bio!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            user.bio!.trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: TextButton.icon(
                              onPressed: () async {
                                _unsavedDraft = null;
                                await ref
                                    .read(authNotifierProvider.notifier)
                                    .logout();
                              },
                              icon: const Icon(
                                LucideIcons.logOut,
                                size: 16,
                                color: AppColors.iconStrong,
                              ),
                              label: const Text('Đăng xuất tài khoản'),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.userRound,
                              color: AppColors.iconStrong,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Chưa đăng nhập',
                                      style: AppTypography.cardTitle),
                                  Text(
                                    'Đăng nhập để xem kỳ nghỉ, tin nhắn và đồng bộ yêu thích',
                                    style: AppTypography.caption
                                        .copyWith(color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () => context.push('/dang-nhap'),
                              child: const Text('Đăng nhập / Đăng ký'),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 24),

            // Quick Portals & Features Navigation
            _buildSectionHeader('Tiện ích & Cổng quản lý'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.planeTakeoff,
                        color: AppColors.iconStrong),
                    title: const Text('Chuyến đi của tôi'),
                    subtitle:
                        const Text('Quản lý đặt phòng, thanh toán & đánh giá'),
                    trailing: const Icon(LucideIcons.chevronRight,
                        size: 18, color: AppColors.iconMuted),
                    onTap: () => context.push('/account/trips'),
                  ),
                  const Divider(height: 1, color: AppColors.borderSoft),
                  ListTile(
                    leading: const Icon(LucideIcons.messageSquare,
                        color: AppColors.iconStrong),
                    title: const Text('Tin nhắn với Chủ nhà'),
                    subtitle:
                        const Text('Trò chuyện thời gian thực (Socket.IO)'),
                    trailing: const Icon(LucideIcons.chevronRight,
                        size: 18, color: AppColors.iconMuted),
                    onTap: () => context.push('/messages'),
                  ),
                  const Divider(height: 1, color: AppColors.borderSoft),
                  ListTile(
                    leading: const Icon(LucideIcons.shoppingCart,
                        color: AppColors.iconStrong),
                    title: const Text('Giỏ chờ đặt nhiều căn'),
                    subtitle: const Text('Đặt cùng lúc tối đa 5 căn biệt thự'),
                    trailing: const Icon(LucideIcons.chevronRight,
                        size: 18, color: AppColors.iconMuted),
                    onTap: () => context.push('/gio-cho-dat'),
                  ),
                  const Divider(height: 1, color: AppColors.borderSoft),
                  ListTile(
                    leading: const Icon(LucideIcons.house,
                        color: AppColors.iconStrong),
                    title: Text(
                      user != null && user.isHost
                          ? 'Kênh Chủ nhà (Host Portal)'
                          : 'Đăng ký trở thành Chủ nhà (Host)',
                    ),
                    subtitle: const Text(
                        'Quản lý chỗ nghỉ, lịch phòng, doanh thu & rút tiền'),
                    trailing: const Icon(LucideIcons.chevronRight,
                        size: 18, color: AppColors.iconMuted),
                    onTap: () {
                      if (user != null && user.isHost) {
                        context.push('/chu-nha/cho-nghi');
                      } else {
                        context.push('/tro-thanh-host');
                      }
                    },
                  ),
                  if (user != null && user.isAdmin) ...[
                    const Divider(height: 1, color: AppColors.borderSoft),
                    ListTile(
                      leading: const Icon(LucideIcons.shieldCheck,
                          color: AppColors.iconStrong),
                      title: const Text('Quản trị hệ thống (Admin Portal)'),
                      subtitle: const Text(
                          'Tổng quan, người dùng, kiểm duyệt bài đăng & hồ sơ Host'),
                      trailing: const Icon(LucideIcons.chevronRight,
                          size: 18, color: AppColors.iconMuted),
                      onTap: () => context.push('/admin'),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Language section
            _buildSectionHeader('Ngôn ngữ / Language / 언어'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Column(
                children: [
                  _buildLanguageTile(
                    title: 'Tiếng Việt',
                    subtitle: 'Mặc định',
                    isSelected: currentLocale == 'vi',
                    onTap: () =>
                        ref.read(localeProvider.notifier).setLocale('vi'),
                  ),
                  const Divider(height: 1, color: AppColors.borderSoft),
                  _buildLanguageTile(
                    title: 'English',
                    subtitle: 'International',
                    isSelected: currentLocale == 'en',
                    onTap: () =>
                        ref.read(localeProvider.notifier).setLocale('en'),
                  ),
                  const Divider(height: 1, color: AppColors.borderSoft),
                  _buildLanguageTile(
                    title: '한국어',
                    subtitle: 'Korean',
                    isSelected: currentLocale == 'ko',
                    onTap: () =>
                        ref.read(localeProvider.notifier).setLocale('ko'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Environment & Technical Info
            _buildSectionHeader('Thông tin môi trường ứng dụng'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                      'Môi trường', AppConfig.environment.toUpperCase(),
                      isBadge: true),
                  const SizedBox(height: 12),
                  _buildInfoRow('Phiên bản', '1.0.0 (Build 1)'),
                  const SizedBox(height: 12),
                  _buildInfoRow('API Endpoint', AppConfig.apiBaseUrl),
                  const SizedBox(height: 12),
                  _buildInfoRow('Hotline', AppConfig.hotlineNumber),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Support & Contact
            _buildSectionHeader('Hỗ trợ trực tiếp'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.phone,
                        color: AppColors.iconStrong),
                    title: const Text('Gọi tổng đài tư vấn'),
                    subtitle: const Text(AppConfig.hotlineNumber),
                    trailing: const Icon(LucideIcons.chevronRight,
                        size: 18, color: AppColors.iconMuted),
                    onTap: () => ContactService.callHotline(),
                  ),
                  const Divider(height: 1, color: AppColors.borderSoft),
                  ListTile(
                    leading: const Icon(LucideIcons.messageCircle,
                        color: AppColors.iconStrong),
                    title: const Text('Nhắn tin qua Zalo OA'),
                    subtitle: const Text('Hỗ trợ khách hàng 24/7'),
                    trailing: const Icon(LucideIcons.chevronRight,
                        size: 18, color: AppColors.iconMuted),
                    onTap: () {
                      ContactService.openZaloInquiry(
                        messageText:
                            'Xin chào VungTau Stay, tôi cần hỗ trợ thông tin ứng dụng.',
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildLanguageTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title,
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: AppTypography.caption),
      trailing: isSelected
          ? const Icon(LucideIcons.check, color: AppColors.iconStrong, size: 20)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBadge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.textMuted)),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          Flexible(
            child: Text(
              value,
              style: AppTypography.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.iconMuted),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
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
