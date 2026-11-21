import 'package:flutter/widgets.dart';

/// Định danh các trang thông tin, chính sách và hỗ trợ chính thức trên hệ thống.
enum SupportPageType {
  bookingGuide,
  cancellationPolicy,
  complaintsFeedback,
  faq,
  aboutUs,
  exploreVungTau,
  addonServices,
  memberOffers,
}

/// Một bước trong quy trình hướng dẫn hoặc xử lý nghiệp vụ.
class SupportStepItem {
  final int stepNumber;
  final IconData icon;
  final String title;
  final String description;

  const SupportStepItem({
    required this.stepNumber,
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// Đặc tả một mức chính sách hủy phòng & hoàn tiền theo quy tắc máy chủ (`bookings.service.ts`).
class CancellationTierSpec {
  final String code;
  final String name;
  final String summaryBadge;
  final List<String> rules;

  const CancellationTierSpec({
    required this.code,
    required this.name,
    required this.summaryBadge,
    required this.rules,
  });
}

/// Câu hỏi thường gặp (FAQ) theo từng nhóm chủ đề.
class FaqTopicItem {
  final String id;
  final String category;
  final String question;
  final String answer;

  const FaqTopicItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });
}

/// Phân khu nghỉ dưỡng thực tế tại TP. Vũng Tàu đồng bộ với `locationGroup` của bộ lọc tìm kiếm.
class VungTauZoneItem {
  final String locationGroup;
  final String name;
  final String distanceHint;
  final String highlight;
  final String assetImage;

  const VungTauZoneItem({
    required this.locationGroup,
    required this.name,
    required this.distanceHint,
    required this.highlight,
    required this.assetImage,
  });
}

/// Nhóm tiện ích và dịch vụ lưu trú đi kèm đồng bộ với mã tiện ích (`amenities`) trên hệ thống.
class VillaServiceCategoryItem {
  final String amenityCode;
  final IconData icon;
  final String title;
  final String description;
  final String bookingNote;

  const VillaServiceCategoryItem({
    required this.amenityCode,
    required this.icon,
    required this.title,
    required this.description,
    required this.bookingNote,
  });
}

/// Mô hình bản ghi báo cáo / khiếu nại từ API `/api/reports`.
class UserSupportReport {
  final String id;
  final String targetType;
  final int targetId;
  final String reason;
  final String? description;
  final String status;
  final String? resolution;
  final String createdAt;

  const UserSupportReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description,
    required this.status,
    this.resolution,
    required this.createdAt,
  });

  // Giải thuật chuẩn hóa dữ liệu phản hồi JSON từ Backend sang thực thể bất biến `UserSupportReport`:
  // Trích xuất linh hoạt khóa chính (`reportId` hoặc `id`), ép kiểu an toàn cho `targetId` nguyên dương,
  // và gán giá trị mặc định hợp lệ cho trạng thái xử lý (`open` | `resolved` | `rejected`).
  factory UserSupportReport.fromJson(Map<String, dynamic> json) {
    final rawTargetId = json['targetId'] ?? json['target_id'] ?? 0;
    final parsedTargetId = rawTargetId is int
        ? rawTargetId
        : (int.tryParse(rawTargetId.toString()) ?? 0);

    final rawDesc = json['description']?.toString().trim();
    final rawResolution = json['resolution']?.toString().trim();

    return UserSupportReport(
      id: (json['reportId'] ?? json['report_id'] ?? json['id'] ?? '')
          .toString(),
      targetType:
          (json['targetType'] ?? json['target_type'] ?? 'booking').toString(),
      targetId: parsedTargetId,
      reason: (json['reason'] ?? '').toString(),
      description: (rawDesc != null && rawDesc.isNotEmpty) ? rawDesc : null,
      status: (json['status'] ?? 'open').toString(),
      resolution: (rawResolution != null && rawResolution.isNotEmpty)
          ? rawResolution
          : null,
      createdAt: (json['createdAt'] ?? json['created_at'] ?? '').toString(),
    );
  }
}

/// Tiện ích lọc và ánh xạ định tuyến cho phân hệ Hỗ trợ & Thông tin.
abstract final class SupportPageResolver {
  // Giải thuật ánh xạ đường dẫn URL (Route Path, bao gồm cả bí danh rút gọn như `/ho-tro/chinh-sach-huy`, `/ho-tro/khieu-nai`) sang `SupportPageType`:
  // Chuẩn hóa đường dẫn (tách bỏ query string, loại bỏ dấu gạch chéo dư ở cuối và chữ hoa) rồi đối sánh
  // bảng ánh xạ tĩnh O(1) để quyết định đúng trang đích cần hiển thị.
  static SupportPageType? resolveFromPath(String rawPath) {
    var normalized = rawPath.split('?').first.trim().toLowerCase();
    while (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    switch (normalized) {
      case '/ho-tro/huong-dan':
      case '/ho-tro/huong-dan-dat-phong':
        return SupportPageType.bookingGuide;
      case '/ho-tro/chinh-sach-huy':
      case '/chinh-sach-huy':
      case '/chinh-sach-huy-phong':
      case '/ho-tro/chinh-sach-huy-phong':
        return SupportPageType.cancellationPolicy;
      case '/ho-tro/khieu-nai':
      case '/khieu-nai':
      case '/ho-tro/khieu-nai-gop-y':
        return SupportPageType.complaintsFeedback;
      case '/ho-tro/faq':
      case '/ho-tro/cau-hoi-thuong-gap':
      case '/faq':
        return SupportPageType.faq;
      case '/ve-chung-toi':
        return SupportPageType.aboutUs;
      case '/kham-pha-vung-tau':
        return SupportPageType.exploreVungTau;
      case '/dich-vu-di-kem':
        return SupportPageType.addonServices;
      case '/uu-dai-thanh-vien':
        return SupportPageType.memberOffers;
      default:
        return null;
    }
  }

  // Giải thuật lọc danh sách câu hỏi FAQ kết hợp theo danh mục đa ngôn ngữ và từ khóa tìm kiếm:
  // Duyệt tuyến tính O(n) qua tập câu hỏi, chấp nhận nhãn "Tất cả" ở mọi ngôn ngữ (`vi`/`en`/`ko`
  // hoặc `allCategoryLabel` truyền vào) và kiểm tra chuỗi con không phân biệt hoa thường.
  static List<FaqTopicItem> filterFaqs({
    required List<FaqTopicItem> items,
    required String selectedCategory,
    required String searchQuery,
    String? allCategoryLabel,
  }) {
    final normalizedCat = selectedCategory.trim();
    final normalizedAll = allCategoryLabel?.trim();
    final normalizedQuery = searchQuery.trim().toLowerCase();

    return items.where((item) {
      final isAllCategory = normalizedCat.isEmpty ||
          normalizedCat == 'Tất cả' ||
          normalizedCat == 'All' ||
          normalizedCat == '전체' ||
          (normalizedAll != null && normalizedCat == normalizedAll);
      final matchCategory = isAllCategory || item.category == normalizedCat;
      if (!matchCategory) return false;

      if (normalizedQuery.isEmpty) return true;
      return item.question.toLowerCase().contains(normalizedQuery) ||
          item.answer.toLowerCase().contains(normalizedQuery);
    }).toList();
  }
}
