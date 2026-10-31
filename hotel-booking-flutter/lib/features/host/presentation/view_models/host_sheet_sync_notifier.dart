import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/host_repository.dart';
import '../../domain/host_models.dart';

class HostSheetSyncViewState {
  final bool isInitialLoading;
  final HostSheetSyncStatusPayload statusPayload;
  final String? loadError;
  final String? activeAction;
  final String? actionSuccessMessage;
  final String? actionErrorMessage;
  final bool isLoadingLogs;
  final List<HostSheetChangeLogItem> searchedLogs;
  final String? logsError;

  const HostSheetSyncViewState({
    this.isInitialLoading = true,
    this.statusPayload = const HostSheetSyncStatusPayload(),
    this.loadError,
    this.activeAction,
    this.actionSuccessMessage,
    this.actionErrorMessage,
    this.isLoadingLogs = false,
    this.searchedLogs = const [],
    this.logsError,
  });

  bool get isBusy => activeAction != null;

  HostSheetSyncViewState copyWith({
    bool? isInitialLoading,
    HostSheetSyncStatusPayload? statusPayload,
    Object? loadError = _sentinel,
    Object? activeAction = _sentinel,
    Object? actionSuccessMessage = _sentinel,
    Object? actionErrorMessage = _sentinel,
    bool? isLoadingLogs,
    List<HostSheetChangeLogItem>? searchedLogs,
    Object? logsError = _sentinel,
  }) {
    return HostSheetSyncViewState(
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      statusPayload: statusPayload ?? this.statusPayload,
      loadError: identical(loadError, _sentinel)
          ? this.loadError
          : loadError as String?,
      activeAction: identical(activeAction, _sentinel)
          ? this.activeAction
          : activeAction as String?,
      actionSuccessMessage: identical(actionSuccessMessage, _sentinel)
          ? this.actionSuccessMessage
          : actionSuccessMessage as String?,
      actionErrorMessage: identical(actionErrorMessage, _sentinel)
          ? this.actionErrorMessage
          : actionErrorMessage as String?,
      isLoadingLogs: isLoadingLogs ?? this.isLoadingLogs,
      searchedLogs: searchedLogs ?? this.searchedLogs,
      logsError: identical(logsError, _sentinel)
          ? this.logsError
          : logsError as String?,
    );
  }
}

const Object _sentinel = Object();

class HostSheetSyncNotifier extends StateNotifier<HostSheetSyncViewState> {
  final HostRepository _repository;

  HostSheetSyncNotifier(this._repository, {bool autoLoad = true})
      : super(const HostSheetSyncViewState()) {
    if (autoLoad) {
      Future<void>.microtask(() => loadStatus());
    }
  }

  Future<void> loadStatus({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      state = state.copyWith(
        isInitialLoading: true,
        loadError: null,
      );
    }
    try {
      final payload = await _repository.getHostSheetSyncStatus();
      if (!mounted) return;
      state = state.copyWith(
        isInitialLoading: false,
        statusPayload: payload,
        loadError: null,
        searchedLogs: payload.recentLogs,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isInitialLoading: false,
        loadError: _repository.extractErrorMessage(
          error,
          'Không thể tải trạng thái đồng bộ Google Sheets.',
        ),
      );
    }
  }

  void clearMessages() {
    if (!mounted) return;
    state = state.copyWith(
      actionSuccessMessage: null,
      actionErrorMessage: null,
    );
  }

