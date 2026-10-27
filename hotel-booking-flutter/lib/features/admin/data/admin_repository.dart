import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/features/admin/data/admin_api_client.dart';

export 'package:hotel_booking_flutter/features/admin/data/admin_api_client.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(dioClientProvider).dio);
});
