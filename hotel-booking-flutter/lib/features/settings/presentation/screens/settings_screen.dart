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
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../../shared/widgets/app_semantic_icons.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../../booking_inquiry/domain/services/contact_service.dart';
import '../../domain/account_profile_models.dart';
import '../../services/avatar_upload_service.dart';
import '../view_models/account_settings_view_model.dart';

/// Account & Settings tab (`Hồ sơ & Tài khoản`).
///
/// Implements full parity with `Source goc/frontend/src/views/pages/Trips/index.tsx`:
/// - Supports `logged-out`, `guest`, `host` (`user.isHost` / `user.isNewHost`), and `admin` modes.
/// - Handles async states (`loading`, `success`, `empty`, `error`, `offline`, `401/403`) with real retry.
/// - Synchronizes profile via `GET /api/auth/me` & `GET /api/users/me` and updates via `PATCH /api/users/me`.
/// - Uploads avatar from device via `POST /api/uploads/presign` (`folder: 'avatars'`) + R2 `PUT` + `PATCH /api/users/me/avatar`.
/// - Preserves unsaved draft per `userId` on 422/500/offline, prevents double-submit, never fakes local-only success,
///   and isolates PII across account switches.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static final TextStyle _menuTitleStyle = AppTypography.bodyMedium.copyWith(
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textStrong,
    letterSpacing: -0.08,
    height: 1.35,
  );

  static final TextStyle _menuTrailingStyle = AppTypography.caption.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.35,
  );

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
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
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
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 14.5,
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
    final currentLocale = ref.read(localeProvider);
    final dialogL10n = lookupAppLocalizations(Locale(currentLocale));
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
          title: Text(
            dialogL10n.settingsConfirmPhoneTitle,
            style: AppTypography.sectionHeading,
          ),
          content: Text(
            newPhone.isEmpty
                ? dialogL10n.settingsConfirmPhoneRemove(oldPhone)
                : dialogL10n.settingsConfirmPhoneChange(oldPhone, newPhone),
            style: AppTypography.bodyMedium,
          ),
          actions: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: OutlinedButton(
                key: const Key('sensitive_change_cancel_btn'),
                style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(dialogL10n.settingsConfirmPhoneReview),
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
                child: Text(dialogL10n.settingsConfirmPhoneSave),
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

    final currentLocale = ref.read(localeProvider);
    final dialogL10n = lookupAppLocalizations(Locale(currentLocale));
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
          title: Text(
            dialogL10n.settingsConfirmLogoutTitle,
            style: AppTypography.sectionHeading,
          ),
          content: Text(
            hasUnsaved
                ? dialogL10n.settingsConfirmLogoutDraft
                : dialogL10n.settingsConfirmLogout,
            style: AppTypography.bodyMedium,
          ),
          actions: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: OutlinedButton(
                key: const Key('logout_cancel_btn'),
                style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(dialogL10n.ctaCancel),
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
                child: Text(dialogL10n.authLogout),
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
    final currentLocale = ref.read(localeProvider);
    final modalL10n = lookupAppLocalizations(Locale(currentLocale));
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
                      modalL10n.settingsAvatarPickError;
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
                    SnackBar(
                      content: Text(
                        modalL10n.settingsAvatarUpdateSuccess,
                      ),
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
                          Expanded(
                            child: Text(
                              modalL10n.settingsAvatarUpdateTitle,
                              style: AppTypography.sectionHeading.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            child: IconButton(
                              key: const Key('avatar_modal_close_button'),
                              tooltip: modalL10n.ctaClose,
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
                        modalL10n.settingsAvatarUpdateHint,
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
                            modalL10n.settingsAvatarSelected(
                              selectedLocalFile!.name,
                              (selectedLocalFile!.sizeBytes / 1024)
                                  .toStringAsFixed(1),
                            ),
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
                              AppSemanticIcons.changeAvatar,
                              size: 18,
                              color: AppColors.textInverse,
                            ),
                            label: Text(
                              isSaving
                                  ? modalL10n.settingsAvatarUploading
                                  : modalL10n.settingsAvatarPickFromDevice,
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
    final currentLocale = ref.read(localeProvider);
    final editL10n = lookupAppLocalizations(Locale(currentLocale));
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
                      editL10n.settingsAvatarPickError;
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
                    SnackBar(
                      content: Text(
                        editL10n.settingsProfileUpdateSuccess,
                      ),
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
                            Expanded(
                              child: Text(
                                editL10n.settingsEditProfileTitle,
                                style: AppTypography.sectionHeading.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              child: IconButton(
                                key: const Key('edit_profile_close_button'),
                                tooltip: editL10n.ctaClose,
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
                                            editL10n.settingsAvatarSectionTitle,
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textStrong,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isUploadingAvatar
                                                ? editL10n.settingsAvatarUploading
                                                : (selectedLocalAvatar != null
                                                    ? editL10n.settingsAvatarSelectedShort(selectedLocalAvatar!.name)
                                                    : editL10n.settingsAvatarPickHint),
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
                                          AppSemanticIcons.changeAvatar,
                                          size: 16,
                                          color: AppColors.iconStrong,
                                        ),
                                        label: Text(
                                          isUploadingAvatar
                                              ? editL10n.settingsAvatarUploadingShort
                                              : editL10n.settingsAvatarPickFromDeviceShort,
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
                                labelText: editL10n.settingsFullNameLabel,
                                hintText: editL10n.settingsFullNameHint,
                                errorText: fieldErrors['fullName'],
                              ),
                              _buildCleanProfileField(
                                fieldKey: const Key('edit_profile_phone_input'),
                                controller: phoneCtrl,
                                enabled: !busy,
                                keyboardType: TextInputType.phone,
                                labelText: editL10n.settingsPhoneLabel,
                                hintText: editL10n.settingsPhoneHint,
                                errorText: fieldErrors['phone'],
                              ),
                              _buildCleanProfileField(
                                fieldKey:
                                    const Key('edit_profile_location_input'),
                                controller: locationCtrl,
                                enabled: !busy,
                                labelText: editL10n.settingsLocationLabel,
                                hintText: editL10n.settingsLocationHint,
                                errorText: fieldErrors['location'],
                              ),
                              _buildCleanProfileField(
                                fieldKey: const Key(
                                  'edit_profile_dream_destination_input',
                                ),
                                controller: dreamDestinationCtrl,
                                enabled: !busy,
                                labelText: editL10n.settingsDreamDestinationLabel,
                                hintText: editL10n.settingsDreamDestinationHint,
                                errorText: fieldErrors['dreamDestination'],
                              ),
                              _buildCleanProfileField(
                                fieldKey: const Key('edit_profile_job_input'),
                                controller: jobCtrl,
                                enabled: !busy,
                                labelText: editL10n.settingsJobLabel,
                                hintText: editL10n.settingsJobHint,
                                errorText: fieldErrors['job'],
                              ),
                              _buildCleanProfileField(
                                fieldKey:
                                    const Key('edit_profile_school_input'),
                                controller: schoolCtrl,
                                enabled: !busy,
                                labelText: editL10n.settingsSchoolLabel,
                                hintText: editL10n.settingsSchoolHint,
                                errorText: fieldErrors['school'],
                              ),
                              _buildCleanProfileField(
                                fieldKey:
                                    const Key('edit_profile_languages_input'),
                                controller: languagesCtrl,
                                enabled: !busy,
                                labelText: editL10n.settingsLanguagesLabel,
                                hintText: editL10n.settingsLanguagesHint,
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
                                labelText: editL10n.settingsBioLabel,
                                hintText: editL10n.settingsBioHint,
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
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.textInverse,
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.s12,
                                      ),
                                    ),
                                    child: Text(
                                      isSubmitting
                                          ? editL10n.settingsSaving
                                          : editL10n.ctaSave,
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

  String _roleLabelForUser(User user, [AppLocalizations? l10n]) {
    if (l10n != null) {
      if (user.isAdmin) return l10n.settingsRoleAdmin;
      if (user.isHost) return l10n.settingsRoleHost;
      if (user.isNewHost) return l10n.settingsRoleHostPending;
      return l10n.settingsRoleGuest;
    }
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

    final l10n = lookupAppLocalizations(Locale(currentLocale));

    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      body: Column(
        children: [
          const AppSearchHeader(
            currentPath: '/account/profile',
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _handleRetrySync,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenMargin,
                    vertical: AppSpacing.s12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Async Error / Offline / 401-403 Status Banner
                      if (activeSyncState.isOffline ||
                          activeSyncState.isError ||
                          activeSyncState.isUnauthorized) ...[
                        _buildAsyncStatusBanner(activeSyncState, l10n),
                        const SizedBox(height: AppSpacing.s16),
                      ],

                      // Group 1: Account Profile Section (`Hồ sơ cá nhân`)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                        child: isInitialLoading
                             ? _buildLoadingProfileCard(l10n)
                             : (effectiveUser != null
                                 ? _buildSignedInProfileCard(effectiveUser, l10n)
                                 : _buildLoggedOutProfileCard(l10n)),
                      ),

                      _buildGroupDivider(),

                      // Group 2: Trips, Favorites & Messages
                      _buildSettingsMenuTile(
                        tileKey: const Key('menu_trips_history'),
                        icon: LucideIcons.calendarCheck,
                        title: l10n.settingsMyTrips,
                        onTap: () => _navigateProtectedRoute(
                          context,
                          '/account/trips',
                          effectiveUser,
                        ),
                      ),
                      _buildSettingsMenuTile(
                        tileKey: const Key('menu_favorites'),
                        icon: LucideIcons.heart,
                        title: l10n.settingsMyFavorites,
                        onTap: () => context.push('/yeu-thich'),
                      ),
                      _buildSettingsMenuTile(
                        tileKey: const Key('menu_messages'),
                        icon: AppSemanticIcons.messageHost,
                        title: l10n.settingsMessagesWithHost,
                        onTap: () => _navigateProtectedRoute(
                          context,
                          '/messages',
                          effectiveUser,
                        ),
                      ),

                      _buildGroupDivider(),

                      // Group 3: Partner & Admin Portals + Language Preferences
                      if (effectiveUser != null && effectiveUser.isAdmin)
                        _buildSettingsMenuTile(
                          tileKey: const Key('menu_admin_portal'),
                          icon: AppSemanticIcons.adminPortal,
                          title: l10n.navAdminPortal,
                          onTap: () => context.push('/admin'),
                        )
                      else if (effectiveUser != null && effectiveUser.isHost)
                        _buildSettingsMenuTile(
                          tileKey: const Key('menu_host_portal'),
                          icon: AppSemanticIcons.home,
                          title: l10n.settingsManageProperties,
                          onTap: () => context.push('/chu-nha/cho-nghi'),
                        )
                      else if (effectiveUser != null && effectiveUser.isNewHost)
                        _buildSettingsMenuTile(
                          tileKey: const Key('menu_host_status'),
                          icon: AppSemanticIcons.hostApplications,
                          title: l10n.hostKycStatusTitle,
                          onTap: () =>
                              context.push('/tro-thanh-host/trang-thai'),
                        )
                      else
                        _buildSettingsMenuTile(
                          tileKey: const Key('menu_become_host'),
                          icon: AppSemanticIcons.becomeHost,
                          title: l10n.navBecomeHost,
                          onTap: () => context.push('/tro-thanh-host'),
                        ),

                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          key: const Key('settings_language_selector'),
                          shape: const Border(),
                          collapsedShape: const Border(),
                          visualDensity: const VisualDensity(vertical: -2),
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s4,
                            vertical: 0,
                          ),
                          childrenPadding: const EdgeInsets.only(
                            left: AppSpacing.s16,
                            bottom: AppSpacing.s4,
                          ),
                          title: Row(
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: Center(
                                  child: Icon(
                                    LucideIcons.globe,
                                    size: 20,
                                    color: AppColors.iconStrong,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              Expanded(
                                child: Text(
                                  lookupAppLocalizations(Locale(currentLocale)).settingsLanguage,
                                  style: _menuTitleStyle,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Text(
                                currentLocale == 'en'
                                    ? 'English'
                                    : currentLocale == 'ko'
                                        ? '한국어'
                                        : 'Tiếng Việt',
                                style: _menuTrailingStyle,
                              ),
                            ],
                          ),
                          iconColor: AppColors.iconMuted,
                          collapsedIconColor: AppColors.iconMuted,
                          children: [
                            _buildLanguageTile(
                              tileKey: const Key('lang_tile_vi'),
                              title: 'Tiếng Việt',
                              subtitle: 'Mặc định • VND (₫)',
                              isSelected: currentLocale == 'vi',
                              onTap: () => ref
                                  .read(localeProvider.notifier)
                                  .setLocale('vi'),
                            ),
                            _buildLanguageTile(
                              tileKey: const Key('lang_tile_en'),
                              title: 'English',
                              subtitle: r'International • USD ($)',
                              isSelected: currentLocale == 'en',
                              onTap: () => ref
                                  .read(localeProvider.notifier)
                                  .setLocale('en'),
                            ),
                            _buildLanguageTile(
                              tileKey: const Key('lang_tile_ko'),
                              title: '한국어',
                              subtitle: '한국어 • KRW (₩)',
                              isSelected: currentLocale == 'ko',
                              onTap: () => ref
                                  .read(localeProvider.notifier)
                                  .setLocale('ko'),
                            ),
                          ],
                        ),
                      ),

                      if (ref.watch(fxFeatureEnabledProvider))
                        _buildCurrencyExpansionSection(currentLocale),

                      _buildGroupDivider(),

                      // Group 4: Support & Contact + Logout
                      _buildSettingsMenuTile(
                        tileKey: const Key('menu_contact_page'),
                        icon: AppSemanticIcons.supportCenter,
                        title: l10n.settingsContactSupportCenter,
                        onTap: () => context.push('/lien-he'),
                      ),
                      _buildSettingsMenuTile(
                        tileKey: const Key('menu_call_hotline'),
                        icon: LucideIcons.phone,
                        title: l10n.settingsCallHotline,
                        trailingText: AppConfig.hotlineNumber,
                        onTap: () => ContactService.callHotline(),
                      ),
                      _buildSettingsMenuTile(
                        tileKey: const Key('menu_zalo_support'),
                        icon: AppSemanticIcons.zaloSupport,
                        title: l10n.settingsZaloSupport,
                        onTap: () {
                          ContactService.openZaloInquiry(
                            messageText: l10n.settingsZaloInquiryDefaultMessage,
                          );
                        },
                      ),

                      if (effectiveUser != null)
                        _buildSettingsMenuTile(
                          tileKey: const Key('settings_bottom_logout_button'),
                          icon: AppSemanticIcons.logout,
                          title: l10n.authLogout,
                          showChevron: false,
                          onTap: () => _confirmAndLogout(effectiveUser),
                        ),

                      const SizedBox(height: AppSpacing.s32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAsyncStatusBanner(
    AccountSyncState syncState, [
    AppLocalizations? l10n,
  ]) {
    final effectiveL10n = l10n ?? context.l10n;
    final bool isOffline = syncState.isOffline;
    final bool isUnauthorized = syncState.isUnauthorized;

    final Key bannerKey = isOffline
        ? const Key('settings_offline_banner')
        : (isUnauthorized
            ? const Key('settings_unauthorized_banner')
            : const Key('settings_error_banner'));

    final IconData bannerIcon = isOffline
        ? LucideIcons.wifiOff
        : (isUnauthorized ? LucideIcons.lock : AppSemanticIcons.errorAlert);

    final String bannerTitle = isOffline
        ? effectiveL10n.settingsStatusOfflineTitle
        : (isUnauthorized
            ? effectiveL10n.settingsStatusUnauthorizedTitle
            : effectiveL10n.settingsStatusServerErrorTitle);

    final String bannerMessage = syncState.message ??
        (isOffline
            ? effectiveL10n.settingsStatusOfflineMessage
            : (isUnauthorized
                ? effectiveL10n.settingsStatusUnauthorizedMessage
                : effectiveL10n.settingsStatusServerErrorMessage));

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
                    AppSemanticIcons.retry,
                    size: 16,
                    color: AppColors.iconStrong,
                  ),
                  label: Text(effectiveL10n.ctaRetry),
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
                    label: Text(effectiveL10n.settingsReLogin),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingProfileCard([AppLocalizations? l10n]) {
    final effectiveL10n = l10n ?? context.l10n;
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
              effectiveL10n.settingsLoadingAccount,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedOutProfileCard([AppLocalizations? l10n]) {
    final effectiveL10n = l10n ?? context.l10n;
    return Column(
      key: const Key('settings_logged_out_card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              AppSemanticIcons.userProfile,
              color: AppColors.iconStrong,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    effectiveL10n.settingsNotLoggedIn,
                    style: AppTypography.cardTitle.copyWith(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    effectiveL10n.settingsLoginPrompt,
                    style: AppTypography.caption.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
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
            constraints: const BoxConstraints(minHeight: 46),
            child: FilledButton(
              key: const Key('settings_login_cta_button'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const StadiumBorder(),
                textStyle: AppTypography.buttonText.copyWith(fontSize: 14),
              ),
              onPressed: () => context.push('/dang-nhap'),
              child: Text(effectiveL10n.settingsSignInSignUp),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileActionIconButton({
    required Key buttonKey,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          key: buttonKey,
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 42,
              minHeight: 42,
            ),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 17,
                    color: AppColors.iconStrong,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignedInProfileCard(
    User user, [
    AppLocalizations? l10n,
  ]) {
    final effectiveL10n = l10n ?? context.l10n;
    final bool hasDraft =
        _unsavedDraft != null && _unsavedDraft!.userId == user.id;

    final avatarBtn = _buildProfileActionIconButton(
      buttonKey: const Key('settings_change_avatar_button'),
      icon: AppSemanticIcons.changeAvatar,
      tooltip: effectiveL10n.settingsChangeAvatarTooltip,
      onPressed: () => _openAvatarUpdateModal(user),
    );

    final editProfileBtn = _buildProfileActionIconButton(
      buttonKey: const Key('settings_edit_profile_button'),
      icon: LucideIcons.pencil,
      tooltip: effectiveL10n.settingsEditProfileTooltip,
      onPressed: () => _openEditProfileModal(user),
    );

    final avatarWidget = Semantics(
      button: true,
      label: effectiveL10n.settingsAvatarUpdateTitle,
      child: InkWell(
        key: const Key('settings_avatar_tap_target'),
        customBorder: const CircleBorder(),
        onTap: () => _openAvatarUpdateModal(user),
        child: Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: ClipOval(
            child: SizedBox(
              width: 54,
              height: 54,
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
                          fontSize: 20,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );

    final userInfoColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.fullName,
          key: const Key('settings_user_fullname'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.cardTitle.copyWith(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            height: 1.28,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          user.email,
          key: const Key('settings_user_email'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
            height: 1.32,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 2.5,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: AppRadii.roundedPill,
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Text(
            _roleLabelForUser(user, effectiveL10n),
            key: const Key('settings_role_label'),
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.05,
            ),
          ),
        ),
      ],
    );

    return Column(
      key: const Key('settings_signed_in_card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1.0);
            final bool showInlineActions =
                constraints.maxWidth >= 310 && textScale < 1.35;

            if (showInlineActions) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  avatarWidget,
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(child: userInfoColumn),
                  const SizedBox(width: AppSpacing.s8),
                  avatarBtn,
                  const SizedBox(width: 4),
                  editProfileBtn,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    avatarWidget,
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(child: userInfoColumn),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                Row(
                  children: [
                    avatarBtn,
                    const SizedBox(width: AppSpacing.s8),
                    editProfileBtn,
                  ],
                ),
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
                  effectiveL10n.settingsUnsavedDraftBanner,
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
                    label: Text(effectiveL10n.settingsResumeEditing),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGroupDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Divider(height: 1, thickness: 1, color: AppColors.borderSoft),
    );
  }

  Widget _buildSettingsMenuTile({
    Key? tileKey,
    required IconData icon,
    required String title,
    String? trailingText,
    bool showChevron = true,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: tileKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: 11,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Center(
                  child: Icon(
                    icon,
                    size: 20,
                    color: AppColors.iconStrong,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  title,
                  style: _menuTitleStyle,
                ),
              ),
              if (trailingText != null && trailingText.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.s8),
                Flexible(
                  flex: 0,
                  child: Text(
                    trailingText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _menuTrailingStyle,
                  ),
                ),
              ],
              if (showChevron) ...[
                const SizedBox(width: AppSpacing.s8),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: AppColors.iconMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyExpansionSection(String currentLocale) {
    final preference = ref.watch(currencyPreferenceProvider);
    final effectiveCurrency = ref.watch(effectiveCurrencyProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final l10n = formatter.l10n;

    final trailingBadge = preference.isAutomatic
        ? '${effectiveCurrency.code} (${effectiveCurrency.symbol})'
        : '${effectiveCurrency.code} (${effectiveCurrency.symbol})';

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        key: const Key('settings_currency_selector'),
        shape: const Border(),
        collapsedShape: const Border(),
        visualDensity: const VisualDensity(vertical: -2),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: 0,
        ),
        childrenPadding: const EdgeInsets.only(
          left: AppSpacing.s16,
          bottom: AppSpacing.s8,
        ),
        title: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: Center(
                child: Icon(
                  LucideIcons.coins,
                  size: 20,
                  color: AppColors.iconStrong,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                l10n.settingsCurrency,
                style: _menuTitleStyle,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              trailingBadge,
              style: _menuTrailingStyle,
            ),
          ],
        ),
        iconColor: AppColors.iconMuted,
        collapsedIconColor: AppColors.iconMuted,
        children: [
          _buildLanguageTile(
            tileKey: const Key('currency_tile_automatic'),
            title: l10n.currencyFollowLanguage,
            subtitle:
                '${l10n.currencyFollowLanguageDesc} (${AppCurrency.defaultForLocale(currentLocale).code} ${AppCurrency.defaultForLocale(currentLocale).symbol})',
            isSelected: preference.isAutomatic,
            onTap: () =>
                ref.read(currencyPreferenceProvider.notifier).setAutomatic(),
          ),
          _buildLanguageTile(
            tileKey: const Key('currency_tile_vnd'),
            title: 'VND (₫)',
            subtitle: l10n.currencyNameVnd,
            isSelected: preference.isManual &&
                preference.manualCurrencyOverride == AppCurrency.vnd,
            onTap: () => ref
                .read(currencyPreferenceProvider.notifier)
                .setManualCurrency(AppCurrency.vnd),
          ),
          _buildLanguageTile(
            tileKey: const Key('currency_tile_usd'),
            title: r'USD ($)',
            subtitle: l10n.currencyNameUsd,
            isSelected: preference.isManual &&
                preference.manualCurrencyOverride == AppCurrency.usd,
            onTap: () => ref
                .read(currencyPreferenceProvider.notifier)
                .setManualCurrency(AppCurrency.usd),
          ),
          _buildLanguageTile(
            tileKey: const Key('currency_tile_krw'),
            title: 'KRW (₩)',
            subtitle: l10n.currencyNameKrw,
            isSelected: preference.isManual &&
                preference.manualCurrencyOverride == AppCurrency.krw,
            onTap: () => ref
                .read(currencyPreferenceProvider.notifier)
                .setManualCurrency(AppCurrency.krw),
          ),
        ],
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
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: 2,
        ),
        title: Text(
          title,
          style: AppTypography.bodyMedium.copyWith(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: AppColors.textStrong,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.caption.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
        ),
        trailing: isSelected
            ? const SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Icon(
                    LucideIcons.check,
                    color: AppColors.iconStrong,
                    size: 18,
                  ),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
