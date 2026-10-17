import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/date/booking_date.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../domain/entities/booking.dart';
import '../view_models/trips_view_model.dart';

/// Complete port of `Source goc/frontend/src/views/pages/MultiBooking/MultiBookingPage.tsx` (`/gio-cho-dat`).
///
/// Fixes BUG-19, BUG-20, BUG-32:
/// - Edits queue items via `updateItem()` instead of `addItem()`.
/// - Uses `BookingQueueItem.calculatePriceEstimate()` for accurate temporary pricing (weekday/weekend nights, fixed surcharge not multiplied by nights, extra guest fees).
/// - Validates per-item dates & guests before submitting and maps `BulkBookingException` per-item backend errors onto the specific villa cards.
/// - Never clears the queue before `POST /api/bookings/bulk` succeeds.
/// - Renders `BookingResultCard` for ALL created bookings (1..N) so the user can pay each unpaid booking individually without losing bookings #2..#N.
class MultiBookingScreen extends ConsumerStatefulWidget {
  const MultiBookingScreen({super.key});

  @override
  ConsumerState<MultiBookingScreen> createState() => _MultiBookingScreenState();
}

class _MultiBookingScreenState extends ConsumerState<MultiBookingScreen>
    with WidgetsBindingObserver {
  final TextEditingController _specialRequestsCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _isRefreshingBookings = false;
  String? _errorMessage;
  Map<int, String> _itemErrorsByIndex = {};
  List<Booking> _createdBookings = [];
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _createdBookings.isNotEmpty) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _specialRequestsCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        _createdBookings.isNotEmpty) {
      _refreshCreatedBookings();
    }
  }

  int _calcItemTotal(BookingQueueItem item) {
    return item.calculatePriceEstimate().estimatedTotal;
  }

  Future<void> _pickDatesForItem(int index, BookingQueueItem item) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final parsedStart = DateTime.tryParse(item.checkIn ?? '');
    final parsedEnd = DateTime.tryParse(item.checkOut ?? '');

    final initialStart = (parsedStart != null && !parsedStart.isBefore(today))
        ? parsedStart
        : today.add(const Duration(days: 1));
    final initialEnd = (parsedEnd != null && parsedEnd.isAfter(initialStart))
        ? parsedEnd
        : initialStart.add(const Duration(days: 2));

    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: initialStart,
        end: initialEnd,
      ),
    );

    if (picked != null && mounted) {
      final updated = item.copyWith(
        checkIn: BookingDate.fromDateTime(picked.start).toIsoDate(),
        checkOut: BookingDate.fromDateTime(picked.end).toIsoDate(),
      );
      await ref.read(bookingQueueProvider.notifier).updateItem(updated);
      setState(() {
        _itemErrorsByIndex.remove(index);
        _errorMessage = null;
      });
    }
  }

  Future<void> _updateItemGuests(
    int index,
    BookingQueueItem item,
    int newGuestsCount,
  ) async {
    final clamped = newGuestsCount.clamp(1, item.maxGuests);
    final updated = item.copyWith(guestsCount: clamped);
    await ref.read(bookingQueueProvider.notifier).updateItem(updated);
    if (mounted) {
      setState(() {
        _itemErrorsByIndex.remove(index);
      });
    }
  }

  Map<int, String> _validateQueueItems(List<BookingQueueItem> queue) {
    final errors = <int, String>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var i = 0; i < queue.length; i++) {
      final item = queue[i];
      final checkIn = DateTime.tryParse(item.checkIn ?? '');
      final checkOut = DateTime.tryParse(item.checkOut ?? '');
      if (checkIn == null || checkOut == null) {
        errors[i] = 'Vui lòng chọn ngày nhận phòng và trả phòng hợp lệ.';
        continue;
      }
      if (checkIn.isBefore(today)) {
        errors[i] = 'Ngày nhận phòng không được ở trong quá khứ.';
        continue;
      }
      final nights = checkOut.difference(checkIn).inDays;
      if (nights < 1) {
        errors[i] = 'Ngày trả phòng phải sau ngày nhận phòng ít nhất 1 đêm.';
        continue;
      }
      if (nights > 60) {
        errors[i] = 'Thời gian lưu trú tối đa cho mỗi đơn là 60 đêm.';
        continue;
      }
      if (item.guestsCount < 1 || item.guestsCount > item.maxGuests) {
        errors[i] =
            'Số khách phải từ 1 đến tối đa ${item.maxGuests} khách cho căn này.';
      }
    }
    return errors;
  }

  Future<void> _submitBulkBooking(List<BookingQueueItem> queue) async {
    if (queue.isEmpty || _isSubmitting) return;

    if (queue.length > PreferencesService.maxBookingQueueSize) {
      setState(() {
        _errorMessage =
            'Chỉ có thể đặt tối đa ${PreferencesService.maxBookingQueueSize} căn trong một lần.';
      });
      return;
    }

    final validationErrors = _validateQueueItems(queue);
    if (validationErrors.isNotEmpty) {
      setState(() {
        _itemErrorsByIndex = validationErrors;
        _errorMessage =
            'Vui lòng kiểm tra lại thông tin ngày lưu trú hoặc số khách ở các căn báo lỗi.';
      });
      return;
    }

    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để đặt nhiều chỗ nghỉ cùng lúc.'),
        ),
      );
      await context.push('/dang-nhap');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _itemErrorsByIndex = {};
    });

    try {
      final specialRequests = _specialRequestsCtrl.text.trim();
      final payload = queue.map((item) {
        return <String, dynamic>{
          'listingId': int.tryParse(item.listingId) ?? item.listingId,
          'checkInDate': item.checkIn,
          'checkOutDate': item.checkOut,
          'guestsCount': item.guestsCount,
          if (item.couponCode != null && item.couponCode!.trim().isNotEmpty)
            'couponCode': item.couponCode!.trim().toUpperCase(),
          if (specialRequests.isNotEmpty) 'specialRequests': specialRequests,
        };
      }).toList();

      final createdBookings = await ref
          .read(bookingRepositoryProvider)
          .createBulkBookings(items: payload);

      // Clear queue ONLY after backend confirms bulk creation succeeded
      await ref.read(bookingQueueProvider.notifier).clear();
      ref.invalidate(myBookingsProvider);

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _createdBookings = createdBookings;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã tạo thành công ${createdBookings.length} đơn đặt phòng! Vui lòng hoàn tất thanh toán cho từng căn.',
          ),
        ),
      );
    } on BulkBookingException catch (e) {
      if (!mounted) return;
      final perItemMap = <int, String>{};
      for (final itemErr in e.itemErrors) {
        if (itemErr.index >= 0 && itemErr.index < queue.length) {
          perItemMap[itemErr.index] = itemErr.message;
        }
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
        _itemErrorsByIndex = perItemMap;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _refreshCreatedBookings() async {
    if (_createdBookings.isEmpty || _isRefreshingBookings || !mounted) return;
    setState(() => _isRefreshingBookings = true);

    final repo = ref.read(bookingRepositoryProvider);
    final updated = <Booking>[];
    for (final existing in _createdBookings) {
      try {
        final fresh = await repo.getBookingById(existing.id);
        updated.add(fresh ?? existing);
      } catch (_) {
        updated.add(existing);
      }
    }

    if (!mounted) return;
    setState(() {
      _createdBookings = updated;
      _isRefreshingBookings = false;
    });
    ref.invalidate(myBookingsProvider);
  }

  Future<void> _openPaymentForBooking(Booking booking) async {
    await context.push('/thanh-toan/${booking.id}');
    if (mounted) {
      await _refreshCreatedBookings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(bookingQueueProvider);
    final grandTotal =
        queue.fold<int>(0, (sum, item) => sum + _calcItemTotal(item));
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopHeader(currentPath: '/gio-cho-dat'),
            Expanded(
              child: _createdBookings.isNotEmpty
                  ? _buildCreatedBookingsResultView()
                  : queue.isEmpty
                      ? AppEmptyView(
                          icon: LucideIcons.shoppingCart,
                          title: 'Giỏ chờ đặt phòng đang trống',
                          description:
                              'Bạn có thể thêm tối đa 5 căn biệt thự vào giỏ chờ để so sánh và gửi yêu cầu đặt nhiều căn cùng lúc.',
                          actionText: 'Khám phá biệt thự Vũng Tàu',
                          onAction: () => context.push('/search'),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.only(bottom: bottomInset + 24),
                          child: Column(
                            children: [
                              Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 1080),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 8,
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Giỏ chờ đặt nhiều căn (Multi-Booking)',
                                                  style: TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                Text(
                                                  'Đang chọn ${queue.length}/${PreferencesService.maxBookingQueueSize} căn • Tự động giữ lịch đồng thời trên hệ thống',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                minHeight: 48,
                                              ),
                                              child: TextButton.icon(
                                                onPressed: _isSubmitting
                                                    ? null
                                                    : () => ref
                                                        .read(
                                                          bookingQueueProvider
                                                              .notifier,
                                                        )
                                                        .clear(),
                                                icon: const Icon(
                                                  LucideIcons.trash2,
                                                  size: 16,
                                                  color: AppColors.iconStrong,
                                                ),
                                                label: const Text(
                                                    'Xóa toàn bộ giỏ'),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        if (_errorMessage != null)
                                          Container(
                                            width: double.infinity,
                                            margin: const EdgeInsets.only(
                                                bottom: 16),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: AppColors.errorSoft,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: AppColors.error),
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
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    _errorMessage!,
                                                    style: const TextStyle(
                                                      color: AppColors.error,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        for (var i = 0;
                                            i < queue.length;
                                            i++) ...[
                                          _buildQueueItemCard(i, queue[i]),
                                        ],
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: _specialRequestsCtrl,
                                          maxLines: 2,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Ghi chú chung cho đoàn (giờ nhận phòng, yêu cầu xuất hóa đơn...)',
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                                color: AppColors.borderSoft),
                                          ),
                                          child: Wrap(
                                            spacing: 16,
                                            runSpacing: 12,
                                            alignment:
                                                WrapAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Tổng tạm tính (${queue.length} căn biệt thự)',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    CurrencyFormatter.formatVnd(
                                                        grandTotal),
                                                    style: const TextStyle(
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  const Text(
                                                    'Số tiền chính thức sẽ được máy chủ chốt khi tạo đơn.',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                  minHeight: 48,
                                                ),
                                                child: ElevatedButton.icon(
                                                  onPressed: _isSubmitting
                                                      ? null
                                                      : () =>
                                                          _submitBulkBooking(
                                                              queue),
                                                  icon: const Icon(
                                                    LucideIcons.check,
                                                    size: 18,
                                                    color: Colors.white,
                                                  ),
                                                  label: Text(
                                                    _isSubmitting
                                                        ? 'Đang xử lý...'
                                                        : 'Xác nhận đặt ${queue.length} căn',
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppColors.primary,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 22,
                                                      vertical: 14,
                                                    ),
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
                              ),
                              const AppFooter(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueItemCard(int index, BookingQueueItem item) {
    final estimate = item.calculatePriceEstimate();
    final itemError = _itemErrorsByIndex[index];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: itemError != null ? AppColors.error : AppColors.borderSoft,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 100,
                    height: 80,
                    child: AppImage(
                      url: item.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.location,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tạm tính (${estimate.nights} đêm): ${CurrencyFormatter.formatVnd(estimate.estimatedTotal)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    tooltip: 'Xóa căn này',
                    onPressed: _isSubmitting
                        ? null
                        : () => ref
                            .read(bookingQueueProvider.notifier)
                            .removeItem(item.listingId),
                    icon: const Icon(
                      LucideIcons.trash2,
                      size: 18,
                      color: AppColors.iconStrong,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _isSubmitting
                      ? null
                      : () => _pickDatesForItem(index, item),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.calendar,
                            size: 16,
                            color: AppColors.iconStrong,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${item.checkIn} → ${item.checkOut}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Số khách:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        onPressed: !_isSubmitting && item.guestsCount > 1
                            ? () => _updateItemGuests(
                                  index,
                                  item,
                                  item.guestsCount - 1,
                                )
                            : null,
                        icon: const Icon(
                          LucideIcons.minus,
                          size: 16,
                          color: AppColors.iconStrong,
                        ),
                      ),
                    ),
                    Text(
                      '${item.guestsCount}/${item.maxGuests}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        onPressed:
                            !_isSubmitting && item.guestsCount < item.maxGuests
                                ? () => _updateItemGuests(
                                      index,
                                      item,
                                      item.guestsCount + 1,
                                    )
                                : null,
                        icon: const Icon(
                          LucideIcons.plus,
                          size: 16,
                          color: AppColors.iconStrong,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Mini breakdown summary
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    'Tiền phòng: ${CurrencyFormatter.formatVnd(estimate.baseNightsAmount)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (estimate.extraGuestFeeAmount > 0)
                    Text(
                      'Phụ thu khách (${estimate.extraGuests} khách): ${CurrencyFormatter.formatVnd(estimate.extraGuestFeeAmount)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (estimate.surchargeAmount > 0)
                    Text(
                      'Phụ thu cố định: ${CurrencyFormatter.formatVnd(estimate.surchargeAmount)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (estimate.cleaningFee + estimate.serviceFee > 0)
                    Text(
                      'Phí dịch vụ & vệ sinh: ${CurrencyFormatter.formatVnd(estimate.cleaningFee + estimate.serviceFee)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (itemError != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    LucideIcons.triangleAlert,
                    size: 15,
                    color: AppColors.iconStrong,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      itemError,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreatedBookingsResultView() {
    final totalConfirmedAmount = _createdBookings.fold<int>(
      0,
      (sum, b) => sum + b.totalAmount,
    );
    final unpaidCount = _createdBookings.where((b) => b.canPayNow).length;

    return SingleChildScrollView(
      child: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đã giữ lịch ${_createdBookings.length} căn biệt thự',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              unpaidCount > 0
                                  ? 'Còn $unpaidCount/${_createdBookings.length} đơn cần hoàn tất thanh toán để xác nhận giữ chỗ.'
                                  : 'Tất cả các đơn đặt phòng đã được xử lý thanh toán.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: OutlinedButton.icon(
                            onPressed: _isRefreshingBookings
                                ? null
                                : _refreshCreatedBookings,
                            icon: const Icon(
                              LucideIcons.refreshCw,
                              size: 16,
                              color: AppColors.iconStrong,
                            ),
                            label: Text(
                              _isRefreshingBookings
                                  ? 'Đang cập nhật...'
                                  : 'Cập nhật trạng thái',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < _createdBookings.length; i++)
                      BookingResultCard(
                        index: i + 1,
                        booking: _createdBookings[i],
                        onPayNow: () =>
                            _openPaymentForBooking(_createdBookings[i]),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tổng giá trị ${_createdBookings.length} đơn đặt phòng',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                CurrencyFormatter.formatVnd(
                                    totalConfirmedAmount),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 48),
                                child: ElevatedButton(
                                  onPressed: () => context.go('/account/trips'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.textPrimary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Quản lý trong Chuyến đi'),
                                ),
                              ),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 48),
                                child: OutlinedButton(
                                  onPressed: () => context.go('/search'),
                                  child: const Text('Tiếp tục tìm biệt thự'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const AppFooter(),
        ],
      ),
    );
  }
}

/// Complete port of `BookingResultCard` in `MultiBookingPage.tsx`.
class BookingResultCard extends StatelessWidget {
  final int index;
  final Booking booking;
  final VoidCallback onPayNow;

  const BookingResultCard({
    super.key,
    required this.index,
    required this.booking,
    required this.onPayNow,
  });

  String _formatHoldCountdown(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final remainingSeconds = booking.computeRemainingPaymentSeconds();
    final canPay = booking.canPayNow;
    final isPaid = booking.status == 'paid' ||
        booking.status == 'confirmed' ||
        booking.status == 'checked_in' ||
        booking.status == 'completed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Căn #$index • Mã đơn #${booking.id}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  booking.statusDisplay,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isPaid
                        ? AppColors.textPrimary
                        : (booking.isCancelled
                            ? AppColors.error
                            : AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              booking.propertyName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.calendar,
                      size: 15,
                      color: AppColors.iconStrong,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${booking.checkInDate} → ${booking.checkOutDate} (${booking.nights} đêm)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.users,
                      size: 15,
                      color: AppColors.iconStrong,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${booking.guestCount} khách',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (booking.status == 'pending_payment') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    LucideIcons.clock,
                    size: 15,
                    color: AppColors.iconStrong,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      remainingSeconds > 0
                          ? 'Thời gian giữ chỗ còn lại: ${_formatHoldCountdown(remainingSeconds)}'
                          : 'Đã hết thời gian giữ chỗ 15 phút',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: remainingSeconds > 0
                            ? AppColors.textSecondary
                            : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 24, color: AppColors.divider),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng thanh toán đơn này',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatVnd(booking.totalAmount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                if (canPay)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: ElevatedButton.icon(
                      onPressed: onPayNow,
                      icon: const Icon(
                        LucideIcons.creditCard,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text('Thanh toán đơn này'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  )
                else if (isPaid)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.circleCheck,
                        size: 18,
                        color: AppColors.iconStrong,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Đã hoàn tất thanh toán',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
