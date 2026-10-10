class Booking {
  final String id;
  final String listingId;
  final String propertyName;
  final String? coverImageUrl;
  final String checkInDate;
  final String checkOutDate;
  final int nights;
  final int totalAmount;
  final int guestCount;
  final String
      status; // active, completed, cancelled, confirmed, checked_in, checked_out
  final String? address;
  final String? cancellationReason;
  final DateTime? createdAt;

  const Booking({
    required this.id,
    required this.listingId,
    required this.propertyName,
    this.coverImageUrl,
    required this.checkInDate,
    required this.checkOutDate,
    required this.nights,
    required this.totalAmount,
    required this.guestCount,
    required this.status,
    this.address,
    this.cancellationReason,
    this.createdAt,
  });

  bool get isCancelled =>
      status == 'cancelled' ||
      status == 'rejected' ||
      status == 'refunded' ||
      status == 'payment_expired';

  bool get isCompleted => status == 'completed' || status == 'checked_out';

  bool get isActive => !isCancelled && !isCompleted;

  String get statusDisplay {
    switch (status) {
      case 'confirmed':
        return 'Đã xác nhận';
      case 'checked_in':
        return 'Đang lưu trú';
      case 'completed':
      case 'checked_out':
        return 'Đã hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      case 'pending':
        return 'Chờ xác nhận';
      default:
        return 'Đang xử lý';
    }
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    final listing = json['listing'] as Map<String, dynamic>?;
    final listingTitle = listing?['title']?.toString() ??
        json['propertyName']?.toString() ??
        'Chỗ nghỉ #${json['listingId']}';

    String? coverImg;
    if (listing != null) {
      coverImg = listing['coverImageUrl']?.toString() ??
          (listing['coverImage'] is Map
              ? listing['coverImage']['url']?.toString()
              : null) ??
          listing['imageUrl']?.toString();
    }
    coverImg ??= json['imageUrl']?.toString();

    final checkIn = json['checkInDate']?.toString() ?? '';
    final checkOut = json['checkOutDate']?.toString() ?? '';

    int calculatedNights = (json['nights'] as num?)?.toInt() ?? 1;
    if (checkIn.isNotEmpty && checkOut.isNotEmpty && calculatedNights <= 0) {
      final inD = DateTime.tryParse(checkIn);
      final outD = DateTime.tryParse(checkOut);
      if (inD != null && outD != null) {
        calculatedNights = outD.difference(inD).inDays;
      }
    }

    return Booking(
      id: (json['bookingId'] ?? json['id'])?.toString() ?? '',
      listingId: (json['listingId'] ?? listing?['listingId'])?.toString() ?? '',
      propertyName: listingTitle,
      coverImageUrl: coverImg,
      checkInDate: checkIn,
      checkOutDate: checkOut,
      nights: calculatedNights > 0 ? calculatedNights : 1,
      totalAmount:
          ((json['totalAmount'] ?? json['totalPrice']) as num?)?.toInt() ?? 0,
      guestCount:
          ((json['guestCount'] ?? json['guestsCount']) as num?)?.toInt() ?? 1,
      status: json['status']?.toString() ?? 'pending',
      address: listing?['addressLine']?.toString(),
      cancellationReason: json['cancellationReason']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
