import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';

/// Thanh hiển thị trạng thái thu âm tin nhắn thoại của Host chống tràn ngang ở mức phóng chữ 1.3x–2.0x.
class HostVoiceRecordingBar extends StatelessWidget {
  final int recordingSeconds;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  /// Khởi tạo thanh hiển thị trạng thái thu âm tin nhắn thoại của Host.
  const HostVoiceRecordingBar({
    super.key,
    required this.recordingSeconds,
    required this.onCancel,
    required this.onSend,
  });

  /// Dựng thanh thu âm tin nhắn thoại với khả năng co giãn linh hoạt theo cỡ chữ hệ thống.
  @override
  Widget build(BuildContext context) {
    // Giải thuật co giãn thanh thu âm khi phóng chữ 1.3x–2.0x:
    // Đặt nhãn thời gian thu âm trong Expanded kèm TextOverflow.ellipsis và thu gọn khoảng đệm nút Hủy/Gửi để không tràn Row.
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isScaled = textScale >= 1.3;
    final formattedSec = recordingSeconds.toString().padLeft(2, '0');

    return Container(
      key: const Key('host_voice_recording_bar'),
      padding: EdgeInsets.symmetric(
        horizontal: isScaled ? 10 : 16,
        vertical: 8,
      ),
      color: const Color(0xFFFFF1F2),
      child: Row(
        children: [
          const Icon(LucideIcons.mic, color: AppColors.error, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Đang ghi âm... 00:$formattedSec',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            flex: 0,
            child: TextButton(
              key: const Key('host_voice_recording_cancel_btn'),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: EdgeInsets.symmetric(horizontal: isScaled ? 8 : 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onCancel,
              child: const Text(
                'Hủy',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            flex: 0,
            child: ElevatedButton.icon(
              key: const Key('host_voice_recording_send_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 36),
                padding: EdgeInsets.symmetric(
                  horizontal: isScaled ? 10 : 12,
                  vertical: 6,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                elevation: 0,
              ),
              onPressed: onSend,
              icon: const Icon(LucideIcons.send, size: 14),
              label: const Text(
                'Gửi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thanh soạn thảo tin nhắn phong cách Messenger của Host với khả năng giữ độ rộng ô nhập ở mức phóng chữ 1.3x–2.0x.
class HostChatComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isRecordingVoice;
  final bool sendingMessage;
  final String? quickEmoji;
  final IconData quickIcon;
  final VoidCallback onShowMoreOptions;
  final VoidCallback onOpenCamera;
  final VoidCallback onPickGalleryImage;
  final VoidCallback onToggleVoiceRecording;
  final VoidCallback onShowEmojiSelector;
  final VoidCallback onSendQuickEmoji;
  final VoidCallback onChooseQuickEmoji;
  final VoidCallback onSendMessage;

  /// Khởi tạo thanh soạn thảo tin nhắn dành cho Host.
  const HostChatComposerBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isRecordingVoice,
    required this.sendingMessage,
    this.quickEmoji,
    this.quickIcon = LucideIcons.thumbsUp,
    required this.onShowMoreOptions,
    required this.onOpenCamera,
    required this.onPickGalleryImage,
    required this.onToggleVoiceRecording,
    required this.onShowEmojiSelector,
    required this.onSendQuickEmoji,
    required this.onChooseQuickEmoji,
    required this.onSendMessage,
  });

  /// Dựng thanh công cụ đính kèm, ô nhập tin nhắn và nút gửi/biểu tượng cảm xúc nhanh.
  @override
  Widget build(BuildContext context) {
    // Giải thuật tính toán mật độ nút công cụ thanh chat theo độ rộng màn hình và hệ số phóng chữ (1.3x–2.0x):
    // Thu gọn khoảng cách ngang và vùng bao icon phụ khi màn hình hẹp hoặc phóng chữ lớn để TextField luôn giữ độ rộng nhập liệu thoải mái.
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactToolbar = textScale >= 1.3 || constraints.maxWidth < 380;
        final iconBtnWidth = compactToolbar ? 28.0 : 36.0;
        final compactIconBtnStyle = compactToolbar
            ? IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size(iconBtnWidth, 36),
                padding: EdgeInsets.zero,
              )
            : null;
        final iconSize = compactToolbar ? 19.0 : 22.0;
        final gap = compactToolbar ? 2.0 : 4.0;
        final outerGap = compactToolbar ? 4.0 : 8.0;
        final plusSize = compactToolbar ? 25.0 : 28.0;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compactToolbar ? 6 : 10,
            vertical: 8,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceBase,
            border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Row(
            children: [
              InkWell(
                key: const Key('chat_more_features_btn'),
                onTap: onShowMoreOptions,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: plusSize,
                  height: plusSize,
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
              SizedBox(width: outerGap),
              IconButton(
                key: const Key('chat_camera_btn'),
                style: compactIconBtnStyle,
                icon: Icon(
                  LucideIcons.camera,
                  size: iconSize,
                  color: AppColors.primary,
                ),
                tooltip: 'Chụp ảnh',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: iconBtnWidth,
                  maxWidth: iconBtnWidth + 4,
                  minHeight: 40,
                ),
                onPressed: onOpenCamera,
              ),
              SizedBox(width: gap),
              IconButton(
                key: const Key('chat_gallery_btn'),
                style: compactIconBtnStyle,
                icon: Icon(
                  LucideIcons.image,
                  size: iconSize,
                  color: AppColors.primary,
                ),
                tooltip: 'Gửi hình ảnh',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: iconBtnWidth,
                  maxWidth: iconBtnWidth + 4,
                  minHeight: 40,
                ),
                onPressed: onPickGalleryImage,
              ),
              SizedBox(width: gap),
              IconButton(
                key: const Key('chat_mic_btn'),
                style: compactIconBtnStyle,
                icon: Icon(
                  isRecordingVoice ? LucideIcons.square : LucideIcons.mic,
                  size: iconSize,
                  color: isRecordingVoice ? AppColors.error : AppColors.primary,
                ),
                tooltip: isRecordingVoice ? 'Dừng ghi âm' : 'Tin nhắn thoại',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: iconBtnWidth,
                  maxWidth: iconBtnWidth + 4,
                  minHeight: 40,
                ),
                onPressed: onToggleVoiceRecording,
              ),
              SizedBox(width: outerGap),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 96),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TextField(
                      key: const Key('host_message_input'),
                      controller: controller,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!sendingMessage) {
                          onSendMessage();
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Nhắn tin',
                        hintMaxLines: 1,
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14.5,
                          overflow: TextOverflow.ellipsis,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: compactToolbar ? 12 : 16,
                          vertical: 10,
                        ),
                        isDense: true,
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 32,
                          maxWidth: 36,
                          minHeight: 34,
                        ),
                        suffixIcon: IconButton(
                          key: const Key('chat_input_smile_btn'),
                          style: compactIconBtnStyle,
                          icon: const Icon(
                            LucideIcons.smile,
                            size: 19,
                            color: AppColors.primary,
                          ),
                          tooltip: 'Biểu tượng cảm xúc',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 34,
                          ),
                          onPressed: onShowEmojiSelector,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: outerGap),
              if (controller.text.trim().isEmpty)
                InkWell(
                  key: const Key('chat_quick_emoji_btn'),
                  onTap: onSendQuickEmoji,
                  onLongPress: onChooseQuickEmoji,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 2,
                    ),
                    child: (quickEmoji != null && quickEmoji!.isNotEmpty)
                        ? SizedBox(
                            width: compactToolbar ? 26 : 30,
                            height: compactToolbar ? 26 : 30,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                quickEmoji!,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          )
                        : Icon(
                            quickIcon,
                            size: compactToolbar ? 20 : 22,
                            color: AppColors.primary,
                          ),
                  ),
                )
              else
                IconButton(
                  key: const Key('host_message_send_btn'),
                  style: compactIconBtnStyle,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: compactToolbar ? 34 : 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(
                    LucideIcons.send,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Gửi tin nhắn',
                  onPressed: sendingMessage ? null : onSendMessage,
                ),
            ],
          ),
        );
      },
    );
  }
}
