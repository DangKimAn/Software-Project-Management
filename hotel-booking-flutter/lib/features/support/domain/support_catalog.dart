import 'dart:ui';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'entities/support_page_models.dart';

// CONFLICT-RESOLVED: Chuyển toàn bộ dữ liệu danh mục trang Hỗ trợ & Khám phá sang đa ngôn ngữ
// `AppLocalizations` (`vi`/`en`/`ko`) theo FLUTTER_RULES.md Mục 2 & Mục 15, đồng thời duy trì
// các getter mặc định tiếng Việt phục vụ tương thích ngược cho kiểm thử đơn vị.

/// Nguồn dữ liệu nghiệp vụ chính thức của The Palm Villa cho các trang Hỗ trợ & Khám phá.
/// Toàn bộ quy tắc giữ chỗ 15 phút, mô hình đêm `[checkIn, checkOut)` và tỷ lệ hoàn tiền
/// khớp 100% với máy trạng thái Backend (`booking-state-machine.ts` & `bookings.service.ts`).
abstract final class SupportCatalog {
  static AppLocalizations get _defaultVi =>
      lookupAppLocalizations(const Locale('vi'));

  static List<SupportStepItem> get bookingGuideSteps =>
      bookingGuideStepsOf(_defaultVi);

  static List<CancellationTierSpec> get cancellationTiers =>
      cancellationTiersOf(_defaultVi);

  static List<SupportStepItem> get complaintProcessSteps =>
      complaintProcessStepsOf(_defaultVi);

  static List<String> get faqCategories => faqCategoriesOf(_defaultVi);

  static List<FaqTopicItem> get faqItems => faqItemsOf(_defaultVi);

  static List<VungTauZoneItem> get vungTauZones => vungTauZonesOf(_defaultVi);

  static List<VillaServiceCategoryItem> get addonServices =>
      addonServicesOf(_defaultVi);

  // Giải thuật khởi tạo danh sách 4 bước hướng dẫn đặt phòng theo ngôn ngữ hiện hành (`vi`/`en`/`ko`).
  static List<SupportStepItem> bookingGuideStepsOf(AppLocalizations l10n) => [
        SupportStepItem(
          stepNumber: 1,
          icon: LucideIcons.search,
          title: l10n.supportGuideStep1Title,
          description: l10n.supportGuideStep1Desc,
        ),
        SupportStepItem(
          stepNumber: 2,
          icon: LucideIcons.calendarCheck,
          title: l10n.supportGuideStep2Title,
          description: l10n.supportGuideStep2Desc,
        ),
        SupportStepItem(
          stepNumber: 3,
          icon: LucideIcons.clock,
          title: l10n.supportGuideStep3Title,
          description: l10n.supportGuideStep3Desc,
        ),
        SupportStepItem(
          stepNumber: 4,
          icon: LucideIcons.shieldCheck,
          title: l10n.supportGuideStep4Title,
          description: l10n.supportGuideStep4Desc,
        ),
      ];

  // Giải thuật tổng hợp 3 bậc chính sách hủy phòng (`flexible`/`moderate`/`strict`) theo ngôn ngữ hiện hành.
  static List<CancellationTierSpec> cancellationTiersOf(
    AppLocalizations l10n,
  ) =>
      [
        CancellationTierSpec(
          code: 'flexible',
          name: l10n.supportCancelFlexName,
          summaryBadge: l10n.supportCancelFlexBadge,
          rules: [
            l10n.supportCancelFlexRule1,
            l10n.supportCancelFlexRule2,
          ],
        ),
        CancellationTierSpec(
          code: 'moderate',
          name: l10n.supportCancelModName,
          summaryBadge: l10n.supportCancelModBadge,
          rules: [
            l10n.supportCancelModRule1,
            l10n.supportCancelModRule2,
            l10n.supportCancelModRule3,
          ],
        ),
        CancellationTierSpec(
          code: 'strict',
          name: l10n.supportCancelStrictName,
          summaryBadge: l10n.supportCancelStrictBadge,
          rules: [
            l10n.supportCancelStrictRule1,
            l10n.supportCancelStrictRule2,
          ],
        ),
      ];

  // Giải thuật khởi tạo quy trình 3 bước tiếp nhận và đối soát khiếu nại theo ngôn ngữ hiện hành.
  static List<SupportStepItem> complaintProcessStepsOf(AppLocalizations l10n) =>
      [
        SupportStepItem(
          stepNumber: 1,
          icon: LucideIcons.fileText,
          title: l10n.supportComplaintStep1Title,
          description: l10n.supportComplaintStep1Desc,
        ),
        SupportStepItem(
          stepNumber: 2,
          icon: LucideIcons.shieldAlert,
          title: l10n.supportComplaintStep2Title,
          description: l10n.supportComplaintStep2Desc,
        ),
        SupportStepItem(
          stepNumber: 3,
          icon: LucideIcons.check,
          title: l10n.supportComplaintStep3Title,
          description: l10n.supportComplaintStep3Desc,
        ),
      ];

  // Giải thuật ánh xạ danh sách nhóm chủ đề FAQ đa ngôn ngữ đồng bộ với từng câu hỏi.
  static List<String> faqCategoriesOf(AppLocalizations l10n) => [
        l10n.supportFaqCatAll,
        l10n.supportFaqCatBooking,
        l10n.supportFaqCatPayment,
        l10n.supportFaqCatAmenities,
        l10n.supportFaqCatHost,
      ];

