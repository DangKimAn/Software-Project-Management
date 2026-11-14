// CONFLICT-RESOLVED: Tách các tác vụ chọn ảnh đại diện, tải lên R2 và lưu bộ đệm hồ sơ cục bộ
// khỏi `SettingsScreen` sang `ProfileSettingsActionsViewModel` theo chuẩn MVVM (FLUTTER_RULES.md Mục 2).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/account_profile_models.dart';
import '../../services/avatar_upload_service.dart';

export '../../domain/account_profile_models.dart'
    show AvatarPickedFile, AvatarR2PresignResult;

/// ViewModel điều phối các thao tác chọn/tải ảnh đại diện và ghi bộ đệm hồ sơ người dùng.
class ProfileSettingsActionsViewModel {
  final Ref _ref;

  const ProfileSettingsActionsViewModel(this._ref);

  // Giải thuật mở trình chọn tệp ảnh đại diện từ thiết bị qua `AvatarPickerService`.
  Future<AvatarPickedFile?> pickAvatarFromDevice() {
    return _ref.read(avatarPickerServiceProvider).pickAvatarFromDevice();
  }

  // Giải thuật tải tệp ảnh đại diện đã chọn lên kho lưu trữ đối tượng R2 qua Presigned URL.
  Future<AvatarR2PresignResult> uploadAvatarToR2(AvatarPickedFile file) {
    return _ref.read(avatarUploadServiceProvider).uploadAvatarToR2(file);
  }

  // Giải thuật lưu bản sao thông tin hồ sơ đã đồng bộ xuống `PreferencesService` phục vụ hiển thị nhanh.
  Future<void> cacheSyncedAccountProfile(User updatedUser) async {
    try {
      final prefs = _ref.read(preferencesServiceProvider);
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
      await prefs.clearProfileDraft(updatedUser.id);
    } catch (_) {
      // Bỏ qua lỗi ghi bộ đệm cục bộ khi dữ liệu trên máy chủ đã cập nhật thành công.
    }
  }

  // Giải thuật khôi phục bản nháp hồ sơ chưa lưu từ bộ nhớ cục bộ theo đúng định danh tài khoản hiện tại.
  ProfileDraftData? loadProfileDraft(String userId) {
    final trimmedId = userId.trim();
    if (trimmedId.isEmpty) return null;
    try {
      final raw = _ref.read(preferencesServiceProvider).getProfileDraft(
            trimmedId,
          );
      if (raw == null) return null;
      final draft = ProfileDraftData.fromJson(raw);
      return draft.userId == trimmedId ? draft : null;
    } catch (_) {
      return null;
    }
  }

  // Giải thuật lưu bền vững bản nháp hồ sơ chưa lưu xuống khóa riêng biệt theo `userId`.
  Future<void> saveProfileDraft(ProfileDraftData draft) async {
    if (draft.userId.trim().isEmpty) return;
    try {
      await _ref
          .read(preferencesServiceProvider)
          .saveProfileDraft(draft.userId, draft.toJson());
    } catch (_) {}
  }

  // Giải thuật xóa bản nháp hồ sơ chưa lưu của người dùng khi đã lưu thành công hoặc đăng xuất.
  Future<void> clearProfileDraft(String userId) async {
    if (userId.trim().isEmpty) return;
    try {
      await _ref.read(preferencesServiceProvider).clearProfileDraft(userId);
    } catch (_) {}
  }
}

final profileSettingsActionsProvider =
    Provider<ProfileSettingsActionsViewModel>((ref) {
  return ProfileSettingsActionsViewModel(ref);
});
