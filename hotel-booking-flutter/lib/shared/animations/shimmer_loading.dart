import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';

/// Khung xương tải dữ liệu tĩnh chuẩn thiết kế tối giản (không dùng dải chuyển màu hay nhấp nháy vô tận)
/// và tự động ẩn nội dung giả khỏi trình đọc màn hình bằng `ExcludeSemantics`.
///
/// Static semantic skeleton: no gradient, halo, or perpetual animation.
/// The name remains compatible with existing callers.
class ShimmerLoading extends StatelessWidget {
  /// Cây giao diện khung xương hiển thị trong lúc chờ dữ liệu.
  final Widget child;

  /// Khởi tạo vùng khung xương tĩnh loại trừ khỏi cây ngữ nghĩa trợ năng.
  const ShimmerLoading({super.key, required this.child});

  /// Bọc `child` trong `ExcludeSemantics` để trình đọc màn hình không đọc các hộp giữ chỗ vô nghĩa.
  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: child);
}

/// Thẻ khung xương giữ chỗ khớp chính xác tỷ lệ khung ảnh `4:3` và nhịp bố cục của `PropertyCard`
/// nhằm triệt tiêu hiện tượng nhảy bố cục (CLS) khi danh sách villa tải xong.
///
/// A luxury placeholder skeleton card matching the exact dimensions of PropertyCard.
class ShimmerPropertyCard extends StatelessWidget {
  /// Khởi tạo thẻ khung xương giữ chỗ cho thẻ bất động sản.
  const ShimmerPropertyCard({super.key});

  /// Dựng bố cục khung ảnh `4:3`, dòng tiêu đề, vị trí, thông số và giá tiền bằng màu nền tĩnh `AppColors.skeleton`.
  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceBase,
          borderRadius: AppRadii.roundedCard,
          border: Border.all(color: AppColors.borderSoft),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image skeleton
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(color: AppColors.skeleton),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                          child: Container(
                        height: 20,
                        width: 180,
                        decoration: BoxDecoration(
                          color: AppColors.skeleton,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )),
                      const SizedBox(width: 12),
                      Container(
                        height: 18,
                        width: 48,
                        decoration: BoxDecoration(
                          color: AppColors.skeleton,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Location line
                  Container(
                    height: 14,
                    width: 120,
                    decoration: BoxDecoration(
                      color: AppColors.skeleton,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Specs line
                  Container(
                    height: 14,
                    width: 200,
                    decoration: BoxDecoration(
                      color: AppColors.skeleton,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Price line
                  Container(
                    height: 22,
                    width: 140,
                    decoration: BoxDecoration(
                      color: AppColors.skeleton,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
