import '../../../core/security/url_security_validator.dart';

/// Trạng thái kết nối và đồng bộ hai chiều giữa Host Portal và tệp Google Sheets.
enum HostSheetConnectionState {
  /// Chưa liên kết tệp Google Sheets nào.
  disconnected('disconnected', 'Chưa kết nối'),

  /// Đang kết nối ổn định và đủ quyền ghi (Editor).
  connected('connected', 'Đã kết nối'),

  /// Tài khoản dịch vụ chưa được cấp quyền Editor trên trang tính.
  permissionError('permission_error', 'Lỗi quyền Editor'),

  /// Không tìm thấy tệp trang tính theo Spreadsheet ID đã cấu hình.
  notFound('not_found', 'Không tìm thấy tệp'),

  /// Cấu trúc dòng/cột hoặc tab tháng trên trang tính bị xóa hoặc sửa sai chuẩn.
  structureError('structure_error', 'Sai lệch cấu trúc'),

  /// Đang chạm ngưỡng giới hạn tốc độ truy vấn của Google Sheets API.
  quotaLimited('quota_limited', 'Giới hạn tốc độ Google API'),

  /// Phát sinh lỗi trong tiến trình đồng bộ dữ liệu gần nhất.
  syncError('sync_error', 'Lỗi đồng bộ'),

  /// Chủ nhà chủ động tạm dừng đồng bộ tự động.
  paused('paused', 'Tạm dừng');

  /// Giá trị chuỗi mã hóa trao đổi với REST API Backend.
  final String apiValue;

  /// Nhãn tiếng Việt hiển thị trên huy hiệu trạng thái đồng bộ.
  final String labelVi;

  const HostSheetConnectionState(this.apiValue, this.labelVi);

  /// Cho biết kết nối Google Sheets hiện đang hoạt động bình thường hay không.
  bool get isHealthy => this == HostSheetConnectionState.connected;

  /// Cho biết kết nối đang gặp lỗi quyền, cấu trúc, hạn mức hoặc đồng bộ cần xử lý hay không.
  bool get hasError =>
      this == HostSheetConnectionState.permissionError ||
      this == HostSheetConnectionState.notFound ||
      this == HostSheetConnectionState.structureError ||
      this == HostSheetConnectionState.quotaLimited ||
      this == HostSheetConnectionState.syncError;

  /// Giải mã giá trị thô `raw` từ JSON sang hằng số `HostSheetConnectionState` tương ứng.
  static HostSheetConnectionState fromApi(dynamic raw) {
    final normalized = (raw ?? '').toString().trim().toLowerCase();
    for (final state in HostSheetConnectionState.values) {
      if (state.apiValue == normalized) {
        return state;
      }
    }
    return HostSheetConnectionState.disconnected;
  }
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

bool _asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = (value ?? '').toString().trim().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map<Object?, Object?>) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

/// Thông tin cấu hình tích hợp Google Sheets của một tài khoản Chủ nhà.
class HostSheetIntegrationInfo {
  final int integrationId;
  final String spreadsheetId;
  final String spreadsheetUrl;
  final String spreadsheetTitle;
  final String hostEditorEmail;
  final HostSheetConnectionState status;
  final bool autoSyncEnabled;
  final bool strictBookingPrecheck;
  final bool canWriteVerified;
  final DateTime? permissionVerifiedAt;
  final DateTime? lastSyncedAt;
  final DateTime? lastPolledAt;
  final DateTime? nextPollAt;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final int consecutiveFailures;

  /// Khởi tạo thông tin cấu hình tích hợp Google Sheets của Host.
  const HostSheetIntegrationInfo({
    required this.integrationId,
    required this.spreadsheetId,
    required this.spreadsheetUrl,
    required this.spreadsheetTitle,
    required this.hostEditorEmail,
    required this.status,
    required this.autoSyncEnabled,
    required this.strictBookingPrecheck,
    required this.canWriteVerified,
    this.permissionVerifiedAt,
    this.lastSyncedAt,
    this.lastPolledAt,
    this.nextPollAt,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.consecutiveFailures = 0,
  });

  /// Trả về đường dẫn `https://docs.google.com/spreadsheets/d/...` đã kiểm duyệt an toàn, hoặc `null` nếu không hợp lệ.
  String? get safeSpreadsheetUrl {
    // Giải thuật xác thực liên kết Google Sheets an toàn (Safe Spreadsheet URL Resolution):
    // Đối chiếu `spreadsheetUrl` với `spreadsheetId` kỳ vọng qua `UrlSecurityValidator`;
    // nếu liên kết gốc bị biến dạng, tự động dựng lại URL chính tắc từ `spreadsheetId`.
    if (UrlSecurityValidator.isValidGoogleSpreadsheetUrl(
      spreadsheetUrl,
      expectedSpreadsheetId: spreadsheetId,
    )) {
      return spreadsheetUrl.trim();
    }
    return UrlSecurityValidator.buildCanonicalGoogleSpreadsheetUrl(
      spreadsheetId,
    );
  }