  // Giải thuật khởi tạo danh sách câu hỏi thường gặp (FAQ) gắn liền mã định danh ổn định cho Widget Key.
  static List<FaqTopicItem> faqItemsOf(AppLocalizations l10n) => [
        FaqTopicItem(
          id: 'faq-night-model',
          category: l10n.supportFaqCatBooking,
          question: l10n.supportFaq1Q,
          answer: l10n.supportFaq1A,
        ),
        FaqTopicItem(
          id: 'faq-hold-15m',
          category: l10n.supportFaqCatBooking,
          question: l10n.supportFaq2Q,
          answer: l10n.supportFaq2A,
        ),
        FaqTopicItem(
          id: 'faq-weekend-surcharge',
          category: l10n.supportFaqCatBooking,
          question: l10n.supportFaq3Q,
          answer: l10n.supportFaq3A,
        ),
        FaqTopicItem(
          id: 'faq-payment-methods',
          category: l10n.supportFaqCatPayment,
          question: l10n.supportFaq4Q,
          answer: l10n.supportFaq4A,
        ),
        FaqTopicItem(
          id: 'faq-refund-track',
          category: l10n.supportFaqCatPayment,
          question: l10n.supportFaq5Q,
          answer: l10n.supportFaq5A,
        ),
        FaqTopicItem(
          id: 'faq-chat-host',
          category: l10n.supportFaqCatAmenities,
          question: l10n.supportFaq6Q,
          answer: l10n.supportFaq6A,
        ),
        FaqTopicItem(
          id: 'faq-become-host',
          category: l10n.supportFaqCatHost,
          question: l10n.supportFaq7Q,
          answer: l10n.supportFaq7A,
        ),
      ];

  // Giải thuật khởi tạo 4 phân khu nghỉ dưỡng biển tại TP. Vũng Tàu đồng bộ `locationGroup`.
  static List<VungTauZoneItem> vungTauZonesOf(AppLocalizations l10n) => [
        VungTauZoneItem(
          locationGroup: 'bai_sau',
          name: l10n.supportZoneBaiSauName,
          distanceHint: l10n.supportZoneBaiSauHint,
          highlight: l10n.supportZoneBaiSauHighlight,
          assetImage: 'assets/images/NDT05929-HDR1.jpg',
        ),
        VungTauZoneItem(
          locationGroup: 'bai_truoc',
          name: l10n.supportZoneBaiTruocName,
          distanceHint: l10n.supportZoneBaiTruocHint,
          highlight: l10n.supportZoneBaiTruocHighlight,
          assetImage: 'assets/images/19tranphu.jpg',
        ),
        VungTauZoneItem(
          locationGroup: 'chi_linh',
          name: l10n.supportZoneChiLinhName,
          distanceHint: l10n.supportZoneChiLinhHint,
          highlight: l10n.supportZoneChiLinhHighlight,
          assetImage: 'assets/images/casamar.jpg',
        ),
        VungTauZoneItem(
          locationGroup: 'long_cung',
          name: l10n.supportZoneLongCungName,
          distanceHint: l10n.supportZoneLongCungHint,
          highlight: l10n.supportZoneLongCungHighlight,
          assetImage: 'assets/images/sunset.jpg',
        ),
      ];

  // Giải thuật khởi tạo 6 nhóm tiện nghi & dịch vụ đi kèm đồng bộ mã `amenityCode`.
  static List<VillaServiceCategoryItem> addonServicesOf(
    AppLocalizations l10n,
  ) =>
      [
        VillaServiceCategoryItem(
          amenityCode: 'pool',
          icon: LucideIcons.waves,
          title: l10n.supportAddonPoolTitle,
          description: l10n.supportAddonPoolDesc,
          bookingNote: l10n.supportAddonPoolNote,
        ),
        VillaServiceCategoryItem(
          amenityCode: 'bbq',
          icon: LucideIcons.flame,
          title: l10n.supportAddonBbqTitle,
          description: l10n.supportAddonBbqDesc,
          bookingNote: l10n.supportAddonBbqNote,
        ),
        VillaServiceCategoryItem(
          amenityCode: 'kitchen',
          icon: LucideIcons.utensils,
          title: l10n.supportAddonKitchenTitle,
          description: l10n.supportAddonKitchenDesc,
          bookingNote: l10n.supportAddonKitchenNote,
        ),
        VillaServiceCategoryItem(
          amenityCode: 'karaoke',
          icon: LucideIcons.micVocal,
          title: l10n.supportAddonKaraokeTitle,
          description: l10n.supportAddonKaraokeDesc,
          bookingNote: l10n.supportAddonKaraokeNote,
        ),
        VillaServiceCategoryItem(
          amenityCode: 'parking',
          icon: LucideIcons.car,
          title: l10n.supportAddonParkingTitle,
          description: l10n.supportAddonParkingDesc,
          bookingNote: l10n.supportAddonParkingNote,
        ),
        VillaServiceCategoryItem(
          amenityCode: 'near_beach',
          icon: LucideIcons.umbrella,
          title: l10n.supportAddonBeachTitle,
          description: l10n.supportAddonBeachDesc,
          bookingNote: l10n.supportAddonBeachNote,
        ),
      ];
}
