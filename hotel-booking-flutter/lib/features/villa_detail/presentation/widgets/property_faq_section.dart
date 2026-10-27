import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

class PropertyFaqSection extends StatelessWidget {
  const PropertyFaqSection({super.key});

  static const _faqs = [
    (
      'Thời gian nhận và trả villa như thế nào?',
      'Giờ nhận villa tiêu chuẩn từ 14:00 chiều và giờ trả trước 12:00 trưa hôm sau. Quý khách có nhu cầu nhận sớm hoặc trả muộn vui lòng thông báo trước để được hỗ trợ tùy theo tình trạng phòng trống.'
    ),
    (
      'Quy định về tiếng ồn và sử dụng karaoke?',
      'Theo quy định trật tự đô thị tại Vũng Tàu, dàn karaoke và âm thanh ngoài trời hoạt động đến 22:00 tối. Sau 22:00, quý khách vui lòng sinh hoạt văn minh trong không gian phòng kín để không ảnh hưởng các biệt thự lân cận.'
    ),
    (
      'Biệt thự có trang bị đầy đủ gia vị và đồ dùng nấu ăn không?',
      'Khu vực bếp và lò nướng BBQ được trang bị sẵn chén bát, đũa muỗng, nồi niêu xoong chảo, bếp từ/gas và vỉ nướng. Quý khách chỉ cần chuẩn bị thực phẩm tươi sống và than nướng theo sở thích.'
    ),
    (
      'Chính sách đặt cọc và hủy phòng?',
      'Để giữ lịch villa, quý khách vui lòng đặt cọc 50% giá trị hợp đồng. Số tiền còn lại thanh toán khi nhận bàn giao villa. Chính sách dời ngày linh hoạt khi thông báo trước ít nhất 7 ngày.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quy định & Câu hỏi thường gặp',
          style: AppTypography.sectionHeading.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 8),
        Column(
          children: _faqs.asMap().entries.map((entry) {
            final idx = entry.key;
            final faq = entry.value;
            final isLast = idx == _faqs.length - 1;

            return Column(
              children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(vertical: 6),
                    title: Text(
                      faq.$1,
                      style: AppTypography.bodyLarge.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textStrong,
                        height: 1.4,
                      ),
                    ),
                    iconColor: AppColors.iconStrong,
                    collapsedIconColor: AppColors.iconMuted,
                    childrenPadding: const EdgeInsets.only(bottom: 16),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          faq.$2,
                          style: AppTypography.bodyMedium.copyWith(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(color: AppColors.borderSoft, height: 1),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