  /// Khởi tạo `HostSheetIntegrationInfo` từ dữ liệu JSON phản hồi của Backend.
  factory HostSheetIntegrationInfo.fromJson(Map<String, dynamic> json) {
    return HostSheetIntegrationInfo(
      integrationId: _asInt(json['integrationId']),
      spreadsheetId: (json['spreadsheetId'] ?? '').toString().trim(),
      spreadsheetUrl: (json['spreadsheetUrl'] ?? '').toString().trim(),
      spreadsheetTitle: (json['spreadsheetTitle'] ?? 'Lịch quản lý chỗ nghỉ')
          .toString()
          .trim(),
      hostEditorEmail: (json['hostEditorEmail'] ?? '').toString().trim(),
      status: HostSheetConnectionState.fromApi(json['status']),
      autoSyncEnabled: _asBool(json['autoSyncEnabled'], true),
      strictBookingPrecheck: _asBool(json['strictBookingPrecheck'], true),
      canWriteVerified: _asBool(json['canWriteVerified']),
      permissionVerifiedAt: _asDateTime(json['permissionVerifiedAt']),
      lastSyncedAt: _asDateTime(json['lastSyncedAt']),
      lastPolledAt: _asDateTime(json['lastPolledAt']),
      nextPollAt: _asDateTime(json['nextPollAt']),
      lastErrorCode: json['lastErrorCode']?.toString(),
      lastErrorMessage: json['lastErrorMessage']?.toString(),
      consecutiveFailures: _asInt(json['consecutiveFailures']),
    );
  }
}

/// Thống kê tổng hợp số lượng chỗ nghỉ, giữ chỗ tạm, xung đột mở và tác vụ chờ của bộ đồng bộ Google Sheets.
class HostSheetSyncStats {
  final int totalListings;
  final int archivedListings;
  final int pendingHoldsCount;
  final int openConflictsCount;
  final int syncErrorsCount;
  final int pendingJobsCount;

  /// Khởi tạo bộ chỉ số thống kê đồng bộ Google Sheets.
  const HostSheetSyncStats({
    this.totalListings = 0,
    this.archivedListings = 0,
    this.pendingHoldsCount = 0,
    this.openConflictsCount = 0,
    this.syncErrorsCount = 0,
    this.pendingJobsCount = 0,
  });

  /// Khởi tạo `HostSheetSyncStats` từ JSON.
  factory HostSheetSyncStats.fromJson(Map<String, dynamic> json) {
    return HostSheetSyncStats(
      totalListings: _asInt(json['totalListings']),
      archivedListings: _asInt(json['archivedListings']),
      pendingHoldsCount: _asInt(json['pendingHoldsCount']),
      openConflictsCount: _asInt(json['openConflictsCount']),
      syncErrorsCount: _asInt(json['syncErrorsCount']),
      pendingJobsCount: _asInt(json['pendingJobsCount']),
    );
  }
}

/// Bản tóm tắt chỗ nghỉ được ánh xạ thành một dòng quản lý trên Google Sheets.
class HostSheetListingSummary {
  final int listingId;
  final String title;
  final String status;

  /// Khởi tạo bản tóm tắt chỗ nghỉ đồng bộ với trang tính.
  const HostSheetListingSummary({
    required this.listingId,
    required this.title,
    required this.status,
  });

  /// Khởi tạo `HostSheetListingSummary` từ JSON.
  factory HostSheetListingSummary.fromJson(Map<String, dynamic> json) {
    return HostSheetListingSummary(
      listingId: _asInt(json['listingId']),
      title: (json['title'] ?? '').toString().trim(),
      status: (json['status'] ?? 'draft').toString().trim(),
    );
  }
}

/// Bản ghi cảnh báo hoặc xung đột lịch phát sinh giữa ứng dụng và tệp Google Sheets.
class HostSheetWarningItem {
  final int conflictId;
  final int? listingId;
  final String? listingTitle;
  final int? bookingId;
  final String? conflictDate;
  final String? monthTab;
  final String conflictType;
  final String severity;
  final String status;
  final String description;
  final bool canUndoBulkChange;
  final DateTime? createdAt;

  /// Khởi tạo bản ghi cảnh báo xung đột đồng bộ trang tính.
  const HostSheetWarningItem({
    required this.conflictId,
    this.listingId,
    this.listingTitle,
    this.bookingId,
    this.conflictDate,
    this.monthTab,
    required this.conflictType,
    this.severity = 'high',
    this.status = 'open',
    required this.description,
    this.canUndoBulkChange = false,
    this.createdAt,
  });

