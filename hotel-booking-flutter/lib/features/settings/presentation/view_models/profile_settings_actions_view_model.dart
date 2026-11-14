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
    } catch (_) {
      // Bỏ qua lỗi ghi bộ đệm cục bộ khi dữ liệu trên máy chủ đã cập nhật thành công.
    }
  }
}

final profileSettingsActionsProvider =
    Provider<ProfileSettingsActionsViewModel>((ref) {
  return ProfileSettingsActionsViewModel(ref);
});
