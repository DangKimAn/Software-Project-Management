import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../../shared/widgets/app_semantic_icons.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../data/host_repository.dart';
import '../../domain/host_models.dart';
import '../../services/host_file_picker_service.dart';
import '../widgets/host_sheet_sync_card.dart';
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
      default:
        return HostPortalSection.overview;
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

class _HostPortalScreenState extends ConsumerState<HostPortalScreen> {
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

  // Guests search state
  final TextEditingController _guestSearchCtrl = TextEditingController();
  String _guestSearchQuery = '';
  String _guestSortBy = 'spent_desc';
  int _guestsVisibleCount = 10;

  // Messages state
  bool _loadingConversations = false;
  String? _conversationsError;
  List<Map<String, dynamic>> _conversations = [];
  String? _selectedConversationId;
  List<Map<String, dynamic>> _conversationMessages = [];
  bool _sendingMessage = false;
  final TextEditingController _messageInputCtrl = TextEditingController();

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
    _messageInputCtrl.dispose();
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
      case HostPortalSection.support:
        _fetchListings();
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
      setState(() {
        _savingBank = false;
        _bankSuccess = 'Đã lưu thông tin tài khoản ngân hàng.';
      });
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
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.surfaceBase,
            elevation: 0,
            titleSpacing: 12,
            leading: isDesktop
                ? IconButton(
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(
                      AppSemanticIcons.home,
                      color: AppColors.iconStrong,
                    ),
                    onPressed: () => _navigatePortalRoute(context, '/'),
                    tooltip: 'Về trang chủ',
                  )
                : null,
            title: Row(
              children: [
                const AppBrandIcon.minhThanhLogo(
                  size: 22,
                  color: AppColors.iconStrong,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isDesktop
                        ? 'Host Portal • ${_activeSection.label}'
                        : _activeSection.label,
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
                  color: AppColors.iconStrong,
                  size: 20,
                ),
              ),
              const NotificationBell(),
              const SizedBox(width: 4),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.border),
            ),
          ),
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
    final activeTabIndex = selectedIndex < 0 ? 4 : selectedIndex;
    const navItems = [
      (icon: LucideIcons.users, label: 'Khách', semantic: 'Khách lưu trú'),
      (icon: LucideIcons.calendar, label: 'Lịch', semantic: 'Lịch lưu trú'),
      (icon: LucideIcons.plus, label: 'Thêm', semantic: 'Thêm chỗ nghỉ'),
      (
        icon: AppSemanticIcons.messageHost,
        label: 'Tin nhắn',
        semantic: 'Tin nhắn',
      ),
      (icon: LucideIcons.menu, label: 'Menu', semantic: 'Mở menu điều hướng Host'),
    ];

    return Container(
      key: const Key('host_bottom_navigation'),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Row(
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = activeTabIndex == index;
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
                        minHeight: 48,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: isSelected
                                  ? AppColors.iconStrong
                                  : AppColors.iconMuted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: isSelected
                                    ? AppColors.textStrong
                                    : AppColors.textSecondary,
                              ),
                            ),
                            Container(
                              width: 24,
                              height: 2,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarNavigation({required bool inDrawer}) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      children: [
        for (final section in HostPortalSection.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              key: Key('host_sidebar_${section.keyName}'),
              borderRadius: BorderRadius.zero,
              onTap: () {
                if (inDrawer) Navigator.of(context).pop();
                _switchSection(section);
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(
                    color: _activeSection == section
                        ? AppColors.primary
                        : Colors.transparent,
                    width: 2,
                  )),
                ),
                child: Row(
                  children: [
                    Icon(
                      section.icon,
                      size: 18,
                      color: _activeSection == section
                          ? AppColors.iconStrong
                          : AppColors.iconMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        section.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _activeSection == section
                              ? FontWeight.w800
                              : FontWeight.w700,
                          color: _activeSection == section
                              ? AppColors.textStrong
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1, color: AppColors.border),
        ),
        InkWell(
          key: const Key('host_portal_home_btn'),
          borderRadius: BorderRadius.zero,
          onTap: () {
            if (inDrawer) Navigator.of(context).pop();
            _navigatePortalRoute(context, '/');
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                Icon(
                  AppSemanticIcons.home,
                  size: 18,
                  color: AppColors.iconStrong,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Về trang chủ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        InkWell(
          key: const Key('host_portal_logout_btn'),
          borderRadius: BorderRadius.zero,
          onTap: () => _handlePortalLogout(inDrawer: inDrawer),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                Icon(
                  AppSemanticIcons.logout,
                  size: 18,
                  color: AppColors.iconStrong,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Đăng xuất',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
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
        return _buildPropertiesSection(isSupportMode: true);
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
        icon: AppSemanticIcons.home, section: HostPortalSection.properties),
      (label: 'Đặt phòng', value: _loadingBookings ? '—' : '${_bookings.length}',
        icon: AppSemanticIcons.bookings, section: HostPortalSection.bookings),
      (label: 'Doanh thu · 30 ngày',
        value: _loadingReport ? '—' : formatCompactHostVnd(_revenueReport.hostRevenue),
        icon: AppSemanticIcons.revenue, section: HostPortalSection.reports),
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
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  tooltip: 'Tải lại',
                  onPressed: _loadInitialPortalData,
                  icon: const Icon(
                    AppSemanticIcons.retry,
                    size: 20,
                    color: AppColors.iconStrong,
                  ),
                ),
                IconButton(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  tooltip: 'Thêm chỗ nghỉ',
                  onPressed: () => _switchSection(HostPortalSection.newProperty),
                  icon: const Icon(
                    LucideIcons.plus,
                    size: 22,
                    color: AppColors.iconStrong,
                  ),
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
                            Icon(stat.icon, size: 20, color: AppColors.iconStrong),
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
              ...recentBookings.take(3).map(_buildBookingItemCard),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSupportMode
                        ? 'Hỗ trợ & Quản lý trạng thái chỗ nghỉ'
                        : 'Chỗ nghỉ của tôi',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (isSupportMode) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Kiểm tra trạng thái và gửi duyệt chỗ nghỉ.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  IconButton(
                    tooltip: 'Tải lại',
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: _loadingListings ? null : _fetchListings,
                    icon: const Icon(
                      AppSemanticIcons.retry,
                      size: 18,
                      color: AppColors.iconStrong,
                    ),
                  ),
                  ElevatedButton.icon(
                    key: const Key('properties_add_new_btn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(150, 48),
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    onPressed: () =>
                        _switchSection(HostPortalSection.newProperty),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Thêm chỗ nghỉ'),
                  ),
                ],
              ),
            ],
          ),
          if (_listingsError != null) ...[
            const SizedBox(height: 16),
            _buildInlineError(
              _listingsError!,
              borderless: true,
              onRetry: _fetchListings,
            ),
          ],
          const Divider(height: 28, color: AppColors.border),
          _buildPropertySummary([
            (
              label: 'Tổng chỗ nghỉ',
              value: '${_listings.length}',
            ),
            (
              label: 'Đang hiển thị',
              value: '${counts['published'] ?? 0}',
            ),
            (
              label: 'Chờ duyệt',
              value: '${counts['pending_approval'] ?? 0}',
            ),
            (
              label: 'Chưa hiển thị',
              value:
                  '${(counts['draft'] ?? 0) + (counts['hidden'] ?? 0) + (counts['rejected'] ?? 0)}',
            ),
          ], borderless: true),
          const Divider(height: 28, color: AppColors.border),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
            children: filterOptions.map((opt) {
              final selected = _listingStatusFilter == opt.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _HostUnderlineTab(
                key: Key('listing_filter_${opt.$1}'),
                label: Text(opt.$2),
                selected: selected,
                onSelected: (_) {
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
          const SizedBox(height: 12),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('listing_sort_dropdown'),
              isExpanded: true,
              value: _listingSortBy,
              items: sortOptions.map((opt) => DropdownMenuItem(
                value: opt.$1,
                child: Text('Sắp xếp: ${opt.$2}'),
              )).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _listingSortBy = value);
              },
            ),
          ),
          const Divider(height: 28, color: AppColors.border),
          if (_loadingListings)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (sortedListings.isEmpty)
            _buildEmptyBox('Chưa có chỗ nghỉ phù hợp bộ lọc.', borderless: true)
          else ...[
            for (var i = 0; i < visibleListings.length; i++) ...[
              if (i > 0) const Divider(height: 28, color: AppColors.border),
              _buildListingCard(visibleListings[i]),
            ],
            if (sortedListings.length > visibleListings.length)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  key: const Key('listings_load_more_btn'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(160, 48),
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide.none,
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
                  foregroundColor: AppColors.error,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),
                onPressed:
                    isBusy ? null : () => _confirmAndDeleteListing(listing),
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 15,
                  color: AppColors.iconStrong,
                ),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildPortalDropdown<String>(
                dropdownKey: const Key('booking_filter_dropdown'),
                label: 'Trạng thái',
                value: _bookingStatusFilter,
                items: filterTabs.map((tab) => DropdownMenuItem(
                  key: Key('booking_filter_${tab.$1}'),
                  value: tab.$1,
                  child: Text(tab.$2, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _bookingStatusFilter = value;
                    _bookingsVisibleCount = 10;
                  });
                },
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildPortalDropdown<String>(
                dropdownKey: const Key('booking_sort_dropdown'),
                label: 'Sắp xếp',
                value: _bookingSortBy,
                items: sortOptions.map((opt) => DropdownMenuItem(
                  key: Key('booking_sort_${opt.$1}'),
                  value: opt.$1,
                  child: Text(opt.$2, overflow: TextOverflow.ellipsis),
                )).toList(),
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
            ...visibleBookings.map(_buildBookingItemCard),
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

    return Container(
      key: Key('host_booking_card_$bookingId'),
      margin: const EdgeInsets.only(bottom: 12),
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
              Text(
                '#$bookingId • $listingTitle',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              _buildStatusPill(display.label, display.code),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.users, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text('$guestName · $guestsCount khách',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              )),
              if (guestPhone.isNotEmpty)
                IconButton(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  tooltip: 'Liên hệ khách',
                  icon: const Icon(
                    LucideIcons.phone,
                    size: 18,
                    color: AppColors.iconStrong,
                  ),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(guestName),
                      content: SelectableText(guestPhone),
                      actions: [TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Đóng'),
                      )],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.calendar, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '${_formatBookingDate(checkIn)} → ${_formatBookingDate(checkOut)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              )),
            ],
          ),
          const SizedBox(height: 12),
          Text(formatHostVnd(totalPrice), style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
          )),
          if (actions.hasAnyAction) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (actions.canConfirm)
                  ElevatedButton.icon(
                    key: Key('booking_confirm_btn_$bookingId'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(110, 48),
                      shape: const StadiumBorder(),
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
                      minimumSize: const Size(110, 48),
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    onPressed: isBusy
                        ? null
                        : () => _handleBookingAction(booking, 'check_in'),
                    icon: const Icon(AppSemanticIcons.checkIn, size: 15),
                    label: const Text('Check-in'),
                  ),
                if (actions.canCheckOut)
                  ElevatedButton.icon(
                    key: Key('booking_checkout_btn_$bookingId'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(110, 48),
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
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
                      minimumSize: const Size(96, 48),
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.border),
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

  void _selectWeekendDays() {
    setState(() {
      for (final d in _calendarDays) {
        final parsed = DateTime.tryParse(d.date);
        if (parsed != null &&
            (parsed.weekday == DateTime.saturday ||
                parsed.weekday == DateTime.sunday)) {
          final isBooked =
              d.bookingStatus != null && d.bookingStatus!.isNotEmpty;
          if (!isBooked) {
            _selectedCalendarDates.add(d.date);
          }
        }
      }
    });
  }

  void _selectAvailableDays() {
    setState(() {
      for (final d in _calendarDays) {
        final isBooked =
            d.bookingStatus != null && d.bookingStatus!.isNotEmpty;
        final isBlocked = !d.isAvailable || d.isBlockedByHost;
        if (!isBooked && !isBlocked) {
          _selectedCalendarDates.add(d.date);
        }
      }
    });
  }

  void _selectAllMonthDays() {
    setState(() {
      for (final d in _calendarDays) {
        final isBooked =
            d.bookingStatus != null && d.bookingStatus!.isNotEmpty;
        if (!isBooked) {
          _selectedCalendarDates.add(d.date);
        }
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
      final idStr = '${l['listingId'] ?? l['id'] ?? ''}'.toLowerCase();
      final title = (l['title'] ?? '').toString().toLowerCase();
      final address = '${l['addressLine'] ?? ''} ${l['city'] ?? ''}'.toLowerCase();
      return title.contains(query) ||
          address.contains(query) ||
          idStr.contains(query) ||
          '#$idStr'.contains(query);
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
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                  if (_calendarListingId != null)
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
          const SizedBox(height: 14),
          HostSheetSyncCard(
            onCalendarChanged: () {
              _fetchListings();
              if (_calendarListingId != null) {
                _fetchCalendarDays();
              }
            },
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
                                id.isNotEmpty
                                    ? 'Mã #$id · $statusTextVi'
                                    : statusTextVi,
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
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
                      final isSelected =
                          _selectedCalendarDates.contains(day.date);
                      final isBooked = day.isBooked ||
                          (day.bookingStatus != null &&
                              day.bookingStatus!.isNotEmpty);
                      final isPast = day.isPast;
                      final isEditable =
                          day.isEditable() && !isBooked && !isPast;
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
                          if (!isEditable) {
                            setState(() {
                              _calendarError = isBooked
                                  ? 'Ngày ${day.date} đã có khách đặt phòng, không thể chỉnh sửa.'
                                  : 'Ngày ${day.date} đã qua hoặc không thuộc quyền chỉnh sửa.';
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
                              Text(
                                day.date.split('-').last.replaceFirst(RegExp(r'^0'), ''),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: dayNumColor,
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

  Widget _buildGuestsSection() {
    final guestMap = <String, Map<String, dynamic>>{};
    for (final b in _bookings) {
      final name = (b['guestName'] ?? b['customerName'] ?? 'Khách lưu trú')
          .toString()
          .trim();
      final email = (b['guestEmail'] ?? '').toString().trim();
      final phone = (b['guestPhone'] ?? '').toString().trim();
      final key = '${name.toLowerCase()}|${email.toLowerCase()}|$phone';
      final amount = b['totalPrice'] is num
          ? (b['totalPrice'] as num).toDouble()
          : (double.tryParse('${b['totalPrice'] ?? 0}') ?? 0);

      final existing = guestMap[key];
      if (existing == null) {
        guestMap[key] = {
          'name': name,
          'email': email,
          'phone': phone,
          'bookingCount': 1,
          'totalSpent': amount,
          'lastCheckIn': (b['checkInDate'] ?? '').toString().split('T').first,
        };
      } else {
        existing['bookingCount'] = (existing['bookingCount'] as int) + 1;
        existing['totalSpent'] = (existing['totalSpent'] as double) + amount;
      }
    }

    final query = _guestSearchQuery.trim().toLowerCase();
    final guests = guestMap.values.where((g) {
      if (query.isEmpty) return true;
      final haystack = '${g['name']} ${g['email']} ${g['phone']}'.toLowerCase();
      return haystack.contains(query);
    }).toList();

    guests.sort((a, b) {
      if (_guestSortBy == 'bookings_desc') {
        final ba = (a['bookingCount'] as int?) ?? 0;
        final bb = (b['bookingCount'] as int?) ?? 0;
        return bb.compareTo(ba);
      }
      if (_guestSortBy == 'name_asc') {
        return (a['name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['name'] ?? '').toString().toLowerCase());
      }
      final sa = (a['totalSpent'] as double?) ?? 0;
      final sb = (b['totalSpent'] as double?) ?? 0;
      return sb.compareTo(sa);
    });

    final visibleGuests = guests.take(_guestsVisibleCount).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Khách lưu trú',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Danh sách khách hàng đã đặt phòng tại các chỗ nghỉ của bạn.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('guests_search_input'),
            controller: _guestSearchCtrl,
            onChanged: (v) => setState(() {
              _guestSearchQuery = v;
              _guestsVisibleCount = 10;
            }),
            decoration: InputDecoration(
              labelText: 'Tìm theo tên, email hoặc số điện thoại',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ('spent_desc', 'Chi tiêu cao nhất'),
              ('bookings_desc', 'Nhiều lượt đặt nhất'),
              ('name_asc', 'Tên A → Z'),
            ].map((opt) {
              return _HostUnderlineTab(
                key: Key('guest_sort_${opt.$1}'),
                label: Text(opt.$2),
                selected: _guestSortBy == opt.$1,
                onSelected: (_) => setState(() => _guestSortBy = opt.$1),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (_loadingBookings)
            const Center(child: CircularProgressIndicator())
          else if (guests.isEmpty)
            _buildEmptyBox('Chưa có dữ liệu khách lưu trú phù hợp.')
          else ...[
            ...visibleGuests.map((g) {
              return Container(
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
                          g['name'].toString(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [g['email'], g['phone']]
                              .where((s) => s != null && '$s'.isNotEmpty)
                              .join(' • '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${g['bookingCount']} lượt đặt • Tổng: ${formatHostVnd(g['totalSpent'])}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (guests.length > visibleGuests.length)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  key: const Key('guests_load_more_btn'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(160, 48),
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => setState(() => _guestsVisibleCount += 10),
                  child: Text(
                    'Xem thêm (${guests.length - visibleGuests.length} khách)',
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

  Widget _buildMessagesSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tin nhắn',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Trao đổi với khách hàng về chỗ nghỉ và lịch đặt phòng.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(110, 48),
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: const StadiumBorder(),
                    ),
                    onPressed:
                        _loadingConversations ? null : _fetchConversations,
                    icon: const Icon(
                      AppSemanticIcons.retry,
                      size: 16,
                      color: AppColors.iconStrong,
                    ),
                    label: const Text('Tải lại'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('host_messages_open_full_btn'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(140, 48),
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () {
                      final convId = _selectedConversationId;
                      if (convId != null && convId.isNotEmpty) {
                        _navigatePortalRoute(
                          context,
                          '/messages?conversationId=$convId',
                        );
                      } else {
                        _navigatePortalRoute(context, '/messages');
                      }
                    },
                    icon: const Icon(
                      AppSemanticIcons.messageHost,
                      size: 16,
                      color: AppColors.iconStrong,
                    ),
                    label: const Text('Hộp thư đầy đủ'),
                  ),
                ],
              ),
            ],
          ),
          if (_conversationsError != null) ...[
            const SizedBox(height: 16),
            _buildInlineError(
              _conversationsError!,
              onRetry: _fetchConversations,
            ),
          ],
          const SizedBox(height: 16),
          if (_loadingConversations)
            const Center(child: CircularProgressIndicator())
          else if (_conversations.isEmpty)
            _buildEmptyBox(
              'Chưa có cuộc trò chuyện nào. Tin nhắn từ khách hàng sẽ hiển thị tại đây.',
            )
          else ...[
            _buildPortalDropdown<String>(
              dropdownKey: const Key('messages_conversation_dropdown'),
              label: 'Chọn cuộc trò chuyện',
              value: _selectedConversationId,
              items: _conversations.map((c) {
                final id = '${c['conversationId'] ?? c['id']}';
                final other = c['otherParticipant'] is Map
                    ? Map<String, dynamic>.from(c['otherParticipant'] as Map)
                    : null;
                final participantName = (other?['fullName'] ??
                        other?['name'] ??
                        c['guestName'] ??
                        c['title'] ??
                        'Hội thoại #$id')
                    .toString();
                final listingTitle =
                    (c['listingTitle'] ?? '').toString().trim();
                final title = listingTitle.isNotEmpty
                    ? '$participantName • $listingTitle'
                    : participantName;
                return DropdownMenuItem<String>(
                  value: id,
                  child: Text(title, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedConversationId = v);
                _fetchMessagesForConversation(v);
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_conversationMessages.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Chưa có tin nhắn trong cuộc trò chuyện này.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ..._conversationMessages.map((m) {
                      final content =
                          (m['content'] ?? m['body'] ?? '').toString();
                      final sender = (m['senderName'] ??
                              m['sender']?['fullName'] ??
                              'Người dùng')
                          .toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('$sender: $content'),
                      );
                    }),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('host_message_input'),
                          controller: _messageInputCtrl,
                          decoration: InputDecoration(
                            hintText: 'Nhập tin nhắn...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
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
                          minimumSize: const Size(88, 48),
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        onPressed: _sendingMessage ? null : _sendHostMessage,
                        child: const Text('Gửi'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 12),
                Text(
                  _reviews.isEmpty
                      ? 'Điểm trung bình: Chưa có đánh giá (0 đánh giá)'
                      : 'Điểm trung bình thực tế: ${avgRating.toStringAsFixed(2)} ★ (${_reviews.length} đánh giá)',
                  key: const Key('reviews_real_summary_text'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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
              final createdAt =
                  (review['createdAt'] ?? '').toString().split('T').first;
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
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$reviewerName • ${'★' * rating.clamp(0, 5)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          createdAt,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      comment,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (hostReply.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Phản hồi của Host: $hostReply',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            key: Key('review_reply_submit_$reviewId'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(140, 48),
                              shape: const StadiumBorder(),
                              elevation: 0,
                            ),
                            onPressed: _savingReviewId != null
                                ? null
                                : () => _submitReviewReply(reviewId),
                            icon: isSavingThis
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(LucideIcons.reply, size: 16),
                            label: Text(
                              isSavingThis ? 'Đang gửi...' : 'Gửi phản hồi',
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Doanh thu', style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          )),
          const SizedBox(height: 20),
          Row(children: [
              Expanded(child: _buildPortalDropdown<String>(
                dropdownKey: const Key('report_range_dropdown'),
                label: 'Thời gian',
                value: _reportRange,
                items: ranges.map((option) => DropdownMenuItem(
                  key: Key('report_range_${option.$1}'),
                  value: option.$1,
                  child: Text(option.$2, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _reportRange = value);
                  _fetchRevenueReport();
                },
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildPortalDropdown<String>(
                dropdownKey: const Key('report_group_dropdown'),
                label: 'Theo kỳ',
                value: _reportGroup,
                items: groups.map((option) => DropdownMenuItem(
                  key: Key('report_group_${option.$1}'),
                  value: option.$1,
                  child: Text(option.$2, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _reportGroup = value);
                  _fetchRevenueReport();
                },
              )),
          ]),
          const SizedBox(height: 12),
                _buildPortalDropdown<String>(
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
                      child: Text('Tất cả chỗ nghỉ'),
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
          if (_reportError != null) ...[
            const SizedBox(height: 16),
            _buildInlineError(
              _reportError!,
              onRetry: _fetchRevenueReport,
            ),
          ],
          const SizedBox(height: 16),
          _buildPropertySummary([
            (
              label: 'Doanh thu gộp',
              value: _loadingReport ? '—' : formatHostVnd(_revenueReport.grossRevenue),
            ),
            (
              label: 'Thực nhận',
              value: _loadingReport ? '—' : formatHostVnd(_revenueReport.hostRevenue),
            ),
            (
              label: 'Phí nền tảng',
              value: _loadingReport ? '—' : formatHostVnd(_revenueReport.platformRevenue),
            ),
            (
              label: 'Đặt phòng',
              value: _loadingReport ? '—' : '${_revenueReport.bookingCount}',
            ),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thực nhận theo kỳ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (_loadingReport)
                  const Center(child: CircularProgressIndicator())
                else if (_revenueReport.series.isEmpty)
                  const Text(
                    'Chưa có doanh thu trong kỳ này.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  ..._revenueReport.series.map((row) {
                    final ratio =
                        (row.hostRevenue / maxRevenue).clamp(0.0, 1.0);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 8,
                            children: [
                              Text(
                                '${row.period} · ${row.bookingCount} đặt phòng',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                formatHostVnd(row.hostRevenue),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Chi tiết', style: TextStyle(fontSize: 12)),
                            children: [
                              ListTile(
                                title: const Text('Doanh thu gộp'),
                                subtitle: Text(formatHostVnd(row.grossRevenue)),
                              ),
                              ListTile(
                                title: const Text('Phí nền tảng'),
                                subtitle: Text(formatHostVnd(row.platformRevenue)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 8,
                              backgroundColor: AppColors.surfaceMuted,
                              color: AppColors.primary,
                            ),
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
                            Container(
                              width: 64,
                              height: 64,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.borderSoft),
                              ),
                              child: ClipOval(
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: (_hostProfile?['avatarUrl'] != null &&
                                          '${_hostProfile!['avatarUrl']}'
                                              .trim()
                                              .isNotEmpty)
                                      ? AppImage(
                                          url: '${_hostProfile!['avatarUrl']}'
                                              .trim(),
                                          fit: BoxFit.cover,
                                        )
                                      : const Center(
                                          child: Icon(
                                            AppSemanticIcons.userProfile,
                                            size: 26,
                                            color: AppColors.iconStrong,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textStrong,
                                side: const BorderSide(color: AppColors.border),
                                minimumSize: const Size(140, 48),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: _uploadingAvatar
                                  ? null
                                  : _handlePickAndUploadAvatar,
                              icon: const Icon(
                                AppSemanticIcons.changeAvatar,
                                size: 16,
                                color: AppColors.iconStrong,
                              ),
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
                            prefixIcon: const Icon(
                              LucideIcons.search,
                              size: 18,
                              color: AppColors.iconStrong,
                            ),
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
                          enableSuggestions: false,
                          autocorrect: false,
                          enableIMEPersonalizedLearning: false,
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
