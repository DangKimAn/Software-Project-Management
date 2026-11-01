import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'app_header_footer.dart';

/// Visual palette and slender vector glyph for each notification category,
/// modeled after the frosted-glass capsule notification template while
/// preserving 100% of existing notification text and business logic.
enum NotificationVisualKind {
  chatBubble,
  alarmClock,
  settingsCog,
  tiltedBell,
}

class _NotificationVisualStyle {
  final NotificationVisualKind kind;
  final Color gradientTop;
  final Color gradientBottom;
  final Color ringBorder;
  final Color iconColor;

  const _NotificationVisualStyle({
    required this.kind,
    required this.gradientTop,
    required this.gradientBottom,
    required this.ringBorder,
    required this.iconColor,
  });

  static const _skyBlue = _NotificationVisualStyle(
    kind: NotificationVisualKind.chatBubble,
    gradientTop: Color(0xFFF2F8FF),
    gradientBottom: Color(0xFFD6E8FF),
    ringBorder: Color(0xFFB3D4FF),
    iconColor: Color(0xFF1E74F5),
  );

  static const _coralRose = _NotificationVisualStyle(
    kind: NotificationVisualKind.alarmClock,
    gradientTop: Color(0xFFFFF4F6),
    gradientBottom: Color(0xFFFFD8E0),
    ringBorder: Color(0xFFFFAEBE),
    iconColor: AppColors.primary,
  );

  static const _orchidLavender = _NotificationVisualStyle(
    kind: NotificationVisualKind.settingsCog,
    gradientTop: Color(0xFFFAF4FF),
    gradientBottom: Color(0xFFECDCFF),
    ringBorder: Color(0xFFD7B8FF),
    iconColor: Color(0xFF8632E8),
  );

  static const _warmButterGold = _NotificationVisualStyle(
    kind: NotificationVisualKind.tiltedBell,
    gradientTop: Color(0xFFFFFBEB),
    gradientBottom: Color(0xFFFCE592),
    ringBorder: Color(0xFFF1CE65),
    iconColor: Color(0xFFA96E08),
  );

  static _NotificationVisualStyle resolveFor(AppNotificationItem item) {
    final eType = item.eventType.trim().toLowerCase();
    final tType = (item.targetType ?? '').trim().toLowerCase();

    if (tType == 'conversation' ||
        tType == 'review' ||
        eType.contains('message') ||
        eType.contains('chat') ||
        eType.contains('comment') ||
        eType.contains('review') ||
        eType == 'user_registered') {
      return _skyBlue;
    }

    if (eType.contains('pending') ||
        eType.contains('expired') ||
        eType.contains('cancel') ||
        eType.contains('refund') ||
        eType.contains('remind') ||
        eType == 'booking_created' ||
        eType == 'booking.created') {
      return _coralRose;
    }

    if (item.forAdmin ||
        tType == 'listing' ||
        tType == 'host_application' ||
        eType.startsWith('listing') ||
        eType.startsWith('host_application') ||
        eType == 'system') {
      return _orchidLavender;
    }

    return _warmButterGold;
  }
}

/// Circular frosted pearl-glass trigger button with slender bell outline
/// and glossy crimson-rose unread counter badge.
class GlassNotificationBellButton extends StatefulWidget {
  final int unreadCount;
  final bool isOverlayTop;
  final VoidCallback onTap;
  final double discDiameter;
  final double boxWidth;
  final double boxHeight;
  final String semanticsLabel;

  const GlassNotificationBellButton({
    super.key,
    required this.unreadCount,
    required this.isOverlayTop,
    required this.onTap,
    this.discDiameter = 36,
    this.boxWidth = 40,
    this.boxHeight = 48,
    this.semanticsLabel = 'Thông báo',
  });

  @override
  State<GlassNotificationBellButton> createState() =>
      _GlassNotificationBellButtonState();
}

