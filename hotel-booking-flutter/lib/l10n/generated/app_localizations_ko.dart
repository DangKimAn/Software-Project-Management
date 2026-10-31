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
  String get aiSearchTitle => 'AI 스마트 검색';

  @override
  String get aiSearchPlaceholder =>
      '원하는 숙소를 설명해 주세요 (예: 바이사우 해변 근처 15인용 해수풀 및 바비큐 빌라)...';

  @override
  String get aiSearchAction => 'AI 검색';

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
}
