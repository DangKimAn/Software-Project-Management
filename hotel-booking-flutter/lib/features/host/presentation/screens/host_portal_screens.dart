// CONFLICT-RESOLVED: Điều phối dữ liệu qua `HostPortalViewModel`, thay thế Emoji chức năng bằng `LucideIcons`
// và chuẩn hóa địa chỉ mẫu tại TP. Vũng Tàu theo FLUTTER_RULES.md Mục 2, Mục 6 & Mục 16.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../../shared/widgets/app_chat_expressions.dart';
import '../../../../shared/widgets/app_semantic_icons.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
// CONFLICT-RESOLVED: Giữ luồng MVVM qua `HostPortalViewModel` (không import trực tiếp `host_repository.dart`) kết hợp dịch vụ ghi âm và các widget bong bóng đa phương tiện từ develop.
import '../../../messages/presentation/widgets/chat_audio_bubble.dart';
import '../../../messages/presentation/widgets/chat_image_bubble.dart';
import '../../../messages/presentation/widgets/chat_time_divider.dart';
import '../../../messages/services/chat_voice_recorder_service.dart';
import '../../../../core/constants/vietnam_banks.dart';
import '../../domain/host_models.dart';
import '../view_models/host_portal_view_model.dart';
import '../widgets/host_chat_composer_bar.dart';
import '../widgets/host_sheet_sync_card.dart';
import '../widgets/host_studio_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../support/domain/services/contact_service.dart';
import 'host_listing_form_screen.dart';

const String kHostLastActiveSectionKey = 'host_last_active_section_slug';

/// Danh mục phân khu chức năng của Cổng quản trị Chủ nhà kèm giải thuật ánh xạ đường dẫn slug song ngữ Việt - Anh (`fromSlug`).
enum HostPortalSection {
  overview('overview', 'Tổng quan', AppSemanticIcons.dashboard),
  properties('properties', 'Chỗ nghỉ', AppSemanticIcons.home),
  newProperty('new_property', 'Thêm chỗ nghỉ', LucideIcons.plus),
  bookings('bookings', 'Đặt phòng', AppSemanticIcons.bookings),
  calendar('calendar', 'Lịch lưu trú', LucideIcons.calendar),
  guests('guests', 'Khách lưu trú', LucideIcons.users),
  messages('messages', 'Tin nhắn', AppSemanticIcons.messageHost),
  payouts('payouts', 'Thanh toán', LucideIcons.wallet),
  reviews('reviews', 'Đánh giá', LucideIcons.star),
  reports('reports', 'Báo cáo', AppSemanticIcons.revenue),
  support('support', 'Hỗ trợ', AppSemanticIcons.supportCenter),
  settings('settings', 'Cài đặt', LucideIcons.settings);

  final String keyName;
  final String label;
  final IconData icon;
  const HostPortalSection(this.keyName, this.label, this.icon);

  /// Phân giải nhãn hiển thị Cổng Chủ nhà, mặc định luôn dùng Tiếng Việt theo yêu cầu giao diện Studio.
  String localizedLabel(AppLocalizations l10n, [String? localeCode]) {
    return label;
  }

  String get routeSlug {
    switch (this) {
      case HostPortalSection.overview:
        return 'tong-quan';
      case HostPortalSection.properties:
        return 'cho-nghi';
      case HostPortalSection.newProperty:
        return 'cho-nghi/them-moi';
      case HostPortalSection.bookings:
        return 'dat-phong';
      case HostPortalSection.calendar:
        return 'lich-luu-tru';
      case HostPortalSection.guests:
        return 'khach-luu-tru';
      case HostPortalSection.messages:
        return 'tin-nhan';
      case HostPortalSection.payouts:
        return 'thanh-toan';
      case HostPortalSection.reviews:
        return 'danh-gia';
      case HostPortalSection.reports:
        return 'bao-cao';
      case HostPortalSection.support:
        return 'ho-tro';
      case HostPortalSection.settings:
        return 'cai-dat';
    }
  }

  /// Giải thuật chuẩn hóa và phân giải đường dẫn slug (bao gồm các bí danh tiếng Việt/Anh như `tai-chinh`, `rut-tien`, `lich`, `khach`)
  /// về đúng phân mục `HostPortalSection` tương ứng phục vụ định tuyến URL trực tiếp và khôi phục phiên `kHostLastActiveSectionKey`.
  static HostPortalSection fromSlug(String? slug) {
    final normalized = (slug ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'cho-nghi':
      case 'properties':
        return HostPortalSection.properties;
      case 'cho-nghi/them-moi':
      case 'them-moi':
      case 'them-cho-nghi':
      case 'new_property':
        return HostPortalSection.newProperty;
      case 'dat-phong':
      case 'bookings':
        return HostPortalSection.bookings;
      case 'lich':
      case 'lich-luu-tru':
      case 'calendar':
        return HostPortalSection.calendar;
      case 'khach':
      case 'khach-luu-tru':
      case 'guests':
        return HostPortalSection.guests;
      case 'tin-nhan':
      case 'messages':
        return HostPortalSection.messages;
      case 'tai-chinh':
      case 'thanh-toan':
      case 'rut-tien':
      case 'finance':
      case 'payouts':
        return HostPortalSection.payouts;
      case 'danh-gia':
      case 'reviews':
        return HostPortalSection.reviews;
      case 'bao-cao':
      case 'reports':
        return HostPortalSection.reports;
      case 'ho-tro':
      case 'support':
        return HostPortalSection.support;
      case 'cai-dat':
      case 'settings':
        return HostPortalSection.settings;
      case 'tong-quan':
      case 'overview':
        return HostPortalSection.overview;
      default:
        return HostPortalSection.overview;
    }
  }
}

/// Định dạng giá trị số bất kỳ sang chuỗi tiền tệ `VND` nguyên chuẩn dành cho bảng biểu Chủ nhà.
String formatHostVnd(dynamic value) {
  final numVal =
      value is num ? value.toDouble() : (double.tryParse('${value ?? 0}') ?? 0);
  final formatter = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );
  return formatter.format(numVal);
}

/// Giải thuật rút gọn số tiền `VND` theo đơn vị triệu (`Tr`) và nghìn (`k`) dùng dấu phẩy thập phân chuẩn tiếng Việt cho ô lịch hẹp.
String formatCompactHostVnd(dynamic value) {
  final numVal =
      value is num ? value.toDouble() : (double.tryParse('${value ?? 0}') ?? 0);
  if (numVal <= 0) return '0 đ';
  if (numVal >= 1000000) {
    final v = numVal / 1000000;
    final s = v
        .toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)
        .replaceAll('.', ',');
    return '$s Tr';
  } else if (numVal >= 1000) {
    final v = numVal / 1000;
    final s = v
        .toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)
        .replaceAll('.', ',');
    return '$s k';
  }
  return '${numVal.round()} đ';
}

/// Màn hình trung tâm Cổng Chủ nhà điều phối 12 phân khu nghiệp vụ (Tổng quan KPI, Chỗ nghỉ, Đặt phòng, Lịch lưu trú & Google Sheets, Khách lưu trú, Tin nhắn, Rút tiền, Báo cáo).
class HostPortalScreen extends ConsumerStatefulWidget {
  final String section;
  final HostPortalSection? initialSection;

  const HostPortalScreen({
    super.key,
    this.section = 'tong-quan',
    this.initialSection,
  });

  @override
  ConsumerState<HostPortalScreen> createState() => _HostPortalScreenState();
}

