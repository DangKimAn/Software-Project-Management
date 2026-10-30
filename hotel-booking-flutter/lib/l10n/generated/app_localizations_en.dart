// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'The Palm Villa';

  @override
  String get appTagline => 'Luxury Vacation Villas in Vung Tau';

  @override
  String get greetingMorning => 'Good morning!';

  @override
  String get greetingAfternoon => 'Good afternoon!';

  @override
  String get greetingEvening => 'Good evening!';

  @override
  String get homeWelcomeSubtitle =>
      'Warmly welcoming you to the coastal city of Vung Tau';

  @override
  String get homeRecentlyViewedTitle => 'Recently viewed';

  @override
  String get homePopularDestinationsTitle => 'Popular destinations in Vung Tau';

  @override
  String get homeApprovedListingsTitle => 'Verified listings';

  @override
  String get homeSeeMoreVillas => 'Show more villas';

  @override
  String get homeSeeNext => 'Next page';

  @override
  String get homeShowLess => 'Show less';

  @override
  String get homeBlogBadge => 'LATEST ARTICLES';

  @override
  String get homeBlogTitle => 'Featured travel guides';

  @override
  String get homeBlogSubtitle =>
      'Practical guides tailored for booking villas in Vung Tau, from family trips to large group getaways.';

  @override
  String get homeBlogSeeAll => 'View all articles';

  @override
  String get searchPlaceholder => 'Start your search...';

  @override
  String get searchDestinationLabel => 'Destination';

  @override
  String get searchDestinationHint =>
      'Where in Vung Tau would you like to stay?';

  @override
  String get searchModeDates => 'Dates';

  @override
  String get searchModeMonths => 'Months';

  @override
  String get searchModeFlexible => 'Flexible';

  @override
  String get searchFlexibleWeekend => 'Weekend';

  @override
  String get searchFlexibleWeek => '1 week';

  @override
  String get searchFlexibleMonth => '1 month';

  @override
  String get searchExactDates => 'Exact dates';

  @override
  String searchPlusMinusDays(int days) {
    return '± $days days';
  }

  @override
  String get searchAdults => 'Adults';

  @override
  String get searchAdultsDesc => 'Ages 13 or above';

  @override
  String get searchChildren => 'Children';

  @override
  String get searchChildrenDesc => 'Ages 2 – 12';

  @override
  String get searchInfants => 'Infants';

  @override
  String get searchInfantsDesc => 'Under 2';

  @override
  String get searchPets => 'Pets';

  @override
  String get searchPetsDesc => 'Bringing a companion animal';

  @override
  String get searchFilterTitle => 'Filters';

  @override
  String get searchSortNewest => 'Newest';

  @override
  String get searchSortPriceAsc => 'Price: low to high';

  @override
  String get searchSortPriceDesc => 'Price: high to low';

  @override
  String get searchSortRatingDesc => 'Highest rated';

  @override
  String get aiSearchTitle => 'AI Semantic Search';

  @override
  String get aiSearchPlaceholder =>
      'Describe your ideal stay (e.g. Beachfront villa in Back Beach for 15 guests with saltwater pool and BBQ)...';

  @override
  String get aiSearchAction => 'Search with AI';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navZalo => 'Zalo';

  @override
  String get navHotline => 'Hotline';

  @override
  String get navFavorites => 'Wishlist';

  @override
  String get navTrips => 'Trips';

  @override
  String get navAccount => 'Account';

  @override
  String get navSettings => 'Settings';

  @override
  String get navStays => 'Stays';

  @override
  String get navBlog => 'Travel Guide';

  @override
  String get navContact => 'Contact';

  @override
  String get navMessages => 'Messages';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navBookingQueue => 'Booking queue';

  @override
  String get navBecomeHost => 'Become a Host';

  @override
  String get navHostPortal => 'Host Portal';

  @override
  String get navAdminPortal => 'Admin Portal';

  @override
  String bedroomsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bedrooms',
      one: '1 bedroom',
    );
    return '$_temp0';
  }

  @override
  String bedsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count beds',
      one: '1 bed',
    );
    return '$_temp0';
  }

  @override
  String guestsCapacity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guests',
      one: '1 guest',
    );
    return '$_temp0';
  }

  @override
  String guestsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guests',
      one: '1 guest',
    );
    return '$_temp0';
  }

  @override
  String adultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count adults',
      one: '1 adult',
    );
    return '$_temp0';
  }

  @override
  String childrenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count children',
      one: '1 child',
    );
    return '$_temp0';
  }

  @override
  String infantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count infants',
      one: '1 infant',
    );
    return '$_temp0';
  }

  @override
  String petsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pets',
      one: '1 pet',
    );
    return '$_temp0';
  }

  @override
  String bathroomsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count baths',
      one: '1 bath',
    );
    return '$_temp0';
  }

  @override
  String nightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nights',
      one: '1 night',
    );
    return '$_temp0';
  }

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
      zero: 'No reviews yet',
    );
    return '$_temp0';
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
  String get pricePerNightUnit => '/ night';

  @override
  String saturdayPrice(String price) {
    return 'Sat: $price';
  }

  @override
  String totalNightsWithFee(int nights) {
    String _temp0 = intl.Intl.pluralLogic(
      nights,
      locale: localeName,
      other: 'Total for $nights nights • Fees included',
      one: 'Total for 1 night • Fees included',
    );
    return '$_temp0';
  }

  @override
  String get contactForPrice => 'Contact for pricing';

  @override
  String get statusAvailable => 'Available';

  @override
  String get statusBooked => 'Booked';

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
  String get ctaBookInstant => 'Book now';

  @override
  String get ctaRequestBooking => 'Request to book';

  @override
  String get ctaAddToQueue => 'Add to booking queue';

  @override
  String get ctaViewDetail => 'View Details';

  @override
  String get ctaCopyLink => 'Copy Link';

  @override
  String get ctaCopied => 'Link copied to clipboard';

  @override
  String get ctaZaloCopied => 'Inquiry copied and opening Zalo';

  @override
  String get ctaRetry => 'Retry';

  @override
  String get ctaResetFilter => 'Reset Filters';

  @override
  String get ctaBack => 'Back';

  @override
  String get ctaBackHome => 'Back to home';

  @override
  String get ctaClose => 'Close';

  @override
  String get ctaCancel => 'Cancel';

  @override
  String get ctaConfirm => 'Confirm';

  @override
  String get ctaSave => 'Save changes';

  @override
  String get ctaPrevPage => 'Previous';

  @override
  String get ctaNextPage => 'Next';

  @override
  String paginationPageOf(int page, int totalPages) {
    return 'Page $page of $totalPages';
  }

  @override
  String get loadingText => 'Loading data...';

  @override
  String get loadingVillas => 'Loading properties...';

  @override
  String get loadingVillaDetail => 'Loading villa details...';

  @override
  String get loadingFavorites => 'Loading your wishlist...';

  @override
  String get emptyList => 'No matching villas found';

  @override
  String get emptyListDesc =>
      'Try adjusting your search filters or stay dates.';

  @override
  String get errorOccurred => 'Something went wrong';

  @override
  String get errorTryAgain =>
      'Unable to complete the request right now. Please try again.';

  @override
  String get errorOfflineTitle => 'No internet connection';

  @override
  String get errorOfflineMessage =>
      'No internet connection or unstable network. Please check your connection and try again.';

  @override
  String get errorServerTitle => 'Server error';

  @override
  String get errorServerMessage =>
      'The server is temporarily unavailable. Please try again later.';

  @override
  String get errorUnauthorizedMessage =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorForbiddenMessage =>
      'You do not have permission to access this feature.';

  @override
  String get errorNotFoundTitle => '404 — Page not found';

  @override
  String get errorNotFoundMessage =>
      'The page you are looking for does not exist or has been moved.';

  @override
  String get errorVillaNotFoundTitle => 'Villa not found';

  @override
  String get errorVillaNotFoundMessage =>
      'The villa you are looking for does not exist or is no longer available.';

  @override
  String get errorRateLimitMessage =>
      'Too many requests. Please wait a moment and try again.';

  @override
  String get errorValidationMessage =>
      'The submitted information is invalid. Please check and try again.';

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
  String get dailyPriceBreakdownTitle => 'Nightly rate breakdown';

  @override
  String get specCapacityLabel => 'Capacity';

  @override
  String get specBedroomsLabel => 'Bedrooms';

  @override
  String get specBedsLabel => 'Beds';

  @override
  String get specBathroomsLabel => 'Bathrooms';

  @override
  String get specHighlightsTitle => 'Key amenities & location';

  @override
  String get specExpandAction => 'Show detailed specifications';

  @override
  String get specCollapseAction => 'Hide detailed specifications';

  @override
  String get specPrivatePool => 'Private pool';

  @override
  String get specNoPool => 'No pool';

  @override
  String get specBbqKitchen => 'Full kitchen & BBQ grill';

  @override
  String get specBasicKitchen => 'Basic kitchen';

  @override
  String get specParking => 'Car parking available';

  @override
  String get specSelfParking => 'Off-site parking';

  @override
  String get specNearCenter => 'Near city center';

  @override
  String get hostDefaultName => 'VungTauStay Host';

  @override
  String get hostDefaultBio =>
      'Local host in Vung Tau assisting with stay details and check-in.';

  @override
  String get bookingInstantConfirm => 'Instant booking confirmation';

  @override
  String get bookingSupport247 => '24/7 Booking Support';

  @override
  String get faqTitle => 'Frequently Asked Questions';

  @override
  String get rulesAndFaqTitle => 'House Rules & FAQ';

  @override
  String get faqCheckInTitle => 'What are the check-in and check-out times?';

  @override
  String get faqCheckInBody =>
      'Standard check-in is from 14:00 and check-out is before 12:00 the next day. Early check-in or late check-out requests are subject to availability.';

  @override
  String get faqNoiseTitle => 'What are the noise and karaoke regulations?';

  @override
  String get faqNoiseBody =>
      'Per Vung Tau municipal rules, outdoor audio and karaoke operate until 22:00. After 22:00, please keep activities indoors so neighboring villas are not disturbed.';

  @override
  String get faqKitchenTitle =>
      'Is the villa equipped with cooking utensils and BBQ gear?';

  @override
  String get faqKitchenBody =>
      'The kitchen and BBQ area are equipped with tableware, pots, pans, induction/gas stove, and grilling racks. Guests only need to prepare fresh ingredients and charcoal.';

  @override
  String get faqDepositTitle => 'What is the deposit and cancellation policy?';

  @override
  String get faqDepositBody =>
      'A 50% deposit is required to secure your villa reservation, with the remaining balance payable upon check-in. Date changes are supported with at least 7 days advance notice.';

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

  @override
  String get bookingStatusPendingPayment => 'Pending payment';

  @override
  String get bookingStatusPaymentExpired => 'Payment expired';

  @override
  String get bookingStatusPaid => 'Paid';

  @override
  String get bookingStatusConfirmed => 'Confirmed';

  @override
  String get bookingStatusCheckedIn => 'Checked in';

  @override
  String get bookingStatusCheckedOut => 'Checked out';

  @override
  String get bookingStatusCompleted => 'Completed';

  @override
  String get bookingStatusCancelledByGuest => 'Cancelled by guest';

  @override
  String get bookingStatusCancelledByHost => 'Cancelled by host';

  @override
  String get bookingStatusCancelledByAdmin => 'Cancelled by admin';

  @override
  String get bookingStatusRejected => 'Rejected';

  @override
  String get bookingStatusRefundPending => 'Refund pending';

  @override
  String get bookingStatusRefunded => 'Refunded';

  @override
  String get paymentUnverifiedTitle => 'Transaction not yet verified';

  @override
  String get paymentUnverifiedDesc =>
      'Unable to verify transaction status with the server right now. Please check your connection and retry verification.';

  @override
  String get paymentRecheckStatus => 'Re-verify status';

  @override
  String get authLoginTitle => 'Sign in';

  @override
  String get authRegisterTitle => 'Create account';

  @override
  String get authForgotPasswordTitle => 'Forgot password';

  @override
  String get authGoogleSignIn => 'Continue with Google';

  @override
  String get authLogout => 'Sign out';

  @override
  String get profileVerified => 'Verified';

  @override
  String get profileUnverified => 'Unverified';

  @override
  String get hostOnboardingTitle => 'Become a Host at The Palm';

  @override
  String get hostKycTitle => 'Host Registration & KYC Verification';

  @override
  String get hostKycStatusTitle => 'Host Application Status';

  @override
  String get hostTabOverview => 'Overview';

  @override
  String get hostTabProperties => 'Listings';

  @override
  String get hostTabNewProperty => 'Add listing';

  @override
  String get hostTabBookings => 'Bookings';

  @override
  String get hostTabCalendar => 'Calendar';

  @override
  String get hostTabGuests => 'Guests';

  @override
  String get hostTabMessages => 'Messages';

  @override
  String get hostTabPayouts => 'Payouts';

  @override
  String get hostTabReviews => 'Reviews';

  @override
  String get hostTabReports => 'Revenue reports';

  @override
  String get hostTabSupport => 'Support';

  @override
  String get hostTabSettings => 'Host settings';

  @override
  String get hostListingDraft => 'Draft';

  @override
  String get hostListingPendingApproval => 'Pending approval';

  @override
  String get hostListingPublished => 'Published';

  @override
  String get hostListingHidden => 'Hidden';

  @override
  String get hostListingRejected => 'Rejected';

  @override
  String get adminTabOverview => 'Overview';

  @override
  String get adminTabUsers => 'Users';

  @override
  String get adminTabModeration => 'Listing moderation';

  @override
  String get adminTabHostApplications => 'Host applications';

  @override
  String get adminTabRoles => 'Role management';

  @override
  String get adminUserStatusActive => 'Active';

  @override
  String get adminUserStatusSuspended => 'Suspended';

  @override
  String get adminUserStatusInactive => 'Inactive';
}