  /// Cho biết xung đột này có phải lỗi hư hỏng cấu trúc trang tính (thiếu dòng, trùng dòng, mất tab tháng) hay không.
  bool get isStructuralConflict =>
      conflictType == 'missing_listing_row' ||
      conflictType == 'duplicate_listing_row' ||
      conflictType == 'missing_month_tab' ||
      conflictType == 'tampered_listing_id' ||
      conflictType == 'sheet_structure_corrupted';

  /// Cho biết cảnh báo xung đột sửa đồng thời (`app_vs_sheet_concurrent`) có hỗ trợ mở khóa trực tiếp một ngày lẻ hay không.
  bool get canUnlockSingleDay =>
      conflictDate != null &&
      conflictDate!.isNotEmpty &&
      conflictType == 'app_vs_sheet_concurrent';

  /// Khởi tạo `HostSheetWarningItem` từ JSON.
  factory HostSheetWarningItem.fromJson(Map<String, dynamic> json) {
    final conflictType = (json['conflictType'] ?? '').toString().trim();
    return HostSheetWarningItem(
      conflictId: _asInt(json['conflictId']),
      listingId: _asNullableInt(json['listingId']),
      listingTitle: json['listingTitle']?.toString(),
      bookingId: _asNullableInt(json['bookingId']),
      conflictDate: json['conflictDate']?.toString(),
      monthTab: json['monthTab']?.toString(),
      conflictType: conflictType,
      severity: (json['severity'] ?? 'high').toString(),
      status: (json['status'] ?? 'open').toString(),
      description: (json['description'] ?? '').toString(),
      canUndoBulkChange: _asBool(
        json['canUndoBulkChange'],
        conflictType == 'bulk_row_block_warning',
      ),
      createdAt: _asDateTime(json['createdAt']),
    );
  }
}

/// Dòng nhật ký ghi nhận một thay đổi đồng bộ hai chiều giữa ứng dụng và Google Sheets.
class HostSheetChangeLogItem {
  final int logId;
  final int? listingId;
  final String? listingTitle;
  final String? targetDate;
  final String direction;
  final String action;
  final String? previousValue;
  final String? newValue;
  final DateTime? detectedAt;

  /// Khởi tạo dòng nhật ký thay đổi đồng bộ trang tính.
  const HostSheetChangeLogItem({
    required this.logId,
    this.listingId,
    this.listingTitle,
    this.targetDate,
    required this.direction,
    required this.action,
    this.previousValue,
    this.newValue,
    this.detectedAt,
  });

  /// Nhãn tiếng Việt mô tả chiều đồng bộ dữ liệu (`Sheets -> Ứng dụng`, `Ứng dụng -> Sheets`, hoặc tự động sửa cấu trúc).
  String get directionLabelVi {
    switch (direction) {
      case 'sheet_to_app':
        return 'Sheets → Ứng dụng';
      case 'app_to_sheet':
        return 'Ứng dụng → Sheets';
      case 'structure_repair':
        return 'Tự động sửa cấu trúc';
      default:
        return 'Hệ thống';
    }
  }

