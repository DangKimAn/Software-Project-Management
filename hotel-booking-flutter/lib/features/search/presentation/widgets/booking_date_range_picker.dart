import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/date/booking_date.dart';
import '../../../../shared/animations/source_animations.dart';

/// `@keyframes datePop` interactive day cell wrapper respecting reduced motion.
class DatePopButton extends StatefulWidget {
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget child;

  const DatePopButton({
    super.key,
    required this.isSelected,
    this.onTap,
    required this.child,
  });

  @override
  State<DatePopButton> createState() => _DatePopButtonState();
}

class _DatePopButtonState extends State<DatePopButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final targetScale = _isPressed ? 0.92 : (widget.isSelected ? 1.08 : 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _isPressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) => setState(() => _isPressed = false)
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _isPressed = false)
          : null,
      onTap: widget.onTap,
      child: disableAnimations
          ? widget.child
          : AnimatedScale(
              scale: targetScale,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutBack,
              child: widget.child,
            ),
    );
  }
}

class BookingDateRangePicker extends StatefulWidget {
  final BookingDate? initialCheckIn;
  final BookingDate? initialCheckOut;
  final Set<BookingDate> bookedDates;
  final Set<String> bookedDatesIso;
  final BookingDate? minDate;
  final ValueChanged<(BookingDate?, BookingDate?)> onRangeSelected;

  const BookingDateRangePicker({
    super.key,
    this.initialCheckIn,
    this.initialCheckOut,
    this.bookedDates = const {},
    this.bookedDatesIso = const {},
    this.minDate,
    required this.onRangeSelected,
  });

  @override
  State<BookingDateRangePicker> createState() => _BookingDateRangePickerState();
}

class _BookingDateRangePickerState extends State<BookingDateRangePicker> {
  static const Color _rangeHighlightColor = Color(0xFFECFEFF);

  late DateTime _currentMonth;
  BookingDate? _checkIn;
  BookingDate? _checkOut;
  String? _errorMessage;

  BookingDate get _effectiveMinDate => widget.minDate ?? BookingDate.today();

  Set<BookingDate> get _effectiveBookedDates {
    if (widget.bookedDatesIso.isEmpty) return widget.bookedDates;
    return {
      ...widget.bookedDates,
      for (final iso in widget.bookedDatesIso)
        if (BookingDate.tryParseIso(iso) != null) BookingDate.tryParseIso(iso)!,
    };
  }

  /// Finds the earliest booked night strictly after [_checkIn] when selecting check-out.
  /// Per half-open interval `[checkIn, checkOut)`, this earliest booked date IS allowed
  /// as a check-out date, while dates strictly after it are blocked.
  BookingDate? get _firstBookedAfterCheckIn {
    if (_checkIn == null || _checkOut != null) return null;
    BookingDate? earliest;
    for (final b in _effectiveBookedDates) {
      if (b.isAfter(_checkIn!)) {
        if (earliest == null || b.isBefore(earliest)) {
          earliest = b;
        }
      }
    }
    return earliest;
  }

  @override
  void initState() {
    super.initState();
    _checkIn = widget.initialCheckIn;
    _checkOut = widget.initialCheckOut;
    final seed = _checkIn ?? widget.minDate ?? BookingDate.today();
    _currentMonth = DateTime(seed.year, seed.month);
  }