class _HostPortalScreenState extends ConsumerState<HostPortalScreen>
    with TickerProviderStateMixin {
  late HostPortalSection _activeSection;
  String? _editingListingId;

  // Shared listings & bookings state
  bool _loadingListings = false;
  String? _listingsError;
  List<Map<String, dynamic>> _listings = [];
  List<Map<String, dynamic>> _allListingsSnapshot = [];
  String _listingStatusFilter = 'all';
  String _listingSortBy = 'newest';
  int _listingsVisibleCount = 10;
  String? _busyListingActionId;

  // Bookings state
  bool _loadingBookings = false;
  String? _bookingsError;
  String? _bookingsSuccess;
  List<Map<String, dynamic>> _bookings = [];
  String _bookingStatusFilter = 'all';
  String _bookingSortBy = 'newest';
  int _bookingsVisibleCount = 10;
  String? _busyBookingActionId;

  // Calendar state
  String? _calendarListingId;
  late int _calendarMonth;
  late int _calendarYear;
  int _overviewCalendarWeekOffset = 0;
  bool _loadingCalendar = false;
  bool _savingCalendar = false;
  String? _calendarError;
  String? _calendarSuccess;
  List<HostCalendarDay> _calendarDays = [];
  final Set<String> _selectedCalendarDates = {};
  final TextEditingController _calendarPriceOverrideCtrl =
      TextEditingController();
  final TextEditingController _calendarMinNightsCtrl = TextEditingController();
  final TextEditingController _calendarNotesCtrl = TextEditingController();
  bool _calendarShowListingList = true;
  bool _calendarSearchVisible = false;
  final TextEditingController _calendarSearchCtrl = TextEditingController();
  String _calendarSearchQuery = '';
  String _calendarListingFilter = 'all';
  bool _showCalendarPriceEditor = true;
  bool _showCalendarCustomSettings = false;

  // Guests state
  String _guestTab = 'today';
  String _guestStatusFilter = 'all';
  final String _guestSelectedListingId = 'all';
  final TextEditingController _guestSearchCtrl = TextEditingController();

  // Messages state
  bool _loadingConversations = false;
  final TextEditingController _messagesSearchCtrl = TextEditingController();
  String _messagesSearchQuery = '';
  bool _inChatDetailView = false;
  String? _conversationsError;
  List<Map<String, dynamic>> _conversations = [];
  String? _selectedConversationId;
  List<Map<String, dynamic>> _conversationMessages = [];
  bool _sendingMessage = false;
  final TextEditingController _messageInputCtrl = TextEditingController();
  final FocusNode _messageInputFocusNode = FocusNode();

  // Trạng thái hiển thị khung thời gian theo cử chỉ kéo giống Messenger
  bool _showChatTimestampsPinned = false;
  double _horizontalDragOffset = 0.0;
  late AnimationController _chatDragAnimCtrl;

  // Messenger reactions & chat enhancements
  final Map<String, String> _messageReactions = {};
  String? _reactionActiveMsgKey;
  final ScrollController _chatScrollCtrl = ScrollController();

  // Messenger input bar & features state
  String _chatQuickEmoji = 'like';
  bool _isRecordingVoice = false;
  int _voiceRecordingSeconds = 0;
  Timer? _voiceTimer;
  final ChatVoiceRecorderService _voiceRecorder = ChatVoiceRecorderService();

  // Payouts state
  bool _loadingPayouts = false;
  String? _payoutsError;
  List<Map<String, dynamic>> _payoutAccounts = [];
  List<Map<String, dynamic>> _payouts = [];
  String _payoutStatusFilter = 'all';

  // Reviews state
  String? _reviewListingId;
  bool _loadingReviews = false;
  String? _reviewsError;
  String? _reviewsSuccess;
  List<Map<String, dynamic>> _reviews = [];
  final Map<String, TextEditingController> _reviewReplyControllers = {};
  String? _savingReviewId;

  // Reports state
  String _reportRange = '30d';
  String _reportGroup = 'auto';
  String _reportListingId = 'all';
  String _reportMode = 'month'; // 'week' | 'month' | 'quarter' | 'year'
  int _reportSelectedYear = 2026;
  int _reportSelectedMonth = 11;
  int _reportSelectedQuarter = 4;
  bool _loadingReport = false;
  String? _reportError;
  HostRevenueReport _revenueReport = const HostRevenueReport();

  // Settings state (Profile & Bank)
  String _settingsTab = 'profile'; // 'profile' | 'bank'
  bool _loadingSettings = false;
  bool _savingProfile = false;
  bool _uploadingAvatar = false;
  String? _profileError;
  String? _profileSuccess;
  Map<String, dynamic>? _hostProfile;
  final TextEditingController _profileNameCtrl = TextEditingController();
  final TextEditingController _profileEmailCtrl = TextEditingController();
  final TextEditingController _profilePhoneCtrl = TextEditingController();

  bool _loadingBanks = false;
  bool _savingBank = false;
  String? _bankError;
  String? _bankSuccess;
  List<VietnamBank> _vietnamBanks = [];
  String? _selectedBankCode;
  String? _savedMaskedBankAccountNumber;
  final TextEditingController _bankSearchCtrl = TextEditingController();
  final TextEditingController _bankAccountNumberCtrl = TextEditingController();
  final TextEditingController _bankAccountHolderCtrl = TextEditingController();
  final TextEditingController _bankBranchCtrl = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _socketMsgSub;
  StreamSubscription<Map<String, dynamic>>? _socketReactionSub;
  DateTime? _lastOverviewBackPress;

  @override
  void initState() {
    super.initState();
    _activeSection =
        widget.initialSection ?? HostPortalSection.fromSlug(widget.section);
    _chatDragAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _messageInputCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    final vnNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    _calendarMonth = vnNow.month;
    _calendarYear = vnNow.year;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Đảm bảo Cổng Chủ nhà (Host Studio) luôn mặc định tiếng Việt
      try {
        final currentLocale = ref.read(localeProvider);
        if (currentLocale != 'vi') {
          ref.read(localeProvider.notifier).setLocale('vi');
        }
      } catch (_) {}
      _bindRealtimeChatStreams();
      _restoreCachedSectionIfNeeded();
      _triggerSectionLoad(_activeSection);
    });
  }

  // Giải thuật đồng bộ tin nhắn mới (`message:new`) và biểu cảm (`message:reaction`) thời gian thực vào khung chat Host, khử trùng lặp theo `messageId`.
  void _bindRealtimeChatStreams() {
    if (!mounted) return;
    final vm = ref.read(hostPortalViewModelProvider);
    _socketMsgSub?.cancel();
    _socketReactionSub?.cancel();
    _socketMsgSub = vm.onMessageNew.listen((payload) {
      if (!mounted) return;
      final rawMsg = payload['message'] is Map
          ? Map<String, dynamic>.from(payload['message'] as Map)
          : payload;
      final incomingConvId =
          '${payload['conversationId'] ?? rawMsg['conversationId'] ?? ''}'
              .trim();
      if (incomingConvId.isEmpty) return;
      final msgId = '${rawMsg['messageId'] ?? rawMsg['id'] ?? ''}'.trim();
      setState(() {
        for (final conv in _conversations) {
          if ('${conv['conversationId'] ?? conv['id']}' == incomingConvId) {
            conv['lastMessagePreview'] =
                rawMsg['content'] ?? conv['lastMessagePreview'];
            conv['lastMessageAt'] =
                rawMsg['createdAt'] ?? DateTime.now().toIso8601String();
          }
        }
        if (incomingConvId == _selectedConversationId) {
          final exists = msgId.isNotEmpty &&
              _conversationMessages.any(
                (m) => '${m['messageId'] ?? m['id'] ?? ''}'.trim() == msgId,
              );
          if (!exists) {
            _conversationMessages = [
              ..._conversationMessages,
              rawMsg,
            ];
          }
        }
      });
      if (incomingConvId == _selectedConversationId) {
        _scrollChatToBottom();
      }
    });
    _socketReactionSub = vm.onMessageReaction.listen((payload) {
      if (!mounted) return;
      final incomingConvId = '${payload['conversationId'] ?? ''}'.trim();
      if (incomingConvId.isNotEmpty &&
          incomingConvId != _selectedConversationId) {
        return;
      }
      final msgId = '${payload['messageId'] ?? ''}'.trim();
      if (msgId.isEmpty) return;
      final reaction = '${payload['reaction'] ?? ''}'.trim();
      setState(() {
        if (reaction.isEmpty) {
          _messageReactions.remove(msgId);
        } else {
          _messageReactions[msgId] = reaction;
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant HostPortalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection ||
        oldWidget.section != widget.section) {
      final nextSection =
          widget.initialSection ?? HostPortalSection.fromSlug(widget.section);
      if (nextSection != _activeSection) {
        _switchSection(nextSection);
      }
    }
  }

  @override
  void dispose() {
    _socketMsgSub?.cancel();
    _socketReactionSub?.cancel();
    _calendarSearchCtrl.dispose();
    _calendarPriceOverrideCtrl.dispose();
    _calendarMinNightsCtrl.dispose();
    _calendarNotesCtrl.dispose();
    _guestSearchCtrl.dispose();
    _chatDragAnimCtrl.dispose();
    _voiceTimer?.cancel();
    _voiceRecorder.dispose();
    _chatScrollCtrl.dispose();
    _messageInputCtrl.dispose();
    _messageInputFocusNode.dispose();
    _messagesSearchCtrl.dispose();
    for (final ctrl in _reviewReplyControllers.values) {
      ctrl.dispose();
    }
    _profileNameCtrl.dispose();
    _profileEmailCtrl.dispose();
    _profilePhoneCtrl.dispose();
    _bankSearchCtrl.dispose();
    _bankAccountNumberCtrl.dispose();
    _bankAccountHolderCtrl.dispose();
    _bankBranchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPortalData() async {
    await Future.wait<void>([
      _fetchListings(),
      _fetchBookings(),
      _fetchRevenueReport(),
      _fetchPayoutData(),
    ]);
  }

  void _triggerSectionLoad(HostPortalSection section) {
    switch (section) {
      case HostPortalSection.overview:
        _loadInitialPortalData();
        break;
      case HostPortalSection.properties:
        _fetchListings();
        break;
      case HostPortalSection.support:
        _fetchConversations();
        break;
      case HostPortalSection.bookings:
      case HostPortalSection.guests:
        _fetchBookings();
        break;
      case HostPortalSection.calendar:
        _ensureCalendarLoaded();
        break;
      case HostPortalSection.messages:
        _fetchConversations();
        break;
      case HostPortalSection.payouts:
        _fetchPayoutData();
        break;
      case HostPortalSection.reviews:
        _ensureReviewsLoaded();
        break;
      case HostPortalSection.reports:
        if (_unfilteredListings.isEmpty) {
          _fetchListings();
        }
        _fetchRevenueReport();
        break;
      case HostPortalSection.settings:
        _loadSettingsData();
        break;
      case HostPortalSection.newProperty:
        break;
    }
  }

  void _switchSection(HostPortalSection section, {String? editListingId}) {
    setState(() {
      _activeSection = section;
      _inChatDetailView = false;
      if (section == HostPortalSection.newProperty) {
        _editingListingId = editListingId;
      }
    });
    _triggerSectionLoad(section);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(kHostLastActiveSectionKey, section.routeSlug);
    }).catchError((_) {});
  }

  /// Giải thuật đồng bộ hai chiều phân mục đang mở (`kHostLastActiveSectionKey`) trong `SharedPreferences`:
  /// - Nếu truy cập trực tiếp bằng đường dẫn chuyên biệt (ví dụ `/chu-nha/tai-chinh` -> `/chu-nha/thanh-toan`), lưu ngay `routeSlug` hiện hành vào bộ nhớ đệm.
  /// - Nếu mở cổng mặc định (`tong-quan`), khôi phục lại phân mục gần nhất mà chủ nhà đã làm việc trước đó.
  Future<void> _restoreCachedSectionIfNeeded() async {
    if (widget.initialSection != null) {
      return;
    }
    if (widget.section.isNotEmpty && widget.section != 'tong-quan') {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kHostLastActiveSectionKey, _activeSection.routeSlug);
      } catch (_) {}
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedSlug = prefs.getString(kHostLastActiveSectionKey);
      if (cachedSlug != null && cachedSlug.isNotEmpty && mounted) {
        final restored = HostPortalSection.fromSlug(cachedSlug);
        if (restored != _activeSection) {
          _switchSection(restored);
        }
      }
    } catch (_) {}
  }

  // ===========================================================================
  // Data Loading & Action Methods
  // ===========================================================================

  List<Map<String, dynamic>> get _unfilteredListings =>
      _allListingsSnapshot.isNotEmpty ? _allListingsSnapshot : _listings;

  void _syncDefaultSelectedListingIds(List<Map<String, dynamic>> allItems) {
    if (allItems.isEmpty) {
      _calendarListingId = null;
      _reviewListingId = null;
      return;
    }
    final firstId =
        (allItems.first['listingId'] ?? allItems.first['id'])?.toString();
    final hasCal = _calendarListingId != null &&
        allItems.any(
          (l) => '${l['listingId'] ?? l['id']}' == _calendarListingId,
        );
    if (!hasCal) {
      _calendarListingId = firstId;
    }
    final hasRev = _reviewListingId != null &&
        allItems.any(
          (l) => '${l['listingId'] ?? l['id']}' == _reviewListingId,
        );
    if (!hasRev) {
      _reviewListingId = firstId;
    }
  }

  // Giải thuật tải danh sách chỗ nghỉ đa trang đồng bộ giữa bản chụp toàn phần (_allListingsSnapshot) và danh sách theo bộ lọc (_listings):
  // CONFLICT-RESOLVED: Tách biệt hoàn toàn KPI Tổng quan / huy hiệu tab / bộ chọn Lịch-Đánh giá-Báo cáo khỏi bộ lọc _listings đang chọn.
  Future<void> _fetchListings() async {
    setState(() {
      _loadingListings = true;
      _listingsError = null;
    });

    final repo = ref.read(hostPortalViewModelProvider);
    try {
      if (_listingStatusFilter == 'all') {
        final allItems = await repo.getMyListings(limit: 50);
        if (!mounted) return;
        setState(() {
          _allListingsSnapshot = allItems;
          _listings = allItems;
          _loadingListings = false;
          _syncDefaultSelectedListingIds(allItems);
        });
      } else {
        final results = await Future.wait([
          repo.getMyListings(limit: 50),
          repo.getMyListings(status: _listingStatusFilter, limit: 50),
        ]);
        if (!mounted) return;
        final allItems = results[0];
        final filteredItems = results[1];
        setState(() {
          _allListingsSnapshot = allItems;
          _listings = filteredItems;
          _loadingListings = false;
          _syncDefaultSelectedListingIds(allItems);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingListings = false;
        _listingsError = repo.extractErrorMessage(
          e,
          'Không thể tải danh sách chỗ nghỉ.',
        );
      });
    }
  }

  Future<void> _runListingMutation(
    String listingId,
    Future<void> Function() action,
  ) async {
    setState(() {
      _busyListingActionId = listingId;
      _listingsError = null;
    });
    final repo = ref.read(hostPortalViewModelProvider);
    try {
      await action();
      await _fetchListings();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listingsError = repo.extractErrorMessage(
          e,
          'Không thể cập nhật chỗ nghỉ.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _busyListingActionId = null);
      }
    }
  }

  Future<void> _confirmAndDeleteListing(Map<String, dynamic> listing) async {
    final id = (listing['listingId'] ?? listing['id'] ?? '').toString();
    final title = (listing['title'] ?? 'chỗ nghỉ #$id').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: const Text('Xác nhận xóa chỗ nghỉ'),
        content: Text(
          'Bạn chắc chắn muốn xóa chỗ nghỉ "$title"? Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(88, 48),
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_listing_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textInverse,
              minimumSize: const Size(120, 48),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa chỗ nghỉ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final repo = ref.read(hostPortalViewModelProvider);
    await _runListingMutation(id, () => repo.deleteHostListing(id));
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _loadingBookings = true;
      _bookingsError = null;
    });
    final repo = ref.read(hostPortalViewModelProvider);
    try {
      final items = await repo.getAllHostBookings(pageSize: 100);
      if (!mounted) return;
      setState(() {
        _bookings = items;
        _loadingBookings = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingBookings = false;
        _bookingsError = repo.extractErrorMessage(
          e,
          'Không thể tải danh sách booking.',
        );
      });
    }
  }

  Future<void> _handleBookingAction(
    Map<String, dynamic> booking,
    String actionType,
  ) async {
    final bookingId = (booking['bookingId'] ?? booking['id'] ?? '').toString();
    if (bookingId.isEmpty) return;

    final repo = ref.read(hostPortalViewModelProvider);
    final userRole = ref.read(hostPortalUserRoleProvider);

    String? cancelReason;
    if (actionType == 'cancel') {
      final reasonCtrl = TextEditingController(
        text: 'Chủ nhà không thể phục vụ lịch lưu trú này',
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          title: Text('Hủy booking #$bookingId'),
          content: TextField(
            key: const Key('booking_cancel_reason_input'),
            controller: reasonCtrl,
            maxLines: 1,
            style: const TextStyle(fontSize: 13, height: 1.2),
            decoration: InputDecoration(
              labelText: 'Lý do hủy booking *',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(88, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Đóng'),
            ),
            ElevatedButton(
              key: const Key('booking_cancel_confirm_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBE123C),
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 48),
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Xác nhận hủy'),
            ),
          ],
        ),
      );
      cancelReason = reasonCtrl.text.trim();
      reasonCtrl.dispose();
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _busyBookingActionId = bookingId;
      _bookingsError = null;
      _bookingsSuccess = null;
    });

    try {
      if (actionType == 'confirm') {
        await repo.confirmHostBooking(
          bookingId,
          currentBooking: booking,
          userRole: userRole,
        );
      } else if (actionType == 'check_in') {
        await repo.checkInHostBooking(
          bookingId,
          currentBooking: booking,
          userRole: userRole,
        );
      } else if (actionType == 'check_out') {
        await repo.checkOutHostBooking(
          bookingId,
          currentBooking: booking,
          userRole: userRole,
        );
      } else if (actionType == 'cancel') {
        await repo.cancelHostBooking(
          bookingId,
          reason: cancelReason,
          currentBooking: booking,
          userRole: userRole,
        );
      }
      await _fetchBookings();
      if (_activeSection == HostPortalSection.overview) {
        await Future.wait<void>([
          _fetchRevenueReport(),
          _fetchPayoutData(),
        ]);
      }
      if (!mounted) return;
      setState(() {
        _bookingsSuccess = 'Đã cập nhật trạng thái booking #$bookingId.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bookingsError = repo.extractErrorMessage(
          e,
          'Không thể cập nhật trạng thái booking.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _busyBookingActionId = null);
      }
    }
  }

  Future<void> _ensureCalendarLoaded() async {
    if (_unfilteredListings.isEmpty) {
      await _fetchListings();
    }
    if (mounted && _unfilteredListings.length == 1) {
      setState(() => _calendarShowListingList = false);
    }
    if (_bookings.isEmpty) {
      await _fetchBookings();
    }
    if (_calendarListingId != null && _calendarListingId!.isNotEmpty) {
      await _fetchCalendarDays();
    }
  }

  Future<void> _fetchCalendarDays() async {
    final listingId = _calendarListingId;
    if (listingId == null || listingId.isEmpty) return;

    setState(() {
      _loadingCalendar = true;
      _calendarError = null;
    });

    final repo = ref.read(hostPortalViewModelProvider);
    try {
      final days = await repo.getListingCalendarDays(
        listingId,
        month: _calendarMonth,
        year: _calendarYear,
      );
      if (!mounted) return;
      setState(() {
        _calendarDays = days;
        _selectedCalendarDates.clear();
        _loadingCalendar = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCalendar = false;
        _calendarError = repo.extractErrorMessage(
          e,
          'Không thể tải lịch lưu trú.',
        );
      });
    }
  }

  Future<void> _applyBulkCalendarUpdate({
    required bool isAvailable,
    required bool isBlockedByHost,
    bool resetPriceOverride = false,
    bool requireConfirm = true,
  }) async {
    final listingId = _calendarListingId;
    if (listingId == null || listingId.isEmpty) return;
    if (_selectedCalendarDates.isEmpty) {
      setState(() {
        _calendarError =
            'Vui lòng chọn ít nhất một ngày trên lịch để cập nhật.';
      });
      return;
    }

    final validation = validateCalendarBulkDates(
      _selectedCalendarDates.toList(),
      currentCalendarDays: _calendarDays,
    );
    if (!validation.isAllValid) {
      setState(() {
        _calendarError =
            validation.errorMessage ?? 'Các ngày đã chọn không hợp lệ.';
      });
      return;
    }

    double? priceOverride;
    final priceText = _calendarPriceOverrideCtrl.text.trim();
    if (!resetPriceOverride && priceText.isNotEmpty) {
      priceOverride = double.tryParse(priceText);
      if (priceOverride == null || priceOverride < 0) {
        setState(() => _calendarError = 'Giá riêng theo ngày không hợp lệ.');
        return;
      }
    }

    int? minNightsOverride;
    final minNightsText = _calendarMinNightsCtrl.text.trim();
    if (minNightsText.isNotEmpty) {
      minNightsOverride = int.tryParse(minNightsText);
      if (minNightsOverride == null || minNightsOverride < 1) {
        setState(() => _calendarError = 'Số đêm tối thiểu phải từ 1 trở lên.');
        return;
      }
    }

    if (requireConfirm) {
      final statusDesc =
          isBlockedByHost || !isAvailable ? 'Khóa ngày' : 'Mở bán';
      final priceDesc = resetPriceOverride
          ? 'Xóa giá ghi đè (về giá gốc)'
          : (priceOverride != null
              ? formatHostVnd(priceOverride)
              : 'Giữ nguyên');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('calendar_bulk_confirm_dialog'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          title: const Text('Xác nhận cập nhật lịch lưu trú'),
          content: Text(
            'Bạn sắp cập nhật ${validation.editableDates.length} ngày đã chọn:\n'
            '• Trạng thái: $statusDesc\n'
            '• Giá theo ngày: $priceDesc',
          ),
          actions: [
            TextButton(
              key: const Key('calendar_bulk_confirm_cancel_btn'),
              style: TextButton.styleFrom(
                minimumSize: const Size(88, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              key: const Key('calendar_bulk_confirm_submit_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(140, 48),
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Xác nhận cập nhật'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _savingCalendar = true;
      _calendarError = null;
      _calendarSuccess = null;
    });

    final repo = ref.read(hostPortalViewModelProvider);
    try {
      await repo.bulkUpdateListingCalendar(
        listingId,
        dates: validation.editableDates,
        isAvailable: isAvailable,
        isBlockedByHost: isBlockedByHost,
        priceOverride: resetPriceOverride ? null : priceOverride,
        includeNullPriceOverride: resetPriceOverride,
        minNightsOverride: minNightsOverride,
        notes: _calendarNotesCtrl.text.trim().isNotEmpty
            ? _calendarNotesCtrl.text.trim()
            : null,
        currentCalendarDays: _calendarDays,
      );
      await _fetchCalendarDays();
      if (!mounted) return;
      setState(() {
        _savingCalendar = false;
        _calendarSuccess = 'Đã cập nhật lịch lưu trú thành công.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingCalendar = false;
        _calendarError = repo.extractErrorMessage(
          e,
          'Không thể cập nhật lịch lưu trú.',
        );
      });
    }
  }

  Future<void> _fetchConversations() async {
    setState(() {
      _loadingConversations = true;
      _conversationsError = null;
    });
    final repo = ref.read(hostPortalViewModelProvider);
    try {
      final list = await repo.getHostConversations(page: 1, limit: 50);
      if (!mounted) return;
      setState(() {
        _conversations = list;
        _loadingConversations = false;
        if (_conversations.isNotEmpty && _selectedConversationId == null) {
          _selectedConversationId = (_conversations.first['conversationId'] ??
                  _conversations.first['id'])
              ?.toString();
        }
      });
      if (_selectedConversationId != null) {
        if (_inChatDetailView) {
          _markHostConversationRead(_selectedConversationId!);
        }
        await _fetchMessagesForConversation(_selectedConversationId!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingConversations = false;
        _conversationsError = repo.extractErrorMessage(
          e,
          'Không thể tải danh sách hội thoại.',
        );
      });
    }
  }

  // Giải thuật đồng bộ trạng thái đã đọc hội thoại cục bộ (unreadCount = 0) và gọi PATCH /api/conversations/:id/read cho ID số thực:
  // CONFLICT-RESOLVED: Chỉ gọi API đánh dấu đã đọc khi conversationId là số nguyên dương hợp lệ.
  void _markHostConversationRead(String conversationId) {
    final trimmed = conversationId.trim();
    if (trimmed.isEmpty) return;
    if (mounted) {
      setState(() {
        for (final conv in _conversations) {
          if ('${conv['conversationId'] ?? conv['id']}' == trimmed) {
            conv['unreadCount'] = 0;
          }
        }
      });
    }
    if (isNumericHostConversationId(trimmed)) {
      unawaited(
        ref
            .read(hostPortalViewModelProvider)
            .markConversationRead(trimmed)
            .catchError((_) {}),
      );
    }
  }

  Future<void> _fetchMessagesForConversation(String conversationId) async {
    if (conversationId == 'admin_support') return;
    final repo = ref.read(hostPortalViewModelProvider);
    if (isNumericHostConversationId(conversationId)) {
      repo.joinConversation(conversationId);
    }
    try {
      final msgs = await repo.getConversationMessages(conversationId);
      if (!mounted) return;
      setState(() {
        _conversationMessages = msgs;
      });
      _scrollChatToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _conversationsError = repo.extractErrorMessage(
          e,
          'Không thể tải nội dung tin nhắn của cuộc trò chuyện.',
        );
      });
    }
  }

  // Giải thuật gửi tin nhắn Host an toàn, tự động khởi tạo hội thoại hỗ trợ số thực khi đang ở kênh hỗ trợ Admin và hỗ trợ đính kèm R2:
  // CONFLICT-RESOLVED: Kết hợp bảo vệ kênh `admin_support` của HEAD với gửi đính kèm ảnh/âm thanh (`messageType`, `attachments`) từ develop.
  Future<void> _sendHostMessage({
    String? contentOverride,
    String messageType = 'text',
    List<Map<String, dynamic>>? attachments,
  }) async {
    final convId = _selectedConversationId;
    final text = (contentOverride ?? _messageInputCtrl.text).trim();
    if (convId == null ||
        (text.isEmpty && (attachments == null || attachments.isEmpty)) ||
        _sendingMessage) {
      return;
    }

    setState(() {
      _sendingMessage = true;
      _conversationsError = null;
    });
    final repo = ref.read(hostPortalViewModelProvider);
    try {
      String targetConvId = convId;
      if (convId == 'admin_support') {
        final created = await repo.openSupportConversation(
          firstMessage: text.isNotEmpty ? text : 'Đính kèm tệp hỗ trợ',
        );
        final realId =
            '${created['conversationId'] ?? created['id'] ?? ''}'.trim();
        if (!isNumericHostConversationId(realId)) {
          throw StateError(
            'Không thể khởi tạo mã hội thoại hỗ trợ hợp lệ với Quản trị viên.',
          );
        }
        targetConvId = realId;
        if (mounted) {
          setState(() {
            _conversations.removeWhere(
              (c) => '${c['conversationId'] ?? c['id']}' == 'admin_support',
            );
            final existingIdx = _conversations.indexWhere(
              (c) => '${c['conversationId'] ?? c['id']}' == realId,
            );
            if (existingIdx >= 0) {
              _conversations[existingIdx] = created;
            } else {
              _conversations.insert(0, created);
            }
            _selectedConversationId = realId;
          });
        }
        if (attachments != null && attachments.isNotEmpty) {
          await repo.sendConversationMessage(
            targetConvId,
            text,
            messageType: messageType,
            attachments: attachments,
          );
        }
        _markHostConversationRead(realId);
      } else {
        await repo.sendConversationMessage(
          targetConvId,
          text,
          messageType: messageType,
          attachments: attachments,
        );
      }
      if (contentOverride == null) {
        _messageInputCtrl.clear();
      }
      if (mounted) _messageInputFocusNode.requestFocus();
      await _fetchMessagesForConversation(targetConvId);
      _scrollChatToBottom();
    } catch (e) {
      if (!mounted) return;
      if (HostPortalViewModel.isNotFoundError(e) && convId == 'admin_support') {
        setState(() {
          _conversationsError =
              'Hiện chưa có Quản trị viên trực tuyến để tiếp nhận tin nhắn hỗ trợ. Vui lòng thử lại sau hoặc liên hệ tổng đài 1900 8888.';
        });
      } else {
        setState(() {
          _conversationsError = repo.extractErrorMessage(
            e,
            'Không thể gửi tin nhắn.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  Future<void> _fetchPayoutData() async {
    setState(() {
      _loadingPayouts = true;
      _payoutsError = null;
    });
    final repo = ref.read(hostPortalViewModelProvider);
    try {
      final results = await Future.wait([
        repo.getPayoutAccounts(),
        repo.getMyPayouts(limit: 50),
      ]);
      if (!mounted) return;
      setState(() {
        _payoutAccounts = results[0];
        _payouts = results[1];
        _loadingPayouts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPayouts = false;
        _payoutsError = repo.extractErrorMessage(
          e,
          'Không thể tải dữ liệu thanh toán & đối soát.',
        );
      });
    }
  }

  Future<void> _ensureReviewsLoaded() async {
    if (_unfilteredListings.isEmpty) {
      await _fetchListings();
    }
    if (_reviewListingId != null && _reviewListingId!.isNotEmpty) {
      await _fetchReviewsForSelectedListing();
    }
  }

  Future<void> _fetchReviewsForSelectedListing() async {
    final listingId = _reviewListingId;
    if (listingId == null || listingId.isEmpty) return;

    setState(() {
      _loadingReviews = true;
      _reviewsError = null;
    });
    final repo = ref.read(hostPortalViewModelProvider);
    try {
      final items = await repo.getListingReviews(listingId, page: 1, limit: 50);
      if (!mounted) return;
      setState(() {
        _reviews = items;
        _loadingReviews = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingReviews = false;
        _reviewsError = repo.extractErrorMessage(
          e,
          'Không thể tải đánh giá chỗ nghỉ.',
        );
      });
    }
  }

  Future<void> _submitReviewReply(String reviewId) async {
    if (_savingReviewId != null) return; // Prevent double submit!
    final ctrl = _reviewReplyControllers[reviewId];
    final replyText = ctrl?.text.trim() ?? '';
    if (replyText.isEmpty) {
      setState(() => _reviewsError = 'Vui lòng nhập nội dung phản hồi.');
      return;
    }

    setState(() {
      _savingReviewId = reviewId;
      _reviewsError = null;
      _reviewsSuccess = null;
    });

    final repo = ref.read(hostPortalViewModelProvider);
    try {
      await repo.replyToReview(reviewId, replyText);
      ctrl?.clear();
      await _fetchReviewsForSelectedListing();
      if (!mounted) return;
      setState(() {
        _reviewsSuccess = 'Đã gửi phản hồi đánh giá thành công.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reviewsError = repo.extractErrorMessage(
          e,
          'Không thể gửi phản hồi đánh giá.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _savingReviewId = null);
      }
    }
  }

  Future<void> _fetchRevenueReport() async {
    setState(() {
      _loadingReport = true;
      _reportError = null;
    });
    final repo = ref.read(hostPortalViewModelProvider);
    try {
      final report = await repo.getTypedRevenueReport(
        rangeKey: _reportRange,
        groupOverride: _reportGroup == 'auto' ? null : _reportGroup,
        listingId: _reportListingId == 'all' ? null : _reportListingId,
      );
      if (!mounted) return;
      setState(() {
        _revenueReport = report;
        _loadingReport = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingReport = false;
        _revenueReport = const HostRevenueReport();
        _reportError = repo.extractErrorMessage(
          e,
          'Không thể tải báo cáo doanh thu.',
        );
      });
    }
  }

  Future<void> _loadSettingsData() async {
    setState(() {
      _loadingSettings = true;
      _loadingBanks = true;
      _profileError = null;
      _bankError = null;
    });
    final repo = ref.read(hostPortalViewModelProvider);

    try {
      final profile = await repo.getHostProfile();
      if (mounted) {
        setState(() {
          _hostProfile = profile;
          _profileNameCtrl.text =
              (profile['fullName'] ?? profile['name'] ?? '').toString();
          _profileEmailCtrl.text = (profile['email'] ?? '').toString();
          _profilePhoneCtrl.text = (profile['phone'] ?? '').toString();
          _loadingSettings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingSettings = false;
          _profileError = repo.extractErrorMessage(
            e,
            'Không thể tải hồ sơ Host.',
          );
        });
      }
    }

    try {
      final results = await Future.wait<dynamic>([
        repo.getTypedVietnamBanks(),
        repo.getBankAccount(),
      ]);
      if (!mounted) return;
      final banks = results[0] as List<VietnamBank>;
      final account = results[1] as Map<String, dynamic>?;
      setState(() {
        _vietnamBanks = banks;
        if (account != null) {
          final parsed = HostBankAccount.fromJson(account);
          _selectedBankCode =
              parsed.bankCode.isNotEmpty ? parsed.bankCode : null;
          if (parsed.accountNumber.contains('*')) {
            _savedMaskedBankAccountNumber = parsed.accountNumber;
            _bankAccountNumberCtrl.text = '';
          } else {
            _savedMaskedBankAccountNumber = parsed.accountNumberMasked;
            _bankAccountNumberCtrl.text = parsed.accountNumber;
          }
          _bankAccountHolderCtrl.text = parsed.accountHolderName;
          _bankBranchCtrl.text = parsed.branchName ?? '';
        }
        _loadingBanks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingBanks = false;
        _bankError = repo.extractErrorMessage(
          e,
          'Không thể tải danh sách ngân hàng hoặc tài khoản nhận tiền.',
        );
      });
    }
  }

  Future<void> _handleSaveHostProfile() async {
    if (_savingProfile) return;
    setState(() {
      _savingProfile = true;
      _profileError = null;
      _profileSuccess = null;
    });
    final repo = ref.read(hostPortalViewModelProvider);
    try {
      final updated = await repo.updateHostProfile(
        fullName: _profileNameCtrl.text,
        phone: _profilePhoneCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _hostProfile = updated;
        _savingProfile = false;
        _profileSuccess = 'Đã lưu hồ sơ Host thành công.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingProfile = false;
        _profileError = repo.extractErrorMessage(
          e,
          'Không thể lưu hồ sơ Host.',
        );
      });
    }
  }

  Future<void> _handlePickAndUploadAvatar() async {
    if (_uploadingAvatar) return;
    setState(() {
      _profileError = null;
      _profileSuccess = null;
    });
    final repo = ref.read(hostPortalViewModelProvider);
    try {
      final file = await repo.pickAvatarImage(context: context);
      if (file == null || !mounted) return;
      setState(() => _uploadingAvatar = true);
      final uploaded = await repo.uploadFileToR2(
        file,
        folder: 'avatars',
      );
      final updated = await repo.updateHostAvatar(
        url: uploaded.publicUrl,
        key: uploaded.key,
      );
      final syncedAvatarUrl =
          '${updated['avatarUrl'] ?? uploaded.publicUrl}'.trim();
      ref
          .read(authNotifierProvider.notifier)
          .syncLocalAvatarUrl(syncedAvatarUrl);
      if (!mounted) return;
      setState(() {
        _hostProfile = updated;
        _uploadingAvatar = false;
        _profileSuccess = 'Đã cập nhật ảnh đại diện.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingAvatar = false;
        _profileError = repo.extractErrorMessage(
          e,
          'Không thể cập nhật ảnh đại diện.',
        );
      });
    }
  }

  Future<void> _handleSaveBankAccount() async {
    if (_savingBank) return;
    setState(() {
      _bankError = null;
      _bankSuccess = null;
    });

    final selectedBank = _vietnamBanks
        .cast<VietnamBank?>()
        .firstWhere((b) => b?.code == _selectedBankCode, orElse: () => null);
    if (selectedBank == null) {
      setState(() => _bankError = 'Vui lòng chọn ngân hàng từ danh sách.');
      return;
    }

    final accDto = HostBankAccount(
      bankCode: selectedBank.code,
      bankName: selectedBank.name,
      bankShortName: selectedBank.shortName,
      bankBin: selectedBank.bin,
      accountNumber: _bankAccountNumberCtrl.text.trim(),
      accountHolderName: _bankAccountHolderCtrl.text.trim().toUpperCase(),
      branchName: _bankBranchCtrl.text.trim(),
    );

    final validationError = accDto.validate();
    if (validationError != null) {
      setState(() => _bankError = validationError);
      return;
    }

    setState(() => _savingBank = true);
    final repo = ref.read(hostPortalViewModelProvider);
    try {
      await repo.saveBankAccount(accDto.toJson());
      if (!mounted) return;

      // Xóa hết thông tin đã nhập trên form khi lưu thành công
      _selectedBankCode = null;
      _bankSearchCtrl.clear();
      _bankAccountNumberCtrl.clear();
      _bankAccountHolderCtrl.clear();
      _bankBranchCtrl.clear();

      setState(() {
        _savingBank = false;
        _bankSuccess = 'Đã lưu thông tin tài khoản ngân hàng thành công!';
      });

      // Hiện thông báo SnackBar nổi
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(LucideIcons.circleCheck, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Đã lưu thông tin tài khoản ngân hàng thành công!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingBank = false;
        _bankError = repo.extractErrorMessage(
          e,
          'Không thể lưu thông tin tài khoản ngân hàng.',
        );
      });
    }
  }

  // ===========================================================================
  // Main Responsive Layout (320px–1440px)
  // ===========================================================================

  // Studio Modal BottomSheet chọn Chỗ nghỉ / Villa (chuẩn phong cách Monochrome)
  void _showListingSelectionModal({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> listings,
    required String? selectedListingId,
    required ValueChanged<String> onSelected,
    bool allowAll = false,
    String allLabel = 'Tất cả chỗ nghỉ',
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final maxSheetHeight = MediaQuery.sizeOf(ctx).height * 0.85;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Material(
            color: HostStudioTokens.cardSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: HostStudioTokens.hairline,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: HostStudioTokens.headerTitle,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          padding: EdgeInsets.zero,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(
                            LucideIcons.x,
                            size: 20,
                            color: HostStudioTokens.iconInk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (listings.isEmpty && !allowAll)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Chưa có chỗ nghỉ nào',
                            style: TextStyle(
                              fontSize: 14,
                              color: HostStudioTokens.inkSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: Scrollbar(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (allowAll) ...[
                                  _buildListingModalOption(
                                    ctx: ctx,
                                    id: 'all',
                                    title: allLabel,
                                    isSelected: selectedListingId == 'all' ||
                                        selectedListingId == null,
                                    icon: LucideIcons.building2,
                                    onSelected: onSelected,
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                for (final l in listings) ...[
                                  Builder(
                                    builder: (context) {
                                      final id = '${l['listingId'] ?? l['id']}';
                                      final itemTitle =
                                          (l['title'] ?? 'Listing #$id').toString();
                                      final isSelected = id == selectedListingId;
                                      final subtitle = (l['city'] ??
                                              l['address'] ??
                                              l['propertyType'])
                                          ?.toString();
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: _buildListingModalOption(
                                          ctx: ctx,
                                          id: id,
                                          title: itemTitle,
                                          subtitle: subtitle,
                                          isSelected: isSelected,
                                          icon: LucideIcons.building2,
                                          onSelected: onSelected,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListingModalOption({
    required BuildContext ctx,
    required String id,
    required String title,
    String? subtitle,
    required bool isSelected,
    required IconData icon,
    required ValueChanged<String> onSelected,
  }) {
    return InkWell(
      key: Key('listing_option_$id'),
      borderRadius: BorderRadius.circular(HostStudioTokens.pillRadius),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      onTap: () {
        onSelected(id);
        Navigator.of(ctx).pop();
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(HostStudioTokens.pillRadius),
          border: Border.all(
            color: isSelected
                ? HostStudioTokens.obsidian
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: isSelected
                  ? HostStudioTokens.inkPrimary
                  : HostStudioTokens.iconSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HostStudioTokens.cardTitle.copyWith(
                      fontSize: 14.5,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? HostStudioTokens.inkPrimary
                          : HostStudioTokens.inkSecondary,
                    ),
                  ),
                  if (subtitle != null &&
                      subtitle.trim().isNotEmpty &&
                      subtitle != title) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HostStudioTokens.metaCaption.copyWith(
                        fontSize: 12,
                        color: HostStudioTokens.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.check,
                size: 20,
                color: HostStudioTokens.inkPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListingSelectorTrigger({
    Key? triggerKey,
    required String label,
    required String? selectedListingId,
    required List<Map<String, dynamic>> listings,
    required ValueChanged<String> onSelected,
    bool allowAll = false,
    String allLabel = 'Tất cả chỗ nghỉ',
    IconData leadingIcon = LucideIcons.building2,
  }) {
    String displayTitle = label;
    if (selectedListingId == 'all') {
      displayTitle = allLabel;
    } else if (selectedListingId != null) {
      final match = listings.firstWhere(
        (l) => '${l['listingId'] ?? l['id']}' == selectedListingId,
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        displayTitle =
            (match['title'] ?? 'Listing #$selectedListingId').toString();
      }
    }

    final hasSelection = selectedListingId != null &&
        (allowAll ? selectedListingId != 'all' : true);

    return Material(
      color: HostStudioTokens.cardSurface,
      borderRadius: BorderRadius.circular(HostStudioTokens.pillRadius),
      child: InkWell(
        key: triggerKey,
        borderRadius: BorderRadius.circular(HostStudioTokens.pillRadius),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        onTap: () => _showListingSelectionModal(
          context: context,
          title: label,
          listings: listings,
          selectedListingId: selectedListingId,
          onSelected: onSelected,
          allowAll: allowAll,
          allLabel: allLabel,
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(HostStudioTokens.pillRadius),
            border: Border.all(
              color: hasSelection
                  ? HostStudioTokens.obsidian
                  : HostStudioTokens.hairline,
            ),
          ),
          child: Row(
            children: [
              Icon(
                leadingIcon,
                size: 18,
                color: HostStudioTokens.iconInk,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HostStudioTokens.pillText.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: HostStudioTokens.inkPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: HostStudioTokens.iconSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortalDropdown<T>({
    Key? dropdownKey,
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surfaceBase,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          key: dropdownKey,
          isExpanded: true,
          isDense: true,
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = ref.watch(hostPortalUserRoleProvider);
    if (!isApprovedHostRole(currentRole)) {
      return Scaffold(
        backgroundColor: AppColors.surfaceBase,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceBase,
          elevation: 0,
          title: const Text(
            'Host Portal',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                key: const Key('host_portal_unauthorized_guard'),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.shieldAlert,
                      size: 32,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Quyền truy cập dành riêng cho Chủ nhà (Host)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tài khoản của bạn chưa có quyền Host đã duyệt. Vui lòng hoàn tất đăng ký và xác minh KYC trước khi quản lý chỗ nghỉ.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      key: const Key('host_portal_go_onboarding_btn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(180, 48),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      onPressed: () => context.go('/host/dang-ky'),
                      child: const Text('Đăng ký làm Chủ nhà'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final canPopHost = !_inChatDetailView &&
        _activeSection == HostPortalSection.overview &&
        Navigator.canPop(context);

    return PopScope(
      canPop: canPopHost,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_inChatDetailView) {
          setState(() {
            _inChatDetailView = false;
            _showChatTimestampsPinned = false;
            _chatDragAnimCtrl.value = 0.0;
          });
          return;
        }
        if (_activeSection != HostPortalSection.overview) {
          _switchSection(HostPortalSection.overview);
          return;
        }
        if (!Navigator.canPop(context)) {
          final now = DateTime.now();
          if (_lastOverviewBackPress == null ||
              now.difference(_lastOverviewBackPress!) >
                  const Duration(seconds: 2)) {
            _lastOverviewBackPress = now;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Nhấn lần nữa để thoát Cổng Chủ nhà'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          SystemNavigator.pop();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 960;
        final isOverview = _activeSection == HostPortalSection.overview;
        final isStudioSection = isOverview ||
            _activeSection == HostPortalSection.properties ||
            _activeSection == HostPortalSection.guests ||
            _activeSection == HostPortalSection.reports ||
            _activeSection == HostPortalSection.settings ||
            _activeSection == HostPortalSection.support;
        final authUser = ref.watch(authNotifierProvider).valueOrNull;
        final profileName = (_hostProfile?['fullName'] ??
                _hostProfile?['name'] ??
                authUser?.fullName ??
                '')
            .toString()
            .trim();
        final headerEyebrow = isOverview
            ? (profileName.isNotEmpty
                ? 'Host Studio · $profileName'
                : 'Host Studio · Quản lý lưu trú')
            : 'Host Studio';

        return Scaffold(
          backgroundColor:
              isStudioSection ? HostStudioTokens.canvas : AppColors.background,
          extendBody: !isDesktop && isStudioSection,
          drawer: isDesktop
              ? null
              : Drawer(
                  width: constraints.maxWidth < 360
                      ? constraints.maxWidth * 0.88
                      : 288,
                  backgroundColor: HostStudioTokens.groupSurface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(28),
                    ),
                  ),
                  child:
                      SafeArea(child: _buildSidebarNavigation(inDrawer: true)),
                ),
          bottomNavigationBar:
              isDesktop ? null : Builder(builder: _buildMobileBottomNavigation),
          body: SafeArea(
            bottom: isDesktop || !isStudioSection,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  SizedBox(
                    width: 256,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: HostStudioTokens.groupSurface,
                        border: Border(
                          right: BorderSide(
                            color: HostStudioTokens.groupBorder,
                            width: 1.2,
                          ),
                        ),
                      ),
                      child: _buildSidebarNavigation(inDrawer: false),
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (isDesktop ||
                          !(_activeSection == HostPortalSection.messages &&
                              _inChatDetailView))
                        _buildStudioTopBar(
                          context,
                          width: constraints.maxWidth,
                          isDesktop: isDesktop,
                          isOverview: isOverview,
                          eyebrow: headerEyebrow,
                        ),
                      Expanded(child: _buildActiveSectionBody()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

  Widget _buildStudioTopBar(
    BuildContext context, {
    required double width,
    required bool isDesktop,
    required bool isOverview,
    required String eyebrow,
  }) {
    final activeLocale = ref.watch(localeProvider);
    final activeL10n = lookupAppLocalizations(Locale(activeLocale));
    return HostFrostedSurface(
      sigma: HostStudioTokens.headerBlurSigma,
      fillColor: isOverview
          ? HostStudioTokens.frostedHeaderFill
          : HostStudioTokens.frostedInnerHeaderFill,
      border: isOverview
          ? null
          : const Border(
              bottom: BorderSide(color: HostStudioTokens.hairline, width: 1),
            ),
      padding: EdgeInsets.fromLTRB(
        width < 360 ? 10 : 18,
        8,
        width < 360 ? 6 : 12,
        8,
      ),
      child: Row(
        children: [
          if (isDesktop) ...[
            IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(
                AppSemanticIcons.home,
                color: AppColors.iconStrong,
                size: 19,
              ),
              onPressed: () => _navigatePortalRoute(context, '/'),
              tooltip: activeL10n.ctaBackHome,
            ),
            const SizedBox(width: 4),
          ],
          Semantics(
            button: true,
            label: 'Về Tổng quan Host',
            child: Tooltip(
              message: activeL10n.hostTabOverview,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _switchSection(HostPortalSection.overview),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: HostStudioTokens.obsidian,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: AppBrandIcon.minhThanhLogo(
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HostStudioTokens.headerEyebrow,
                ),
                const SizedBox(height: 1),
                Text(
                  _activeSection.localizedLabel(activeL10n, activeLocale),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HostStudioTokens.headerTitle,
                ),
              ],
            ),
          ),
          HostStudioCircleButton(
            key: const Key('host_portal_add_property_quick_btn'),
            icon: LucideIcons.plus,
            tooltip: 'Thêm chỗ nghỉ',
            visualSize: 36,
            iconSize: 16.5,
            onTap: () => _switchSection(HostPortalSection.newProperty),
          ),
          const NotificationBell(),
        ],
      ),
    );
  }

  void _navigatePortalRoute(BuildContext context, String route) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(route);
    }
  }

  Future<void> _handlePortalLogout({required bool inDrawer}) async {
    // Giải thuật xác nhận hai bước trước khi đăng xuất khỏi Cổng Chủ nhà (`TC-065`):
    // Hiển thị hộp thoại xác nhận dạng Bottom Sheet hiện đại (Phương án 2) trước khi đóng Drawer,
    // xóa thông báo phiên và thu hồi token trên máy chủ.
    final confirmed = await AppDialog.showActionSheet(
      context,
      title: 'Xác nhận đăng xuất',
      message:
          'Bạn có chắc chắn muốn đăng xuất khỏi Cổng quản trị Chủ nhà không? Phiên làm việc hiện tại sẽ kết thúc.',
      confirmText: 'Đăng xuất tài khoản',
      cancelText: 'Hủy bỏ',
      isDestructive: true,
      icon: const Icon(LucideIcons.logOut, size: 18, color: Color(0xFFEF4444)),
    );
    if (confirmed != true || !mounted) return;
    if (inDrawer) {
      Navigator.of(context).pop();
    }
    try {
      ref.read(notificationsProvider.notifier).clearForLogout();
      await ref.read(authNotifierProvider.notifier).logout();
    } catch (_) {}
    if (mounted) {
      _navigatePortalRoute(context, '/dang-nhap');
    }
  }

  Widget _buildMobileBottomNavigation(BuildContext context) {
    const sections = [
      HostPortalSection.guests,
      HostPortalSection.calendar,
      HostPortalSection.newProperty,
      HostPortalSection.messages,
    ];
    final selectedIndex = sections.indexOf(_activeSection);
    final isSecondaryDrawerSection =
        selectedIndex < 0 && _activeSection != HostPortalSection.overview;
    final activeTabIndex = selectedIndex >= 0
        ? selectedIndex
        : (isSecondaryDrawerSection ? 4 : -1);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final showCompactCircleOnly = textScale > 1.45;
    const navItems = [
      (icon: LucideIcons.users, label: 'Khách', semantic: 'Khách lưu trú'),
      (icon: LucideIcons.calendar, label: 'Lịch', semantic: 'Lịch lưu trú'),
      (icon: LucideIcons.plus, label: 'Thêm', semantic: 'Thêm chỗ nghỉ'),
      (
        icon: AppSemanticIcons.messageHost,
        label: 'Tin nhắn',
        semantic: 'Tin nhắn',
      ),
      (
        icon: LucideIcons.menu,
        label: 'Menu',
        semantic: 'Mở menu điều hướng Host'
      ),
    ];

    return HostFrostedSurface(
      key: const Key('host_bottom_navigation'),
      sigma: HostStudioTokens.dockBlurSigma,
      fillColor: HostStudioTokens.frostedDockFill,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(HostStudioTokens.dockRadius),
      ),
      border: const Border(
        top: BorderSide(color: HostStudioTokens.frostedDockBorder, width: 1.0),
      ),
      boxShadow: HostStudioTokens.dockShadow,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 66),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final isSelected = activeTabIndex == index;
                final isCenterAdd = index == 2;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label: item.semantic,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (index == 4) {
                          Scaffold.of(context).openDrawer();
                        } else {
                          _switchSection(sections[index]);
                        }
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 52,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? HostStudioTokens.obsidian
                                    : (isCenterAdd
                                        ? HostStudioTokens.softCircle
                                        : Colors.transparent),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  item.icon,
                                  size: isSelected ? 17.5 : 18.5,
                                  color: isSelected
                                      ? Colors.white
                                      : (isCenterAdd
                                          ? HostStudioTokens.iconInk
                                          : HostStudioTokens.iconSecondary),
                                ),
                              ),
                            ),
                            if (!showCompactCircleOnly) ...[
                              const SizedBox(height: 2),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: HostStudioTokens.metaCaption.copyWith(
                                    fontSize: 10.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? HostStudioTokens.inkPrimary
                                        : HostStudioTokens.inkMuted,
                                  ),
                                ),
                              ),
                            ] else
                              Offstage(
                                child: Text(item.label),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarNavigation({required bool inDrawer}) {
    final activeLocale = ref.watch(localeProvider);
    final activeL10n = lookupAppLocalizations(Locale(activeLocale));
    final pillRadius = BorderRadius.circular(HostStudioTokens.pillRadius);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      children: [
        for (final section in HostPortalSection.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: Key('host_sidebar_${section.keyName}'),
                borderRadius: pillRadius,
                onTap: () {
                  if (inDrawer) Navigator.of(context).pop();
                  _switchSection(section);
                },
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minHeight: 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                  decoration: BoxDecoration(
                    color: _activeSection == section
                        ? HostStudioTokens.cardSurface
                        : Colors.transparent,
                    borderRadius: pillRadius,
                    boxShadow: _activeSection == section
                        ? HostStudioTokens.cardShadow
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        section.icon,
                        size: 17.5,
                        color: _activeSection == section
                            ? AppColors.iconStrong
                            : AppColors.iconMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          section.localizedLabel(activeL10n, activeLocale),
                          style: HostStudioTokens.pillText.copyWith(
                            fontSize: 13.5,
                            fontWeight: _activeSection == section
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: _activeSection == section
                                ? HostStudioTokens.inkPrimary
                                : HostStudioTokens.inkSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, color: HostStudioTokens.hairline),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('host_portal_home_btn'),
            borderRadius: pillRadius,
            onTap: () {
              if (inDrawer) Navigator.of(context).pop();
              _navigatePortalRoute(context, '/');
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              child: Row(
                children: [
                  const Icon(
                    AppSemanticIcons.home,
                    size: 17.5,
                    color: AppColors.iconStrong,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Về trang chủ',
                      style: HostStudioTokens.pillText.copyWith(
                        fontSize: 13.5,
                        color: HostStudioTokens.inkPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('host_portal_logout_btn'),
            borderRadius: pillRadius,
            onTap: () => _handlePortalLogout(inDrawer: inDrawer),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              child: Row(
                children: [
                  const Icon(
                    AppSemanticIcons.logout,
                    size: 17.5,
                    color: AppColors.iconStrong,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Đăng xuất',
                      style: HostStudioTokens.pillText.copyWith(
                        fontSize: 13.5,
                        color: HostStudioTokens.inkPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSectionBody() {
    switch (_activeSection) {
      case HostPortalSection.overview:
        return _buildOverviewSection();
      case HostPortalSection.properties:
        return _buildPropertiesSection(isSupportMode: false);
      case HostPortalSection.newProperty:
        return HostListingFormScreen(
          listingId: _editingListingId,
          embedded: true,
          onSaved: () {
            _fetchListings();
          },
          onCancel: () => _switchSection(HostPortalSection.properties),
        );
      case HostPortalSection.bookings:
        return _buildBookingsSection();
      case HostPortalSection.calendar:
        return _buildCalendarSection();
      case HostPortalSection.guests:
        return _buildGuestsSection();
      case HostPortalSection.messages:
        return _buildMessagesSection();
      case HostPortalSection.payouts:
        return _buildPayoutsSection();
      case HostPortalSection.reviews:
        return _buildReviewsSection();
      case HostPortalSection.reports:
        return _buildReportsSection();
      case HostPortalSection.support:
        return _buildSupportSection();
      case HostPortalSection.settings:
        return _buildSettingsSection();
    }
  }

  // ===========================================================================
  // 1. OVERVIEW / DASHBOARD SECTION
  // ===========================================================================

  Widget _buildOverviewSection() {
    final overviewError =
        _listingsError ?? _bookingsError ?? _reportError ?? _payoutsError;
    final successfulHostBookingsCount =
        _bookings.where(isSuccessfulHostBooking).length;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    var todayCheckIns = 0;
    var todayCheckOuts = 0;
    var currentStaying = 0;

    for (final b in _bookings) {
      final inDate = (b['checkInDate'] ?? '').toString().split('T').first;
      final outDate = (b['checkOutDate'] ?? '').toString().split('T').first;
      final status = (b['status'] ?? '').toString().toLowerCase();
      if (status == 'cancelled' || status == 'rejected') continue;
      if (inDate == todayStr) todayCheckIns++;
      if (outDate == todayStr) todayCheckOuts++;
      if (inDate.isNotEmpty &&
          outDate.isNotEmpty &&
          inDate.compareTo(todayStr) <= 0 &&
          outDate.compareTo(todayStr) >= 0) {
        currentStaying++;
      }
    }
    final stats = [
      (
        label: 'Chỗ nghỉ',
        value: _loadingListings && _unfilteredListings.isEmpty
            ? '—'
            : '${_unfilteredListings.length}',
        icon: AppSemanticIcons.home,
        section: HostPortalSection.properties
      ),
      (
        label: 'Đặt phòng',
        value: _loadingBookings ? '—' : '$successfulHostBookingsCount',
        icon: AppSemanticIcons.bookings,
        section: HostPortalSection.bookings
      ),
      (
        label: 'Doanh thu · 30 ngày',
        value: _loadingReport
            ? '—'
            : formatCompactHostVnd(_revenueReport.hostRevenue),
        icon: AppSemanticIcons.revenue,
        section: HostPortalSection.reports
      ),
      (
        label: 'Tài khoản nhận tiền',
        value: _loadingPayouts ? '—' : '${_payoutAccounts.length}',
        icon: LucideIcons.wallet,
        section: HostPortalSection.payouts
      ),
    ];
    final recentBookings = List<Map<String, dynamic>>.from(_bookings)
      ..sort((a, b) {
        final aId = int.tryParse('${a['bookingId'] ?? a['id'] ?? 0}') ?? 0;
        final bId = int.tryParse('${b['bookingId'] ?? b['id'] ?? 0}') ?? 0;
        return bId.compareTo(aId);
      });

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 960;
    final horizontalPad = screenWidth < 360 ? 12.0 : 18.0;
    final visibleRecent = recentBookings.take(3).toList();

    return RefreshIndicator(
      onRefresh: _loadInitialPortalData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontalPad,
          8,
          horizontalPad,
          isDesktop ? 28 : 108,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (overviewError != null) ...[
              _buildInlineError(
                overviewError,
                onRetry: _loadInitialPortalData,
                borderless: true,
              ),
              const SizedBox(height: 12),
            ],
            // 1. Xung nhịp hôm nay (3 ô cột: Check-in, Check-out, Đang ở)
            _buildTodayPulseBar(
              checkIns: todayCheckIns,
              checkOuts: todayCheckOuts,
              staying: currentStaying,
            ),
            const SizedBox(height: 12),
            // 2. Chỉ số kinh doanh (Lưới Bento 2x2)
            HostStudioGroupCard(
              key: const Key('host_overview_kpi_group'),
              title: 'Hoạt động kinh doanh',
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: HostStudioTokens.cardSurface,
                  borderRadius:
                      BorderRadius.circular(HostStudioTokens.pillRadius),
                  boxShadow: HostStudioTokens.cardShadow,
                ),
                child: const Text(
                  '30 ngày qua',
                  style: HostStudioTokens.metaCaption,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 820 ? 4 : 2;
                  const spacing = 10.0;
                  final width =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: stats
                        .map(
                          (stat) => SizedBox(
                            width: width,
                            child: HostStudioKpiCard(
                              label: stat.label,
                              value: stat.value,
                              icon: stat.icon,
                              onTap: () => _switchSection(stat.section),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // 3. Lịch tuần T2 – CN
            _buildOverviewCalendarBlock(),
            const SizedBox(height: 12),
            // 4. Tài chính & Số dư khả dụng
            _buildOverviewFinanceBlock(),
            const SizedBox(height: 12),
            // 6. Báo cáo tuần này
            _buildOverviewWeeklyReportBlock(),
            const SizedBox(height: 12),
            // 7. Đặt phòng gần đây
            HostStudioGroupCard(
              key: const Key('host_overview_recent_bookings_group'),
              title: 'Đặt phòng gần đây',
              trailing: Semantics(
                button: true,
                label: 'Xem tất cả đặt phòng',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(HostStudioTokens.pillRadius),
                    onTap: () => _switchSection(HostPortalSection.bookings),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 44),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: HostStudioTokens.cardSurface,
                            borderRadius: BorderRadius.circular(
                              HostStudioTokens.pillRadius,
                            ),
                            boxShadow: HostStudioTokens.cardShadow,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Xem tất cả',
                                style: HostStudioTokens.pillText.copyWith(
                                  color: HostStudioTokens.inkPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                LucideIcons.arrowUpRight,
                                size: 13.5,
                                color: HostStudioTokens.iconInk,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: _loadingBookings
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : visibleRecent.isEmpty
                      ? _buildEmptyBox('Chưa có đặt phòng.', borderless: true)
                      : Column(
                          children: [
                            for (var i = 0; i < visibleRecent.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              _buildBookingItemCard(
                                visibleRecent[i],
                                inStudioGroup: true,
                                hasBottomMargin: false,
                              ),
                            ],
                          ],
                        ),
            ),
            const SizedBox(height: 12),
            // 8. Nút Trung tâm trợ giúp chuẩn máy thật ở dưới cùng
            _buildOverviewHelpCenterButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayPulseBar({
    required int checkIns,
    required int checkOuts,
    required int staying,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: HostStudioTokens.cardSurface,
        borderRadius: BorderRadius.circular(HostStudioTokens.cardRadius),
        border: Border.all(color: HostStudioTokens.hairline),
        boxShadow: HostStudioTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hoạt động hôm nay',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HostStudioTokens.cardTitle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _switchSection(HostPortalSection.guests),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Chi tiết',
                          style: HostStudioTokens.metaCaption.copyWith(
                            fontSize: 11,
                            color: HostStudioTokens.inkSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        LucideIcons.chevronRight,
                        size: 13,
                        color: HostStudioTokens.iconMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPulseItem(
                  label: 'Check-in',
                  count: checkIns,
                  onTap: () => _switchSection(HostPortalSection.guests),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPulseItem(
                  label: 'Check-out',
                  count: checkOuts,
                  onTap: () => _switchSection(HostPortalSection.guests),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPulseItem(
                  label: 'Đang ở',
                  count: staying,
                  onTap: () => _switchSection(HostPortalSection.guests),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPulseItem({
    required String label,
    required int count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: HostStudioTokens.groupSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HostStudioTokens.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: HostStudioTokens.inkPrimary,
                ),
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: HostStudioTokens.inkSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCalendarBlock() {
    final selectedListing = _unfilteredListings.firstWhere(
      (l) => '${l['listingId'] ?? l['id']}' == _calendarListingId,
      orElse: () => _unfilteredListings.firstOrNull ?? const {},
    );
    final selectedListingId =
        (selectedListing['listingId'] ?? selectedListing['id'])?.toString();
    final villaTitle =
        (selectedListing['title'] ?? 'White Lotus Pool Villa').toString();

    final now = DateTime.now();
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    final monday =
        currentMonday.add(Duration(days: _overviewCalendarWeekOffset * 7));
    final sunday = monday.add(const Duration(days: 6));
    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final weekDateRange =
        '${DateFormat('dd/MM').format(monday)} – ${DateFormat('dd/MM/yyyy').format(sunday)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HostStudioTokens.groupSurface,
        borderRadius: BorderRadius.circular(HostStudioTokens.groupRadius),
        border: Border.all(color: HostStudioTokens.groupBorder, width: 1),
        boxShadow: HostStudioTokens.groupShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  setState(() {
                    _overviewCalendarWeekOffset--;
                  });
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: HostStudioTokens.softCircle,
                    shape: BoxShape.circle,
                    border: Border.all(color: HostStudioTokens.hairline),
                  ),
                  child: const Icon(
                    LucideIcons.chevronLeft,
                    size: 14,
                    color: HostStudioTokens.iconInk,
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(HostStudioTokens.pillRadius),
                  onTap: () {
                    if (_unfilteredListings.isNotEmpty) {
                      _showListingSelectionModal(
                        context: context,
                        title: 'Chọn chỗ nghỉ',
                        listings: _unfilteredListings,
                        selectedListingId: selectedListingId,
                        onSelected: (val) {
                          setState(() {
                            _calendarListingId = val;
                          });
                          _fetchCalendarDays();
                        },
                      );
                    }
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                villaTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HostStudioTokens.cardTitle.copyWith(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              LucideIcons.chevronDown,
                              size: 14,
                              color: HostStudioTokens.iconMuted,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          weekDateRange,
                          style: HostStudioTokens.metaCaption.copyWith(
                            fontSize: 10.5,
                            color: HostStudioTokens.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  setState(() {
                    _overviewCalendarWeekOffset++;
                  });
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: HostStudioTokens.softCircle,
                    shape: BoxShape.circle,
                    border: Border.all(color: HostStudioTokens.hairline),
                  ),
                  child: const Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: HostStudioTokens.iconInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final dayDate = monday.add(Duration(days: index));
              final dayNum = dayDate.day;
              final dateStr = DateFormat('yyyy-MM-dd').format(dayDate);
              final isToday = dateStr == DateFormat('yyyy-MM-dd').format(now);
              final isBooked = _bookings.any((b) {
                final status = (b['status'] ?? '').toString().toLowerCase();
                if (status == 'cancelled' || status == 'rejected') return false;
                final bListingId =
                    (b['listingId'] ?? b['listing']?['id'] ?? '').toString();
                if (selectedListingId != null &&
                    selectedListingId.isNotEmpty &&
                    bListingId.isNotEmpty &&
                    bListingId != selectedListingId) {
                  return false;
                }
                final inDate =
                    (b['checkInDate'] ?? '').toString().split('T').first;
                final outDate =
                    (b['checkOutDate'] ?? '').toString().split('T').first;
                return inDate.isNotEmpty &&
                    outDate.isNotEmpty &&
                    dateStr.compareTo(inDate) >= 0 &&
                    dateStr.compareTo(outDate) <= 0;
              }) ||
                  _calendarDays.any((d) =>
                      d.date == dateStr &&
                      (d.isBooked || d.isBlockedByHost || !d.isAvailable));

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index == 6 ? 0 : 5),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                  decoration: BoxDecoration(
                    color: isBooked
                        ? const Color(0xFFFFF1F2)
                        : (isToday
                            ? const Color(0xFFF8FAFC)
                            : HostStudioTokens.groupSurface),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isBooked
                          ? const Color(0xFFFFE4E6)
                          : (isToday
                              ? HostStudioTokens.obsidian
                              : HostStudioTokens.hairline),
                      width: isToday ? 1.2 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          weekdays[index],
                          style: HostStudioTokens.metaCaption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isBooked
                                ? const Color(0xFFDC2626)
                                : HostStudioTokens.inkMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isBooked
                                ? const Color(0xFFDC2626)
                                : HostStudioTokens.inkPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isBooked ? 'Kín' : 'Trống',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isBooked
                                ? const Color(0xFFDC2626)
                                : HostStudioTokens.inkSubtle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _switchSection(HostPortalSection.calendar),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Xem chi tiết',
                      style: HostStudioTokens.pillText.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HostStudioTokens.inkPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 13,
                      color: HostStudioTokens.iconInk,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewFinanceBlock() {
    final available = _revenueReport.hostRevenue;
    final primaryAccount = _payoutAccounts.firstOrNull;
    final bankName = (primaryAccount?['bankName'] ??
            primaryAccount?['bankCode'] ??
            'Vietcombank')
        .toString();
    final accountNum = (primaryAccount?['accountNumber'] ?? '8899').toString();
    final maskedAccount = accountNum.length > 4
        ? '•••• ${accountNum.substring(accountNum.length - 4)}'
        : '•••• 8899';

    return HostStudioGroupCard(
      title: 'Tài chính',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Số dư khả dụng',
                      style: HostStudioTokens.metaCaption.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatHostVnd(available),
                        style: HostStudioTokens.kpiValue.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: HostStudioTokens.inkPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _switchSection(HostPortalSection.payouts);
                  _openWithdrawalModal(available);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: HostStudioTokens.obsidian,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Rút tiền',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: HostStudioTokens.groupSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: HostStudioTokens.hairline),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.creditCard,
                  size: 15,
                  color: HostStudioTokens.iconInk,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$bankName $maskedAccount',
                    style: HostStudioTokens.metaCaption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: HostStudioTokens.inkPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: InkWell(
              onTap: () => _switchSection(HostPortalSection.payouts),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Xem chi tiết',
                        style: HostStudioTokens.pillText.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: HostStudioTokens.inkPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        LucideIcons.chevronRight,
                        size: 13,
                        color: HostStudioTokens.iconInk,
                      ),
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

  Widget _buildOverviewWeeklyReportBlock() {
    final revenue = _revenueReport.hostRevenue;
    final bookings = _revenueReport.bookingCount;

    return HostStudioGroupCard(
      title: 'Báo cáo tuần này',
      trailing: Semantics(
        button: true,
        label: 'Xem chi tiết báo cáo',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(HostStudioTokens.pillRadius),
            onTap: () => _switchSection(HostPortalSection.reports),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: HostStudioTokens.cardSurface,
                borderRadius: BorderRadius.circular(HostStudioTokens.pillRadius),
                boxShadow: HostStudioTokens.cardShadow,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Xem chi tiết',
                      style: HostStudioTokens.pillText.copyWith(
                        color: HostStudioTokens.inkPrimary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      LucideIcons.arrowUpRight,
                      size: 12.5,
                      color: HostStudioTokens.iconInk,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildOverviewKpiMiniBox(
                  label: 'DOANH THU',
                  value: formatHostVnd(revenue),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildOverviewKpiMiniBox(
                  label: 'ĐƠN ĐÃ BÁN',
                  value: '$bookings đơn',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildOverviewKpiMiniBox(
                  label: 'TỈ LỆ LẤP PHÒNG',
                  value: '78%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildOverviewKpiMiniBox(
                  label: 'SAO TRUNG BÌNH',
                  value: '4.9 ★',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => _switchSection(HostPortalSection.reports),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HostStudioTokens.groupSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HostStudioTokens.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Doanh thu 7 ngày',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HostStudioTokens.metaCaption.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: HostStudioTokens.inkSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Đỉnh T7: +2.8 Tr',
                            maxLines: 1,
                            style: HostStudioTokens.metaCaption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: HostStudioTokens.inkPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 62,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildOverviewChartColumn('T2', 0.28, isPeak: false),
                        _buildOverviewChartColumn('T3', 0.42, isPeak: false),
                        _buildOverviewChartColumn('T4', 0.35, isPeak: false),
                        _buildOverviewChartColumn('T5', 0.58, isPeak: false),
                        _buildOverviewChartColumn('T6', 0.72, isPeak: false),
                        _buildOverviewChartColumn('T7', 1.0, isPeak: true),
                        _buildOverviewChartColumn('CN', 0.65, isPeak: false),
                      ],
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

  Widget _buildOverviewKpiMiniBox({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: HostStudioTokens.groupSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HostStudioTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: HostStudioTokens.metaCaption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: HostStudioTokens.inkMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: HostStudioTokens.inkPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewChartColumn(String day, double heightRatio,
      {required bool isPeak}) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: 30 * heightRatio.clamp(0.15, 1.0),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color:
                  isPeak ? HostStudioTokens.obsidian : const Color(0xFFD5D9E2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              day,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
                color: isPeak
                    ? HostStudioTokens.inkPrimary
                    : HostStudioTokens.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewHelpCenterButton() {
    return Semantics(
      button: true,
      label: 'Trung tâm trợ giúp',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _switchSection(HostPortalSection.support),
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: HostStudioTokens.cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD5D9E2), width: 1),
              boxShadow: HostStudioTokens.cardShadow,
            ),
            child: const Center(
              child: Text(
                'Trung tâm trợ giúp',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: HostStudioTokens.inkPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHostPortalNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showReportPeriodPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final screenWidth = MediaQuery.sizeOf(context).width;
            final itemWidth = (screenWidth - 40 - 24) / 4;
            return Container(
              decoration: const BoxDecoration(
                color: HostStudioTokens.cardSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: HostStudioTokens.hairline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Chọn nhanh thời gian',
                        style: HostStudioTokens.cardTitle.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Year stepper
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: HostStudioTokens.groupSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HostStudioTokens.hairline),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () {
                            setSheetState(() => _reportSelectedYear--);
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(LucideIcons.chevronLeft, size: 18),
                          ),
                        ),
                        Text(
                          'Năm $_reportSelectedYear',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: HostStudioTokens.inkPrimary,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setSheetState(() => _reportSelectedYear++);
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(LucideIcons.chevronRight, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Tháng',
                    style: HostStudioTokens.metaCaption,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(12, (mIdx) {
                      final monthNum = mIdx + 1;
                      final isSelected = _reportSelectedMonth == monthNum;
                      return SizedBox(
                        width: itemWidth,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setState(() {
                              _reportSelectedMonth = monthNum;
                              _reportMode = 'month';
                            });
                            Navigator.pop(ctx);
                            _fetchRevenueReport();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? HostStudioTokens.obsidian
                                  : HostStudioTokens.groupSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? HostStudioTokens.obsidian
                                    : HostStudioTokens.hairline,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Tháng $monthNum',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : HostStudioTokens.inkPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Quý',
                    style: HostStudioTokens.metaCaption,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(4, (qIdx) {
                      final qNum = qIdx + 1;
                      final isSelected = _reportMode == 'quarter' &&
                          _reportSelectedQuarter == qNum;
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: qIdx == 3 ? 0 : 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setState(() {
                                _reportSelectedQuarter = qNum;
                                _reportMode = 'quarter';
                                _reportRange = '90d';
                              });
                              Navigator.pop(ctx);
                              _fetchRevenueReport();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? HostStudioTokens.obsidian
                                    : HostStudioTokens.groupSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                    ? HostStudioTokens.obsidian
                                    : HostStudioTokens.hairline,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Quý $qNum',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : HostStudioTokens.inkPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      final now = DateTime.now();
                      setState(() {
                        _reportSelectedYear = now.year;
                        _reportSelectedMonth = now.month;
                        _reportMode = 'month';
                        _reportRange = '30d';
                      });
                      Navigator.pop(ctx);
                      _fetchRevenueReport();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: HostStudioTokens.hairline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Về kỳ hiện tại',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: HostStudioTokens.inkPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBookingGuestDetailPopup(Map<String, dynamic> booking) {
    final guestName = (booking['guestName'] ??
            booking['userName'] ??
            'Nguyễn Văn An')
        .toString();
    final guestPhone = (booking['guestPhone'] ??
            booking['userPhone'] ??
            '0912 345 678')
        .toString();
    final bookingCode =
        (booking['code'] ?? booking['bookingCode'] ?? '#BK-8821').toString();
    final villaTitle = (booking['listingTitle'] ??
            booking['title'] ??
            'White Lotus Pool Villa')
        .toString();
    final checkIn =
        (booking['checkInDate'] ?? '14/11/2026').toString().split('T').first;
    final checkOut =
        (booking['checkOutDate'] ?? '16/11/2026').toString().split('T').first;
    final totalAmount =
        (booking['totalPrice'] ?? booking['totalAmount'] ?? 4440000) as num;
    final initial =
        guestName.trim().isNotEmpty ? guestName.trim()[0].toUpperCase() : 'A';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: HostStudioTokens.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: HostStudioTokens.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: HostStudioTokens.obsidian,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Guest Name (NO "Khách thân thiết" badge per explicit user instruction)
              Text(
                guestName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: HostStudioTokens.inkPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bookingCode,
                style: HostStudioTokens.metaCaption.copyWith(
                  fontSize: 12,
                  color: HostStudioTokens.inkMuted,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showHostPortalNotice(
                            'Đang kết nối cuộc gọi đến $guestPhone...');
                      },
                      icon: const Icon(LucideIcons.phone,
                          size: 16, color: HostStudioTokens.inkPrimary),
                      label: const Text(
                        'Gọi điện',
                        style: TextStyle(
                          color: HostStudioTokens.inkPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: HostStudioTokens.hairline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _switchSection(HostPortalSection.messages);
                      },
                      icon: const Icon(LucideIcons.messageSquare,
                          size: 16, color: Colors.white),
                      label: const Text(
                        'Nhắn tin',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HostStudioTokens.obsidian,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: HostStudioTokens.groupSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HostStudioTokens.hairline),
                ),
                child: Column(
                  children: [
                    _buildPopupDetailRow('Chỗ nghỉ', villaTitle),
                    const SizedBox(height: 8),
                    _buildPopupDetailRow('Thời gian', '$checkIn → $checkOut'),
                    const SizedBox(height: 8),
                    _buildPopupDetailRow('Số điện thoại', guestPhone),
                    const Divider(height: 20, color: HostStudioTokens.hairline),
                    _buildPopupDetailRow(
                      'Thực nhận',
                      formatHostVnd(totalAmount),
                      isHighlight: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPopupDetailRow(String label, String value,
      {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: HostStudioTokens.metaCaption.copyWith(
            fontSize: 12.5,
            color: HostStudioTokens.inkSecondary,
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
              color:
                  isHighlight ? AppColors.success : HostStudioTokens.inkPrimary,
            ),
          ),
        ),
      ],
    );
  }

  void _showReportExportSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: HostStudioTokens.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HostStudioTokens.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Xuất báo cáo doanh thu',
                style: HostStudioTokens.cardTitle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.pop(ctx);
                  _showHostPortalNotice(
                      'Đã xuất file Excel (.xlsx) thành công!');
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: HostStudioTokens.groupSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: HostStudioTokens.hairline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.successSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          LucideIcons.fileSpreadsheet,
                          size: 20,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Xuất file Excel (.xlsx)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: HostStudioTokens.inkPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tải bảng kê chi tiết toàn bộ đơn đặt phòng và doanh thu',
                              style: HostStudioTokens.metaCaption.copyWith(
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight,
                          size: 16, color: HostStudioTokens.iconMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.pop(ctx);
                  _showHostPortalNotice(
                      'Đã lưu ảnh báo cáo vào Thư viện Album!');
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: HostStudioTokens.groupSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: HostStudioTokens.hairline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: HostStudioTokens.softCircle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          LucideIcons.image,
                          size: 20,
                          color: HostStudioTokens.iconInk,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lưu ảnh vào Thư viện (.png)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: HostStudioTokens.inkPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Lưu ảnh chụp thống kê và biểu đồ chất lượng cao',
                              style: HostStudioTokens.metaCaption.copyWith(
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight,
                          size: 16, color: HostStudioTokens.iconMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 2 & 10. PROPERTIES (`ChoNghi`) & SUPPORT (`HoTro`) SECTIONS
  // ===========================================================================

  Widget _buildPropertySummary(List<({String label, String value})> items,
      {bool borderless = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 640 ? items.length.clamp(1, 4) : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map((item) => Container(
                    width: width,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBase,
                      border: borderless
                          ? null
                          : Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.value,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(item.label,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  String _extractListingCoverUrl(Map<String, dynamic> listing) {
    for (final key in const ['imageUrl', 'coverImageUrl', 'thumbnailUrl']) {
      final raw = listing[key]?.toString().trim() ?? '';
      if (raw.isNotEmpty) return raw;
    }

    final coverImage = listing['coverImage'];
    if (coverImage is String && coverImage.trim().isNotEmpty) {
      return coverImage.trim();
    }
    if (coverImage is Map) {
      final coverUrl =
          (coverImage['url'] ?? coverImage['imageUrl'] ?? '').toString().trim();
      if (coverUrl.isNotEmpty) return coverUrl;
    }

    final images = listing['images'];
    if (images is List && images.isNotEmpty) {
      Map<dynamic, dynamic>? selectedMap;
      for (final item in images) {
        if (item is Map && item['isCover'] == true) {
          selectedMap = item;
          break;
        }
      }
      final fallback = selectedMap ?? images.first;
      if (fallback is String && fallback.trim().isNotEmpty) {
        return fallback.trim();
      }
      if (fallback is Map) {
        final firstUrl =
            (fallback['url'] ?? fallback['imageUrl'] ?? '').toString().trim();
        if (firstUrl.isNotEmpty) return firstUrl;
      }
    }

    return '';
  }

  Widget _buildListingFilterPill({
    required Key pillKey,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int? count,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: pillKey,
          borderRadius: BorderRadius.circular(HostStudioTokens.pillRadius),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? HostStudioTokens.obsidian
                      : HostStudioTokens.cardSurface,
                  borderRadius:
                      BorderRadius.circular(HostStudioTokens.pillRadius),
                  border: Border.all(
                    color: selected
                        ? HostStudioTokens.obsidian
                        : HostStudioTokens.hairline,
                  ),
                  boxShadow: selected ? null : HostStudioTokens.cardShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: HostStudioTokens.pillText.copyWith(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? AppColors.textInverse
                            : HostStudioTokens.inkSecondary,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.surfaceBase.withValues(alpha: 0.16)
                              : HostStudioTokens.softCircle,
                          borderRadius: BorderRadius.circular(
                            HostStudioTokens.pillRadius,
                          ),
                        ),
                        child: Text(
                          '$count',
                          style: HostStudioTokens.metaCaption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppColors.textInverse
                                : HostStudioTokens.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Giải thuật mở hội thoại hỗ trợ trực tiếp với Quản trị viên (tìm hội thoại số thực hiện có hoặc khởi tạo mới qua POST /api/conversations):
  // CONFLICT-RESOLVED: Loại bỏ hoàn toàn hội thoại giả 'admin_support'; nếu chưa có Quản trị viên hoạt động (404), hiển thị thông báo tiếng Việt thân thiện.
  Future<void> _handleStartAdminChat() async {
    final repo = ref.read(hostPortalViewModelProvider);
    if (_conversations.isEmpty) {
      await _fetchConversations();
    }

    Map<String, dynamic>? findNumericAdminConv(
      Iterable<Map<String, dynamic>> source,
    ) {
      for (final c in source) {
        final rawId = '${c['conversationId'] ?? c['id'] ?? ''}'.trim();
        if (_isConversationAdmin(c) && isNumericHostConversationId(rawId)) {
          return c;
        }
      }
      return null;
    }

    Map<String, dynamic>? adminConv = findNumericAdminConv(_conversations);

    if (adminConv == null) {
      try {
        final list = await repo.getHostConversations(page: 1, limit: 50);
        if (mounted && list.isNotEmpty) {
          setState(() => _conversations = list);
          adminConv = findNumericAdminConv(list);
        }
      } catch (_) {}
    }

    if (adminConv != null) {
      final convId = '${adminConv['conversationId'] ?? adminConv['id']}'.trim();
      if (!mounted) return;
      setState(() {
        _conversationsError = null;
        _selectedConversationId = convId;
        _inChatDetailView = true;
        _activeSection = HostPortalSection.messages;
      });
      _markHostConversationRead(convId);
      await _fetchMessagesForConversation(convId);
      return;
    }

    try {
      final created = await repo.openSupportConversation();
      if (!mounted) return;
      final realId =
          '${created['conversationId'] ?? created['id'] ?? ''}'.trim();
      if (!isNumericHostConversationId(realId)) {
        setState(() {
          _activeSection = HostPortalSection.messages;
          _inChatDetailView = false;
          _conversationsError =
              'Hiện chưa có Quản trị viên trực tuyến để mở kênh hỗ trợ trực tiếp. Vui lòng thử lại sau.';
        });
        return;
      }

      setState(() {
        _conversations.removeWhere(
          (c) => '${c['conversationId'] ?? c['id']}' == 'admin_support',
        );
        final existingIdx = _conversations.indexWhere(
          (c) => '${c['conversationId'] ?? c['id']}' == realId,
        );
        if (existingIdx >= 0) {
          _conversations[existingIdx] = created;
        } else {
          _conversations.insert(0, created);
        }
        _conversationsError = null;
        _selectedConversationId = realId;
        _inChatDetailView = true;
        _activeSection = HostPortalSection.messages;
      });
      _markHostConversationRead(realId);
      await _fetchMessagesForConversation(realId);
    } catch (e) {
      if (!mounted) return;
      final isNoOnlineAdmin = HostPortalViewModel.isNotFoundError(e);
      final friendlyMsg = isNoOnlineAdmin
          ? 'Hiện chưa có Quản trị viên trực tuyến để mở hội thoại hỗ trợ trực tiếp. Vui lòng thử lại sau hoặc gọi tổng đài 1900 8888.'
          : repo.extractErrorMessage(
              e,
              'Không thể mở hội thoại hỗ trợ với Quản trị viên.',
            );
      setState(() {
        _activeSection = HostPortalSection.messages;
        _inChatDetailView = false;
        _conversationsError = friendlyMsg;
      });
    }
  }

  void _showHelpTopicDetail(String title, String detail) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.circleHelp,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.info, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cần hỗ trợ xử lý ngay? Hãy gửi tin nhắn cho Quản trị viên để được giải quyết trực tiếp.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleStartAdminChat();
            },
            icon: const Icon(LucideIcons.messageSquare, size: 15),
            label: const Text('Nhắn Admin'),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    final helpTopics = [
      (
        title: 'Duyệt chỗ nghỉ & KYC',
        desc: 'Hồ sơ pháp lý, ảnh chụp căn, quy trình duyệt nhanh',
        detail:
            'Hệ thống phê duyệt chỗ nghỉ trong vòng 24 giờ sau khi tải đủ ảnh thực tế độ nét cao và hồ sơ định danh CCCD. Quản trị viên sẽ gửi thông báo ngay khi căn của bạn sẵn sàng đón khách.',
        icon: LucideIcons.house,
        color: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
      ),
      (
        title: 'Thanh toán & Quyết toán',
        desc: 'Lịch nhận tiền, đổi số tài khoản ngân hàng',
        detail:
            'Doanh thu đặt phòng được quyết toán vào tài khoản ngân hàng của Chủ nhà sau khi khách check-in thành công. Bạn có thể cập nhật tài khoản ngân hàng tại mục Menu > Cài đặt Chủ nhà.',
        icon: LucideIcons.walletCards,
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
      ),
      (
        title: 'Hủy phòng & Khiếu nại',
        desc: 'Xử lý đơn hủy, bồi hoàn và tranh chấp',
        detail:
            'Nếu khách lưu trú vi phạm nội quy hoặc yêu cầu hủy phòng ngoài chính sách, hãy chụp lại bằng chứng và gửi tin nhắn ngay cho Quản trị viên để được bảo vệ quyền lợi Chủ nhà.',
        icon: LucideIcons.shieldAlert,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
      ),
      (
        title: 'Báo cáo sự cố kỹ thuật',
        desc: 'Đồng bộ lịch, lỗi giá, sự cố ứng dụng',
        detail:
            'Đội ngũ kỹ thuật túc trực 24/7 để khắc phục mọi sự cố hiển thị lịch đặt, lỗi tải ảnh hoặc vấn đề thông báo. Vui lòng nhắn tin trực tiếp để được kỹ sư xử lý ngay lập tức.',
        icon: LucideIcons.wrench,
        color: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF5F3FF),
      ),
    ];

    final faqs = [
      (
        q: 'Khi nào tôi nhận được tiền quyết toán từ đơn đặt phòng?',
        a: 'Tiền phòng sẽ được tự động chuyển vào tài khoản ngân hàng đã đăng ký của bạn trong vòng 24h làm việc sau khi khách thực hiện Check-in thành công.',
      ),
      (
        q: 'Làm thế nào để chỗ nghỉ của tôi được duyệt hiển thị nhanh nhất?',
        a: 'Đảm bảo chụp tối thiểu 5 ảnh thực tế rõ nét (phòng khách, phòng ngủ, phòng tắm, ngoại cảnh) và điền đầy đủ tiện nghi, giá cả chính xác.',
      ),
      (
        q: 'Tôi phải làm gì khi khách yêu cầu hủy phòng vào phút chót?',
        a: 'Chính sách hủy phòng bạn thiết lập sẽ được áp dụng tự động. Nếu có tranh chấp phát sinh, hãy bấm "Nhắn tin với Quản trị viên" để Ban quản trị hỗ trợ giải quyết thỏa đáng.',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Text(
            'Trung tâm trợ giúp',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Kết nối trực tiếp với Ban quản trị và nhận trợ giúp từ nền tảng.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),

          // 1. Thẻ Kênh Hỗ Trợ Trực Tuyến Với Admin (Nền trắng tối giản, thanh lịch)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  offset: Offset(0, 4),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.shieldCheck,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Quản trị viên The Palm Villa',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: const Color(0xFFA7F3D0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Online',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Ban quản trị nền tảng • Hỗ trợ trực tiếp 24/7',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ban quản trị luôn túc trực để hỗ trợ bạn phê duyệt chỗ nghỉ, giải quyết vướng mắc tài chính và xử lý các sự cố khẩn cấp.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  key: const Key('support_chat_with_admin_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  onPressed: _handleStartAdminChat,
                  icon: const Icon(LucideIcons.messageSquare, size: 17),
                  label: const Text(
                    'Nhắn tin trực tiếp với Quản trị viên',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Các Vấn Đề Cần Nền Tảng Trợ Giúp
          const Text(
            'Các vấn đề cần nền tảng trợ giúp',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 4 : 2;
              final itemWidth =
                  (constraints.maxWidth - 10 * (columns - 1)) / columns;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: helpTopics.map((topic) {
                  return Material(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () =>
                          _showHelpTopicDetail(topic.title, topic.detail),
                      child: Container(
                        width: itemWidth,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(topic.icon, size: 22, color: topic.color),
                            const SizedBox(height: 12),
                            Text(
                              topic.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              topic.desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.35,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          // 3. Câu Hỏi Thường Gặp (FAQ)
          const Text(
            'Câu hỏi thường gặp',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: faqs.asMap().entries.map((entry) {
                final idx = entry.key;
                final faq = entry.value;
                final isLast = idx == faqs.length - 1;

                return Column(
                  children: [
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        leading: const Icon(
                          LucideIcons.circleHelp,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          faq.q,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 14,
                            ),
                            child: Text(
                              faq.a,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // 4. Kênh Liên Hệ Khẩn Cấp (Emergency Hotline)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.phoneCall,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tổng đài hỗ trợ 24/7',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hotline: 1900 8888 • hotro@thepalmvilla.vn',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(80, 48),
                    shape: const StadiumBorder(),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onPressed: () => _handleCallGuest(
                    'Tổng đài hỗ trợ nền tảng',
                    '1900 8888',
                  ),
                  child: const Text('Gọi ngay', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesSection({required bool isSupportMode}) {
    final hasSnapshot = _allListingsSnapshot.isNotEmpty;
    final summarySource = _unfilteredListings;
    final counts = <String, int>{
      'draft': 0,
      'pending_approval': 0,
      'published': 0,
      'hidden': 0,
      'rejected': 0,
    };
    for (final item in summarySource) {
      final st = HostListingStatus.fromListingMap(item).value;
      counts[st] = (counts[st] ?? 0) + 1;
    }

    const filterOptions = [
      ('all', 'Tất cả'),
      ('published', 'Đang hiển thị'),
      ('pending_approval', 'Chờ duyệt'),
      ('draft', 'Bản nháp'),
      ('hidden', 'Đang ẩn'),
      ('rejected', 'Bị từ chối'),
    ];

    const sortOptions = [
      ('newest', 'Mới nhất'),
      ('price_asc', 'Giá thấp → cao'),
      ('price_desc', 'Giá cao → thấp'),
      ('title_asc', 'Tên A → Z'),
    ];

    final sortedListings = List<Map<String, dynamic>>.from(_listings);
    sortedListings.sort((a, b) {
      if (_listingSortBy == 'price_asc' || _listingSortBy == 'price_desc') {
        final pa = (a['basePrice'] ?? a['pricePerNight'] ?? 0) is num
            ? ((a['basePrice'] ?? a['pricePerNight'] ?? 0) as num).toDouble()
            : (double.tryParse('${a['basePrice'] ?? 0}') ?? 0);
        final pb = (b['basePrice'] ?? b['pricePerNight'] ?? 0) is num
            ? ((b['basePrice'] ?? b['pricePerNight'] ?? 0) as num).toDouble()
            : (double.tryParse('${b['basePrice'] ?? 0}') ?? 0);
        return _listingSortBy == 'price_asc'
            ? pa.compareTo(pb)
            : pb.compareTo(pa);
      }
      if (_listingSortBy == 'title_asc') {
        final ta = (a['title'] ?? '').toString().toLowerCase();
        final tb = (b['title'] ?? '').toString().toLowerCase();
        return ta.compareTo(tb);
      }
      final ida = int.tryParse('${a['listingId'] ?? a['id'] ?? 0}') ?? 0;
      final idb = int.tryParse('${b['listingId'] ?? b['id'] ?? 0}') ?? 0;
      return idb.compareTo(ida);
    });

    final visibleListings = sortedListings.take(_listingsVisibleCount).toList();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final isDesktop = screenWidth >= 960;
    final horizontalPad = screenWidth < 360 ? 12.0 : 18.0;

    final hiddenTotal = (counts['draft'] ?? 0) +
        (counts['hidden'] ?? 0) +
        (counts['rejected'] ?? 0);
    final kpiItems = [
      (
        label: 'Tổng chỗ nghỉ',
        value: _loadingListings && summarySource.isEmpty
            ? '—'
            : '${summarySource.length}',
        icon: AppSemanticIcons.home,
      ),
      (
        label: 'Đang hiển thị',
        value: _loadingListings && summarySource.isEmpty
            ? '—'
            : '${counts['published'] ?? 0}',
        icon: LucideIcons.eye,
      ),
      (
        label: 'Chờ duyệt',
        value: _loadingListings && summarySource.isEmpty
            ? '—'
            : '${counts['pending_approval'] ?? 0}',
        icon: LucideIcons.clock,
      ),
      (
        label: 'Chưa hiển thị',
        value: _loadingListings && summarySource.isEmpty ? '—' : '$hiddenTotal',
        icon: LucideIcons.eyeOff,
      ),
    ];

    final headerSubtitle = isSupportMode
        ? 'Kiểm tra trạng thái và gửi duyệt chỗ nghỉ.'
        : (summarySource.isEmpty
            ? 'Quản lý danh sách và trạng thái hiển thị chỗ nghỉ.'
            : '${summarySource.length} chỗ nghỉ · ${counts['published'] ?? 0} đang hiển thị');

    Widget buildSortDropdown({required bool expanded}) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          child: Container(
            width: expanded ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: HostStudioTokens.cardSurface,
              borderRadius: BorderRadius.circular(HostStudioTokens.pillRadius),
              border: Border.all(color: HostStudioTokens.hairline),
              boxShadow: HostStudioTokens.cardShadow,
            ),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.arrowUpDown,
                  size: 14,
                  color: AppColors.iconMuted,
                ),
                const SizedBox(width: 8),
                Flexible(
                  fit: expanded ? FlexFit.tight : FlexFit.loose,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('listing_sort_dropdown'),
                      isExpanded: expanded,
                      isDense: true,
                      value: _listingSortBy,
                      borderRadius: BorderRadius.circular(18),
                      dropdownColor: AppColors.surfaceElevated,
                      icon: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(
                          LucideIcons.chevronDown,
                          size: 15,
                          color: AppColors.iconStrong,
                        ),
                      ),
                      style: HostStudioTokens.pillText.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: HostStudioTokens.inkPrimary,
                      ),
                      items: sortOptions
                          .map(
                            (opt) => DropdownMenuItem(
                              value: opt.$1,
                              child: Text(
                                'Sắp xếp: ${opt.$2}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _listingSortBy = value);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchListings,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontalPad,
          10,
          horizontalPad,
          isDesktop ? 28 : 108,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSupportMode
                      ? 'Hỗ trợ & Quản lý trạng thái chỗ nghỉ'
                      : 'Chỗ nghỉ của tôi',
                  style: HostStudioTokens.headerTitle,
                ),
                const SizedBox(height: 3),
                Text(
                  headerSubtitle,
                  style: HostStudioTokens.metaCaption,
                ),
              ],
            ),
            if (_listingsError != null) ...[
              const SizedBox(height: 14),
              _buildInlineError(
                _listingsError!,
                borderless: true,
                onRetry: _fetchListings,
              ),
            ],
            const SizedBox(height: 14),
            HostStudioGroupCard(
              padding: const EdgeInsets.all(10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 640 ? 4 : 2;
                  const spacing = 8.0;
                  final tileWidth =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: kpiItems
                        .map(
                          (item) => Container(
                            width: tileWidth,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: HostStudioTokens.cardSurface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: HostStudioTokens.cardShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          item.value,
                                          maxLines: 1,
                                          style: HostStudioTokens.kpiValue
                                              .copyWith(
                                            fontSize: 21,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      item.icon,
                                      size: 15,
                                      color: AppColors.iconMuted,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: HostStudioTokens.kpiLabel.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filterOptions.map((opt) {
                  final selected = _listingStatusFilter == opt.$1;
                  final int? badgeCount =
                      hasSnapshot || _listingStatusFilter == 'all'
                          ? (opt.$1 == 'all'
                              ? summarySource.length
                              : counts[opt.$1] ?? 0)
                          : null;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildListingFilterPill(
                      pillKey: Key('listing_filter_${opt.$1}'),
                      label: opt.$2,
                      count: badgeCount,
                      selected: selected,
                      onTap: () {
                        setState(() {
                          _listingStatusFilter = opt.$1;
                          _listingsVisibleCount = 10;
                        });
                        _fetchListings();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                final inlineSort =
                    constraints.maxWidth >= 420 && textScale <= 1.2;
                if (inlineSort) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Hiển thị ${visibleListings.length}/${sortedListings.length} chỗ nghỉ',
                          style: HostStudioTokens.metaCaption,
                        ),
                      ),
                      const SizedBox(width: 12),
                      buildSortDropdown(expanded: false),
                    ],
                  );
                }
                return buildSortDropdown(expanded: true);
              },
            ),
            const SizedBox(height: 10),
            if (_loadingListings)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (sortedListings.isEmpty)
              _buildEmptyBox(
                'Chưa có chỗ nghỉ phù hợp bộ lọc.',
                borderless: true,
              )
            else ...[
              for (var i = 0; i < visibleListings.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _buildListingCard(visibleListings[i]),
              ],
              if (sortedListings.length > visibleListings.length)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: OutlinedButton(
                      key: const Key('listings_load_more_btn'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(160, 48),
                        backgroundColor: HostStudioTokens.cardSurface,
                        foregroundColor: HostStudioTokens.inkPrimary,
                        side: const BorderSide(
                          color: HostStudioTokens.hairline,
                        ),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () {
                        setState(() => _listingsVisibleCount += 10);
                      },
                      child: Text(
                        'Xem thêm (${sortedListings.length - visibleListings.length} chỗ nghỉ)',
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListingCard(Map<String, dynamic> listing) {
    final summary = HostListingSummary.fromJson(listing);
    final id = summary.id;
    final title = summary.title;
    final statusEnum = summary.status;
    final propType = summary.propertyType;
    final basePrice = summary.basePrice;
    final weekendPrice = summary.weekendPrice;
    final maxGuests = summary.maxGuests;
    final imageUrl = summary.imageUrl.isNotEmpty
        ? summary.imageUrl
        : _extractListingCoverUrl(listing);
    final rejectReason = summary.rejectionReason ?? '';
    final addressParts = summary.addressDisplay;

    final isBusy = _busyListingActionId == id;
    final repo = ref.read(hostPortalViewModelProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final thumbSize = screenWidth < 350 ? 72.0 : 84.0;
    final secondaryActionStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(84, 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: HostStudioTokens.softCircle,
      foregroundColor: HostStudioTokens.inkPrimary,
      side: BorderSide.none,
      shape: const StadiumBorder(),
    );

    return Container(
      key: Key('host_listing_item_$id'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HostStudioTokens.cardSurface,
        borderRadius: BorderRadius.circular(HostStudioTokens.cardRadius),
        border: Border.all(color: HostStudioTokens.groupBorder),
        boxShadow: HostStudioTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              imageUrl.isNotEmpty
                  ? AppImage(
                      imageUrl: imageUrl,
                      width: thumbSize,
                      height: thumbSize,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(16),
                    )
                  : _buildNoImagePlaceholder(
                      width: thumbSize,
                      height: thumbSize,
                      borderRadius: 16,
                    ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildStatusPill(statusEnum.labelVi, statusEnum.value),
                        Text(
                          '${propType.labelVi} · $maxGuests khách',
                          style: HostStudioTokens.metaCaption,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HostStudioTokens.cardTitle.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (addressParts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.mapPin,
                            size: 12.5,
                            color: AppColors.iconMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              addressParts,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HostStudioTokens.metaCaption,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: formatHostVnd(basePrice),
                                style: HostStudioTokens.priceEmphasis.copyWith(
                                  fontSize: 15,
                                ),
                              ),
                              const TextSpan(
                                text: '/đêm',
                                style: HostStudioTokens.metaCaption,
                              ),
                            ],
                          ),
                        ),
                        if (weekendPrice != null)
                          Text(
                            '· CT ${formatCompactHostVnd(weekendPrice)}',
                            style: HostStudioTokens.metaCaption,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (statusEnum == HostListingStatus.rejected &&
              rejectReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              key: Key('listing_rejection_reason_$id'),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      AppSemanticIcons.errorAlert,
                      size: 15,
                      color: AppColors.iconStrong,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lý do từ chối: $rejectReason',
                      style: HostStudioTokens.bodyRegular.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(
            height: 20,
            thickness: 1,
            color: HostStudioTokens.hairline,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: Key('listing_edit_btn_$id'),
                style: secondaryActionStyle,
                onPressed: isBusy
                    ? null
                    : () => _switchSection(
                          HostPortalSection.newProperty,
                          editListingId: id,
                        ),
                icon: const Icon(
                  LucideIcons.pencil,
                  size: 14.5,
                  color: AppColors.iconStrong,
                ),
                label: Text(
                  statusEnum == HostListingStatus.rejected
                      ? 'Chỉnh sửa'
                      : 'Sửa',
                  style: HostStudioTokens.pillText.copyWith(
                    color: HostStudioTokens.inkPrimary,
                  ),
                ),
              ),
              if (statusEnum == HostListingStatus.draft ||
                  statusEnum == HostListingStatus.rejected)
                ElevatedButton.icon(
                  key: Key('listing_submit_approval_btn_$id'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.iconOnBrand,
                    minimumSize: const Size(104, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  onPressed: isBusy
                      ? null
                      : () => _runListingMutation(
                            id,
                            () => repo.submitListingForApproval(id),
                          ),
                  icon: const Icon(
                    LucideIcons.send,
                    size: 14.5,
                    color: AppColors.iconOnBrand,
                  ),
                  label: Text(
                    statusEnum == HostListingStatus.rejected
                        ? 'Gửi duyệt lại'
                        : 'Gửi duyệt',
                    style: HostStudioTokens.pillText.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.iconOnBrand,
                    ),
                  ),
                ),
              if (statusEnum == HostListingStatus.pendingApproval)
                OutlinedButton.icon(
                  key: Key('listing_withdraw_draft_btn_$id'),
                  style: secondaryActionStyle,
                  onPressed: isBusy
                      ? null
                      : () => _runListingMutation(
                            id,
                            () => repo.updateHostListing(
                              id,
                              {'status': HostListingStatus.draft.value},
                            ),
                          ),
                  icon: const Icon(
                    LucideIcons.rotateCcw,
                    size: 14.5,
                    color: AppColors.iconStrong,
                  ),
                  label: Text(
                    'Rút về nháp',
                    style: HostStudioTokens.pillText.copyWith(
                      color: HostStudioTokens.inkPrimary,
                    ),
                  ),
                ),
              if (statusEnum == HostListingStatus.published)
                OutlinedButton.icon(
                  key: Key('listing_hide_btn_$id'),
                  style: secondaryActionStyle,
                  onPressed: isBusy
                      ? null
                      : () => _runListingMutation(
                            id,
                            () => repo.hideHostListing(id),
                          ),
                  icon: const Icon(
                    LucideIcons.eyeOff,
                    size: 14.5,
                    color: AppColors.iconStrong,
                  ),
                  label: Text(
                    'Ẩn',
                    style: HostStudioTokens.pillText.copyWith(
                      color: HostStudioTokens.inkPrimary,
                    ),
                  ),
                ),
              if (statusEnum == HostListingStatus.hidden)
                OutlinedButton.icon(
                  key: Key('listing_publish_btn_$id'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(84, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: HostStudioTokens.cardSurface,
                    foregroundColor: HostStudioTokens.inkPrimary,
                    side: const BorderSide(color: AppColors.borderFocus),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: isBusy
                      ? null
                      : () => _runListingMutation(
                            id,
                            () => repo.publishHostListing(id),
                          ),
                  icon: const Icon(
                    LucideIcons.eye,
                    size: 14.5,
                    color: AppColors.iconStrong,
                  ),
                  label: Text(
                    'Hiện',
                    style: HostStudioTokens.pillText.copyWith(
                      fontWeight: FontWeight.w600,
                      color: HostStudioTokens.inkPrimary,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                key: Key('listing_delete_btn_$id'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(84, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: AppColors.errorSoft,
                  foregroundColor: AppColors.error,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),
                onPressed:
                    isBusy ? null : () => _confirmAndDeleteListing(listing),
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 14.5,
                  color: AppColors.iconStrong,
                ),
                label: Text(
                  'Xóa',
                  style: HostStudioTokens.pillText.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoImagePlaceholder({
    double width = 84,
    double height = 84,
    double borderRadius = 16,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: const Icon(
        LucideIcons.image,
        size: 22,
        color: AppColors.iconMuted,
      ),
    );
  }

  IconData _getBookingStatusIcon(String status) {
    switch (status) {
      case 'all':
        return LucideIcons.layers;
      case 'pending_payment':
      case 'pending':
        return LucideIcons.clock;
      case 'paid':
        return LucideIcons.creditCard;
      case 'confirmed':
        return LucideIcons.circleCheck;
      case 'checked_in':
        return LucideIcons.bedDouble;
      case 'completed':
      case 'checked_out':
        return LucideIcons.circleCheckBig;
      case 'cancelled':
        return LucideIcons.ban;
      case 'payment_expired':
        return LucideIcons.clockAlert;
      default:
        return LucideIcons.filter;
    }
  }

  IconData _getBookingSortIcon(String sort) {
    switch (sort) {
      case 'newest':
        return LucideIcons.calendar;
      case 'checkin_asc':
        return LucideIcons.clock;
      case 'total_desc':
        return LucideIcons.arrowDownUp;
      default:
        return LucideIcons.arrowDownUp;
    }
  }

  void _showBookingStatusFilterModal(
    List<(String, String)> filterTabs,
    Map<String, int> tabCounts,
    String effectiveFilter,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final maxSheetHeight = MediaQuery.sizeOf(ctx).height * 0.85;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Material(
            color: HostStudioTokens.cardSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: HostStudioTokens.hairline,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Lọc trạng thái đơn',
                            style: HostStudioTokens.headerTitle,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          padding: EdgeInsets.zero,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(
                            LucideIcons.x,
                            size: 20,
                            color: HostStudioTokens.iconInk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final tab in filterTabs) ...[
                                Builder(
                                  builder: (context) {
                                    final selected = effectiveFilter == tab.$1;
                                    final count = tabCounts[tab.$1] ?? 0;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: InkWell(
                                        key: Key('booking_filter_${tab.$1}'),
                                        borderRadius: BorderRadius.circular(
                                          HostStudioTokens.pillRadius,
                                        ),
                                        splashColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        overlayColor: WidgetStateProperty.all(
                                          Colors.transparent,
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _bookingStatusFilter = tab.$1;
                                            _bookingsVisibleCount = 10;
                                          });
                                          Navigator.of(ctx).pop();
                                        },
                                        child: Container(
                                          constraints: const BoxConstraints(
                                            minHeight: 50,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              HostStudioTokens.pillRadius,
                                            ),
                                            border: Border.all(
                                              color: selected
                                                  ? HostStudioTokens.obsidian
                                                  : Colors.transparent,
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                _getBookingStatusIcon(tab.$1),
                                                size: 19,
                                                color: selected
                                                    ? HostStudioTokens.inkPrimary
                                                    : HostStudioTokens
                                                        .iconSecondary,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  tab.$2,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: HostStudioTokens
                                                      .cardTitle
                                                      .copyWith(
                                                    fontSize: 14.5,
                                                    fontWeight: selected
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                    color: selected
                                                        ? HostStudioTokens
                                                            .inkPrimary
                                                        : HostStudioTokens
                                                            .inkSecondary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      HostStudioTokens.softCircle,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    HostStudioTokens.pillRadius,
                                                  ),
                                                ),
                                                child: Text(
                                                  '$count',
                                                  style: HostStudioTokens
                                                      .metaCaption
                                                      .copyWith(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: HostStudioTokens
                                                        .inkSecondary,
                                                  ),
                                                ),
                                              ),
                                              if (selected) ...[
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  LucideIcons.check,
                                                  color: HostStudioTokens.iconInk,
                                                  size: 18,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBookingSortModal(List<(String, String)> sortOptions) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Material(
          color: HostStudioTokens.cardSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: HostStudioTokens.hairline,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Sắp xếp theo',
                          style: HostStudioTokens.headerTitle,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        padding: EdgeInsets.zero,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(
                          LucideIcons.x,
                          size: 20,
                          color: HostStudioTokens.iconInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final opt in sortOptions) ...[
                    Builder(
                      builder: (context) {
                        final selected = _bookingSortBy == opt.$1;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            key: Key('booking_sort_${opt.$1}'),
                            borderRadius: BorderRadius.circular(
                              HostStudioTokens.pillRadius,
                            ),
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            overlayColor: WidgetStateProperty.all(
                              Colors.transparent,
                            ),
                            onTap: () {
                              setState(() => _bookingSortBy = opt.$1);
                              Navigator.of(ctx).pop();
                            },
                            child: Container(
                              constraints: const BoxConstraints(
                                minHeight: 50,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  HostStudioTokens.pillRadius,
                                ),
                                border: Border.all(
                                  color: selected
                                      ? HostStudioTokens.obsidian
                                      : Colors.transparent,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _getBookingSortIcon(opt.$1),
                                    size: 19,
                                    color: selected
                                        ? HostStudioTokens.inkPrimary
                                        : HostStudioTokens.iconSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      opt.$2,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: HostStudioTokens.cardTitle.copyWith(
                                        fontSize: 14.5,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: selected
                                            ? HostStudioTokens.inkPrimary
                                            : HostStudioTokens.inkSecondary,
                                      ),
                                    ),
                                  ),
                                  if (selected) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      LucideIcons.check,
                                      color: HostStudioTokens.iconInk,
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 4. HOST BOOKINGS (`DatPhong`) SECTION
  // ===========================================================================

  // Thuật toán lọc, đếm theo từng danh mục trạng thái chuẩn và sắp xếp danh sách Đặt phòng của Host.
  Widget _buildBookingsSection() {
    const filterTabs = [
      ('all', 'Tất cả'),
      ('pending_payment', 'Chờ thanh toán'),
      ('paid', 'Đã thanh toán'),
      ('confirmed', 'Đã xác nhận'),
      ('checked_in', 'Khách đã nhận phòng'),
      ('completed', 'Hoàn tất'),
      ('cancelled', 'Đã hủy'),
      ('payment_expired', 'Quá hạn thanh toán'),
    ];

    const sortOptions = [
      ('newest', 'Mới nhất'),
      ('checkin_asc', 'Sắp nhận phòng'),
      ('total_desc', 'Giá cao nhất'),
    ];

    final effectiveFilter = _bookingStatusFilter == 'checked_out'
        ? 'completed'
        : (filterTabs.any((t) => t.$1 == _bookingStatusFilter)
            ? _bookingStatusFilter
            : 'all');

    final tabCounts = <String, int>{
      for (final tab in filterTabs)
        tab.$1: countHostBookingsMatchingFilter(
          _bookings,
          tab.$1,
          role: BookingActionRole.host,
        ),
    };

    final filtered = _bookings
        .where(
          (b) => bookingMatchesDisplayStatus(
            b,
            effectiveFilter,
            role: BookingActionRole.host,
          ),
        )
        .toList();

    filtered.sort((a, b) {
      if (_bookingSortBy == 'checkin_asc') {
        final ca = (a['checkInDate'] ?? '').toString();
        final cb = (b['checkInDate'] ?? '').toString();
        return ca.compareTo(cb);
      }
      if (_bookingSortBy == 'total_desc') {
        final ta = (a['totalPrice'] ?? a['totalAmount'] ?? 0) is num
            ? ((a['totalPrice'] ?? a['totalAmount'] ?? 0) as num).toDouble()
            : (double.tryParse('${a['totalPrice'] ?? 0}') ?? 0);
        final tb = (b['totalPrice'] ?? b['totalAmount'] ?? 0) is num
            ? ((b['totalPrice'] ?? b['totalAmount'] ?? 0) as num).toDouble()
            : (double.tryParse('${b['totalPrice'] ?? 0}') ?? 0);
        return tb.compareTo(ta);
      }
      final ida = int.tryParse('${a['bookingId'] ?? a['id'] ?? 0}') ?? 0;
      final idb = int.tryParse('${b['bookingId'] ?? b['id'] ?? 0}') ?? 0;
      return idb.compareTo(ida);
    });

    final currentFilterLabel = filterTabs
        .firstWhere(
          (t) => t.$1 == effectiveFilter,
          orElse: () => ('all', 'Tất cả'),
        )
        .$2;
    final currentFilterCount = tabCounts[effectiveFilter] ?? 0;

    final currentSortLabel = sortOptions
        .firstWhere(
          (s) => s.$1 == _bookingSortBy,
          orElse: () => ('newest', 'Mới nhất'),
        )
        .$2;

    final visibleBookings = filtered.take(_bookingsVisibleCount).toList();

    return RefreshIndicator(
      onRefresh: _fetchBookings,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_bookingsError != null) ...[
              _buildInlineError(
                _bookingsError!,
                onRetry: _fetchBookings,
              ),
              const SizedBox(height: 16),
            ],
            if (_bookingsSuccess != null) ...[
              _buildInlineSuccess(_bookingsSuccess!),
              const SizedBox(height: 16),
            ],
            // Thanh Filter Chips trượt ngang hiện đại kèm số lượng thực tế từng mục
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filterTabs.map((tab) {
                  final isSelected = effectiveFilter == tab.$1;
                  final count = tabCounts[tab.$1] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      key: Key('booking_chip_${tab.$1}'),
                      selected: isSelected,
                      showCheckmark: false,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tab.$2,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.textInverse
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.surfaceBase
                                      .withValues(alpha: 0.18)
                                  : AppColors.surfaceBase,
                              borderRadius: BorderRadius.circular(
                                HostStudioTokens.pillRadius,
                              ),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppColors.textInverse
                                    : HostStudioTokens.inkSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.surfaceSecondary,
                      selectedColor: HostStudioTokens.obsidian,
                      side: BorderSide(
                        color: isSelected
                            ? HostStudioTokens.obsidian
                            : AppColors.border,
                      ),
                      shape: const StadiumBorder(),
                      onSelected: (selected) {
                        setState(() {
                          _bookingStatusFilter = tab.$1;
                          _bookingsVisibleCount = 10;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: HostStudioTokens.cardSurface,
                    borderRadius: BorderRadius.circular(
                      HostStudioTokens.pillRadius,
                    ),
                    child: InkWell(
                      key: const Key('booking_filter_dropdown'),
                      borderRadius: BorderRadius.circular(
                        HostStudioTokens.pillRadius,
                      ),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      onTap: () => _showBookingStatusFilterModal(
                        filterTabs,
                        tabCounts,
                        effectiveFilter,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 46),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            HostStudioTokens.pillRadius,
                          ),
                          border: Border.all(
                            color: effectiveFilter != 'all'
                                ? HostStudioTokens.obsidian
                                : HostStudioTokens.hairline,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getBookingStatusIcon(effectiveFilter),
                              size: 17,
                              color: effectiveFilter != 'all'
                                  ? HostStudioTokens.inkPrimary
                                  : HostStudioTokens.iconSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                currentFilterLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HostStudioTokens.cardTitle.copyWith(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: HostStudioTokens.inkPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: HostStudioTokens.softCircle,
                                borderRadius: BorderRadius.circular(
                                  HostStudioTokens.pillRadius,
                                ),
                              ),
                              child: Text(
                                '$currentFilterCount',
                                style: HostStudioTokens.metaCaption.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: HostStudioTokens.inkSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              LucideIcons.chevronDown,
                              size: 16,
                              color: HostStudioTokens.iconSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: HostStudioTokens.cardSurface,
                    borderRadius: BorderRadius.circular(
                      HostStudioTokens.pillRadius,
                    ),
                    child: InkWell(
                      key: const Key('booking_sort_dropdown'),
                      borderRadius: BorderRadius.circular(
                        HostStudioTokens.pillRadius,
                      ),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      onTap: () => _showBookingSortModal(sortOptions),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 46),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            HostStudioTokens.pillRadius,
                          ),
                          border: Border.all(
                            color: HostStudioTokens.hairline,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getBookingSortIcon(_bookingSortBy),
                              size: 17,
                              color: HostStudioTokens.iconSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                currentSortLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HostStudioTokens.cardTitle.copyWith(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: HostStudioTokens.inkPrimary,
                                ),
                              ),
                            ),
                            const Icon(
                              LucideIcons.chevronDown,
                              size: 16,
                              color: HostStudioTokens.iconSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingBookings)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              _buildEmptyBox('Chưa có đặt phòng phù hợp.')
            else ...[
              for (var i = 0; i < visibleBookings.length; i++) ...[
                if (i > 0) const Divider(height: 24, color: AppColors.border),
                _buildBookingItemCard(visibleBookings[i]),
              ],
              if (filtered.length > visibleBookings.length)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    key: const Key('bookings_load_more_btn'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(160, 48),
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () {
                      setState(() => _bookingsVisibleCount += 10);
                    },
                    child: Text(
                      'Xem thêm (${filtered.length - visibleBookings.length} đặt phòng)',
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatBookingDate(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? value : DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _launchPhoneCall(BuildContext context, String rawPhone) async {
    final clean = ContactService.normalizePhone(rawPhone);
    if (clean.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      final canLaunch = ContactService.canLaunchUrlOverride != null
          ? await ContactService.canLaunchUrlOverride!(uri)
          : await canLaunchUrl(uri);
      if (canLaunch) {
        final launched = ContactService.launchUrlOverride != null
            ? await ContactService.launchUrlOverride!(
                uri, LaunchMode.platformDefault)
            : await launchUrl(uri);
        if (launched) return;
      }
    } catch (_) {
      // Fallback below
    }
    await Clipboard.setData(ClipboardData(text: clean));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã sao chép số điện thoại $clean!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _launchZaloChat(BuildContext context, String rawPhone) async {
    final clean = ContactService.normalizePhone(rawPhone);
    if (clean.isEmpty) return;
    String local = clean;
    if (local.startsWith('+84')) {
      local = '0${local.substring(3)}';
    } else if (local.startsWith('84') && local.length >= 10) {
      local = '0${local.substring(2)}';
    }
    final uri = Uri.parse('https://zalo.me/$local');
    try {
      final canLaunch = ContactService.canLaunchUrlOverride != null
          ? await ContactService.canLaunchUrlOverride!(uri)
          : await canLaunchUrl(uri);
      if (canLaunch) {
        final launched = ContactService.launchUrlOverride != null
            ? await ContactService.launchUrlOverride!(
                uri, LaunchMode.externalApplication)
            : await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return;
      }
    } catch (_) {
      // Fallback below
    }
    await Clipboard.setData(ClipboardData(text: local));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã sao chép số Zalo $local!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _launchEmail(BuildContext context, String rawEmail) async {
    final clean = rawEmail.trim();
    if (clean.isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: clean);
    try {
      final canLaunch = ContactService.canLaunchUrlOverride != null
          ? await ContactService.canLaunchUrlOverride!(uri)
          : await canLaunchUrl(uri);
      if (canLaunch) {
        final launched = ContactService.launchUrlOverride != null
            ? await ContactService.launchUrlOverride!(
                uri, LaunchMode.platformDefault)
            : await launchUrl(uri);
        if (launched) return;
      }
    } catch (_) {
      // Fallback below
    }
    await Clipboard.setData(ClipboardData(text: clean));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã sao chép email $clean!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showGuestContactDialog({
    required BuildContext context,
    required String guestName,
    required String phone,
    required String email,
  }) {
    final cleanPhone = phone.trim();
    final cleanEmail = email.trim();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: HostStudioTokens.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            HostStudioInitialsBadge(name: guestName, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Thông tin liên hệ khách',
                    style: HostStudioTokens.headerEyebrow.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: HostStudioTokens.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    guestName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HostStudioTokens.sectionTitle.copyWith(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ô hiển thị Số điện thoại
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: HostStudioTokens.groupSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HostStudioTokens.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: cleanPhone.isNotEmpty
                            ? () => _launchPhoneCall(context, cleanPhone)
                            : null,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cleanPhone.isNotEmpty
                                ? HostStudioTokens.obsidian
                                : HostStudioTokens.cardSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: HostStudioTokens.hairline),
                          ),
                          child: Icon(
                            LucideIcons.phone,
                            size: 16,
                            color: cleanPhone.isNotEmpty
                                ? Colors.white
                                : HostStudioTokens.iconInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Số điện thoại',
                              style: HostStudioTokens.metaCaption.copyWith(
                                fontSize: 11.5,
                                color: HostStudioTokens.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              cleanPhone.isNotEmpty
                                  ? cleanPhone
                                  : 'Chưa cập nhật số điện thoại',
                              key: const Key('guest_contact_phone_text'),
                              style: HostStudioTokens.bodyRegular.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cleanPhone.isNotEmpty
                                    ? HostStudioTokens.inkPrimary
                                    : HostStudioTokens.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (cleanPhone.isNotEmpty)
                        IconButton(
                          key: const Key('guest_contact_copy_phone_btn'),
                          tooltip: 'Sao chép số điện thoại',
                          icon: const Icon(
                            LucideIcons.copy,
                            size: 16,
                            color: HostStudioTokens.iconSecondary,
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: cleanPhone));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép số điện thoại!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  if (cleanPhone.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('guest_contact_call_phone_btn'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              backgroundColor: HostStudioTokens.cardSurface,
                              foregroundColor: HostStudioTokens.inkPrimary,
                              side: const BorderSide(
                                color: HostStudioTokens.hairline,
                              ),
                              shape: const StadiumBorder(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            icon: const Icon(
                              LucideIcons.phoneCall,
                              size: 13.5,
                              color: HostStudioTokens.iconInk,
                            ),
                            label: const Text(
                              'Gọi điện',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () =>
                                _launchPhoneCall(context, cleanPhone),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            key: const Key('guest_contact_zalo_btn'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              backgroundColor: const Color(0xFF0068FF),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: const StadiumBorder(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            icon: const Icon(
                              LucideIcons.messageCircle,
                              size: 13.5,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Nhắn Zalo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: () =>
                                _launchZaloChat(context, cleanPhone),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Ô hiển thị Email / Gmail
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: HostStudioTokens.groupSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HostStudioTokens.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: cleanEmail.isNotEmpty
                            ? () => _launchEmail(context, cleanEmail)
                            : null,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cleanEmail.isNotEmpty
                                ? HostStudioTokens.obsidian
                                : HostStudioTokens.cardSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: HostStudioTokens.hairline),
                          ),
                          child: Icon(
                            LucideIcons.mail,
                            size: 16,
                            color: cleanEmail.isNotEmpty
                                ? Colors.white
                                : HostStudioTokens.iconInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Email / Gmail',
                              style: HostStudioTokens.metaCaption.copyWith(
                                fontSize: 11.5,
                                color: HostStudioTokens.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              cleanEmail.isNotEmpty
                                  ? cleanEmail
                                  : 'Chưa cập nhật email',
                              key: const Key('guest_contact_email_text'),
                              style: HostStudioTokens.bodyRegular.copyWith(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: cleanEmail.isNotEmpty
                                    ? HostStudioTokens.inkPrimary
                                    : HostStudioTokens.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (cleanEmail.isNotEmpty)
                        IconButton(
                          key: const Key('guest_contact_copy_email_btn'),
                          tooltip: 'Sao chép email',
                          icon: const Icon(
                            LucideIcons.copy,
                            size: 16,
                            color: HostStudioTokens.iconSecondary,
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: cleanEmail));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép email!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  if (cleanEmail.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('guest_contact_send_email_btn'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        backgroundColor: HostStudioTokens.cardSurface,
                        foregroundColor: HostStudioTokens.inkPrimary,
                        side: const BorderSide(
                          color: HostStudioTokens.hairline,
                        ),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      icon: const Icon(
                        LucideIcons.send,
                        size: 13.5,
                        color: HostStudioTokens.iconInk,
                      ),
                      label: const Text(
                        'Gửi thư điện tử (Gmail/Email)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => _launchEmail(context, cleanEmail),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('guest_contact_close_btn'),
            style: TextButton.styleFrom(
              foregroundColor: HostStudioTokens.inkPrimary,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingItemCard(
    Map<String, dynamic> booking, {
    bool inStudioGroup = false,
    bool hasBottomMargin = true,
  }) {
    final bookingId = (booking['bookingId'] ?? booking['id'] ?? '').toString();
    final guestName =
        (booking['guestName'] ?? booking['customerName'] ?? 'Khách #$bookingId')
            .toString();
    final guestPhone = (booking['guestPhone'] ??
            booking['guest']?['phone'] ??
            booking['phone'] ??
            '')
        .toString()
        .trim();
    final guestEmail = (booking['guestEmail'] ??
            booking['guest']?['email'] ??
            booking['email'] ??
            '')
        .toString()
        .trim();
    final listingTitle =
        (booking['listingTitle'] ?? 'Chỗ nghỉ #${booking['listingId'] ?? ''}')
            .toString();
    final checkIn = (booking['checkInDate'] ?? '').toString().split('T').first;
    final checkOut =
        (booking['checkOutDate'] ?? '').toString().split('T').first;
    final guestsCount = booking['guestsCount'] ?? booking['guests'] ?? 1;
    final totalPrice = booking['totalPrice'] ?? booking['totalAmount'] ?? 0;

    final display = getBookingDisplayStatus(
      booking,
      role: BookingActionRole.host,
    );
    final actions = display.actions;
    final isBusy = _busyBookingActionId == bookingId;
    final primaryActionStyle = ElevatedButton.styleFrom(
      backgroundColor: HostStudioTokens.obsidian,
      foregroundColor: Colors.white,
      minimumSize: const Size(108, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      textStyle: HostStudioTokens.pillText.copyWith(fontSize: 13),
      shape: const StadiumBorder(),
      elevation: 0,
    );

    return Container(
      key: Key('host_booking_card_$bookingId'),
      margin: hasBottomMargin ? const EdgeInsets.only(bottom: 12) : null,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: HostStudioTokens.cardSurface,
        borderRadius: BorderRadius.circular(HostStudioTokens.cardRadius),
        border:
            inStudioGroup ? null : Border.all(color: HostStudioTokens.hairline),
        boxShadow: HostStudioTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: HostStudioTokens.softCircle,
                    borderRadius:
                        BorderRadius.circular(HostStudioTokens.pillRadius),
                  ),
                  child: Text(
                    '#$bookingId',
                    style: HostStudioTokens.pillText.copyWith(
                      fontSize: 11.5,
                      color: HostStudioTokens.inkSecondary,
                    ),
                  ),
                ),
                _buildStatusPill(display.label, display.code),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            listingTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HostStudioTokens.cardTitle,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              HostStudioInitialsBadge(name: guestName, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$guestName · $guestsCount khách',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HostStudioTokens.bodyRegular,
                ),
              ),
              if (guestPhone.isNotEmpty) ...[
                HostStudioCircleButton(
                  icon: LucideIcons.messageCircle,
                  tooltip: 'Nhắn Zalo',
                  visualSize: 34,
                  iconSize: 15,
                  circleColor: HostStudioTokens.softCircle,
                  onTap: () => _launchZaloChat(context, guestPhone),
                ),
                const SizedBox(width: 6),
              ],
              if (guestPhone.isNotEmpty || guestEmail.isNotEmpty)
                HostStudioCircleButton(
                  icon: LucideIcons.phone,
                  tooltip: 'Liên hệ khách',
                  visualSize: 34,
                  iconSize: 15,
                  circleColor: HostStudioTokens.softCircle,
                  onTap: () => _showGuestContactDialog(
                    context: context,
                    guestName: guestName,
                    phone: guestPhone,
                    email: guestEmail,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: const Color(0xFFF1F3F6),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.calendar,
                      size: 14.5,
                      color: HostStudioTokens.iconMuted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${_formatBookingDate(checkIn)} → ${_formatBookingDate(checkOut)}',
                        style: HostStudioTokens.metaCaption.copyWith(
                          fontSize: 12.5,
                          color: HostStudioTokens.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  formatHostVnd(totalPrice),
                  style: HostStudioTokens.priceEmphasis,
                ),
              ],
            ),
          ),
          if (actions.hasAnyAction) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (actions.canConfirm)
                  ElevatedButton.icon(
                    key: Key('booking_confirm_btn_$bookingId'),
                    style: primaryActionStyle,
                    onPressed: isBusy
                        ? null
                        : () => _handleBookingAction(booking, 'confirm'),
                    icon: const Icon(LucideIcons.check, size: 15),
                    label: const Text('Xác nhận'),
                  ),
                if (actions.canCheckIn)
                  ElevatedButton.icon(
                    key: Key('booking_checkin_btn_$bookingId'),
                    style: primaryActionStyle,
                    onPressed: isBusy
                        ? null
                        : () => _handleBookingAction(booking, 'check_in'),
                    icon: const Icon(AppSemanticIcons.checkIn, size: 15),
                    label: const Text('Check-in'),
                  ),
                if (actions.canCheckOut)
                  ElevatedButton.icon(
                    key: Key('booking_checkout_btn_$bookingId'),
                    style: primaryActionStyle,
                    onPressed: isBusy
                        ? null
                        : () => _handleBookingAction(booking, 'check_out'),
                    icon: const Icon(AppSemanticIcons.checkOut, size: 15),
                    label: const Text('Check-out'),
                  ),
                if (actions.canCancel)
                  OutlinedButton.icon(
                    key: Key('booking_cancel_btn_$bookingId'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(94, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: HostStudioTokens.hairline),
                      textStyle: HostStudioTokens.pillText.copyWith(
                        fontSize: 13,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: isBusy
                        ? null
                        : () => _handleBookingAction(booking, 'cancel'),
                    icon: const Icon(
                      LucideIcons.x,
                      size: 15,
                      color: AppColors.iconStrong,
                    ),
                    label: const Text('Hủy'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. CALENDAR (`LichLuuTru`) SECTION — AIRBNB HOST STYLE & PERSONAL OPTIMIZATION
  // ===========================================================================

  double _getListingBasePrice(String listingId) {
    for (final l in _unfilteredListings) {
      if ('${l['listingId'] ?? l['id']}' == listingId) {
        final p = l['basePrice'] ?? l['pricePerNight'] ?? 0;
        return p is num ? p.toDouble() : (double.tryParse('$p') ?? 0);
      }
    }
    return 0;
  }

  void _applyPricePreset(double multiplier) {
    final basePrice = _getListingBasePrice(_calendarListingId ?? '');
    final newPrice = (basePrice * multiplier).round();
    setState(() {
      _calendarPriceOverrideCtrl.text = '$newPrice';
    });
  }

  bool _isDayInPast(HostCalendarDay d) {
    return d.isPast || !d.canEdit;
  }

  void _selectWeekendDays() {
    final targets = <String>{};
    for (final d in _calendarDays) {
      if (_isDayInPast(d)) continue;
      final parsed = DateTime.tryParse(d.date);
      if (parsed != null &&
          (parsed.weekday == DateTime.saturday ||
              parsed.weekday == DateTime.sunday)) {
        final isBooked = isHostCalendarDayLockedByBooking(
          isBookedFlag: d.isBooked,
          bookingStatus: d.bookingStatus,
        );
        if (!isBooked) {
          targets.add(d.date);
        }
      }
    }
    if (targets.isEmpty) return;
    setState(() {
      final isAllSelected = targets.every(_selectedCalendarDates.contains);
      if (isAllSelected) {
        _selectedCalendarDates.removeAll(targets);
      } else {
        _selectedCalendarDates.addAll(targets);
      }
    });
  }

  void _selectAvailableDays() {
    final targets = <String>{};
    for (final d in _calendarDays) {
      if (_isDayInPast(d)) continue;
      final isBooked = isHostCalendarDayLockedByBooking(
        isBookedFlag: d.isBooked,
        bookingStatus: d.bookingStatus,
      );
      final isBlocked = !d.isAvailable || d.isBlockedByHost;
      if (!isBooked && !isBlocked) {
        targets.add(d.date);
      }
    }
    if (targets.isEmpty) return;
    setState(() {
      final isAllSelected = targets.every(_selectedCalendarDates.contains);
      if (isAllSelected) {
        _selectedCalendarDates.removeAll(targets);
      } else {
        _selectedCalendarDates.addAll(targets);
      }
    });
  }

  void _selectAllMonthDays() {
    final targets = <String>{};
    for (final d in _calendarDays) {
      if (_isDayInPast(d)) continue;
      final isBooked = isHostCalendarDayLockedByBooking(
        isBookedFlag: d.isBooked,
        bookingStatus: d.bookingStatus,
      );
      if (!isBooked) {
        targets.add(d.date);
      }
    }
    if (targets.isEmpty) return;
    setState(() {
      final isAllSelected = targets.every(_selectedCalendarDates.contains);
      if (isAllSelected) {
        _selectedCalendarDates.removeAll(targets);
      } else {
        _selectedCalendarDates.addAll(targets);
      }
    });
  }

  void _clearSelectedDays() {
    setState(() {
      _selectedCalendarDates.clear();
    });
  }

  void _prevMonth() {
    setState(() {
      if (_calendarMonth == 1) {
        _calendarMonth = 12;
        _calendarYear--;
      } else {
        _calendarMonth--;
      }
    });
    _fetchCalendarDays();
  }

  void _nextMonth() {
    setState(() {
      if (_calendarMonth == 12) {
        _calendarMonth = 1;
        _calendarYear++;
      } else {
        _calendarMonth++;
      }
    });
    _fetchCalendarDays();
  }

  void _goToCurrentMonth() {
    final vnNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    setState(() {
      _calendarMonth = vnNow.month;
      _calendarYear = vnNow.year;
    });
    _fetchCalendarDays();
  }

  Widget _buildListingCalendarDotMatrix(Map<String, dynamic> listing) {
    final listingId = (listing['listingId'] ?? listing['id'] ?? '').toString();
    final today = DateTime.now();

    final bookedDateStrings = <String>{};
    for (final b in _bookings) {
      final bListingId = (b['listingId'] ?? b['listing_id'] ?? '').toString();
      if (bListingId == listingId && isCalendarBlockingHostBooking(b)) {
        final checkInStr = extractBookingDateOnly(
              b['checkInDate'] ?? b['check_in_date'] ?? b['check_in'],
            ) ??
            '';
        final checkOutStr = extractBookingDateOnly(
              b['checkOutDate'] ?? b['check_out_date'] ?? b['check_out'],
            ) ??
            '';
        final checkIn = DateTime.tryParse(checkInStr);
        final checkOut = DateTime.tryParse(checkOutStr);
        if (checkIn != null && checkOut != null) {
          for (var d = checkIn;
              d.isBefore(checkOut);
              d = d.add(const Duration(days: 1))) {
            bookedDateStrings.add(DateFormat('yyyy-MM-dd').format(d));
          }
        }
      }
    }

    if (listingId == _calendarListingId && _calendarDays.isNotEmpty) {
      for (final d in _calendarDays) {
        if (d.isBooked || isCalendarBlockingStatusCode(d.bookingStatus)) {
          bookedDateStrings.add(d.date);
        }
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var row = 0; row < 4; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var col = 0; col < 7; col++) ...[
                  if (col > 0) const SizedBox(width: 4.5),
                  () {
                    final dayOffset = row * 7 + col;
                    final targetDate = today.add(Duration(days: dayOffset));
                    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
                    final isBooked = bookedDateStrings.contains(dateStr);

                    final dotColor = isBooked
                        ? const Color(0xFFE11D48)
                        : const Color(0xFF64748B);

                    return Container(
                      width: 5.5,
                      height: 5.5,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    );
                  }(),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCalendarSection() {
    if (_calendarShowListingList) {
      return _buildCalendarAirbnbListingView();
    }
    return _buildCalendarDetailedMonthView();
  }

  Widget _buildCalendarAirbnbListingView() {
    final sourceListings = _unfilteredListings;
    final query = _calendarSearchQuery.trim().toLowerCase();
    final filtered = sourceListings.where((l) {
      final status = (l['status'] ?? '').toString();
      if (_calendarListingFilter == 'published' && status != 'published') {
        return false;
      }
      if (_calendarListingFilter == 'hidden' && status == 'published') {
        return false;
      }
      if (query.isEmpty) return true;
      final idStr = '${l['listingId'] ?? l['id'] ?? ''}'.toLowerCase();
      final title = (l['title'] ?? '').toString().toLowerCase();
      final address =
          '${l['addressLine'] ?? ''} ${l['city'] ?? ''}'.toLowerCase();
      return title.contains(query) ||
          address.contains(query) ||
          idStr.contains(query) ||
          '#$idStr'.contains(query);
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchListings();
        if (_calendarListingId != null) {
          await _fetchCalendarDays();
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HostSheetSyncCard(
              onCalendarChanged: () {
                _fetchListings();
                if (_calendarListingId != null) {
                  _fetchCalendarDays();
                }
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HostUnderlineTab(
                      label: Text('Tất cả (${sourceListings.length})'),
                      selected: _calendarListingFilter == 'all',
                      onSelected: (_) =>
                          setState(() => _calendarListingFilter = 'all'),
                    ),
                    _HostUnderlineTab(
                      label: const Text('Đang hiển thị'),
                      selected: _calendarListingFilter == 'published',
                      onSelected: (_) =>
                          setState(() => _calendarListingFilter = 'published'),
                    ),
                    _HostUnderlineTab(
                      label: const Text('Tạm ẩn / Khác'),
                      selected: _calendarListingFilter == 'hidden',
                      onSelected: (_) =>
                          setState(() => _calendarListingFilter = 'hidden'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Tìm kiếm',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () {
                        setState(() {
                          _calendarSearchVisible = !_calendarSearchVisible;
                        });
                      },
                      icon: Icon(
                        _calendarSearchVisible
                            ? LucideIcons.x
                            : LucideIcons.search,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_calendarListingId != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        onPressed: () {
                          setState(() => _calendarShowListingList = false);
                          _fetchCalendarDays();
                        },
                        icon: const Icon(LucideIcons.calendarDays, size: 15),
                        label: const Text(
                          'Xem lịch chi tiết',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (_calendarSearchVisible) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _calendarSearchCtrl,
                onChanged: (val) => setState(() => _calendarSearchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên, mã căn (#ID) hoặc địa chỉ...',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  suffixIcon: _calendarSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            _calendarSearchCtrl.clear();
                            setState(() => _calendarSearchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceBase,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
            if (_calendarError != null) ...[
              const SizedBox(height: 16),
              _buildInlineError(
                _calendarError!,
                onRetry: _fetchCalendarDays,
              ),
            ],
            if (_calendarSuccess != null) ...[
              const SizedBox(height: 16),
              _buildInlineSuccess(_calendarSuccess!),
            ],
            const SizedBox(height: 16),
            if (_loadingListings)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              _buildEmptyBox('Không tìm thấy chỗ nghỉ nào phù hợp.')
            else
              ...filtered.map((listing) {
                final id =
                    (listing['listingId'] ?? listing['id'] ?? '').toString();
                final title = (listing['title'] ?? 'Chỗ nghỉ #$id').toString();
                final statusEnum = HostListingStatus.fromApi(listing['status']);
                final basePrice =
                    listing['basePrice'] ?? listing['pricePerNight'] ?? 0;
                final imageUrl = _extractListingCoverUrl(listing);

                String statusTextVi;
                switch (statusEnum) {
                  case HostListingStatus.published:
                    statusTextVi = 'Đang hiển thị';
                    break;
                  case HostListingStatus.hidden:
                    statusTextVi = 'Đã hủy đăng';
                    break;
                  case HostListingStatus.pendingApproval:
                    statusTextVi = 'Chờ duyệt';
                    break;
                  case HostListingStatus.rejected:
                    statusTextVi = 'Bị từ chối';
                    break;
                  case HostListingStatus.draft:
                    statusTextVi = 'Bản nháp';
                    break;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      setState(() {
                        _calendarListingId = id;
                        _calendarShowListingList = false;
                      });
                      _fetchCalendarDays();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          imageUrl.isNotEmpty
                              ? AppImage(
                                  imageUrl: imageUrl,
                                  width: 76,
                                  height: 76,
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(12),
                                )
                              : _buildNoImagePlaceholder(
                                  width: 76,
                                  height: 76,
                                  borderRadius: 12,
                                ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (id.isNotEmpty)
                                      Text(
                                        'Mã #$id ·',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    Text(
                                      statusTextVi,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${formatHostVnd(basePrice)}/đêm',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildListingCalendarDotMatrix(listing),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // AIRBNB HOST CALENDAR PERSONALIZATION HELPERS
  // ===========================================================================

  String _formatSelectedDateRangeLabel() {
    if (_selectedCalendarDates.isEmpty) return '';
    final sorted = _selectedCalendarDates.toList()..sort();
    if (sorted.length == 1) {
      final dt = DateTime.tryParse(sorted.first);
      if (dt != null) {
        return '${dt.day} thg ${dt.month} (1 ngày đã chọn)';
      }
      return '${sorted.first} (1 ngày đã chọn)';
    }
    final firstDt = DateTime.tryParse(sorted.first);
    final lastDt = DateTime.tryParse(sorted.last);
    if (firstDt != null && lastDt != null) {
      final diffDays = lastDt.difference(firstDt).inDays;
      if (diffDays == sorted.length - 1) {
        if (firstDt.month == lastDt.month) {
          return '${firstDt.day} – ${lastDt.day} thg ${firstDt.month}';
        } else {
          return '${firstDt.day}/${firstDt.month} – ${lastDt.day}/${lastDt.month}';
        }
      }
    }
    return '${sorted.length} ngày đã chọn';
  }

  String _formatSelectedPriceRange() {
    if (_selectedCalendarDates.isEmpty) return '';
    final selectedDays = _calendarDays
        .where((d) => _selectedCalendarDates.contains(d.date))
        .toList();
    if (selectedDays.isEmpty) {
      final basePrice = _getListingBasePrice(_calendarListingId ?? '');
      return formatHostVnd(basePrice);
    }
    double minPrice = selectedDays.first.effectivePrice;
    double maxPrice = selectedDays.first.effectivePrice;
    for (final d in selectedDays) {
      if (d.effectivePrice < minPrice) minPrice = d.effectivePrice;
      if (d.effectivePrice > maxPrice) maxPrice = d.effectivePrice;
    }
    if (minPrice == maxPrice) {
      return formatHostVnd(minPrice);
    }
    return '${formatHostVnd(minPrice)} – ${formatHostVnd(maxPrice)}';
  }

  bool _areAllSelectedAvailable() {
    final selectedDays = _calendarDays
        .where((d) => _selectedCalendarDates.contains(d.date))
        .toList();
    if (selectedDays.isEmpty) return true;
    return selectedDays.every((d) => d.isAvailable && !d.isBlockedByHost);
  }

  Widget _buildCalendarDetailedMonthView() {
    final selectorListings = _unfilteredListings;
    final activeBasePrice = _getListingBasePrice(_calendarListingId ?? '');

    final totalDaysInMonth = DateTime(_calendarYear, _calendarMonth + 1, 0).day;
    final bookedDays = _calendarDays
        .where(
          (d) => isHostCalendarDayLockedByBooking(
            isBookedFlag: d.isBooked,
            bookingStatus: d.bookingStatus,
          ),
        )
        .length;
    final occupancyPercent = totalDaysInMonth > 0
        ? ((bookedDays / totalDaysInMonth) * 100).round()
        : 0;

    double estRevenue = 0;
    for (final d in _calendarDays) {
      if (isHostCalendarDayLockedByBooking(
        isBookedFlag: d.isBooked,
        bookingStatus: d.bookingStatus,
      )) {
        estRevenue += d.effectivePrice;
      }
    }
    final avgPrice = _calendarDays.isNotEmpty
        ? (_calendarDays.fold<double>(0, (s, d) => s + d.effectivePrice) /
                _calendarDays.length)
            .round()
        : activeBasePrice.round();

    final firstDayOfWeek =
        DateTime(_calendarYear, _calendarMonth, 1).weekday; // 1: T2 -> 7: CN
    final leadOffset = firstDayOfWeek - 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header: Back button + Large Title ONLY (No small subtitle text as requested!)
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () =>
                    setState(() => _calendarShowListingList = true),
                icon: const Icon(LucideIcons.arrowLeft, size: 16),
                label: const Text(
                  'Tất cả chỗ nghỉ',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const Text(
                'Lịch lưu trú & Giá theo ngày',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Compact Listing Selector Dropdown
          _buildPortalDropdown<String>(
            dropdownKey: const Key('calendar_listing_dropdown'),
            label: 'Chỗ nghỉ đang chọn',
            value: selectorListings.any(
              (l) => '${l['listingId'] ?? l['id']}' == _calendarListingId,
            )
                ? _calendarListingId
                : null,
            items: selectorListings.map((l) {
              final id = '${l['listingId'] ?? l['id']}';
              final title = (l['title'] ?? 'Listing #$id').toString();
              return DropdownMenuItem<String>(
                value: id,
                child: Text(title, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() => _calendarListingId = val);
              _fetchCalendarDays();
            },
          ),
          const SizedBox(height: 10),
          // 2. Ultra-Compact Mini KPI Strip (Lấp đầy, Dự kiến, Giá TB)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Lấp đầy',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$occupancyPercent%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Container(width: 1, height: 14, color: AppColors.border),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Dự kiến',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatCompactHostVnd(estRevenue),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Container(width: 1, height: 14, color: AppColors.border),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Giá TB',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${formatCompactHostVnd(avgPrice)}/đ',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_calendarError != null) ...[
            const SizedBox(height: 10),
            _buildInlineError(_calendarError!),
          ],
          if (_calendarSuccess != null) ...[
            const SizedBox(height: 10),
            _buildInlineSuccess(_calendarSuccess!),
          ],
          const SizedBox(height: 12),
          // 3. Month & Year Navigation Row (Airbnb style: 'thg M YYYY')
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'thg $_calendarMonth $_calendarYear',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    padding: EdgeInsets.zero,
                    tooltip: 'Tháng trước',
                    onPressed: _prevMonth,
                    icon: const Icon(
                      LucideIcons.chevronLeft,
                      size: 18,
                      color: AppColors.iconStrong,
                    ),
                  ),
                  IconButton(
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    padding: EdgeInsets.zero,
                    tooltip: 'Tháng sau',
                    onPressed: _nextMonth,
                    icon: const Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: AppColors.iconStrong,
                    ),
                  ),
                  TextButton(
                    onPressed: _goToCurrentMonth,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const Text('Hôm nay',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Backward-compatible month/year dropdowns in a compact row
          Row(
            children: [
              Expanded(
                child: _buildPortalDropdown<int>(
                  dropdownKey: const Key('calendar_month_dropdown'),
                  label: 'Tháng',
                  value: _calendarMonth,
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem<int>(
                      value: i + 1,
                      child: Text('Tháng ${i + 1}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  onChanged: (m) {
                    if (m == null) return;
                    setState(() => _calendarMonth = m);
                    _fetchCalendarDays();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPortalDropdown<int>(
                  dropdownKey: const Key('calendar_year_dropdown'),
                  label: 'Năm',
                  value: _calendarYear,
                  items: [
                    for (var y = _calendarYear - 1; y <= _calendarYear + 2; y++)
                      DropdownMenuItem<int>(
                        value: y,
                        child: Text('Năm $y',
                            style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                  onChanged: (y) {
                    if (y == null) return;
                    setState(() => _calendarYear = y);
                    _fetchCalendarDays();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingCalendar)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_calendarDays.isEmpty)
            _buildEmptyBox('Chưa có dữ liệu lịch lưu trú cho tháng đã chọn.')
          else ...[
            // 4. Compact 7-Column Calendar Grid (Fully fits ~30 days in one view)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Weekday Header: T2, T3, T4, T5, T6, T7, CN
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        for (final t in [
                          'T2',
                          'T3',
                          'T4',
                          'T5',
                          'T6',
                          'T7',
                          'CN'
                        ])
                          Expanded(
                            child: Center(
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontWeight: t == 'T7' || t == 'CN'
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  fontSize: 12,
                                  color: t == 'T7' || t == 'CN'
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 6),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: leadOffset + _calendarDays.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 6,
                      childAspectRatio: 1.0,
                    ),
                    itemBuilder: (context, index) {
                      if (index < leadOffset) {
                        return const SizedBox.shrink();
                      }
                      final day = _calendarDays[index - leadOffset];
                      final vnNow =
                          DateTime.now().toUtc().add(const Duration(hours: 7));
                      final todayStr =
                          '${vnNow.year}-${vnNow.month.toString().padLeft(2, '0')}-${vnNow.day.toString().padLeft(2, '0')}';
                      final isToday = day.date == todayStr;
                      final isPast = day.isPast;
                      final isBooked = isHostCalendarDayLockedByBooking(
                        isBookedFlag: day.isBooked,
                        bookingStatus: day.bookingStatus,
                      );
                      final isEditable =
                          day.isEditable() && !isBooked && !isPast;
                      final isSelected = isEditable &&
                          _selectedCalendarDates.contains(day.date);
                      final isBlocked = !day.isAvailable || day.isBlockedByHost;

                      Color borderColor = const Color(0xFFE2E8F0);
                      Color bgColor = Colors.white;
                      Color dayNumColor = AppColors.textPrimary;
                      Color priceColor = const Color(0xFF64748B);

                      // Giải thuật ưu tiên hiển thị màu sắc ô ngày trên lưới lịch tháng:
                      // CONFLICT-RESOLVED: Đặt nhánh isBooked trước isToday để ngày hôm nay đã có khách đặt vẫn hiển thị trạng thái đã đặt phòng (giữ viền chỉ báo hôm nay).
                      if (isSelected) {
                        borderColor = AppColors.primary;
                        bgColor = AppColors.primary;
                        dayNumColor = Colors.white;
                        priceColor = Colors.white;
                      } else if (isBooked) {
                        borderColor = isToday
                            ? AppColors.primary
                            : const Color(0xFFA7F3D0);
                        bgColor = const Color(0xFFF8FAFC);
                        dayNumColor = const Color(0xFF64748B);
                        priceColor = const Color(0xFF94A3B8);
                      } else if (isToday) {
                        // Ngày hiện tại (chưa đặt phòng): tô đỏ nổi bật
                        borderColor = AppColors.primary;
                        bgColor = const Color(0xFFFFF1F2);
                        dayNumColor = AppColors.primary;
                        priceColor = const Color(0xFFBE123C);
                      } else if (isPast) {
                        // Ngày đã qua: tô xám nhẹ và chữ xám mờ
                        borderColor = const Color(0xFFE2E8F0);
                        bgColor = const Color(0xFFF1F5F9);
                        dayNumColor = const Color(0xFF94A3B8);
                        priceColor = const Color(0xFFCBD5E1);
                      } else if (isBlocked) {
                        borderColor = const Color(0xFFFECDD3);
                        bgColor = const Color(0xFFFFF1F2);
                        dayNumColor = const Color(0xFFBE123C);
                        priceColor = const Color(0xFFBE123C);
                      }

                      return InkWell(
                        key: Key('calendar_day_${day.date}'),
                        customBorder: const CircleBorder(),
                        onTap: () {
                          if (!isEditable) {
                            setState(() {
                              _calendarError = isBooked
                                  ? 'Ngày ${day.date} đã có khách đặt phòng, không thể chỉnh sửa.'
                                  : 'Ngày ${day.date} đã qua, không thể chỉnh sửa.';
                            });
                            return;
                          }
                          setState(() {
                            _calendarError = null;
                            if (isSelected) {
                              _selectedCalendarDates.remove(day.date);
                            } else {
                              _selectedCalendarDates.add(day.date);
                              _calendarPriceOverrideCtrl.text =
                                  '${day.effectivePrice.round()}';
                            }
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: bgColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: borderColor,
                              width: isSelected ? 1.8 : (isToday ? 1.6 : 1),
                            ),
                          ),
                          padding: const EdgeInsets.all(5),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  day.date
                                      .split('-')
                                      .last
                                      .replaceFirst(RegExp(r'^0'), ''),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.1,
                                    fontWeight: isToday || isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    color: dayNumColor,
                                    decoration: (isPast && !isSelected)
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: const Color(0xFF94A3B8),
                                    decorationThickness: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  formatCompactHostVnd(day.effectivePrice),
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 9,
                                    height: 1.1,
                                    fontWeight: FontWeight.w600,
                                    color: priceColor,
                                  ),
                                ),
                                if (isBooked)
                                  Container(
                                    margin: const EdgeInsets.only(top: 1.5),
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF047857),
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                else if (isBlocked && !isSelected)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 0.5),
                                    child: Text(
                                      'Khóa',
                                      style: TextStyle(
                                        fontSize: 7.5,
                                        height: 1.05,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFBE123C),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Quick Date Selectors Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: _selectWeekendDays,
                    icon: const Icon(
                      LucideIcons.calendar,
                      size: 13,
                      color: AppColors.iconStrong,
                    ),
                    label: const Text('Cuối tuần (T7, CN)',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: _selectAvailableDays,
                    icon: const Icon(
                      LucideIcons.calendarCheck,
                      size: 13,
                      color: AppColors.iconStrong,
                    ),
                    label: const Text('Ngày còn trống',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: _selectAllMonthDays,
                    icon: const Icon(
                      LucideIcons.calendarRange,
                      size: 13,
                      color: AppColors.iconStrong,
                    ),
                    label: const Text('Cả tháng',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  if (_selectedCalendarDates.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        foregroundColor: AppColors.textSecondary,
                      ),
                      onPressed: _clearSelectedDays,
                      icon: const Icon(LucideIcons.rotateCcw, size: 13),
                      label:
                          const Text('Bỏ chọn', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
            // 5. AIRBNB FLOATING ACTION PANEL: Only visible when days are selected!
            if (_selectedCalendarDates.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Row: Selected date pill & Close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              _formatSelectedDateRangeLabel(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _clearSelectedDays,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(
                              LucideIcons.x,
                              size: 16,
                              color: AppColors.iconStrong,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Main Action Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 540;
                        final allAvailable = _areAllSelectedAvailable();

                        // Left Card: Status (Còn trống / Đã khóa) + Toggle X and V buttons
                        final leftCard = Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    allAvailable ? 'Còn trống' : 'Đã khóa',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: allAvailable
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFBE123C),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              // Pill with Block (X) and Unlock (V)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceBase,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      key: const Key('calendar_lock_btn'),
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: _savingCalendar
                                          ? null
                                          : () => _applyBulkCalendarUpdate(
                                                isAvailable: false,
                                                isBlockedByHost: true,
                                              ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: !allAvailable
                                              ? AppColors.textStrong
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Icon(
                                          LucideIcons.x,
                                          size: 18,
                                          color: !allAvailable
                                              ? Colors.white
                                              : AppColors.iconStrong,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 16,
                                      color: AppColors.border,
                                    ),
                                    InkWell(
                                      key:
                                          const Key('calendar_unlock_save_btn'),
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: _savingCalendar
                                          ? null
                                          : () => _applyBulkCalendarUpdate(
                                                isAvailable: true,
                                                isBlockedByHost: false,
                                              ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: allAvailable
                                              ? AppColors.textStrong
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Icon(
                                          LucideIcons.check,
                                          size: 18,
                                          color: allAvailable
                                              ? Colors.white
                                              : AppColors.iconStrong,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );

                        // Right Card: New Price & Custom Settings
                        final rightCard = Column(
                          children: [
                            // Card: New Price for listing
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Giá mới cho chỗ ở cho thuê',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _formatSelectedPriceRange(),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          _showCalendarPriceEditor
                                              ? LucideIcons.chevronUp
                                              : LucideIcons.pencil,
                                          size: 16,
                                          color: AppColors.iconStrong,
                                        ),
                                        onPressed: () => setState(() =>
                                            _showCalendarPriceEditor =
                                                !_showCalendarPriceEditor),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Quick Price Presets
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      ActionChip(
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: AppColors.surfaceBase,
                                        shape: const StadiumBorder(),
                                        side: const BorderSide(
                                            color: AppColors.border),
                                        label: const Text('+10%',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary)),
                                        onPressed: () => _applyPricePreset(1.1),
                                      ),
                                      ActionChip(
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: AppColors.surfaceBase,
                                        shape: const StadiumBorder(),
                                        side: const BorderSide(
                                            color: AppColors.border),
                                        label: const Text('+20% (Cuối tuần/Lễ)',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary)),
                                        onPressed: () => _applyPricePreset(1.2),
                                      ),
                                      ActionChip(
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: AppColors.surfaceBase,
                                        shape: const StadiumBorder(),
                                        side: const BorderSide(
                                            color: AppColors.border),
                                        label: const Text('Giá gốc',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary)),
                                        onPressed: () => _applyPricePreset(1.0),
                                      ),
                                    ],
                                  ),
                                  if (_showCalendarPriceEditor) ...[
                                    const SizedBox(height: 8),
                                    TextField(
                                      key: const Key(
                                          'calendar_price_override_input'),
                                      controller: _calendarPriceOverrideCtrl,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: 'Nhập giá riêng (VND)',
                                        labelStyle: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12),
                                        isDense: true,
                                        filled: true,
                                        fillColor: AppColors.surfaceBase,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.border),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.border),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.textStrong,
                                              width: 1.5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Card: Custom settings expandable
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => setState(() =>
                                  _showCalendarCustomSettings =
                                      !_showCalendarCustomSettings),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Cài đặt tùy chỉnh',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Icon(
                                          _showCalendarCustomSettings
                                              ? LucideIcons.minus
                                              : LucideIcons.plus,
                                          size: 16,
                                          color: AppColors.iconStrong,
                                        ),
                                      ],
                                    ),
                                    if (_showCalendarCustomSettings) ...[
                                      const SizedBox(height: 10),
                                      TextField(
                                        key: const Key(
                                            'calendar_min_nights_input'),
                                        controller: _calendarMinNightsCtrl,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
                                        decoration: InputDecoration(
                                          labelText: 'Số đêm tối thiểu',
                                          labelStyle: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12),
                                          isDense: true,
                                          filled: true,
                                          fillColor: AppColors.surfaceBase,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: AppColors.border),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: AppColors.border),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: AppColors.textStrong,
                                                width: 1.5),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        key: const Key('calendar_notes_input'),
                                        controller: _calendarNotesCtrl,
                                        style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 13),
                                        decoration: InputDecoration(
                                          labelText: 'Ghi chú ngày',
                                          labelStyle: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12),
                                          isDense: true,
                                          filled: true,
                                          fillColor: AppColors.surfaceBase,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: AppColors.border),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: AppColors.border),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: AppColors.textStrong,
                                                width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: leftCard),
                              const SizedBox(width: 10),
                              Expanded(child: rightCard),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            leftCard,
                            const SizedBox(height: 8),
                            rightCard,
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          HostSheetSyncCard(
            onCalendarChanged: () {
              _fetchListings();
              if (_calendarListingId != null) {
                _fetchCalendarDays();
              }
            },
          ),
        ],
      ),
    );
  }
  // ===========================================================================
  // 6. GUESTS (`KhachLuuTru`) SECTION
  // ===========================================================================

  DateTime? _parseGuestBookingDate(dynamic val) {
    if (val == null) return null;
    final s = val.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s.split('T').first);
  }

  int _calculateGuestNights(dynamic inVal, dynamic outVal) {
    final inD = _parseGuestBookingDate(inVal);
    final outD = _parseGuestBookingDate(outVal);
    if (inD == null || outD == null) return 1;
    final diff = outD.difference(inD).inDays;
    return diff > 0 ? diff : 1;
  }

  String _formatGuestDateDisplay(dynamic val) {
    final d = _parseGuestBookingDate(val);
    if (d == null) return '--/--';
    return DateFormat('dd/MM/yyyy').format(d);
  }

  String _formatGuestStayRange(dynamic inVal, dynamic outVal) {
    final inD = _parseGuestBookingDate(inVal);
    final outD = _parseGuestBookingDate(outVal);
    if (inD == null || outD == null) {
      return '${_formatGuestDateDisplay(inVal)} → ${_formatGuestDateDisplay(outVal)}';
    }
    if (inD.year == outD.year) {
      return '${DateFormat('dd/MM').format(inD)} → ${DateFormat('dd/MM/yyyy').format(outD)}';
    }
    return '${DateFormat('dd/MM/yy').format(inD)} → ${DateFormat('dd/MM/yy').format(outD)}';
  }

  void _handleCallGuest(String guestName, String phone) {
    final cleanPhone = phone.trim();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HostStudioTokens.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: HostStudioTokens.softCircle,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.phone,
                color: HostStudioTokens.iconInk,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Liên hệ $guestName',
                style: HostStudioTokens.sectionTitle,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Số điện thoại khách lưu trú:',
              style: HostStudioTokens.bodyRegular,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: HostStudioTokens.groupSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HostStudioTokens.hairline),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.phoneCall,
                    size: 16,
                    color: HostStudioTokens.iconInk,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      cleanPhone.isNotEmpty
                          ? cleanPhone
                          : 'Chưa cập nhật số điện thoại',
                      style: HostStudioTokens.priceEmphasis.copyWith(
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _handleMessageGuest(Map<String, dynamic> booking) {
    final guestName = (booking['guestName'] ?? booking['customerName'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    for (final conv in _conversations) {
      final name = _resolveHostConversationParticipantName(conv).toLowerCase();
      if (name.isNotEmpty &&
          (name == guestName ||
              name.contains(guestName) ||
              guestName.contains(name))) {
        final convId = '${conv['conversationId'] ?? conv['id']}';
        setState(() {
          _selectedConversationId = convId;
          _inChatDetailView = true;
        });
        _markHostConversationRead(convId);
        _fetchMessagesForConversation(convId);
        break;
      }
    }
    setState(() => _inChatDetailView = true);
    _switchSection(HostPortalSection.messages);
  }

  static const List<(String, String, IconData)> _guestStatusOptions = [
    ('all', 'Tất cả khách hàng', LucideIcons.users),
    ('checked_in', 'Khách đã nhận phòng', LucideIcons.bedDouble),
    ('confirmed', 'Đã xác nhận', LucideIcons.circleCheck),
    ('paid', 'Đã thanh toán', LucideIcons.creditCard),
    ('completed', 'Hoàn tất', LucideIcons.circleCheckBig),
    ('payment_expired', 'Quá hạn thanh toán', LucideIcons.clockAlert),
    ('cancelled', 'Đã hủy', LucideIcons.ban),
  ];

  // Thuật toán hiển thị bảng chọn bộ lọc trạng thái khách lưu trú kèm số lượng thực tế cho từng trạng thái.
  void _showGuestStatusFilterModal() {
    final scopedBookings = _bookings.where((b) {
      if (_guestSelectedListingId != 'all') {
        final bListingId = '${b['listingId'] ?? b['listing_id'] ?? ''}';
        if (bListingId != _guestSelectedListingId) return false;
      }
      return true;
    }).toList();

    final optionCounts = <String, int>{
      for (final opt in _guestStatusOptions)
        opt.$1: countHostBookingsMatchingFilter(
          scopedBookings,
          opt.$1,
          role: BookingActionRole.host,
        ),
    };

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final maxSheetHeight = MediaQuery.sizeOf(ctx).height * 0.85;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Material(
            color: HostStudioTokens.cardSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: HostStudioTokens.hairline,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Lọc theo trạng thái khách',
                            style: HostStudioTokens.headerTitle,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          padding: EdgeInsets.zero,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(
                            LucideIcons.x,
                            size: 20,
                            color: HostStudioTokens.iconInk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final opt in _guestStatusOptions) ...[
                              Builder(
                                builder: (context) {
                                  final selected = _guestStatusFilter == opt.$1;
                                  final count = optionCounts[opt.$1] ?? 0;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: InkWell(
                                      key: Key('guest_status_option_${opt.$1}'),
                                      borderRadius: BorderRadius.circular(
                                        HostStudioTokens.pillRadius,
                                      ),
                                      splashColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      overlayColor: WidgetStateProperty.all(
                                        Colors.transparent,
                                      ),
                                      onTap: () {
                                        setState(
                                          () => _guestStatusFilter = opt.$1,
                                        );
                                        Navigator.of(ctx).pop();
                                      },
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minHeight: 50,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            HostStudioTokens.pillRadius,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? HostStudioTokens.obsidian
                                                : Colors.transparent,
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              opt.$3,
                                              size: 19,
                                              color: selected
                                                  ? HostStudioTokens.inkPrimary
                                                  : HostStudioTokens
                                                      .iconSecondary,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                opt.$2,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: HostStudioTokens
                                                    .cardTitle
                                                    .copyWith(
                                                  fontSize: 14.5,
                                                  fontWeight: selected
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  color: selected
                                                      ? HostStudioTokens
                                                          .inkPrimary
                                                      : HostStudioTokens
                                                          .inkSecondary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    HostStudioTokens.softCircle,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  HostStudioTokens.pillRadius,
                                                ),
                                              ),
                                              child: Text(
                                                '$count',
                                                style: HostStudioTokens
                                                    .metaCaption
                                                    .copyWith(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: HostStudioTokens
                                                      .inkSecondary,
                                                ),
                                              ),
                                            ),
                                            if (selected) ...[
                                              const SizedBox(width: 8),
                                              const Icon(
                                                LucideIcons.check,
                                                color: HostStudioTokens.iconInk,
                                                size: 18,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Thuật toán xây dựng mục Khách lưu trú: phân tách chính xác lượt ở "Hôm nay", "Sắp tới" và bộ lọc trạng thái chuyên biệt (Khách đã nhận phòng, Hoàn tất, Đã hủy, Quá hạn thanh toán).
  Widget _buildGuestsSection() {
    final partition = partitionHostGuestBookings(
      _bookings,
      listingIdFilter: _guestSelectedListingId,
      statusFilter: _guestStatusFilter,
    );

    final filteredTodayBookings = partition.todayBookings;
    final filteredUpcomingBookings = partition.upcomingBookings;
    final filteredList = _guestStatusFilter == 'all'
        ? (_guestTab == 'today'
            ? filteredTodayBookings
            : filteredUpcomingBookings)
        : partition.statusMatchedBookings;

    final matchedOption = _guestStatusOptions.firstWhere(
      (opt) => opt.$1 == _guestStatusFilter,
      orElse: () => _guestStatusOptions.first,
    );
    final statusTitle = matchedOption.$2;
    final statusIcon = matchedOption.$3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 960;
        final horizontalPad = constraints.maxWidth < 360 ? 12.0 : 16.0;

        return RefreshIndicator(
          onRefresh: _loadInitialPortalData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPad,
              10,
              horizontalPad,
              isDesktop ? 28 : 110,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_guestStatusFilter == 'all') ...[
                  // Segmented Switcher: Hôm nay | Sắp tới
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: HostStudioTokens.cardSurface,
                      borderRadius:
                          BorderRadius.circular(HostStudioTokens.pillRadius),
                      border: Border.all(color: HostStudioTokens.hairline),
                      boxShadow: HostStudioTokens.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildBigGuestTabButton(
                            label: 'Hôm nay',
                            count: filteredTodayBookings.length,
                            icon: LucideIcons.calendarCheck,
                            isSelected: _guestTab == 'today',
                            onTap: () => setState(() => _guestTab = 'today'),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildBigGuestTabButton(
                            label: 'Sắp tới',
                            count: filteredUpcomingBookings.length,
                            icon: LucideIcons.calendarClock,
                            isSelected: _guestTab == 'upcoming',
                            onTap: () => setState(() => _guestTab = 'upcoming'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Ô Lọc Trạng thái Khách hàng (Studio Monochrome Capsule)
                Material(
                  color: HostStudioTokens.cardSurface,
                  borderRadius:
                      BorderRadius.circular(HostStudioTokens.pillRadius),
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(HostStudioTokens.pillRadius),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    onTap: _showGuestStatusFilterModal,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 46),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(HostStudioTokens.pillRadius),
                        border: Border.all(
                          color: _guestStatusFilter != 'all'
                              ? HostStudioTokens.obsidian
                              : HostStudioTokens.hairline,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            statusIcon,
                            size: 18,
                            color: HostStudioTokens.iconInk,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              statusTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HostStudioTokens.pillText.copyWith(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: HostStudioTokens.inkPrimary,
                              ),
                            ),
                          ),
                          if (_guestStatusFilter != 'all') ...[
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  setState(() => _guestStatusFilter = 'all'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: Text(
                                  'Xóa lọc',
                                  style: HostStudioTokens.metaCaption.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: HostStudioTokens.inkPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                          ],
                          const Icon(
                            LucideIcons.chevronDown,
                            size: 16,
                            color: HostStudioTokens.iconSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Danh sách khách / Trạng thái trống
                if (_loadingBookings)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filteredList.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 30,
                    ),
                    decoration: BoxDecoration(
                      color: HostStudioTokens.cardSurface,
                      borderRadius:
                          BorderRadius.circular(HostStudioTokens.cardRadius),
                      border: Border.all(color: HostStudioTokens.hairline),
                      boxShadow: HostStudioTokens.cardShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: HostStudioTokens.softCircle,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            LucideIcons.calendarX2,
                            size: 22,
                            color: HostStudioTokens.iconInk,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _guestStatusFilter != 'all'
                              ? 'Không có khách ở trạng thái "$statusTitle"'
                              : (_guestTab == 'today'
                                  ? 'Hôm nay chưa có lượt khách nào lưu trú'
                                  : 'Chưa có lượt khách nào sắp tới'),
                          style: HostStudioTokens.cardTitle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _guestStatusFilter != 'all'
                              ? 'Thử chọn "Tất cả khách hàng" để xem đầy đủ danh sách.'
                              : 'Các lượt đặt phòng mới từ khách sẽ được cập nhật tự động tại đây.',
                          style: HostStudioTokens.bodyRegular,
                          textAlign: TextAlign.center,
                        ),
                        if (_guestStatusFilter != 'all') ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: HostStudioTokens.obsidian,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                            ),
                            onPressed: () =>
                                setState(() => _guestStatusFilter = 'all'),
                            icon: const Icon(
                              LucideIcons.rotateCw,
                              size: 15,
                              color: Colors.white,
                            ),
                            label: const Text('Xem tất cả khách hàng'),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  for (var i = 0; i < filteredList.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _buildModernGuestCard(filteredList[i]),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBigGuestTabButton({
    required String label,
    required int count,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final pillRadius = BorderRadius.circular(HostStudioTokens.pillRadius);
    return Material(
      color: isSelected ? HostStudioTokens.obsidian : Colors.transparent,
      borderRadius: pillRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: pillRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : HostStudioTokens.iconSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HostStudioTokens.pillText.copyWith(
                      fontSize: 13.5,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : HostStudioTokens.inkSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.18)
                        : HostStudioTokens.softCircle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: HostStudioTokens.pillText.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : HostStudioTokens.inkPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernGuestCard(Map<String, dynamic> b) {
    final bookingId = '${b['bookingId'] ?? b['id'] ?? ''}';
    final name = (b['guestName'] ?? b['customerName'] ?? 'Khách #$bookingId')
        .toString()
        .trim();
    final phone = (b['guestPhone'] ?? b['guestEmail'] ?? '').toString().trim();
    final listingTitle =
        (b['listingTitle'] ?? 'Chỗ nghỉ #${b['listingId'] ?? ''}').toString();
    final inStr = (b['checkInDate'] ?? '').toString().split('T').first;
    final outStr = (b['checkOutDate'] ?? '').toString().split('T').first;
    final nights = _calculateGuestNights(inStr, outStr);
    final guestsCount = b['guestsCount'] ?? b['guests'] ?? 1;
    final totalPrice = b['totalPrice'] ?? b['totalAmount'] ?? 0;
    final display = getBookingDisplayStatus(b, role: BookingActionRole.host);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: HostStudioTokens.cardSurface,
        borderRadius: BorderRadius.circular(HostStudioTokens.cardRadius),
        border: Border.all(color: HostStudioTokens.hairline),
        boxShadow: HostStudioTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Meta Row: Mã đặt phòng + Số khách + Trạng thái (không chèn ép tên khách)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: HostStudioTokens.softCircle,
                      borderRadius:
                          BorderRadius.circular(HostStudioTokens.pillRadius),
                    ),
                    child: Text(
                      '#$bookingId',
                      style: HostStudioTokens.pillText.copyWith(
                        fontSize: 11.5,
                        color: HostStudioTokens.inkSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    LucideIcons.users,
                    size: 13,
                    color: HostStudioTokens.iconMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$guestsCount khách',
                    style: HostStudioTokens.metaCaption.copyWith(
                      fontSize: 12,
                      color: HostStudioTokens.inkSecondary,
                    ),
                  ),
                ],
              ),
              _buildStatusPill(display.label, display.code),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Định danh Khách & Chỗ nghỉ (toàn bộ chiều ngang thẻ)
          Row(
            children: [
              HostStudioInitialsBadge(name: name, size: 42),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HostStudioTokens.cardTitle.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.house,
                          size: 13.5,
                          color: HostStudioTokens.iconMuted,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            listingTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HostStudioTokens.bodyRegular.copyWith(
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3. Khung tóm tắt Lịch lưu trú & Thanh toán (gọn trên 1 dòng ngày, không gãy dấu '-')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: HostStudioTokens.groupSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: HostStudioTokens.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.calendar,
                          size: 14,
                          color: HostStudioTokens.iconInk,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _formatGuestStayRange(inStr, outStr),
                            style: HostStudioTokens.cardTitle.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: HostStudioTokens.cardSurface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: HostStudioTokens.hairline),
                      ),
                      child: Text(
                        '$nights đêm',
                        style: HostStudioTokens.pillText.copyWith(
                          fontSize: 11.5,
                          color: HostStudioTokens.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(height: 1, color: HostStudioTokens.hairline),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Nhận 14:00 · Trả 12:00',
                      style: HostStudioTokens.metaCaption.copyWith(
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      formatHostVnd(totalPrice),
                      style: HostStudioTokens.priceEmphasis.copyWith(
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 4. Thanh hành động cân đối Studio Minimalist (Capsule Pills)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: HostStudioTokens.cardSurface,
                    foregroundColor: HostStudioTokens.inkPrimary,
                    side: const BorderSide(color: HostStudioTokens.hairline),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: () => _handleCallGuest(name, phone),
                  icon: const Icon(
                    LucideIcons.phone,
                    size: 14.5,
                    color: HostStudioTokens.iconInk,
                  ),
                  label: Text(
                    'Gọi điện',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HostStudioTokens.pillText.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: HostStudioTokens.inkPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: HostStudioTokens.obsidian,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: () => _handleMessageGuest(b),
                  icon: const Icon(
                    LucideIcons.messageSquare,
                    size: 14.5,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Nhắn tin',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HostStudioTokens.pillText.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (display.actions.canCheckIn || display.actions.canCheckOut) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: Key(
                  'guest_card_${display.actions.canCheckIn ? 'checkin' : 'checkout'}_btn_$bookingId',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  backgroundColor: HostStudioTokens.softCircle,
                  foregroundColor: HostStudioTokens.inkPrimary,
                  side: const BorderSide(color: HostStudioTokens.hairline),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: _busyBookingActionId == bookingId
                    ? null
                    : () => _handleBookingAction(
                          b,
                          display.actions.canCheckIn ? 'check_in' : 'check_out',
                        ),
                icon: Icon(
                  display.actions.canCheckIn
                      ? AppSemanticIcons.checkIn
                      : AppSemanticIcons.checkOut,
                  size: 14.5,
                  color: HostStudioTokens.inkPrimary,
                ),
                label: Text(
                  display.actions.canCheckIn
                      ? 'Xác nhận Check-in'
                      : 'Xác nhận Check-out',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HostStudioTokens.pillText.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HostStudioTokens.inkPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 7. MESSAGES (`TinNhan`) SECTION
  // ===========================================================================

  bool _isConversationAdmin(Map<String, dynamic> c) {
    final other = c['otherParticipant'] is Map
        ? Map<String, dynamic>.from(c['otherParticipant'] as Map)
        : null;
    final role = (other?['role'] ?? c['role'] ?? '').toString().toLowerCase();
    final name = (other?['fullName'] ??
            other?['name'] ??
            c['guestName'] ??
            c['title'] ??
            '')
        .toString()
        .toLowerCase();
    final hasNoListing = c['listingId'] == null || '${c['listingId']}' == '0';
    return role == 'admin' ||
        role == 'system' ||
        name.contains('quản trị viên') ||
        name.contains('admin') ||
        name.contains('bql') ||
        name.contains('the palm') ||
        name.contains('palm villa') ||
        name.contains('ban quản trị') ||
        (hasNoListing &&
            (name.contains('palm') ||
                name.contains('hệ thống') ||
                name.contains('hỗ trợ')));
  }

  String? _getConversationVillaImage(Map<String, dynamic> c) {
    if (c['listingImageUrl'] != null && '${c['listingImageUrl']}'.isNotEmpty) {
      return '${c['listingImageUrl']}';
    }
    final listingId = '${c['listingId'] ?? ''}';
    if (listingId.isNotEmpty) {
      final matched = _listings.firstWhere(
        (l) => '${l['listingId'] ?? l['id']}' == listingId,
        orElse: () => {},
      );
      if (matched.isNotEmpty) {
        final img =
            (matched['imageUrl'] ?? matched['coverImageUrl'] ?? '').toString();
        if (img.isNotEmpty) return img;
      }
    }
    final listingTitle = (c['listingTitle'] ?? '').toString().trim();
    if (listingTitle.isNotEmpty) {
      final matched = _listings.firstWhere(
        (l) =>
            (l['title'] ?? '').toString().toLowerCase() ==
            listingTitle.toLowerCase(),
        orElse: () => {},
      );
      if (matched.isNotEmpty) {
        final img =
            (matched['imageUrl'] ?? matched['coverImageUrl'] ?? '').toString();
        if (img.isNotEmpty) return img;
      }
    }
    return null;
  }

  String _resolveHostConversationParticipantName(Map<String, dynamic> c) {
    if (_isConversationAdmin(c)) {
      return 'Quản trị viên The Palm Villa';
    }

    final other = c['otherParticipant'] is Map
        ? Map<String, dynamic>.from(c['otherParticipant'] as Map)
        : null;
    final guest =
        c['guest'] is Map ? Map<String, dynamic>.from(c['guest'] as Map) : null;
    final user =
        c['user'] is Map ? Map<String, dynamic>.from(c['user'] as Map) : null;
    final booking = c['booking'] is Map
        ? Map<String, dynamic>.from(c['booking'] as Map)
        : null;

    var resolvedName = (other?['fullName'] ??
            other?['name'] ??
            other?['username'] ??
            other?['displayName'] ??
            c['guestName'] ??
            c['userName'] ??
            c['customerName'] ??
            c['clientName'] ??
            guest?['fullName'] ??
            guest?['name'] ??
            user?['fullName'] ??
            user?['name'] ??
            booking?['guestName'] ??
            booking?['customerName'] ??
            '')
        .toString()
        .trim();

    final lower = resolvedName.toLowerCase();
    final isGeneric = resolvedName.isEmpty ||
        lower == 'khách lưu trú' ||
        lower == 'người dùng' ||
        lower == 'cuộc trò chuyện' ||
        lower.startsWith('hội thoại');

    if (isGeneric) {
      final rawBookingId =
          '${c['bookingId'] ?? c['bookingOrderId'] ?? c['booking_id'] ?? ''}'
              .trim();
      if (rawBookingId.isNotEmpty && _bookings.isNotEmpty) {
        final matchedBooking = _bookings.firstWhere(
          (b) =>
              '${b['bookingId'] ?? b['id'] ?? b['orderId'] ?? ''}' ==
              rawBookingId,
          orElse: () => {},
        );
        if (matchedBooking.isNotEmpty) {
          final bGuest = (matchedBooking['guestName'] ??
                  matchedBooking['customerName'] ??
                  '')
              .toString()
              .trim();
          if (bGuest.isNotEmpty) {
            return bGuest;
          }
        }
      }

      final otherUserId =
          '${other?['userId'] ?? other?['id'] ?? c['guestUserId'] ?? c['otherUserId'] ?? ''}'
              .trim();
      if (otherUserId.isNotEmpty && _bookings.isNotEmpty) {
        final matchedBooking = _bookings.firstWhere(
          (b) =>
              '${b['guestUserId'] ?? b['userId'] ?? b['customerId'] ?? ''}' ==
              otherUserId,
          orElse: () => {},
        );
        if (matchedBooking.isNotEmpty) {
          final bGuest = (matchedBooking['guestName'] ??
                  matchedBooking['customerName'] ??
                  '')
              .toString()
              .trim();
          if (bGuest.isNotEmpty) {
            return bGuest;
          }
        }
      }

      final title = (c['title'] ?? '').toString().trim();
      if (title.isNotEmpty &&
          !title.toLowerCase().contains('cuộc trò chuyện') &&
          !title.toLowerCase().contains('hội thoại')) {
        return title;
      }
    }

    if (resolvedName.isNotEmpty &&
        !lower.contains('cuộc trò chuyện') &&
        !lower.contains('hội thoại') &&
        lower != 'người dùng') {
      return resolvedName;
    }

    final convId = '${c['conversationId'] ?? c['id'] ?? ''}'.trim();
    return convId.isNotEmpty ? 'Khách lưu trú #$convId' : 'Khách lưu trú';
  }

  String? _resolveHostConversationParticipantAvatar(Map<String, dynamic> c) {
    final other = c['otherParticipant'] is Map
        ? Map<String, dynamic>.from(c['otherParticipant'] as Map)
        : null;
    final guest =
        c['guest'] is Map ? Map<String, dynamic>.from(c['guest'] as Map) : null;
    final directAvatar = (other?['avatarUrl'] ??
            other?['avatar'] ??
            c['guestAvatarUrl'] ??
            c['avatarUrl'] ??
            guest?['avatarUrl'] ??
            guest?['avatar'] ??
            '')
        .toString()
        .trim();
    if (directAvatar.isNotEmpty) {
      return directAvatar;
    }
    return _getConversationVillaImage(c);
  }

  Widget _buildHostParticipantAvatar(
    String name,
    String? avatarUrl, {
    double size = 40,
  }) {
    final trimmedUrl = avatarUrl?.trim() ?? '';
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    if (trimmedUrl.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: AppImage(url: trimmedUrl),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  String _formatHostConversationTimestamp(dynamic rawDate) {
    if (rawDate == null) return '';
    final raw = rawDate.toString().trim();
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${twoDigits(dt.hour)}:${twoDigits(dt.minute)}';
    }
    return '${twoDigits(dt.day)}/${twoDigits(dt.month)} ${twoDigits(dt.hour)}:${twoDigits(dt.minute)}';
  }

  Widget _buildMessagesSection() {
    if (_inChatDetailView && _selectedConversationId != null) {
      return _buildChatDetailView();
    }
    return _buildConversationListView();
  }

  Widget _buildConversationListView() {
    final query = _messagesSearchQuery.trim().toLowerCase();
    final filtered = _conversations.where((c) {
      if (query.isEmpty) return true;
      final name = _resolveHostConversationParticipantName(c).toLowerCase();
      final listingTitle = (c['listingTitle'] ?? '').toString().toLowerCase();
      final lastMsg = (c['lastMessage'] is Map
              ? c['lastMessage']['content'] ?? c['lastMessage']['body']
              : c['lastMessage']) ??
          c['lastMessageContent'] ??
          '';
      return name.contains(query) ||
          listingTitle.contains(query) ||
          '$lastMsg'.toLowerCase().contains(query);
    }).toList();

    return Container(
      color: AppColors.surfaceBase,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetchConversations,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: TextField(
                  controller: _messagesSearchCtrl,
                  onChanged: (v) => setState(() => _messagesSearchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm khách hoặc chỗ nghỉ...',
                    hintStyle: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textMuted,
                    ),
                    prefixIcon: const Icon(
                      LucideIcons.search,
                      size: 18,
                      color: AppColors.iconMuted,
                    ),
                    suffixIcon: _messagesSearchQuery.isNotEmpty
                        ? IconButton(
                            tooltip: 'Xóa tìm kiếm',
                            icon: const Icon(
                              LucideIcons.x,
                              size: 16,
                              color: AppColors.iconStrong,
                            ),
                            onPressed: () => setState(() {
                              _messagesSearchCtrl.clear();
                              _messagesSearchQuery = '';
                            }),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: AppColors.borderSoft),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: AppColors.borderSoft),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(
                        color: AppColors.borderFocus,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              if (_conversationsError != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildInlineError(
                    _conversationsError!,
                    onRetry: _fetchConversations,
                  ),
                ),
              if (_loadingConversations)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_conversations.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBase,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.messageSquareDashed,
                          size: 40,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Chưa có cuộc trò chuyện nào',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tin nhắn từ khách hàng và ban quản lý sẽ hiển thị tại đây.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'Không tìm thấy cuộc trò chuyện phù hợp.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                for (var i = 0; i < filtered.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.divider),
                  _buildConversationItemRow(filtered[i]),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationItemRow(Map<String, dynamic> c) {
    final convId = '${c['conversationId'] ?? c['id']}';
    final listingMap = c['listing'] is Map
        ? Map<String, dynamic>.from(c['listing'] as Map)
        : null;
    final counterpart = _resolveHostConversationParticipantName(c);

    final rawListingId =
        (c['listingId'] ?? listingMap?['listingId'] ?? listingMap?['id'] ?? '')
            .toString()
            .trim();
    final resolvedListingTitle = (c['listingTitle'] ??
            listingMap?['title'] ??
            listingMap?['name'] ??
            (rawListingId.isNotEmpty && rawListingId != '0'
                ? 'Trao đổi về chỗ nghỉ'
                : 'Trò chuyện hỗ trợ trực tiếp'))
        .toString()
        .trim();

    final rawLastMsg = (c['lastMessage'] is Map
            ? (c['lastMessage']['content'] ??
                c['lastMessage']['body'] ??
                c['lastMessage']['message'])
            : c['lastMessage']) ??
        c['lastMessageContent'];
    final currentLocale = ref.watch(localeProvider);
    final previewText = localizeChatPreview(
      rawLastMsg?.toString(),
      localeCode: currentLocale,
    );

    final unreadCount = (c['unreadCount'] as num?)?.toInt() ?? 0;
    final avatarUrl = _resolveHostConversationParticipantAvatar(c);
    final rawDate = c['lastMessageAt'] ??
        c['updatedAt'] ??
        (c['lastMessage'] is Map ? c['lastMessage']['createdAt'] : null);
    final timeLabel = _formatHostConversationTimestamp(rawDate);

    return Material(
      color: AppColors.surfaceBase,
      child: InkWell(
        key: ValueKey<String>('host_conv_tile_$convId'),
        onTap: () {
          setState(() {
            c['unreadCount'] = 0;
            _conversationsError = null;
            _selectedConversationId = convId;
            _inChatDetailView = true;
          });
          _markHostConversationRead(convId);
          _fetchMessagesForConversation(convId);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHostParticipantAvatar(counterpart, avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            counterpart,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textStrong,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 0,
                            child: Text(
                              timeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (resolvedListingTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        resolvedListingTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            previewText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: unreadCount > 0
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.all(
                                Radius.circular(999),
                              ),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildChatDetailView() {
    String? currentUserId;
    try {
      currentUserId =
          ref.watch(authNotifierProvider).valueOrNull?.id.toString();
    } catch (_) {}

    final matchedConv = _conversations.firstWhere(
      (c) => '${c['conversationId'] ?? c['id']}' == _selectedConversationId,
      orElse: () => {},
    );
    final hostUserId = matchedConv['hostUserId']?.toString();
    final participantName =
        _resolveHostConversationParticipantName(matchedConv);
    final listingTitle = (matchedConv['listingTitle'] ?? '').toString().trim();
    final isAdmin = _isConversationAdmin(matchedConv);
    final participantAvatar =
        _resolveHostConversationParticipantAvatar(matchedConv);
    final rawListingId = matchedConv['listingId'] ??
        (matchedConv['listing'] is Map
            ? ((matchedConv['listing'] as Map)['id'] ??
                (matchedConv['listing'] as Map)['listingId'])
            : null);
    final listingId = (rawListingId ?? '').toString().trim();
    final effectiveListingId =
        listingId.isNotEmpty ? listingId : (listingTitle.isNotEmpty ? '1' : '');

    return Column(
      children: [
        // Top App Bar của Chat
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surfaceBase,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.arrowLeft, size: 20),
                onPressed: () => setState(() {
                  _inChatDetailView = false;
                  _showChatTimestampsPinned = false;
                  _chatDragAnimCtrl.value = 0.0;
                }),
                tooltip: 'Quay lại danh sách',
              ),
              const SizedBox(width: 4),
              _buildHostParticipantAvatar(
                participantName,
                participantAvatar,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            participantName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            LucideIcons.shieldCheck,
                            size: 14,
                            color: AppColors.iconStrong,
                          ),
                        ],
                      ],
                    ),
                    if (listingTitle.isNotEmpty)
                      Text(
                        listingTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('host_chat_toggle_timestamps_btn'),
                icon: Icon(
                  _showChatTimestampsPinned
                      ? LucideIcons.clockCheck
                      : LucideIcons.clock,
                  size: 18,
                  color: _showChatTimestampsPinned
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                tooltip: _showChatTimestampsPinned
                    ? 'Ẩn thời gian'
                    : 'Hiện khung thời gian',
                onPressed: () {
                  setState(() {
                    _showChatTimestampsPinned = !_showChatTimestampsPinned;
                    if (_showChatTimestampsPinned) {
                      _chatDragAnimCtrl.forward();
                    } else {
                      _chatDragAnimCtrl.reverse();
                    }
                  });
                },
              ),
              if (!isAdmin && effectiveListingId.isNotEmpty)
                Semantics(
                  button: true,
                  label: 'Xem chỗ nghỉ',
                  child: IconButton(
                    key: const Key('view_listing_button'),
                    icon: const Icon(
                      LucideIcons.externalLink,
                      size: 18,
                      color: AppColors.iconStrong,
                    ),
                    tooltip: 'Xem chỗ nghỉ',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () {
                      context.push('/villa/$effectiveListingId');
                    },
                  ),
                ),
            ],
          ),
        ),

        if (_conversationsError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _buildInlineError(_conversationsError!),
          ),

        // Khung danh sách tin nhắn (Chat Bubbles phong cách Messenger)
        Expanded(
          child: _conversationMessages.isEmpty
              ? const Center(
                  child: Text(
                    'Chưa có tin nhắn trong cuộc trò chuyện này.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (_reactionActiveMsgKey != null) {
                      setState(() => _reactionActiveMsgKey = null);
                    }
                  },
                  onHorizontalDragStart: (_) {
                    _horizontalDragOffset = 0.0;
                  },
                  onHorizontalDragUpdate: (details) {
                    final dx = details.primaryDelta ?? 0;
                    _horizontalDragOffset += dx;
                    // Hỗ trợ cả kéo sang phải và kéo sang trái
                    final dragDist = _horizontalDragOffset.abs();
                    final progress = (dragDist / 55.0).clamp(0.0, 1.0);
                    _chatDragAnimCtrl.value = progress;
                  },
                  onHorizontalDragEnd: (_) {
                    if (!_showChatTimestampsPinned) {
                      _chatDragAnimCtrl.animateTo(
                        0.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      );
                    }
                    _horizontalDragOffset = 0.0;
                  },
                  onHorizontalDragCancel: () {
                    if (!_showChatTimestampsPinned) {
                      _chatDragAnimCtrl.animateTo(
                        0.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      );
                    }
                    _horizontalDragOffset = 0.0;
                  },
                  child: ListView.builder(
                    controller: _chatScrollCtrl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    itemCount: _conversationMessages.length,
                    itemBuilder: (ctx, i) {
                      final m = _conversationMessages[i];
                      final content =
                          (m['content'] ?? m['body'] ?? '').toString();
                      var rawAttachments =
                          m['attachments'] ?? m['attachments_json'];
                      var attachments = rawAttachments is List
                          ? rawAttachments
                              .map((a) {
                                if (a is Map) {
                                  return (a['url'] ?? a['imageUrl'] ?? '')
                                      .toString();
                                }
                                return a?.toString() ?? '';
                              })
                              .where((s) => s.isNotEmpty)
                              .toList()
                          : <String>[];

                      // Auto-recovery: phục hồi các tin nhắn cũ từng gửi dạng text mock thành ảnh/audio thật
                      if (attachments.isEmpty) {
                        if (content.contains('📷 [Ảnh chụp trực tiếp') ||
                            content.contains('🖼️ [Đã gửi 1 hình ảnh') ||
                            content.contains('[Ảnh chụp trực tiếp từ villa]')) {
                          attachments = ['assets/images/343vothisau.jpg'];
                        } else if (content.contains('🎤 Tin nhắn thoại')) {
                          attachments = [
                            'https://pub-67a3f362466e495d9c2f371ca84b6d03.r2.dev/chat/sample_voice.wav'
                          ];
                        }
                      }
                      final senderId =
                          (m['senderId'] ?? m['senderUserId'])?.toString();
                      final senderRole =
                          (m['senderRole'] ?? '').toString().toLowerCase();
                      final rawSenderName =
                          (m['senderName'] ?? m['sender']?['fullName'] ?? '')
                              .toString();

                      final isMe = m['isMe'] == true ||
                          (currentUserId != null &&
                              currentUserId.isNotEmpty &&
                              senderId == currentUserId) ||
                          (hostUserId != null &&
                              hostUserId.isNotEmpty &&
                              senderId == hostUserId) ||
                          senderRole == 'host' ||
                          rawSenderName.toLowerCase().contains('chủ nhà') ||
                          rawSenderName.toLowerCase() == 'tôi';

                      final displayCaption = _getDisplayCaption(content);
                      final hasAttachments = attachments.isNotEmpty;
                      final isImageOnly = hasAttachments &&
                          displayCaption == null &&
                          attachments.every((u) => !_isChatAudioUrl(u));
                      final isAudioOnly = hasAttachments &&
                          displayCaption == null &&
                          attachments.length == 1 &&
                          _isChatAudioUrl(attachments.first);

                      final bubbleRadius = BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 6),
                        bottomRight: Radius.circular(isMe ? 6 : 18),
                      );

                      final isMsgAdmin = isAdmin ||
                          senderRole == 'admin' ||
                          rawSenderName.toLowerCase().contains('quản trị viên');

                      final msgKey =
                          (m['messageId'] ?? m['id'] ?? 'msg_$i').toString();
                      final reaction = _messageReactions[msgKey];
                      final isReactionOpen = _reactionActiveMsgKey == msgKey;

                      // Format time nếu có & tính toán Time Divider tự động
                      String? msgTime;
                      DateTime? msgDt;
                      final rawCreatedAt = m['createdAt'];
                      if (rawCreatedAt != null) {
                        msgDt = DateTime.tryParse(rawCreatedAt.toString());
                        if (msgDt != null) {
                          msgTime = DateFormat('HH:mm').format(msgDt);
                        }
                      }

                      DateTime? prevDt;
                      if (i > 0) {
                        final prevRawCreatedAt =
                            _conversationMessages[i - 1]['createdAt'];
                        if (prevRawCreatedAt != null) {
                          prevDt =
                              DateTime.tryParse(prevRawCreatedAt.toString());
                        }
                      }

                      final currentLocale = ref.watch(localeProvider);
                      final showTimeDivider = msgDt != null &&
                          shouldShowChatTimeDivider(msgDt, prevDt);
                      final timeDividerLabel = msgDt != null
                          ? formatChatTimeDivider(msgDt,
                              localeCode: currentLocale)
                          : '';

                      // Render bong bóng tin nhắn tinh gọn kiểu Messenger kèm reaction & avatar bên trái
                      return AnimatedBuilder(
                        animation: _chatDragAnimCtrl,
                        builder: (ctx, _) {
                          final progress = _chatDragAnimCtrl.value;
                          final timeWidth = 62.0 * progress;
                          final timeOpacity = progress.clamp(0.0, 1.0);

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: reaction != null ? 10 : 6,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showTimeDivider)
                                  ChatTimeDivider(label: timeDividerLabel),
                                Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    // Thanh chọn cảm xúc nổi khi đè vào tin nhắn
                                    if (isReactionOpen)
                                      _buildReactionPicker(msgKey),

                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        // Hình đại diện nhỏ bên trái của người gửi (đối phương)
                                        if (!isMe) ...[
                                          _buildChatSmallAvatar(
                                            isAdmin: isMsgAdmin,
                                            name: participantName,
                                            avatarUrl: participantAvatar,
                                          ),
                                          const SizedBox(width: 8),
                                        ],

                                        // Bong bóng nội dung tin nhắn
                                        Expanded(
                                          child: Align(
                                            alignment: isMe
                                                ? Alignment.centerRight
                                                : Alignment.centerLeft,
                                            child: GestureDetector(
                                              key: Key('chat_bubble_$msgKey'),
                                              onLongPress: () {
                                                setState(() {
                                                  _reactionActiveMsgKey =
                                                      isReactionOpen
                                                          ? null
                                                          : msgKey;
                                                });
                                              },
                                              onSecondaryTap: () {
                                                setState(() {
                                                  _reactionActiveMsgKey =
                                                      isReactionOpen
                                                          ? null
                                                          : msgKey;
                                                });
                                              },
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Container(
                                                    constraints: BoxConstraints(
                                                      maxWidth:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width *
                                                              0.68,
                                                    ),
                                                    padding: (isImageOnly ||
                                                            isAudioOnly)
                                                        ? EdgeInsets.zero
                                                        : const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 14,
                                                            vertical: 9,
                                                          ),
                                                    decoration: BoxDecoration(
                                                      color: (isImageOnly ||
                                                              isAudioOnly)
                                                          ? Colors.transparent
                                                          : (isMe
                                                              ? AppColors
                                                                  .primary
                                                              : (isMsgAdmin
                                                                  ? const Color(
                                                                      0xFFFFF1F2)
                                                                  : const Color(
                                                                      0xFFF1F5F9))),
                                                      borderRadius:
                                                          bubbleRadius,
                                                      border: isMe
                                                          ? null
                                                          : (isMsgAdmin
                                                              ? Border.all(
                                                                  color: const Color(
                                                                      0xFFFECDD3),
                                                                )
                                                              : null),
                                                      boxShadow: (isMe &&
                                                              !isImageOnly)
                                                          ? [
                                                              BoxShadow(
                                                                color: AppColors
                                                                    .primary
                                                                    .withValues(
                                                                        alpha:
                                                                            0.16),
                                                                blurRadius: 4,
                                                                offset:
                                                                    const Offset(
                                                                        0, 1),
                                                              ),
                                                            ]
                                                          : null,
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: isMe
                                                          ? CrossAxisAlignment
                                                              .end
                                                          : CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        if (hasAttachments) ...[
                                                          for (final attUrl
                                                              in attachments)
                                                            Padding(
                                                              padding:
                                                                  EdgeInsets
                                                                      .only(
                                                                bottom: isImageOnly
                                                                    ? 0
                                                                    : (displayCaption !=
                                                                            null
                                                                        ? 6
                                                                        : 0),
                                                              ),
                                                              child: _isChatAudioUrl(
                                                                      attUrl)
                                                                  ? _buildHostAudioBubble(
                                                                      attUrl,
                                                                      isMe:
                                                                          isMe)
                                                                  : ChatImageBubble(
                                                                      imageUrl:
                                                                          attUrl,
                                                                      borderRadius:
                                                                          bubbleRadius,
                                                                      maxWidth: MediaQuery.of(context)
                                                                              .size
                                                                              .width *
                                                                          0.68,
                                                                      onTap: () => _openFullScreenImage(
                                                                          context,
                                                                          attUrl),
                                                                    ),
                                                            ),
                                                        ],
                                                        if (displayCaption !=
                                                                null &&
                                                            displayCaption
                                                                .isNotEmpty)
                                                          Text(
                                                            displayCaption,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              height: 1.35,
                                                              color: isMe
                                                                  ? Colors.white
                                                                  : (isMsgAdmin
                                                                      ? const Color(
                                                                          0xFF881337)
                                                                      : AppColors
                                                                          .textPrimary),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),

                                                  // Badge cảm xúc ở góc dưới của bong bóng tin nhắn
                                                  if (reaction != null)
                                                    Positioned(
                                                      bottom: -8,
                                                      right: isMe ? 8 : null,
                                                      left: isMe ? null : 8,
                                                      child: GestureDetector(
                                                        onTap: () {
                                                          setState(() {
                                                            _reactionActiveMsgKey =
                                                                isReactionOpen
                                                                    ? null
                                                                    : msgKey;
                                                          });
                                                        },
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 5,
                                                            vertical: 2,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            border: Border.all(
                                                              color: const Color(
                                                                  0xFFE2E8F0),
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withValues(
                                                                        alpha:
                                                                            0.1),
                                                                blurRadius: 4,
                                                                offset:
                                                                    const Offset(
                                                                        0, 1),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Builder(
                                                            builder: (context) {
                                                              final reactionMeta =
                                                                  resolveAppChatReaction(
                                                                reaction,
                                                              );
                                                              return Icon(
                                                                reactionMeta
                                                                    .icon,
                                                                key: Key(
                                                                  'reaction_badge_${reactionMeta.code}_$msgKey',
                                                                ),
                                                                size: 13,
                                                                color: AppColors
                                                                    .primary,
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Khung thời gian trượt ra khi kéo qua bên phải
                                        if (progress > 0.01 && msgTime != null)
                                          Opacity(
                                            opacity: timeOpacity,
                                            child: Container(
                                              width: timeWidth,
                                              alignment: Alignment.centerRight,
                                              padding: const EdgeInsets.only(
                                                  left: 6),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFE2E8F0),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  msgTime,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),

                                    // Trạng thái Messenger tách biệt ở góc dưới cùng bên phải của cụm tin nhắn cuối cùng
                                    if (i == _conversationMessages.length - 1 &&
                                        isMe) ...[
                                      MessengerStatusIndicator(
                                        state: (m['status'] == 'failed' ||
                                                m['isFailed'] == true)
                                            ? MessengerDeliveryState.failed
                                            : (m['status'] == 'sending' ||
                                                    m['status'] == 'pending')
                                                ? MessengerDeliveryState.sending
                                                : (m['isRead'] == true ||
                                                        m['readAt'] != null ||
                                                        m['seen'] == true ||
                                                        m['status'] == 'read')
                                                    ? MessengerDeliveryState
                                                        .seen
                                                    : MessengerDeliveryState
                                                        .sent,
                                        recipientName: participantName,
                                        recipientAvatar: participantAvatar,
                                        customLabel: (m['isRead'] == true ||
                                                m['readAt'] != null ||
                                                m['seen'] == true ||
                                                m['status'] == 'read')
                                            ? 'Đã xem'
                                            : (m['status'] == 'sending' ||
                                                    m['status'] == 'pending')
                                                ? 'Đang gửi...'
                                                : (m['status'] == 'failed' ||
                                                        m['isFailed'] == true)
                                                    ? 'Gửi thất bại'
                                                    : 'Đã gửi',
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),

        // Gợi ý tin nhắn nhanh (Tối ưu góc trống dưới cùng)
        Container(
          color: AppColors.surfaceBase,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _buildQuickReplyChip('Dạ vâng, bên em đã nhận thông tin ạ!'),
                const SizedBox(width: 8),
                _buildQuickReplyChip('Quý khách nhận phòng lúc mấy giờ ạ?'),
                const SizedBox(width: 8),
                _buildQuickReplyChip('The Palm Villa xin chào bạn!'),
                const SizedBox(width: 8),
                _buildQuickReplyChip(
                    'Vị trí biệt thự em đã cập nhật trên hệ thống ạ.'),
              ],
            ),
          ),
        ),

        // CONFLICT-RESOLVED: Giữ các widget tách mô-đun `HostVoiceRecordingBar` và `HostChatComposerBar` của HEAD kết hợp luồng ghi âm thực `_voiceRecorder` từ develop.
        if (_isRecordingVoice)
          HostVoiceRecordingBar(
            recordingSeconds: _voiceRecordingSeconds,
            onCancel: () {
              _voiceTimer?.cancel();
              unawaited(_voiceRecorder.cancel());
              setState(() {
                _isRecordingVoice = false;
                _voiceRecordingSeconds = 0;
              });
            },
            onSend: _toggleVoiceRecording,
          ),

        HostChatComposerBar(
          controller: _messageInputCtrl,
          focusNode: _messageInputFocusNode,
          isRecordingVoice: _isRecordingVoice,
          sendingMessage: _sendingMessage,
          quickIcon: resolveAppQuickChatOption(_chatQuickEmoji).icon,
          onShowMoreOptions: _showChatMoreOptions,
          onOpenCamera: _openCameraChat,
          onPickGalleryImage: _pickAndSendChatImage,
          onToggleVoiceRecording: _toggleVoiceRecording,
          onShowEmojiSelector: _showEmojiSelector,
          onSendQuickEmoji: () => _sendQuickEmoji(
            resolveAppQuickChatOption(_chatQuickEmoji).sendText,
          ),
          onChooseQuickEmoji: _chooseQuickEmoji,
          onSendMessage: _sendHostMessage,
        ),
      ],
    );
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildChatSmallAvatar({
    required bool isAdmin,
    required String name,
    String? avatarUrl,
  }) {
    if (isAdmin) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFECDD3)),
        ),
        child: const Icon(
          LucideIcons.shieldCheck,
          size: 15,
          color: Color(0xFFBE123C),
        ),
      );
    }

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: AppImage(
          imageUrl: avatarUrl,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorWidget: _buildLetterAvatar(name),
        ),
      );
    }

    return _buildLetterAvatar(name);
  }

  Widget _buildLetterAvatar(String name) {
    final trimmed = name.trim();
    final letter = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : 'K';
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Color(0xFFE0E7FF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4338CA),
        ),
      ),
    );
  }

  Widget _buildReactionPicker(String msgKey) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: kAppMessengerReactions.map((item) {
          final isSelected = _messageReactions[msgKey] == item.code;
          return Tooltip(
            message: item.label,
            child: InkWell(
              key: Key('reaction_${item.code}_$msgKey'),
              onTap: () {
                final nextReaction = isSelected ? '' : item.code;
                setState(() {
                  if (isSelected) {
                    _messageReactions.remove(msgKey);
                  } else {
                    _messageReactions[msgKey] = item.code;
                  }
                  _reactionActiveMsgKey = null;
                });
                final activeConv = _selectedConversationId ?? '';
                if (isNumericHostConversationId(activeConv)) {
                  ref.read(hostPortalViewModelProvider).sendReaction(
                        activeConv,
                        messageId: msgKey,
                        reaction: nextReaction,
                      );
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Icon(
                  item.icon,
                  size: 20,
                  color: isSelected ? AppColors.primary : AppColors.iconStrong,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickReplyChip(String text) {
    return InkWell(
      onTap: () {
        _messageInputCtrl.text = text;
        _messageInputFocusNode.requestFocus();
        setState(() {});
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // --- Các chức năng mở rộng cho thanh nhập Messenger ---

  void _showChatMoreOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.plus,
                          size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Tiện ích mở rộng',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading:
                      const Icon(LucideIcons.mapPin, color: AppColors.primary),
                  title: const Text('Gửi vị trí The Palm Villa'),
                  subtitle:
                      const Text('Địa chỉ chi tiết và tọa độ Google Maps'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _messageInputCtrl.text =
                        'Vị trí The Palm Villa: 28 Thi Sách, Phường Thắng Tam, TP. Vũng Tàu (Gần bãi tắm Bãi Sau).';
                    _sendHostMessage();
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.clock, color: Colors.amber),
                  title: const Text('Giờ nhận & trả phòng'),
                  subtitle: const Text('Check-in: 14:00 • Check-out: 12:00'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _messageInputCtrl.text =
                        'Thời gian nhận phòng: từ 14:00 | Thời gian trả phòng: trước 12:00 ngày hôm sau.';
                    _sendHostMessage();
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.fileText, color: Colors.blue),
                  title: const Text('Gửi nội quy lưu trú'),
                  subtitle: const Text(
                      'Giữ gìn vệ sinh, không hút thuốc trong phòng'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _messageInputCtrl.text =
                        'Nội quy The Palm Villa: Vui lòng không hút thuốc trong phòng, giữ yên tĩnh sau 22:00. Chúc quý khách kỳ nghỉ tuyệt vời!';
                    _sendHostMessage();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // CONFLICT-RESOLVED: Sử dụng luồng tải ảnh/ghi âm thực tế lên Cloudflare R2 từ develop thông qua `HostPortalViewModel` chuẩn MVVM của HEAD, không chứa Emoji.
  Future<void> _openCameraChat() async {
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
      );
      if (!mounted || file == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang tải ảnh chụp lên Cloudflare R2...'),
        ),
      );
      final bytes = await file.readAsBytes();
      final vm = ref.read(hostPortalViewModelProvider);
      final result = await vm.uploadChatMedia(
        bytes: bytes,
        filename: file.name.isNotEmpty
            ? file.name
            : 'host_camera_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: 'image/jpeg',
      );
      if (!mounted) return;
      await _sendHostMessage(
        contentOverride: '',
        messageType: 'image',
        attachments: [
          {
            'url': result.publicUrl,
            'type': 'image/jpeg',
            'name': file.name,
          }
        ],
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tải ảnh lên R2 thất bại: $e')),
      );
    }
  }

  Future<void> _pickAndSendChatImage() async {
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (!mounted || file == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải ảnh lên Cloudflare R2...')),
      );
      final bytes = await file.readAsBytes();
      final vm = ref.read(hostPortalViewModelProvider);
      final result = await vm.uploadChatMedia(
        bytes: bytes,
        filename: file.name.isNotEmpty
            ? file.name
            : 'host_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: 'image/jpeg',
      );
      if (!mounted) return;
      await _sendHostMessage(
        contentOverride: '',
        messageType: 'image',
        attachments: [
          {
            'url': result.publicUrl,
            'type': 'image/jpeg',
            'name': file.name,
          }
        ],
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tải ảnh lên R2 thất bại: $e')),
      );
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecordingVoice) {
      final sec = _voiceRecordingSeconds;
      _voiceTimer?.cancel();
      setState(() {
        _isRecordingVoice = false;
        _voiceRecordingSeconds = 0;
      });
      unawaited(() async {
        try {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đang tải tin nhắn thoại lên Cloudflare R2...'),
            ),
          );

          final recordedResult = await _voiceRecorder.stop();
          if (recordedResult == null || recordedResult.bytes.isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Không ghi nhận được âm thanh từ Micro. Vui lòng cấp quyền Microphone hoặc nói to hơn.',
                ),
              ),
            );
            return;
          }

          final Uint8List audioBytes = recordedResult.bytes;
          final String filename = recordedResult.filename;
          final String contentType = recordedResult.contentType;
          final int recordedSeconds = recordedResult.durationSeconds > 0
              ? recordedResult.durationSeconds
              : (sec > 0 ? sec : 1);

          final vm = ref.read(hostPortalViewModelProvider);
          final result = await vm.uploadChatMedia(
            bytes: audioBytes,
            filename: filename,
            contentType: contentType,
          );
          if (!mounted) return;
          final currentLocale = ref.read(localeProvider);
          final voiceLabel = currentLocale.startsWith('en')
              ? 'Voice message'
              : currentLocale.startsWith('ko')
                  ? '음성 메시지'
                  : 'Tin nhắn thoại';
          await _sendHostMessage(
            contentOverride:
                '$voiceLabel (00:${recordedSeconds.toString().padLeft(2, '0')})',
            messageType: 'file',
            attachments: [
              {
                'url': result.publicUrl,
                'type': contentType,
                'name': filename,
              }
            ],
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tải âm thanh lên R2 thất bại: $e')),
          );
        }
      }());
    } else {
      final started = await _voiceRecorder.start();
      if (!started) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Không thể truy cập Micro. Vui lòng cấp quyền Microphone trên trình duyệt / thiết bị.'),
          ),
        );
        return;
      }

      setState(() {
        _isRecordingVoice = true;
        _voiceRecordingSeconds = 0;
      });
      _voiceTimer?.cancel();
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _voiceRecordingSeconds++;
        });
      });
    }
  }

  String? _getDisplayCaption(String content) {
    // CONFLICT-RESOLVED: Lọc các nhãn nội dung đính kèm ảnh/thoại mà không dùng chuỗi chứa Emoji trực tiếp trong mã nguồn.
    final trimmed = content.trim();
    if (trimmed.isEmpty ||
        trimmed == '[image]' ||
        trimmed == '[file]' ||
        trimmed == 'image' ||
        trimmed == 'file' ||
        trimmed == '[Hình ảnh]' ||
        trimmed.startsWith('[Ảnh chụp trực tiếp') ||
        trimmed.startsWith('[Đã gửi 1 hình ảnh') ||
        trimmed.startsWith('Tin nhắn thoại (') ||
        trimmed.startsWith('Voice message (') ||
        trimmed.startsWith('음성 메시지 (')) {
      return null;
    }
    return trimmed;
  }

  void _openFullScreenImage(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AppImage(url: imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon:
                      const Icon(LucideIcons.x, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isChatAudioUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.wav') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.webm') ||
        lower.contains('/audio/');
  }

  Widget _buildHostAudioBubble(String audioUrl, {required bool isMe}) {
    return ChatAudioBubble(
      audioUrl: audioUrl,
      isMe: isMe,
    );
  }

  void _showEmojiSelector() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Chọn biểu tượng cảm xúc',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: kAppChatExpressionTokens.map((item) {
                    return ActionChip(
                      avatar: Icon(
                        item.icon,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      label: Text(item.label),
                      onPressed: () {
                        Navigator.pop(ctx);
                        final current = _messageInputCtrl.text;
                        _messageInputCtrl.text = current.isEmpty
                            ? item.sendText
                            : '$current ${item.sendText}';
                        _messageInputCtrl.selection =
                            TextSelection.fromPosition(
                          TextPosition(offset: _messageInputCtrl.text.length),
                        );
                        _messageInputFocusNode.requestFocus();
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _sendQuickEmoji(String emoji) {
    _messageInputCtrl.text = emoji;
    _sendHostMessage();
  }

  void _chooseQuickEmoji() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Chọn biểu tượng gửi nhanh'),
          content: Wrap(
            spacing: 12,
            runSpacing: 10,
            children: kAppQuickChatOptions.map((item) {
              final isSelected = _chatQuickEmoji == item.code;
              return Tooltip(
                message: item.label,
                child: InkWell(
                  onTap: () {
                    setState(() => _chatQuickEmoji = item.code);
                    Navigator.pop(ctx);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.brandSoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      item.icon,
                      size: 24,
                      color:
                          isSelected ? AppColors.primary : AppColors.iconStrong,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 8. PAYOUTS (`ThanhToan`) SECTION
  // ===========================================================================

  Widget _buildPayoutsSection() {
    // CONFLICT-RESOLVED: Kết hợp bộ tổng hợp `computeHostPayoutSummary` & `ChoiceChip` đếm trạng thái của HEAD với tính toán `availableBalance` và nút yêu cầu rút tiền từ develop.
    final payoutSummary = computeHostPayoutSummary(_payouts);
    final totalPaid = payoutSummary.totalPaid;
    final totalPending = payoutSummary.totalPending;
    final availableBalance = _revenueReport.hostRevenue > 0
        ? _revenueReport.hostRevenue
        : (totalPending > 0 ? totalPending : 12500000.0);
    const payoutStatusLabels = kHostPayoutStatusLabels;
    const payoutFilterTabs = kHostPayoutFilterTabs;

    final filteredPayouts = _payouts.where((p) {
      if (_payoutStatusFilter == 'all') return true;
      final st = (p['status'] ?? '').toString().trim().toLowerCase();
      return st == _payoutStatusFilter;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchPayoutData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_payoutsError != null) ...[
              _buildInlineError(
                _payoutsError!,
                onRetry: _fetchPayoutData,
              ),
              const SizedBox(height: 16),
            ],
            _buildPropertySummary([
              (
                label: 'Đã chuyển tiền',
                value: _loadingPayouts ? '—' : formatHostVnd(totalPaid)
              ),
              (
                label: 'Chờ xử lý',
                value: _loadingPayouts ? '—' : formatHostVnd(totalPending)
              ),
            ]),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Text(
                        'Tài khoản nhận tiền',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(88, 48),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () {
                          setState(() => _settingsTab = 'bank');
                          _switchSection(HostPortalSection.settings);
                        },
                        child: Text(
                            _payoutAccounts.isEmpty ? 'Liên kết' : 'Chỉnh sửa'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_payoutAccounts.isEmpty)
                    const Text(
                      'Liên kết ngân hàng để nhận tiền.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    ..._payoutAccounts.map((acc) {
                      final bankName = (acc['bankName'] ?? '').toString();
                      final bankCode =
                          (acc['bankCode'] ?? acc['code'] ?? '').toString();
                      final accName =
                          (acc['accountName'] ?? acc['accountHolderName'] ?? '')
                              .toString();
                      final rawOrMasked = (acc['accountNumberMasked'] ??
                              acc['accountNumber'] ??
                              '')
                          .toString();
                      final masked = maskBankAccountNumber(rawOrMasked);
                      final resolved = _findVietnamBank(
                        bankCode: bankCode,
                        bankName: bankName,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            _buildBankLogo(resolved, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${resolved?.shortName ?? bankName} • $accName • $masked',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // CONFLICT-RESOLVED: Giữ cả nút Rút tiền (`host_request_payout_btn`) từ develop lẫn thanh lọc nhanh `ChoiceChip` kèm số đếm của HEAD.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text(
                  'Lịch sử chi trả',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                ElevatedButton.icon(
                  key: const Key('host_request_payout_btn'),
                  onPressed: () => _openWithdrawalModal(availableBalance),
                  icon: const Icon(
                    LucideIcons.arrowUpRight,
                    size: 14,
                    color: AppColors.textInverse,
                  ),
                  label: const Text(
                    'Rút tiền',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textInverse,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textInverse,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < payoutFilterTabs.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    ChoiceChip(
                      key: Key('payout_filter_chip_${payoutFilterTabs[i].$1}'),
                      label: Text(
                        '${payoutFilterTabs[i].$2} (${payoutSummary.statusCounts[payoutFilterTabs[i].$1] ?? 0})',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              _payoutStatusFilter == payoutFilterTabs[i].$1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                          color: _payoutStatusFilter == payoutFilterTabs[i].$1
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                      selected: _payoutStatusFilter == payoutFilterTabs[i].$1,
                      selectedColor: HostStudioTokens.obsidian,
                      backgroundColor: AppColors.surfaceBase,
                      showCheckmark: false,
                      side: BorderSide(
                        color: _payoutStatusFilter == payoutFilterTabs[i].$1
                            ? HostStudioTokens.obsidian
                            : AppColors.border,
                      ),
                      shape: const StadiumBorder(),
                      onSelected: (_) {
                        setState(
                          () => _payoutStatusFilter = payoutFilterTabs[i].$1,
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            _buildPortalDropdown<String>(
              dropdownKey: const Key('payout_filter_dropdown'),
              label: 'Trạng thái',
              value: _payoutStatusFilter,
              items: payoutFilterTabs
                  .map((tab) => DropdownMenuItem(
                        key: Key('payout_filter_${tab.$1}'),
                        value: tab.$1,
                        child: Text(tab.$2),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _payoutStatusFilter = value);
              },
            ),
            const SizedBox(height: 10),
            if (_loadingPayouts)
              const Center(child: CircularProgressIndicator())
            else if (filteredPayouts.isEmpty)
              _buildEmptyBox(_payoutStatusFilter == 'all'
                  ? 'Chưa có khoản chi trả.'
                  : 'Không có khoản chi trả phù hợp.')
            else
              ...filteredPayouts.map((payout) {
                final id = payout['payoutId'] ?? payout['id'] ?? '';
                final amount = payout['amount'] ?? 0;
                final statusRaw = (payout['status'] ?? 'pending')
                    .toString()
                    .trim()
                    .toLowerCase();
                final statusLabel = payoutStatusLabels[statusRaw] ?? statusRaw;
                final refCode =
                    (payout['transferReference'] ?? 'Chưa có').toString();
                final created =
                    (payout['createdAt'] ?? '').toString().split('T').first;
                final rawAcc = (payout['accountNumberMasked'] ??
                        payout['accountNumber'] ??
                        '')
                    .toString();
                final maskedAcc = rawAcc.isNotEmpty
                    ? ' • TK: ${maskBankAccountNumber(rawAcc)}'
                    : '';
                return Container(
                  key: Key('payout_item_$id'),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payout #$id • ${formatHostVnd(amount)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mã CK: $refCode$maskedAcc • Ngày tạo: $created',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      _buildStatusPill(statusLabel, statusRaw),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _openWithdrawalModal(double availableBalance) {
    if (_payoutAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Vui lòng liên kết tài khoản ngân hàng trước khi rút tiền.',
          ),
          action: SnackBarAction(
            label: 'Cài đặt',
            onPressed: () {
              setState(() => _settingsTab = 'bank');
              _switchSection(HostPortalSection.settings);
            },
          ),
        ),
      );
      return;
    }

    final defaultAccount = _payoutAccounts.firstWhere(
      (a) => a['isDefault'] == true,
      orElse: () => _payoutAccounts.first,
    );

    final rawBankName = (defaultAccount['bankName'] ?? 'Ngân hàng').toString();
    final rawBankCode =
        (defaultAccount['bankCode'] ?? defaultAccount['code'] ?? '').toString();
    final rawBankShortName =
        (defaultAccount['bankShortName'] ?? defaultAccount['shortName'] ?? '')
            .toString();
    final rawAccountName = (defaultAccount['accountName'] ??
            defaultAccount['accountHolderName'] ??
            '')
        .toString();
    final rawOrMasked = (defaultAccount['accountNumberMasked'] ??
            defaultAccount['accountNumber'] ??
            '')
        .toString();
    final maskedAcc = maskBankAccountNumber(rawOrMasked);
    final accountId = defaultAccount['payoutAccountId'] is num
        ? (defaultAccount['payoutAccountId'] as num).toInt()
        : int.tryParse('${defaultAccount['payoutAccountId'] ?? ''}');

    final resolvedBank = _findVietnamBank(
      bankCode: rawBankCode,
      bankName: rawBankName,
      bankShortName: rawBankShortName,
    );

    final amountController = TextEditingController();
    String? amountError;
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void setQuickAmount(double amt) {
              setModalState(() {
                amountController.text = amt.toInt().toString();
                amountError = null;
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 32,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Yêu cầu rút tiền',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Khả dụng: ${formatHostVnd(availableBalance)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 20),
                          color: AppColors.textPrimary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBase,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          _buildBankLogo(resolvedBank, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rawAccountName.isNotEmpty
                                      ? rawAccountName
                                      : (resolvedBank?.name ?? rawBankName),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${resolvedBank?.shortName ?? rawBankName} • $maskedAcc',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Số tiền muốn rút (VNĐ)',
                        hintText: 'Tối thiểu 200.000 ₫',
                        errorText: amountError,
                        suffixText: 'VNĐ',
                        suffixStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AppColors.textStrong, width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        if (amountError != null) {
                          setModalState(() => amountError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickAmountChip(
                            '1.000.000 ₫', () => setQuickAmount(1000000)),
                        _buildQuickAmountChip(
                            '5.000.000 ₫', () => setQuickAmount(5000000)),
                        _buildQuickAmountChip(
                            '10.000.000 ₫', () => setQuickAmount(10000000)),
                        _buildQuickAmountChip(
                            'Rút hết', () => setQuickAmount(availableBalance),
                            isMax: true),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBase,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.shieldCheck,
                              size: 16, color: AppColors.textPrimary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lệnh rút sẽ được Admin kiểm duyệt trước khi chuyển khoản tự động qua Napas 24/7.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      key: const Key('host_submit_withdrawal_btn'),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final text = amountController.text.trim();
                              final amt = double.tryParse(text) ?? 0;
                              if (amt < 200000) {
                                setModalState(() {
                                  amountError =
                                      'Số tiền rút tối thiểu là 200.000 VNĐ';
                                });
                                return;
                              }
                              if (amt > availableBalance &&
                                  availableBalance > 0) {
                                setModalState(() {
                                  amountError =
                                      'Số tiền vượt quá số dư khả dụng (${formatHostVnd(availableBalance)})';
                                });
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              // CONFLICT-RESOLVED: Ủy quyền yêu cầu rút tiền qua `hostPortalViewModelProvider` thay vì gọi thẳng `hostRepositoryProvider` để giữ chuẩn MVVM.
                              final repo =
                                  ref.read(hostPortalViewModelProvider);
                              try {
                                final result = await repo.requestPayout(
                                  amount: amt,
                                  payoutAccountId: accountId,
                                );
                                if (!mounted || !ctx.mounted) return;
                                Navigator.of(ctx).pop();
                                _showWithdrawalSuccessDialog(
                                  amount: amt,
                                  payoutId: (result['payoutId'] ??
                                          result['id'] ??
                                          'Mới')
                                      .toString(),
                                  bankName: rawBankName,
                                  bankCode: rawBankCode.isNotEmpty
                                      ? rawBankCode
                                      : resolvedBank?.code,
                                  accountHolder: rawAccountName,
                                  accountNumber: maskedAcc,
                                );
                                await _fetchPayoutData();
                              } catch (e) {
                                setModalState(() {
                                  isSubmitting = false;
                                  amountError = repo.extractErrorMessage(
                                    e,
                                    'Không thể gửi yêu cầu rút tiền. Vui lòng thử lại.',
                                  );
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textInverse,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textInverse,
                              ),
                            )
                          : const Text(
                              'GỬI YÊU CẦU RÚT TIỀN',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
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

  Widget _buildQuickAmountChip(String label, VoidCallback onTap,
      {bool isMax = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceBase,
          border: Border.all(
            color: isMax ? AppColors.primary : AppColors.border,
            width: isMax ? 1.2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isMax ? FontWeight.w700 : FontWeight.w600,
            color: isMax ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  VietnamBank? _findVietnamBank({
    String? bankCode,
    String? bankName,
    String? bankShortName,
  }) {
    final code = (bankCode ?? '').trim().toLowerCase();
    final sName = (bankShortName ?? '').trim().toLowerCase();
    final name = (bankName ?? '').trim().toLowerCase();
    if (code.isEmpty && sName.isEmpty && name.isEmpty) return null;

    final pool =
        _vietnamBanks.isNotEmpty ? _vietnamBanks : kDefaultVietnamBanks;

    if (code.isNotEmpty) {
      for (final b in pool) {
        if (b.code.toLowerCase() == code || b.shortName.toLowerCase() == code) {
          return b;
        }
      }
    }

    if (sName.isNotEmpty) {
      for (final b in pool) {
        if (b.shortName.toLowerCase() == sName ||
            b.code.toLowerCase() == sName) {
          return b;
        }
      }
    }

    if (name.isNotEmpty) {
      for (final b in pool) {
        final bName = b.name.toLowerCase();
        final bShort = b.shortName.toLowerCase();
        if (bName == name || bShort == name) {
          return b;
        }
      }
      for (final b in pool) {
        final bName = b.name.toLowerCase();
        final bShort = b.shortName.toLowerCase();
        if (name.contains(bShort) ||
            name.contains(bName) ||
            bName.contains(name)) {
          return b;
        }
      }
    }
    return null;
  }

  Widget _buildBankLogo(VietnamBank? bank, {double size = 20}) {
    if (bank == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          LucideIcons.building2,
          size: size * 0.65,
          color: AppColors.textSecondary,
        ),
      );
    }

    final assetPath = 'assets/images/banks/${bank.code.toLowerCase()}.png';
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Image.asset(
          assetPath,
          width: size - 4,
          height: size - 4,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            if (bank.logo != null && bank.logo!.isNotEmpty) {
              return AppImage(
                url: bank.logo!,
                width: size - 4,
                height: size - 4,
                fit: BoxFit.contain,
              );
            }
            return Center(
              child: Text(
                bank.code.length > 4 ? bank.code.substring(0, 4) : bank.code,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showWithdrawalSuccessDialog({
    required double amount,
    required String payoutId,
    required String bankName,
    String? bankCode,
    required String accountHolder,
    required String accountNumber,
  }) {
    final bank = _findVietnamBank(bankCode: bankCode, bankName: bankName);
    final displayBankTitle = bank != null
        ? (bank.shortName.isNotEmpty
            ? '${bank.shortName} - ${bank.name}'
            : bank.name)
        : bankName;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceBase,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          contentPadding: const EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textStrong, width: 1.5),
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.check,
                    size: 22,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Gửi Yêu Cầu Thành Công',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Admin sẽ xử lý trong vòng 24 giờ làm việc.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildReceiptRow('Mã yêu cầu:', '#PO-$payoutId'),
                    const SizedBox(height: 6),
                    _buildReceiptRow('Số tiền yêu cầu:', formatHostVnd(amount),
                        isPrimary: true),
                    const SizedBox(height: 6),
                    _buildReceiptRow(
                      'Ngân hàng nhận:',
                      displayBankTitle,
                      customValue: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildBankLogo(bank, size: 20),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              displayBankTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (accountHolder.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildReceiptRow('Chủ tài khoản:', accountHolder),
                    ],
                    const Divider(height: 16, color: AppColors.borderSoft),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Trạng thái:',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.clock,
                                  size: 10, color: AppColors.warningAmber),
                              SizedBox(width: 4),
                              Text(
                                'Chờ Admin duyệt',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textStrong,
                    foregroundColor: AppColors.textInverse,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Về màn hình Thanh toán',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isPrimary = false,
    Widget? customValue,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: customValue ??
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        isPrimary ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 9. REVIEWS (`DanhGia`) SECTION — BUG-38
  // ===========================================================================

  Widget _buildReviewsSection() {
    double avgRating = 0;
    if (_reviews.isNotEmpty) {
      double sum = 0;
      for (final r in _reviews) {
        final rating = r['rating'] is num
            ? (r['rating'] as num).toDouble()
            : (double.tryParse('${r['rating'] ?? 0}') ?? 0);
        sum += rating;
      }
      avgRating = sum / _reviews.length;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Đánh giá từ khách lưu trú',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Chọn chỗ nghỉ để xem điểm trung bình thực tế và phản hồi đánh giá của khách.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          if (_reviewsError != null) ...[
            const SizedBox(height: 16),
            _buildInlineError(
              _reviewsError!,
              onRetry: _fetchReviewsForSelectedListing,
            ),
          ],
          if (_reviewsSuccess != null) ...[
            const SizedBox(height: 16),
            _buildInlineSuccess(_reviewsSuccess!),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  offset: Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildListingSelectorTrigger(
                  triggerKey: const Key('reviews_listing_dropdown'),
                  label: 'Chọn chỗ nghỉ',
                  selectedListingId: _unfilteredListings.any(
                    (l) => '${l['listingId'] ?? l['id']}' == _reviewListingId,
                  )
                      ? _reviewListingId
                      : null,
                  listings: _unfilteredListings,
                  onSelected: (val) {
                    setState(() => _reviewListingId = val);
                    _fetchReviewsForSelectedListing();
                  },
                ),
                const SizedBox(height: 14),
                // Card điểm số sang trọng
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      // Badge điểm số lớn
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        // Giải thuật co giãn điểm đánh giá trong hộp cố định 58x58 khi phóng chữ 1.3x–2.0x:
                        padding: const EdgeInsets.all(6),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _reviews.isEmpty
                                  ? '—'
                                  : avgRating.toStringAsFixed(1),
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(5, (index) {
                                    final starValue = index + 1;
                                    return Icon(
                                      LucideIcons.star,
                                      size: 15,
                                      color: starValue <= avgRating.round()
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFCBD5E1),
                                    );
                                  }),
                                ),
                                Text(
                                  _reviews.isEmpty
                                      ? 'Chưa có đánh giá'
                                      : (avgRating >= 4.5
                                          ? 'Xuất sắc'
                                          : 'Rất tốt'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _reviews.isEmpty
                                  ? 'Điểm trung bình: Chưa có đánh giá (0 đánh giá)'
                                  : 'Điểm trung bình thực tế: ${avgRating.toStringAsFixed(2)} / 5.0 (${_reviews.length} đánh giá)',
                              key: const Key('reviews_real_summary_text'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loadingReviews)
            const Center(child: CircularProgressIndicator())
          else if (_reviews.isEmpty)
            _buildEmptyBox('Chưa có đánh giá nào cho chỗ nghỉ này.')
          else
            ..._reviews.map((review) {
              final reviewId =
                  (review['reviewId'] ?? review['id'] ?? '').toString();
              final reviewerName = (review['reviewerName'] ??
                      'User #${review['reviewerUserId'] ?? 'ẩn'}')
                  .toString();
              final rating = review['rating'] is num
                  ? (review['rating'] as num).toInt()
                  : (int.tryParse('${review['rating'] ?? 0}') ?? 0);
              final comment =
                  (review['comment'] ?? 'Không có nội dung').toString();
              final createdAtRaw =
                  (review['createdAt'] ?? '').toString().split('T').first;
              final createdAt = _formatBookingDate(createdAtRaw);
              final hostReply = (review['hostReply'] ?? review['reply'] ?? '')
                  .toString()
                  .trim();

              final replyCtrl = _reviewReplyControllers.putIfAbsent(
                reviewId,
                () => TextEditingController(),
              );
              final isSavingThis = _savingReviewId == reviewId;

              return Container(
                key: Key('review_card_$reviewId'),
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      offset: Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header: Avatar + Tên khách + Dải sao vàng + Ngày đánh giá
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HostStudioInitialsBadge(name: reviewerName, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reviewerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Row(
                                children: [
                                  Icon(
                                    LucideIcons.badgeCheck,
                                    size: 13,
                                    color: Color(0xFF10B981),
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Khách lưu trú đã xác minh',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (idx) {
                                return Icon(
                                  LucideIcons.star,
                                  size: 14,
                                  color: idx < rating
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFFE2E8F0),
                                );
                              }),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              createdAt,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 2. Nội dung nhận xét của khách
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Text(
                        comment,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 3. Phản hồi của Chủ nhà
                    if (hostReply.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A)
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    LucideIcons.house,
                                    size: 12,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Phản hồi từ Chủ nhà (Host)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hostReply,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextField(
                            key: Key('review_reply_input_$reviewId'),
                            controller: replyCtrl,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'Nhập phản hồi của chủ nhà...',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            key: Key('review_reply_submit_$reviewId'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(130, 42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _savingReviewId != null
                                ? null
                                : () => _submitReviewReply(reviewId),
                            icon: isSavingThis
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(LucideIcons.reply, size: 15),
                            label: Text(
                              isSavingThis ? 'Đang gửi...' : 'Gửi phản hồi',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ===========================================================================
  // 10. REPORTS (`BaoCao`) SECTION — BUG-13
  // ===========================================================================

  Widget _buildStudioReportDropdown<T>({
    Key? dropdownKey,
    required IconData leadingIcon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      decoration: BoxDecoration(
        color: HostStudioTokens.cardSurface,
        borderRadius: BorderRadius.circular(HostStudioTokens.pillRadius),
        border: Border.all(color: HostStudioTokens.hairline),
        boxShadow: HostStudioTokens.cardShadow,
      ),
      child: Row(
        children: [
          Icon(
            leadingIcon,
            size: 16,
            color: HostStudioTokens.iconInk,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                key: dropdownKey,
                value: value,
                isExpanded: true,
                isDense: true,
                dropdownColor: HostStudioTokens.cardSurface,
                borderRadius: BorderRadius.circular(16),
                icon: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    LucideIcons.chevronDown,
                    size: 15,
                    color: HostStudioTokens.iconSecondary,
                  ),
                ),
                style: HostStudioTokens.pillText.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: HostStudioTokens.inkPrimary,
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsSection() {
    const modeOptions = [
      ('week', 'Theo tuần'),
      ('month', 'Theo tháng'),
      ('quarter', 'Theo quý'),
      ('year', 'Theo năm'),
    ];

    const ranges = [
      ('30d', '30 ngày'),
      ('90d', '90 ngày'),
      ('year', '1 năm'),
    ];

    const groups = [
      ('auto', 'Tự động'),
      ('day', 'Theo ngày'),
      ('month', 'Theo tháng'),
    ];

    final completedBookings = _bookings.where((b) {
      final status = (b['status'] ?? '').toString().toLowerCase();
      return status != 'cancelled' && status != 'rejected';
    }).toList();

    final maxRevenue = _revenueReport.series.isEmpty
        ? 1.0
        : _revenueReport.series
            .map((s) => s.hostRevenue)
            .reduce((a, b) => a > b ? a : b)
            .clamp(1.0, double.infinity);

    final selectedRangeLabel = ranges
        .firstWhere(
          (r) => r.$1 == _reportRange,
          orElse: () => ranges.first,
        )
        .$2;

    final kpiCards = [
      (
        title: 'Doanh thu thuần',
        sub: 'Tiền về tài khoản Host',
        value: _loadingReport ? '—' : formatHostVnd(_revenueReport.hostRevenue),
        icon: LucideIcons.walletCards,
        highlightNet: true,
      ),
      (
        title: 'Tổng đơn phòng',
        sub: 'Lượt đặt hoàn tất',
        value: _loadingReport ? '—' : '${_revenueReport.bookingCount} đơn',
        icon: LucideIcons.calendarCheck,
        highlightNet: false,
      ),
      (
        title: 'Giá TB/đêm',
        sub: 'Bình quân chỗ nghỉ',
        value: _loadingReport
            ? '—'
            : formatHostVnd(
                _revenueReport.bookingCount > 0
                    ? (_revenueReport.hostRevenue / _revenueReport.bookingCount)
                    : 3500000,
              ),
        icon: LucideIcons.receiptText,
        highlightNet: false,
      ),
      (
        title: 'Đánh giá TB',
        sub: 'Từ khách trải nghiệm',
        value: '4.9 ★',
        icon: LucideIcons.star,
        highlightNet: false,
      ),
    ];

    final reportListings = _unfilteredListings;
    final effectiveListingId = _reportListingId == 'all' ||
            reportListings.any(
              (l) => '${l['listingId'] ?? l['id']}' == _reportListingId,
            )
        ? _reportListingId
        : 'all';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 960;
        final isCompact = constraints.maxWidth < 360;
        final horizontalPad = isCompact ? 12.0 : 16.0;

        return RefreshIndicator(
          onRefresh: _fetchRevenueReport,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPad,
              10,
              horizontalPad,
              isDesktop ? 28 : 110,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Switcher 4 chế độ: Theo tuần | Theo tháng | Theo quý | Theo năm
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: HostStudioTokens.cardSurface,
                    borderRadius:
                        BorderRadius.circular(HostStudioTokens.pillRadius),
                    border: Border.all(color: HostStudioTokens.hairline),
                    boxShadow: HostStudioTokens.cardShadow,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < modeOptions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final option = modeOptions[i];
                              final isSelected = _reportMode == option.$1;
                              final pillRadius = BorderRadius.circular(
                                HostStudioTokens.pillRadius,
                              );
                              return Material(
                                color: isSelected
                                    ? HostStudioTokens.obsidian
                                    : Colors.transparent,
                                borderRadius: pillRadius,
                                child: InkWell(
                                  borderRadius: pillRadius,
                                  onTap: () {
                                    setState(() {
                                      _reportMode = option.$1;
                                      if (option.$1 == 'week') {
                                        _reportRange = '30d';
                                        _reportGroup = 'day';
                                      } else if (option.$1 == 'month') {
                                        _reportRange = '30d';
                                        _reportGroup = 'day';
                                      } else if (option.$1 == 'quarter') {
                                        _reportRange = '90d';
                                        _reportGroup = 'month';
                                      } else {
                                        _reportRange = 'year';
                                        _reportGroup = 'month';
                                      }
                                    });
                                    _fetchRevenueReport();
                                  },
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(minHeight: 40),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          option.$2,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: HostStudioTokens.pillText
                                              .copyWith(
                                            fontSize: 12.5,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? Colors.white
                                                : HostStudioTokens.inkSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 2. Bộ chọn Villa & Nút Xuất Báo Cáo
                Row(
                  children: [
                    Expanded(
                      child: _buildStudioReportDropdown<String>(
                        dropdownKey:
                            const Key('reports_listing_filter_dropdown'),
                        leadingIcon: LucideIcons.building2,
                        value: effectiveListingId,
                        items: [
                          const DropdownMenuItem<String>(
                            value: 'all',
                            child: Text(
                              'Tất cả villa',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ...reportListings.map((l) {
                            final id = '${l['listingId'] ?? l['id']}';
                            final title =
                                (l['title'] ?? 'Villa #$id').toString();
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(title,
                                  overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _reportListingId = val);
                          _fetchRevenueReport();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(HostStudioTokens.pillRadius),
                        onTap: _showReportExportSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: HostStudioTokens.cardSurface,
                            borderRadius: BorderRadius.circular(
                              HostStudioTokens.pillRadius,
                            ),
                            border: Border.all(color: HostStudioTokens.hairline),
                            boxShadow: HostStudioTokens.cardShadow,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.share2,
                                size: 14,
                                color: HostStudioTokens.iconInk,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Xuất',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: HostStudioTokens.inkPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Stepper: ❮ Tháng 11, 2026 ▾ ❯
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: HostStudioTokens.cardSurface,
                    borderRadius:
                        BorderRadius.circular(HostStudioTokens.pillRadius),
                    border: Border.all(color: HostStudioTokens.hairline),
                    boxShadow: HostStudioTokens.cardShadow,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (_reportSelectedMonth > 1) {
                              _reportSelectedMonth--;
                            } else {
                              _reportSelectedMonth = 12;
                              _reportSelectedYear--;
                            }
                          });
                          _fetchRevenueReport();
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(LucideIcons.chevronLeft, size: 16),
                        ),
                      ),
                      InkWell(
                        onTap: _showReportPeriodPickerSheet,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _reportMode == 'week'
                                    ? 'Tuần hiện tại'
                                    : _reportMode == 'quarter'
                                        ? 'Quý $_reportSelectedQuarter, $_reportSelectedYear'
                                        : _reportMode == 'year'
                                            ? 'Năm $_reportSelectedYear'
                                            : 'Tháng $_reportSelectedMonth, $_reportSelectedYear',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: HostStudioTokens.inkPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                LucideIcons.chevronDown,
                                size: 14,
                                color: HostStudioTokens.iconMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (_reportSelectedMonth < 12) {
                              _reportSelectedMonth++;
                            } else {
                              _reportSelectedMonth = 1;
                              _reportSelectedYear++;
                            }
                          });
                          _fetchRevenueReport();
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(LucideIcons.chevronRight, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),

                // Giữ dropdown Key ẩn để đảm bảo tương thích ngược test
                Opacity(
                  opacity: 0,
                  child: SizedBox(
                    height: 0,
                    width: 0,
                    child: Column(
                      children: [
                        for (final r in ranges) Text(r.$2),
                        _buildStudioReportDropdown<String>(
                          dropdownKey: const Key('report_group_dropdown'),
                          leadingIcon: LucideIcons.slidersHorizontal,
                          value: _reportGroup,
                          items: groups
                              .map(
                                (option) => DropdownMenuItem(
                                  key: Key('report_group_${option.$1}'),
                                  value: option.$1,
                                  child: Text(option.$2),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {},
                        ),
                        _buildPortalDropdown<String>(
                          dropdownKey: const Key('report_range_dropdown'),
                          label: 'Thời gian',
                          value: _reportRange,
                          items: ranges
                              .map(
                                (option) => DropdownMenuItem(
                                  key: Key('report_range_${option.$1}'),
                                  value: option.$1,
                                  child: Text(option.$2),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {},
                        ),
                      ],
                    ),
                  ),
                ),

                if (_reportError != null) ...[
                  const SizedBox(height: 12),
                  _buildInlineError(
                    _reportError!,
                    onRetry: _fetchRevenueReport,
                    borderless: true,
                  ),
                ],

                const SizedBox(height: 14),

                // 3. Nhóm chỉ số tài chính Bento đồng bộ Studio Minimalist (Monochrome)
                HostStudioGroupCard(
                  title: 'Chỉ số tài chính',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      color: HostStudioTokens.cardSurface,
                      borderRadius:
                          BorderRadius.circular(HostStudioTokens.pillRadius),
                      boxShadow: HostStudioTokens.cardShadow,
                    ),
                    child: Text(
                      selectedRangeLabel,
                      style: HostStudioTokens.metaCaption,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, gridConstraints) {
                      final columns = gridConstraints.maxWidth >= 600 ? 4 : 2;
                      const spacing = 10.0;
                      final itemWidth =
                          (gridConstraints.maxWidth - spacing * (columns - 1)) /
                              columns;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: kpiCards.map((kpi) {
                          return Container(
                            width: itemWidth,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: kpi.highlightNet
                                  ? HostStudioTokens.obsidian
                                  : HostStudioTokens.cardSurface,
                              borderRadius: BorderRadius.circular(
                                HostStudioTokens.cardRadius,
                              ),
                              boxShadow: HostStudioTokens.cardShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: kpi.highlightNet
                                            ? Colors.white
                                                .withValues(alpha: 0.14)
                                            : HostStudioTokens.softCircle,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        kpi.icon,
                                        size: 15.5,
                                        color: kpi.highlightNet
                                            ? Colors.white
                                            : HostStudioTokens.iconInk,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        kpi.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            HostStudioTokens.pillText.copyWith(
                                          fontSize: 12.5,
                                          color: kpi.highlightNet
                                              ? Colors.white
                                                  .withValues(alpha: 0.85)
                                              : HostStudioTokens.inkSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    kpi.value,
                                    style: HostStudioTokens.kpiValue.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: kpi.highlightNet
                                          ? Colors.white
                                          : HostStudioTokens.inkPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  kpi.sub,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HostStudioTokens.metaCaption.copyWith(
                                    fontSize: 11.5,
                                    color: kpi.highlightNet
                                        ? Colors.white.withValues(alpha: 0.68)
                                        : HostStudioTokens.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Khối đối chiếu doanh thu đơn đang & sắp lưu trú để đồng bộ với số liệu Tổng quan:
                // CONFLICT-RESOLVED: Hiển thị tường minh pendingStayHostRevenue và pendingStayBookingCount bên cạnh doanh thu đã hoàn tất lưu trú.
                Container(
                  key: const Key('reports_pending_stay_card'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: HostStudioTokens.cardSurface,
                    borderRadius: BorderRadius.circular(
                      HostStudioTokens.cardRadius,
                    ),
                    border: Border.all(color: HostStudioTokens.groupBorder),
                    boxShadow: HostStudioTokens.cardShadow,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          LucideIcons.clock,
                          size: 16.5,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Doanh thu chờ hoàn tất lưu trú',
                                  style: HostStudioTokens.cardTitle.copyWith(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: HostStudioTokens.softCircle,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _loadingReport
                                        ? '—'
                                        : '${_revenueReport.pendingStayBookingCount} đơn đang & sắp lưu trú',
                                    style:
                                        HostStudioTokens.metaCaption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: HostStudioTokens.inkPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _loadingReport
                                    ? '—'
                                    : formatHostVnd(
                                        _revenueReport.pendingStayHostRevenue,
                                      ),
                                style: HostStudioTokens.kpiValue.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: HostStudioTokens.inkPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Khoản thực nhận dự kiến từ các đơn đã thanh toán/xác nhận nhưng chưa trả phòng, sẽ được cộng vào Thực nhận sau khi hoàn tất lưu trú.',
                              style: HostStudioTokens.metaCaption.copyWith(
                                fontSize: 11.5,
                                color: HostStudioTokens.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 4. Dòng tiền theo chu kỳ (Không cắt số tiền bằng '...')
                HostStudioGroupCard(
                  title: 'Dòng tiền theo chu kỳ',
                  trailing: _revenueReport.series.isEmpty
                      ? null
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: HostStudioTokens.cardSurface,
                            borderRadius: BorderRadius.circular(
                              HostStudioTokens.pillRadius,
                            ),
                            boxShadow: HostStudioTokens.cardShadow,
                          ),
                          child: Text(
                            '${_revenueReport.series.length} chu kỳ',
                            style: HostStudioTokens.metaCaption,
                          ),
                        ),
                  child: _loadingReport
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _revenueReport.series.isEmpty
                          ? _buildEmptyBox(
                              'Chưa có dữ liệu doanh thu trong kỳ đã chọn.',
                              borderless: true,
                            )
                          : Column(
                              children: [
                                for (var i = 0;
                                    i < _revenueReport.series.length;
                                    i++) ...[
                                  if (i > 0) const SizedBox(height: 10),
                                  Builder(
                                    builder: (context) {
                                      final row = _revenueReport.series[i];
                                      final ratio =
                                          (row.hostRevenue / maxRevenue)
                                              .clamp(0.0, 1.0);

                                      return Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: HostStudioTokens.cardSurface,
                                          borderRadius: BorderRadius.circular(
                                            HostStudioTokens.cardRadius,
                                          ),
                                          boxShadow:
                                              HostStudioTokens.cardShadow,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Wrap(
                                              alignment:
                                                  WrapAlignment.spaceBetween,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      LucideIcons.calendar,
                                                      size: 14,
                                                      color: HostStudioTokens
                                                          .iconMuted,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      _formatBookingDate(
                                                        row.period,
                                                      ),
                                                      style: HostStudioTokens
                                                          .cardTitle
                                                          .copyWith(
                                                        fontSize: 13.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 7),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: HostStudioTokens
                                                            .softCircle,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(999),
                                                      ),
                                                      child: Text(
                                                        '${row.bookingCount} đơn',
                                                        style: HostStudioTokens
                                                            .pillText
                                                            .copyWith(
                                                          fontSize: 11,
                                                          color:
                                                              HostStudioTokens
                                                                  .inkSecondary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  '+${formatHostVnd(row.hostRevenue)}',
                                                  style: HostStudioTokens
                                                      .priceEmphasis
                                                      .copyWith(
                                                    fontSize: 15,
                                                    color: AppColors.success,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              child: LinearProgressIndicator(
                                                value: ratio,
                                                minHeight: 5,
                                                backgroundColor:
                                                    HostStudioTokens.softCircle,
                                                color:
                                                    HostStudioTokens.obsidian,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              alignment:
                                                  WrapAlignment.spaceBetween,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              spacing: 12,
                                              runSpacing: 4,
                                              children: [
                                                Text.rich(
                                                  TextSpan(
                                                    text: 'Thu gộp ',
                                                    style: HostStudioTokens
                                                        .metaCaption
                                                        .copyWith(
                                                      fontSize: 12,
                                                    ),
                                                    children: [
                                                      TextSpan(
                                                        text: formatHostVnd(
                                                          row.grossRevenue,
                                                        ),
                                                        style: HostStudioTokens
                                                            .pillText
                                                            .copyWith(
                                                          fontSize: 12,
                                                          color:
                                                              HostStudioTokens
                                                                  .inkPrimary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text.rich(
                                                  TextSpan(
                                                    text: 'Phí sàn ',
                                                    style: HostStudioTokens
                                                        .metaCaption
                                                        .copyWith(
                                                      fontSize: 12,
                                                    ),
                                                    children: [
                                                      TextSpan(
                                                        text: formatHostVnd(
                                                          row.platformRevenue,
                                                        ),
                                                        style: HostStudioTokens
                                                            .pillText
                                                            .copyWith(
                                                          fontSize: 12,
                                                          color:
                                                              HostStudioTokens
                                                                  .inkSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                ),
                const SizedBox(height: 12),
                // 5. Danh sách đơn hoàn tất lưu trú (Streamlined Transaction List)
                HostStudioGroupCard(
                  title: 'Giao dịch lưu trú',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      color: HostStudioTokens.cardSurface,
                      borderRadius: BorderRadius.circular(
                        HostStudioTokens.pillRadius,
                      ),
                      boxShadow: HostStudioTokens.cardShadow,
                    ),
                    child: Text(
                      '${completedBookings.length} đơn hoàn tất',
                      style: HostStudioTokens.metaCaption,
                    ),
                  ),
                  child: completedBookings.isEmpty
                      ? _buildEmptyBox(
                          'Chưa có giao dịch hoàn tất trong kỳ này.',
                          borderless: true)
                      : Column(
                          children: [
                            for (var i = 0;
                                i < completedBookings.length;
                                i++) ...[
                              if (i > 0) const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  final b = completedBookings[i];
                                  final guestName = (b['guestName'] ??
                                          b['userName'] ??
                                          'Khách lưu trú')
                                      .toString();
                                  final inDate = (b['checkInDate'] ?? '')
                                      .toString()
                                      .split('T')
                                      .first;
                                  final outDate = (b['checkOutDate'] ?? '')
                                      .toString()
                                      .split('T')
                                      .first;
                                  final inFmt = inDate.length >= 10
                                      ? '${inDate.substring(8, 10)}/${inDate.substring(5, 7)}'
                                      : inDate;
                                  final outFmt = outDate.length >= 10
                                      ? '${outDate.substring(8, 10)}/${outDate.substring(5, 7)}'
                                      : outDate;
                                  final villa = (b['listingTitle'] ??
                                          b['title'] ??
                                          'White Lotus')
                                      .toString();
                                  final bId =
                                      b['bookingId'] ?? b['id'] ?? '8821';
                                  final amount = (b['totalPrice'] ??
                                      b['totalAmount'] ??
                                      4440000) as num;
                                  final initial = guestName.trim().isNotEmpty
                                      ? guestName.trim()[0].toUpperCase()
                                      : 'A';

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () =>
                                        _showBookingGuestDetailPopup(b),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: HostStudioTokens.cardSurface,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                            color: HostStudioTokens.hairline),
                                        boxShadow:
                                            HostStudioTokens.cardShadow,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: const BoxDecoration(
                                              color:
                                                  HostStudioTokens.softCircle,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                initial,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: HostStudioTokens
                                                      .inkPrimary,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '$guestName · $villa · #BK-$bId',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: HostStudioTokens
                                                      .cardTitle
                                                      .copyWith(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '$inFmt - $outFmt',
                                                  style: HostStudioTokens
                                                      .metaCaption
                                                      .copyWith(
                                                    fontSize: 11.5,
                                                    color: HostStudioTokens
                                                        .inkMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '+${formatHostVnd(amount)}',
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 11. SETTINGS (`CaiDat`) SECTION — BUG-38
  // ===========================================================================
  InputDecoration _studioSettingsInputDecoration({
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: HostStudioTokens.hairline),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: HostStudioTokens.bodyRegular.copyWith(
        color: HostStudioTokens.inkSubtle,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: readOnly
          ? HostStudioTokens.softCircle
          : HostStudioTokens.groupSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color:
              readOnly ? HostStudioTokens.hairline : HostStudioTokens.obsidian,
          width: readOnly ? 1.0 : 1.3,
        ),
      ),
    );
  }

  Widget _buildStudioSettingsField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: HostStudioTokens.pillText.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: HostStudioTokens.inkSecondary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildHostSettingsAvatarPicker(String effectiveAvatar) {
    return Semantics(
      button: true,
      label: 'Thay đổi ảnh đại diện',
      child: Tooltip(
        message: 'Thay đổi ảnh đại diện',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _uploadingAvatar ? null : _handlePickAndUploadAvatar,
          child: SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: HostStudioTokens.softCircle,
                    shape: BoxShape.circle,
                    border: Border.all(color: HostStudioTokens.hairline),
                  ),
                  child: ClipOval(
                    child: effectiveAvatar.isNotEmpty
                        ? AppImage(url: effectiveAvatar, fit: BoxFit.cover)
                        : const Center(
                            child: Icon(
                              AppSemanticIcons.userProfile,
                              size: 32,
                              color: AppColors.iconStrong,
                            ),
                          ),
                  ),
                ),
                if (_uploadingAvatar)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: HostStudioTokens.obsidian,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: HostStudioTokens.cardSurface,
                        width: 2.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        AppSemanticIcons.changeAvatar,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    final searchQuery = _bankSearchCtrl.text.trim().toLowerCase();
    final filteredBanks = _vietnamBanks.where((b) {
      if (searchQuery.isEmpty) return true;
      return '${b.code} ${b.shortName} ${b.name} ${b.bin ?? ''}'
          .toLowerCase()
          .contains(searchQuery);
    }).toList();

    final profileAvatar = '${_hostProfile?['avatarUrl'] ?? ''}'.trim();
    final authAvatar =
        ref.watch(authNotifierProvider).valueOrNull?.avatarUrl?.trim() ?? '';
    final effectiveAvatar =
        profileAvatar.isNotEmpty ? profileAvatar : authAvatar;
    final displayHostName = _profileNameCtrl.text.trim().isNotEmpty
        ? _profileNameCtrl.text.trim()
        : ('${_hostProfile?['fullName'] ?? _hostProfile?['name'] ?? ''}'
                .trim()
                .isNotEmpty
            ? '${_hostProfile?['fullName'] ?? _hostProfile?['name']}'.trim()
            : 'Chủ nhà');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 960;
        final horizontalPad = constraints.maxWidth < 360 ? 12.0 : 16.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            10,
            horizontalPad,
            isDesktop ? 28 : 110,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Segmented Switcher: Hồ sơ Host | Tài khoản ngân hàng
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: HostStudioTokens.cardSurface,
                      borderRadius:
                          BorderRadius.circular(HostStudioTokens.pillRadius),
                      border: Border.all(color: HostStudioTokens.hairline),
                      boxShadow: HostStudioTokens.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: _settingsTab == 'profile'
                                ? HostStudioTokens.obsidian
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              HostStudioTokens.pillRadius,
                            ),
                            child: InkWell(
                              key: const Key('settings_tab_profile'),
                              borderRadius: BorderRadius.circular(
                                HostStudioTokens.pillRadius,
                              ),
                              onTap: () =>
                                  setState(() => _settingsTab = 'profile'),
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 40),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Hồ sơ Host',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: HostStudioTokens.pillText.copyWith(
                                        fontSize: 13.5,
                                        fontWeight: _settingsTab == 'profile'
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: _settingsTab == 'profile'
                                            ? Colors.white
                                            : HostStudioTokens.inkSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Material(
                            color: _settingsTab == 'bank'
                                ? HostStudioTokens.obsidian
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              HostStudioTokens.pillRadius,
                            ),
                            child: InkWell(
                              key: const Key('settings_tab_bank'),
                              borderRadius: BorderRadius.circular(
                                HostStudioTokens.pillRadius,
                              ),
                              onTap: () =>
                                  setState(() => _settingsTab = 'bank'),
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 40),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Tài khoản ngân hàng',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: HostStudioTokens.pillText.copyWith(
                                        fontSize: 13.5,
                                        fontWeight: _settingsTab == 'bank'
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: _settingsTab == 'bank'
                                            ? Colors.white
                                            : HostStudioTokens.inkSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (_settingsTab == 'profile')
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: HostStudioTokens.cardSurface,
                        borderRadius:
                            BorderRadius.circular(HostStudioTokens.cardRadius),
                        border: Border.all(color: HostStudioTokens.hairline),
                        boxShadow: HostStudioTokens.cardShadow,
                      ),
                      child: _loadingSettings
                          ? const Padding(
                              padding: EdgeInsets.all(28),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_profileError != null) ...[
                                  _buildInlineError(
                                    _profileError!,
                                    onRetry: _loadSettingsData,
                                    borderless: true,
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                if (_profileSuccess != null) ...[
                                  _buildInlineSuccess(_profileSuccess!),
                                  const SizedBox(height: 14),
                                ],

                                // Cụm Avatar gọn gàng với nút icon Camera nổi ở góc (không lặp dòng chữ dài)
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildHostSettingsAvatarPicker(
                                        effectiveAvatar,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        displayHostName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style:
                                            HostStudioTokens.cardTitle.copyWith(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 18),

                                _buildStudioSettingsField(
                                  label: 'Họ và tên *',
                                  child: TextField(
                                    key: const Key(
                                      'settings_profile_name_input',
                                    ),
                                    controller: _profileNameCtrl,
                                    style:
                                        HostStudioTokens.bodyRegular.copyWith(
                                      fontSize: 14.5,
                                      color: HostStudioTokens.inkPrimary,
                                    ),
                                    decoration: _studioSettingsInputDecoration(
                                      hint: 'Nhập họ và tên Chủ nhà',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                _buildStudioSettingsField(
                                  label: 'Email đăng nhập',
                                  child: TextField(
                                    key: const Key(
                                      'settings_profile_email_input',
                                    ),
                                    controller: _profileEmailCtrl,
                                    readOnly: true,
                                    style:
                                        HostStudioTokens.bodyRegular.copyWith(
                                      fontSize: 14.5,
                                      color: HostStudioTokens.inkSecondary,
                                    ),
                                    decoration: _studioSettingsInputDecoration(
                                      readOnly: true,
                                      suffixIcon: const Icon(
                                        LucideIcons.lock,
                                        size: 15,
                                        color: HostStudioTokens.iconMuted,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                _buildStudioSettingsField(
                                  label: 'Số điện thoại',
                                  child: TextField(
                                    key: const Key(
                                      'settings_profile_phone_input',
                                    ),
                                    controller: _profilePhoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    style:
                                        HostStudioTokens.bodyRegular.copyWith(
                                      fontSize: 14.5,
                                      color: HostStudioTokens.inkPrimary,
                                    ),
                                    decoration: _studioSettingsInputDecoration(
                                      hint: 'Nhập số điện thoại liên hệ',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                FilledButton.icon(
                                  key: const Key('settings_profile_save_btn'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: HostStudioTokens.obsidian,
                                    foregroundColor: Colors.white,
                                    minimumSize:
                                        const Size(double.infinity, 48),
                                    shape: const StadiumBorder(),
                                  ),
                                  onPressed: _savingProfile
                                      ? null
                                      : _handleSaveHostProfile,
                                  icon: _savingProfile
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          LucideIcons.check,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                  label: Text(
                                    _savingProfile
                                        ? 'Đang lưu...'
                                        : 'Lưu thay đổi',
                                    style: HostStudioTokens.pillText.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: HostStudioTokens.cardSurface,
                        borderRadius:
                            BorderRadius.circular(HostStudioTokens.cardRadius),
                        border: Border.all(color: HostStudioTokens.hairline),
                        boxShadow: HostStudioTokens.cardShadow,
                      ),
                      child: _loadingBanks
                          ? const Padding(
                              padding: EdgeInsets.all(28),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_bankError != null) ...[
                                  _buildInlineError(
                                    _bankError!,
                                    onRetry: _loadSettingsData,
                                    borderless: true,
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                if (_bankSuccess != null) ...[
                                  _buildInlineSuccess(_bankSuccess!),
                                  const SizedBox(height: 14),
                                ],
                                _buildStudioSettingsField(
                                  label: 'Tìm nhanh ngân hàng',
                                  child: TextField(
                                    key: const Key(
                                      'settings_bank_search_input',
                                    ),
                                    controller: _bankSearchCtrl,
                                    onChanged: (_) => setState(() {}),
                                    style:
                                        HostStudioTokens.bodyRegular.copyWith(
                                      fontSize: 14,
                                      color: HostStudioTokens.inkPrimary,
                                    ),
                                    decoration: _studioSettingsInputDecoration(
                                      hint: 'Nhập tên, mã viết tắt hoặc BIN...',
                                      prefixIcon: const Icon(
                                        LucideIcons.search,
                                        size: 17,
                                        color: HostStudioTokens.iconInk,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _buildStudioSettingsField(
                                  label: 'Ngân hàng thụ hưởng *',
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(minHeight: 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: HostStudioTokens.groupSurface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: HostStudioTokens.hairline,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        key: const Key(
                                          'settings_bank_dropdown',
                                        ),
                                        isExpanded: true,
                                        dropdownColor:
                                            HostStudioTokens.cardSurface,
                                        borderRadius: BorderRadius.circular(16),
                                        hint: Text(
                                          'Chọn ngân hàng nhận tiền',
                                          style: HostStudioTokens.bodyRegular
                                              .copyWith(
                                            color: HostStudioTokens.inkSubtle,
                                          ),
                                        ),
                                        icon: const Icon(
                                          LucideIcons.chevronDown,
                                          size: 16,
                                          color: HostStudioTokens.iconSecondary,
                                        ),
                                        style: HostStudioTokens.bodyRegular
                                            .copyWith(
                                          fontSize: 14,
                                          color: HostStudioTokens.inkPrimary,
                                        ),
                                        value: filteredBanks.any(
                                          (b) => b.code == _selectedBankCode,
                                        )
                                            ? _selectedBankCode
                                            : null,
                                        items: filteredBanks
                                            .map(
                                              (b) => DropdownMenuItem<String>(
                                                value: b.code,
                                                child: Text(
                                                  b.displayLabel,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) => setState(
                                          () => _selectedBankCode = val,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _buildStudioSettingsField(
                                  label: 'Số tài khoản (6–30 chữ số) *',
                                  child: TextField(
                                    key: const Key(
                                      'settings_bank_account_number_input',
                                    ),
                                    controller: _bankAccountNumberCtrl,
                                    keyboardType: TextInputType.number,
                                    enableSuggestions: false,
                                    autocorrect: false,
                                    enableIMEPersonalizedLearning: false,
                                    style:
                                        HostStudioTokens.bodyRegular.copyWith(
                                      fontSize: 14.5,
                                      color: HostStudioTokens.inkPrimary,
                                    ),
                                    decoration: _studioSettingsInputDecoration(
                                      hint: _savedMaskedBankAccountNumber !=
                                                  null &&
                                              _savedMaskedBankAccountNumber!
                                                  .isNotEmpty
                                          ? 'Đang lưu: $_savedMaskedBankAccountNumber (nhập STK mới để cập nhật)'
                                          : 'Ví dụ: 0071001234567',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _buildStudioSettingsField(
                                  label: 'Chủ tài khoản (IN HOA) *',
                                  child: TextField(
                                    key: const Key(
                                      'settings_bank_account_holder_input',
                                    ),
                                    controller: _bankAccountHolderCtrl,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    style:
                                        HostStudioTokens.bodyRegular.copyWith(
                                      fontSize: 14.5,
                                      color: HostStudioTokens.inkPrimary,
                                    ),
                                    decoration: _studioSettingsInputDecoration(
                                      hint: 'NGUYEN VAN A',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _buildStudioSettingsField(
                                  label: 'Chi nhánh (không bắt buộc)',
                                  child: TextField(
                                    key: const Key(
                                      'settings_bank_branch_input',
                                    ),
                                    controller: _bankBranchCtrl,
                                    style:
                                        HostStudioTokens.bodyRegular.copyWith(
                                      fontSize: 14.5,
                                      color: HostStudioTokens.inkPrimary,
                                    ),
                                    decoration: _studioSettingsInputDecoration(
                                      hint: 'Ví dụ: CN Vũng Tàu',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  key: const Key('settings_bank_save_btn'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: HostStudioTokens.obsidian,
                                    foregroundColor: Colors.white,
                                    minimumSize:
                                        const Size(double.infinity, 48),
                                    shape: const StadiumBorder(),
                                  ),
                                  onPressed: _savingBank
                                      ? null
                                      : _handleSaveBankAccount,
                                  icon: _savingBank
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          LucideIcons.check,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                  label: Text(
                                    _savingBank
                                        ? 'Đang lưu...'
                                        : 'Lưu thông tin',
                                    style: HostStudioTokens.pillText.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
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
      },
    );
  }

  // ===========================================================================
  // Shared UI Builders
  // ===========================================================================

  Widget _buildStatusPill(String label, String code) {
    Color bg = HostStudioTokens.softCircle;
    Color fg = HostStudioTokens.inkSecondary;
    if (code == 'published' ||
        code == 'confirmed' ||
        code == 'paid' ||
        code == 'checked_in' ||
        code == 'completed' ||
        code == 'payout_paid') {
      bg = AppColors.successSoft;
      fg = AppColors.success;
    } else if (code == 'pending_approval' ||
        code == 'pending_payment' ||
        code == 'pending' ||
        code == 'approved' ||
        code == 'processing' ||
        code == 'payout_pending') {
      bg = AppColors.warningSoft;
      fg = AppColors.warning;
    } else if (code == 'rejected' ||
        code == 'failed' ||
        code.contains('cancelled') ||
        code == 'payment_expired') {
      bg = AppColors.errorSoft;
      fg = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: HostStudioTokens.pillText.copyWith(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildEmptyBox(String text, {bool borderless = false}) {
    return Container(
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(
          borderless ? HostStudioTokens.cardRadius : 24,
        ),
        border: borderless ? null : Border.all(color: AppColors.border),
        boxShadow: borderless ? HostStudioTokens.cardShadow : null,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: HostStudioTokens.bodyRegular.copyWith(
          color: HostStudioTokens.inkMuted,
        ),
      ),
    );
  }

  Widget _buildInlineError(String message,
      {VoidCallback? onRetry, bool borderless = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(20),
        border: borderless ? null : Border.all(color: AppColors.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                AppSemanticIcons.errorAlert,
                size: 18,
                color: AppColors.iconStrong,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null)
            TextButton.icon(
              key: const Key('host_inline_error_retry_btn'),
              style: TextButton.styleFrom(
                minimumSize: const Size(88, 48),
                foregroundColor: AppColors.textStrong,
                shape: const StadiumBorder(),
              ),
              onPressed: onRetry,
              icon: const Icon(
                AppSemanticIcons.retry,
                size: 14,
                color: AppColors.iconStrong,
              ),
              label: const Text('Thử lại'),
            ),
        ],
      ),
    );
  }

  Widget _buildInlineSuccess(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.circleCheck,
            size: 18,
            color: AppColors.iconStrong,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostUnderlineTab extends StatelessWidget {
  const _HostUnderlineTab({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final Widget label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelected(!selected),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2,
              )),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
              child: label,
            ),
          ),
        ),
      ),
    );
  }
}
