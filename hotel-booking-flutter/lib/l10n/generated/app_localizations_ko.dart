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
  String get searchPlaceholder => '검색을 시작하세요...';

  @override
  String get navDiscover => '탐색';

  @override
  String get navZalo => 'Zalo';

  @override
  String get navHotline => '핫라인';

  @override
  String get navFavorites => '위시리스트';

  @override
  String get navSettings => '설정';

  @override
  String bedroomsCount(int count) {
    return '침실 $count개';
  }

  @override
  String bedsCount(int count) {
    return '침대 $count개';
  }

  @override
  String guestsCapacity(int count) {
    return '최대 $count명';
  }

  @override
  String bathroomsCount(int count) {
    return '욕실 $count개';
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
  String saturdayPrice(String price) {
    return '토요일: $price';
  }

  @override
  String get contactForPrice => '가격 문의';

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
  String get ctaViewDetail => '상세 보기';

  @override
  String get ctaCopyLink => '링크 복사';

  @override
  String get ctaCopied => '링크가 클립보드에 복사되었습니다';

  @override
  String get ctaRetry => '다시 시도';

  @override
  String get ctaResetFilter => '필터 초기화';

  @override
  String get loadingText => '빌라 정보를 불러오는 중...';

  @override
  String get emptyList => '일치하는 빌라가 없습니다';

  @override
  String get emptyListDesc => '검색 조건이나 일정을 변경해 보세요.';

  @override
  String get errorOccurred => '오류가 발생했습니다';

  @override
  String get errorTryAgain => '네트워크 연결을 확인한 후 다시 시도해 주세요.';

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
  String get faqTitle => '자주 묻는 질문';

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
}
