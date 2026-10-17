import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../../shared/widgets/app_semantic_icons.dart';

/// Port of `Source goc/frontend/src/views/pages/Contact/ContactPage.tsx` and `NotFoundPage.tsx`.
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  static const List<String> _supportTopics = [
    'Tư vấn chọn villa theo số khách',
    'Kiểm tra lịch trống và giá theo ngày',
    'Hỗ trợ thanh toán hoặc đổi lịch',
    'Góp ý trải nghiệm lưu trú',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _sentMessage = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _openHref(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _sentMessage =
          'Cảm ơn bạn, Minh Thanh Villa đã ghi nhận thông tin và sẽ phản hồi sớm nhất.';
    });
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _messageCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1024;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const AppTopHeader(currentPath: '/lien-he'),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Top Section (`ContactPage.tsx` lines 48-82)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          width >= 640 ? 24 : 16,
                          32,
                          width >= 640 ? 24 : 16,
                          48,
                        ),
                        child: isDesktop
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 95,
                                    child: _buildHeroInfo(context),
                                  ),
                                  const SizedBox(width: 32),
                                  Expanded(
                                    flex: 105,
                                    child: _buildHeroImage(height: 420),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeroInfo(context),
                                  const SizedBox(height: 24),
                                  _buildHeroImage(
                                    height: width >= 640 ? 380 : 280,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

                  // Bottom Section (`ContactPage.tsx` lines 84-176)
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: AppColors.divider),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: width >= 640 ? 24 : 16,
                      vertical: 48,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: isDesktop
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 72,
                                    child: _buildSupportAside(),
                                  ),
                                  const SizedBox(width: 32),
                                  Expanded(
                                    flex: 128,
                                    child: _buildConsultationForm(context),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildSupportAside(),
                                  const SizedBox(height: 24),
                                  _buildConsultationForm(context),
                                ],
                              ),
                      ),
                    ),
                  ),

                  const AppFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LIÊN HỆ MINH THANH VILLA',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: Color(0xFF0891B2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Cần tư vấn villa hoặc hỗ trợ đặt phòng?',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            height: 1.18,
            letterSpacing: -0.6,
            color: Color(0xFF020617),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Gửi nhu cầu của bạn cho đội ngũ Minh Thanh Villa. Chúng tôi hỗ trợ chọn căn phù hợp, kiểm tra lịch trống, báo giá và giải đáp các câu hỏi trước chuyến đi.',
          style: TextStyle(
            fontSize: 16,
            height: 1.75,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 560 ? 3 : 1;
            const gap = 12.0;
            final cardWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _ContactInfoCard(
                    icon: LucideIcons.phone,
                    title: 'Hotline',
                    value: '0929.399.893',
                    onTap: () => _openHref('tel:0929399893'),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _ContactInfoCard(
                    icon: LucideIcons.mail,
                    title: 'Email',
                    value: 'bookingvillavtdl@gmail.com',
                    onTap: () => _openHref('mailto:bookingvillavtdl@gmail.com'),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _ContactInfoCard(
                    icon: LucideIcons.mapPin,
                    title: 'Địa chỉ',
                    value: '28 Thi Sách, Vũng Tàu',
                    onTap: () => _openHref(
                      'https://www.google.com/maps/search/?api=1&query=28%20Thi%20Sach%20Vung%20Tau',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeroImage({required double height}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: const AppImage(
        url: 'assets/images/NDT05929-HDR1.jpg',
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildSupportAside() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin hỗ trợ',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF020617),
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  LucideIcons.clock,
                  size: 20,
                  color: AppColors.iconStrong,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thời gian phản hồi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF020617),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '08:00 - 22:00 hằng ngày, ưu tiên khách có lịch nhận phòng gần.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final topic in _supportTopics)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: AppColors.divider),
                ),
              ),
              child: Text(
                topic,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () =>
                _openHref('https://www.facebook.com/villavungtauuytin'),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBrandIcon.facebook(
                    size: 16,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Nhắn qua Facebook',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gửi yêu cầu tư vấn',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF020617),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Điền thông tin cơ bản để đội ngũ hỗ trợ gợi ý căn phù hợp hơn.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCols = constraints.maxWidth >= 520;
                if (twoCols) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildNameField()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildPhoneField()),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildNameField(),
                    const SizedBox(height: 16),
                    _buildPhoneField(),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Nhu cầu của bạn',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _messageCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText:
                    'Ví dụ: nhóm 10 khách, cần villa hồ bơi gần Bãi Sau, đi 2 ngày 1 đêm...',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập nhu cầu của bạn'
                  : null,
            ),
            const SizedBox(height: 16),
            if (_sentMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 12,
                ),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: AppColors.divider),
                  ),
                ),
                child: Text(
                  _sentMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0891B2),
                  ),
                ),
              ),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                FilledButton.icon(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(
                    LucideIcons.send,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Gửi yêu cầu',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => context.push('/tim-kiem'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Xem danh sách villa',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0891B2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Họ và tên',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            hintText: 'Tên của bạn',
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Vui lòng nhập họ và tên'
              : null,
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Số điện thoại',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: '0929...',
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Vui lòng nhập số điện thoại'
              : null,
        ),
      ],
    );
  }
}

class _ContactInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _ContactInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: AppColors.divider),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.iconStrong),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF020617),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Port of `NotFoundPage.tsx`.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const AppTopHeader(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: AppColors.divider),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(color: AppColors.divider),
                            ),
                          ),
                          child: const Text(
                            '404 / ĐIỀU HƯỚNG LẠC NHỊP',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                              color: Color(0xFF0891B2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Xin lỗi, chúng tôi không tìm thấy trang bạn cần.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: Color(0xFF083344),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Liên kết này có thể đã thay đổi hoặc không còn tồn tại. Bạn có thể quay về trang chủ hoặc tiếp tục khám phá các chỗ ở đang mở để không bị ngắt mạch trải nghiệm.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.65,
                            color: Color(0xFF0891B2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton(
                              onPressed: () => context.go('/'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF06B6D4),
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                              ),
                              child: const Text('Về trang chủ'),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/');
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                              ),
                              child: const Text('Quay lại trang trước'),
                            ),
                          ],
                        ),
                      ],
                    ),
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
