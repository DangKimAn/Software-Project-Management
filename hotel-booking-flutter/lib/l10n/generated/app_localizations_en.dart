// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Minh Thanh Villa';

  @override
  String get appTagline => 'Luxury Vacation Villas in Vung Tau';

  @override
  String get searchPlaceholder => 'Start your search...';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navZalo => 'Zalo';

  @override
  String get navHotline => 'Hotline';

  @override
  String get navFavorites => 'Wishlist';

  @override
  String get navSettings => 'Settings';

  @override
  String bedroomsCount(int count) {
    return '$count bedrooms';
  }

  @override
  String bedsCount(int count) {
    return '$count beds';
  }

  @override
  String guestsCapacity(int count) {
    return '$count guests';
  }

  @override
  String bathroomsCount(int count) {
    return '$count baths';
  }

  @override
  String beachDistance(int distance) {
    return '${distance}m to beach';
  }

  @override
  String priceFrom(String price) {
    return 'From $price / night';
  }

  @override
  String saturdayPrice(String price) {
    return 'Sat: $price';
  }

  @override
  String get contactForPrice => 'Contact for pricing';

  @override
  String get badgeFeatured => 'Featured';

  @override
  String get badgeNew => 'New';

  @override
  String get badgeNearBeach => 'Near Beach';

  @override
  String get badgeSaltwater => 'Saltwater Pool';

  @override
  String get badgeGroup => 'Large Group';

  @override
  String get ctaContactZalo => 'Chat on Zalo';

  @override
  String get ctaCallHotline => 'Call Hotline';

  @override
  String get ctaBookNow => 'Inquire Booking';

  @override
  String get ctaViewDetail => 'View Details';

  @override
  String get ctaCopyLink => 'Copy Link';

  @override
  String get ctaCopied => 'Link copied to clipboard';

  @override
  String get ctaRetry => 'Retry';

  @override
  String get ctaResetFilter => 'Reset Filters';

  @override
  String get loadingText => 'Loading villas...';

  @override
  String get emptyList => 'No villas match your search';

  @override
  String get emptyListDesc => 'Try adjusting your filters or date selection.';

  @override
  String get errorOccurred => 'Something went wrong';

  @override
  String get errorTryAgain =>
      'Please check your network connection and try again.';

  @override
  String get dateBooked => 'This date is booked';

  @override
  String get checkInDate => 'Check-in';

  @override
  String get checkOutDate => 'Check-out';

  @override
  String get guestCount => 'Guests';

  @override
  String get priceBreakdown => 'Nightly Price Breakdown';

  @override
  String get faqTitle => 'Frequently Asked Questions';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsEnvironment => 'Environment';

  @override
  String get settingsVersion => 'Version';

  @override
  String get favoritesEmpty => 'No saved villas yet';

  @override
  String get favoritesEmptyDesc =>
      'Tap the heart icon on any villa card to save it to your wishlist.';
}
