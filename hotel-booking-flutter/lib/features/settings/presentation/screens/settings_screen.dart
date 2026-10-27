import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../../booking_inquiry/domain/services/contact_service.dart';
import '../../domain/account_profile_models.dart';
import '../../services/avatar_upload_service.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/widgets/global_pending_booking_banner.dart';
import '../view_models/account_settings_view_model.dart';

/// Account & Settings tab (`Hồ sơ & Tài khoản`).
///
/// Implements full parity with `Source goc/frontend/src/views/pages/Trips/index.tsx`:
/// - Supports `logged-out`, `guest`, `host` (`user.isHost` / `user.isNewHost`), and `admin` modes.
/// - Handles async states (`loading`, `success`, `empty`, `error`, `offline`, `401/403`) with real retry.
/// - Synchronizes profile via `GET /api/auth/me` & `GET /api/users/me` and updates via `PATCH /api/users/me`.
/// - Uploads avatar from device via `POST /api/uploads/presign` (`folder: 'avatars'`) + R2 `PUT` + `PATCH /api/users/me/avatar`.
/// - Displays real `user.isVerified` status (never hardcoded).
/// - Preserves unsaved draft per `userId` on 422/500/offline, prevents double-submit, never fakes local-only success,
///   and isolates PII across account switches.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  ProfileDraftData? _unsavedDraft;
  String? _activeUserId;

  void _enforceUserIsolation(User? currentUser) {
    final newUserId = currentUser?.id;
    if (_activeUserId != newUserId) {
      if (_unsavedDraft != null && _unsavedDraft!.userId != newUserId) {
        _unsavedDraft = null;
      }
      _activeUserId = newUserId;
    }
  }

  Widget _buildCleanProfileField({
    required Key fieldKey,
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    String? errorText,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    int maxLines = 1,
    int? minLines,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            labelText,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          TextField(
            key: fieldKey,
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            maxLines: maxLines,
            minLines: minLines,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textStrong,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              hintText: hintText,
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              errorText: errorText,
              errorMaxLines: 3,
              contentPadding: const EdgeInsets.only(top: 6, bottom: 10),
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider, width: 1),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider, width: 1),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(
                  color: AppColors.textStrong,
                  width: 1.5,
                ),
              ),
              errorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.error, width: 1),
              ),
              focusedErrorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.error, width: 1.5),
              ),
              disabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.borderSoft, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRetrySync() async {
    await ref.read(accountSyncNotifierProvider.notifier).refreshProfile();
  }

  void _navigateProtectedRoute(
    BuildContext context,
    String targetPath,
    User? user,
  ) {
    if (user == null) {
      final loginUri = Uri(
        path: '/dang-nhap',
        queryParameters: <String, String>{'redirectTo': targetPath},
      );
      context.push(loginUri.toString());
      return;
    }
    context.push(targetPath);
  }

  Future<bool> _confirmSensitivePhoneChange(
    BuildContext parentContext, {
    required String oldPhone,
    required String newPhone,
  }) async {
    final confirmed = await showDialog<bool>(
      context: parentContext,
      builder: (dialogCtx) {
        return AlertDialog(
          key: const Key('sensitive_change_confirm_dialog'),
          backgroundColor: AppColors.surfaceBase,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.modal),
          ),
          title: const Text(
            'Xác nhận thay đổi số điện thoại',
            style: AppTypography.sectionHeading,
          ),
          content: Text(
            newPhone.isEmpty
                ? 'Bạn sắp xóa số điện thoại liên hệ đã lưu ($oldPhone). Bạn có chắc chắn muốn tiếp tục?'
                : 'Bạn sắp thay đổi số điện thoại liên hệ từ $oldPhone sang $newPhone. Bạn có chắc chắn muốn lưu thay đổi này?',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: OutlinedButton(
                key: const Key('sensitive_change_cancel_btn'),
                style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Kiểm tra lại'),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: FilledButton(
                key: const Key('sensitive_change_confirm_btn'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Xác nhận lưu'),
              ),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _confirmAndLogout(User user) async {
    final hasUnsaved =
        _unsavedDraft != null && _unsavedDraft!.userId == user.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          key: const Key('logout_confirm_dialog'),
          backgroundColor: AppColors.surfaceBase,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.modal),
          ),
          title: const Text(
            'Xác nhận đăng xuất',
            style: AppTypography.sectionHeading,
          ),
          content: Text(
            hasUnsaved
                ? 'Bạn đang có bản nháp chỉnh sửa hồ sơ chưa lưu. Đăng xuất sẽ xóa dữ liệu nháp tạm thời trên phiên này. Bạn có chắc chắn muốn đăng xuất?'
                : 'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này không?',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: OutlinedButton(
                key: const Key('logout_cancel_btn'),
                style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Hủy'),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: FilledButton(
                key: const Key('logout_confirm_btn'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Đăng xuất'),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _unsavedDraft = null;
      _activeUserId = null;
    });
    ref.read(accountSyncNotifierProvider.notifier).clearForUserSwitch();
    await ref.read(authNotifierProvider.notifier).logout();
  }

  Future<void> _openAvatarUpdateModal(User user) async {
    bool isSaving = false;
    String? modalError;
    AvatarPickedFile? selectedLocalFile;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadii.roundedBottomSheet,
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickAndUploadFromDevice() async {
              if (isSaving) return;
              setModalState(() {
                modalError = null;
              });

              AvatarPickedFile? picked;
              try {
                final picker = ref.read(avatarPickerServiceProvider);
                picked = await picker.pickAvatarFromDevice();
              } on AvatarPickException catch (e) {
                if (!ctx.mounted) return;
                setModalState(() {
                  modalError = e.message;
                });
                return;
              } catch (_) {
                if (!ctx.mounted) return;
                setModalState(() {
                  modalError =
                      'Không thể chọn ảnh từ thiết bị. Vui lòng thử lại.';
                });
                return;
              }

              if (picked == null || !ctx.mounted) {
                // User cancelled image picker — do nothing.
                return;
              }

              setModalState(() {
                selectedLocalFile = picked;
                isSaving = true;
                modalError = null;
              });

              try {
                final uploadService = ref.read(avatarUploadServiceProvider);
                final presigned = await uploadService.uploadAvatarToR2(picked);
                await ref.read(authNotifierProvider.notifier).updateAvatar(
                      url: presigned.publicUrl,
                      key: presigned.key,
                    );
                if (_unsavedDraft?.userId == user.id) {
                  _unsavedDraft = _unsavedDraft!.copyWith(
                    avatarUrl: presigned.publicUrl,
                  );
                }
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
                final failure = e is AppFailure ? e : DioClient.handleError(e);
                setModalState(() {
                  isSaving = false;
                  modalError = failure.message;
                });
              }
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.s24,
                  right: AppSpacing.s24,
                  top: AppSpacing.s20,
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.s24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Cập nhật ảnh đại diện',
                              style: AppTypography.sectionHeading,
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            child: IconButton(
                              key: const Key('avatar_modal_close_button'),
                              tooltip: 'Đóng',
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(ctx).pop(),
                              icon: const Icon(
                                LucideIcons.x,
                                size: 20,
                                color: AppColors.iconStrong,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        'Chọn ảnh định dạng JPG, PNG, WebP hoặc GIF từ máy của bạn (dung lượng tối đa 5MB).',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      if (selectedLocalFile != null) ...[
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.s12),
                          child: Text(
                            'Đã chọn: ${selectedLocalFile!.name} (${(selectedLocalFile!.sizeBytes / 1024).toStringAsFixed(1)} KB)',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                      if (modalError != null) ...[
                        Container(
                          key: const Key('avatar_modal_error_banner'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.s16),
                          margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                          decoration: BoxDecoration(
                            color: AppColors.errorSoft,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                LucideIcons.circleAlert,
                                size: 18,
                                color: AppColors.iconStrong,
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: Text(
                                  modalError!,
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
                      SizedBox(
                        width: double.infinity,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: FilledButton.icon(
                            key: const Key('avatar_pick_device_button'),
                            onPressed:
                                isSaving ? null : pickAndUploadFromDevice,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textInverse,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s20,
                                vertical: AppSpacing.s12,
                              ),
                            ),
                            icon: const Icon(
                              LucideIcons.imageUp,
                              size: 18,
                              color: AppColors.textInverse,
                            ),
                            label: Text(
                              isSaving
                                  ? 'Đang tải ảnh lên...'
                                  : 'Chọn ảnh từ thiết bị (Tối đa 5MB)',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
    bool isUploadingAvatar = false;
    AvatarPickedFile? selectedLocalAvatar;
    String? uploadedAvatarKey;
    String? errorMessage;
    Map<String, String> fieldErrors = <String, String>{};

    ProfileDraftData buildCurrentDraft() {
      return ProfileDraftData(
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

    void snapshotDraft() {
      final candidate = buildCurrentDraft();
      if (candidate.hasChangesComparedTo(user)) {
        _unsavedDraft = candidate;
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadii.roundedBottomSheet,
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> handlePickAvatarFromDevice() async {
              if (isSubmitting || isUploadingAvatar) return;
              setModalState(() {
                errorMessage = null;
                fieldErrors = Map<String, String>.from(fieldErrors)
                  ..remove('avatarUrl');
              });

              AvatarPickedFile? picked;
              try {
                final picker = ref.read(avatarPickerServiceProvider);
                picked = await picker.pickAvatarFromDevice();
              } on AvatarPickException catch (e) {
                if (!ctx.mounted) return;
                setModalState(() {
                  errorMessage = e.message;
                });
                return;
              } catch (_) {
                if (!ctx.mounted) return;
                setModalState(() {
                  errorMessage =
                      'Không thể chọn ảnh từ thiết bị. Vui lòng thử lại.';
                });
                return;
              }

              if (picked == null || !ctx.mounted) {
                return;
              }

              setModalState(() {
                selectedLocalAvatar = picked;
                isUploadingAvatar = true;
                errorMessage = null;
              });

              try {
                final uploadService = ref.read(avatarUploadServiceProvider);
                final presigned = await uploadService.uploadAvatarToR2(picked);
                avatarUrlCtrl.text = presigned.publicUrl;
                uploadedAvatarKey = presigned.key;
                await ref.read(authNotifierProvider.notifier).updateAvatar(
                      url: presigned.publicUrl,
                      key: presigned.key,
                    );
                snapshotDraft();
                if (!ctx.mounted) return;
                setModalState(() {
                  isUploadingAvatar = false;
                });
                if (mounted) {
                  setState(() {});
                }
              } catch (e) {
                if (!ctx.mounted) return;
                final failure = e is AppFailure ? e : DioClient.handleError(e);
                setModalState(() {
                  isUploadingAvatar = false;
                  errorMessage = failure.message;
                });
              }
            }

            Future<void> handleSave() async {
              // Synchronous lock against double-submit
              if (isSubmitting || isUploadingAvatar) return;

              final candidateDraft = buildCurrentDraft();
              final validation = validateProfileDraft(candidateDraft);
              if (!validation.isValid) {
                _unsavedDraft = candidateDraft;
                setModalState(() {
                  fieldErrors = validation.fieldErrors;
                  errorMessage = validation.firstErrorMessage;
                });
                return;
              }

              if (candidateDraft.hasSensitiveChangeComparedTo(user)) {
                final confirmedPhone = await _confirmSensitivePhoneChange(
                  ctx,
                  oldPhone: (user.phoneNumber ?? '').trim(),
                  newPhone: candidateDraft.phone.trim(),
                );
                if (!confirmedPhone || !ctx.mounted) {
                  return;
                }
              }

              _unsavedDraft = candidateDraft;
              isSubmitting = true;
              setModalState(() {
                fieldErrors = const <String, String>{};
                errorMessage = null;
              });

              try {
                final newAvatarUrl = avatarUrlCtrl.text.trim();
                final oldAvatarUrl = (user.avatarUrl ?? '').trim();
                final parsedLanguages = candidateDraft.parsedLanguages;

                if (newAvatarUrl.isNotEmpty &&
                    newAvatarUrl != oldAvatarUrl &&
                    uploadedAvatarKey == null) {
                  await ref
                      .read(authNotifierProvider.notifier)
                      .updateAvatar(url: newAvatarUrl);
                }

                final updatedUser = await ref
                    .read(authNotifierProvider.notifier)
                    .updateProfile(
                      fullName: fullNameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      bio: bioCtrl.text.trim(),
                      location: locationCtrl.text.trim(),
                      job: jobCtrl.text.trim(),
                      dreamDestination: dreamDestinationCtrl.text.trim(),
                      school: schoolCtrl.text.trim(),
                      languages: parsedLanguages,
                      avatarUrl: newAvatarUrl.isNotEmpty ? newAvatarUrl : null,
                    );

                try {
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
                } catch (_) {
                  // Ignore local cache write failure when backend update succeeded.
                }

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
                final failure = e is AppFailure ? e : DioClient.handleError(e);
                final serverFieldErrors = <String, String>{};
                if (failure is ValidationFailure) {
                  for (final item in failure.fieldErrors) {
                    final fieldPath = item.path?.trim() ?? '';
                    final fieldMsg = item.msg?.trim() ?? '';
                    if (fieldPath.isNotEmpty && fieldMsg.isNotEmpty) {
                      serverFieldErrors[fieldPath] = fieldMsg;
                    }
                  }
                }
                setModalState(() {
                  isSubmitting = false;
                  fieldErrors = serverFieldErrors;
                  errorMessage = failure.message;
                });
                if (mounted) {
                  setState(() {});
                }
              }
            }

            final currentAvatarUrl = avatarUrlCtrl.text.trim();
            final bool busy = isSubmitting || isUploadingAvatar;

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s24,
                          AppSpacing.s16,
                          AppSpacing.s16,
                          AppSpacing.s8,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Chỉnh sửa hồ sơ cá nhân',
                                style: AppTypography.sectionHeading,
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              child: IconButton(
                                key: const Key('edit_profile_close_button'),
                                tooltip: 'Đóng',
                                onPressed: busy
                                    ? null
                                    : () {
                                        snapshotDraft();
                                        Navigator.of(ctx).pop();
                                        if (mounted) {
                                          setState(() {});
                                        }
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
                      ),
                      const Divider(height: 1, color: AppColors.divider),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.s24,
                            AppSpacing.s16,
                            AppSpacing.s24,
                            AppSpacing.s24,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (errorMessage != null) ...[
                                Container(
                                  key: const Key('edit_profile_error_banner'),
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AppSpacing.s12),
                                  margin: const EdgeInsets.only(
                                    bottom: AppSpacing.s16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorSoft,
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.md),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        LucideIcons.circleAlert,
                                        size: 18,
                                        color: AppColors.iconStrong,
                                      ),
                                      const SizedBox(width: AppSpacing.s8),
                                      Expanded(
                                        child: Text(
                                          errorMessage!,
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
                              // Avatar picker row (replaces raw URL text input)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.s16,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: const BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: SizedBox(
                                          width: 56,
                                          height: 56,
                                          child: selectedLocalAvatar != null
                                              ? Image.memory(
                                                  selectedLocalAvatar!.bytes,
                                                  fit: BoxFit.cover,
                                                )
                                              : (currentAvatarUrl.isNotEmpty
                                                  ? AppImage(
                                                      url: currentAvatarUrl,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : Center(
                                                      child: Text(
                                                        user.firstName
                                                                .isNotEmpty
                                                            ? user.firstName[0]
                                                                .toUpperCase()
                                                            : 'U',
                                                        style: AppTypography
                                                            .cardTitle
                                                            .copyWith(
                                                          color: AppColors
                                                              .textStrong,
                                                        ),
                                                      ),
                                                    )),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Ảnh đại diện',
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textStrong,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isUploadingAvatar
                                                ? 'Đang tải ảnh lên...'
                                                : (selectedLocalAvatar != null
                                                    ? 'Đã chọn: ${selectedLocalAvatar!.name}'
                                                    : 'Chọn ảnh từ thiết bị (tối đa 5MB)'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                AppTypography.caption.copyWith(
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s8),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(minHeight: 40),
                                      child: TextButton.icon(
                                        key: const Key(
                                          'edit_profile_pick_avatar_button',
                                        ),
                                        onPressed: busy
                                            ? null
                                            : handlePickAvatarFromDevice,
                                        style: TextButton.styleFrom(
                                          backgroundColor:
                                              AppColors.surfaceElevated,
                                          foregroundColor: AppColors.textStrong,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.s12,
                                            vertical: AppSpacing.s8,
                                          ),
                                          shape: const StadiumBorder(),
                                        ),
                                        icon: const Icon(
                                          LucideIcons.imageUp,
                                          size: 16,
                                          color: AppColors.iconStrong,
                                        ),
                                        label: Text(
                                          isUploadingAvatar
                                              ? 'Đang tải...'
                                              : 'Chọn ảnh từ máy',
                                          style: AppTypography.caption.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textStrong,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(
                                height: 1,
                                color: AppColors.divider,
                              ),
                              const SizedBox(height: AppSpacing.s16),
                              _buildCleanProfileField(
                                fieldKey:
                                    const Key('edit_profile_full_name_input'),
                                controller: fullNameCtrl,
                                enabled: !busy,
                                labelText: 'Họ và tên *',
                                hintText: 'Nhập họ và tên đầy đủ',
                                errorText: fieldErrors['fullName'],
                              ),
                              _buildCleanProfileField(
                                fieldKey: const Key('edit_profile_phone_input'),
                                controller: phoneCtrl,
                                enabled: !busy,
                                keyboardType: TextInputType.phone,
                                labelText: 'Số điện thoại',
                                hintText: '0912345678 hoặc +84912345678',
                                errorText: fieldErrors['phone'],
                              ),
                              _buildCleanProfileField(
                                fieldKey:
                                    const Key('edit_profile_location_input'),
                                controller: locationCtrl,
                                enabled: !busy,
                                labelText: 'Nơi sinh sống',
                                hintText: 'Ví dụ: Vũng Tàu, Việt Nam',
                                errorText: fieldErrors['location'],
                              ),
                              _buildCleanProfileField(
                                fieldKey: const Key(
                                  'edit_profile_dream_destination_input',
                                ),
                                controller: dreamDestinationCtrl,
                                enabled: !busy,
                                labelText: 'Nơi tôi luôn muốn đến',
                                hintText: 'Nhập điểm đến yêu thích của bạn',
                                errorText: fieldErrors['dreamDestination'],
                              ),
                              _buildCleanProfileField(
                                fieldKey: const Key('edit_profile_job_input'),
                                controller: jobCtrl,
                                enabled: !busy,
                                labelText: 'Công việc / Nghề nghiệp',
                                hintText: 'Nhập công việc hiện tại',
                                errorText: fieldErrors['job'],
                              ),
                              _buildCleanProfileField(
                                fieldKey:
                                    const Key('edit_profile_school_input'),
                                controller: schoolCtrl,
                                enabled: !busy,
                                labelText: 'Trường học',
                                hintText: 'Nơi bạn từng theo học',
                                errorText: fieldErrors['school'],
                              ),
                              _buildCleanProfileField(
                                fieldKey:
                                    const Key('edit_profile_languages_input'),
                                controller: languagesCtrl,
                                enabled: !busy,
                                labelText: 'Ngôn ngữ giao tiếp',
                                hintText:
                                    'Tiếng Việt, English (phân cách bằng dấu phẩy)',
                                errorText: fieldErrors['languages'],
                              ),
                              _buildCleanProfileField(
                                fieldKey: const Key('edit_profile_bio_input'),
                                controller: bioCtrl,
                                enabled: !busy,
                                maxLines: 3,
                                minLines: 2,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                labelText: 'Giới thiệu bản thân',
                                hintText: 'Chia sẻ đôi nét về bản thân...',
                                errorText: fieldErrors['bio'],
                              ),
                              const SizedBox(height: AppSpacing.s8),
                              SizedBox(
                                width: double.infinity,
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(minHeight: 48),
                                  child: FilledButton(
                                    key: const Key('edit_profile_save_button'),
                                    onPressed: busy ? null : handleSave,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.textStrong,
                                      foregroundColor: AppColors.textInverse,
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.s12,
                                      ),
                                    ),
                                    child: Text(
                                      isSubmitting
                                          ? 'Đang lưu...'
                                          : 'Lưu thay đổi',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _roleLabelForUser(User user) {
    if (user.isAdmin) return 'Quản trị viên (Admin)';
    if (user.isHost) return 'Chủ nhà (Host)';
    if (user.isNewHost) return 'Hồ sơ Chủ nhà đang chờ duyệt';
    return 'Khách lưu trú';
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(localeProvider);
    final authState = ref.watch(authNotifierProvider);
    final syncState = ref.watch(accountSyncNotifierProvider);

    final authUser = authState.valueOrNull;
    final User? effectiveUser = (authUser != null &&
            syncState.syncedUser != null &&
            syncState.syncedUser!.id == authUser.id)
        ? syncState.syncedUser
        : authUser;

    _enforceUserIsolation(effectiveUser);

    final AccountSyncState? derivedAuthErrorState = authState.hasError
        ? mapFailureToAccountSyncState(
            authState.error!,
            existingUser: effectiveUser,
          )
        : null;

    final AccountSyncState activeSyncState = derivedAuthErrorState ?? syncState;
    final bool isInitialLoading =
        (authState.isLoading || activeSyncState.isLoading) &&
            effectiveUser == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tài khoản'),
        actions: [
          if (effectiveUser != null)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: IconButton(
                key: const Key('settings_refresh_profile_button'),
                tooltip: 'Đồng bộ hồ sơ từ máy chủ',
                onPressed: activeSyncState.isLoading ? null : _handleRetrySync,
                icon: const Icon(
                  LucideIcons.refreshCw,
                  size: 20,
                  color: AppColors.iconStrong,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _handleRetrySync,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GlobalPendingBookingHeaderBanner(),
                // Async Error / Offline / 401-403 Status Banner
                if (activeSyncState.isOffline ||
                    activeSyncState.isError ||
                    activeSyncState.isUnauthorized) ...[
                  _buildAsyncStatusBanner(activeSyncState),
                  const SizedBox(height: AppSpacing.s16),
                ],

                // Group 1: Account Profile Section (`Hồ sơ cá nhân`)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: isInitialLoading
                      ? _buildLoadingProfileCard()
                      : (effectiveUser != null
                          ? _buildSignedInProfileCard(effectiveUser)
                          : _buildLoggedOutProfileCard()),
                ),

                const SizedBox(height: AppSpacing.s20),

                // Group 2: Trips, Favorites & Messages (`Hoạt động lưu trú & Yêu thích`)
                _buildSectionHeader('Kỳ nghỉ của bạn'),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Column(
                    children: [
                      _buildSettingsMenuTile(
                        tileKey: const Key('menu_trips_history'),
                        icon: LucideIcons.calendarCheck,
                        title: 'Chuyến đi của tôi',
                        onTap: () => _navigateProtectedRoute(
                          context,
                          '/account/trips',
                          effectiveUser,
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.borderSoft),
                      _buildSettingsMenuTile(
                        tileKey: const Key('menu_favorites'),
                        icon: LucideIcons.heart,
                        title: 'Danh sách yêu thích',
                        onTap: () => context.push('/yeu-thich'),
                      ),
                      const Divider(height: 1, color: AppColors.borderSoft),
                      _buildSettingsMenuTile(
                        tileKey: const Key('menu_messages'),
                        icon: LucideIcons.messageSquare,
                        title: 'Tin nhắn với Chủ nhà',
                        onTap: () => _navigateProtectedRoute(
                          context,
                          '/messages',
                          effectiveUser,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.s20),

                // Group 3: Partner & Admin Portals (`Tiện ích & Cổng quản lý`)
                if (effectiveUser != null && effectiveUser.isAdmin) ...[
                  _buildSectionHeader('Quản trị'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBase,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Column(
                      children: [
                        _buildSettingsMenuTile(
                          tileKey: const Key('menu_admin_portal'),
                          icon: LucideIcons.shieldCheck,
                          title: 'Quản trị hệ thống',
                          subtitle:
                              'Tổng quan, người dùng, kiểm duyệt bài đăng & hồ sơ Host',
                          onTap: () => context.push('/admin'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  _buildSectionHeader('Dành cho chủ nhà'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBase,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Column(
                      children: [
                        if (effectiveUser != null && effectiveUser.isHost)
                          _buildSettingsMenuTile(
                            tileKey: const Key('menu_host_portal'),
                            icon: LucideIcons.house,
                            title: 'Quản lý chỗ nghỉ',
                            subtitle:
                                'Quản lý chỗ nghỉ, lịch phòng, doanh thu & rút tiền',
                            onTap: () => context.push('/chu-nha/cho-nghi'),
                          )
                        else if (effectiveUser != null &&
                            effectiveUser.isNewHost)
                          _buildSettingsMenuTile(
                            tileKey: const Key('menu_host_status'),
                            icon: LucideIcons.clock,
                            title: 'Trạng thái hồ sơ Chủ nhà',
                            subtitle:
                                'Theo dõi tiến độ xét duyệt đăng ký trở thành Chủ nhà',
                            onTap: () =>
                                context.push('/tro-thanh-host/trang-thai'),
                          )
                        else
                          _buildSettingsMenuTile(
                            tileKey: const Key('menu_become_host'),
                            icon: LucideIcons.housePlus,
                            title: 'Trở thành chủ nhà',
                            subtitle:
                                'Quản lý chỗ nghỉ, lịch phòng, doanh thu & rút tiền',
                            onTap: () => context.push('/tro-thanh-host'),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.s20),

                // Group 4: Language Switcher (`Ngôn ngữ / Language / 언어`)
                _buildSectionHeader('Tùy chọn'),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: ExpansionTile(
                    key: const Key('settings_language_selector'),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s4,
                    ),
                    leading: const SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(
                        child: Icon(
                          LucideIcons.globe,
                          size: 20,
                          color: AppColors.iconStrong,
                        ),
                      ),
                    ),
                    title: Text(
                      'Ngôn ngữ',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textStrong,
                      ),
                    ),
                    subtitle: Text(
                      currentLocale == 'en'
                          ? 'English'
                          : currentLocale == 'ko'
                              ? '한국어'
                              : 'Tiếng Việt',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    iconColor: AppColors.iconMuted,
                    collapsedIconColor: AppColors.iconMuted,
                    children: [
                      const Divider(height: 1, color: AppColors.borderSoft),
                      _buildLanguageTile(
                        tileKey: const Key('lang_tile_vi'),
                        title: 'Tiếng Việt',
                        subtitle: 'Mặc định',
                        isSelected: currentLocale == 'vi',
                        onTap: () =>
                            ref.read(localeProvider.notifier).setLocale('vi'),
                      ),
                      const Divider(height: 1, color: AppColors.borderSoft),
                      _buildLanguageTile(
                        tileKey: const Key('lang_tile_en'),
                        title: 'English',
                        subtitle: 'International',
                        isSelected: currentLocale == 'en',
                        onTap: () =>
                            ref.read(localeProvider.notifier).setLocale('en'),
                      ),
                      const Divider(height: 1, color: AppColors.borderSoft),
                      _buildLanguageTile(
                        tileKey: const Key('lang_tile_ko'),
                        title: '한국어',
                        subtitle: 'Korean',
                        isSelected: currentLocale == 'ko',
                        onTap: () =>
                            ref.read(localeProvider.notifier).setLocale('ko'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.s20),

                // Group 5: Support & Contact (`Liên hệ & Hỗ trợ trực tiếp`)
                _buildSectionHeader('Hỗ trợ trực tiếp'),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Column(
                    children: [
                      _buildSettingsMenuTile(
                        tileKey: const Key('menu_contact_page'),
                        icon: LucideIcons.lifeBuoy,
                        title: 'Trung tâm Liên hệ & Hỗ trợ',
                        subtitle:
                            'Gửi yêu cầu hỗ trợ, địa chỉ & câu hỏi thường gặp',
                        onTap: () => context.push('/lien-he'),
                      ),
                      const Divider(height: 1, color: AppColors.borderSoft),
                      _buildSettingsMenuTile(
                        tileKey: const Key('menu_call_hotline'),
                        icon: LucideIcons.phone,
                        title: 'Gọi tổng đài tư vấn',
                        subtitle: AppConfig.hotlineNumber,
                        onTap: () => ContactService.callHotline(),
                      ),
                      const Divider(height: 1, color: AppColors.borderSoft),
                      _buildSettingsMenuTile(
                        tileKey: const Key('menu_zalo_support'),
                        icon: LucideIcons.messageCircle,
                        title: 'Nhắn tin qua Zalo OA',
                        subtitle: 'Hỗ trợ khách hàng 24/7',
                        onTap: () {
                          ContactService.openZaloInquiry(
                            messageText:
                                'Xin chào The Palm, tôi cần hỗ trợ thông tin ứng dụng.',
                          );
                        },
                      ),
                    ],
                  ),
                ),

                if (effectiveUser != null) ...[
                  const SizedBox(height: AppSpacing.s24),
                  SizedBox(
                    width: double.infinity,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: OutlinedButton.icon(
                        key: const Key('settings_bottom_logout_button'),
                        onPressed: () => _confirmAndLogout(effectiveUser),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textStrong,
                          side: const BorderSide(color: AppColors.borderStrong),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s12,
                            horizontal: AppSpacing.s20,
                          ),
                        ),
                        icon: const Icon(
                          LucideIcons.logOut,
                          size: 18,
                          color: AppColors.iconStrong,
                        ),
                        label: const Text('Đăng xuất tài khoản'),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.s32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAsyncStatusBanner(AccountSyncState syncState) {
    final bool isOffline = syncState.isOffline;
    final bool isUnauthorized = syncState.isUnauthorized;

    final Key bannerKey = isOffline
        ? const Key('settings_offline_banner')
        : (isUnauthorized
            ? const Key('settings_unauthorized_banner')
            : const Key('settings_error_banner'));

    final IconData bannerIcon = isOffline
        ? LucideIcons.wifiOff
        : (isUnauthorized ? LucideIcons.lock : LucideIcons.triangleAlert);

    final String bannerTitle = isOffline
        ? 'Thiết bị đang ngoại tuyến'
        : (isUnauthorized
            ? 'Phiên đăng nhập hết hạn hoặc bị từ chối'
            : 'Không thể đồng bộ dữ liệu máy chủ');

    final String bannerMessage = syncState.message ??
        (isOffline
            ? 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.'
            : (isUnauthorized
                ? 'Phiên đăng nhập không hợp lệ hoặc bạn không có quyền truy cập (401/403).'
                : 'Máy chủ đang gặp sự cố tạm thời. Vui lòng thử lại sau.'));

    return Container(
      key: bannerKey,
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(bannerIcon, size: 22, color: AppColors.iconStrong),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bannerTitle,
                      style: AppTypography.cardTitle,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      bannerMessage,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: OutlinedButton.icon(
                  key: const Key('settings_retry_button'),
                  onPressed: syncState.isLoading ? null : _handleRetrySync,
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(
                    LucideIcons.refreshCw,
                    size: 16,
                    color: AppColors.iconStrong,
                  ),
                  label: const Text('Thử lại'),
                ),
              ),
              if (isUnauthorized)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: FilledButton.icon(
                    key: const Key('settings_relogin_button'),
                    onPressed: () => context.push('/dang-nhap'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(
                      LucideIcons.logIn,
                      size: 16,
                      color: AppColors.textInverse,
                    ),
                    label: const Text('Đăng nhập lại'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingProfileCard() {
    return Padding(
      key: const Key('settings_loading_state'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Text(
              'Đang tải thông tin tài khoản...',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedOutProfileCard() {
    return Column(
      key: const Key('settings_logged_out_card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              LucideIcons.userRound,
              color: AppColors.iconStrong,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chưa đăng nhập',
                    style: AppTypography.cardTitle,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Đăng nhập để xem kỳ nghỉ, tin nhắn và đồng bộ yêu thích',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        SizedBox(
          width: double.infinity,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: FilledButton(
              key: const Key('settings_login_cta_button'),
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
    );
  }

  Widget _buildSignedInProfileCard(User user) {
    final bool hasDraft =
        _unsavedDraft != null && _unsavedDraft!.userId == user.id;

    final avatarBtn = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: OutlinedButton.icon(
        key: const Key('settings_change_avatar_button'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textStrong,
          side: const BorderSide(color: AppColors.borderStrong),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
        ),
        onPressed: () => _openAvatarUpdateModal(user),
        icon: const Icon(
          LucideIcons.camera,
          size: 16,
          color: AppColors.iconStrong,
        ),
        label: const Text('Đổi ảnh'),
      ),
    );

    final editProfileBtn = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: OutlinedButton.icon(
        key: const Key('settings_edit_profile_button'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textStrong,
          side: const BorderSide(color: AppColors.borderStrong),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
        ),
        onPressed: () => _openEditProfileModal(user),
        icon: const Icon(
          LucideIcons.pencil,
          size: 16,
          color: AppColors.iconStrong,
        ),
        label: const Text('Sửa hồ sơ'),
      ),
    );

    return Column(
      key: const Key('settings_signed_in_card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              button: true,
              label: 'Cập nhật ảnh đại diện',
              child: InkWell(
                key: const Key('settings_avatar_tap_target'),
                customBorder: const CircleBorder(),
                onTap: () => _openAvatarUpdateModal(user),
                child: Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: ClipOval(
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: (user.avatarUrl != null &&
                              user.avatarUrl!.trim().isNotEmpty)
                          ? AppImage(
                              url: user.avatarUrl!.trim(),
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Text(
                                user.firstName.isNotEmpty
                                    ? user.firstName[0].toUpperCase()
                                    : 'U',
                                style: AppTypography.displayMedium.copyWith(
                                  color: AppColors.textStrong,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    key: const Key('settings_user_fullname'),
                    style: AppTypography.cardTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    key: const Key('settings_user_email'),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: AppRadii.roundedPill,
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Text(
                      _roleLabelForUser(user),
                      key: const Key('settings_role_label'),
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
        const SizedBox(height: AppSpacing.s16),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1.0);
            if (constraints.maxWidth >= 280 && textScale < 1.35) {
              return Row(
                children: [
                  Expanded(child: avatarBtn),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(child: editProfileBtn),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                avatarBtn,
                const SizedBox(height: AppSpacing.s8),
                editProfileBtn,
              ],
            );
          },
        ),
        if (hasDraft) ...[
          const SizedBox(height: AppSpacing.s12),
          Container(
            key: const Key('settings_unsaved_draft_banner'),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Bạn có bản nháp hồ sơ chưa lưu thành công.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textStrong,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: TextButton.icon(
                    key: const Key('settings_resume_draft_button'),
                    onPressed: () => _openEditProfileModal(user),
                    icon: const Icon(
                      LucideIcons.rotateCcw,
                      size: 16,
                      color: AppColors.iconStrong,
                    ),
                    label: const Text('Tiếp tục sửa'),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.s12),
          child: Divider(height: 1, color: AppColors.borderSoft),
        ),
        _ProfileDetailRow(
          rowKey: const Key('settings_verification_status'),
          icon: user.isVerified
              ? LucideIcons.badgeCheck
              : LucideIcons.shieldAlert,
          label: 'Xác minh danh tính',
          value: user.isVerified ? 'Đã xác minh' : 'Chưa xác minh',
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.s4,
        bottom: AppSpacing.s8,
      ),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildSettingsMenuTile({
    Key? tileKey,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        key: tileKey,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s4,
        ),
        horizontalTitleGap: AppSpacing.s12,
        minLeadingWidth: 24,
        leading: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: AppColors.iconStrong,
            ),
          ),
        ),
        title: Text(
          title,
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textStrong,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
        trailing: const Icon(
          LucideIcons.chevronRight,
          size: 18,
          color: AppColors.iconMuted,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLanguageTile({
    Key? tileKey,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        key: tileKey,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s4,
        ),
        title: Text(
          title,
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textStrong,
          ),
        ),
        subtitle: Text(subtitle, style: AppTypography.caption),
        trailing: isSelected
            ? const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(
                    LucideIcons.check,
                    color: AppColors.iconStrong,
                    size: 20,
                  ),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final Key? rowKey;
  final IconData icon;
  final String label;
  final String value;

  const _ProfileDetailRow({
    this.rowKey,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: rowKey,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: AppColors.iconMuted),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textStrong,
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
}
