import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/booking.dart';
import '../view_models/trips_view_model.dart';

/// Wraps the entire application's Navigator shell to display a pinned sticky banner
/// at the top whenever the authenticated user has an active pending booking hold.
class GlobalPendingBookingWrapper extends ConsumerWidget {
  final Widget child;

  const GlobalPendingBookingWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBooking = ref.watch(activePendingBookingProvider);
    final router = ref.watch(appRouterProvider);

    String currentPath = '/';
    try {
      final configPath = router.routerDelegate.currentConfiguration.uri.path;
      if (configPath.isNotEmpty && configPath != '/') {
        currentPath = configPath;
      } else {
        currentPath = router.routeInformationProvider.value.uri.path;
      }
    } catch (_) {
      try {
        currentPath = router.routeInformationProvider.value.uri.path;
      } catch (_) {}
    }

    final isExcludedPath = activeBooking != null &&
        (currentPath == '/thanh-toan/${activeBooking.id}' ||
            currentPath == '/thanh-toan/ket-qua');

    final showBanner = activeBooking != null && !isExcludedPath;

    if (!showBanner) {
      return child;
    }

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            GlobalPendingBookingBanner(booking: activeBooking),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Banner displayed directly underneath headers (such as `AppTopHeader` or `AppBar`)
/// when the user has an active pending booking hold.
class GlobalPendingBookingHeaderBanner extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;

  const GlobalPendingBookingHeaderBanner({
    super.key,
    this.margin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBooking = ref.watch(activePendingBookingProvider);
    if (activeBooking == null) {
      return const SizedBox.shrink();
    }

    final router = ref.watch(appRouterProvider);
    String currentPath = '/';
    try {
      final configPath = router.routerDelegate.currentConfiguration.uri.path;
      if (configPath.isNotEmpty && configPath != '/') {
        currentPath = configPath;
      } else {
        currentPath = router.routeInformationProvider.value.uri.path;
      }
    } catch (_) {
      try {
        currentPath = router.routeInformationProvider.value.uri.path;
      } catch (_) {}
    }

    if (currentPath.contains('/thanh-toan') ||
        currentPath.contains('/pay')) {
      return const SizedBox.shrink();
    }

    return GlobalPendingBookingBanner(
      booking: activeBooking,
      margin: margin,
    );
  }
}

/// A pinned hold countdown banner matching the app's design system.
/// Displays a live countdown pill ("09:45") and navigates to the payment screen on tap.
class GlobalPendingBookingBanner extends ConsumerStatefulWidget {
  final Booking booking;
  final EdgeInsetsGeometry? margin;

  const GlobalPendingBookingBanner({
    super.key,
    required this.booking,
    this.margin,
  });

  @override
  ConsumerState<GlobalPendingBookingBanner> createState() =>
      _GlobalPendingBookingBannerState();
}

class _GlobalPendingBookingBannerState
    extends ConsumerState<GlobalPendingBookingBanner> {
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  String? _initializedBookingKey;

  @override
  void initState() {
    super.initState();
    _syncCountdown();
  }

  @override
  void didUpdateWidget(covariant GlobalPendingBookingBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking.id != widget.booking.id ||
        oldWidget.booking.paymentDeadline != widget.booking.paymentDeadline ||
        oldWidget.booking.remainingPaymentSeconds !=
            widget.booking.remainingPaymentSeconds) {
      _syncCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _syncCountdown() {
    final bookingKey =
        '${widget.booking.id}_${widget.booking.paymentDeadline?.toIso8601String()}_${widget.booking.remainingPaymentSeconds}';
    if (_initializedBookingKey == bookingKey) return;
    _initializedBookingKey = bookingKey;

    _countdownTimer?.cancel();
    _remainingSeconds = widget.booking.computeRemainingPaymentSeconds();

    if (_remainingSeconds <= 0) {
      _remainingSeconds = 0;
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (widget.booking.paymentDeadline != null) {
        final next = widget.booking.computeRemainingPaymentSeconds();
        if (next <= 0) {
          timer.cancel();
          setState(() => _remainingSeconds = 0);
          ref.invalidate(myBookingsProvider);
        } else {
          setState(() => _remainingSeconds = next);
        }
      } else {
        if (_remainingSeconds <= 1) {
          timer.cancel();
          setState(() => _remainingSeconds = 0);
          ref.invalidate(myBookingsProvider);
        } else {
          setState(() => _remainingSeconds--);
        }
      }
    });
  }

  String _formatCountdown(int seconds) {
    final clamped = seconds > 0 ? seconds : 0;
    final m = (clamped ~/ 60).toString().padLeft(2, '0');
    final s = (clamped % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _navigateToPayment() {
    final router = ref.read(appRouterProvider);
    final currentPath =
        router.routerDelegate.currentConfiguration.uri.path;
    final targetPath = '/thanh-toan/${widget.booking.id}';
    if (currentPath != targetPath) {
      router.push(targetPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Container(
          margin: widget.margin ?? const EdgeInsets.fromLTRB(16, 6, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.borderSoft,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _navigateToPayment,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: Countdown timer (đồng hồ, chữ đen, căn giữa theo chiều dài/chiều cao của banner)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 85),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatCountdown(_remainingSeconds),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),

                    // Center: Tên villa (căn giữa cho phù hợp)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          widget.booking.propertyName,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),

                    // Right: Chỉ giữ nút Thanh toán (hình oval, đẹp)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 85),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _navigateToPayment,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Thanh toán'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
