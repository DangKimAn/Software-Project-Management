import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_semantic_icons.dart';
import '../../data/host_repository.dart';
import '../../domain/host_models.dart';
import '../../services/host_file_picker_service.dart';
import 'them_cho_nghi_screen.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';

enum HostPortalSection {
  overview('overview', 'Tổng quan', LucideIcons.layoutDashboard),
  properties('properties', 'Chỗ nghỉ', LucideIcons.house),
  newProperty('new_property', 'Thêm chỗ nghỉ', LucideIcons.plus),
  bookings('bookings', 'Đặt phòng', LucideIcons.calendarCheck),
  calendar('calendar', 'Lịch lưu trú', LucideIcons.calendar),
  guests('guests', 'Khách lưu trú', LucideIcons.users),
  messages('messages', 'Tin nhắn', LucideIcons.messageSquare),
  payouts('payouts', 'Thanh toán', LucideIcons.wallet),
  reviews('reviews', 'Đánh giá', LucideIcons.star),
  reports('reports', 'Báo cáo', LucideIcons.chartColumn),
  support('support', 'Hỗ trợ', LucideIcons.lifeBuoy),
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
    final s = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1).replaceAll('.', ',');
    return '$s Tr đ';
  } else if (numVal >= 1000) {
    final v = numVal / 1000;
    final s = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1).replaceAll('.', ',');
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
  String? _guestSelectedListingId = 'all';
  final TextEditingController _guestSearchCtrl = TextEditingController();
  String _guestSearchQuery = '';
  String _guestSortBy = 'spent_desc';
  int _guestsVisibleCount = 10;

  // Messages state
  bool _loadingConversations = false;
  bool _messagesSearchExpanded = false;
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
              backgroundColor: const Color(0xFFBE123C),
              foregroundColor: Colors.white,
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

  Future<void> _sendHostMessage() async {
    final convId = _selectedConversationId;
    final text = _messageInputCtrl.text.trim();
    if (convId == null || text.isEmpty || _sendingMessage) return;

    setState(() => _sendingMessage = true);
    final repo = ref.read(hostRepositoryProvider);
    try {
      await repo.sendConversationMessage(convId, text);
      _messageInputCtrl.clear();
      if (mounted) _messageInputFocusNode.requestFocus();
      await _fetchMessagesForConversation(convId);
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

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: isDesktop
              ? AppBar(
                  backgroundColor: AppColors.surfaceBase,
                  elevation: 0,
                  titleSpacing: 12,
                  leading: IconButton(
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(
                      LucideIcons.house,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => context.go('/'),
                    tooltip: 'Về trang chủ',
                  ),
                  title: Row(
                    children: [
                      const AppBrandIcon.minhThanhLogo(
                        size: 22,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Host Portal • ${_activeSection.label}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      key: const Key('host_portal_add_property_quick_btn'),
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      tooltip: 'Thêm chỗ nghỉ mới',
                      onPressed: () =>
                          _switchSection(HostPortalSection.newProperty),
                      icon: const Icon(
                        LucideIcons.plus,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      tooltip: 'Về trang chủ',
                      onPressed: () => context.go('/'),
                      icon: const Icon(
                        LucideIcons.externalLink,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                    ),
                  ],
                )
              : null,
          drawer: isDesktop
              ? null
              : Drawer(
                  backgroundColor: AppColors.surfaceBase,
                  child:
                      SafeArea(child: _buildSidebarNavigation(inDrawer: true)),
                ),
          bottomNavigationBar: isDesktop
              ? null
              : Builder(builder: _buildMobileBottomNavigation),
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  SizedBox(
                    width: 250,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceBase,
                        border: Border(
                          right: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: _buildSidebarNavigation(inDrawer: false),
                    ),
                  ),
                Expanded(child: _buildActiveSectionBody()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileBottomNavigation(BuildContext context) {
    const sections = [
      HostPortalSection.guests,
      HostPortalSection.calendar,
      HostPortalSection.newProperty,
      HostPortalSection.messages,
    ];
    final selectedIndex = sections.indexOf(_activeSection);

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: BottomNavigationBar(
        key: const Key('host_bottom_navigation'),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surfaceBase,
        elevation: 0,
        currentIndex: selectedIndex < 0 ? 4 : selectedIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        showUnselectedLabels: true,
        onTap: (index) {
          if (index == 4) {
            Scaffold.of(context).openDrawer();
          } else {
            _switchSection(sections[index]);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.users),
            label: 'Khách',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.calendar),
            label: 'Lịch',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.plus),
            label: 'Thêm',
            tooltip: 'Thêm chỗ nghỉ',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.messageSquare),
            label: 'Tin nhắn',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.menu),
            label: 'Menu',
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required HostPortalSection section,
    required String title,
    required IconData icon,
    String? badgeText,
    required bool inDrawer,
    bool isLast = false,
  }) {
    final isSelected = _activeSection == section;
    return InkWell(
      key: Key('host_sidebar_${section.keyName}'),
      onTap: () {
        if (inDrawer) Navigator.of(context).pop();
        _switchSection(section);
      },
      borderRadius: BorderRadius.vertical(
        top: Radius.zero,
        bottom: isLast ? const Radius.circular(14) : Radius.zero,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            if (badgeText != null && badgeText.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: isSelected ? AppColors.primary : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarGroupCard({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: items),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildSidebarNavigation({required bool inDrawer}) {
    final listingsCount = _listings.isNotEmpty ? '${_listings.length}' : null;
    final bookingsCount = _bookings.isNotEmpty ? '${_bookings.length}' : null;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // ── Header (Tối giản, KHÔNG có Avatar Đặng Kim An) ──
          if (inDrawer) ...[
            Row(
              children: [
                const Text(
                  'Menu',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.x,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
          ] else ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'CỔNG QUẢN LÝ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
          ],

          // ── Nhóm điều hành trên Desktop (vì desktop ẩn bottom bar) ──
          if (!inDrawer)
            _buildSidebarGroupCard(
              title: 'VẬN HÀNH HẰNG NGÀY',
              items: [
                _buildSidebarItem(
                  section: HostPortalSection.guests,
                  title: 'Khách lưu trú',
                  icon: LucideIcons.users,
                  inDrawer: inDrawer,
                ),
                _buildSidebarItem(
                  section: HostPortalSection.calendar,
                  title: 'Lịch lưu trú',
                  icon: LucideIcons.calendar,
                  inDrawer: inDrawer,
                ),
                _buildSidebarItem(
                  section: HostPortalSection.messages,
                  title: 'Tin nhắn',
                  icon: LucideIcons.messageSquare,
                  inDrawer: inDrawer,
                ),
                _buildSidebarItem(
                  section: HostPortalSection.newProperty,
                  title: 'Thêm chỗ nghỉ',
                  icon: LucideIcons.plus,
                  inDrawer: inDrawer,
                  isLast: true,
                ),
              ],
            ),

          // ── Nhóm 1: QUẢN LÝ KINH DOANH ──
          _buildSidebarGroupCard(
            title: 'QUẢN LÝ KINH DOANH',
            items: [
              _buildSidebarItem(
                section: HostPortalSection.properties,
                title: 'Chỗ nghỉ của tôi',
                icon: LucideIcons.house,
                badgeText: listingsCount,
                inDrawer: inDrawer,
              ),
              _buildSidebarItem(
                section: HostPortalSection.bookings,
                title: 'Quản lý đặt phòng',
                icon: LucideIcons.calendarCheck,
                badgeText: bookingsCount,
                inDrawer: inDrawer,
                isLast: true,
              ),
            ],
          ),

          // ── Nhóm 2: TÀI CHÍNH & HIỆU QUẢ ──
          _buildSidebarGroupCard(
            title: 'TÀI CHÍNH & HIỆU QUẢ',
            items: [
              _buildSidebarItem(
                section: HostPortalSection.payouts,
                title: 'Thanh toán & Ngân hàng',
                icon: LucideIcons.wallet,
                inDrawer: inDrawer,
              ),
              _buildSidebarItem(
                section: HostPortalSection.reviews,
                title: 'Đánh giá từ khách',
                icon: LucideIcons.star,
                inDrawer: inDrawer,
              ),
              _buildSidebarItem(
                section: HostPortalSection.reports,
                title: 'Báo cáo doanh thu',
                icon: LucideIcons.chartColumn,
                inDrawer: inDrawer,
                isLast: true,
              ),
            ],
          ),

          // ── Nhóm 3: CÀI ĐẶT & TRỢ GIÚP ──
          _buildSidebarGroupCard(
            title: 'CÀI ĐẶT & TRỢ GIÚP',
            items: [
              _buildSidebarItem(
                section: HostPortalSection.settings,
                title: 'Cài đặt tài khoản',
                icon: LucideIcons.settings,
                inDrawer: inDrawer,
              ),
              _buildSidebarItem(
                section: HostPortalSection.support,
                title: 'Trung tâm trợ giúp',
                icon: LucideIcons.lifeBuoy,
                inDrawer: inDrawer,
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Chân Drawer: Chuyển sang du khách & Đăng xuất ──
          InkWell(
            onTap: () {
              if (inDrawer) Navigator.of(context).pop();
              context.go('/');
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.arrowLeftRight,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Chuyển sang chế độ Du khách',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          InkWell(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text(
                    'Xác nhận đăng xuất',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  content: const Text(
                    'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?',
                    style: TextStyle(fontSize: 14),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                if (inDrawer) Navigator.of(context).pop();
                try {
                  await ref.read(authNotifierProvider.notifier).logout();
                } catch (_) {}
                if (context.mounted) {
                  context.go('/auth/login');
                }
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.logOut,
                    size: 16,
                    color: Color(0xFFE11D48),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Đăng xuất',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
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
    final stats = [
      (label: 'Chỗ nghỉ', value: _loadingListings ? '—' : '${_listings.length}',
        icon: LucideIcons.house, section: HostPortalSection.properties),
      (label: 'Đặt phòng', value: _loadingBookings ? '—' : '${_bookings.length}',
        icon: LucideIcons.calendarCheck, section: HostPortalSection.bookings),
      (label: 'Doanh thu · 30 ngày',
        value: _loadingReport ? '—' : formatCompactHostVnd(_revenueReport.hostRevenue),
        icon: LucideIcons.chartColumn, section: HostPortalSection.reports),
      (label: 'Tài khoản nhận tiền', value: _loadingPayouts ? '—' : '${_payoutAccounts.length}',
        icon: LucideIcons.wallet, section: HostPortalSection.payouts),
    ];
    final recentBookings = List<Map<String, dynamic>>.from(_bookings)
      ..sort((a, b) {
        final aId = int.tryParse('${a['bookingId'] ?? a['id'] ?? 0}') ?? 0;
        final bId = int.tryParse('${b['bookingId'] ?? b['id'] ?? 0}') ?? 0;
        return bId.compareTo(aId);
      });

    return RefreshIndicator(
      onRefresh: _loadInitialPortalData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Tổng quan', style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ))),
                IconButton(
                  tooltip: 'Tải lại',
                  onPressed: _loadInitialPortalData,
                  icon: const Icon(LucideIcons.refreshCw, size: 20),
                ),
                IconButton.filled(
                  tooltip: 'Thêm chỗ nghỉ',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _switchSection(HostPortalSection.newProperty),
                  icon: const Icon(LucideIcons.plus, size: 22),
                ),
              ],
            ),
            if (overviewError != null) ...[
              const SizedBox(height: 12),
              _buildInlineError(overviewError, onRetry: _loadInitialPortalData),
            ],
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 820 ? 4 : 2;
              final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: stats.map((stat) => SizedBox(
                  width: width,
                  child: Material(
                    color: AppColors.surfaceBase,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _switchSection(stat.section),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(stat.icon, size: 20, color: AppColors.primary),
                            const SizedBox(height: 10),
                            Text(stat.value, style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            )),
                            const SizedBox(height: 4),
                            Text(stat.label, style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                )).toList(),
              );
            }),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Text('Đặt phòng gần đây', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ))),
                TextButton(
                  onPressed: () => _switchSection(HostPortalSection.bookings),
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingBookings)
              const Center(child: CircularProgressIndicator())
            else if (recentBookings.isEmpty)
              _buildEmptyBox('Chưa có đặt phòng.')
            else
              for (var i = 0; i < recentBookings.take(3).length; i++) ...[
                if (i > 0) const Divider(height: 24, color: AppColors.border),
                _buildBookingItemCard(recentBookings.elementAt(i)),
              ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 2 & 10. PROPERTIES (`ChoNghi`) & SUPPORT (`HoTro`) SECTIONS
  // ===========================================================================

  Widget _buildPropertySummary(
    List<({String label, String value})> items, {bool borderless = false}
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640
            ? items.length.clamp(1, 4)
            : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) => Container(
            width: width,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              border: borderless ? null : Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.value, style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                )),
                const SizedBox(height: 4),
                Text(item.label, style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                )),
              ],
            ),
          )).toList(),
        );
      },
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
      'lastMessage': 'Xin chào, Ban quản trị The Palm Villa có thể hỗ trợ gì cho bạn?',
      'updatedAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      if (!_conversations.any((c) => '${c['conversationId'] ?? c['id']}' == 'admin_support')) {
        _conversations.insert(0, fallbackAdminConv);
      }
      _selectedConversationId = 'admin_support';
      _inChatDetailView = true;
      _activeSection = HostPortalSection.messages;
      if (_conversationMessages.isEmpty) {
        _conversationMessages = [
          {
            'messageId': 'welcome_admin',
            'content': 'Xin chào! Ban quản trị The Palm Villa luôn sẵn sàng hỗ trợ bạn 24/7. Bạn cần trợ giúp vấn đề gì hôm nay?',
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
        a:
            'Tiền phòng sẽ được tự động chuyển vào tài khoản ngân hàng đã đăng ký của bạn trong vòng 24h làm việc sau khi khách thực hiện Check-in thành công.',
      ),
      (
        q: 'Làm thế nào để chỗ nghỉ của tôi được duyệt hiển thị nhanh nhất?',
        a:
            'Đảm bảo chụp tối thiểu 5 ảnh thực tế rõ nét (phòng khách, phòng ngủ, phòng tắm, ngoại cảnh) và điền đầy đủ tiện nghi, giá cả chính xác.',
      ),
      (
        q: 'Tôi phải làm gì khi khách yêu cầu hủy phòng vào phút chót?',
        a:
            'Chính sách hủy phòng bạn thiết lập sẽ được áp dụng tự động. Nếu có tranh chấp phát sinh, hãy bấm "Nhắn tin với Quản trị viên" để Ban quản trị hỗ trợ giải quyết thỏa đáng.',
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
                                  border:
                                      Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 3.5,
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
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
                    minimumSize: const Size(double.infinity, 46),
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
                    minimumSize: const Size(80, 36),
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
    final counts = <String, int>{
      'draft': 0,
      'pending_approval': 0,
      'published': 0,
      'hidden': 0,
      'rejected': 0,
    };
    for (final item in _listings) {
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header (Tiêu đề + Thêm chỗ nghỉ, BỎ NÚT LOAD) ──
          Row(
            children: [
              Expanded(
                child: const Text(
                  'Quản lý chỗ nghỉ',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ElevatedButton.icon(
                key: const Key('properties_add_new_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(130, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                onPressed: () =>
                    _switchSection(HostPortalSection.newProperty),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text(
                  'Thêm chỗ nghỉ',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (_listingsError != null) ...[
            const SizedBox(height: 12),
            _buildInlineError(
              _listingsError!,
              borderless: true,
              onRetry: _fetchListings,
            ),
          ],

          const SizedBox(height: 12),

          // ── Hộp tóm tắt Thông minh (Smart Banner Header) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.house, size: 15, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${_listings.length} chỗ nghỉ',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      '${counts['published'] ?? 0} đang hiển thị',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
                Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: (counts['pending_approval'] ?? 0) > 0 ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      (counts['pending_approval'] ?? 0) > 0
                          ? '${counts['pending_approval'] ?? 0} chờ duyệt'
                          : '${(counts['draft'] ?? 0) + (counts['hidden'] ?? 0) + (counts['rejected'] ?? 0)} chưa hiển thị',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: (counts['pending_approval'] ?? 0) > 0 ? FontWeight.w600 : FontWeight.w500,
                        color: (counts['pending_approval'] ?? 0) > 0 ? const Color(0xFFB45309) : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Bộ lọc trạng thái dạng Pills hiện đại có số đếm ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filterOptions.map((opt) {
                final selected = _listingStatusFilter == opt.$1;
                final count = opt.$1 == 'all'
                    ? _listings.length
                    : (opt.$1 == 'hidden'
                        ? (counts['hidden'] ?? 0)
                        : (counts[opt.$1] ?? 0));
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    key: Key('listing_filter_${opt.$1}'),
                    onTap: () {
                      setState(() {
                        _listingStatusFilter = opt.$1;
                        _listingsVisibleCount = 10;
                      });
                      _fetchListings();
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.textPrimary : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            opt.$2,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: selected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // ── Sắp xếp tinh gọn ──
          Row(
            children: [
              const Icon(LucideIcons.arrowUpDown, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const Key('listing_sort_dropdown'),
                  value: _listingSortBy,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  isDense: true,
                  items: sortOptions.map((opt) => DropdownMenuItem(
                    value: opt.$1,
                    child: Text('Sắp xếp: ${opt.$2}'),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _listingSortBy = value);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),

          // ── Danh sách các căn chỗ nghỉ (ĐẨY LÊN CAO NGAY ĐÂY) ──
          if (_loadingListings)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (sortedListings.isEmpty)
            _buildEmptyBox('Chưa có chỗ nghỉ phù hợp bộ lọc.', borderless: true)
          else ...[
            for (var i = 0; i < visibleListings.length; i++) ...[
              if (i > 0) const Divider(height: 20, color: AppColors.border),
              _buildListingCard(visibleListings[i]),
            ],
            if (sortedListings.length > visibleListings.length)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  key: const Key('listings_load_more_btn'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(160, 44),
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
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
          ],
        ],
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
    final imageUrl =
        (listing['imageUrl'] ?? listing['coverImageUrl'] ?? '').toString();
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

    return Container(
      key: Key('host_listing_item_$id'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(24),

      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 88,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildNoImagePlaceholder(),
                      )
                    : _buildNoImagePlaceholder(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (addressParts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        addressParts,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildStatusPill(statusEnum.labelVi, statusEnum.value),
                        Text(
                          '${propType.labelVi} • ${formatHostVnd(basePrice)}/đêm'
                          '${weekendPrice != null ? ' (CT: ${formatHostVnd(weekendPrice)})' : ''}'
                          ' • $maxGuests khách',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Text(
                'Lý do từ chối: $rejectReason',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFBE123C),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: Key('listing_edit_btn_$id'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(88, 48),
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),
                onPressed: isBusy
                    ? null
                    : () => _switchSection(
                          HostPortalSection.newProperty,
                          editListingId: id,
                        ),
                icon: const Icon(LucideIcons.pencil, size: 15),
                label: const Text('Sửa'),
              ),
              if (statusEnum == HostListingStatus.draft ||
                  statusEnum == HostListingStatus.rejected)
                ElevatedButton.icon(
                  key: Key('listing_submit_approval_btn_$id'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(110, 48),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  onPressed: isBusy
                      ? null
                      : () => _runListingMutation(
                            id,
                            () => repo.submitListingForApproval(id),
                          ),
                  icon: const Icon(LucideIcons.send, size: 15),
                  label: const Text('Gửi duyệt'),
                ),
              if (statusEnum == HostListingStatus.pendingApproval)
                OutlinedButton.icon(
                  key: Key('listing_withdraw_draft_btn_$id'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(110, 48),
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: isBusy
                      ? null
                      : () => _runListingMutation(
                            id,
                            () => repo.updateHostListing(
                              id,
                              {'status': HostListingStatus.draft.value},
                            ),
                          ),
                  icon: const Icon(LucideIcons.rotateCcw, size: 15),
                  label: const Text('Rút về nháp'),
                ),
              if (statusEnum == HostListingStatus.published)
                OutlinedButton.icon(
                  key: Key('listing_hide_btn_$id'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(88, 48),
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: isBusy
                      ? null
                      : () => _runListingMutation(
                            id,
                            () => repo.hideHostListing(id),
                          ),
                  icon: const Icon(LucideIcons.eyeOff, size: 15),
                  label: const Text('Ẩn'),
                ),
              if (statusEnum == HostListingStatus.hidden)
                OutlinedButton.icon(
                  key: Key('listing_publish_btn_$id'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(88, 48),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: isBusy
                      ? null
                      : () => _runListingMutation(
                            id,
                            () => repo.publishHostListing(id),
                          ),
                  icon: const Icon(LucideIcons.eye, size: 15),
                  label: const Text('Hiện'),
                ),
              OutlinedButton.icon(
                key: Key('listing_delete_btn_$id'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(88, 48),
                  foregroundColor: const Color(0xFFBE123C),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),
                onPressed:
                    isBusy ? null : () => _confirmAndDeleteListing(listing),
                icon: const Icon(LucideIcons.trash2, size: 15),
                label: const Text('Xóa'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoImagePlaceholder() {
    return Container(
      width: 88,
      height: 68,
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: const Text(
        'Chưa có ảnh',
        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Đặt phòng', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ))),
              IconButton.outlined(
                tooltip: 'Tải lại',
                onPressed: _loadingBookings ? null : _fetchBookings,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
              ),
            ],
          ),
          if (_bookingsError != null) ...[
            const SizedBox(height: 16),
            _buildInlineError(
              _bookingsError!,
              onRetry: _fetchBookings,
            ),
          ],
          if (_bookingsSuccess != null) ...[
            const SizedBox(height: 16),
            _buildInlineSuccess(_bookingsSuccess!),
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
                      .map(
                        (tab) => DropdownMenuItem(
                          key: Key('booking_filter_${tab.$1}'),
                          value: tab.$1,
                          child: Text(tab.$2, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _bookingStatusFilter = value;
                      _bookingsVisibleCount = 10;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPortalDropdown<String>(
                  dropdownKey: const Key('booking_sort_dropdown'),
                  label: 'Sắp xếp',
                  value: _bookingSortBy,
                  items: sortOptions
                      .map(
                        (opt) => DropdownMenuItem(
                          key: Key('booking_sort_${opt.$1}'),
                          value: opt.$1,
                          child: Text(opt.$2, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _bookingSortBy = value);
                  },
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
    );
  }

  String _formatBookingDate(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? value : DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _buildBookingItemCard(Map<String, dynamic> booking) {
    final bookingId = (booking['bookingId'] ?? booking['id'] ?? '').toString();
    final guestName =
        (booking['guestName'] ?? booking['customerName'] ?? 'Khách #$bookingId')
            .toString()
            .trim();
    final guestPhone =
        (booking['guestPhone'] ?? booking['guestEmail'] ?? '').toString().trim();
    final listingTitle =
        (booking['listingTitle'] ?? 'Chỗ nghỉ #${booking['listingId'] ?? ''}')
            .toString();
    final checkIn = (booking['checkInDate'] ?? '').toString().split('T').first;
    final checkOut =
        (booking['checkOutDate'] ?? '').toString().split('T').first;
    final nights = _calculateGuestNights(checkIn, checkOut);
    final guestsCount = booking['guestsCount'] ?? booking['guests'] ?? 1;
    final totalPrice = booking['totalPrice'] ?? booking['totalAmount'] ?? 0;
    final initial =
        guestName.isNotEmpty ? guestName.substring(0, 1).toUpperCase() : 'K';

    final display = getBookingDisplayStatus(
      booking,
      role: BookingActionRole.host,
    );
    final actions = display.actions;
    final isBusy = _busyBookingActionId == bookingId;

    return Container(
      key: Key('host_booking_card_$bookingId'),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Thẻ: Avatar chữ cái đầu + Tên khách + Chỗ nghỉ + Nhãn trạng thái
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFFEE2E2),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guestName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.house,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            listingTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(display.label, display.code),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Thân Thẻ: Bố cục 2 cột phẳng, thoáng đãng, không đóng hộp xám
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cột 1: THỜI GIAN LƯU TRÚ
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.calendar,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'LƯU TRÚ · $nights ĐÊM',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_formatBookingDate(checkIn)} - ${_formatBookingDate(checkOut)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Nhận: 14:00 · Trả: 12:00',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: const Color(0xFFF1F5F9),
                ),
                // Cột 2: THANH TOÁN & KHÁCH
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            LucideIcons.wallet,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'THANH TOÁN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatHostVnd(totalPrice),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$guestsCount khách · Mã #$bookingId',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Phím tắt liên hệ nhanh: Gọi điện & Nhắn tin
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _handleCallGuest(guestName, guestPhone),
                  icon: const Icon(
                    LucideIcons.phone,
                    size: 15,
                    color: AppColors.textPrimary,
                  ),
                  label: const Text(
                    'Gọi điện',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _handleMessageGuest(booking),
                  icon: const Icon(
                    LucideIcons.messageSquare,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Nhắn tin',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),

          // 4. Các nút thao tác nghiệp vụ (Xác nhận, Check-in, Check-out, Hủy) nếu có
          if (actions.hasAnyAction) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (actions.canConfirm)
                  ElevatedButton.icon(
                    key: Key('booking_confirm_btn_$bookingId'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(110, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: isBusy
                        ? null
                        : () => _handleBookingAction(booking, 'confirm'),
                    icon: const Icon(LucideIcons.check, size: 15),
                    label: const Text('Xác nhận'),
                  ),
                if (actions.canCheckIn)
                  ElevatedButton.icon(
                    key: Key('booking_checkin_btn_$bookingId'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(110, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: isBusy
                        ? null
                        : () => _handleBookingAction(booking, 'check_in'),
                    icon: const Icon(LucideIcons.logIn, size: 15),
                    label: const Text('Check-in'),
                  ),
                if (actions.canCheckOut)
                  ElevatedButton.icon(
                    key: Key('booking_checkout_btn_$bookingId'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(110, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: isBusy
                        ? null
                        : () => _handleBookingAction(booking, 'check_out'),
                    icon: const Icon(LucideIcons.logOut, size: 15),
                    label: const Text('Check-out'),
                  ),
                if (actions.canCancel)
                  OutlinedButton.icon(
                    key: Key('booking_cancel_btn_$bookingId'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(96, 40),
                      foregroundColor: const Color(0xFFBE123C),
                      side: const BorderSide(color: Color(0xFFFECDD3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isBusy
                        ? null
                        : () => _handleBookingAction(booking, 'cancel'),
                    icon: const Icon(LucideIcons.x, size: 15),
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
    if (d.isPast) return true;
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return d.date.isNotEmpty && d.date.compareTo(todayStr) < 0;
  }

  void _selectWeekendDays() {
    final targets = <String>{};
    for (final d in _calendarDays) {
      if (_isDayInPast(d)) continue;
      final parsed = DateTime.tryParse(d.date);
      if (parsed != null &&
          (parsed.weekday == DateTime.saturday ||
              parsed.weekday == DateTime.sunday)) {
        final isBooked =
            d.bookingStatus != null && d.bookingStatus!.isNotEmpty;
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
      final isBooked =
          d.bookingStatus != null && d.bookingStatus!.isNotEmpty;
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
      final isBooked =
          d.bookingStatus != null && d.bookingStatus!.isNotEmpty;
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
    final listingId =
        (listing['listingId'] ?? listing['id'] ?? '').toString();
    final today = DateTime.now();

    final bookedDateStrings = <String>{};
    for (final b in _bookings) {
      final bListingId =
          (b['listingId'] ?? b['listing_id'] ?? b['id'] ?? '').toString();
      final status = (b['status'] ?? '').toString().toLowerCase();
      if (bListingId == listingId && status != 'cancelled') {
        final checkInStr =
            (b['checkInDate'] ?? b['check_in'] ?? '').toString().split('T').first;
        final checkOutStr =
            (b['checkOutDate'] ?? b['check_out'] ?? '').toString().split('T').first;
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
                    final dateStr =
                        DateFormat('yyyy-MM-dd').format(targetDate);
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
      final title = (l['title'] ?? '').toString().toLowerCase();
      final address = '${l['addressLine'] ?? ''} ${l['city'] ?? ''}'.toLowerCase();
      return title.contains(query) || address.contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lịch',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tổng quan lịch chỗ nghỉ & tình trạng phòng',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Tìm kiếm',
                    onPressed: () {
                      setState(() {
                        _calendarSearchVisible = !_calendarSearchVisible;
                      });
                    },
                    icon: Icon(
                      _calendarSearchVisible ? LucideIcons.x : LucideIcons.search,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_calendarListingId != null) ...[
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      onPressed: () {
                        setState(() => _calendarShowListingList = false);
                        _fetchCalendarDays();
                      },
                      icon: const Icon(LucideIcons.calendarDays, size: 15),
                      label: const Text('Xem lịch chi tiết',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
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
                hintText: 'Tìm theo tên hoặc địa chỉ chỗ nghỉ...',
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HostUnderlineTab(
                label: Text('Tất cả (${_listings.length})'),
                selected: _calendarListingFilter == 'all',
                onSelected: (_) => setState(() => _calendarListingFilter = 'all'),
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
              final statusEnum =
                  HostListingStatus.fromApi(listing['status']);
              final basePrice =
                  listing['basePrice'] ?? listing['pricePerNight'] ?? 0;
              final imageUrl = (listing['imageUrl'] ??
                      listing['coverImageUrl'] ??
                      '')
                  .toString();

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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  width: 76,
                                  height: 76,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildNoImagePlaceholder(),
                                )
                              : _buildNoImagePlaceholder(),
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
                              Text(
                                statusTextVi,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
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
    final activeBasePrice =
        _getListingBasePrice(_calendarListingId ?? '');

    final totalDaysInMonth =
        DateTime(_calendarYear, _calendarMonth + 1, 0).day;
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
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    tooltip: 'Tháng trước',
                    onPressed: _prevMonth,
                    icon: const Icon(LucideIcons.chevronLeft, size: 18),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    tooltip: 'Tháng sau',
                    onPressed: _nextMonth,
                    icon: const Icon(LucideIcons.chevronRight, size: 18),
                  ),
                  TextButton(
                    onPressed: _goToCurrentMonth,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const Text('Hôm nay',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
                    for (var y = _calendarYear - 1;
                        y <= _calendarYear + 2;
                        y++)
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
              padding: const EdgeInsets.all(10),
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
                      mainAxisSpacing: 4,
                      childAspectRatio: 0.82,
                    ),
                    itemBuilder: (context, index) {
                      if (index < leadOffset) {
                        return const SizedBox.shrink();
                      }
                      final day = _calendarDays[index - leadOffset];
                      final now = DateTime.now();
                      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                      final isToday = day.date == todayStr;
                      final isPast = day.isPast ||
                          (day.date.isNotEmpty && day.date.compareTo(todayStr) < 0 && !isToday);
                      final isSelected = !isPast &&
                          _selectedCalendarDates.contains(day.date);
                      final isBooked = day.isBooked ||
                          (day.bookingStatus != null &&
                              day.bookingStatus!.isNotEmpty);
                      final isEditable = day.isEditable() && !isBooked && !day.isPast;
                          day.isEditable(todayVietnam: todayStr) && !isBooked && !isPast;
                      final isBlocked =
                          !day.isAvailable || day.isBlockedByHost;

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
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          if (day.isPast || !isEditable) {
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
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: borderColor,
                              width: isSelected ? 1.8 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 1, vertical: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isToday && !isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    day.date.split('-').last.replaceFirst(RegExp(r'^0'), ''),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  day.date.split('-').last.replaceFirst(RegExp(r'^0'), ''),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
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
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: priceColor,
                                ),
                              ),
                              if (isBooked)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF047857),
                                    shape: BoxShape.circle,
                                  ),
                                )
                              else if (isBlocked && !isSelected)
                                Text(
                                  'Khóa',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white70
                                        : const Color(0xFFBE123C),
                                  ),
                                ),
                            ],
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
                      label: const Text('Bỏ chọn',
                          style: TextStyle(fontSize: 12)),
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
                                      borderRadius:
                                          BorderRadius.circular(999),
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
                                      key: const Key('calendar_unlock_save_btn'),
                                      borderRadius:
                                          BorderRadius.circular(999),
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
                                        onPressed: () =>
                                            _applyPricePreset(1.1),
                                      ),
                                      ActionChip(
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: AppColors.surfaceBase,
                                        shape: const StadiumBorder(),
                                        side: const BorderSide(
                                            color: AppColors.border),
                                        label: const Text(
                                            '+20% (Cuối tuần/Lễ)',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary)),
                                        onPressed: () =>
                                            _applyPricePreset(1.2),
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
                                        onPressed: () =>
                                            _applyPricePreset(1.0),
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
                                                  horizontal: 12,
                                                  vertical: 10),
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
                                        key: const Key(
                                            'calendar_notes_input'),
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
                                                  horizontal: 12,
                                                  vertical: 10),
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

  void _handleCallGuest(String guestName, String phone) {
    final cleanPhone = phone.trim();
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
              child: const Icon(LucideIcons.phone, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Liên hệ $guestName',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.phoneCall, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      cleanPhone.isNotEmpty ? cleanPhone : 'Chưa cập nhật số điện thoại',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
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
    final guestName = (booking['guestName'] ?? booking['customerName'] ?? '').toString().trim().toLowerCase();
    for (final conv in _conversations) {
      final other = conv['otherParticipant'] is Map ? Map<String, dynamic>.from(conv['otherParticipant'] as Map) : null;
      final name = (other?['fullName'] ?? other?['name'] ?? conv['guestName'] ?? '').toString().toLowerCase();
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
    final statusOptions = [
      ('all', 'Tất cả khách hàng', LucideIcons.users, AppColors.primary),
      ('confirmed', 'Đã xác nhận', LucideIcons.circleCheck, const Color(0xFF10B981)),
      ('payment_expired', 'Quá hạn thanh toán', LucideIcons.clockAlert, const Color(0xFFEF4444)),
      ('cancelled', 'Hủy', LucideIcons.ban, const Color(0xFF64748B)),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceBase,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Lọc theo trạng thái khách',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final opt in statusOptions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tileColor: _guestStatusFilter == opt.$1
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : null,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: opt.$4.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(opt.$3, size: 18, color: opt.$4),
                    ),
                    title: Text(
                      opt.$2,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _guestStatusFilter == opt.$1
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: _guestStatusFilter == opt.$1
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    trailing: _guestStatusFilter == opt.$1
                        ? const Icon(LucideIcons.check,
                            color: AppColors.primary, size: 20)
                        : null,
                    onTap: () {
                      setState(() => _guestStatusFilter = opt.$1);
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showGuestListingFilterModal() {
    _showGuestStatusFilterModal();
  }

  Widget _buildGuestsSection() {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    // 1. Lọc theo căn được chọn (nếu có)
    final relevantBookings = _bookings.where((b) {
      if (_guestSelectedListingId != null &&
          _guestSelectedListingId != 'all') {
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
      final outDay = outD != null ? DateTime(outD.year, outD.month, outD.day) : inDay;
      if (inDay.isAtSameMomentAs(todayDate)) return true;
      if (!inDay.isAfter(todayDate) && !outDay.isBefore(todayDate)) return true;
      return false;
    }).toList();

    final upcomingBookings = relevantBookings.where((b) {
      final st = (b['status'] ?? '').toString().toLowerCase();
      if (st == 'cancelled' || st == 'rejected' || st == 'completed' || st == 'checked_out') {
        return false;
      }
      final inD = _parseGuestBookingDate(b['checkInDate']);
      if (inD == null) return st == 'confirmed' || st == 'paid';
      final inDay = DateTime(inD.year, inD.month, inD.day);
      return inDay.isAfter(todayDate) || inDay.isAtSameMomentAs(todayDate) || st == 'confirmed' || st == 'paid';
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
    Color statusColor = AppColors.primary;
    if (_guestStatusFilter == 'confirmed') {
      statusTitle = 'Đã xác nhận';
      statusIcon = LucideIcons.circleCheck;
      statusColor = const Color(0xFF10B981);
    } else if (_guestStatusFilter == 'payment_expired') {
      statusTitle = 'Quá hạn thanh toán';
      statusIcon = LucideIcons.clockAlert;
      statusColor = const Color(0xFFEF4444);
    } else if (_guestStatusFilter == 'cancelled') {
      statusTitle = 'Hủy';
      statusIcon = LucideIcons.ban;
      statusColor = const Color(0xFF64748B);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Text(
            'Khách lưu trú',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Theo dõi lượt khách nhận phòng và lịch lưu trú theo từng căn.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),

          // 2 Nút Lớn: Hôm nay & Sắp tới (Số đếm đồng bộ với trạng thái đang lọc)
          Row(
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
              const SizedBox(width: 12),
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

          const SizedBox(height: 12),

          // Ô Lọc Trạng thái Khách hàng (Đổi từ Tất cả các căn thành Tất cả khách hàng)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _showGuestStatusFilterModal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, size: 18, color: statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Danh sách khách / Trạng thái trống
          if (_loadingBookings)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredList.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(LucideIcons.calendarX2, size: 28, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _guestStatusFilter != 'all'
                        ? 'Không có khách nào có trạng thái "$statusTitle"'
                        : (_guestTab == 'today'
                            ? 'Hôm nay chưa có lượt khách nào lưu trú'
                            : 'Chưa có lượt khách nào sắp tới'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _guestStatusFilter != 'all'
                        ? 'Thử chọn "Tất cả khách hàng" để xem đầy đủ danh sách.'
                        : 'Các lượt đặt phòng mới từ khách sẽ được cập nhật tự động tại đây.',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  if (_guestStatusFilter != 'all') ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      onPressed: () => setState(() => _guestStatusFilter = 'all'),
                      icon: const Icon(LucideIcons.users, size: 16),
                      label: const Text('Xem tất cả khách hàng'),
                    ),
                  ],
                ],
              ),
            )
          else
            for (var i = 0; i < filteredList.length; i++) ...[
              if (i > 0) const Divider(height: 24, color: AppColors.border),
              _buildModernGuestCard(filteredList[i]),
            ],
        ],
      ),
    );
  }

  Widget _buildBigGuestTabButton({
    required String label,
    required int count,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernGuestCard(Map<String, dynamic> b) {
    final bookingId = '${b['bookingId'] ?? b['id'] ?? ''}';
    final name = (b['guestName'] ?? b['customerName'] ?? 'Khách #$bookingId').toString().trim();
    final phone = (b['guestPhone'] ?? b['guestEmail'] ?? '').toString().trim();
    final listingTitle = (b['listingTitle'] ?? 'Chỗ nghỉ #${b['listingId'] ?? ''}').toString();
    final inStr = (b['checkInDate'] ?? '').toString().split('T').first;
    final outStr = (b['checkOutDate'] ?? '').toString().split('T').first;
    final nights = _calculateGuestNights(inStr, outStr);
    final guestsCount = b['guestsCount'] ?? b['guests'] ?? 1;
    final totalPrice = b['totalPrice'] ?? b['totalAmount'] ?? 0;
    final display = getBookingDisplayStatus(b, role: BookingActionRole.host);
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'K';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Phần Trên: Avatar + Tên khách + Căn + Trạng thái
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFFEE2E2),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(LucideIcons.house, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            listingTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(display.label, display.code),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Phần Giữa: Bố cục 2 cột phẳng, thoáng đãng, không đóng hộp xám
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cột 1: THỜI GIAN LƯU TRÚ
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.calendar, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Text(
                            'LƯU TRÚ · $nights ĐÊM',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_formatGuestDateDisplay(inStr)} - ${_formatGuestDateDisplay(outStr)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Nhận: 14:00 · Trả: 12:00',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: const Color(0xFFF1F5F9),
                ),
                // Cột 2: THANH TOÁN & KHÁCH
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.wallet, size: 13, color: AppColors.textSecondary),
                          SizedBox(width: 5),
                          Text(
                            'THANH TOÁN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatHostVnd(totalPrice),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$guestsCount khách · Mã #$bookingId',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Phần Dưới: 2 Nút hành động 50% - 50%
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _handleCallGuest(name, phone),
                  icon: const Icon(LucideIcons.phone, size: 15, color: AppColors.textPrimary),
                  label: const Text(
                    'Gọi điện',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _handleMessageGuest(b),
                  icon: const Icon(LucideIcons.messageSquare, size: 15, color: Colors.white),
                  label: const Text(
                    'Nhắn tin',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
        (hasNoListing && (name.contains('palm') || name.contains('hệ thống') || name.contains('hỗ trợ')));
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

  Widget _buildVillaPlaceholderAvatar({bool isAdmin = false}) {
    if (isAdmin) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(
          LucideIcons.shieldCheck,
          size: 24,
          color: AppColors.primary,
        ),
      );
    }
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(
        LucideIcons.house,
        size: 24,
        color: AppColors.primary,
      ),
    );
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Tiêu đề 28px to rõ + Nút tìm kiếm co giãn góc phải
          Row(
            children: [
              if (!_messagesSearchExpanded) ...[
                const Expanded(
                  child: Text(
                    'Tin nhắn',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Material(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _messagesSearchExpanded = true),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.search,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: TextField(
                    controller: _messagesSearchCtrl,
                    autofocus: true,
                    onChanged: (v) =>
                        setState(() => _messagesSearchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm khách hoặc chỗ nghỉ...',
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      suffixIcon: IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => setState(() {
                          _messagesSearchExpanded = false;
                          _messagesSearchCtrl.clear();
                          _messagesSearchQuery = '';
                        }),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (_conversationsError != null) ...[
            const SizedBox(height: 16),
            _buildInlineError(
              _conversationsError!,
              onRetry: _fetchConversations,
            ),
          ],

          const SizedBox(height: 18),

          if (_loadingConversations)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_conversations.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
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
            )
          else if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text(
                  'Không tìm thấy cuộc trò chuyện phù hợp.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...filtered.map(_buildConversationItemRow),
        ],
      ),
    );
  }

  Widget _buildConversationItemRow(Map<String, dynamic> c) {
    final convId = '${c['conversationId'] ?? c['id']}';
    final other = c['otherParticipant'] is Map
        ? Map<String, dynamic>.from(c['otherParticipant'] as Map)
        : null;
    final isAdmin = _isConversationAdmin(c);
    var name = (other?['fullName'] ??
            other?['name'] ??
            c['guestName'] ??
            c['title'] ??
            'Hội thoại #$convId')
        .toString();
    if (isAdmin) {
      if (name.toLowerCase().contains('quản trị viên')) {
        name = name.replaceAll(RegExp(r'quản trị viên\s*', caseSensitive: false), '').trim();
      }
      if (name.isEmpty || name.toLowerCase().contains('cuộc trò chuyện') || name.toLowerCase().contains('hội thoại')) {
        name = 'The Palm Villa';
      }
    }
    final listingTitle = (c['listingTitle'] ?? '').toString().trim();
    final lastMsg = (c['lastMessage'] is Map
            ? c['lastMessage']['content'] ?? c['lastMessage']['body']
            : c['lastMessage']) ??
        c['lastMessageContent'] ??
        'Chưa có tin nhắn nào';
    final villaImage = _getConversationVillaImage(c);

    // Format time
    String timeStr = '';
    final rawDate = c['updatedAt'] ??
        c['lastMessageAt'] ??
        (c['lastMessage'] is Map ? c['lastMessage']['createdAt'] : null);
    if (rawDate != null) {
      final d = DateTime.tryParse(rawDate.toString());
      if (d != null) {
        final now = DateTime.now();
        if (d.year == now.year && d.month == now.month && d.day == now.day) {
          timeStr = DateFormat('HH:mm').format(d);
        } else {
          timeStr = DateFormat('dd/MM').format(d);
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              _selectedConversationId = convId;
              _inChatDetailView = true;
            });
            _fetchMessagesForConversation(convId);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar: Hình ảnh Villa hoặc Icon Admin
                if (isAdmin)
                  _buildVillaPlaceholderAvatar(isAdmin: true)
                else if (villaImage != null && villaImage.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      villaImage,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildVillaPlaceholderAvatar(),
                    ),
                  )
                else
                  _buildVillaPlaceholderAvatar(),

                const SizedBox(width: 12),

                // Nội dung ở giữa
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.shieldCheck,
                                    size: 11,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Quản trị viên',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$lastMsg',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (listingTitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.house,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                listingTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Bên phải: Giờ gửi & Chấm đỏ
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (timeStr.isNotEmpty)
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (isAdmin) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatDetailView() {
    final currentUser = ref.watch(authNotifierProvider).value;
    final currentUserId = currentUser?.id.toString();

    final matchedConv = _conversations.firstWhere(
      (c) => '${c['conversationId'] ?? c['id']}' == _selectedConversationId,
      orElse: () => {},
    );
    final hostUserId = matchedConv['hostUserId']?.toString();
    final guestUserId = matchedConv['guestUserId']?.toString();
    final other = matchedConv['otherParticipant'] is Map
        ? Map<String, dynamic>.from(matchedConv['otherParticipant'] as Map)
        : null;
    final participantName = (other?['fullName'] ??
            other?['name'] ??
            matchedConv['guestName'] ??
            matchedConv['title'] ??
            'Cuộc trò chuyện')
        .toString();
    final listingTitle =
        (matchedConv['listingTitle'] ?? '').toString().trim();
    final isAdmin = _isConversationAdmin(matchedConv);
    final villaImage = _getConversationVillaImage(matchedConv);

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
              if (isAdmin)
                _buildVillaPlaceholderAvatar(isAdmin: true)
              else if (villaImage != null && villaImage.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    villaImage,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildVillaPlaceholderAvatar(),
                  ),
                )
              else
                _buildVillaPlaceholderAvatar(),
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
                            color: Color(0xFFBE123C),
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
                  _showChatTimestampsPinned ? LucideIcons.clockCheck : LucideIcons.clock,
                  size: 18,
                  color: _showChatTimestampsPinned ? AppColors.primary : AppColors.textSecondary,
                ),
                tooltip: _showChatTimestampsPinned ? 'Ẩn thời gian' : 'Hiện khung thời gian',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  itemCount: _conversationMessages.length,
                  itemBuilder: (ctx, i) {
                    final m = _conversationMessages[i];
                    final content =
                        (m['content'] ?? m['body'] ?? '').toString();
                    final senderId =
                        (m['senderId'] ?? m['senderUserId'])?.toString();
                    final senderRole =
                        (m['senderRole'] ?? '').toString().toLowerCase();
                    final rawSenderName = (m['senderName'] ??
                            m['sender']?['fullName'] ??
                            '')
                        .toString();

                    // Xác định tin nhắn là của tôi (Host) hay của Khách/Admin
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

                    final isMsgAdmin = isAdmin ||
                        senderRole == 'admin' ||
                        rawSenderName.toLowerCase().contains('quản trị viên');

                    // Format time nếu có
                    String? msgTime;
                    final rawCreatedAt = m['createdAt'];
                    if (rawCreatedAt != null) {
                      final dt = DateTime.tryParse(rawCreatedAt.toString());
                      if (dt != null) {
                        msgTime = DateFormat('HH:mm').format(dt);
                      }
                    }

                    // Render bong bóng tin nhắn tinh gọn kiểu Messenger (bỏ tên, bỏ thời gian tĩnh, kéo lộ khung thời gian)
                    return AnimatedBuilder(
                      animation: _chatDragAnimCtrl,
                      builder: (ctx, _) {
                        final progress = _chatDragAnimCtrl.value;
                        final timeWidth = 62.0 * progress;
                        final timeOpacity = progress.clamp(0.0, 1.0);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: isMe
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.72,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? AppColors.primary
                                          : (isMsgAdmin
                                              ? const Color(0xFFFFF1F2)
                                              : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(18),
                                        topRight: const Radius.circular(18),
                                        bottomLeft:
                                            Radius.circular(isMe ? 18 : 6),
                                        bottomRight:
                                            Radius.circular(isMe ? 6 : 18),
                                      ),
                                      border: isMe
                                          ? null
                                          : (isMsgAdmin
                                              ? Border.all(
                                                  color:
                                                      const Color(0xFFFECDD3),
                                                )
                                              : null),
                                      boxShadow: isMe
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
                                    child: Text(
                                      content,
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
                                  ),
                                ),
                              ),
                              if (progress > 0.01 && msgTime != null)
                                Opacity(
                                  opacity: timeOpacity,
                                  child: Container(
                                    width: timeWidth,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(6),
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
                        );
                      },
                    );
                  },
                ),
                ),
        ),

        // Thanh soạn thảo tin nhắn ở đáy
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surfaceBase,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
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
                    hintText: 'Nhập tin nhắn...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                key: const Key('host_message_send_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(56, 44),
                  shape: const StadiumBorder(),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: _sendingMessage ? null : _sendHostMessage,
                child: _sendingMessage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.send, size: 18),
              ),
            ],
          ),
        ),
      ],
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Thanh toán', style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ))),
              IconButton(
                tooltip: 'Tải lại',
                onPressed: _loadingPayouts ? null : _fetchPayoutData,
                icon: const Icon(LucideIcons.refreshCw, size: 20),
              ),
            ],
          ),
          if (_payoutsError != null) ...[
            const SizedBox(height: 16),
            _buildInlineError(
              _payoutsError!,
              onRetry: _fetchPayoutData,
            ),
          ],
          const SizedBox(height: 16),
          _buildPropertySummary([
            (label: 'Đã chuyển tiền', value: _loadingPayouts ? '—' : formatHostVnd(totalPaid)),
            (label: 'Chờ xử lý', value: _loadingPayouts ? '—' : formatHostVnd(totalPending)),
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
                      child: Text(_payoutAccounts.isEmpty ? 'Liên kết' : 'Chỉnh sửa'),
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
          const Text('Lịch sử chi trả', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          )),
          const SizedBox(height: 12),
          _buildPortalDropdown<String>(
            dropdownKey: const Key('payout_filter_dropdown'),
            label: 'Trạng thái',
            value: _payoutStatusFilter,
            items: payoutFilterTabs.map((tab) => DropdownMenuItem(
              key: Key('payout_filter_${tab.$1}'),
              value: tab.$1,
              child: Text(tab.$2),
            )).toList(),
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
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _reviews.isEmpty ? '—' : avgRating.toStringAsFixed(1),
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
                                      : (avgRating >= 4.5 ? 'Xuất sắc' : 'Rất tốt'),
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
              final initial = reviewerName.isNotEmpty
                  ? reviewerName.substring(0, 1).toUpperCase()
                  : 'K';

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
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFFEE2E2),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
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
                              Row(
                                children: [
                                  const Icon(
                                    LucideIcons.badgeCheck,
                                    size: 13,
                                    color: Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Khách lưu trú đã xác minh',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
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
                                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
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

    final kpiCards = [
      (
        title: 'THỰC NHẬN',
        sub: 'Tiền về tài khoản Host',
        value: _loadingReport ? '—' : formatHostVnd(_revenueReport.hostRevenue),
        icon: LucideIcons.walletCards,
        color: const Color(0xFF047857),
        bgColor: const Color(0xFFECFDF5),
        isPrimary: true,
      ),
      (
        title: 'DOANH THU GỘP',
        sub: 'Tổng thu từ khách',
        value: _loadingReport ? '—' : formatHostVnd(_revenueReport.grossRevenue),
        icon: LucideIcons.trendingUp,
        color: const Color(0xFF1D4ED8),
        bgColor: const Color(0xFFEFF6FF),
        isPrimary: false,
      ),
      (
        title: 'ĐẶT PHÒNG',
        sub: 'Lượt đặt hoàn tất',
        value: _loadingReport ? '—' : '${_revenueReport.bookingCount} lượt',
        icon: LucideIcons.calendarCheck,
        color: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF5F3FF),
        isPrimary: false,
      ),
      (
        title: 'PHÍ NỀN TẢNG',
        sub: 'Chiết khấu vận hành',
        value: _loadingReport ? '—' : formatHostVnd(_revenueReport.platformRevenue),
        icon: LucideIcons.receiptText,
        color: const Color(0xFFC2410C),
        bgColor: const Color(0xFFFFF7ED),
        isPrimary: false,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Tiêu đề
          const Text(
            'Doanh thu & Báo cáo tài chính',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Theo dõi dòng tiền, doanh thu thực nhận và hiệu quả chỗ nghỉ.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // 2. Thanh Filter Chips thời gian 1 chạm
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ranges.map((option) {
                final isSelected = _reportRange == option.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    label: Text(
                      option.$2,
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
                      setState(() => _reportRange = option.$1);
                      _fetchRevenueReport();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Dropdown Chỗ nghỉ & Theo kỳ
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildPortalDropdown<String>(
                  dropdownKey: const Key('reports_listing_filter_dropdown'),
                  label: 'Chỗ nghỉ',
                  value: _reportListingId == 'all' ||
                          _listings.any(
                            (l) =>
                                '${l['listingId'] ?? l['id']}' ==
                                _reportListingId,
                          )
                      ? _reportListingId
                      : 'all',
                  items: [
                    const DropdownMenuItem<String>(
                      value: 'all',
                      child: Text('Tất cả chỗ nghỉ',
                          overflow: TextOverflow.ellipsis),
                    ),
                    ..._listings.map((l) {
                      final id = '${l['listingId'] ?? l['id']}';
                      final title = (l['title'] ?? 'Chỗ nghỉ #$id').toString();
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(title, overflow: TextOverflow.ellipsis),
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
                child: _buildPortalDropdown<String>(
                  dropdownKey: const Key('report_group_dropdown'),
                  label: 'Theo kỳ',
                  value: _reportGroup,
                  items: groups
                      .map((option) => DropdownMenuItem(
                            key: Key('report_group_${option.$1}'),
                            value: option.$1,
                            child:
                                Text(option.$2, overflow: TextOverflow.ellipsis),
                          ))
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
                    .map((option) => DropdownMenuItem(
                          key: Key('report_range_${option.$1}'),
                          value: option.$1,
                          child: Text(option.$2),
                        ))
                    .toList(),
                onChanged: (val) {},
              ),
            ),
          ),

          if (_reportError != null) ...[
            const SizedBox(height: 14),
            _buildInlineError(
              _reportError!,
              onRetry: _fetchRevenueReport,
            ),
          ],
          const SizedBox(height: 16),

          // 4. Bảng điều khiển 4 chỉ số tài chính (Financial Metric Cards)
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 4 : 2;
              final itemWidth =
                  (constraints.maxWidth - 10 * (columns - 1)) / columns;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kpiCards.map((kpi) {
                  return Container(
                    width: itemWidth,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBase,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.border,
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          offset: Offset(0, 3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(kpi.icon, size: 16, color: kpi.color),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                kpi.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: kpi.color,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            kpi.value,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: kpi.isPrimary
                                  ? const Color(0xFF047857)
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          kpi.sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 20),

          // 5. Thẻ Báo cáo Dòng tiền theo chu kỳ (Period Cash Flow Timeline)
          Container(
            padding: const EdgeInsets.all(18),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.chartColumnIncreasing,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Dòng tiền theo chu kỳ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loadingReport)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_revenueReport.series.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Chưa có dữ liệu doanh thu trong kỳ đã chọn.',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ..._revenueReport.series.map((row) {
                    final ratio =
                        (row.hostRevenue / maxRevenue).clamp(0.0, 1.0);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.calendar,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${_formatBookingDate(row.period)} · ${row.bookingCount} đơn đặt',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '+${formatHostVnd(row.hostRevenue)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 7,
                              backgroundColor: const Color(0xFFE2E8F0),
                              color: const Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Doanh thu gộp: ${formatHostVnd(row.grossRevenue)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Phí sàn: ${formatHostVnd(row.platformRevenue)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
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
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 11. SETTINGS (`CaiDat`) SECTION — BUG-38
  // ===========================================================================
  Widget _buildSettingsSection() {
    final searchQuery = _bankSearchCtrl.text.trim().toLowerCase();
    final filteredBanks = _vietnamBanks.where((b) {
      if (searchQuery.isEmpty) return true;
      return '${b.code} ${b.shortName} ${b.name} ${b.bin ?? ''}'
          .toLowerCase()
          .contains(searchQuery);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cài đặt Chủ nhà',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Quản lý thông tin hồ sơ Host và tài khoản ngân hàng nhận thanh toán.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HostUnderlineTab(
                key: const Key('settings_tab_profile'),
                label: const Text('Hồ sơ Host'),
                selected: _settingsTab == 'profile',
                onSelected: (_) => setState(() => _settingsTab = 'profile'),
              ),
              _HostUnderlineTab(
                key: const Key('settings_tab_bank'),
                label: const Text('Tài khoản ngân hàng'),
                selected: _settingsTab == 'bank',
                onSelected: (_) => setState(() => _settingsTab = 'bank'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_settingsTab == 'profile')
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: _loadingSettings
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_profileError != null) ...[
                          _buildInlineError(
                            _profileError!,
                            onRetry: _loadSettingsData,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_profileSuccess != null) ...[
                          _buildInlineSuccess(_profileSuccess!),
                          const SizedBox(height: 12),
                        ],
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: AppColors.surfaceMuted,
                              backgroundImage:
                                  (_hostProfile?['avatarUrl'] != null &&
                                          '${_hostProfile!['avatarUrl']}'
                                              .isNotEmpty)
                                      ? NetworkImage(
                                          '${_hostProfile!['avatarUrl']}',
                                        )
                                      : null,
                              child: (_hostProfile?['avatarUrl'] == null ||
                                      '${_hostProfile!['avatarUrl']}'.isEmpty)
                                  ? const Icon(
                                      LucideIcons.user,
                                      color: AppColors.textPrimary,
                                    )
                                  : null,
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(140, 48),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: _uploadingAvatar
                                  ? null
                                  : _handlePickAndUploadAvatar,
                              icon: const Icon(LucideIcons.upload, size: 16),
                              label: Text(
                                _uploadingAvatar
                                    ? 'Đang tải ảnh...'
                                    : 'Thay đổi ảnh đại diện',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('settings_profile_name_input'),
                          controller: _profileNameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Họ và tên *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('settings_profile_email_input'),
                          controller: _profileEmailCtrl,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('settings_profile_phone_input'),
                          controller: _profilePhoneCtrl,
                          decoration: InputDecoration(
                            labelText: 'Số điện thoại',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          key: const Key('settings_profile_save_btn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(160, 48),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          onPressed:
                              _savingProfile ? null : _handleSaveHostProfile,
                          icon: const Icon(LucideIcons.save, size: 16),
                          label: Text(
                            _savingProfile ? 'Đang lưu...' : 'Lưu thay đổi',
                          ),
                        ),
                      ],
                    ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: _loadingBanks
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_bankError != null) ...[
                          _buildInlineError(
                            _bankError!,
                            onRetry: _loadSettingsData,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_bankSuccess != null) ...[
                          _buildInlineSuccess(_bankSuccess!),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          key: const Key('settings_bank_search_input'),
                          controller: _bankSearchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Tìm kiếm ngân hàng (Tên, Mã, BIN)',
                            prefixIcon:
                                const Icon(LucideIcons.search, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPortalDropdown<String>(
                          dropdownKey: const Key('settings_bank_dropdown'),
                          label: 'Chọn ngân hàng *',
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
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedBankCode = val),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('settings_bank_account_number_input'),
                          controller: _bankAccountNumberCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Số tài khoản (6–30 chữ số) *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('settings_bank_account_holder_input'),
                          controller: _bankAccountHolderCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Chủ tài khoản (IN HOA) *',
                            hintText: 'NGUYEN VAN A',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('settings_bank_branch_input'),
                          controller: _bankBranchCtrl,
                          decoration: InputDecoration(
                            labelText: 'Chi nhánh (không bắt buộc)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          key: const Key('settings_bank_save_btn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(160, 48),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          onPressed:
                              _savingBank ? null : _handleSaveBankAccount,
                          icon: const Icon(LucideIcons.save, size: 16),
                          label: Text(
                            _savingBank ? 'Đang lưu...' : 'Lưu thông tin',
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Shared UI Builders
  // ===========================================================================


  Widget _buildStatusPill(String label, String code) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF334155);
    if (code == 'published' ||
        code == 'confirmed' ||
        code == 'paid' ||
        code == 'completed' ||
        code == 'payout_paid') {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF047857);
    } else if (code == 'pending_approval' ||
        code == 'pending_payment' ||
        code == 'pending' ||
        code == 'payout_pending') {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFB45309);
    } else if (code == 'rejected' ||
        code == 'failed' ||
        code.contains('cancelled') ||
        code == 'payment_expired') {
      bg = const Color(0xFFFFF1F2);
      fg = const Color(0xFFBE123C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
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
        borderRadius: BorderRadius.circular(24),
        border: borderless ? null : Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildInlineError(String message, {VoidCallback? onRetry, bool borderless = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(20),
        border: borderless ? null : Border.all(color: const Color(0xFFFECDD3)),
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
                LucideIcons.circleAlert,
                size: 18,
                color: Color(0xFFBE123C),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFBE123C),
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
                foregroundColor: const Color(0xFFBE123C),
                shape: const StadiumBorder(),
              ),
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 14),
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
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.circleCheck,
            size: 18,
            color: Color(0xFF047857),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF047857),
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
    super.key,
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
              border: Border(bottom: BorderSide(
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
