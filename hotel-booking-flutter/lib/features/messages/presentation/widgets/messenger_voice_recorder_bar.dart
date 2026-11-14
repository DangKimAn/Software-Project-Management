import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';

/// Luxury Facebook Messenger style voice recording input bar.
/// Features a pulsing recording dot, monospace timer, live animated audio waveform,
/// and quick-action Cancel (Trash) and Send buttons.
class MessengerVoiceRecorderBar extends StatefulWidget {
  final int recordingSeconds;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const MessengerVoiceRecorderBar({
    super.key,
    required this.recordingSeconds,
    required this.onCancel,
    required this.onSend,
  });

  @override
  State<MessengerVoiceRecorderBar> createState() =>
      _MessengerVoiceRecorderBarState();
}

class _MessengerVoiceRecorderBarState extends State<MessengerVoiceRecorderBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2), // Messenger soft red/rose tint
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
      ),
      child: Row(
        children: [
          // 1. Nút Thùng rác (Hủy ghi âm)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onCancel,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.trash2,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 2. Chấm đỏ nhấp nháy + Thời gian đếm
          AnimatedBuilder(
            animation: _animCtrl,
            builder: (context, child) {
              final opacity = 0.3 + 0.7 * _animCtrl.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: opacity),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: opacity * 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(widget.recordingSeconds),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 12),

          // 3. Dải sóng âm thanh chuyển động (Animated Waveform Equalizer)
          Expanded(
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, _) {
                const barCount = 18;
                return SizedBox(
                  height: 28,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(barCount, (i) {
                      final phase = (i / barCount) * math.pi * 2;
                      final wave = (math.sin(_animCtrl.value * math.pi * 2 + phase) + 1) / 2;
                      // Dynamic height between 4dp and 24dp
                      final height = 4.0 + 20.0 * wave;
                      return Container(
                        width: 2.8,
                        height: height,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.4 + 0.6 * wave),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),

          // 4. Nút Gửi tin nhắn thoại (Send Button phong cách Messenger)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onSend,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primary,
                      Color(0xFFE11D48),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.arrowUp,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
