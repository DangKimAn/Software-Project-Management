import 'package:flutter/material.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../shared/widgets/app_image.dart';

/// Khung trình chiếu ảnh vuốt ngang của thẻ biệt thự kèm chấm chỉ báo vị trí động.
///
/// Tự động lùi về ảnh tài nguyên nội bộ khi danh sách `imageUrls` rỗng để không bao giờ hiển thị khung trống.
class PropertyImageCarousel extends StatefulWidget {
  /// Danh sách đường dẫn ảnh mạng hoặc tài nguyên nội bộ của biệt thự.
  final List<String> imageUrls;

  /// Tỷ lệ khung hình cố định của vùng ảnh (mặc định `4 / 3`).
  final double aspectRatio;

  /// Bán kính bo góc cho khung cắt ảnh `ClipRRect`.
  final BorderRadius borderRadius;

  /// Khởi tạo bộ trình chiếu ảnh `PropertyImageCarousel`.
  const PropertyImageCarousel({
    super.key,
    required this.imageUrls,
    this.aspectRatio = 4 / 3,
    this.borderRadius = AppRadii.roundedCard,
  });

  @override
  State<PropertyImageCarousel> createState() => _PropertyImageCarouselState();
}

class _PropertyImageCarouselState extends State<PropertyImageCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.imageUrls.isNotEmpty
        ? widget.imageUrls
        : const ['assets/images/NDT05929-HDR1.jpg'];

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final url = images[index];
                return AppImage(
                  url: url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                );
              },
            ),

            // Dots indicator (only if more than 1 image)
            if (images.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (idx) {
                    final isActive = idx == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
