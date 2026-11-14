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

  @override
  String get settingsCurrency => 'Display currency';

  @override
  String get currencyFollowLanguage => 'Follow language';

  @override
  String get currencyFollowLanguageDesc =>
      'Automatically switch currency with interface language';

  @override
  String get currencyNameVnd => 'Vietnamese Dong (VND - ₫)';

  @override
  String get currencyNameUsd => 'US Dollar (USD - \$)';

  @override
  String get currencyNameKrw => 'South Korean Won (KRW - ₩)';

  @override
  String fxEstimatedPrice(String amount) {
    return 'Estimated price: ≈ $amount';
  }

  @override
  String fxTotalPayableVnd(String amountVnd) {
    return 'Total payable: $amountVnd';
  }

  @override
  String get fxChargedInVndNotice =>
      'You will be charged in VND. Your bank may apply exchange rates and fees.';

  @override
  String fxReferenceRateLabel(String source) {
    return 'Reference rate ($source)';
  }

  @override
  String fxRateUpdatedAt(String time) {
    return 'Exchange rate as of $time';
  }

  @override
  String get fxRateUnavailableFallback =>
      'Exchange rates unavailable. Displaying official prices in VND.';

  @override
  String fxRateStaleNotice(String time) {
    return 'Using last verified exchange rate ($time).';
  }

  @override
  String get fxBankConversionFeeNotice =>
      'Conversion fees and bank exchange rates may apply.';

  @override
  String get fxPaymentMethodUnsupported =>
      'This payment method is not currently supported.';

  @override
  String get fxRefundInVndNotice =>
      'Actual refunds are processed in VND. Your card statement amount may differ based on bank exchange rates at refund time.';

  @override
  String get fxHistoricalReferenceNote =>
      'Converted foreign amount is for reference only, not the actual statement charge.';

  @override
  String fxPayButtonVnd(String amountVnd, String method) {
    return 'Pay $amountVnd via $method';
  }

  @override
  String get fxPriceRangePerNight => 'Nightly price range';

  @override
  String get vnpayGatewayTitle => 'VNPay (QR Pay / Domestic Bank Card)';

  @override
  String get vnpayGatewaySubtitle =>
      'Secure VND settlement via VNPay payment gateway';

  @override
  String get momoGatewayTitle => 'MoMo E-Wallet';

  @override
  String get momoGatewaySubtitle => 'Pay in VND via MoMo app or MoMo QR code';

  @override
  String get footerSupportTitle => 'Support';

  @override
  String get footerLinkBookingGuide => 'Booking guide';

  @override
  String get footerLinkCancellationPolicy => 'Cancellation policy';

  @override
  String get footerLinkComplaintsFeedback => 'Complaints & Feedback';

  @override
  String get footerLinkFaq => 'Frequently asked questions (FAQ)';

  @override
  String get footerExploreTitle => 'Explore & Services';

  @override
  String get footerLinkAboutUs => 'About us';

  @override
  String get footerLinkExploreVungTau => 'Explore Vung Tau';

  @override
  String get footerLinkTravelGuide => 'Travel guide';

  @override
  String get footerLinkAddonServices => 'Add-on services';

  @override
  String get footerLinkMemberOffers => 'Member offers';

  @override
  String get footerContactTitle => 'Contact';

  @override
  String footerHotlineLabel(String phone) {
    return 'Hotline: $phone';
  }

  @override
  String get footerOnlineConsultLink => 'Online consultation';

  @override
  String footerAddressLabel(String address) {
    return 'Address: $address';
  }

  @override
  String footerEmailLabel(String email) {
    return 'Email: $email';
  }

  @override
  String get footerEmailSubject => 'Booking inquiry - The Palm Villa Vung Tau';

  @override
  String get footerSocialTitle => 'Social';

  @override
  String get footerCopyright =>
      '© 2026 The Palm Villa Vung Tau. All rights reserved.';

  @override
  String get supportGuideStep1Title =>
      'Search by coastal zone & live availability';

  @override
  String get supportGuideStep1Desc =>
      'Select a Vung Tau beach zone (Back Beach, Front Beach, Chi Linh, Long Cung), stay dates [Check-in, Check-out), and group size to filter available private villas.';

  @override
  String get supportGuideStep2Title =>
      'Review nightly rates & apply promo codes';

  @override
  String get supportGuideStep2Desc =>
      'Inspect villa specifications (bedrooms, beds, baths, beach distance), weekday/weekend nightly rates, extra-guest surcharges (if any), and apply valid coupon codes.';

  @override
  String get supportGuideStep3Title => '15-minute temporary calendar hold';

  @override
  String get supportGuideStep3Desc =>
      'As soon as a booking is created, the system locks your stay dates for 15 minutes (Pending Payment) to prevent double-booking by other groups.';

  @override
  String get supportGuideStep4Title =>
      'Complete online payment & receive stay confirmation';

  @override
  String get supportGuideStep4Desc =>
      'Complete payment via supported gateways (VNPay, MoMo, or VietQR) within the hold window. Track booking status and message the Host directly in Trips.';

  @override
  String get supportCancelFlexName => 'Flexible Policy';

  @override
  String get supportCancelFlexBadge => '100% refund 24h+ before check-in';

  @override
  String get supportCancelFlexRule1 =>
      'Cancel at least 24 hours before check-in: 100% refund of the total paid amount.';

  @override
  String get supportCancelFlexRule2 =>
      'Cancel less than 24 hours before check-in: non-refundable.';

  @override
  String get supportCancelModName => 'Moderate Policy';

  @override
  String get supportCancelModBadge => '100% refund 5+ days before check-in';

  @override
  String get supportCancelModRule1 =>
      'Cancel at least 5 days (120 hours) before check-in: 100% refund of the total paid amount.';

  @override
  String get supportCancelModRule2 =>
      'Cancel between 24 hours and 5 days (120 hours) before check-in: 50% refund of the total paid amount.';

  @override
  String get supportCancelModRule3 =>
      'Cancel less than 24 hours before check-in: non-refundable.';

  @override
  String get supportCancelStrictName => 'Strict Policy';

  @override
  String get supportCancelStrictBadge => '50% refund 7+ days before check-in';

  @override
  String get supportCancelStrictRule1 =>
      'Cancel at least 7 days (168 hours) before check-in: 50% refund of the total paid amount.';

  @override
  String get supportCancelStrictRule2 =>
      'Cancel less than 7 days (168 hours) before check-in: non-refundable.';

  @override
  String get supportComplaintStep1Title =>
      'Submit report with Booking ID or Listing ID';

  @override
  String get supportComplaintStep1Desc =>
      'Sign in and submit an online report with your Booking ID or Listing ID, describing the factual issue that needs verification.';

  @override
  String get supportComplaintStep2Title => 'Audit stay logs & payment records';

  @override
  String get supportComplaintStep2Desc =>
      'Our Trust & Safety team independently audits booking state logs, in-app message history, and verified payment records.';

  @override
  String get supportComplaintStep3Title =>
      'Transparent resolution & guest protection';

  @override
  String get supportComplaintStep3Desc =>
      'Resolution outcomes are updated transparently on your report (Resolved / Rejected with reason) and trigger refunds if the Host breached commitments.';

  @override
  String get supportFaqCatAll => 'All';

  @override
  String get supportFaqCatBooking => 'Booking & Availability';

  @override
  String get supportFaqCatPayment => 'Payments & Refunds';

  @override
  String get supportFaqCatAmenities => 'Amenities & House Rules';

  @override
  String get supportFaqCatHost => 'Host Partners';

  @override
  String get supportFaq1Q => 'How does the system calculate stay nights?';

  @override
  String get supportFaq1A =>
      'We use the half-open stay interval [Check-in, Check-out) in Vietnam timezone (Asia/Ho_Chi_Minh). Checking in on the 15th and checking out on the 17th equals 2 nights (the 15th and 16th).';

  @override
  String get supportFaq2Q =>
      'Why does a reservation have a 15-minute hold window?';

  @override
  String get supportFaq2A =>
      'Each whole-villa listing is a unique property. Creating a reservation locks those dates for 15 minutes so no one else can book them while you pay. Unpaid holds release automatically after 15 minutes.';

  @override
  String get supportFaq3Q =>
      'How are weekend rates and extra-guest surcharges calculated?';

  @override
  String get supportFaq3A =>
      'Weekday/weekend nightly rates, cleaning fees, and extra-guest surcharges come directly from each villa’s verified pricing configuration and are shown transparently before booking.';

  @override
  String get supportFaq4Q => 'Which payment methods are supported?';

  @override
  String get supportFaq4A =>
      'We support online payments via VNPay, MoMo e-wallet, and VietQR bank transfer. Transactions are reconciled automatically and updated in real time under Trips.';

  @override
  String get supportFaq5Q =>
      'How do refunds work when I cancel within policy or a Host declines?';

  @override
  String get supportFaq5A =>
      'When a paid booking is cancelled within the villa’s refund window (or cancelled/declined by the Host for a 100% refund), the system automatically creates a refund record for finance reconciliation back to your payment channel.';

  @override
  String get supportFaq6Q =>
      'Can I chat directly with the Host before booking?';

  @override
  String get supportFaq6A =>
      'Yes. On any villa detail page, tap Message Host or reach our Zalo OA / Hotline on the Contact page to confirm pool details, BBQ setup, or group bus parking.';

  @override
  String get supportFaq7Q => 'How do I list my villa on The Palm Villa?';

  @override
  String get supportFaq7A =>
      'Open Become a Host from the navigation menu, complete identity verification (KYC) and property details. Once approved by Admin, you can manage 30-day availability and two-way Google Sheets sync.';

  @override
  String get supportZoneBaiSauName => 'Back Beach Zone (Thuy Van – Thi Sach)';

  @override
  String get supportZoneBaiSauHint =>
      'Long vibrant coastline within walking distance to the beach';

  @override
  String get supportZoneBaiSauHighlight =>
      'Features spacious private-pool villas ideal for families and friend groups near Thuy Van, Thi Sach, and Vo Thi Sau streets.';

  @override
  String get supportZoneBaiTruocName =>
      'Front Beach Zone (Tran Phu – Quang Trung)';

  @override
  String get supportZoneBaiTruocHint =>
      'Direct ocean sunset views near downtown dining spots';

  @override
  String get supportZoneBaiTruocHighlight =>
      'Tranquil ocean-facing villas along Tran Phu coastal road with open sunset views and easy access to Front Beach Park.';

  @override
  String get supportZoneChiLinhName => 'Chi Linh Coastal Zone';

  @override
  String get supportZoneChiLinhHint =>
      'Gated, peaceful resort enclave near quieter beaches';

  @override
  String get supportZoneChiLinhHighlight =>
      'Well-suited for multi-generational families and corporate retreats seeking greenery, quiet surroundings, and clean beaches.';

  @override
  String get supportZoneLongCungName => 'Long Cung – Thuy Tien Zone';

  @override
  String get supportZoneLongCungHint =>
      'Beachside villa compounds built for large groups';

  @override
  String get supportZoneLongCungHighlight =>
      'Known for wide garden villas, private pools, and outdoor BBQ party spaces steps from Long Cung Beach.';

  @override
  String get supportAddonPoolTitle => 'Private in-villa swimming pool';

  @override
  String get supportAddonPoolDesc =>
      'Enjoy a private swimming pool right inside your villa compound for families and groups.';

  @override
  String get supportAddonPoolNote =>
      'Included according to each villa’s published specifications.';

  @override
  String get supportAddonBbqTitle => 'Garden BBQ grilling station';

  @override
  String get supportAddonBbqDesc =>
      'Equipped with outdoor grill area, garden seating, and essential utensils for evening gatherings.';

  @override
  String get supportAddonBbqNote =>
      'Coordinate charcoal or optional cleaning support with your Host in advance.';

  @override
  String get supportAddonKitchenTitle => 'Full family-style kitchen';

  @override
  String get supportAddonKitchenDesc =>
      'Includes refrigerator, stove, cookware, and tableware so your group can cook fresh local seafood.';

  @override
  String get supportAddonKitchenNote =>
      'Please keep kitchenware tidy per each property’s house rules.';

  @override
  String get supportAddonKaraokeTitle => 'Entertainment room & Karaoke audio';

  @override
  String get supportAddonKaraokeDesc =>
      'Audio entertainment or dedicated lounge rooms available at villas tagged with Karaoke amenities.';

  @override
  String get supportAddonKaraokeNote =>
      'Follow residential quiet hours (outdoor audio off by 22:00).';

  @override
  String get supportAddonParkingTitle => 'Secure car & group van parking';

  @override
  String get supportAddonParkingDesc =>
      'On-site courtyard or wide internal road parking suitable for personal cars and 7–29-seat tour vans.';

  @override
  String get supportAddonParkingNote =>
      'Check exact vehicle capacity in the villa description before arrival.';

  @override
  String get supportAddonBeachTitle => 'Walkable proximity to the beach';

  @override
  String get supportAddonBeachDesc =>
      'Actual walking distance to the nearest beach is stated clearly in meters on every listing card.';

  @override
  String get supportAddonBeachNote =>
      'Filter beach-close villas with a single tap below.';

  @override
  String get supportExploreZoneAction => 'View villas in this zone';

  @override
  String supportServiceNotePrefix(String note) {
    return 'Note: $note';
  }

  @override
  String get supportFilterByAmenityAction => 'Filter villas with this amenity';

  @override
  String get supportFaqSearchHint =>
      'Search questions by keyword (e.g., hold, refund)...';

  @override
  String get supportFaqClearSearchTooltip => 'Clear search query';

  @override
  String get supportFaqEmptyResult =>
      'No matching questions found for this keyword. Try another term or contact our support team directly.';

  @override
  String get supportBookingGuideEyebrow => 'Booking Support';

  @override
  String get supportBookingGuideTitle => 'How to book a private villa';

  @override
  String get supportBookingGuideSubtitle =>
      'Transparent 4-step reservation flow with a 15-minute anti-double-booking hold and instant online payment verification.';

  @override
  String get supportBookingGuideNoteTitle => 'Check-in & check-out reminder';

  @override
  String get supportBookingGuideNoteBody =>
      'All reservations follow the [Check-in, Check-out) night model in Vietnam time. Before arrival, message your Host in Messages to coordinate arrival time and vehicle plates.';

  @override
  String get supportBookingGuideCtaTitle =>
      'Ready to find the right villa for your group?';

  @override
  String get supportBookingGuideCtaDesc =>
      'Browse verified Vung Tau villas with open dates and published nightly rates.';

  @override
  String get supportBookingGuidePrimaryAction => 'Find villas now';

  @override
  String get supportBookingGuideSecondaryAction => 'Contact support';

  @override
  String get supportCancelEyebrow => 'Stay & Refund Policies';

  @override
  String get supportCancelTitle => 'Cancellation & Refund Policy';

  @override
  String get supportCancelSubtitle =>
      'Refund percentages are calculated automatically from each villa’s published policy tier and hours remaining before check-in.';

  @override
  String get supportCancelHostProtectTitle =>
      '100% guest protection if a Host cancels';

  @override
  String get supportCancelHostProtectBody =>
      'If a paid booking is declined or cancelled by the Host, the system automatically issues a 100% refund regardless of policy tier. Unpaid holds expire free of charge after 15 minutes.';

  @override
  String get supportCancelCtaTitle =>
      'Check booking status or request cancellation';

  @override
  String get supportCancelCtaDesc =>
      'Open Trips to view the policy attached to your reservation or reach out to support.';

  @override
  String get supportCancelPrimaryAction => 'View my Trips';

  @override
  String get supportCancelSecondaryAction => 'Read FAQ';

  @override
  String get supportComplaintsEyebrow => 'Trust & Transparency';

  @override
  String get supportComplaintsTitle => 'Complaints, Reports & Service Feedback';

  @override
  String get supportComplaintsSubtitle =>
      'Every report regarding villa quality, listing accuracy, or host service is logged and independently reviewed.';

  @override
  String get supportComplaintsCtaTitle =>
      'Need urgent help during an active stay?';

  @override
  String get supportComplaintsCtaDesc =>
      'Connect directly via Hotline or Zalo OA at our Vung Tau office (08:00 – 22:00) for immediate assistance.';

  @override
  String get supportComplaintsPrimaryAction => 'Open Contact page';

  @override
  String get supportComplaintsSecondaryAction => 'Messages with Host';

  @override
  String get supportFaqEyebrow => 'Help Center';

  @override
  String get supportFaqPageTitle => 'Frequently Asked Questions (FAQ)';

  @override
  String get supportFaqSubtitle =>
      'Quick answers about stay-night calculation, 15-minute holds, payment gateways, refunds, and Host onboarding.';

  @override
  String get supportFaqCtaTitle => 'Still looking for a specific answer?';

  @override
  String get supportFaqCtaDesc =>
      'Our advisors at 28 Thi Sach, Vung Tau City are ready to tailor recommendations for your group.';

  @override
  String get supportFaqPrimaryAction => 'Online consultation';

  @override
  String get supportFaqSecondaryAction => 'View booking guide';

  @override
  String get supportAboutEyebrow => 'About The Palm Villa';

  @override
  String get supportAboutTitle =>
      'Verified Private Vacation Villa Platform in Vung Tau';

  @override
  String get supportAboutSubtitle =>
      'Connecting travelers directly with inspected vacation villas and KYC-verified Hosts across Vung Tau City.';

  @override
  String get supportAboutPillar1Title =>
      'Inspected properties & KYC-verified Hosts';

  @override
  String get supportAboutPillar1Body =>
      'Every Host partner completes identity verification and listing photo inspection before opening availability to guests.';

  @override
  String get supportAboutPillar2Title =>
      'Zero Double-Booking transactional lock';

  @override
  String get supportAboutPillar2Body =>
      'Transactional date locking upon booking creation protects your group’s stay dates throughout checkout.';

  @override
  String get supportAboutPillar3Title => 'Transparent nightly rate breakdown';

  @override
  String get supportAboutPillar3Body =>
      'Displays server-verified weekday/weekend prices, cleaning fees, and extra-guest charges upfront before payment.';

  @override
  String get supportAboutCtaTitle => 'Partner & travel with The Palm Villa';

  @override
  String get supportAboutCtaDesc =>
      'Explore open villas for your next trip or register as a Host partner for transparent calendar and payout management.';

  @override
  String get supportAboutPrimaryAction => 'Explore stays';

  @override
  String get supportAboutSecondaryAction => 'Become a Host';

  @override
  String get supportExploreVtEyebrow => 'Coastal Resort Zones';

  @override
  String get supportExploreVtTitle =>
      'Explore Vung Tau by coastal neighborhood';

  @override
  String get supportExploreVtSubtitle =>
      'Each neighborhood in Vung Tau offers a distinct vibe. Pick a zone matching your itinerary to filter live villas.';

  @override
  String get supportExploreVtCtaTitle =>
      'Pair your villa stay with local dining & tips';

  @override
  String get supportExploreVtCtaDesc =>
      'Read our local travel guide articles to plan a complete coastal getaway in Vung Tau.';

  @override
  String get supportExploreVtPrimaryAction => 'Read Travel Guide';

  @override
  String get supportExploreVtSecondaryAction => 'Open search map';

  @override
  String get supportAddonEyebrow => 'Amenities & Experiences';

  @override
  String get supportAddonTitle => 'Villa Amenities & Stay Services';

  @override
  String get supportAddonSubtitle =>
      'Overview of signature whole-villa amenities and how to coordinate BBQ setup or group vehicle parking with Hosts.';

  @override
  String get supportAddonNoteTitle =>
      'How to request preparation before check-in';

  @override
  String get supportAddonNoteBody =>
      'Every villa publishes its exact amenities and group policies. Once you pick a villa, tap Message Host on the detail screen to confirm custom arrangements.';

  @override
  String get supportAddonCtaTitle =>
      'Looking for a villa with both private pool & BBQ yard?';

  @override
  String get supportAddonCtaDesc =>
      'Use multi-criteria filters on the Search screen to match every amenity your group needs.';

  @override
  String get supportAddonPrimaryAction => 'Open stay filters';

  @override
  String get supportAddonSecondaryAction => 'Group consultation';

  @override
  String get supportMemberEyebrow => 'Member Benefits';

  @override
  String get supportMemberTitle => 'Member Offers & Booking Promo Codes';

  @override
  String get supportMemberSubtitle =>
      'Create a free member account to apply promo codes at checkout, sync your wishlist, and manage trip history.';

  @override
  String get supportMemberNote1Title =>
      'Apply Coupon codes directly when booking';

  @override
  String get supportMemberNote1Body =>
      'Signed-in members can apply percentage or fixed-amount coupons on the villa detail page. Validity, minimum order value, and per-user limits are verified automatically.';

  @override
  String get supportMemberNote2Title =>
      'Sync Wishlist & track Trips in real time';

  @override
  String get supportMemberNote2Body =>
      'Save favorite villas across devices, receive instant booking updates, and chat directly with Hosts.';

  @override
  String get supportMemberCtaTitle =>
      'Redeem an offer for your upcoming Vung Tau stay';

  @override
  String get supportMemberCtaDesc =>
      'Choose your villa, review published nightly rates, and enter your coupon code right at booking confirmation.';

  @override
  String get supportMemberPrimaryAction => 'Browse open villas';

  @override
  String get supportMemberSecondaryAction => 'My Wishlist';

  @override
  String get supportReportTargetBooking => 'Reservation (Booking ID)';

  @override
  String get supportReportTargetListing => 'Property / Villa (Listing ID)';

  @override
  String get supportReportTargetReview => 'Stay Review (Review ID)';

  @override
  String get supportReportTargetUser => 'User Account (User ID)';

  @override
  String get supportReportSuccessMessage =>
      'Your report has been recorded. Our Trust & Safety team will review and respond promptly.';

  @override
  String get supportReportErrorFallback =>
      'Unable to submit your report right now. Please try again.';

  @override
  String get supportReportStatusResolved => 'Resolved';

  @override
  String get supportReportStatusRejected => 'Rejected';

  @override
  String get supportReportStatusOpen => 'In review';

  @override
  String get supportReportGuestCardTitle =>
      'Submit an online report or complaint';

  @override
  String get supportReportGuestCardBody =>
      'To verify booking records accurately, please sign in before submitting an online report, or reach us directly via the Contact page.';

  @override
  String get supportReportLoginAction => 'Sign in to submit report';

  @override
  String get supportReportDirectContactAction => 'Open direct Contact channels';

  @override
  String get supportReportAuthCardTitle => 'Submit a report to Trust & Safety';

  @override
  String get supportReportAuthCardSubtitle =>
      'Reports are logged directly for Administrator verification and transparent follow-up.';

  @override
  String get supportReportTargetGroupLabel => 'Report target category';

  @override
  String get supportReportTargetIdLabel =>
      'Numeric ID (e.g., Booking 102 or Villa 15)';

  @override
  String get supportReportTargetIdError =>
      'Please enter a valid positive numeric ID';

  @override
  String get supportReportReasonLabel => 'Report / feedback title';

  @override
  String get supportReportReasonEmptyError => 'Please enter a report title';

  @override
  String get supportReportReasonMaxError => 'Maximum 255 characters';

  @override
  String get supportReportDescLabel => 'Detailed description (optional)';

  @override
  String get supportReportSubmittingLabel => 'Submitting report...';

  @override
  String get supportReportSubmitAction => 'Submit report';

  @override
  String supportReportRecentTitle(int count) {
    return 'Your recent reports ($count)';
  }

  @override
  String get supportCouponEmptyError => 'Please enter a coupon code to check.';

  @override
  String supportCouponValidStatus(String code, String discount) {
    return 'Code $code is valid — estimated $discount off this subtotal.';
  }

  @override
  String get supportCouponInvalidFallback =>
      'This coupon code is ineligible or has expired.';

  @override
  String get supportCouponCheckError =>
      'Unable to validate coupon code right now.';

  @override
  String get supportCouponCardTitle => 'Check Coupon Code Eligibility';

  @override
  String get supportCouponGuestHint =>
      'Sign in to your member account to validate coupon codes against an estimated stay subtotal or apply them at checkout.';

  @override
  String get supportCouponAuthHint =>
      'Enter your coupon code and estimated booking amount (VND) to verify live eligibility.';

  @override
  String get supportCouponLoginAction => 'Member sign in';

  @override
  String get supportCouponRegisterAction => 'Create free account';

  @override
  String get supportCouponCodeInputLabel => 'Coupon code (e.g., PALM2026)';

  @override
  String get supportCouponAmountInputLabel => 'Estimated subtotal (VND)';

  @override
  String get supportCouponCheckingLabel => 'Checking...';

  @override
  String get supportCouponCheckAction => 'Check coupon code';
}