  @override
  void didUpdateWidget(covariant BookingDateRangePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCheckIn != oldWidget.initialCheckIn ||
        widget.initialCheckOut != oldWidget.initialCheckOut) {
      _checkIn = widget.initialCheckIn;
      _checkOut = widget.initialCheckOut;
    }
  }

  bool _canUseDayAsCheckOut(BookingDate day) {
    if (_checkIn == null || _checkOut != null) return false;
    if (!day.isAfter(_checkIn!)) return false;
    return BookingDate.isRangeAvailable(
      checkIn: _checkIn!,
      checkOut: day,
      bookedNights: _effectiveBookedDates,
    );
  }

  void _onDayTapped(BookingDate day) {
    if (day.isBefore(_effectiveMinDate)) {
      return;
    }

    final booked = _effectiveBookedDates;
    final isBookedNight = booked.contains(day);
    final isSelectingCheckOut =
        _checkIn != null && _checkOut == null && day.isAfter(_checkIn!);

    if (isBookedNight) {
      // Half-open [checkIn, checkOut): allow selecting the first booked date after checkIn as checkOut!
      if (isSelectingCheckOut && _canUseDayAsCheckOut(day)) {
        setState(() {
          _errorMessage = null;
          _checkOut = day;
          widget.onRangeSelected((_checkIn, _checkOut));
        });
        return;
      }
      setState(() => _errorMessage = 'Ngày này đã kín');
      return;
    }

    setState(() {
      _errorMessage = null;

      // If no check-in selected yet, or both already selected, start new selection
      if (_checkIn == null || (_checkIn != null && _checkOut != null)) {
        _checkIn = day;
        _checkOut = null;
        widget.onRangeSelected((_checkIn, null));
      } else {
        // We have check-in, selecting check-out
        if (day.isBefore(_checkIn!) || day.isAtSameMomentAs(_checkIn!)) {
          // Tapped before or same day -> reset check-in to this day
          _checkIn = day;
          _checkOut = null;
          widget.onRangeSelected((_checkIn, null));
        } else {
          // Check if range traverses any booked nights
          final isAvailable = BookingDate.isRangeAvailable(
            checkIn: _checkIn!,
            checkOut: day,
            bookedNights: booked,
          );

          if (!isAvailable) {
            _errorMessage = 'Ngày này đã kín';
          } else {
            _checkOut = day;
            widget.onRangeSelected((_checkIn, _checkOut));
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthFormat = DateFormat('MMMM yyyy', 'vi_VN');
    final monthTitle = monthFormat.format(_currentMonth);

    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1)
        .weekday; // 1 = Mon, 7 = Sun
    final firstBookedAfter = _firstBookedAfterCheckIn;

    return CalFadeIn(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Navigation Header (LucideIcons, 48x48 touch target, neutral color)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                button: true,
                label: 'Tháng trước',
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _currentMonth =
                          DateTime(_currentMonth.year, _currentMonth.month - 1);
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Icon(
                        LucideIcons.chevronLeft,
                        size: 20,
                        color: AppColors.iconStrong,
                      ),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  monthTitle.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle.copyWith(fontSize: 15),
                ),
              ),
              Semantics(
                button: true,
                label: 'Tháng tiếp theo',
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _currentMonth =
                          DateTime(_currentMonth.year, _currentMonth.month + 1);
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Icon(
                        LucideIcons.chevronRight,
                        size: 20,
                        color: AppColors.iconStrong,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Weekday labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].map((w) {
              return Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),

          // Calendar Grid with MonthInSwitcher transition (180ms ease-out)
          MonthInSwitcher(
            monthKey: '${_currentMonth.year}-${_currentMonth.month}',
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: (firstWeekday - 1) + daysInMonth,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 0,
              ),
              itemBuilder: (context, index) {
                if (index < firstWeekday - 1) {
                  return const SizedBox.shrink();
                }

                final dayNumber = index - (firstWeekday - 1) + 1;
                final date = BookingDate(
                  year: _currentMonth.year,
                  month: _currentMonth.month,
                  day: dayNumber,
                );

                final isPast = date.isBefore(_effectiveMinDate);
                final isBooked = _effectiveBookedDates.contains(date);
                final isAllowedCheckOutBoundary = firstBookedAfter != null &&
                    date.isAtSameMomentAs(firstBookedAfter);
                final isAfterFirstBooked =
                    firstBookedAfter != null && date.isAfter(firstBookedAfter);
                final isCheckIn =
                    _checkIn != null && date.isAtSameMomentAs(_checkIn!);
                final isCheckOut =
                    _checkOut != null && date.isAtSameMomentAs(_checkOut!);
                final isInRange = _checkIn != null &&
                    _checkOut != null &&
                    date.isAfter(_checkIn!) &&
                    date.isBefore(_checkOut!);

                return _buildCalendarDayCell(
                  date: date,
                  dayNumber: dayNumber,
                  isPast: isPast,
                  isBooked: isBooked && !isAllowedCheckOutBoundary,
                  isBlockedAfterBooked: isAfterFirstBooked,
                  isAllowedCheckOutBoundary: isAllowedCheckOutBoundary,
                  isCheckIn: isCheckIn,
                  isCheckOut: isCheckOut,
                  isInRange: isInRange,
                );
              },
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                _errorMessage!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.errorRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarDayCell({
    required BookingDate date,
    required int dayNumber,
    required bool isPast,
    required bool isBooked,
    required bool isBlockedAfterBooked,
    required bool isAllowedCheckOutBoundary,
    required bool isCheckIn,
    required bool isCheckOut,
    required bool isInRange,
  }) {
    Color? cellBg;
    Color textColor = AppColors.textStrong;
    TextDecoration? textDecoration;

    if (isCheckIn || isCheckOut) {
      cellBg = AppColors.primary;
      textColor = Colors.white;
    } else if (isInRange) {
      cellBg = _rangeHighlightColor;
      textColor = AppColors.primary;
    } else if (isPast) {
      textColor = AppColors.textTertiary;
    } else if (isBooked || isBlockedAfterBooked) {
      textColor = AppColors.textTertiary;
      textDecoration = TextDecoration.lineThrough;
    }

    final isSelectedEnd = isCheckIn || isCheckOut;

    return Semantics(
      label: isBooked
          ? 'Ngày $dayNumber đã kín'
          : (isAllowedCheckOutBoundary
              ? 'Ngày $dayNumber chỉ trả phòng'
              : 'Ngày $dayNumber'),
      button: !isPast,
      child: DatePopButton(
        isSelected: isSelectedEnd,
        onTap: isPast ? null : () => _onDayTapped(date),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cellBg,
              borderRadius: BorderRadius.circular(16),
              border: isAllowedCheckOutBoundary && !isSelectedEnd
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      width: 1,
                    )
                  : null,
            ),
            child: Center(
              child: Text(
                '$dayNumber',
                style: AppTypography.bodyMedium.copyWith(
                  color: textColor,
                  fontWeight: (isSelectedEnd || isInRange)
                      ? FontWeight.w700
                      : FontWeight.w500,
                  decoration: textDecoration,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
