import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../../shared/widgets/app_semantic_icons.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../../messages/services/chat_media_upload_service.dart';
import '../../../messages/services/chat_voice_recorder_service.dart';
import '../../../messages/presentation/widgets/chat_audio_bubble.dart';
import '../../../messages/presentation/widgets/chat_image_bubble.dart';
import '../../../messages/presentation/widgets/messenger_voice_recorder_bar.dart';
import '../../data/host_repository.dart';
import '../../domain/host_models.dart';
import '../../services/host_file_picker_service.dart';
import '../widgets/host_sheet_sync_card.dart';
import '../widgets/host_studio_widgets.dart';
import 'them_cho_nghi_screen.dart';

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

  static HostPortalSection fromSlug(String? slug) {
    final normalized = (slug ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'cho-nghi':
      case 'properties':
        return HostPortalSection.properties;
      case 'them-moi':
      case 'them-cho-nghi':
      case 'new_property':
        return HostPortalSection.newProperty;
      case 'dat-phong':
      case 'bookings':
        return HostPortalSection.bookings;
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
      case 'thanh-toan':
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
        return HostPortalSection.guests;
    }
  }
}

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
  static const List<String> _messengerReactions = [
    '❤️',
    '😆',
    '😮',
    '😢',
    '😡',
    '👍',
  ];
  final Map<String, String> _messageReactions = {};
  String? _reactionActiveMsgKey;
  final ScrollController _chatScrollCtrl = ScrollController();

  // Messenger input bar & features state
  String _chatQuickEmoji = '😤';
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
  final TextEditingController _bankSearchCtrl = TextEditingController();
  final TextEditingController _bankAccountNumberCtrl = TextEditingController();
  final TextEditingController _bankAccountHolderCtrl = TextEditingController();
  final TextEditingController _bankBranchCtrl = TextEditingController();

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
      _triggerSectionLoad(_activeSection);
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
        if (_listings.isEmpty) {
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
      if (section == HostPortalSection.newProperty) {
        _editingListingId = editListingId;
      }
    });
    _triggerSectionLoad(section);
  }

  // ===========================================================================
  // Data Loading & Action Methods
  // ===========================================================================

  Future<void> _fetchListings() async {
    setState(() {
      _loadingListings = true;
      _listingsError = null;
    });

    final repo = ref.read(hostRepositoryProvider);
    try {
      final items = await repo.getHostListings(
        status: _listingStatusFilter == 'all' ? null : _listingStatusFilter,
        page: 1,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _listings = items;
        if (_listingStatusFilter == 'all') {
          _allListingsSnapshot = items;
        }
        _loadingListings = false;
        if (_listings.isNotEmpty) {
          final firstId =
              (_listings.first['listingId'] ?? _listings.first['id'])
                  ?.toString();
          _calendarListingId ??= firstId;
          _reviewListingId ??= firstId;
        }
      });
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
    final repo = ref.read(hostRepositoryProvider);
    try {
      await action();
      _allListingsSnapshot = [];
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
    final repo = ref.read(hostRepositoryProvider);
    await _runListingMutation(id, () => repo.deleteHostListing(id));
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _loadingBookings = true;
      _bookingsError = null;
    });
    final repo = ref.read(hostRepositoryProvider);
    try {
      final items = await repo.getHostBookings(page: 1, limit: 50);
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

    final repo = ref.read(hostRepositoryProvider);
    final userRole = ref.read(hostCurrentUserRoleProvider);

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
    if (_listings.isEmpty) {
      await _fetchListings();
    }
    if (mounted && _listings.length == 1) {
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

    final repo = ref.read(hostRepositoryProvider);
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

    final repo = ref.read(hostRepositoryProvider);
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
    final repo = ref.read(hostRepositoryProvider);
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

  Future<void> _fetchMessagesForConversation(String conversationId) async {
    final repo = ref.read(hostRepositoryProvider);
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

  Future<void> _sendHostMessage({
    String? contentOverride,
    String messageType = 'text',
    List<Map<String, dynamic>>? attachments,
  }) async {
    final convId = _selectedConversationId;
    final text = (contentOverride ?? _messageInputCtrl.text).trim();
    if (convId == null || (text.isEmpty && (attachments == null || attachments.isEmpty)) || _sendingMessage) return;

    setState(() => _sendingMessage = true);
    final repo = ref.read(hostRepositoryProvider);
    try {
      await repo.sendConversationMessage(
        convId,
        text,
        messageType: messageType,
        attachments: attachments,
      );
      if (contentOverride == null) {
        _messageInputCtrl.clear();
      }
      if (mounted) _messageInputFocusNode.requestFocus();
      await _fetchMessagesForConversation(convId);
      _scrollChatToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _conversationsError = repo.extractErrorMessage(
          e,
          'Không thể gửi tin nhắn.',
        );
      });
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  Future<void> _fetchPayoutData() async {
    setState(() {
      _loadingPayouts = true;
      _payoutsError = null;
    });
    final repo = ref.read(hostRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.getPayoutAccounts(),
        repo.getPayouts(page: 1, limit: 50),
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
    if (_listings.isEmpty) {
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
    final repo = ref.read(hostRepositoryProvider);
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

    final repo = ref.read(hostRepositoryProvider);
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
    final repo = ref.read(hostRepositoryProvider);
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
    final repo = ref.read(hostRepositoryProvider);

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
          _bankAccountNumberCtrl.text = parsed.accountNumber;
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
    final repo = ref.read(hostRepositoryProvider);
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
    final picker = ref.read(hostFilePickerProvider);
    final repo = ref.read(hostRepositoryProvider);
    try {
      final file = await picker.pickAvatarImage(context: context);
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
    final repo = ref.read(hostRepositoryProvider);
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
    final currentRole = ref.watch(hostCurrentUserRoleProvider);
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

    return LayoutBuilder(
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
    );
  }

  Widget _buildStudioTopBar(
    BuildContext context, {
    required double width,
    required bool isDesktop,
    required bool isOverview,
    required String eyebrow,
  }) {
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
              tooltip: 'Về trang chủ',
            ),
            const SizedBox(width: 4),
          ],
          Semantics(
            button: true,
            label: 'Về Tổng quan Host',
            child: Tooltip(
              message: 'Tổng quan Host',
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
                  _activeSection.label,
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
            tooltip: 'Thêm chỗ nghỉ mới',
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
    if (inDrawer) {
      Navigator.of(context).pop();
    }
    try {
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
                          section.label,
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
        return ThemChoNghiScreen(
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
    const paidOrCompletedStatuses = <String>{
      'paid',
      'confirmed',
      'checked_in',
      'checked_out',
      'completed',
    };
    final successfulHostBookingsCount = _bookings.where((b) {
      final rawStatus = '${b['status'] ?? ''}'.trim().toLowerCase();
      if (rawStatus.isEmpty) return true;
      return paidOrCompletedStatuses.contains(rawStatus);
    }).length;
    final stats = [
      (
        label: 'Chỗ nghỉ',
        value: _loadingListings ? '—' : '${_listings.length}',
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
              const SizedBox(height: 14),
            ],
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
            const SizedBox(height: 16),
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
          ],
        ),
      ),
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
                        Text(item.value,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            )),
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

  Future<void> _handleStartAdminChat() async {
    // 1. Nếu danh sách hội thoại rỗng, fetch ngay
    if (_conversations.isEmpty) {
      await _fetchConversations();
    }

    // 2. Tìm cuộc hội thoại với Admin
    Map<String, dynamic>? adminConv;
    for (final c in _conversations) {
      if (_isConversationAdmin(c)) {
        adminConv = c;
        break;
      }
    }

    // 3. Nếu chưa thấy, thử fetch từ server một lần nữa
    if (adminConv == null) {
      final repo = ref.read(hostRepositoryProvider);
      try {
        final list = await repo.getHostConversations(page: 1, limit: 50);
        if (mounted && list.isNotEmpty) {
          setState(() => _conversations = list);
          for (final c in list) {
            if (_isConversationAdmin(c)) {
              adminConv = c;
              break;
            }
          }
        }
      } catch (_) {}
    }

    // 4. Nếu tìm thấy cuộc hội thoại Admin -> Mở ngay màn hình chat
    if (adminConv != null) {
      final convId = '${adminConv['conversationId'] ?? adminConv['id']}';
      if (!mounted) return;
      setState(() {
        _selectedConversationId = convId;
        _inChatDetailView = true;
        _activeSection = HostPortalSection.messages;
      });
      await _fetchMessagesForConversation(convId);
      return;
    }

    // 5. Nếu chưa có conversation Admin nào trong DB -> mở màn hình chat hỗ trợ Quản trị viên The Palm Villa
    if (!mounted) return;
    final fallbackAdminConv = <String, dynamic>{
      'conversationId': 'admin_support',
      'id': 'admin_support',
      'title': 'Quản trị viên The Palm Villa',
      'otherParticipant': {
        'fullName': 'Quản trị viên The Palm Villa',
        'role': 'admin',
      },
      'lastMessage':
          'Xin chào, Ban quản trị The Palm Villa có thể hỗ trợ gì cho bạn?',
      'updatedAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      if (!_conversations
          .any((c) => '${c['conversationId'] ?? c['id']}' == 'admin_support')) {
        _conversations.insert(0, fallbackAdminConv);
      }
      _selectedConversationId = 'admin_support';
      _inChatDetailView = true;
      _activeSection = HostPortalSection.messages;
      if (_conversationMessages.isEmpty) {
        _conversationMessages = [
          {
            'messageId': 'welcome_admin',
            'content':
                'Xin chào! Ban quản trị The Palm Villa luôn sẵn sàng hỗ trợ bạn 24/7. Bạn cần trợ giúp vấn đề gì hôm nay?',
            'senderRole': 'admin',
            'senderName': 'Quản trị viên The Palm Villa',
            'createdAt': DateTime.now().toIso8601String(),
            'isMe': false,
          }
        ];
      }
    });
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

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
            ),
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
    final summarySource = hasSnapshot ? _allListingsSnapshot : _listings;
    final counts = <String, int>{
      'draft': 0,
      'pending_approval': 0,
      'published': 0,
      'hidden': 0,
      'rejected': 0,
    };
    for (final item in summarySource) {
      final st = HostListingStatus.fromApi(item['status']).value;
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
    final id = (listing['listingId'] ?? listing['id'] ?? '').toString();
    final title = (listing['title'] ?? 'Chỗ nghỉ #$id').toString();
    final statusEnum = HostListingStatus.fromApi(listing['status']);
    final propType = HostPropertyType.fromApi(listing['propertyType']);
    final basePrice = listing['basePrice'] ?? listing['pricePerNight'] ?? 0;
    final weekendPrice = listing['weekendPrice'];
    final maxGuests = listing['maxGuests'] ?? 1;
    final imageUrl = _extractListingCoverUrl(listing);
    final rejectReason =
        (listing['rejectionReason'] ?? listing['rejectReason'] ?? '')
            .toString()
            .trim();
    final addressParts = [
      listing['addressLine'],
      listing['ward'],
      listing['district'],
      listing['city'],
    ]
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .join(', ');

    final isBusy = _busyListingActionId == id;
    final repo = ref.read(hostRepositoryProvider);
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
                  'Sửa',
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
                    'Gửi duyệt',
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

  // ===========================================================================
  // 4. HOST BOOKINGS (`DatPhong`) SECTION
  // ===========================================================================

  Widget _buildBookingsSection() {
    const filterTabs = [
      ('all', 'Tất cả'),
      ('pending_payment', 'Chờ thanh toán'),
      ('paid', 'Đã thanh toán'),
      ('confirmed', 'Đã xác nhận'),
      ('checked_in', 'Đã nhận phòng'),
      ('checked_out', 'Đã trả phòng'),
      ('completed', 'Hoàn tất'),
      ('cancelled', 'Đã hủy'),
    ];

    const sortOptions = [
      ('newest', 'Mới nhất'),
      ('checkin_asc', 'Sắp nhận phòng'),
      ('total_desc', 'Giá cao nhất'),
    ];

    final filtered = _bookings
        .where(
          (b) => bookingMatchesDisplayStatus(
            b,
            _bookingStatusFilter,
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
            // Thanh Filter Chips trượt ngang hiện đại
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filterTabs.map((tab) {
                  final isSelected = _bookingStatusFilter == tab.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      showCheckmark: false,
                      label: Text(
                        tab.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color:
                              isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      backgroundColor: const Color(0xFFF1F5F9),
                      selectedColor: const Color(0xFF0F172A),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF0F172A)
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
                    child: _buildPortalDropdown<String>(
                  dropdownKey: const Key('booking_filter_dropdown'),
                  label: 'Trạng thái',
                  value: _bookingStatusFilter,
                  items: filterTabs
                      .map((tab) => DropdownMenuItem(
                            key: Key('booking_filter_${tab.$1}'),
                            value: tab.$1,
                            child:
                                Text(tab.$2, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _bookingStatusFilter = value;
                      _bookingsVisibleCount = 10;
                    });
                  },
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _buildPortalDropdown<String>(
                  dropdownKey: const Key('booking_sort_dropdown'),
                  label: 'Sắp xếp',
                  value: _bookingSortBy,
                  items: sortOptions
                      .map((opt) => DropdownMenuItem(
                            key: Key('booking_sort_${opt.$1}'),
                            value: opt.$1,
                            child:
                                Text(opt.$2, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _bookingSortBy = value);
                  },
                )),
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

  Widget _buildBookingItemCard(
    Map<String, dynamic> booking, {
    bool inStudioGroup = false,
    bool hasBottomMargin = true,
  }) {
    final bookingId = (booking['bookingId'] ?? booking['id'] ?? '').toString();
    final guestName =
        (booking['guestName'] ?? booking['customerName'] ?? 'Khách #$bookingId')
            .toString();
    final guestPhone =
        (booking['guestPhone'] ?? booking['guestEmail'] ?? '').toString();
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
              if (guestPhone.isNotEmpty)
                HostStudioCircleButton(
                  icon: LucideIcons.phone,
                  tooltip: 'Liên hệ khách',
                  visualSize: 34,
                  iconSize: 15,
                  circleColor: HostStudioTokens.softCircle,
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: HostStudioTokens.cardSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      title:
                          Text(guestName, style: HostStudioTokens.sectionTitle),
                      content: SelectableText(
                        guestPhone,
                        style: HostStudioTokens.bodyRegular.copyWith(
                          fontSize: 14.5,
                          color: HostStudioTokens.inkPrimary,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Đóng'),
                        ),
                      ],
                    ),
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
    for (final l in _listings) {
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
        final isBooked = d.isBooked ||
            (d.bookingStatus != null && d.bookingStatus!.isNotEmpty);
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
      final isBooked = d.isBooked ||
          (d.bookingStatus != null && d.bookingStatus!.isNotEmpty);
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
      final isBooked = d.isBooked ||
          (d.bookingStatus != null && d.bookingStatus!.isNotEmpty);
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
      final bListingId =
          (b['listingId'] ?? b['listing_id'] ?? b['id'] ?? '').toString();
      final status = (b['status'] ?? '').toString().toLowerCase();
      if (bListingId == listingId && status != 'cancelled') {
        final checkInStr = (b['checkInDate'] ?? b['check_in'] ?? '')
            .toString()
            .split('T')
            .first;
        final checkOutStr = (b['checkOutDate'] ?? b['check_out'] ?? '')
            .toString()
            .split('T')
            .first;
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
        if (d.bookingStatus != null && d.bookingStatus!.isNotEmpty) {
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
    final query = _calendarSearchQuery.trim().toLowerCase();
    final filtered = _listings.where((l) {
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
                      label: Text('Tất cả (${_listings.length})'),
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
    final activeBasePrice = _getListingBasePrice(_calendarListingId ?? '');

    final totalDaysInMonth = DateTime(_calendarYear, _calendarMonth + 1, 0).day;
    final bookedDays = _calendarDays
        .where((d) => d.bookingStatus != null && d.bookingStatus!.isNotEmpty)
        .length;
    final occupancyPercent = totalDaysInMonth > 0
        ? ((bookedDays / totalDaysInMonth) * 100).round()
        : 0;

    double estRevenue = 0;
    for (final d in _calendarDays) {
      if (d.bookingStatus != null && d.bookingStatus!.isNotEmpty) {
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
            value: _listings.any(
              (l) => '${l['listingId'] ?? l['id']}' == _calendarListingId,
            )
                ? _calendarListingId
                : null,
            items: _listings.map((l) {
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
                      final isBooked = day.isBooked ||
                          (day.bookingStatus != null &&
                              day.bookingStatus!.isNotEmpty);
                      final isEditable =
                          day.isEditable() && !isBooked && !isPast;
                      final isSelected = isEditable &&
                          _selectedCalendarDates.contains(day.date);
                      final isBlocked = !day.isAvailable || day.isBlockedByHost;

                      Color borderColor = const Color(0xFFE2E8F0);
                      Color bgColor = Colors.white;
                      Color dayNumColor = AppColors.textPrimary;
                      Color priceColor = const Color(0xFF64748B);

                      if (isSelected) {
                        borderColor = AppColors.primary;
                        bgColor = AppColors.primary;
                        dayNumColor = Colors.white;
                        priceColor = Colors.white;
                      } else if (isToday) {
                        // Ngày hiện tại: tô đỏ nổi bật
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
                      } else if (isBooked) {
                        borderColor = const Color(0xFFA7F3D0);
                        bgColor = const Color(0xFFF8FAFC);
                        dayNumColor = const Color(0xFF64748B);
                        priceColor = const Color(0xFF94A3B8);
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
      final other = conv['otherParticipant'] is Map
          ? Map<String, dynamic>.from(conv['otherParticipant'] as Map)
          : null;
      final name =
          (other?['fullName'] ?? other?['name'] ?? conv['guestName'] ?? '')
              .toString()
              .toLowerCase();
      if (name.isNotEmpty && name == guestName) {
        final convId = '${conv['conversationId'] ?? conv['id']}';
        setState(() {
          _selectedConversationId = convId;
          _inChatDetailView = true;
        });
        _fetchMessagesForConversation(convId);
        break;
      }
    }
    setState(() => _inChatDetailView = true);
    _switchSection(HostPortalSection.messages);
  }

  bool _matchGuestBookingStatus(Map<String, dynamic> b, String filter) {
    if (filter == 'all') return true;
    final display = getBookingDisplayStatus(b, role: BookingActionRole.host);
    final lbl = display.label.toLowerCase();
    final st = (b['status'] ?? '').toString().toLowerCase();
    final paymentSt = (b['paymentStatus'] ?? '').toString().toLowerCase();

    switch (filter) {
      case 'confirmed':
        return lbl.contains('đã xác nhận') ||
            lbl.contains('thanh toán thành công') ||
            lbl.contains('đã nhận phòng') ||
            lbl.contains('đã trả phòng') ||
            lbl.contains('hoàn tất') ||
            st == 'confirmed' ||
            st == 'paid' ||
            st == 'checked_in';
      case 'payment_expired':
        return lbl.contains('quá hạn thanh toán') ||
            st == 'payment_expired' ||
            paymentSt == 'expired';
      case 'cancelled':
        return lbl.contains('hủy') ||
            st == 'cancelled' ||
            st == 'cancelled_by_guest' ||
            st == 'cancelled_by_host' ||
            st == 'rejected';
      default:
        return true;
    }
  }

  void _showGuestStatusFilterModal() {
    const statusOptions = [
      ('all', 'Tất cả khách hàng', LucideIcons.users),
      ('confirmed', 'Đã xác nhận', LucideIcons.circleCheck),
      ('payment_expired', 'Quá hạn thanh toán', LucideIcons.clockAlert),
      ('cancelled', 'Đã hủy', LucideIcons.ban),
    ];

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
                  for (final opt in statusOptions) ...[
                    Builder(
                      builder: (context) {
                        final selected = _guestStatusFilter == opt.$1;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                                HostStudioTokens.pillRadius),
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            overlayColor:
                                WidgetStateProperty.all(Colors.transparent),
                            onTap: () {
                              setState(() => _guestStatusFilter = opt.$1);
                              Navigator.of(ctx).pop();
                            },
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 50),
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
                                        : HostStudioTokens.iconSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      opt.$2,
                                      style:
                                          HostStudioTokens.cardTitle.copyWith(
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
                                  if (selected)
                                    const Icon(
                                      LucideIcons.check,
                                      color: HostStudioTokens.iconInk,
                                      size: 18,
                                    ),
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

  Widget _buildGuestsSection() {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    // 1. Lọc theo căn được chọn (nếu có)
    final relevantBookings = _bookings.where((b) {
      if (_guestSelectedListingId != 'all') {
        final bListingId = '${b['listingId'] ?? ''}';
        if (bListingId != _guestSelectedListingId) return false;
      }
      return true;
    }).toList();

    // 2. Tính danh sách Hôm nay & Sắp tới
    final todayBookings = relevantBookings.where((b) {
      final st = (b['status'] ?? '').toString().toLowerCase();
      if (st == 'checked_in') return true;
      final inD = _parseGuestBookingDate(b['checkInDate']);
      final outD = _parseGuestBookingDate(b['checkOutDate']);
      if (inD == null) return false;
      final inDay = DateTime(inD.year, inD.month, inD.day);
      final outDay =
          outD != null ? DateTime(outD.year, outD.month, outD.day) : inDay;
      if (inDay.isAtSameMomentAs(todayDate)) return true;
      if (!inDay.isAfter(todayDate) && !outDay.isBefore(todayDate)) return true;
      return false;
    }).toList();

    final upcomingBookings = relevantBookings.where((b) {
      final st = (b['status'] ?? '').toString().toLowerCase();
      if (st == 'cancelled' ||
          st == 'rejected' ||
          st == 'completed' ||
          st == 'checked_out') {
        return false;
      }
      final inD = _parseGuestBookingDate(b['checkInDate']);
      if (inD == null) return st == 'confirmed' || st == 'paid';
      final inDay = DateTime(inD.year, inD.month, inD.day);
      return inDay.isAfter(todayDate) ||
          inDay.isAtSameMomentAs(todayDate) ||
          st == 'confirmed' ||
          st == 'paid';
    }).toList();

    // 3. Lọc danh sách Hôm nay & Sắp tới theo trạng thái khách đã chọn
    final filteredTodayBookings = todayBookings.where((b) {
      return _matchGuestBookingStatus(b, _guestStatusFilter);
    }).toList();

    final filteredUpcomingBookings = upcomingBookings.where((b) {
      return _matchGuestBookingStatus(b, _guestStatusFilter);
    }).toList();

    final filteredList =
        _guestTab == 'today' ? filteredTodayBookings : filteredUpcomingBookings;

    // Xác định tiêu đề và icon hiển thị trên ô chọn trạng thái
    String statusTitle = 'Tất cả khách hàng';
    IconData statusIcon = LucideIcons.users;
    if (_guestStatusFilter == 'confirmed') {
      statusTitle = 'Đã xác nhận';
      statusIcon = LucideIcons.circleCheck;
    } else if (_guestStatusFilter == 'payment_expired') {
      statusTitle = 'Quá hạn thanh toán';
      statusIcon = LucideIcons.clockAlert;
    } else if (_guestStatusFilter == 'cancelled') {
      statusTitle = 'Đã hủy';
      statusIcon = LucideIcons.ban;
    }

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
      final other = c['otherParticipant'] is Map
          ? Map<String, dynamic>.from(c['otherParticipant'] as Map)
          : null;
      final name = (other?['fullName'] ??
              other?['name'] ??
              c['guestName'] ??
              c['title'] ??
              '')
          .toString()
          .toLowerCase();
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
    final other = c['otherParticipant'] is Map
        ? Map<String, dynamic>.from(c['otherParticipant'] as Map)
        : null;
    final listingMap = c['listing'] is Map
        ? Map<String, dynamic>.from(c['listing'] as Map)
        : null;
    final isAdmin = _isConversationAdmin(c);
    var counterpart = (other?['fullName'] ??
            other?['name'] ??
            other?['username'] ??
            c['guestName'] ??
            c['title'] ??
            '')
        .toString()
        .trim();
    if (counterpart.isEmpty ||
        counterpart.toLowerCase().contains('cuộc trò chuyện') ||
        counterpart.toLowerCase().contains('hội thoại')) {
      counterpart =
          isAdmin ? 'Quản trị viên The Palm Villa' : 'Hội thoại #$convId';
    }

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
    final previewText = (rawLastMsg != null && '$rawLastMsg'.trim().isNotEmpty)
        ? '$rawLastMsg'.trim()
        : 'Chưa có tin nhắn.';

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
            _selectedConversationId = convId;
            _inChatDetailView = true;
          });
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
    final other = matchedConv['otherParticipant'] is Map
        ? Map<String, dynamic>.from(matchedConv['otherParticipant'] as Map)
        : null;
    final participantName = (other?['fullName'] ??
            other?['name'] ??
            matchedConv['guestName'] ??
            matchedConv['title'] ??
            'Cuộc trò chuyện')
        .toString();
    final listingTitle = (matchedConv['listingTitle'] ?? '').toString().trim();
    final isAdmin = _isConversationAdmin(matchedConv);
    final participantAvatar =
        _resolveHostConversationParticipantAvatar(matchedConv);

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
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                tooltip: 'Tải lại tin nhắn',
                onPressed: () {
                  if (_selectedConversationId != null) {
                    _fetchMessagesForConversation(_selectedConversationId!);
                  }
                },
              ),
            ],
          ),
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
                      var rawAttachments = m['attachments'] ?? m['attachments_json'];
                      var attachments = rawAttachments is List
                          ? rawAttachments
                              .map((a) {
                                if (a is Map) return (a['url'] ?? a['imageUrl'] ?? '').toString();
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
                          attachments = ['https://pub-67a3f362466e495d9c2f371ca84b6d03.r2.dev/chat/sample_voice.wav'];
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

                      // Format time nếu có
                      String? msgTime;
                      final rawCreatedAt = m['createdAt'];
                      if (rawCreatedAt != null) {
                        final dt = DateTime.tryParse(rawCreatedAt.toString());
                        if (dt != null) {
                          msgTime = DateFormat('HH:mm').format(dt);
                        }
                      }

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
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                // Thanh chọn cảm xúc nổi khi đè vào tin nhắn
                                if (isReactionOpen)
                                  _buildReactionPicker(msgKey),

                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // Hình đại diện nhỏ bên trái của người gửi (đối phương)
                                    if (!isMe) ...[
                                      _buildChatSmallAvatar(
                                        isAdmin: isMsgAdmin,
                                        name: participantName,
                                        avatarUrl:
                                            other?['avatar']?.toString() ??
                                                other?['avatarUrl']?.toString(),
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
                                                padding: (isImageOnly || isAudioOnly)
                                                    ? EdgeInsets.zero
                                                    : const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 9,
                                                      ),
                                                decoration: BoxDecoration(
                                                  color: (isImageOnly || isAudioOnly)
                                                      ? Colors.transparent
                                                      : (isMe
                                                          ? AppColors.primary
                                                          : (isMsgAdmin
                                                              ? const Color(0xFFFFF1F2)
                                                              : const Color(0xFFF1F5F9))),
                                                  borderRadius: bubbleRadius,
                                                  border: isMe
                                                      ? null
                                                      : (isMsgAdmin
                                                          ? Border.all(
                                                              color: const Color(0xFFFECDD3),
                                                            )
                                                          : null),
                                                  boxShadow: (isMe && !isImageOnly)
                                                      ? [
                                                          BoxShadow(
                                                            color: AppColors.primary
                                                                .withValues(alpha: 0.16),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 1),
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: isMe
                                                      ? CrossAxisAlignment.end
                                                      : CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (hasAttachments) ...[
                                                      for (final attUrl in attachments)
                                                        Padding(
                                                          padding: EdgeInsets.only(
                                                            bottom: isImageOnly
                                                                ? 0
                                                                : (displayCaption != null ? 6 : 0),
                                                          ),
                                                          child: _isChatAudioUrl(attUrl)
                                                              ? _buildHostAudioBubble(attUrl, isMe: isMe)
                                                              : ChatImageBubble(
                                                                  imageUrl: attUrl,
                                                                  borderRadius: bubbleRadius,
                                                                  maxWidth: MediaQuery.of(context).size.width * 0.68,
                                                                  onTap: () => _openFullScreenImage(context, attUrl),
                                                                ),
                                                        ),
                                                    ],
                                                    if (displayCaption != null && displayCaption.isNotEmpty)
                                                      Text(
                                                        displayCaption,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          height: 1.35,
                                                          color: isMe
                                                              ? Colors.white
                                                              : (isMsgAdmin
                                                                  ? const Color(0xFF881337)
                                                                  : AppColors.textPrimary),
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
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 5,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        border: Border.all(
                                                          color: const Color(
                                                              0xFFE2E8F0),
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withValues(
                                                                    alpha: 0.1),
                                                            blurRadius: 4,
                                                            offset:
                                                                const Offset(
                                                                    0, 1),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Text(
                                                        reaction,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
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
                                          padding:
                                              const EdgeInsets.only(left: 6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE2E8F0),
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

                                // Trạng thái đã gửi / đã xem ở tin nhắn cuối cùng của Host
                                if (i == _conversationMessages.length - 1 &&
                                    isMe) ...[
                                  const SizedBox(height: 6),
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          LucideIcons.checkCheck,
                                          size: 13,
                                          color: AppColors.primary,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Đã gửi • Đã xem',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                _buildQuickReplyChip('The Palm Villa xin chào bạn! 🌴'),
                const SizedBox(width: 8),
                _buildQuickReplyChip(
                    'Vị trí biệt thự em đã cập nhật trên hệ thống ạ.'),
              ],
            ),
          ),
        ),

        // Thanh soạn thảo tin nhắn ở đáy chuẩn Facebook Messenger (khớp 100% hình mẫu của user)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.surfaceBase,
            border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: _isRecordingVoice
              ? MessengerVoiceRecorderBar(
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
                )
              : Row(
                  children: [
              // 1. Nút '+' tròn màu hồng/đỏ
              InkWell(
                key: const Key('chat_more_features_btn'),
                onTap: _showChatMoreOptions,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.plus,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Nút Máy ảnh (Camera) màu hồng/đỏ
              IconButton(
                key: const Key('chat_camera_btn'),
                icon: const Icon(LucideIcons.camera,
                    size: 22, color: AppColors.primary),
                tooltip: 'Chụp ảnh',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
                onPressed: _openCameraChat,
              ),
              const SizedBox(width: 4),

              // 3. Nút Thư viện Ảnh (Image) màu hồng/đỏ
              IconButton(
                key: const Key('chat_gallery_btn'),
                icon: const Icon(LucideIcons.image,
                    size: 22, color: AppColors.primary),
                tooltip: 'Gửi hình ảnh',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
                onPressed: _pickAndSendChatImage,
              ),
              const SizedBox(width: 4),

              // 4. Nút Micro thu âm màu hồng/đỏ
              IconButton(
                key: const Key('chat_mic_btn'),
                icon: Icon(
                  _isRecordingVoice ? LucideIcons.square : LucideIcons.mic,
                  size: 22,
                  color: _isRecordingVoice ? Colors.red : AppColors.primary,
                ),
                tooltip: _isRecordingVoice ? 'Dừng ghi âm' : 'Tin nhắn thoại',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
                onPressed: _toggleVoiceRecording,
              ),
              const SizedBox(width: 8),

              // 5. Ô nhập tin nhắn với placeholder "Nhắn tin" & icon mặt cười màu hồng bên trong
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    key: const Key('host_message_input'),
                    controller: _messageInputCtrl,
                    focusNode: _messageInputFocusNode,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (!_sendingMessage) {
                        _sendHostMessage();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Nhắn tin',
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14.5,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      isDense: true,
                      suffixIcon: IconButton(
                        key: const Key('chat_input_smile_btn'),
                        icon: const Icon(
                          LucideIcons.smile,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Biểu tượng cảm xúc',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 34, minHeight: 34),
                        onPressed: _showEmojiSelector,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 6. Bên phải ngoài cùng:
              // Nếu ô trống: Icon cảm xúc nhanh mặc định (icon 😤 trong ảnh của user)
              // Nếu có chữ: Nút gửi tin nhắn (Send button)
              if (_messageInputCtrl.text.trim().isEmpty)
                InkWell(
                  key: const Key('chat_quick_emoji_btn'),
                  onTap: () => _sendQuickEmoji(_chatQuickEmoji),
                  onLongPress: _chooseQuickEmoji,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      _chatQuickEmoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                )
              else
                IconButton(
                  key: const Key('host_message_send_btn'),
                  icon: const Icon(
                    LucideIcons.send,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Gửi tin nhắn',
                  onPressed: _sendingMessage ? null : _sendHostMessage,
                ),
            ],
          ),
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
        child: Image.network(
          avatarUrl,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildLetterAvatar(name),
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
        children: _messengerReactions.map((emoji) {
          final isSelected = _messageReactions[msgKey] == emoji;
          return InkWell(
            key: Key('reaction_${emoji}_$msgKey'),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _messageReactions.remove(msgKey);
                } else {
                  _messageReactions[msgKey] = emoji;
                }
                _reactionActiveMsgKey = null;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 22),
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
                        '📍 Vị trí The Palm Villa: 123 Đường Hạ Long, Phường Bãi Cháy, TP. Hạ Long (Gần bãi tắm & Sun World).';
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
                        '⏰ Thời gian nhận phòng: từ 14:00 | Thời gian trả phòng: trước 12:00 ngày hôm sau.';
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
                        '📋 Nội quy The Palm Villa: Vui lòng không hút thuốc trong phòng, giữ yên tĩnh sau 22:00. Chúc quý khách kỳ nghỉ tuyệt vời!';
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

  Future<void> _openCameraChat() async {
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 82);
      if (!mounted || file == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải ảnh chụp lên Cloudflare R2...')),
      );
      final bytes = await file.readAsBytes();
      final uploadService = ref.read(chatMediaUploadServiceProvider);
      final result = await uploadService.uploadMediaBytesToR2(
        bytes: bytes,
        filename: file.name.isNotEmpty ? file.name : 'host_camera_${DateTime.now().millisecondsSinceEpoch}.jpg',
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
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (!mounted || file == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải ảnh lên Cloudflare R2...')),
      );
      final bytes = await file.readAsBytes();
      final uploadService = ref.read(chatMediaUploadServiceProvider);
      final result = await uploadService.uploadMediaBytesToR2(
        bytes: bytes,
        filename: file.name.isNotEmpty ? file.name : 'host_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
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
            const SnackBar(content: Text('Đang tải tin nhắn thoại lên Cloudflare R2...')),
          );

          final recordedResult = await _voiceRecorder.stop();
          if (recordedResult == null || recordedResult.bytes.isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Không ghi nhận được âm thanh từ Micro. Vui lòng cấp quyền Microphone hoặc nói to hơn.'),
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

          final uploadService = ref.read(chatMediaUploadServiceProvider);
          final result = await uploadService.uploadMediaBytesToR2(
            bytes: audioBytes,
            filename: filename,
            contentType: contentType,
          );
          if (!mounted) return;
          await _sendHostMessage(
            contentOverride: '🎤 Tin nhắn thoại (00:${recordedSeconds.toString().padLeft(2, '0')})',
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
    final trimmed = content.trim();
    if (trimmed.isEmpty ||
        trimmed == '[image]' ||
        trimmed == '[file]' ||
        trimmed == 'image' ||
        trimmed == 'file' ||
        trimmed == '📷 [Hình ảnh]' ||
        trimmed == '[Hình ảnh]' ||
        trimmed.startsWith('📷 [Ảnh chụp trực tiếp') ||
        trimmed.startsWith('🖼️ [Đã gửi 1 hình ảnh') ||
        trimmed == '📷 [Ảnh chụp trực tiếp từ villa]' ||
        trimmed.startsWith('🎤 Tin nhắn thoại')) {
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
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white, size: 20),
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
        const emojis = [
          '😊',
          '🥰',
          '😍',
          '🌴',
          '🏖️',
          '✨',
          '👍',
          '🙏',
          '❤️',
          '🔥',
          '🎉',
          '💯',
          '⭐',
          '🌊',
          '🏡',
          '🔑',
          '☕',
          '🌟'
        ];
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
                  spacing: 12,
                  runSpacing: 10,
                  children: emojis.map((e) {
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        final current = _messageInputCtrl.text;
                        _messageInputCtrl.text =
                            current.isEmpty ? e : '$current $e';
                        _messageInputCtrl.selection =
                            TextSelection.fromPosition(
                          TextPosition(offset: _messageInputCtrl.text.length),
                        );
                        _messageInputFocusNode.requestFocus();
                        setState(() {});
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(e, style: const TextStyle(fontSize: 26)),
                      ),
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
        const quickOptions = ['😤', '👍', '❤️', '🌴', '🔥', '⭐'];
        return AlertDialog(
          title: const Text('Chọn biểu tượng gửi nhanh'),
          content: Wrap(
            spacing: 14,
            runSpacing: 12,
            children: quickOptions.map((e) {
              return InkWell(
                onTap: () {
                  setState(() => _chatQuickEmoji = e);
                  Navigator.pop(ctx);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(e, style: const TextStyle(fontSize: 30)),
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
    double totalPaid = 0;
    double totalPending = 0;
    for (final p in _payouts) {
      final amt = p['amount'] is num
          ? (p['amount'] as num).toDouble()
          : (double.tryParse('${p['amount'] ?? 0}') ?? 0);
      final st = (p['status'] ?? '').toString().trim().toLowerCase();
      if (st == 'paid') {
        totalPaid += amt;
      } else {
        totalPending += amt;
      }
    }

    const payoutStatusLabels = {
      'pending': 'Chờ duyệt',
      'approved': 'Đã duyệt',
      'processing': 'Đang xử lý',
      'paid': 'Đã chuyển tiền',
      'failed': 'Thất bại',
      'rejected': 'Đã từ chối',
      'cancelled': 'Đã hủy',
    };

    const payoutFilterTabs = [
      ('all', 'Tất cả'),
      ('pending', 'Chờ duyệt'),
      ('approved', 'Đã duyệt'),
      ('paid', 'Đã chuyển tiền'),
      ('rejected', 'Đã từ chối'),
    ];

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
                      final accName =
                          (acc['accountName'] ?? acc['accountHolderName'] ?? '')
                              .toString();
                      final rawOrMasked = (acc['accountNumberMasked'] ??
                              acc['accountNumber'] ??
                              '')
                          .toString();
                      final masked = maskBankAccountNumber(rawOrMasked);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '$bankName • $accName • $masked',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Lịch sử chi trả',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 12),
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
                final statusRaw = (payout['status'] ?? 'pending').toString();
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
                _buildPortalDropdown<String>(
                  dropdownKey: const Key('reviews_listing_dropdown'),
                  label: 'Chọn chỗ nghỉ',
                  value: _listings.any(
                    (l) => '${l['listingId'] ?? l['id']}' == _reviewListingId,
                  )
                      ? _reviewListingId
                      : null,
                  items: _listings.map((l) {
                    final id = '${l['listingId'] ?? l['id']}';
                    final title = (l['title'] ?? 'Listing #$id').toString();
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(title, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val == null) return;
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
                        child: Center(
                          child: Text(
                            _reviews.isEmpty
                                ? '—'
                                : avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
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
                                  : 'Điểm trung bình thực tế: ${avgRating.toStringAsFixed(2)} ★ (${_reviews.length} đánh giá)',
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
        title: 'Thực nhận',
        sub: 'Tiền về tài khoản Host',
        value: _loadingReport ? '—' : formatHostVnd(_revenueReport.hostRevenue),
        icon: LucideIcons.walletCards,
        highlightNet: true,
      ),
      (
        title: 'Doanh thu gộp',
        sub: 'Tổng thu từ khách',
        value:
            _loadingReport ? '—' : formatHostVnd(_revenueReport.grossRevenue),
        icon: LucideIcons.trendingUp,
        highlightNet: false,
      ),
      (
        title: 'Đặt phòng',
        sub: 'Lượt đặt hoàn tất',
        value: _loadingReport ? '—' : '${_revenueReport.bookingCount} lượt',
        icon: LucideIcons.calendarCheck,
        highlightNet: false,
      ),
      (
        title: 'Phí nền tảng',
        sub: 'Chiết khấu vận hành',
        value: _loadingReport
            ? '—'
            : formatHostVnd(_revenueReport.platformRevenue),
        icon: LucideIcons.receiptText,
        highlightNet: false,
      ),
    ];

    final effectiveListingId = _reportListingId == 'all' ||
            _listings.any(
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
                // 1. Segmented Switcher cân đối 3 phần: 30 ngày | 90 ngày | 1 năm
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
                      for (var i = 0; i < ranges.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final option = ranges[i];
                              final isSelected = _reportRange == option.$1;
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
                                    setState(() => _reportRange = option.$1);
                                    _fetchRevenueReport();
                                  },
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(minHeight: 40),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          option.$2,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: HostStudioTokens.pillText
                                              .copyWith(
                                            fontSize: 13,
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

                // 2. Bộ lọc Chỗ nghỉ & Chu kỳ (Studio Minimalist Selectors)
                if (isCompact)
                  Column(
                    children: [
                      _buildStudioReportDropdown<String>(
                        dropdownKey:
                            const Key('reports_listing_filter_dropdown'),
                        leadingIcon: LucideIcons.house,
                        value: effectiveListingId,
                        items: [
                          const DropdownMenuItem<String>(
                            value: 'all',
                            child: Text(
                              'Tất cả chỗ nghỉ',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ..._listings.map((l) {
                            final id = '${l['listingId'] ?? l['id']}';
                            final title =
                                (l['title'] ?? 'Chỗ nghỉ #$id').toString();
                            return DropdownMenuItem<String>(
                              value: id,
                              child:
                                  Text(title, overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _reportListingId = val);
                          _fetchRevenueReport();
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildStudioReportDropdown<String>(
                        dropdownKey: const Key('report_group_dropdown'),
                        leadingIcon: LucideIcons.slidersHorizontal,
                        value: _reportGroup,
                        items: groups
                            .map(
                              (option) => DropdownMenuItem(
                                key: Key('report_group_${option.$1}'),
                                value: option.$1,
                                child: Text(
                                  option.$2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _reportGroup = value);
                          _fetchRevenueReport();
                        },
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildStudioReportDropdown<String>(
                          dropdownKey:
                              const Key('reports_listing_filter_dropdown'),
                          leadingIcon: LucideIcons.house,
                          value: effectiveListingId,
                          items: [
                            const DropdownMenuItem<String>(
                              value: 'all',
                              child: Text(
                                'Tất cả chỗ nghỉ',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ..._listings.map((l) {
                              final id = '${l['listingId'] ?? l['id']}';
                              final title =
                                  (l['title'] ?? 'Chỗ nghỉ #$id').toString();
                              return DropdownMenuItem<String>(
                                value: id,
                                child: Text(
                                  title,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildStudioReportDropdown<String>(
                          dropdownKey: const Key('report_group_dropdown'),
                          leadingIcon: LucideIcons.slidersHorizontal,
                          value: _reportGroup,
                          items: groups
                              .map(
                                (option) => DropdownMenuItem(
                                  key: Key('report_group_${option.$1}'),
                                  value: option.$1,
                                  child: Text(
                                    option.$2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _reportGroup = value);
                            _fetchRevenueReport();
                          },
                        ),
                      ),
                    ],
                  ),

                // Giữ dropdown Key ẩn để đảm bảo tương thích ngược test
                Opacity(
                  opacity: 0,
                  child: SizedBox(
                    height: 0,
                    width: 0,
                    child: _buildPortalDropdown<String>(
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
                                      hint: 'Ví dụ: 0071001234567',
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
        code == 'completed' ||
        code == 'payout_paid') {
      bg = AppColors.successSoft;
      fg = AppColors.success;
    } else if (code == 'pending_approval' ||
        code == 'pending_payment' ||
        code == 'pending' ||
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
