import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/features/admin/data/admin_api_client.dart';

export 'package:hotel_booking_flutter/features/admin/data/admin_api_client.dart';

/// Riverpod provider khởi tạo và cung cấp `AdminRepository` dùng chung cho phân hệ Quản trị viên.
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(dioClientProvider).dio);
});
