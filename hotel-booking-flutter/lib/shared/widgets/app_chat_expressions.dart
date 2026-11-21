// CONFLICT-RESOLVED: Chuẩn hóa bộ biểu tượng tương tác tin nhắn bằng `LucideIcons` đơn sắc
// thay cho Unicode Emoji chức năng theo FLUTTER_RULES.md Mục 6.
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Mô hình lựa chọn thả cảm xúc (`Messenger Reaction`) cho tin nhắn.
class AppChatReactionOption {
  /// Mã định danh phản hồi cảm xúc lưu trữ và đồng bộ với máy chủ (ví dụ `'heart'`, `'like'`).
  final String code;

  /// Biểu tượng đường nét đơn sắc `LucideIcons` hiển thị trên giao diện.
  final IconData icon;

  /// Nhãn tiếng Việt mô tả ý nghĩa cảm xúc phục vụ hiển thị và trợ năng.
  final String label;

  /// Khởi tạo một tùy chọn phản hồi cảm xúc tin nhắn.
  const AppChatReactionOption({
    required this.code,
    required this.icon,
    required this.label,
  });
}

/// Mô hình biểu tượng gửi nhanh hoặc chèn nhãn cảm xúc trong thanh soạn thảo tin nhắn.
class AppChatQuickExpression {
  /// Mã định danh nội bộ của nhãn cảm xúc nhanh.
  final String code;

  /// Biểu tượng đường nét đơn sắc `LucideIcons` đại diện cho nhãn.
  final IconData icon;

  /// Tên hiển thị ngắn gọn trên nút chọn hoặc chú giải.
  final String label;

  /// Chuỗi văn bản chuẩn hóa gửi vào luồng tin nhắn (ví dụ `'[Yêu thích]'`).
  final String sendText;

  /// Khởi tạo cấu hình biểu tượng gửi nhanh hoặc chèn vào khung chat.
  const AppChatQuickExpression({
    required this.code,
    required this.icon,
    required this.label,
    required this.sendText,
  });
}

/// Danh mục 6 phản hồi cảm xúc chuẩn dùng chung cho Khách, Chủ nhà và Quản trị viên.
const List<AppChatReactionOption> kAppMessengerReactions = [
  AppChatReactionOption(
    code: 'heart',
    icon: LucideIcons.heart,
    label: 'Yêu thích',
  ),
  AppChatReactionOption(
    code: 'laugh',
    icon: LucideIcons.laugh,
    label: 'Vui vẻ',
  ),
  AppChatReactionOption(
    code: 'surprised',
    icon: LucideIcons.smilePlus,
    label: 'Ấn tượng',
  ),
  AppChatReactionOption(
    code: 'sad',
    icon: LucideIcons.frown,
    label: 'Chia sẻ',
  ),
  AppChatReactionOption(
    code: 'angry',
    icon: LucideIcons.angry,
    label: 'Không hài lòng',
  ),
  AppChatReactionOption(
    code: 'like',
    icon: LucideIcons.thumbsUp,
    label: 'Đồng ý',
  ),
];

/// Danh mục 6 biểu tượng gửi nhanh khi ô nhập tin nhắn đang trống.
const List<AppChatQuickExpression> kAppQuickChatOptions = [
  AppChatQuickExpression(
    code: 'like',
    icon: LucideIcons.thumbsUp,
    label: 'Thích',
    sendText: '[Thích]',
  ),
  AppChatQuickExpression(
    code: 'heart',
    icon: LucideIcons.heart,
    label: 'Yêu thích',
    sendText: '[Yêu thích]',
  ),
  AppChatQuickExpression(
    code: 'sparkles',
    icon: LucideIcons.sparkles,
    label: 'Tuyệt vời',
    sendText: '[Tuyệt vời]',
  ),
  AppChatQuickExpression(
    code: 'palm',
    icon: LucideIcons.treePalm,
    label: 'Chào đón',
    sendText: '[Chào đón]',
  ),
  AppChatQuickExpression(
    code: 'flame',
    icon: LucideIcons.flame,
    label: 'Nổi bật',
    sendText: '[Nổi bật]',
  ),
  AppChatQuickExpression(
    code: 'star',
    icon: LucideIcons.star,
    label: '5 sao',
    sendText: '[5 sao]',
  ),
];

/// Danh mục 12 nhãn cảm xúc & chủ đề kỳ nghỉ bằng `LucideIcons` trong hộp thoại chọn biểu tượng.
const List<AppChatQuickExpression> kAppChatExpressionTokens = [
  AppChatQuickExpression(
    code: 'smile',
    icon: LucideIcons.smile,
    label: 'Vui vẻ',
    sendText: '[Vui vẻ]',
  ),
  AppChatQuickExpression(
    code: 'heart',
    icon: LucideIcons.heart,
    label: 'Yêu thích',
    sendText: '[Yêu thích]',
  ),
  AppChatQuickExpression(
    code: 'like',
    icon: LucideIcons.thumbsUp,
    label: 'Đồng ý',
    sendText: '[Thích]',
  ),
  AppChatQuickExpression(
    code: 'sparkles',
    icon: LucideIcons.sparkles,
    label: 'Tuyệt vời',
    sendText: '[Tuyệt vời]',
  ),
  AppChatQuickExpression(
    code: 'palm',
    icon: LucideIcons.treePalm,
    label: 'Kỳ nghỉ',
    sendText: '[Kỳ nghỉ]',
  ),
  AppChatQuickExpression(
    code: 'waves',
    icon: LucideIcons.waves,
    label: 'Biển Vũng Tàu',
    sendText: '[Biển Vũng Tàu]',
  ),
  AppChatQuickExpression(
    code: 'house',
    icon: LucideIcons.house,
    label: 'Biệt thự',
    sendText: '[Biệt thự]',
  ),
  AppChatQuickExpression(
    code: 'key',
    icon: LucideIcons.keyRound,
    label: 'Nhận phòng',
    sendText: '[Nhận phòng]',
  ),
  AppChatQuickExpression(
    code: 'flame',
    icon: LucideIcons.flame,
    label: 'Tiệc BBQ',
    sendText: '[Tiệc BBQ]',
  ),
  AppChatQuickExpression(
    code: 'coffee',
    icon: LucideIcons.coffee,
    label: 'Thư giãn',
    sendText: '[Thư giãn]',
  ),
  AppChatQuickExpression(
    code: 'party',
    icon: LucideIcons.partyPopper,
    label: 'Chúc mừng',
    sendText: '[Chúc mừng]',
  ),
  AppChatQuickExpression(
    code: 'star',
    icon: LucideIcons.star,
    label: '5 sao',
    sendText: '[5 sao]',
  ),
];

// Giải thuật ánh xạ mã phản hồi cảm xúc sang biểu tượng `LucideIcons` tương ứng (có dự phòng an toàn).
AppChatReactionOption resolveAppChatReaction(String code) {
  for (final item in kAppMessengerReactions) {
    if (item.code == code) return item;
  }
  return kAppMessengerReactions.first;
}

// Giải thuật ánh xạ mã gửi nhanh sang cấu hình biểu tượng `LucideIcons` và chuỗi văn bản gửi đi.
AppChatQuickExpression resolveAppQuickChatOption(String code) {
  for (final item in kAppQuickChatOptions) {
    if (item.code == code) return item;
  }
  return kAppQuickChatOptions.first;
}
