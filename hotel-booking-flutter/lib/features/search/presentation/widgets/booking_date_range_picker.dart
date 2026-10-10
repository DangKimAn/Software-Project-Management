import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/date/booking_date.dart';

class BookingDateRangePicker extends StatefulWidget {
  final BookingDate? initialCheckIn;
  final BookingDate? initialCheckOut;
  final Set<BookingDate> bookedDates;
  final ValueChanged<(BookingDate?, BookingDate?)> onRangeSelected;

  const BookingDateRangePicker({
    super.key,
    this.initialCheckIn,
    this.initialCheckOut,
    this.bookedDates = const {},
    required this.onRangeSelected,
  });

  @override
  State<BookingDateRangePicker> createState() => _BookingDateRangePickerState();
}

class _BookingDateRangePickerState extends State<BookingDateRangePicker> {
  late DateTime _currentMonth;
  BookingDate? _checkIn;
  BookingDate? _checkOut;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkIn = widget.initialCheckIn;
    _checkOut = widget.initialCheckOut;
    _currentMonth = DateTime.now();
  }

  void _onDayTapped(BookingDate day) {
    if (widget.bookedDates.contains(day)) {
      setState(() => _errorMessage = 'Ngày này đã có khách đặt.');
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
            bookedNights: widget.bookedDates,
          );

          if (!isAvailable) {
            _errorMessage = 'Khoảng thời gian đã chọn đi qua ngày đã kín.';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month Navigation Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  _currentMonth =
                      DateTime(_currentMonth.year, _currentMonth.month - 1);
                });
              },
            ),
            Text(
              monthTitle.toUpperCase(),
              style: AppTypography.cardTitle.copyWith(fontSize: 15),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  _currentMonth =
                      DateTime(_currentMonth.year, _currentMonth.month + 1);
                });
              },
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Weekday labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].map((w) {
            return SizedBox(
              width: 38,
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

        // Calendar Grid with monthIn transition (180ms ease-out)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: GridView.builder(
            key: ValueKey<String>(
                '${_currentMonth.year}-${_currentMonth.month}'),
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

              final isBooked = widget.bookedDates.contains(date);
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
                isBooked: isBooked,
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
    );
  }

  Widget _buildCalendarDayCell({
    required BookingDate date,
    required int dayNumber,
    required bool isBooked,
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
      cellBg = AppColors.rangeBackground;
      textColor = AppColors.textStrong;
    } else if (isBooked) {
      textColor = AppColors.textTertiary;
      textDecoration = TextDecoration.lineThrough;
    }

    final isSelectedEnd = isCheckIn || isCheckOut;

    return Semantics(
      label: isBooked ? 'Ngày $dayNumber đã kín' : 'Ngày $dayNumber',
      button: !isBooked,
      child: InkWell(
        onTap: isBooked ? null : () => _onDayTapped(date),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: isInRange ? AppColors.rangeBackground : null,
          ),
          child: Center(
            child: AnimatedScale(
              scale: isSelectedEnd ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cellBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$dayNumber',
                    style: AppTypography.bodyMedium.copyWith(
                      color: textColor,
                      fontWeight:
                          isSelectedEnd ? FontWeight.w700 : FontWeight.w500,
                      decoration: textDecoration,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