  Future<bool> connectSpreadsheet({
    required String spreadsheetUrlOrId,
    String? hostEditorEmail,
    bool autoSyncEnabled = true,
    bool strictBookingPrecheck = true,
  }) async {
    if (state.isBusy || !mounted) return false;
    state = state.copyWith(
      activeAction: 'connect',
      actionSuccessMessage: null,
      actionErrorMessage: null,
    );
    try {
      final payload = await _repository.connectHostSheet(
        spreadsheetUrlOrId: spreadsheetUrlOrId,
        hostEditorEmail: hostEditorEmail,
        autoSyncEnabled: autoSyncEnabled,
        strictBookingPrecheck: strictBookingPrecheck,
        initializeImmediately: true,
      );
      if (!mounted) return false;
      state = state.copyWith(
        activeAction: null,
        statusPayload: payload,
        loadError: null,
        searchedLogs: payload.recentLogs,
        actionSuccessMessage:
            'Đã kết nối Google Sheets và khởi tạo khung lịch 6 tháng thành công.',
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        activeAction: null,
        actionErrorMessage: _repository.extractErrorMessage(
          error,
          'Không thể kết nối Google Sheets. Vui lòng kiểm tra quyền Editor.',
        ),
      );
      return false;
    }
  }

  Future<bool> syncNow() async {
    if (state.isBusy || !mounted) return false;
    state = state.copyWith(
      activeAction: 'sync_now',
      actionSuccessMessage: null,
      actionErrorMessage: null,
    );
    try {
      final payload = await _repository.syncHostSheetNow();
      if (!mounted) return false;
      state = state.copyWith(
        activeAction: null,
        statusPayload: payload,
        searchedLogs: payload.recentLogs,
        actionSuccessMessage: 'Đã đồng bộ lịch hai chiều thành công.',
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        activeAction: null,
        actionErrorMessage: _repository.extractErrorMessage(
          error,
          'Đồng bộ ngay thất bại. Vui lòng thử lại sau ít phút.',
        ),
      );
      return false;
    }
  }

  Future<bool> initializeStandardCalendar() async {
    if (state.isBusy || !mounted) return false;
    state = state.copyWith(
      activeAction: 'init_calendar',
      actionSuccessMessage: null,
      actionErrorMessage: null,
    );
    try {
      final payload = await _repository.initializeHostSheetCalendar();
      if (!mounted) return false;
      state = state.copyWith(
        activeAction: null,
        statusPayload: payload,
        searchedLogs: payload.recentLogs,
        actionSuccessMessage:
            'Đã kiểm tra và bổ sung khung lịch chuẩn an toàn (giữ nguyên màu lịch hiện có).',
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        activeAction: null,
        actionErrorMessage: _repository.extractErrorMessage(
          error,
          'Không thể khởi tạo lịch chuẩn trên Google Sheets.',
        ),
      );
      return false;
    }
  }

  Future<bool> verifyPermissions() async {
    if (state.isBusy || !mounted) return false;
    state = state.copyWith(
      activeAction: 'verify_permissions',
      actionSuccessMessage: null,
      actionErrorMessage: null,
    );
    try {
      final payload = await _repository.verifyHostSheetPermissions();
      if (!mounted) return false;
      state = state.copyWith(
        activeAction: null,
        statusPayload: payload,
        actionSuccessMessage:
            'Quyền Chỉnh sửa (Editor) trên Google Sheets hoạt động bình thường.',
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        activeAction: null,
        actionErrorMessage: _repository.extractErrorMessage(
          error,
          'Chưa xác minh được quyền Editor. Vui lòng cấp quyền Chỉnh sửa cho email hệ thống.',
        ),
      );
      return false;
    }
  }

  Future<bool> toggleAutoSync(bool enabled) async {
    if (state.isBusy || !mounted) return false;
    state = state.copyWith(
      activeAction: 'update_settings',
      actionSuccessMessage: null,
      actionErrorMessage: null,
    );
    try {
      final payload = await _repository.updateHostSheetSettings(
        autoSyncEnabled: enabled,
      );
      if (!mounted) return false;
      state = state.copyWith(
        activeAction: null,
        statusPayload: payload,
        actionSuccessMessage: enabled
            ? 'Đã bật đồng bộ tự động hai chiều.'
            : 'Đã tạm dừng quét định kỳ (vẫn giữ dữ liệu lịch hiện tại).',
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        activeAction: null,
        actionErrorMessage: _repository.extractErrorMessage(
          error,
          'Không thể cập nhật chế độ đồng bộ tự động.',
        ),
      );
      return false;
    }
  }