class _GlassNotificationBellButtonState
    extends State<GlassNotificationBellButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final badgeLabel =
        widget.unreadCount > 99 ? '99+' : '${widget.unreadCount}';
    final iconSize = widget.discDiameter * 0.50;
    final isLargeAnchor = widget.discDiameter >= 46;

    Widget bellDisc = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: widget.discDiameter,
      height: widget.discDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: widget.isOverlayTop
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: _isHovered ? 0.34 : 0.24),
                  Colors.white.withValues(alpha: _isHovered ? 0.20 : 0.12),
                ],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFFFFFF),
                  _isHovered
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFFF9FAFC),
                ],
              ),
        border: Border.all(
          color: widget.isOverlayTop
              ? Colors.white.withValues(alpha: 0.50)
              : Colors.white,
          width: isLargeAnchor ? 1.2 : 1.0,
        ),
        boxShadow: widget.isOverlayTop
            ? const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Color(_isHovered ? 0x180F172A : 0x100F172A),
                  blurRadius: isLargeAnchor ? 18 : (_isHovered ? 14 : 11),
                  offset: Offset(0, isLargeAnchor ? 6 : 4),
                ),
              ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(iconSize, iconSize),
          painter: _SlenderHeaderBellPainter(
            color: widget.isOverlayTop
                ? Colors.white
                : const Color(0xFF3A3E47),
          ),
        ),
      ),
    );

    if (widget.isOverlayTop) {
      bellDisc = ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: bellDisc,
        ),
      );
    }

    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            width: widget.boxWidth,
            height: widget.boxHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                bellDisc,
                if (widget.unreadCount > 0)
                  Positioned(
                    top: isLargeAnchor ? 0 : 3,
                    right: isLargeAnchor ? -2 : -1,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeAnchor ? 5.5 : 4.5,
                        vertical: isLargeAnchor ? 2 : 1.5,
                      ),
                      constraints: BoxConstraints(
                        minWidth: isLargeAnchor ? 21 : 18,
                        minHeight: isLargeAnchor ? 21 : 18,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFF5E7E),
                            Color(0xFFE8254D),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white,
                          width: isLargeAnchor ? 1.8 : 1.6,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x42F43F5E),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontFamily: AppTypography.roundedFontFamily,
                            fontFamilyFallback: AppTypography.fontFallbacks,
                            fontSize: isLargeAnchor ? 10.5 : 9.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.0,
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
    );
  }
}

/// Opens the frosted-glass floating capsule notification overlay while keeping
/// all existing notification text, mark-as-read actions, and navigation intact.
Future<void> showGlassNotificationsOverlay({
  required BuildContext context,
  required String Function(String raw) formatTime,
  required void Function(AppNotificationItem item) onSelectNotification,
}) {
  final disableAnimations = MediaQuery.disableAnimationsOf(context);

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng thông báo',
    barrierColor: Colors.transparent,
    transitionDuration:
        disableAnimations ? Duration.zero : const Duration(milliseconds: 230),
    pageBuilder: (dialogContext, _, __) {
      return _GlassNotificationsModal(
        formatTime: formatTime,
        onClose: () => Navigator.of(dialogContext).pop(),
        onSelectItem: (item) {
          Navigator.of(dialogContext).pop();
          onSelectNotification(item);
        },
      );
    },
    transitionBuilder: (dialogContext, animation, _, child) {
      if (disableAnimations) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: child,
      );
    },
  );
}

class _GlassNotificationsModal extends ConsumerWidget {
  final String Function(String raw) formatTime;
  final VoidCallback onClose;
  final ValueChanged<AppNotificationItem> onSelectItem;

  const _GlassNotificationsModal({
    required this.formatTime,
    required this.onClose,
    required this.onSelectItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificationsProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 640;
    final isNarrow = screenWidth < 350;

    final topPad = isWide ? 36.0 : 18.0;
    const bottomPad = 16.0;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred cool-silver frosted glass backdrop (tap outside to close)
          GestureDetector(
            key: const Key('notification_glass_backdrop'),
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFDADDE3)
                            .withValues(alpha: isWide ? 0.72 : 0.85),
                        const Color(0xFFD0D4DC)
                            .withValues(alpha: isWide ? 0.80 : 0.91),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Floating notification header, capsule stack, and bottom bell toggle
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availHeight = math.max(
                  0.0,
                  constraints.maxHeight - topPad - bottomPad,
                );

                return Align(
                  alignment: isWide ? Alignment.topRight : Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isNarrow ? 2 : 4,
                      topPad,
                      isNarrow ? 2 : (isWide ? 14 : 4),
                      bottomPad,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 458,
                        maxHeight: availHeight,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header bar above floating capsules (matching "View all notifications")
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 18, 6),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Text(
                                  'Thông báo (${notifState.unreadCount} chưa đọc)',
                                  style: const TextStyle(
                                    fontFamily: AppTypography.primaryFontFamily,
                                    fontFamilyFallback:
                                        AppTypography.fontFallbacks,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.25,
                                    color: Color(0xFF3B3F46),
                                  ),
                                ),
                                if (notifState.unreadCount > 0)
                                  _FrostedActionPill(
                                    label: 'Đánh dấu tất cả đã đọc',
                                    onTap: () => ref
                                        .read(notificationsProvider.notifier)
                                        .markAllAsRead(),
                                  ),
                              ],
                            ),
                          ),

                          // Floating frosted-glass capsule list (or empty capsule)
                          Flexible(
                            child: notifState.items.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.fromLTRB(14, 8, 14, 14),
                                    child: _EmptyNotificationGlassCard(),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    addRepaintBoundaries: false,
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      10,
                                      14,
                                      18,
                                    ),
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: notifState.items.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final item = notifState.items[index];
                                      return _NotificationGlassCapsuleCard(
                                        item: item,
                                        timeText: formatTime(item.createdAt),
                                        compactIcon: isNarrow,
                                        onTap: () {
                                          if (!item.isRead) {
                                            ref
                                                .read(notificationsProvider
                                                    .notifier)
                                                .markAsRead(item.id);
                                          }
                                          onSelectItem(item);
                                        },
                                      );
                                    },
                                  ),
                          ),

                          // Floating pearl-white Bell anchor button below the capsule stack (matching template)
                          if (availHeight >= 240)
                            Padding(
                              padding: const EdgeInsets.only(left: 24, top: 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: GlassNotificationBellButton(
                                  key: const Key(
                                    'notification_overlay_bell_close_btn',
                                  ),
                                  unreadCount: notifState.unreadCount,
                                  isOverlayTop: false,
                                  discDiameter: 50,
                                  boxWidth: 54,
                                  boxHeight: 54,
                                  semanticsLabel: 'Đóng thông báo',
                                  onTap: onClose,
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
          ),
        ],
      ),
    );
  }
}