  /// Nhãn tiếng Việt mô tả chi tiết hành động nghiệp vụ được ghi nhận trong nhật ký đồng bộ.
  String get actionLabelVi {
    switch (action) {
      case 'host_block_added':
      case 'host_manual_block':
        return 'Khóa ngày từ Google Sheets';
      case 'host_block_removed':
      case 'host_manual_unblock':
        return 'Mở khóa ngày từ Google Sheets';
      case 'restore_missing_listing_row':
        return 'Khôi phục dòng mã căn bị xóa trên Sheets';
      case 'prebooking_live_block_detected':
        return 'Chặn đặt phòng do ngày vừa khóa trên Sheets';
      case 'bulk_block_reverted':
        return 'Hoàn tác khóa hàng loạt trên dòng';
      case 'booking_synced':
        return 'Đồng bộ đơn đặt phòng lên Sheets';
      case 'structure_initialized':
        return 'Khởi tạo / cập nhật khung lịch chuẩn';
      case 'concurrent_edit_locked':
        return 'Giữ khóa an toàn do sửa đồng thời';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  /// Khởi tạo `HostSheetChangeLogItem` từ JSON.
  factory HostSheetChangeLogItem.fromJson(Map<String, dynamic> json) {
    return HostSheetChangeLogItem(
      logId: _asInt(json['logId']),
      listingId: _asNullableInt(json['listingId']),
      listingTitle: json['listingTitle']?.toString(),
      targetDate: json['targetDate']?.toString(),
      direction: (json['direction'] ?? 'system').toString(),
      action: (json['action'] ?? '').toString(),
      previousValue: json['previousValue']?.toString(),
      newValue: json['newValue']?.toString(),
      detectedAt: _asDateTime(json['detectedAt']),
    );
  }
}

/// Gói dữ liệu toàn cảnh trạng thái tích hợp Google Sheets của Chủ nhà trả về từ `/api/host/sheet-sync/status`.
class HostSheetSyncStatusPayload {
  final bool connected;
  final String? serviceAccountEmail;
  final String defaultHostEditorEmail;
  final HostSheetIntegrationInfo? integration;
  final HostSheetSyncStats stats;
  final List<HostSheetListingSummary> listingsSummary;
  final List<HostSheetWarningItem> openWarnings;
  final List<HostSheetChangeLogItem> recentLogs;

  /// Khởi tạo gói trạng thái tổng thể của bộ đồng bộ Google Sheets.
  const HostSheetSyncStatusPayload({
    this.connected = false,
    this.serviceAccountEmail,
    this.defaultHostEditorEmail = 'athanhnee@gmail.com',
    this.integration,
    this.stats = const HostSheetSyncStats(),
    this.listingsSummary = const [],
    this.openWarnings = const [],
    this.recentLogs = const [],
  });

  /// Trạng thái kết nối hiệu lực sau khi đối chiếu cờ `connected` và cấu hình `integration`.
  HostSheetConnectionState get effectiveState {
    if (!connected || integration == null) {
      return HostSheetConnectionState.disconnected;
    }
    return integration!.status;
  }

  /// Khởi tạo `HostSheetSyncStatusPayload` từ dữ liệu JSON phản hồi của Backend.
  factory HostSheetSyncStatusPayload.fromJson(Map<String, dynamic> json) {
    final integrationMap = json['integration'];
    final rawListings = json['listingsSummary'] is List
        ? json['listingsSummary'] as List<dynamic>
        : const <dynamic>[];
    final rawWarnings = json['openWarnings'] is List
        ? json['openWarnings'] as List<dynamic>
        : const <dynamic>[];
    final rawLogs = json['recentLogs'] is List
        ? json['recentLogs'] as List<dynamic>
        : const <dynamic>[];

    final serviceEmailRaw = json['serviceAccountEmail']?.toString().trim();
    final defaultEditorRaw = json['defaultHostEditorEmail']?.toString().trim();

    return HostSheetSyncStatusPayload(
      connected: _asBool(json['connected']),
      serviceAccountEmail:
          (serviceEmailRaw != null && serviceEmailRaw.isNotEmpty)
              ? serviceEmailRaw
              : null,
      defaultHostEditorEmail:
          (defaultEditorRaw != null && defaultEditorRaw.isNotEmpty)
              ? defaultEditorRaw
              : 'athanhnee@gmail.com',
      integration: integrationMap is Map<Object?, Object?>
          ? HostSheetIntegrationInfo.fromJson(_asMap(integrationMap))
          : null,
      stats: HostSheetSyncStats.fromJson(_asMap(json['stats'])),
      listingsSummary: rawListings
          .whereType<Map<Object?, Object?>>()
          .map((item) => HostSheetListingSummary.fromJson(_asMap(item)))
          .toList(),
      openWarnings: rawWarnings
          .whereType<Map<Object?, Object?>>()
          .map((item) => HostSheetWarningItem.fromJson(_asMap(item)))
          .toList(),
      recentLogs: rawLogs
          .whereType<Map<Object?, Object?>>()
          .map((item) => HostSheetChangeLogItem.fromJson(_asMap(item)))
          .toList(),
    );
  }
}

/// Kiểm tra tính hợp lệ của đường dẫn Google Sheets hoặc mã `Spreadsheet ID` từ `rawInput` trước khi gửi lên Backend.
String? validateGoogleSheetInput(String rawInput) {
  final trimmed = rawInput.trim();
  if (trimmed.isEmpty) {
    return 'Vui lòng dán đường dẫn Google Sheets hoặc mã Spreadsheet ID.';
  }
  final extracted = UrlSecurityValidator.extractGoogleSpreadsheetId(trimmed);
  if (extracted == null) {
    return 'Liên kết không hợp lệ. Chỉ chấp nhận đường dẫn https://docs.google.com/spreadsheets/d/... hoặc Spreadsheet ID hợp lệ.';
  }
  return null;
}

/// Kiểm tra định dạng địa chỉ email quyền Editor tùy chọn `rawEmail` của Chủ nhà.
String? validateOptionalEditorEmail(String? rawEmail) {
  final trimmed = (rawEmail ?? '').trim();
  if (trimmed.isEmpty) return null;
  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  if (!emailRegex.hasMatch(trimmed)) {
    return 'Địa chỉ email Editor không đúng định dạng.';
  }
  return null;
}