  Future<bool> toggleStrictBookingPrecheck(bool enabled) async {
    if (state.isBusy || !mounted) return false;
    state = state.copyWith(
      activeAction: 'update_settings',
      actionSuccessMessage: null,
      actionErrorMessage: null,
    );
    try {
      final payload = await _repository.updateHostSheetSettings(
        strictBookingPrecheck: enabled,
      );
      if (!mounted) return false;
      state = state.copyWith(
        activeAction: null,
        statusPayload: payload,
        actionSuccessMessage: enabled
            ? 'Đã bật kiểm tra trực tiếp Google Sheets trước khi khách đặt phòng.'
            : 'Đã chuyển kiểm tra lịch trước đặt phòng sang chế độ linh hoạt.',
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        activeAction: null,
        actionErrorMessage: _repository.extractErrorMessage(
          error,
          'Không thể cập nhật cấu hình kiểm tra trước đặt phòng.',
        ),
      );
      return false;
    }
  }

  Future<bool> disconnect() async {
    if (state.isBusy || !mounted) return false;
    state = state.copyWith(
      activeAction: 'disconnect',
      actionSuccessMessage: null,
      actionErrorMessage: null,
    );
    try {
      final payload = await _repository.disconnectHostSheet();
      if (!mounted) return false;
      state = state.copyWith(
        activeAction: null,
        statusPayload: payload,
        actionSuccessMessage:
            'Đã ngắt kết nối Google Sheets. Toàn bộ đơn đặt phòng và khóa lịch trên ứng dụng vẫn được giữ nguyên.',
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        activeAction: null,
        actionErrorMessage: _repository.extractErrorMessage(
          error,
          'Không thể ngắt kết nối Google Sheets.',
        ),
      );
      return false;
    }
  }

  Future<bool> resolveConflict({
    required int conflictId,
    required String action,
  }) async {
    if (state.isBusy || !mounted) return false;
    state = state.copyWith(
      activeAction: 'resolve_conflict_$conflictId',
      actionSuccessMessage: null,
      actionErrorMessage: null,
    );
    try {
      final payload = await _repository.resolveHostSheetConflict(
        conflictId: conflictId,
        action: action,
      );
      if (!mounted) return false;
      final successMsg = action == 'undo_bulk_change'
          ? 'Đã hoàn tác khóa hàng loạt và khôi phục các ngày trống an toàn.'
          : action == 'repair_structure'
              ? 'Đã phục hồi cấu trúc bảng tính từ dữ liệu chuẩn của ứng dụng.'
              : 'Đã xử lý cảnh báo xung đột lịch.';
      state = state.copyWith(
        activeAction: null,
        statusPayload: payload,
        searchedLogs: payload.recentLogs,
        actionSuccessMessage: successMsg,
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        activeAction: null,
        actionErrorMessage: _repository.extractErrorMessage(
          error,
          'Không thể xử lý cảnh báo đồng bộ.',
        ),
      );
      return false;
    }
  }

  Future<void> fetchChangeLogs({
    String? search,
    int? listingId,
  }) async {
    if (!mounted) return;
    state = state.copyWith(
      isLoadingLogs: true,
      logsError: null,
    );
    try {
      final items = await _repository.getHostSheetChangeLogs(
        search: search,
        listingId: listingId,
        limit: 30,
      );
      if (!mounted) return;
      state = state.copyWith(
        isLoadingLogs: false,
        searchedLogs: items,
        logsError: null,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingLogs: false,
        logsError: _repository.extractErrorMessage(
          error,
          'Không thể tải nhật ký đồng bộ Google Sheets.',
        ),
      );
    }
  }
}

final hostSheetSyncNotifierProvider = StateNotifierProvider.autoDispose<
    HostSheetSyncNotifier, HostSheetSyncViewState>((ref) {
  final repo = ref.watch(hostRepositoryProvider);
  return HostSheetSyncNotifier(repo);
});