class _FrostedActionPill extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _FrostedActionPill({
    required this.label,
    required this.onTap,
  });

  @override
  State<_FrostedActionPill> createState() => _FrostedActionPillState();
}

class _FrostedActionPillState extends State<_FrostedActionPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _hovered ? 0.88 : 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.92),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontFamily: AppTypography.textFontFamily,
              fontFamilyFallback: AppTypography.fontFallbacks,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
              color: Color(0xFF474C56),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNotificationGlassCard extends StatelessWidget {
  const _EmptyNotificationGlassCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF9FAFC),
          ],
        ),
        border: Border.all(
          color: Colors.white,
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E0F172A),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: const Row(
        children: [
          _PastelGlassIconBadge(
            style: _NotificationVisualStyle._warmButterGold,
            diameter: 46,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Chưa có thông báo mới.',
              style: TextStyle(
                fontFamily: AppTypography.textFontFamily,
                fontFamilyFallback: AppTypography.fontFallbacks,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.1,
                color: Color(0xFF666B75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual floating frosted-glass capsule card with seamless white surface,
/// concentric pastel icon circle, and slender SF Pro type.
class _NotificationGlassCapsuleCard extends StatefulWidget {
  final AppNotificationItem item;
  final String timeText;
  final bool compactIcon;
  final VoidCallback onTap;

  const _NotificationGlassCapsuleCard({
    required this.item,
    required this.timeText,
    required this.compactIcon,
    required this.onTap,
  });

  @override
  State<_NotificationGlassCapsuleCard> createState() =>
      _NotificationGlassCapsuleCardState();
}

class _NotificationGlassCapsuleCardState
    extends State<_NotificationGlassCapsuleCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final visualStyle = _NotificationVisualStyle.resolveFor(item);
    final iconSize = widget.compactIcon ? 42.0 : 48.0;
    final compactBody = item.body.contains('\n')
        ? item.body.replaceAll(RegExp(r'\s+'), ' ').trim()
        : item.body;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.fromLTRB(13, 11, 20, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: item.isRead
              ? const [
                  Color(0xFCFFFFFF),
                  Color(0xFFF7F8FB),
                ]
              : const [
                  Color(0xFFFFFFFF),
                  Color(0xFFFAFBFD),
                ],
        ),
        border: Border.all(
          color: Colors.white,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(_hovered ? 0x140F172A : 0x0D0F172A),
            blurRadius: _hovered ? 16 : 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PastelGlassIconBadge(
            style: visualStyle,
            diameter: iconSize,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (item.forAdmin) ...[
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5EEFF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFFD8B4FE),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            fontFamily: AppTypography.primaryFontFamily,
                            fontFamilyFallback: AppTypography.fontFallbacks,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7E22CE),
                            letterSpacing: 0.35,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.primaryFontFamily,
                          fontFamilyFallback: AppTypography.fontFallbacks,
                          fontSize: 15,
                          fontWeight: item.isRead
                              ? FontWeight.w500
                              : FontWeight.w600,
                          letterSpacing: -0.22,
                          height: 1.24,
                          color: item.isRead
                              ? const Color(0xFF4A4E58)
                              : const Color(0xFF333740),
                        ),
                      ),
                    ),
                  ],
                ),
                if (compactBody.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    compactBody,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.textFontFamily,
                      fontFamilyFallback: AppTypography.fontFallbacks,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.08,
                      height: 1.3,
                      color: Color(0xFF686D76),
                    ),
                  ),
                ],
                if (widget.timeText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.timeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.textFontFamily,
                      fontFamilyFallback: AppTypography.fontFallbacks,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.05,
                      height: 1.2,
                      color: Color(0xFF949AA6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!item.isRead) ...[
            const SizedBox(width: 10),
            Container(
              width: 7.5,
              height: 7.5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF6382),
                    Color(0xFFE8254D),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x45F43F5E),
                    blurRadius: 5,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (_pressed) {
      card = Transform.scale(scale: 0.985, child: card);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: card,
      ),
    );
  }
}

