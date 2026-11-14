import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../view_models/admin_portal_view_model.dart';

/// Thanh công cụ đối soát & tạo lô chi trả theo quy trình kiểm soát chéo Maker-Checker 3 bước (`TC-093`).
class AdminPayoutMakerCheckerBar extends StatelessWidget {
  /// Khởi tạo thanh công cụ tạo lô chi trả cho Quản trị viên.
  const AdminPayoutMakerCheckerBar({
    super.key,
    required this.onCreateBatch,
  });

  final VoidCallback onCreateBatch;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quy trình kiểm soát chéo Maker-Checker (3 bước)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Bước 1: Admin lập lô chi trả · Bước 2: Admin độc lập duyệt lệnh · Bước 3: Xác nhận mã giao dịch FT hoặc giải ngân Napas 24/7.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            key: const Key('admin_create_payout_batch_btn'),
            onPressed: onCreateBatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textStrong,
              foregroundColor: AppColors.textInverse,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(LucideIcons.plus, size: 15),
            label: const Text('Tạo lô chi trả'),
          ),
        ],
      ),
    );
  }
}

// Giải thuật kiểm tra đầu vào và khởi tạo lô chi trả Chủ nhà (`POST /api/admin/host-payouts`):
// Tách chuỗi mã đơn đặt phòng phân cách bởi dấu phẩy thành mảng số nguyên dương `bookingIds`,
// đối chiếu `hostId`, `payoutAccountId` và số tiền VNĐ nguyên dương trước khi gửi lên ViewModel.
/// Mở hộp thoại lập lô chi trả thủ công (Bước 1 - Maker) cho Chủ nhà.
Future<bool> showCreateAdminPayoutBatchDialog({
  required BuildContext context,
  required AdminPortalViewModel viewModel,
}) async {
  final hostIdCtrl = TextEditingController();
  final bookingIdsCtrl = TextEditingController();
  final payoutAccountCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  String? fieldError;
  bool submitting = false;

  final created = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        Future<void> submit() async {
          final hostId = int.tryParse(hostIdCtrl.text.trim()) ?? 0;
          final accountId = int.tryParse(payoutAccountCtrl.text.trim()) ?? 0;
          final amount = int.tryParse(
                amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
              ) ??
              0;
          final bookingIds = bookingIdsCtrl.text
              .split(RegExp(r'[,\s]+'))
              .map((s) => int.tryParse(s.trim()) ?? 0)
              .where((id) => id > 0)
              .toSet()
              .toList();

          if (hostId <= 0 ||
              accountId <= 0 ||
              amount <= 0 ||
              bookingIds.isEmpty) {
            setModalState(() {
              fieldError =
                  'Vui lòng nhập đầy đủ Host ID, mã tài khoản nhận, mã booking và số tiền hợp lệ.';
            });
            return;
          }

          setModalState(() {
            submitting = true;
            fieldError = null;
          });
          try {
            await viewModel.createAdminHostPayout(
              hostId: hostId,
              bookingIds: bookingIds,
              payoutAccountId: accountId,
              amount: amount,
              notes: notesCtrl.text.trim(),
            );
            if (ctx.mounted) {
              Navigator.of(ctx).pop(true);
            }
          } catch (e) {
            if (ctx.mounted) {
              setModalState(() {
                submitting = false;
                fieldError = AdminPortalViewModel.extractErrorMessage(
                  e,
                  'Không thể tạo lô chi trả.',
                );
              });
            }
          }
        }

        return AppModal(
          key: const Key('admin_create_payout_batch_dialog'),
          title: 'Tạo lô chi trả Chủ nhà (Maker)',
          subtitle:
              'Khởi tạo lệnh chi trả mới chờ Quản trị viên thứ hai phê duyệt.',
          maxWidth: 480,
          actions: [
            OutlinedButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              key: const Key('admin_submit_payout_batch_btn'),
              onPressed: submitting ? null : submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(submitting ? 'Đang tạo...' : 'Tạo lô chi trả'),
            ),
          ],
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (fieldError != null) ...[
                  Text(
                    fieldError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.errorRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  key: const Key('payout_batch_host_id_input'),
                  controller: hostIdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Mã Chủ nhà (Host ID) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('payout_batch_account_id_input'),
                  controller: payoutAccountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Mã tài khoản ngân hàng (Payout Account ID) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('payout_batch_booking_ids_input'),
                  controller: bookingIdsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Danh sách Booking ID (cách nhau dấu phẩy) *',
                    hintText: 'Ví dụ: 101, 102',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('payout_batch_amount_input'),
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số tiền chi trả (VND) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('payout_batch_notes_input'),
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú đối soát',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  hostIdCtrl.dispose();
  bookingIdsCtrl.dispose();
  payoutAccountCtrl.dispose();
  amountCtrl.dispose();
  notesCtrl.dispose();
  return created == true;
}

// Giải thuật xác nhận mã bút toán chuyển khoản ngân hàng (`PATCH /api/admin/host-payouts/:id/paid`) ở bước cuối Maker-Checker.
/// Mở hộp thoại nhập mã tham chiếu chuyển khoản `transferReference` (Bước 3 - Disburser).
Future<String?> showMarkPayoutPaidDialog({
  required BuildContext context,
  required String payoutId,
}) async {
  final refCtrl = TextEditingController();
  String? errorText;

  final confirmedRef = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => AppModal(
        key: const Key('admin_mark_payout_paid_dialog'),
        title: 'Xác nhận đã chuyển khoản',
        subtitle: 'Nhập mã giao dịch ngân hàng (FT/UNC) cho Payout #$payoutId.',
        maxWidth: 440,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            key: const Key('admin_confirm_payout_paid_btn'),
            onPressed: () {
              final trimmed = refCtrl.text.trim();
              if (trimmed.isEmpty) {
                setModalState(() {
                  errorText = 'Vui lòng nhập mã giao dịch chuyển khoản (FT).';
                });
                return;
              }
              Navigator.of(ctx).pop(trimmed);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận hoàn tất'),
          ),
        ],
        child: TextField(
          key: const Key('payout_transfer_reference_input'),
          controller: refCtrl,
          decoration: InputDecoration(
            labelText: 'Mã giao dịch chuyển khoản (FT / Napas) *',
            hintText: 'Ví dụ: FT26318000123',
            errorText: errorText,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    ),
  );

  refCtrl.dispose();
  return confirmedRef;
}
