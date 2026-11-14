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
  String get loadingTrips => 'Loading trips...';

  @override
  String get loadingPaymentInfo => 'Loading booking payment details...';

  @override
  String get guestPaymentConnectingGateway =>
      'Connecting to payment gateway...';

  @override
  String get guestPaymentBookingNotFoundTitle => 'Booking not found';

  @override
  String get guestPaymentBookingNotFoundMessage =>
      'This booking does not exist or has expired.';

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
  String get calendarPrevMonth => 'Previous month';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String calendarDay(int day) {
    return 'Day $day';
  }

  @override
  String calendarDayBooked(int day) {
    return 'Day $day is booked';
  }

  @override
  String calendarDayCheckOutOnly(int day) {
    return 'Day $day check-out only';
  }

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
  String get footerSupport => 'Support';

  @override
  String get footerBookingGuide => 'Booking Guide';

  @override
  String get footerCancellationPolicy => 'Cancellation Policy';

  @override
  String get footerFeedback => 'Complaints & Feedback';

  @override
  String get footerFaq => 'Frequently Asked Questions (FAQ)';

  @override
  String get footerDiscover => 'Explore Vung Tau';

  @override
  String get footerAboutUs => 'About Us';

  @override
  String get footerTravelGuide => 'Travel Guide';

  @override
  String get footerAddonServices => 'Add-on Services';

  @override
  String get footerMemberOffers => 'Member Offers';

  @override
  String get footerContact => 'Contact';

  @override
  String get footerOnlineConsultation => 'Online Consultation';

  @override
  String footerHotline(String phone) {
    return 'Hotline: $phone';
  }

  @override
  String get footerAddress => 'Address: 28 Thi Sach';

  @override
  String footerEmail(String email) {
    return 'Email: $email';
  }

  @override
  String get footerSocial => 'Social';

  @override
  String get footerCopyright =>
      '© 2026 The Palm Villa Vung Tau. All rights reserved.';

  @override
  String get settingsAvatarUpdateTitle => 'Update profile photo';

  @override
  String get settingsAvatarUpdateHint =>
      'Select a JPG, PNG, WebP, or GIF image from your device (maximum 5MB).';

  @override
  String get settingsAvatarPickFromDevice =>
      'Choose photo from device (Max 5MB)';

  @override
  String get settingsAvatarUploading => 'Uploading photo...';

  @override
  String settingsAvatarSelected(String fileName, String sizeKb) {
    return 'Selected: $fileName ($sizeKb KB)';
  }

  @override
  String get settingsAvatarPickError =>
      'Unable to choose photo from device. Please try again.';

  @override
  String get settingsAvatarUpdateSuccess =>
      'Profile photo updated successfully.';

  @override
  String get settingsChangeAvatarTooltip => 'Change photo';

  @override
  String get settingsEditProfileTooltip => 'Edit profile';

  @override
  String get settingsEditProfileTitle => 'Edit personal profile';

  @override
  String get settingsAvatarSectionTitle => 'Profile photo';

  @override
  String get settingsAvatarPickFromDeviceShort => 'Choose from device';

  @override
  String get settingsAvatarUploadingShort => 'Uploading...';

  @override
  String get settingsAvatarPickHint => 'Choose photo from device (max 5MB)';

  @override
  String settingsAvatarSelectedShort(String fileName) {
    return 'Selected: $fileName';
  }

  @override
  String get settingsFullNameLabel => 'Full name *';

  @override
  String get settingsFullNameHint => 'Enter your full name';

  @override
  String get settingsPhoneLabel => 'Phone number';

  @override
  String get settingsPhoneHint => '0912345678 or +84912345678';

  @override
  String get settingsLocationLabel => 'Location';

  @override
  String get settingsLocationHint => 'e.g. Vung Tau, Vietnam';

  @override
  String get settingsDreamDestinationLabel => 'Dream destination';

  @override
  String get settingsDreamDestinationHint => 'Enter your favorite destination';

  @override
  String get settingsJobLabel => 'Profession / Occupation';

  @override
  String get settingsJobHint => 'Enter your current profession';

  @override
  String get settingsSchoolLabel => 'School / University';

  @override
  String get settingsSchoolHint => 'Where you studied';

  @override
  String get settingsLanguagesLabel => 'Languages spoken';

  @override
  String get settingsLanguagesHint => 'English, Vietnamese (comma-separated)';

  @override
  String get settingsBioLabel => 'About me';

  @override
  String get settingsBioHint => 'Tell us a bit about yourself...';

  @override
  String get settingsSaving => 'Saving...';

  @override
  String get settingsProfileUpdateSuccess => 'Profile updated successfully.';

  @override
  String get settingsUnsavedDraftBanner => 'You have unsaved profile changes.';

  @override
  String get settingsResumeEditing => 'Continue editing';

  @override
  String get settingsConfirmPhoneTitle => 'Confirm phone number change';

  @override
  String settingsConfirmPhoneRemove(String oldPhone) {
    return 'You are about to remove saved phone number ($oldPhone). Are you sure you want to proceed?';
  }

  @override
  String settingsConfirmPhoneChange(String oldPhone, String newPhone) {
    return 'You are about to change phone number from $oldPhone to $newPhone. Are you sure you want to save this change?';
  }

  @override
  String get settingsConfirmPhoneReview => 'Review';

  @override
  String get settingsConfirmPhoneSave => 'Confirm save';

  @override
  String get settingsConfirmLogoutTitle => 'Confirm sign out';

  @override
  String get settingsConfirmLogoutDraft =>
      'You have unsaved profile edits. Signing out will discard temporary draft data on this session. Are you sure you want to sign out?';

  @override
  String get settingsConfirmLogout =>
      'Are you sure you want to sign out of this account?';

  @override
  String get settingsRoleAdmin => 'Administrator (Admin)';

  @override
  String get settingsRoleHost => 'Host';

  @override
  String get settingsRoleHostPending => 'Host application pending approval';

  @override
  String get settingsRoleGuest => 'Guest';

  @override
  String get settingsLoadingAccount => 'Loading account information...';

  @override
  String get settingsNotLoggedIn => 'Not signed in';

  @override
  String get settingsLoginPrompt =>
      'Sign in to view your trips, messages, and synced wishlists';

  @override
  String get settingsSignInSignUp => 'Sign In / Register';

  @override
  String get settingsReLogin => 'Sign in again';

  @override
  String get settingsContactSupportCenter => 'Contact & Support Center';

  @override
  String get settingsCallHotline => 'Call hotline support';

  @override
  String get settingsZaloSupport => 'Message via Zalo OA';

  @override
  String get settingsZaloInquiryDefaultMessage =>
      'Hello The Palm, I need assistance with the app.';

  @override
  String get settingsManageProperties => 'Manage listings';

  @override
  String get settingsMyTrips => 'My trips';

  @override
  String get settingsMyFavorites => 'My wishlist';

  @override
  String get settingsMessagesWithHost => 'Messages with hosts';

  @override
  String get settingsStatusOfflineTitle => 'Device is offline';

  @override
  String get settingsStatusUnauthorizedTitle =>
      'Session expired or access denied';

  @override
  String get settingsStatusServerErrorTitle => 'Unable to sync server data';

  @override
  String get settingsStatusOfflineMessage =>
      'Unable to connect to the server. Please check your network connection and try again.';

  @override
  String get settingsStatusUnauthorizedMessage =>
      'Invalid session or you do not have permission to access (401/403).';

  @override
  String get settingsStatusServerErrorMessage =>
      'The server is experiencing temporary issues. Please try again later.';

  @override
  String villaDetailViewAllPhotos(int count) {
    return 'See all $count photos';
  }

  @override
  String get villaDetailShareCopied => 'Link copied to clipboard';

  @override
  String get villaDetailAboutTitle => 'About this villa';

  @override
  String get villaDetailTranslatedBadge => 'Translated to English';

  @override
  String get villaDetailShowOriginal => 'Show original';

  @override
  String get villaDetailShowTranslation => 'Show translation';

  @override
  String get villaDetailOriginalBadge => 'Original (Vietnamese)';

  @override
  String get villaDetailAmenitiesTitle => 'Amenities';

  @override
  String get villaDetailBookingCalendarTitle => 'Select stay dates & Book';

  @override
  String villaDetailStayNightsRange(int min, int max) {
    return 'Minimum $min nights • Maximum $max nights';
  }

  @override
  String villaDetailGuestCapacityInfo(int included, int max) {
    return 'Standard $included · Up to $max guests';
  }

  @override
  String villaDetailGuestCapacityMax(int max) {
    return 'Up to $max guests';
  }

  @override
  String get villaDetailPromoCodeHint => 'Promo code';

  @override
  String get villaDetailPromoApply => 'Apply';

  @override
  String get villaDetailPromoChecking => 'Checking...';

  @override
  String get villaDetailSpecialRequestsHint => 'Note for the host (optional)';

  @override
  String villaDetailRoomSubtotal(int nights) {
    return 'Room rate ($nights nights)';
  }

  @override
  String villaDetailWeekendNights(int count) {
    return ', $count weekend nights';
  }

  @override
  String get villaDetailExtraGuestFee => 'Extra guest fee';

  @override
  String get villaDetailCleaningFee => 'Cleaning fee';

  @override
  String get villaDetailServiceFee => 'Service fee';

  @override
  String villaDetailDiscountLabel(String code) {
    return 'Discount ($code)';
  }

  @override
  String get villaDetailEstimatedTotal => 'Estimated total';

  @override
  String get villaDetailPoliciesTitle => 'House rules & Cancellation policy';

  @override
  String villaDetailCheckInTime(String from, String until) {
    return 'Check-in: $from – $until';
  }

  @override
  String villaDetailCheckOutTime(String time) {
    return 'Check-out: Before $time';
  }

  @override
  String villaDetailQuietHours(String hours) {
    return 'Quiet hours: $hours';
  }

  @override
  String get villaDetailPetsAllowed => 'Pets allowed';

  @override
  String get villaDetailPetsNotAllowed => 'No pets allowed';

  @override
  String get villaDetailPolicyFlexible =>
      'Flexible — 100% refund up to 24 hours before check-in';

  @override
  String get villaDetailPolicyModerate =>
      'Moderate — 100% refund up to 5 days before check-in';

  @override
  String get villaDetailPolicyStrict =>
      'Strict — 50% refund up to 7 days before check-in';

  @override
  String get villaDetailSimilarTitle => 'Similar stays nearby';

  @override
  String get villaDetailMessageHostTooltip => 'Message Host';

  @override
  String villaDetailHostPrefix(String name) {
    return 'Host: $name';
  }

  @override
  String villaDetailMinNightsRequired(int min) {
    return 'This stay requires a minimum of $min nights.';
  }

  @override
  String villaDetailMaxNightsExceeded(int max) {
    return 'This stay limits reservations to a maximum of $max nights.';
  }

  @override
  String get villaDetailLoginToBook =>
      'Please log in to complete your reservation.';

  @override
  String get villaDetailBookingSuccess =>
      'Booking request sent! You can pay now or track it in Trips.';

  @override
  String get specSaltwaterPool => 'Saltwater pool';

  @override
  String specBeachDistance(int meters) {
    return '${meters}m to beach';
  }

  @override
  String get specBeachfront => 'Beachfront';

  @override
  String specGuestsCount(int count) {
    return '$count guests';
  }

  @override
  String specBedroomsCount(int count) {
    return '$count bedrooms';
  }

  @override
  String specBedsCount(int count) {
    return '$count beds';
  }

  @override
  String specBathsCount(int count) {
    return '$count baths';
  }

  @override
  String get reviewsTranslate => 'Translate review';

  @override
  String get reviewsShowOriginal => 'Show original';

  @override
  String get reviewsTranslating => 'Translating...';

  @override
  String get reviewsTranslatedBadge => 'Automatically translated';

  @override
  String get reviewsFilterAll => 'All';

  @override
  String reviewsFilterStar(int star) {
    return '$star stars';
  }

  @override
  String get reviewsHostReply => 'Host response';

  @override
  String get reviewsLoadMore => 'Show more reviews';

  @override
  String get reviewsLoadError => 'Unable to load reviews right now.';

  @override
  String get reviewsEmpty =>
      'No reviews for this villa yet. Be the first guest to share your experience!';

  @override
  String reviewsEmptyRating(int rating) {
    return 'No $rating-star reviews for this property yet.';
  }

  @override
  String get chatBackToList => 'Back to list';

  @override
  String get chatShowTimestamps => 'Show timestamps';

  @override
  String get chatHideTimestamps => 'Hide timestamps';

  @override
  String get chatViewListing => 'View listing';

  @override
  String get chatAboutListing => 'About listing';

  @override
  String get chatSelectConversationPrompt =>
      'Select a conversation to view messages';

  @override
  String get chatInputPlaceholder => 'Message';

  @override
  String get chatMoreOptions => 'More options';

  @override
  String get chatCamera => 'Take photo';

  @override
  String get chatGallery => 'Send photo';

  @override
  String get chatGalleryLabel => 'Photo gallery';

  @override
  String get chatVoiceMessage => 'Voice message';

  @override
  String get chatStopRecording => 'Stop recording';

  @override
  String get chatEmojiTooltip => 'Emoji';

  @override
  String get chatSendMessage => 'Send message';

  @override
  String get chatSendQuickEmoji => 'Send quick emoji';

  @override
  String get chatSendQuickEmojiHint =>
      'Send quick emoji (press and hold to change)';

  @override
  String get chatSending => 'Sending...';

  @override
  String get chatSent => 'Sent';

  @override
  String get chatSeen => ' • Seen';

  @override
  String get chatFailed => 'Failed to send';

  @override
  String get chatRetry => 'Retry';

  @override
  String get chatDeleteFailedMessage => 'Delete failed message';

  @override
  String get chatEmptyPrompt => 'Send a message to start the conversation.';

  @override
  String get chatLoadMoreHistory => 'Load older messages';

  @override
  String get chatLoadingHistory => 'Loading history...';

  @override
  String chatNewMessagesCount(int count) {
    return 'New messages ($count)';
  }

  @override
  String chatUserTyping(String user) {
    return '$user is typing...';
  }

  @override
  String get chatDraftPrefix => 'Draft';

  @override
  String get chatNoMessagesYet => 'No messages yet.';

  @override
  String get chatSearchConversationsPlaceholder => 'Search conversations...';

  @override
  String get chatLoginTitle => 'Sign in to view messages';

  @override
  String get chatLoginDescription =>
      'Chat directly with Vung Tau hosts about availability, amenities, and offers.';

  @override
  String get chatLoginAction => 'Sign in now';

  @override
  String get chatEmptyAdminTitle => 'No support conversations yet';

  @override
  String get chatEmptyAdminDesc =>
      'Direct support conversations with hosts and guests will appear here.';

  @override
  String get chatEmptyAdminAction => 'User management';

  @override
  String get chatEmptyHostTitle => 'No conversations yet';

  @override
  String get chatEmptyHostDesc =>
      'When guests inquire or book, conversations will appear here.';

  @override
  String get chatEmptyGuestTitle => 'No conversations yet';

  @override
  String get chatEmptyGuestDesc =>
      'Choose a villa and click \"Contact host\" to start a chat.';

  @override
  String get chatEmptyGuestAction => 'Explore villas';

  @override
  String get chatExtensionsAndTemplatesTitle => 'Extensions & Quick templates';

  @override
  String get chatSelectEmojiTitle => 'Choose emoji';

  @override
  String get chatSelectQuickEmojiTitle => 'Choose quick emoji';

  @override
  String get chatQuickReplyGuest1 => 'Is this villa available for these dates?';

  @override
  String get chatQuickReplyGuest2 =>
      'What are the check-in and check-out times?';

  @override
  String get chatQuickReplyGuest3 =>
      'Does the villa have a private pool and BBQ kitchen?';

  @override
  String get chatQuickReplyGuest4 => 'Thank you very much, host!';

  @override
  String get chatQuickReplyHost1 => 'Yes, we have received your information!';

  @override
  String get chatQuickReplyHost2 => 'What time will you be checking in?';

  @override
  String get chatQuickReplyHost3 => 'The Palm Villa welcomes you! 🌴';

  @override
  String get chatQuickReplyHost4 =>
      'Villa location has been updated on the system.';

  @override
  String get chatQuickReplyAdmin1 =>
      'Hello! How can system administration assist you?';

  @override
  String get chatQuickReplyAdmin2 =>
      'The system has received the request and is reviewing it.';

  @override
  String get chatQuickReplyAdmin3 =>
      'Your profile/listing status has been updated.';

  @override
  String get chatQuickReplyAdmin4 =>
      'Thank you for your feedback to the administration!';

  @override
  String get chatTplAdminDocsTitle => 'Request document supplement';

  @override
  String get chatTplAdminDocsSubtitle =>
      'Remind host or guest to update verification details';

  @override
  String get chatTplAdminDocsContent =>
      '📋 The administration requests that you check and submit clear verification documents for review.';

  @override
  String get chatTplHostLocationTitle => 'Send property location';

  @override
  String get chatTplHostLocationSubtitle => 'Detailed address and directions';

  @override
  String chatTplHostLocationContent(String villaTitle) {
    return '📍 Location of $villaTitle: Thuy Van St., Vung Tau City (near Back Beach).';
  }

  @override
  String get chatTplGuestInquiryTitle => 'Check availability & rate';

  @override
  String get chatTplGuestInquirySubtitle =>
      'Check room status and weekend surcharge';

  @override
  String get chatTplGuestInquiryContent =>
      '📅 Hello host, is this villa available this weekend and what is the total package rate for our group?';

  @override
  String get chatTplAdminReviewTitle => 'Review result notification';

  @override
  String get chatTplAdminReviewSubtitle => 'Update listing or account status';

  @override
  String get chatTplAdminReviewContent =>
      '✅ Administrators have reviewed and updated your listing/profile status on the system.';

  @override
  String get chatTplHostCheckinTitle => 'Check-in & Check-out times';

  @override
  String get chatTplHostCheckinSubtitle => 'Check-in: 14:00 • Check-out: 12:00';

  @override
  String get chatTplHostCheckinContent =>
      '⏰ Check-in time: from 14:00 | Check-out time: before 12:00 the next day.';

  @override
  String get chatTplGuestCheckinTitle =>
      'Early check-in / late check-out request';

  @override
  String get chatTplGuestCheckinSubtitle =>
      'Inquire about flexible check-in / check-out';

  @override
  String get chatTplGuestCheckinContent =>
      '⏰ We expect to arrive a bit earlier than 14:00, could you support early check-in or luggage storage?';

  @override
  String get chatTplAdminPolicyTitle => 'Platform policy guidance';

  @override
  String get chatTplAdminPolicySubtitle =>
      'Explain booking policies and service fees';

  @override
  String get chatTplAdminPolicyContent =>
      'ℹ️ All transactions on the system are protected under the transparent booking and cancellation policy of The Palm Villa.';

  @override
  String get chatTplHostHouseRulesTitle => 'Send house rules';

  @override
  String get chatTplHostHouseRulesSubtitle =>
      'Keep clean, quiet hours after 22:00';

  @override
  String get chatTplHostHouseRulesContent =>
      '📋 House rules: Please respect common property and keep noise down after 22:00. Wish you a wonderful stay!';

  @override
  String get chatTplGuestAmenitiesTitle => 'Inquire about BBQ & pool amenities';

  @override
  String get chatTplGuestAmenitiesSubtitle =>
      'Grill, charcoal, floats, and parking';

  @override
  String get chatTplGuestAmenitiesContent =>
      '🔥 Does the villa come with a BBQ grill, kitchen utensils, private pool, and on-site parking?';

  @override
  String get chatToastUploadingPhoto => 'Uploading photo to Cloudflare R2...';

  @override
  String get chatToastUploadPhotoFailed => 'Photo upload failed';

  @override
  String get chatToastUploadingVoice =>
      'Uploading voice message to Cloudflare R2...';

  @override
  String get chatToastUploadVoiceFailed => 'Voice message upload failed';

  @override
  String get chatToastMicNoAudio =>
      'No microphone audio detected. Please grant microphone permission or speak louder.';

  @override
  String get chatToastMicAccessError =>
      'Cannot access microphone. Please grant microphone permission in your browser / device.';

  @override
  String get chatErrorNetwork => 'No network connection';

  @override
  String get chatErrorForbidden => 'Access denied';

  @override
  String get chatErrorUnauthorized => 'Session expired';

  @override
  String get chatErrorNotFound => 'Conversation not found';

  @override
  String get chatErrorRateLimit => 'Too many requests';

  @override
  String get chatErrorServer => 'Server error';

  @override
  String get chatErrorValidation => 'Invalid data';

  @override
  String get chatErrorGeneric => 'An error occurred';

  @override
  String get hostMsgBackToVilla => 'Back to villa details';

  @override
  String get hostMsgContactTitle => 'Contact Host';

  @override
  String hostMsgHostLabel(String name) {
    return 'Host: $name';
  }

  @override
  String get hostMsgDefaultHost => 'The Palm Villa Host';

  @override
  String get hostMsgFaqTitle => 'Frequently asked questions for Host:';

  @override
  String get hostMsgInputLabel => 'Message to Host ';

  @override
  String get hostMsgInputPlaceholder =>
      'Ask about availability, amenities, or special requests...';

  @override
  String get hostMsgSendAction => 'Send message & Open chat';

  @override
  String get hostMsgSendingAction => 'Sending message...';

  @override
  String get hostMsgQuestion1 =>
      'Hello host, is the villa available this weekend?';

  @override
  String get hostMsgQuestion2 =>
      'Is the pool freshwater or saltwater, and are there floats available?';

  @override
  String get hostMsgQuestion3 =>
      'Does the villa have a BBQ grill, charcoal, and complete cookware?';

  @override
  String get hostMsgQuestion4 =>
      'Can our group be accommodated for check-in before 14:00?';

  @override
  String galleryPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get galleryViewAllPhotosSemantic => 'View all photos';

  @override
  String gallerySpacePrefix(String type) {
    return 'Space: $type';
  }

  @override
  String get spaceBedroom => 'Bedroom';

  @override
  String get spaceLivingRoom => 'Living room';

  @override
  String get spaceKitchen => 'Kitchen';

  @override
  String get spaceBathroom => 'Bathroom';

  @override
  String get spacePool => 'Swimming pool';

  @override
  String get spaceExterior => 'Exterior';

  @override
  String get spaceView => 'View';

  @override
  String get spaceDining => 'Dining room';

  @override
  String get spaceOther => 'Other space';

  @override
  String get blogAllArticles => 'All articles';

  @override
  String get blogShareTooltip => 'Share article';

  @override
  String get blogShareInvalidLink => 'Invalid article link to share.';

  @override
  String get blogShareSuccess => 'Article link copied to clipboard';

  @override
  String get blogShareFailure => 'Unable to copy article link on this device.';

  @override
  String get blogNotFoundTitle => 'Article not found';

  @override
  String get blogNotFoundDescription =>
      'This article may have been removed or the link is incorrect.';

  @override
  String get blogBackToBlog => 'Back to Travel Guides';

  @override
  String get blogLoadingArticle => 'Loading article...';

  @override
  String get blogRelatedArticlesBadge => 'RELATED ARTICLES';

  @override
  String get blogRelatedArticlesTitle => 'Recommended reading';

  @override
  String get blogViewAllArticles => 'View all articles';

  @override
  String blogReadMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes mins read',
      one: '1 min read',
    );
    return '$_temp0';
  }

  @override
  String get blogDefaultAuthor => 'The Palm Editorial Team';

  @override
  String get blogListBadge => 'VUNG TAU TRAVEL GUIDE';

  @override
  String get blogListHeroTitle =>
      'Stay guides, itineraries & secrets to booking Vung Tau beach villas';

  @override
  String get blogSearchHint => 'Search Vung Tau travel guides...';

  @override
  String get blogClearSearchTooltip => 'Clear search query';

  @override
  String get blogCategoryAll => 'All';

  @override
  String get blogCategoryTravelGuide => 'Travel Guide';

  @override
  String get blogCategoryReviews => 'Villa & Homestay Reviews';

  @override
  String get blogCategoryTripGuide => 'Trip Guide';

  @override
  String get blogCategoryBookingTips => 'Booking Tips';

  @override
  String get blogCategoryLocalDiscovery => 'Local Discovery';

  @override
  String get blogCategoryStayTips => 'Stay Tips';

  @override
  String get blogCategoryNearBeach => 'Near Beach Villas';

  @override
  String get blogCategoryBookingChecklist => 'Booking Checklist';

  @override
  String get blogEmptyTitle => 'No articles found';

  @override
  String get blogEmptyDescription =>
      'Try choosing another category or keyword.';

  @override
  String get blogClearFilters => 'Reset filters';

  @override
  String get blogLoadingList => 'Loading articles...';

  @override
  String get blogPaginationPrev => 'Previous page';

  @override
  String get blogPaginationNext => 'Next page';

  @override
  String blogPaginationPage(int page) {
    return 'Page $page';
  }

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

  @override
  String get homeEmptyApprovedVillas =>
      'No approved villas are available right now.';

  @override
  String homeApprovedVillasCountTitle(int count) {
    return 'Verified Stays ($count)';
  }

  @override
  String get homePrevVillaTooltip => 'Previous villa';

  @override
  String get homeNextVillaTooltip => 'Next villa';

  @override
  String get homeFavoriteAdd => 'Save to wishlist';

  @override
  String get homeFavoriteRemove => 'Remove from wishlist';

  @override
  String homeCardSpecsSummary(int bedrooms, int guests) {
    return '$bedrooms BR · Up to $guests guests';
  }

  @override
  String get searchFilterBtn => 'Filters';

  @override
  String searchFilterActiveBtn(int count) {
    return 'Filters ($count)';
  }

  @override
  String get searchShowMapBtn => 'Show map';

  @override
  String get searchHideMapBtn => 'Hide map';

  @override
  String get searchClearAllBtn => 'Clear all';

  @override
  String searchFoundStaysCount(int count) {
    return 'Found $count stays in Vung Tau';
  }

  @override
  String favoritesSavedCountSubtitle(int count) {
    return '$count saved villas';
  }

  @override
  String get favoritesSyncOfflineNotice =>
      'Unable to sync with server — showing locally saved villas.';

  @override
  String favoritesInvalidCountNotice(int count) {
    return '$count saved stays are no longer accepting bookings.';
  }

  @override
  String get favoritesExploreAction => 'Explore villas';

  @override
  String get contactEyebrow => 'DIRECT VUNG TAU SUPPORT';

  @override
  String get contactBrowseVillas => 'Browse Villas';

  @override
  String get contactHeroTitle =>
      'Contact our stay advisors & local operations team';

  @override
  String get contactHeroSubtitle =>
      'Get help checking live availability, matching villas for your group, and planning your stay in Vung Tau City.';

  @override
  String get contactHotlineTitle => 'Hotline & Zalo support';

  @override
  String get contactVerifiedBadge => 'Verified';

  @override
  String get contactCallNow => 'Call now';

  @override
  String get contactCopyHotlineTooltip => 'Copy Hotline';

  @override
  String get contactCopiedHotline => 'Hotline copied to clipboard';

  @override
  String get contactOpenZalo => 'Chat on Zalo OA';

  @override
  String get contactOfficeTitle => 'Vung Tau Reception Office';

  @override
  String get contactMapAction => 'Open directions map';

  @override
  String get contactEmailTitle => 'Support & billing email';

  @override
  String get contactSameDayReply => 'Same-day response';

  @override
  String get contactSendEmail => 'Send support email';

  @override
  String get contactCopyEmailTooltip => 'Copy Email';

  @override
  String get contactCopiedEmail => 'Email copied to clipboard';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authLoginSubtitle =>
      'Sign in to view your getaways and manage your trips at The Palm Villa.';

  @override
  String get authIdentifierLabel => 'Email or phone number';

  @override
  String get authIdentifierHint => 'Enter email or Vietnam phone number';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint => 'Enter password';

  @override
  String get authShowPasswordTooltip => 'Show password';

  @override
  String get authHidePasswordTooltip => 'Hide password';

  @override
  String get authRememberMe => 'Remember me';

  @override
  String get authSigningIn => 'Signing in...';

  @override
  String get authOrDivider => 'OR';

  @override
  String get authGoogleLoginBtn => 'Sign in with Google';

  @override
  String get authNoAccountYet => 'Don\'t have an account?';

  @override
  String get authRegisterBtn => 'Sign up';

  @override
  String get authCreateAccountTitle => 'Create a new account';

  @override
  String get authRegisterSubtitle =>
      'Book verified private vacation villas and unlock member-only offers.';

  @override
  String get authFullNameLabel => 'Full name';

  @override
  String get authFullNameHint => 'Enter your full name';

  @override
  String get authPhoneRequiredLabel => 'Phone number *';

  @override
  String get authPhoneHint => 'Enter Vietnam phone number (e.g. 0901234567)';

  @override
  String get authEmailRequiredLabel => 'Email *';

  @override
  String get authEmailHint => 'Enter email address';

  @override
  String get authPasswordCreateHint =>
      'Create password (min 8 chars, letters & numbers)';

  @override
  String get authConfirmPasswordLabel => 'Confirm password *';

  @override
  String get authConfirmPasswordHint => 'Re-enter your password';

  @override
  String authPasswordStrengthLabel(String level) {
    return 'Password strength: $level';
  }

  @override
  String get authStrengthWeak => 'Weak';

  @override
  String get authStrengthFair => 'Fair';

  @override
  String get authStrengthGood => 'Good';

  @override
  String get authStrengthStrong => 'Strong';

  @override
  String get authTermsAgreement =>
      'I agree to The Palm Villa Terms of Service and Privacy Policy';

  @override
  String get authTermsRequiredError =>
      'Please accept the Terms of Service and Privacy Policy';

  @override
  String get authCreatingAccount => 'Creating account...';

  @override
  String get authAlreadyHaveAccount => 'Already have an account?';

  @override
  String get authForgotQuestionTitle => 'Forgot password?';

  @override
  String get authOtpVerifyTitle => 'Verify OTP code';

  @override
  String get authPasswordChangedTitle => 'Password reset complete';

  @override
  String get authForgotRequestSubtitle =>
      'Enter your registered email or phone number to receive a 6-digit recovery OTP.';

  @override
  String get authForgotOtpSubtitle =>
      'Enter the 6-digit OTP code and set your new password.';

  @override
  String get authForgotSuccessSubtitle =>
      'Your password has been updated securely.';

  @override
  String get authSendOtpButton => 'Send OTP code';

  @override
  String authOtpSentTo(String target) {
    return 'OTP sent to: $target';
  }

  @override
  String get authOtpSixDigitsLabel => '6-digit OTP code';

  @override
  String get authNewPasswordLabel => 'New password';

  @override
  String authResendOtpCountdown(String seconds) {
    return 'Resend in 00:$seconds';
  }

  @override
  String get authResendOtpButton => 'Resend OTP code';

  @override
  String get authConfirmOtpButton => 'Verify OTP code';

  @override
  String get authOtpSuccessBanner =>
      'OTP verified and your new password is ready to use.';

  @override
  String get authBackToLoginButton => 'Back to sign in';

  @override
  String get adminTabFinance => 'Finance & Payouts';

  @override
  String get adminTabBlog => 'Blog CMS';

  @override
  String get adminTabTrustSafety => 'Reports & Safety';
}