/// Jewel-like pastel circular glass badge with concentric outer frost rim
/// and slender 1.55px custom-drawn vector icon.
class _PastelGlassIconBadge extends StatelessWidget {
  final _NotificationVisualStyle style;
  final double diameter;

  const _PastelGlassIconBadge({
    required this.style,
    required this.diameter,
  });

  @override
  Widget build(BuildContext context) {
    final glyphSize = diameter * 0.46;
    return Container(
      width: diameter,
      height: diameter,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.85),
        boxShadow: [
          BoxShadow(
            color: style.ringBorder.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              style.gradientTop,
              style.gradientBottom,
            ],
          ),
          border: Border.all(
            color: style.ringBorder,
            width: 1.05,
          ),
        ),
        child: Center(
          child: CustomPaint(
            size: Size(glyphSize, glyphSize),
            painter: _SlenderNotificationGlyphPainter(
              kind: style.kind,
              color: style.iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ultra-clean slender stroke painter (1.55px on 24x24 grid) matching the
/// 4 template icons: rounded speech bubble, alarm clock, 8-tooth cog, tilted bell.
class _SlenderNotificationGlyphPainter extends CustomPainter {
  final NotificationVisualKind kind;
  final Color color;

  const _SlenderNotificationGlyphPainter({
    required this.kind,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.35, 1.62 * s)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case NotificationVisualKind.chatBubble:
        _paintChatBubble(canvas, s, paint);
      case NotificationVisualKind.alarmClock:
        _paintAlarmClock(canvas, s, paint);
      case NotificationVisualKind.settingsCog:
        _paintSettingsCog(canvas, s, paint);
      case NotificationVisualKind.tiltedBell:
        _paintTiltedBell(canvas, s, paint);
    }
  }

  void _paintChatBubble(Canvas canvas, double s, Paint paint) {
    final rect = Rect.fromCenter(
      center: Offset(12.2 * s, 11.6 * s),
      width: 15.8 * s,
      height: 13.4 * s,
    );
    const startAngle = 2.62; // ~150 deg (lower-left above tail)
    const sweepAngle = 5.66; // ~324 deg clockwise around oval

    final endX = 12.2 * s + 7.9 * s * math.cos(startAngle + sweepAngle);
    final startX = 12.2 * s + 7.9 * s * math.cos(startAngle);
    final startY = 11.6 * s + 6.7 * s * math.sin(startAngle);

    final fullBubble = Path()
      ..moveTo(startX, startY)
      ..arcTo(rect, startAngle, sweepAngle, false)
      ..quadraticBezierTo(endX - 1.4 * s, 18.2 * s, 4.9 * s, 18.3 * s)
      ..quadraticBezierTo(5.5 * s, 15.8 * s, startX, startY)
      ..close();

    canvas.drawPath(fullBubble, paint);
  }

  void _paintAlarmClock(Canvas canvas, double s, Paint paint) {
    // Clock body circle
    canvas.drawCircle(Offset(12.0 * s, 13.0 * s), 6.9 * s, paint);

    // Twin curved alarm bells at top-left and top-right
    final leftBell = Path()
      ..moveTo(4.6 * s, 7.6 * s)
      ..quadraticBezierTo(5.6 * s, 4.8 * s, 8.5 * s, 4.4 * s);
    final rightBell = Path()
      ..moveTo(15.5 * s, 4.4 * s)
      ..quadraticBezierTo(18.4 * s, 4.8 * s, 19.4 * s, 7.6 * s);
    canvas.drawPath(leftBell, paint);
    canvas.drawPath(rightBell, paint);

    // Slender clock hands
    final hands = Path()
      ..moveTo(12.0 * s, 9.3 * s)
      ..lineTo(12.0 * s, 13.0 * s)
      ..lineTo(14.5 * s, 14.5 * s);
    canvas.drawPath(hands, paint);
  }

  void _paintSettingsCog(Canvas canvas, double s, Paint paint) {
    final cx = 12.0 * s;
    final cy = 12.0 * s;

    // Inner center ring
    canvas.drawCircle(Offset(cx, cy), 2.85 * s, paint);

    // Smooth 8-tooth rounded gear contour
    const teeth = 8;
    final outerR = 8.4 * s;
    final innerR = 6.35 * s;
    const step = (2 * math.pi) / teeth;
    final gear = Path();

    for (var i = 0; i < teeth; i++) {
      final base = i * step - math.pi / 2;
      final a1 = base - step * 0.28;
      final a2 = base - step * 0.15;
      final a3 = base + step * 0.15;
      final a4 = base + step * 0.28;
      final aNext = base + step - step * 0.28;

      final p1 = Offset(cx + innerR * math.cos(a1), cy + innerR * math.sin(a1));
      final p2 = Offset(cx + outerR * math.cos(a2), cy + outerR * math.sin(a2));
      final p3 = Offset(cx + outerR * math.cos(a3), cy + outerR * math.sin(a3));
      final p4 = Offset(cx + innerR * math.cos(a4), cy + innerR * math.sin(a4));
      final pNext = Offset(
        cx + innerR * math.cos(aNext),
        cy + innerR * math.sin(aNext),
      );

      if (i == 0) {
        gear.moveTo(p1.dx, p1.dy);
      }
      gear.lineTo(p2.dx, p2.dy);
      gear.arcToPoint(p3, radius: Radius.circular(outerR), clockwise: true);
      gear.lineTo(p4.dx, p4.dy);
      gear.arcToPoint(pNext, radius: Radius.circular(innerR), clockwise: true);
    }
    gear.close();
    canvas.drawPath(gear, paint);
  }

  void _paintTiltedBell(Canvas canvas, double s, Paint paint) {
    canvas.save();
    canvas.translate(12.0 * s, 12.0 * s);
    canvas.rotate(math.pi / 5.4); // ~33 deg clockwise tilt matching template
    canvas.translate(-12.0 * s, -12.0 * s);

    // Top loop knob
    final knobRect = Rect.fromCenter(
      center: Offset(12.0 * s, 4.8 * s),
      width: 2.4 * s,
      height: 2.2 * s,
    );
    canvas.drawArc(knobRect, math.pi, math.pi, false, paint);

    // Slender flared bell body
    final body = Path()
      ..moveTo(7.4 * s, 10.6 * s)
      ..arcToPoint(
        Offset(16.6 * s, 10.6 * s),
        radius: Radius.circular(4.6 * s),
        clockwise: true,
      )
      ..cubicTo(16.6 * s, 13.8 * s, 17.8 * s, 15.4 * s, 18.4 * s, 16.3 * s)
      ..lineTo(5.6 * s, 16.3 * s)
      ..cubicTo(6.2 * s, 15.4 * s, 7.4 * s, 13.8 * s, 7.4 * s, 10.6 * s)
      ..close();
    canvas.drawPath(body, paint);

    // Bottom clapper arc
    final clapperRect = Rect.fromCenter(
      center: Offset(12.0 * s, 16.5 * s),
      width: 4.0 * s,
      height: 4.0 * s,
    );
    canvas.drawArc(clapperRect, 0.12, math.pi - 0.24, false, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SlenderNotificationGlyphPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

/// Slender upright bell outline for the circular header trigger button.
class _SlenderHeaderBellPainter extends CustomPainter {
  final Color color;

  const _SlenderHeaderBellPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.45, 1.75 * s)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final body = Path()
      ..moveTo(6.8 * s, 10.2 * s)
      ..arcToPoint(
        Offset(17.2 * s, 10.2 * s),
        radius: Radius.circular(5.2 * s),
        clockwise: true,
      )
      ..cubicTo(17.2 * s, 13.8 * s, 18.5 * s, 15.6 * s, 19.2 * s, 16.8 * s)
      ..lineTo(4.8 * s, 16.8 * s)
      ..cubicTo(5.5 * s, 15.6 * s, 6.8 * s, 13.8 * s, 6.8 * s, 10.2 * s)
      ..close();
    canvas.drawPath(body, paint);

    final clapperRect = Rect.fromCenter(
      center: Offset(12.0 * s, 17.0 * s),
      width: 4.6 * s,
      height: 4.6 * s,
    );
    canvas.drawArc(clapperRect, 0.1, math.pi - 0.2, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SlenderHeaderBellPainter oldDelegate) =>
      oldDelegate.color != color;
}
