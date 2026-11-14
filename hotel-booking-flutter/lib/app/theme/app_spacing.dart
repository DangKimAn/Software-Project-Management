/// Hệ thống thang khoảng cách (Spacing Scale) theo bội số 4 logical pixel cho toàn bộ bố cục giao diện.
///
/// Cung cấp cả tên ngữ nghĩa (`xxs`..`xxxl`), bí danh số học (`s4`..`s40`) và lề chuẩn cho màn hình / thẻ.
abstract final class AppSpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;

  // Numeric scale aliases
  static const double s4 = xxs;
  static const double s8 = xs;
  static const double s12 = sm;
  static const double s16 = md;
  static const double s20 = lg;
  static const double s24 = xl;
  static const double s32 = xxl;
  static const double s40 = xxxl;

  // Screen horizontal margins
  static const double screenMargin = 16.0;
  static const double cardPadding = 16.0;
}
