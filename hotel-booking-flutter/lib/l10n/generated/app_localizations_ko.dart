// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '민탄 빌라';

  @override
  String get appTagline => '붕따우 럭셔리 휴양 빌라';

  @override
  String get greetingMorning => '좋은 아침입니다!';

  @override
  String get greetingAfternoon => '좋은 오후입니다!';

  @override
  String get greetingEvening => '좋은 저녁입니다!';

  @override
  String get homeWelcomeSubtitle => '해안 도시 붕따우에 오신 것을 진심으로 환영합니다';

  @override
  String get homeRecentlyViewedTitle => '최근 본 숙소';

  @override
  String get homePopularDestinationsTitle => '붕따우 인기 여행지';

  @override
  String get homeApprovedListingsTitle => '승인된 숙소 목록';

  @override
  String get homeSeeMoreVillas => '빌라 더 보기';

  @override
  String get homeSeeNext => '다음 보기';

  @override
  String get homeShowLess => '접기';

  @override
  String get homeBlogBadge => '최신 아티클';

  @override
  String get homeBlogTitle => '추천 숙박 가이드';

  @override
  String get homeBlogSubtitle =>
      '가족 여행부터 단체 모임까지 붕따우 빌라 예약에 필요한 실용적인 가이드를 제공합니다.';

  @override
  String get homeBlogSeeAll => '모든 글 보기';

  @override
  String get searchPlaceholder => '검색을 시작하세요...';

  @override
  String get searchDestinationLabel => '여행지';

  @override
  String get searchDestinationHint => '붕따우 어디에서 머무르고 싶으신가요?';

  @override
  String get searchModeDates => '날짜 지정';

  @override
  String get searchModeMonths => '월 단위';

  @override
  String get searchModeFlexible => '유연한 일정';

  @override
  String get searchFlexibleWeekend => '주말';

  @override
  String get searchFlexibleWeek => '1주일';

  @override
  String get searchFlexibleMonth => '1개월';

  @override
  String get searchExactDates => '정확한 날짜';

  @override
  String searchPlusMinusDays(int days) {
    return '± $days일';
  }

  @override
  String get searchAdults => '성인';

  @override
  String get searchAdultsDesc => '13세 이상';

  @override
  String get searchChildren => '어린이';

  @override
  String get searchChildrenDesc => '2~12세';

  @override
  String get searchInfants => '유아';

  @override
  String get searchInfantsDesc => '2세 미만';

  @override
  String get searchPets => '반려동물';

  @override
  String get searchPetsDesc => '반려동물 동반';

  @override
  String get searchFilterTitle => '상세 필터';

  @override
  String get searchSortNewest => '최신순';

  @override
  String get searchSortPriceAsc => '가격 낮은순';

  @override
  String get searchSortPriceDesc => '가격 높은순';

  @override
  String get searchSortRatingDesc => '평점 높은순';

  @override
  String get navDiscover => '탐색';

  @override
  String get navZalo => 'Zalo';

  @override
  String get navHotline => '핫라인';

  @override
  String get navFavorites => '위시리스트';

  @override
  String get navTrips => '여행';

  @override
  String get navAccount => '계정';

  @override
  String get navSettings => '설정';

  @override
  String get navStays => '숙소';

  @override
  String get navBlog => '여행 가이드';

  @override
  String get navContact => '문의하기';

  @override
  String get navMessages => '메시지';

  @override
  String get navNotifications => '알림';

  @override
  String get navBookingQueue => '예약 대기열';

  @override
  String get navBecomeHost => '호스트 되기';

  @override
  String get navHostPortal => '호스트 포털';

  @override
  String get navAdminPortal => '관리자 포털';

  @override
  String bedroomsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '침실 $count개',
    );
    return '$_temp0';
  }

  @override
  String bedsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '침대 $count개',
    );
    return '$_temp0';
  }

  @override
  String guestsCapacity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '최대 $count명',
    );
    return '$_temp0';
  }

  @override
  String guestsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '게스트 $count명',
    );
    return '$_temp0';
  }

  @override
  String adultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '성인 $count명',
    );
    return '$_temp0';
  }

  @override
  String childrenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '어린이 $count명',
    );
    return '$_temp0';
  }

  @override
  String infantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '유아 $count명',
    );
    return '$_temp0';
  }

  @override
  String petsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '반려동물 $count마리',
    );
    return '$_temp0';
  }

  @override
  String bathroomsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '욕실 $count개',
    );
    return '$_temp0';
  }

  @override
  String nightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count박',
    );
    return '$_temp0';
  }

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '리뷰 $count개',
      zero: '리뷰 없음',
    );
    return '$_temp0';
  }

  @override
  String beachDistance(int distance) {
    return '해변까지 ${distance}m';
  }

  @override
  String priceFrom(String price) {
    return '1박당 $price부터';
  }

  @override
  String get pricePerNightUnit => '/ 박';

  @override
  String saturdayPrice(String price) {
    return '토요일: $price';
  }

  @override
  String totalNightsWithFee(int nights) {
    String _temp0 = intl.Intl.pluralLogic(
      nights,
      locale: localeName,
      other: '총 $nights박 • 수수료 포함',
    );
    return '$_temp0';
  }

  @override
  String get contactForPrice => '가격 문의';

  @override
  String get statusAvailable => '예약 가능';

  @override
  String get statusBooked => '예약 마감';

  @override
  String get badgeFeatured => '추천';

  @override
  String get badgeNew => '신규';

  @override
  String get badgeNearBeach => '해변 인접';

  @override
  String get badgeSaltwater => '해수 풀장';

  @override
  String get badgeGroup => '단체 환영';

  @override
  String get ctaContactZalo => 'Zalo 문의';

  @override
  String get ctaCallHotline => '핫라인 전화';

  @override
  String get ctaBookNow => '예약 상담';

  @override
  String get ctaBookInstant => '지금 예약';

  @override
  String get ctaRequestBooking => '예약 요청';

  @override
  String get ctaAddToQueue => '예약 대기열에 추가';

  @override
  String get ctaViewDetail => '상세 보기';

  @override
  String get ctaCopyLink => '링크 복사';

  @override
  String get ctaCopied => '링크가 클립보드에 복사되었습니다';

  @override
  String get ctaZaloCopied => '상담 내용이 복사되었으며 Zalo를 엽니다';

  @override
  String get ctaRetry => '다시 시도';

  @override
  String get ctaResetFilter => '필터 초기화';

  @override
  String get ctaBack => '뒤로';

  @override
  String get ctaBackHome => '홈으로 돌아가기';

  @override
  String get ctaClose => '닫기';

  @override
  String get ctaCancel => '취소';

  @override
  String get ctaConfirm => '확인';

  @override
  String get ctaSave => '변경사항 저장';

  @override
  String get ctaPrevPage => '이전';

  @override
  String get ctaNextPage => '다음';

  @override
  String paginationPageOf(int page, int totalPages) {
    return '$page / $totalPages 페이지';
  }

  @override
  String get loadingText => '데이터를 불러오는 중...';

  @override
  String get loadingVillas => '숙소 정보를 불러오는 중...';

  @override
  String get loadingVillaDetail => '빌라 상세 정보를 불러오는 중...';

  @override
  String get loadingFavorites => '위시리스트를 불러오는 중...';

  @override
  String get emptyList => '일치하는 빌라가 없습니다';

  @override
  String get emptyListDesc => '검색 조건이나 숙박 일정을 변경해 보세요.';

  @override
  String get errorOccurred => '오류가 발생했습니다';

  @override
  String get errorTryAgain => '지금 요청을 처리할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get errorOfflineTitle => '인터넷 연결 없음';

  @override
  String get errorOfflineMessage =>
      '네트워크 연결이 없거나 불안정합니다. 연결 상태를 확인한 후 다시 시도해 주세요.';

  @override
  String get errorServerTitle => '서버 오류';

  @override
  String get errorServerMessage => '서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorUnauthorizedMessage => '세션이 만료되었습니다. 다시 로그인해 주세요.';

  @override
  String get errorForbiddenMessage => '이 기능에 접근할 권한이 없습니다.';

  @override
  String get errorNotFoundTitle => '404 — 페이지를 찾을 수 없습니다';

  @override
  String get errorNotFoundMessage => '요청하신 페이지가 존재하지 않거나 이동되었습니다.';

  @override
  String get errorVillaNotFoundTitle => '빌라를 찾을 수 없습니다';

  @override
  String get errorVillaNotFoundMessage => '찾으시는 빌라가 존재하지 않거나 운영이 중단되었습니다.';

  @override
  String get errorRateLimitMessage => '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorValidationMessage => '입력하신 정보가 올바르지 않습니다. 다시 확인해 주세요.';

  @override
  String get dateBooked => '예약 마감된 날짜입니다';

  @override
  String get checkInDate => '체크인';

  @override
  String get checkOutDate => '체크아웃';

  @override
  String get guestCount => '인원 수';

  @override
  String get priceBreakdown => '박별 요금 세부 정보';

  @override
  String get dailyPriceBreakdownTitle => '박별 상세 요금표';

  @override
  String get specCapacityLabel => '수용 인원';

  @override
  String get specBedroomsLabel => '침실';

  @override
  String get specBedsLabel => '침대';

  @override
  String get specBathroomsLabel => '욕실';

  @override
  String get specHighlightsTitle => '주요 편의시설 및 위치';

  @override
  String get specExpandAction => '상세 사양 더 보기';

  @override
  String get specCollapseAction => '상세 사양 접기';

  @override
  String get specPrivatePool => '전용 수영장';

  @override
  String get specNoPool => '수영장 없음';

  @override
  String get specBbqKitchen => '주방 및 바비큐 설비 완비';

  @override
  String get specBasicKitchen => '기본 주방';

  @override
  String get specParking => '자동차 주차 가능';

  @override
  String get specSelfParking => '외부 주차';

  @override
  String get specNearCenter => '중심가 인접';

  @override
  String get hostDefaultName => 'VungTauStay 호스트';

  @override
  String get hostDefaultBio => '붕따우 현지 호스트가 숙박 및 체크인 정보를 안내해 드립니다.';

  @override
  String get bookingInstantConfirm => '즉시 예약 확정';

  @override
  String get bookingSupport247 => '24시간 예약 상담';

  @override
  String get faqTitle => '자주 묻는 질문';

  @override
  String get rulesAndFaqTitle => '이용 수칙 및 자주 묻는 질문';

  @override
  String get faqCheckInTitle => '체크인 및 체크아웃 시간은 어떻게 되나요?';

  @override
  String get faqCheckInBody =>
      '표준 체크인은 오후 14:00부터이며, 체크아웃은 익일 낮 12:00 이전입니다. 얼리 체크인이나 레이트 체크아웃은 객실 상황에 따라 사전 문의 시 지원됩니다.';

  @override
  String get faqNoiseTitle => '소음 및 노래방 이용 규정은 어떻게 되나요?';

  @override
  String get faqNoiseBody =>
      '붕따우 시 규정에 따라 야외 음향 및 노래방 기기는 밤 22:00까지 이용 가능합니다. 22:00 이후에는 인근 빌라에 피해가 가지 않도록 실내에서 조용히 이용해 주세요.';

  @override
  String get faqKitchenTitle => '조리 도구와 바비큐 설비가 구비되어 있나요?';

  @override
  String get faqKitchenBody =>
      '주방과 바비큐 공간에 식기류, 냄비, 프라이팬, 가스/인덕션 레인지, 그릴망이 준비되어 있습니다. 신선한 식재료와 숯만 준비해 오시면 됩니다.';

  @override
  String get faqDepositTitle => '예약금 및 취소 정책은 어떻게 되나요?';

  @override
  String get faqDepositBody =>
      '예약 확정을 위해 계약 금액의 50% 예약금이 필요하며, 잔금은 체크인 시 결제합니다. 최소 7일 전 사전 통보 시 일정 변경이 가능합니다.';

  @override
  String get settingsLanguage => '언어';

  @override
  String get settingsEnvironment => '환경';

  @override
  String get settingsVersion => '버전';

  @override
  String get favoritesEmpty => '저장된 빌라가 없습니다';

  @override
  String get favoritesEmptyDesc => '빌라 카드의 하트 아이콘을 눌러 위시리스트에 저장해 보세요.';

  @override
  String get bookingStatusPendingPayment => '결제 대기 중';

  @override
  String get bookingStatusPaymentExpired => '결제 기한 만료';

  @override
  String get bookingStatusPaid => '결제 완료';

  @override
  String get bookingStatusConfirmed => '예약 확정';

  @override
  String get bookingStatusCheckedIn => '체크인 완료';

  @override
  String get bookingStatusCheckedOut => '체크아웃 완료';

  @override
  String get bookingStatusCompleted => '이용 완료';

  @override
  String get bookingStatusCancelledByGuest => '게스트 취소';

  @override
  String get bookingStatusCancelledByHost => '호스트 취소';

  @override
  String get bookingStatusCancelledByAdmin => '관리자 취소';

  @override
  String get bookingStatusRejected => '거절됨';

  @override
  String get bookingStatusRefundPending => '환불 처리 중';

  @override
  String get bookingStatusRefunded => '환불 완료';

  @override
  String get paymentUnverifiedTitle => '결제 확인 대기 중';

  @override
  String get paymentUnverifiedDesc =>
      '현재 서버에서 결제 상태를 확인할 수 없습니다. 네트워크 연결을 확인한 후 다시 시도해 주세요.';

  @override
  String get paymentRecheckStatus => '상태 다시 확인';

  @override
  String get authLoginTitle => '로그인';

  @override
  String get authRegisterTitle => '회원가입';

  @override
  String get authForgotPasswordTitle => '비밀번호 찾기';

  @override
  String get authGoogleSignIn => 'Google로 계속하기';

  @override
  String get authLogout => '로그아웃';

  @override
  String get profileVerified => '인증됨';

  @override
  String get profileUnverified => '미인증';

  @override
  String get hostOnboardingTitle => '민탄 빌라 호스트 되기';

  @override
  String get hostKycTitle => '호스트 등록 및 본인 인증';

  @override
  String get hostKycStatusTitle => '호스트 심사 상태';

  @override
  String get hostTabOverview => '개요';

  @override
  String get hostTabProperties => '숙소 관리';

  @override
  String get hostTabNewProperty => '숙소 등록';

  @override
  String get hostTabBookings => '예약 관리';

  @override
  String get hostTabCalendar => '달력 및 요금';

  @override
  String get hostTabGuests => '게스트 목록';

  @override
  String get hostTabMessages => '메시지';

  @override
  String get hostTabPayouts => '정산 내역';

  @override
  String get hostTabReviews => '리뷰 관리';

  @override
  String get hostTabReports => '매출 리포트';

  @override
  String get hostTabSupport => '고객 지원';

  @override
  String get hostTabSettings => '호스트 설정';

  @override
  String get hostListingDraft => '초안';

  @override
  String get hostListingPendingApproval => '승인 대기';

  @override
  String get hostListingPublished => '게시 중';

  @override
  String get hostListingHidden => '숨김';

  @override
  String get hostListingRejected => '반려됨';

  @override
  String get adminTabOverview => '대시보드';

  @override
  String get adminTabUsers => '사용자 관리';

  @override
  String get adminTabModeration => '숙소 검수';

  @override
  String get adminTabHostApplications => '호스트 신청 심사';

  @override
  String get adminTabRoles => '권한 관리';

  @override
  String get adminUserStatusActive => '활성';

  @override
  String get adminUserStatusSuspended => '정지됨';

  @override
  String get adminUserStatusInactive => '비활성';

  @override
  String get settingsCurrency => '표시 통화';

  @override
  String get currencyFollowLanguage => '언어에 따라 자동 설정';

  @override
  String get currencyFollowLanguageDesc => '인터페이스 언어에 맞춰 통화를 자동으로 전환합니다';

  @override
  String get currencyNameVnd => '베트남 동 (VND - ₫)';

  @override
  String get currencyNameUsd => '미국 달러 (USD - \$)';

  @override
  String get currencyNameKrw => '대한민국 원 (KRW - ₩)';

  @override
  String fxEstimatedPrice(String amount) {
    return '예상 금액: 약 $amount';
  }

  @override
  String fxTotalPayableVnd(String amountVnd) {
    return '실제 결제 총액: $amountVnd';
  }

  @override
  String get fxChargedInVndNotice =>
      '실제 결제는 베트남 동(VND)으로 처리됩니다. 카드 발급 은행의 환율 및 수수료가 적용될 수 있습니다.';

  @override
  String fxReferenceRateLabel(String source) {
    return '참고 환율 ($source)';
  }

  @override
  String fxRateUpdatedAt(String time) {
    return '환율 기준 시각: $time';
  }

  @override
  String get fxRateUnavailableFallback =>
      '환율 정보를 불러올 수 없어 공식 베트남 동(VND) 가격으로 표시합니다.';

  @override
  String fxRateStaleNotice(String time) {
    return '최근 확인된 환율($time)을 기준으로 표시 중입니다.';
  }

  @override
  String get fxBankConversionFeeNotice =>
      '은행 및 카드사에 따라 별도의 환전 수수료가 발생할 수 있습니다.';

  @override
  String get fxPaymentMethodUnsupported => '현재 지원되지 않는 결제 수단입니다.';

  @override
  String get fxRefundInVndNotice =>
      '실제 환불은 베트남 동(VND)으로 처리되며, 환불 시점의 은행 환율에 따라 명세서 금액이 달라질 수 있습니다.';

  @override
  String get fxHistoricalReferenceNote => '외화 금액은 참고용이며 실제 카드 명세서 청구 금액이 아닙니다.';

  @override
  String fxPayButtonVnd(String amountVnd, String method) {
    return '$method로 $amountVnd 결제';
  }

  @override
  String get fxPriceRangePerNight => '1박 요금 범위';

  @override
  String get vnpayGatewayTitle => 'VNPay (QR 결제 / 베트남 국내 카드)';

  @override
  String get vnpayGatewaySubtitle => 'VNPay 보안 결제창을 통한 베트남 동(VND) 결제';

  @override
  String get momoGatewayTitle => 'MoMo 전자지갑';

  @override
  String get momoGatewaySubtitle => 'MoMo 앱 또는 QR 코드를 통한 베트남 동(VND) 결제';

  @override
  String get footerSupportTitle => '고객 지원';

  @override
  String get footerLinkBookingGuide => '예약 가이드';

  @override
  String get footerLinkCancellationPolicy => '취소 및 환불 정책';

  @override
  String get footerLinkComplaintsFeedback => '불만 접수 및 의견';

  @override
  String get footerLinkFaq => '자주 묻는 질문 (FAQ)';

  @override
  String get footerExploreTitle => '탐색 및 서비스';

  @override
  String get footerLinkAboutUs => '회사 소개';

  @override
  String get footerLinkExploreVungTau => '붕따우 지역 탐색';

  @override
  String get footerLinkTravelGuide => '붕따우 여행 가이드';

  @override
  String get footerLinkAddonServices => '빌라 부대 서비스';

  @override
  String get footerLinkMemberOffers => '회원 전용 혜택';

  @override
  String get footerContactTitle => '연락처 안내';

  @override
  String footerHotlineLabel(String phone) {
    return '핫라인: $phone';
  }

  @override
  String get footerOnlineConsultLink => '온라인 상담 문의';

  @override
  String footerAddressLabel(String address) {
    return '주소: $address';
  }

  @override
  String footerEmailLabel(String email) {
    return '이메일: $email';
  }

  @override
  String get footerEmailSubject => '더 팜 빌라 붕따우 예약 문의';

  @override
  String get footerSocialTitle => '소셜 미디어';

  @override
  String get footerCopyright => '© 2026 더 팜 빌라 붕따우. 모든 권리 보유.';

  @override
  String get supportGuideStep1Title => '해안 구역 및 실시간 예약 가능 일정으로 검색';

  @override
  String get supportGuideStep1Desc =>
      '붕따우 해안 구역(바이사우, 바이트르억, 찌린, 롱꿍), 숙박 일정 [체크인, 체크아웃) 및 총 인원을 선택하여 예약 가능한 독채 빌라를 필터링하세요.';

  @override
  String get supportGuideStep2Title => '박별 요금표 확인 및 프로모션 코드 적용';

  @override
  String get supportGuideStep2Desc =>
      '빌라 상세 사양(침실, 침대, 욕실, 해변 거리), 평일 및 주말 박별 요금, 기준 인원 초과 추가 요금 여부를 확인하고 유효한 할인 쿠폰을 적용하세요.';

  @override
  String get supportGuideStep3Title => '15분 임시 예약 일정 잠금 보호';

  @override
  String get supportGuideStep3Desc =>
      '예약 생성 즉시 시스템이 15분간 숙박 일정을 잠금(결제 대기 상태) 처리하여 다른 고객과의 중복 예약을 안전하게 방지합니다.';

  @override
  String get supportGuideStep4Title => '온라인 결제 완료 및 숙박 확정 안내 수령';

  @override
  String get supportGuideStep4Desc =>
      '임시 홀드 시간 내에 지원 결제 수단(VNPay, MoMo 또는 VietQR)으로 결제를 완료하세요. 여행 탭에서 예약 상태를 확인하고 호스트와 직접 대화할 수 있습니다.';

  @override
  String get supportCancelFlexName => '유연 정책 (Flexible)';

  @override
  String get supportCancelFlexBadge => '체크인 24시간 전 100% 환불';

  @override
  String get supportCancelFlexRule1 => '체크인 최소 24시간 전 취소 시: 결제 총액의 100% 환불.';

  @override
  String get supportCancelFlexRule2 => '체크인 24시간 이내 취소 시: 환불 불가.';

  @override
  String get supportCancelModName => '보통 정책 (Moderate)';

  @override
  String get supportCancelModBadge => '체크인 5일 전 100% 환불';

  @override
  String get supportCancelModRule1 =>
      '체크인 최소 5일(120시간) 전 취소 시: 결제 총액의 100% 환불.';

  @override
  String get supportCancelModRule2 =>
      '체크인 24시간 이상~5일(120시간) 미만 전 취소 시: 결제 총액의 50% 환불.';

  @override
  String get supportCancelModRule3 => '체크인 24시간 이내 취소 시: 환불 불가.';

  @override
  String get supportCancelStrictName => '엄격 정책 (Strict)';

  @override
  String get supportCancelStrictBadge => '체크인 7일 전 50% 환불';

  @override
  String get supportCancelStrictRule1 =>
      '체크인 최소 7일(168시간) 전 취소 시: 결제 총액의 50% 환불.';

  @override
  String get supportCancelStrictRule2 => '체크인 7일(168시간) 이내 취소 시: 환불 불가.';

  @override
  String get supportComplaintStep1Title => '예약 번호 또는 숙소 번호와 함께 신고 접수';

  @override
  String get supportComplaintStep1Desc =>
      '로그인 후 예약 번호(Booking ID) 또는 숙소 번호(Listing ID)와 함께 확인이 필요한 실제 내용을 상세히 기재하여 온라인으로 제출하세요.';

  @override
  String get supportComplaintStep2Title => '숙박 이력 및 결제 내역 교차 검증';

  @override
  String get supportComplaintStep2Desc =>
      '신뢰 및 안전(Trust & Safety) 전담팀이 예약 상태 기록, 앱 내 메시지 대화 내역 및 결제 증빙 자료를 독립적으로 검토합니다.';

  @override
  String get supportComplaintStep3Title => '처리 결과 안내 및 고객 권익 보호';

  @override
  String get supportComplaintStep3Desc =>
      '처리 결과는 신고 상태(해결됨 / 사유 포함 반려)에 투명하게 반영되며, 호스트 귀책 확인 시 환불 절차가 즉시 진행됩니다.';

  @override
  String get supportFaqCatAll => '전체';

  @override
  String get supportFaqCatBooking => '예약 및 일정';

  @override
  String get supportFaqCatPayment => '결제 및 환불';

  @override
  String get supportFaqCatAmenities => '편의시설 및 이용 수칙';

  @override
  String get supportFaqCatHost => '호스트 파트너';

  @override
  String get supportFaq1Q => '숙박 일수(박수)는 어떻게 계산되나요?';

  @override
  String get supportFaq1A =>
      '베트남 표준시(Asia/Ho_Chi_Minh) 기준 반개구간 [체크인, 체크아웃) 모델이 적용됩니다. 예를 들어 15일 체크인~17일 체크아웃 선택 시 15일과 16일 총 2박으로 계산됩니다.';

  @override
  String get supportFaq2Q => '예약 시 왜 15분 임시 홀드 시간이 적용되나요?';

  @override
  String get supportFaq2A =>
      '각 독채 빌라는 단일 숙소이므로 결제 진행 중 중복 예약을 막기 위해 15분간 일정을 잠금 보호합니다. 15분 내 미결제 시 잠금은 자동 해제됩니다.';

  @override
  String get supportFaq3Q => '주말 요금과 인원 추가 요금은 어떻게 산정되나요?';

  @override
  String get supportFaq3A =>
      '평일 및 주말 박별 요금, 청소비, 기준 인원 초과 요금은 검수된 각 빌라의 공식 설정에서 직접 불러오며 예약 확정 전에 투명하게 표시됩니다.';

  @override
  String get supportFaq4Q => '어떤 결제 수단을 사용할 수 있나요?';

  @override
  String get supportFaq4A =>
      'VNPay 결제창, MoMo 전자지갑 및 VietQR 계좌이체를 지원합니다. 모든 결제는 자동 대사 처리되어 여행 탭에 실시간 반영됩니다.';

  @override
  String get supportFaq5Q => '정책 내 취소 또는 호스트 거절 시 환불은 어떻게 진행되나요?';

  @override
  String get supportFaq5A =>
      '환불 가능 기간 내 취소하거나 호스트가 취소·거절(100% 환불)한 경우 시스템이 자동으로 환불 요청을 생성하며 재무팀 대사 후 원결제 수단으로 환급됩니다.';

  @override
  String get supportFaq6Q => '예약 전에 호스트와 직접 문의할 수 있나요?';

  @override
  String get supportFaq6A =>
      '네, 가능합니다. 빌라 상세 화면에서 호스트에게 메시지 보내기를 누르거나 문의하기 페이지의 공식 Zalo OA 및 핫라인을 통해 수영장, 바비큐, 단체 주차 여부를 확인하실 수 있습니다.';

  @override
  String get supportFaq7Q => '더 팜 빌라에 숙소를 호스트로 등록하려면 어떻게 하나요?';

  @override
  String get supportFaq7A =>
      '상단 메뉴에서 호스트 되기를 선택하여 본인 인증(KYC) 및 숙소 정보를 제출하세요. 관리자 승인 후 30일 달력 관리와 Google 시트 양방향 동기화를 이용할 수 있습니다.';

  @override
  String get supportZoneBaiSauName => '바이사우 구역 (투이반 – 티삭)';

  @override
  String get supportZoneBaiSauHint => '길고 활기찬 해변, 도보 해수욕 이동에 편리';

  @override
  String get supportZoneBaiSauHighlight =>
      '투이반, 티삭, 보티사우 거리 인근에 가족 및 단체 여행객을 위한 대형 전용 수영장 빌라가 밀집해 있습니다.';

  @override
  String get supportZoneBaiTruocName => '바이트르억 구역 (쩐푸 – 꽝쭝)';

  @override
  String get supportZoneBaiTruocHint => '정면 바다 일몰 전망 및 시내 미식 중심지 인접';

  @override
  String get supportZoneBaiTruocHighlight =>
      '쩐푸 해안도로를 따라 고요한 오션뷰와 탁 트인 석양을 감상할 수 있으며 바이트르억 공원 이동이 편리합니다.';

  @override
  String get supportZoneChiLinhName => '찌린 해안 휴양 구역';

  @override
  String get supportZoneChiLinhHint => '독립된 보안 휴양 단지 및 한적한 해변';

  @override
  String get supportZoneChiLinhHighlight =>
      '푸른 녹지와 조용한 환경, 쾌적한 해변을 선호하는 다세대 가족 여행 및 기업 워크숍 단체에 적합합니다.';

  @override
  String get supportZoneLongCungName => '롱꿍 – 투이띠엔 구역';

  @override
  String get supportZoneLongCungHint => '대규모 단체를 위한 해변 인접 빌라 단지';

  @override
  String get supportZoneLongCungHighlight =>
      '롱꿍 해변 가까이 넓은 정원, 전용 수영장, 야외 바비큐 파티 공간을 갖춘 대형 독채 빌라들이 특징입니다.';

  @override
  String get supportAddonPoolTitle => '빌라 내 전용 수영장';

  @override
  String get supportAddonPoolDesc =>
      '빌라 단지 내 독립된 전용 수영장에서 가족 및 일행과 여유로운 휴식을 즐기실 수 있습니다.';

  @override
  String get supportAddonPoolNote => '각 빌라의 공개된 상세 사양에 따라 기본 제공됩니다.';

  @override
  String get supportAddonBbqTitle => '정원 야외 바비큐 그릴 구역';

  @override
  String get supportAddonBbqDesc =>
      '야외 그릴 설비, 정원 테이블 및 기본 조리 도구가 마련되어 따뜻한 저녁 바비큐 파티가 가능합니다.';

  @override
  String get supportAddonBbqNote => '숯 준비 또는 뒷정리 지원 여부는 사전 메시지로 호스트와 확인해 주세요.';

  @override
  String get supportAddonKitchenTitle => '가족형 취사 주방 완비';

  @override
  String get supportAddonKitchenDesc =>
      '냉장고, 가스·인덕션 레인지, 냄비·프라이팬, 식기류가 구비되어 현지 수산시장에서 구매한 해산물을 직접 조리할 수 있습니다.';

  @override
  String get supportAddonKitchenNote => '숙소별 이용 수칙에 따라 주방 청결 유지를 부탁드립니다.';

  @override
  String get supportAddonKaraokeTitle => '엔터테인먼트 룸 및 노래방 음향';

  @override
  String get supportAddonKaraokeDesc =>
      '노래방 편의시설 태그가 등록된 빌라에서 음향 시스템 또는 단체 공용 라운지를 이용하실 수 있습니다.';

  @override
  String get supportAddonKaraokeNote => '주거지역 정숙 시간 규정(22:00 이전 이용)을 준수해 주세요.';

  @override
  String get supportAddonParkingTitle => '승용차 및 단체 차량 안전 주차';

  @override
  String get supportAddonParkingDesc =>
      '빌라 내 마당 또는 넓은 단지 도로를 통해 개인 승용차와 7~29인승 투어 차량 주차가 편리합니다.';

  @override
  String get supportAddonParkingNote => '차량 수용 대수는 각 빌라 상세 설명에서 미리 확인해 주세요.';

  @override
  String get supportAddonBeachTitle => '해수욕장 인접 위치';

  @override
  String get supportAddonBeachDesc =>
      '해변까지의 실제 거리가 숙소 카드에 미터(m) 단위로 명확히 안내됩니다.';

  @override
  String get supportAddonBeachNote => '아래 버튼 한 번으로 해변 인접 빌라만 빠르게 모아볼 수 있습니다.';

  @override
  String get supportExploreZoneAction => '이 구역 빌라 보기';

  @override
  String supportServiceNotePrefix(String note) {
    return '안내: $note';
  }

  @override
  String get supportFilterByAmenityAction => '이 편의시설이 있는 빌라 필터링';

  @override
  String get supportFaqSearchHint => '키워드로 질문 검색 (예: 홀드, 환불)...';

  @override
  String get supportFaqClearSearchTooltip => '검색어 지우기';

  @override
  String get supportFaqEmptyResult =>
      '현재 검색어와 일치하는 질문이 없습니다. 다른 키워드를 입력하거나 상담팀에 직접 문의해 주세요.';

  @override
  String get supportBookingGuideEyebrow => '예약 지원 안내';

  @override
  String get supportBookingGuideTitle => '독채 빌라 예약 가이드';

  @override
  String get supportBookingGuideSubtitle =>
      '중복 예약을 막는 15분 일정 잠금과 실시간 온라인 결제 확인을 갖춘 투명한 4단계 예약 절차입니다.';

  @override
  String get supportBookingGuideNoteTitle => '체크인 및 체크아웃 유의사항';

  @override
  String get supportBookingGuideNoteBody =>
      '모든 예약은 베트남 시간 기준 [체크인, 체크아웃) 숙박 모델로 계산됩니다. 출발 전 메시지 탭에서 호스트와 도착 시간 및 차량 번호를 미리 조율하실 수 있습니다.';

  @override
  String get supportBookingGuideCtaTitle => '우리 일행에게 꼭 맞는 빌라를 찾아볼까요?';

  @override
  String get supportBookingGuideCtaDesc =>
      '붕따우의 실시간 예약 가능 빌라와 박별 공시 요금을 지금 바로 확인해 보세요.';

  @override
  String get supportBookingGuidePrimaryAction => '지금 빌라 찾기';

  @override
  String get supportBookingGuideSecondaryAction => '상담 문의하기';

  @override
  String get supportCancelEyebrow => '숙박 및 환불 정책';

  @override
  String get supportCancelTitle => '예약 취소 및 환불 정책';

  @override
  String get supportCancelSubtitle =>
      '환불 비율은 각 빌라에 명시된 정책 등급과 체크인까지 남은 시간을 기준으로 시스템에서 자동 산정됩니다.';

  @override
  String get supportCancelHostProtectTitle => '호스트 취소 시 게스트 100% 환불 보호';

  @override
  String get supportCancelHostProtectBody =>
      '결제 완료된 예약을 호스트가 거절하거나 취소할 경우 정책 등급과 무관하게 결제 금액 100% 환불 요청이 자동 생성됩니다. 미결제 홀드 건은 15분 후 수수료 없이 자동 취소됩니다.';

  @override
  String get supportCancelCtaTitle => '예약 상태 확인 또는 취소 요청';

  @override
  String get supportCancelCtaDesc =>
      '여행 탭에서 내 예약에 적용된 세부 취소 정책을 확인하거나 고객 지원팀에 문의하세요.';

  @override
  String get supportCancelPrimaryAction => '내 여행 보기';

  @override
  String get supportCancelSecondaryAction => '자주 묻는 질문';

  @override
  String get supportComplaintsEyebrow => '안전 및 투명성';

  @override
  String get supportComplaintsTitle => '불만 접수, 신고 및 서비스 의견';

  @override
  String get supportComplaintsSubtitle =>
      '빌라 품질, 숙소 정보 불일치 또는 응대 서비스에 대한 모든 신고는 기록되며 독립적으로 검증됩니다.';

  @override
  String get supportComplaintsCtaTitle => '숙박 중 긴급 지원이 필요하신가요?';

  @override
  String get supportComplaintsCtaDesc =>
      '붕따우 오피스 공식 핫라인 또는 Zalo OA(08:00~22:00)로 연락 주시면 신속히 도와드립니다.';

  @override
  String get supportComplaintsPrimaryAction => '문의하기 페이지 열기';

  @override
  String get supportComplaintsSecondaryAction => '호스트 메시지';

  @override
  String get supportFaqEyebrow => '도움말 센터';

  @override
  String get supportFaqPageTitle => '자주 묻는 질문 (FAQ)';

  @override
  String get supportFaqSubtitle =>
      '숙박 일수 산정, 15분 홀드, 결제 수단, 환불 절차 및 호스트 파트너 등록에 대한 주요 답변을 확인하세요.';

  @override
  String get supportFaqCtaTitle => '원하시는 답변을 찾지 못하셨나요?';

  @override
  String get supportFaqCtaDesc =>
      '붕따우 시 티삭 거리 28번지 상담팀이 일행 일정에 맞춰 상세히 안내해 드립니다.';

  @override
  String get supportFaqPrimaryAction => '온라인 상담 문의';

  @override
  String get supportFaqSecondaryAction => '예약 가이드 보기';

  @override
  String get supportAboutEyebrow => '더 팜 빌라 소개';

  @override
  String get supportAboutTitle => '붕따우 검증된 독채 휴양 빌라 예약 플랫폼';

  @override
  String get supportAboutSubtitle =>
      '붕따우 시 전역에서 현장 검수와 호스트 본인 인증(KYC)을 거친 독채 휴양 빌라를 여행객과 직접 연결합니다.';

  @override
  String get supportAboutPillar1Title => '검수된 숙소 및 KYC 인증 호스트';

  @override
  String get supportAboutPillar1Body =>
      '모든 호스트 파트너는 신원 인증과 실제 숙소 사진·정보 검수를 통과한 후에만 예약을 오픈할 수 있습니다.';

  @override
  String get supportAboutPillar2Title => '중복 예약 방지 트랜잭션 일정 잠금';

  @override
  String get supportAboutPillar2Body =>
      '예약 생성 즉시 트랜잭션 단위로 날짜를 잠금 처리하여 결제 시간 동안 일행의 일정을 안전하게 보호합니다.';

  @override
  String get supportAboutPillar3Title => '박별 공시 요금의 투명한 공개';

  @override
  String get supportAboutPillar3Body =>
      '평일·주말 요금, 청소비, 인원 추가 요금을 결제 전에 서버 검증 데이터 그대로 투명하게 안내합니다.';

  @override
  String get supportAboutCtaTitle => '더 팜 빌라와 함께하는 여행 및 파트너십';

  @override
  String get supportAboutCtaDesc =>
      '예약 가능한 빌라를 둘러보거나 호스트 파트너로 등록하여 일정과 정산을 투명하게 관리해 보세요.';

  @override
  String get supportAboutPrimaryAction => '숙소 둘러보기';

  @override
  String get supportAboutSecondaryAction => '호스트 되기';

  @override
  String get supportExploreVtEyebrow => '붕따우 해안 휴양 구역 안내';

  @override
  String get supportExploreVtTitle => '해안 구역별로 살펴보는 붕따우';

  @override
  String get supportExploreVtSubtitle =>
      '붕따우의 각 해안 구역은 저마다 다른 매력을 지니고 있습니다. 여행 일정에 맞는 구역을 선택해 실제 숙소를 바로 확인하세요.';

  @override
  String get supportExploreVtCtaTitle => '현지 맛집 코스와 해변 여행 팁 함께 보기';

  @override
  String get supportExploreVtCtaDesc =>
      '붕따우 현지 여행 가이드 아티클을 참고하여 더욱 알찬 휴가 일정을 계획해 보세요.';

  @override
  String get supportExploreVtPrimaryAction => '여행 가이드 읽기';

  @override
  String get supportExploreVtSecondaryAction => '검색 지도 열기';

  @override
  String get supportAddonEyebrow => '편의시설 및 숙박 경험';

  @override
  String get supportAddonTitle => '빌라 주요 편의시설 및 부대 서비스';

  @override
  String get supportAddonSubtitle =>
      '독채 빌라의 핵심 편의시설 구성과 바비큐 파티 준비, 단체 차량 주차 등을 호스트와 사전 조율하는 방법을 안내합니다.';

  @override
  String get supportAddonNoteTitle => '체크인 전 부대 서비스 및 사전 준비 요청 방법';

  @override
  String get supportAddonNoteBody =>
      '각 빌라마다 제공 편의시설과 인원 규정이 투명하게 공시되어 있습니다. 원하는 숙소 상세 화면에서 호스트에게 메시지를 보내 세부 요청 사항을 확인하세요.';

  @override
  String get supportAddonCtaTitle => '전용 수영장과 바비큐 정원을 모두 갖춘 빌라를 찾으시나요?';

  @override
  String get supportAddonCtaDesc =>
      '검색 페이지의 상세 필터를 활용해 일행이 원하는 편의시설을 정확히 선택해 보세요.';

  @override
  String get supportAddonPrimaryAction => '숙소 필터 열기';

  @override
  String get supportAddonSecondaryAction => '단체 상담 문의';

  @override
  String get supportMemberEyebrow => '회원 전용 혜택';

  @override
  String get supportMemberTitle => '회원 혜택 및 예약 할인 쿠폰';

  @override
  String get supportMemberSubtitle =>
      '무료 회원 가입으로 빌라 예약 시 할인 쿠폰을 즉시 적용하고 위시리스트 동기화 및 여행 내역을 편리하게 관리하세요.';

  @override
  String get supportMemberNote1Title => '예약 시 할인 쿠폰(Coupon) 즉시 적용';

  @override
  String get supportMemberNote1Body =>
      '로그인한 회원은 빌라 상세 페이지에서 정률(%) 또는 정액 할인 쿠폰을 적용할 수 있으며 유효기간, 최소 주문 금액, 사용 가능 횟수가 자동 검증됩니다.';

  @override
  String get supportMemberNote2Title => '위시리스트 동기화 및 실시간 여행 상태 추적';

  @override
  String get supportMemberNote2Body =>
      '마음에 드는 빌라를 기기 간 동기화하여 저장하고 실시간 예약 알림 수신 및 호스트와의 1:1 대화를 이용하세요.';

  @override
  String get supportMemberCtaTitle => '다가오는 붕따우 휴가에 회원 혜택 적용하기';

  @override
  String get supportMemberCtaDesc =>
      '마음에 드는 빌라를 선택해 박별 요금을 확인한 뒤 예약 확인 단계에서 할인 코드를 입력해 보세요.';

  @override
  String get supportMemberPrimaryAction => '예약 가능 빌라 보기';

  @override
  String get supportMemberSecondaryAction => '위시리스트 보기';

  @override
  String get supportReportTargetBooking => '예약 건 (예약 번호)';

  @override
  String get supportReportTargetListing => '숙소 / 빌라 (숙소 번호)';

  @override
  String get supportReportTargetReview => '숙박 리뷰 (리뷰 번호)';

  @override
  String get supportReportTargetUser => '사용자 계정 (회원 번호)';

  @override
  String get supportReportSuccessMessage =>
      '신고가 정상적으로 접수되었습니다. 신뢰 및 안전 전담팀에서 검토 후 신속히 안내해 드리겠습니다.';

  @override
  String get supportReportErrorFallback =>
      '현재 신고를 전송할 수 없습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get supportReportStatusResolved => '해결 완료';

  @override
  String get supportReportStatusRejected => '반려됨';

  @override
  String get supportReportStatusOpen => '검토 중';

  @override
  String get supportReportGuestCardTitle => '온라인 신고 및 불만 접수';

  @override
  String get supportReportGuestCardBody =>
      '정확한 예약 대사를 위해 온라인 신고 전 로그인해 주시거나 문의하기 페이지를 통해 직접 연락해 주세요.';

  @override
  String get supportReportLoginAction => '로그인하여 신고하기';

  @override
  String get supportReportDirectContactAction => '직접 문의 채널 열기';

  @override
  String get supportReportAuthCardTitle => '검수·안전팀에 신고 및 의견 보내기';

  @override
  String get supportReportAuthCardSubtitle =>
      '제출된 내용은 관리자가 투명하게 확인하고 답변할 수 있도록 시스템에 직접 기록됩니다.';

  @override
  String get supportReportTargetGroupLabel => '신고 대상 유형';

  @override
  String get supportReportTargetIdLabel => '숫자 식별 번호 (예: 예약 102 또는 빌라 15)';

  @override
  String get supportReportTargetIdError => '유효한 양의 정수 번호를 입력해 주세요';

  @override
  String get supportReportReasonLabel => '신고 및 의견 제목';

  @override
  String get supportReportReasonEmptyError => '신고 제목을 입력해 주세요';

  @override
  String get supportReportReasonMaxError => '최대 255자까지 입력 가능합니다';

  @override
  String get supportReportDescLabel => '상세 내용 설명 (선택 사항)';

  @override
  String get supportReportSubmittingLabel => '신고 전송 중...';

  @override
  String get supportReportSubmitAction => '신고 제출하기';

  @override
  String supportReportRecentTitle(int count) {
    return '최근 접수 내역 ($count건)';
  }

  @override
  String get supportCouponEmptyError => '확인할 프로모션 코드를 입력해 주세요.';

  @override
  String supportCouponValidStatus(String code, String discount) {
    return '코드 $code 사용 가능 — 예상 주문 금액에서 $discount 할인됩니다.';
  }

  @override
  String get supportCouponInvalidFallback => '조건을 충족하지 않거나 만료된 쿠폰 코드입니다.';

  @override
  String get supportCouponCheckError => '현재 쿠폰 코드를 확인할 수 없습니다.';

  @override
  String get supportCouponCardTitle => '할인 쿠폰(Coupon) 유효성 조회';

  @override
  String get supportCouponGuestHint =>
      '회원 계정으로 로그인하여 예상 숙박 금액 기준 쿠폰 적용 가능 여부를 조회하거나 예약 시 바로 적용해 보세요.';

  @override
  String get supportCouponAuthHint =>
      '보유하신 쿠폰 코드와 예상 숙박 금액(VND)을 입력하여 실시간 적용 조건을 확인하세요.';

  @override
  String get supportCouponLoginAction => '회원 로그인';

  @override
  String get supportCouponRegisterAction => '무료 계정 만들기';

  @override
  String get supportCouponCodeInputLabel => '쿠폰 코드 (예: PALM2026)';

  @override
  String get supportCouponAmountInputLabel => '예상 예약 금액 (VND)';

  @override
  String get supportCouponCheckingLabel => '확인 중...';

  @override
  String get supportCouponCheckAction => '쿠폰 코드 확인';
}
