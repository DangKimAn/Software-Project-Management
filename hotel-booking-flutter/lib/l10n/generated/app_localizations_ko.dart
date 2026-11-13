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
  String get calendarPrevMonth => '이전 달';

  @override
  String get calendarNextMonth => '다음 달';

  @override
  String calendarDay(int day) {
    return '$day일';
  }

  @override
  String calendarDayBooked(int day) {
    return '$day일 예약 마감';
  }

  @override
  String calendarDayCheckOutOnly(int day) {
    return '$day일 체크아웃만 가능';
  }

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
  String get footerSupport => '고객 지원';

  @override
  String get footerBookingGuide => '예약 안내';

  @override
  String get footerCancellationPolicy => '취소 정책';

  @override
  String get footerFeedback => '문의 및 피드백';

  @override
  String get footerFaq => '자주 묻는 질문 (FAQ)';

  @override
  String get footerDiscover => '붕따우 둘러보기';

  @override
  String get footerAboutUs => '회사 소개';

  @override
  String get footerTravelGuide => '여행 가이드';

  @override
  String get footerAddonServices => '부가 서비스';

  @override
  String get footerMemberOffers => '회원 특별 혜택';

  @override
  String get footerContact => '연락처';

  @override
  String get footerOnlineConsultation => '온라인 상담 문의';

  @override
  String footerHotline(String phone) {
    return '핫라인: $phone';
  }

  @override
  String get footerAddress => '주소: 28 Thi Sach, 붕따우';

  @override
  String footerEmail(String email) {
    return '이메일: $email';
  }

  @override
  String get footerSocial => '소셜 미디어';

  @override
  String get footerCopyright => '© 2026 Villa Vung Tau. 모든 권리 보유.';

  @override
  String get settingsAvatarUpdateTitle => '프로필 사진 업데이트';

  @override
  String get settingsAvatarUpdateHint =>
      '기기에서 JPG, PNG, WebP 또는 GIF 이미지를 선택하세요 (최대 5MB).';

  @override
  String get settingsAvatarPickFromDevice => '기기에서 사진 선택 (최대 5MB)';

  @override
  String get settingsAvatarUploading => '사진 업로드 중...';

  @override
  String settingsAvatarSelected(String fileName, String sizeKb) {
    return '선택됨: $fileName ($sizeKb KB)';
  }

  @override
  String get settingsAvatarPickError => '기기에서 사진을 선택할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get settingsAvatarUpdateSuccess => '프로필 사진이 성공적으로 업데이트되었습니다.';

  @override
  String get settingsChangeAvatarTooltip => '사진 변경';

  @override
  String get settingsEditProfileTooltip => '프로필 수정';

  @override
  String get settingsEditProfileTitle => '개인 프로필 수정';

  @override
  String get settingsAvatarSectionTitle => '프로필 사진';

  @override
  String get settingsAvatarPickFromDeviceShort => '기기에서 선택';

  @override
  String get settingsAvatarUploadingShort => '업로드 중...';

  @override
  String get settingsAvatarPickHint => '기기에서 사진 선택 (최대 5MB)';

  @override
  String settingsAvatarSelectedShort(String fileName) {
    return '선택됨: $fileName';
  }

  @override
  String get settingsFullNameLabel => '성명 *';

  @override
  String get settingsFullNameHint => '성명을 입력하세요';

  @override
  String get settingsPhoneLabel => '전화번호';

  @override
  String get settingsPhoneHint => '0912345678 또는 +84912345678';

  @override
  String get settingsLocationLabel => '거주지';

  @override
  String get settingsLocationHint => '예: 붕따우, 베트남';

  @override
  String get settingsDreamDestinationLabel => '가고 싶은 여행지';

  @override
  String get settingsDreamDestinationHint => '선호하는 여행지를 입력하세요';

  @override
  String get settingsJobLabel => '직업 / 직종';

  @override
  String get settingsJobHint => '현재 직업을 입력하세요';

  @override
  String get settingsSchoolLabel => '출신 학교';

  @override
  String get settingsSchoolHint => '다녔던 학교를 입력하세요';

  @override
  String get settingsLanguagesLabel => '구사 언어';

  @override
  String get settingsLanguagesHint => '한국어, 영어 (쉼표로 구분)';

  @override
  String get settingsBioLabel => '자기소개';

  @override
  String get settingsBioHint => '간단한 소개를 입력하세요...';

  @override
  String get settingsSaving => '저장 중...';

  @override
  String get settingsProfileUpdateSuccess => '프로필이 성공적으로 업데이트되었습니다.';

  @override
  String get settingsUnsavedDraftBanner => '저장되지 않은 프로필 수정 내용이 있습니다.';

  @override
  String get settingsResumeEditing => '수정 계속하기';

  @override
  String get settingsConfirmPhoneTitle => '전화번호 변경 확인';

  @override
  String settingsConfirmPhoneRemove(String oldPhone) {
    return '저장된 연락처 ($oldPhone)를 삭제하려고 합니다. 계속하시겠습니까?';
  }

  @override
  String settingsConfirmPhoneChange(String oldPhone, String newPhone) {
    return '연락처를 $oldPhone에서 $newPhone(으)로 변경하려고 합니다. 이 변경사항을 저장하시겠습니까?';
  }

  @override
  String get settingsConfirmPhoneReview => '다시 확인';

  @override
  String get settingsConfirmPhoneSave => '저장 확인';

  @override
  String get settingsConfirmLogoutTitle => '로그아웃 확인';

  @override
  String get settingsConfirmLogoutDraft =>
      '저장되지 않은 프로필 수정 내용이 있습니다. 로그아웃하면 이번 세션의 임시 데이터가 삭제됩니다. 로그아웃하시겠습니까?';

  @override
  String get settingsConfirmLogout => '이 계정에서 로그아웃하시겠습니까?';

  @override
  String get settingsRoleAdmin => '관리자 (Admin)';

  @override
  String get settingsRoleHost => '호스트 (Host)';

  @override
  String get settingsRoleHostPending => '호스트 신청 승인 대기 중';

  @override
  String get settingsRoleGuest => '게스트';

  @override
  String get settingsLoadingAccount => '계정 정보를 불러오는 중...';

  @override
  String get settingsNotLoggedIn => '로그인되지 않음';

  @override
  String get settingsLoginPrompt => '여행 일정, 메시지 및 위시리스트 동기화를 위해 로그인하세요';

  @override
  String get settingsSignInSignUp => '로그인 / 회원가입';

  @override
  String get settingsReLogin => '다시 로그인';

  @override
  String get settingsContactSupportCenter => '고객센터 및 지원';

  @override
  String get settingsCallHotline => '고객센터 상담 전화';

  @override
  String get settingsZaloSupport => 'Zalo OA로 문의하기';

  @override
  String get settingsZaloInquiryDefaultMessage =>
      '안녕하세요 The Palm, 앱 이용 관련 문의드립니다.';

  @override
  String get settingsManageProperties => '숙소 관리';

  @override
  String get settingsMyTrips => '내 여행';

  @override
  String get settingsMyFavorites => '위시리스트';

  @override
  String get settingsMessagesWithHost => '호스트와의 메시지';

  @override
  String get settingsStatusOfflineTitle => '기기가 오프라인 상태입니다';

  @override
  String get settingsStatusUnauthorizedTitle => '세션이 만료되었거나 접근이 거부되었습니다';

  @override
  String get settingsStatusServerErrorTitle => '서버 데이터를 동기화할 수 없습니다';

  @override
  String get settingsStatusOfflineMessage =>
      '서버에 연결할 수 없습니다. 네트워크 연결을 확인하고 다시 시도해 주세요.';

  @override
  String get settingsStatusUnauthorizedMessage =>
      '유효하지 않은 세션이거나 접근 권한이 없습니다 (401/403).';

  @override
  String get settingsStatusServerErrorMessage =>
      '서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String villaDetailViewAllPhotos(int count) {
    return '$count개 사진 모두 보기';
  }

  @override
  String get villaDetailShareCopied => '링크가 클립보드에 복사되었습니다';

  @override
  String get villaDetailAboutTitle => '숙소 소개';

  @override
  String get villaDetailTranslatedBadge => '한국어로 번역됨';

  @override
  String get villaDetailShowOriginal => '원문 보기';

  @override
  String get villaDetailShowTranslation => '번역 보기';

  @override
  String get villaDetailOriginalBadge => '원문 (베트남어)';

  @override
  String get villaDetailAmenitiesTitle => '편의시설';

  @override
  String get villaDetailBookingCalendarTitle => '숙박 일정 선택 및 예약';

  @override
  String villaDetailStayNightsRange(int min, int max) {
    return '최소 $min박 • 최대 $max박';
  }

  @override
  String villaDetailGuestCapacityInfo(int included, int max) {
    return '기준 $included명 · 최대 $max명';
  }

  @override
  String villaDetailGuestCapacityMax(int max) {
    return '최대 $max명';
  }

  @override
  String get villaDetailPromoCodeHint => '할인 코드';

  @override
  String get villaDetailPromoApply => '적용';

  @override
  String get villaDetailPromoChecking => '확인 중...';

  @override
  String get villaDetailSpecialRequestsHint => '호스트에게 남길 메모 (선택사항)';

  @override
  String villaDetailRoomSubtotal(int nights) {
    return '숙박 요금 ($nights박)';
  }

  @override
  String villaDetailWeekendNights(int count) {
    return ', $count박 주말';
  }

  @override
  String get villaDetailExtraGuestFee => '기준 인원 초과 요금';

  @override
  String get villaDetailCleaningFee => '청소비';

  @override
  String get villaDetailServiceFee => '서비스 수수료';

  @override
  String villaDetailDiscountLabel(String code) {
    return '할인 ($code)';
  }

  @override
  String get villaDetailEstimatedTotal => '총 예상 결제 금액';

  @override
  String get villaDetailPoliciesTitle => '숙소 이용규칙 및 환불 정책';

  @override
  String villaDetailCheckInTime(String from, String until) {
    return '체크인: $from – $until';
  }

  @override
  String villaDetailCheckOutTime(String time) {
    return '체크아웃: $time 이전';
  }

  @override
  String villaDetailQuietHours(String hours) {
    return '정숙 시간: $hours';
  }

  @override
  String get villaDetailPetsAllowed => '반려동물 동반 가능';

  @override
  String get villaDetailPetsNotAllowed => '반려동물 동반 불가';

  @override
  String get villaDetailPolicyFlexible => '유연 — 체크인 24시간 전까지 100% 환불';

  @override
  String get villaDetailPolicyModerate => '보통 — 체크인 5일 전까지 100% 환불';

  @override
  String get villaDetailPolicyStrict => '엄격 — 체크인 7일 전까지 50% 환불';

  @override
  String get villaDetailSimilarTitle => '주변 유사 숙소 추천';

  @override
  String get villaDetailMessageHostTooltip => '호스트에게 메시지 보내기';

  @override
  String villaDetailHostPrefix(String name) {
    return '호스트: $name';
  }

  @override
  String villaDetailMinNightsRequired(int min) {
    return '이 숙소는 최소 $min박 이상 예약해야 합니다.';
  }

  @override
  String villaDetailMaxNightsExceeded(int max) {
    return '이 숙소는 1회 예약 시 최대 $max박까지 가능합니다.';
  }

  @override
  String get villaDetailLoginToBook => '예약을 완료하려면 로그인해 주세요.';

  @override
  String get villaDetailBookingSuccess =>
      '예약 요청이 전송되었습니다! 지금 결제하거나 내 여행에서 확인하실 수 있습니다.';

  @override
  String get specSaltwaterPool => '해수 수영장';

  @override
  String specBeachDistance(int meters) {
    return '해변까지 ${meters}m';
  }

  @override
  String get specBeachfront => '해변 바로 앞';

  @override
  String specGuestsCount(int count) {
    return '$count명';
  }

  @override
  String specBedroomsCount(int count) {
    return '$count개 침실';
  }

  @override
  String specBedsCount(int count) {
    return '$count개 침대';
  }

  @override
  String specBathsCount(int count) {
    return '$count개 욕실';
  }

  @override
  String get reviewsTranslate => '후기 번역';

  @override
  String get reviewsShowOriginal => '원문 보기';

  @override
  String get reviewsTranslating => '번역 중...';

  @override
  String get reviewsTranslatedBadge => '자동 번역됨';

  @override
  String get reviewsFilterAll => '전체';

  @override
  String reviewsFilterStar(int star) {
    return '$star성';
  }

  @override
  String get reviewsHostReply => '호스트 답변';

  @override
  String get reviewsLoadMore => '후기 더보기';

  @override
  String get reviewsLoadError => '지금은 후기를 불러올 수 없습니다.';

  @override
  String get reviewsEmpty => '이 숙소에 대한 후기가 아직 없습니다. 첫 번째 후기를 남겨보세요!';

  @override
  String reviewsEmptyRating(int rating) {
    return '이 숙소에 대한 $rating성 후기가 아직 없습니다.';
  }

  @override
  String get chatBackToList => '대화 목록으로 돌아가기';

  @override
  String get chatShowTimestamps => '타임스탬프 표시';

  @override
  String get chatHideTimestamps => '타임스탬프 숨기기';

  @override
  String get chatViewListing => '숙소 보기';

  @override
  String get chatAboutListing => '숙소 문의';

  @override
  String get chatSelectConversationPrompt => '메시지를 보려면 대화를 선택하세요';

  @override
  String get chatInputPlaceholder => '메시지 보내기';

  @override
  String get chatMoreOptions => '더보기';

  @override
  String get chatCamera => '사진 촬영';

  @override
  String get chatGallery => '사진 전송';

  @override
  String get chatGalleryLabel => '사진 갤러리';

  @override
  String get chatVoiceMessage => '음성 메시지';

  @override
  String get chatStopRecording => '녹음 중지';

  @override
  String get chatEmojiTooltip => '이모지';

  @override
  String get chatSendMessage => '메시지 보내기';

  @override
  String get chatSendQuickEmoji => '빠른 이모티콘 전송';

  @override
  String get chatSendQuickEmojiHint => '빠른 이모티콘 전송 (길게 눌러 변경)';

  @override
  String get chatSending => '전송 중...';

  @override
  String get chatSent => '전송됨';

  @override
  String get chatSeen => ' • 읽음';

  @override
  String get chatFailed => '전송 실패';

  @override
  String get chatRetry => '다시 시도';

  @override
  String get chatDeleteFailedMessage => '실패한 메시지 삭제';

  @override
  String get chatEmptyPrompt => '대화를 시작하려면 첫 메시지를 보내보세요.';

  @override
  String get chatLoadMoreHistory => '이전 메시지 더 불러오기';

  @override
  String get chatLoadingHistory => '기록 불러오는 중...';

  @override
  String chatNewMessagesCount(int count) {
    return '새 메시지 ($count)';
  }

  @override
  String chatUserTyping(String user) {
    return '$user님이 입력 중입니다...';
  }

  @override
  String get chatDraftPrefix => '임시 보관';

  @override
  String get chatNoMessagesYet => '메시지가 없습니다.';

  @override
  String get chatSearchConversationsPlaceholder => '대화 검색...';

  @override
  String get chatLoginTitle => '메시지를 보려면 로그인하세요';

  @override
  String get chatLoginDescription => '붕따우 호스트와 객실 예약, 편의시설 및 혜택에 대해 직접 문의하세요.';

  @override
  String get chatLoginAction => '지금 로그인';

  @override
  String get chatEmptyAdminTitle => '지원 대화가 없습니다';

  @override
  String get chatEmptyAdminDesc => '호스트 및 게스트와의 직접 지원 대화가 여기에 표시됩니다.';

  @override
  String get chatEmptyAdminAction => '사용자 관리';

  @override
  String get chatEmptyHostTitle => '대화가 없습니다';

  @override
  String get chatEmptyHostDesc => '게스트가 문의하거나 예약할 때 대화가 여기에 표시됩니다.';

  @override
  String get chatEmptyGuestTitle => '대화가 없습니다';

  @override
  String get chatEmptyGuestDesc => '빌라를 선택하고 \"호스트에게 문의\"를 눌러 대화를 시작하세요.';

  @override
  String get chatEmptyGuestAction => '빌라 둘러보기';

  @override
  String get chatExtensionsAndTemplatesTitle => '확장 기능 및 빠른 템플릿';

  @override
  String get chatSelectEmojiTitle => '이모지 선택';

  @override
  String get chatSelectQuickEmojiTitle => '빠른 전송 이모티콘 선택';

  @override
  String get chatQuickReplyGuest1 => '이 일정에 예약 가능한가요?';

  @override
  String get chatQuickReplyGuest2 => '체크인과 체크아웃 시간은 언제인가요?';

  @override
  String get chatQuickReplyGuest3 => '빌라에 전용 수영장과 바비큐 시설이 있나요?';

  @override
  String get chatQuickReplyGuest4 => '호스트님 감사합니다!';

  @override
  String get chatQuickReplyHost1 => '네, 정보를 잘 받았습니다!';

  @override
  String get chatQuickReplyHost2 => '몇 시에 체크인 예정이신가요?';

  @override
  String get chatQuickReplyHost3 => '더 팜 빌라에 오신 것을 환영합니다! 🌴';

  @override
  String get chatQuickReplyHost4 => '시스템에 빌라 위치를 업데이트했습니다.';

  @override
  String get chatQuickReplyAdmin1 => '안녕하세요, 시스템 관리자가 어떤 지원을 도와드릴까요?';

  @override
  String get chatQuickReplyAdmin2 => '요청이 접수되었으며 현재 검토 중입니다.';

  @override
  String get chatQuickReplyAdmin3 => '프로필/게시물 상태가 업데이트되었습니다.';

  @override
  String get chatQuickReplyAdmin4 => '관리팀에 피드백을 주셔서 감사합니다!';

  @override
  String get chatTplAdminDocsTitle => '서류 보완 요청';

  @override
  String get chatTplAdminDocsSubtitle => '인증 정보 업데이트 요청';

  @override
  String get chatTplAdminDocsContent =>
      '📋 승인을 완료하기 위해 선명한 인증 서류를 확인 및 보완해 주시기 바랍니다.';

  @override
  String get chatTplHostLocationTitle => '숙소 위치 전송';

  @override
  String get chatTplHostLocationSubtitle => '상세 주소 및 오시는 길 안내';

  @override
  String chatTplHostLocationContent(String villaTitle) {
    return '📍 $villaTitle 위치: 붕따우시 투이반 거리 (바이 사우 해변 인근)';
  }

  @override
  String get chatTplGuestInquiryTitle => '예약 가능 일정 및 견적 문의';

  @override
  String get chatTplGuestInquirySubtitle => '객실 현황 및 주말 추가 요금 확인';

  @override
  String get chatTplGuestInquiryContent =>
      '📅 안녕하세요 호스트님, 이번 주말 예약 가능 여부와 단체 총 요금을 문의드립니다.';

  @override
  String get chatTplAdminReviewTitle => '검토 결과 안내';

  @override
  String get chatTplAdminReviewSubtitle => '게시물 또는 계정 상태 업데이트';

  @override
  String get chatTplAdminReviewContent =>
      '✅ 관리자가 시스템에서 귀하의 프로필/게시물 상태를 검토 및 업데이트했습니다.';

  @override
  String get chatTplHostCheckinTitle => '체크인 및 체크아웃 시간';

  @override
  String get chatTplHostCheckinSubtitle => '체크인: 14:00 • 체크아웃: 12:00';

  @override
  String get chatTplHostCheckinContent =>
      '⏰ 체크인 시간: 14:00부터 | 체크아웃 시간: 다음날 12:00 이전입니다.';

  @override
  String get chatTplGuestCheckinTitle => '얼리 체크인 / 레이트 체크아웃 문의';

  @override
  String get chatTplGuestCheckinSubtitle => '체크인/체크아웃 시간 조정 문의';

  @override
  String get chatTplGuestCheckinContent =>
      '⏰ 14:00보다 조금 일찍 도착할 예정인데, 짐 보관이나 얼리 체크인이 가능할까요?';

  @override
  String get chatTplAdminPolicyTitle => '플랫폼 정책 안내';

  @override
  String get chatTplAdminPolicySubtitle => '예약 규정 및 서비스 수수료 안내';

  @override
  String get chatTplAdminPolicyContent =>
      'ℹ️ 시스템의 모든 거래는 더 팜 빌라의 투명한 예약 및 환불 정책에 따라 보호됩니다.';

  @override
  String get chatTplHostHouseRulesTitle => '숙소 이용 수칙 안내';

  @override
  String get chatTplHostHouseRulesSubtitle => '청결 유지, 22:00 이후 정숙';

  @override
  String get chatTplHostHouseRulesContent =>
      '📋 이용 수칙: 공용 자산을 소중히 다뤄주시고 22:00 이후 소음을 자제해 주세요. 즐거운 여행 되세요!';

  @override
  String get chatTplGuestAmenitiesTitle => 'BBQ 및 수영장 편의시설 문의';

  @override
  String get chatTplGuestAmenitiesSubtitle => '그릴, 숯, 튜브 및 주차 공간';

  @override
  String get chatTplGuestAmenitiesContent =>
      '🔥 빌라에 바비큐 그릴, 주방 기구, 전용 수영장 및 마당 주차장이 구비되어 있나요?';

  @override
  String get chatToastUploadingPhoto => 'Cloudflare R2에 사진 업로드 중...';

  @override
  String get chatToastUploadPhotoFailed => '사진 업로드 실패';

  @override
  String get chatToastUploadingVoice => 'Cloudflare R2에 음성 메시지 업로드 중...';

  @override
  String get chatToastUploadVoiceFailed => '음성 메시지 업로드 실패';

  @override
  String get chatToastMicNoAudio =>
      '마이크에서 소리가 감지되지 않았습니다. 권한을 확인하거나 더 크게 말씀해 주세요.';

  @override
  String get chatToastMicAccessError =>
      '마이크에 접근할 수 없습니다. 브라우저/기기에서 마이크 권한을 허용해 주세요.';

  @override
  String get chatErrorNetwork => '네트워크 연결 끊김';

  @override
  String get chatErrorForbidden => '접근 권한 없음';

  @override
  String get chatErrorUnauthorized => '세션 만료됨';

  @override
  String get chatErrorNotFound => '대화를 찾을 수 없습니다';

  @override
  String get chatErrorRateLimit => '요청이 너무 빠릅니다';

  @override
  String get chatErrorServer => '서버 오류';

  @override
  String get chatErrorValidation => '유효하지 않은 데이터';

  @override
  String get chatErrorGeneric => '오류가 발생했습니다';

  @override
  String get hostMsgBackToVilla => '빌라 페이지로 돌아가기';

  @override
  String get hostMsgContactTitle => '호스트에게 문의하기';

  @override
  String hostMsgHostLabel(String name) {
    return '호스트: $name';
  }

  @override
  String get hostMsgDefaultHost => '더 팜 빌라 호스트';

  @override
  String get hostMsgFaqTitle => '호스트 자주 묻는 질문:';

  @override
  String get hostMsgInputLabel => '호스트에게 보낼 메시지 내용 ';

  @override
  String get hostMsgInputPlaceholder => '예약 가능 일정, 편의시설 또는 특별 요청 사항을 입력하세요...';

  @override
  String get hostMsgSendAction => '메시지 보내기 및 채팅방 열기';

  @override
  String get hostMsgSendingAction => '메시지 전송 중...';

  @override
  String get hostMsgQuestion1 => '안녕하세요 호스트님, 이번 주말에 빌라 예약이 가능한가요?';

  @override
  String get hostMsgQuestion2 => '수영장은 담수인가요 해수인가요? 튜브가 준비되어 있나요?';

  @override
  String get hostMsgQuestion3 => '빌라에 바비큐 그릴, 숯 및 조리도구가 구비되어 있나요?';

  @override
  String get hostMsgQuestion4 => '저희 일행이 14:00 이전 얼리 체크인을 지원받을 수 있을까요?';

  @override
  String galleryPhotoCount(int count) {
    return '$count장의 사진';
  }

  @override
  String get galleryViewAllPhotosSemantic => '모든 사진 보기';

  @override
  String gallerySpacePrefix(String type) {
    return '공간: $type';
  }

  @override
  String get spaceBedroom => '침실';

  @override
  String get spaceLivingRoom => '거실';

  @override
  String get spaceKitchen => '주방';

  @override
  String get spaceBathroom => '욕실';

  @override
  String get spacePool => '수영장';

  @override
  String get spaceExterior => '외관';

  @override
  String get spaceView => '전망';

  @override
  String get spaceDining => '식당';

  @override
  String get spaceOther => '기타 공간';
}
