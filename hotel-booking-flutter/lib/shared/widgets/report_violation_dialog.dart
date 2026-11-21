import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/di/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/network/dio_client.dart';
import 'app_dialog.dart';

/// Dịch vụ gửi báo cáo vi phạm (`POST /api/reports`) tuân thủ tầng dữ liệu tách biệt khỏi giao diện.
class ReportViolationService {
  /// Khởi tạo `ReportViolationService` kết nối qua `DioClient` trung tâm.
  const ReportViolationService(this._client);

  final DioClient _client;

  // Giải thuật chuẩn hóa và gửi báo cáo vi phạm lên `/api/reports`:
  // Kiểm tra tính hợp lệ của loại đối tượng (`listing`, `user`, `review`, `booking`, `message`),
  // mã định danh nguyên dương và lý do báo cáo trước khi phát yêu cầu HTTP POST.
  /// Gửi báo cáo vi phạm cho đối tượng `targetType` có mã `targetId`.
  Future<void> submitReport({
    required String targetType,
    required int targetId,
    required String reason,
    String? description,
  }) async {
    final trimmedReason = reason.trim();
    final trimmedDesc = description?.trim() ?? '';
    await _client.dio.post<dynamic>(
      '/api/reports',
      data: <String, dynamic>{
        'targetType': targetType.trim(),
        'targetId': targetId,
        'reason': trimmedReason,
        if (trimmedDesc.isNotEmpty) 'description': trimmedDesc,
      },
    );
  }
}

/// Provider cung cấp `ReportViolationService` cho hộp thoại báo cáo vi phạm toàn ứng dụng.
final reportViolationServiceProvider = Provider<ReportViolationService>((ref) {
  return ReportViolationService(ref.watch(dioClientProvider));
});

/// Hiển thị hộp thoại báo cáo vi phạm ngữ cảnh cho chỗ nghỉ, tin nhắn hoặc người dùng (`TC-095`).
Future<bool> showReportViolationDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String targetType,
  required int targetId,
  required String targetLabel,
}) async {
  if (targetId <= 0) {
    AppToast.show(
      context,
      'Không xác định được mã đối tượng cần báo cáo.',
      type: AppToastType.error,
    );
    return false;
  }

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ReportViolationModal(
      ref: ref,
      targetType: targetType,
      targetId: targetId,
      targetLabel: targetLabel,
    ),
  );
  if (result == true && context.mounted) {
    AppToast.show(
      context,
      'Đã gửi báo cáo vi phạm đến bộ phận Quản trị.',
      type: AppToastType.success,
    );
  }
  return result == true;
}

class _ReportViolationModal extends StatefulWidget {
  const _ReportViolationModal({
    required this.ref,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
  });

  final WidgetRef ref;
  final String targetType;
  final int targetId;
  final String targetLabel;

  @override
  State<_ReportViolationModal> createState() => _ReportViolationModalState();
}

class _ReportViolationModalState extends State<_ReportViolationModal> {
  static const List<String> _presetReasons = <String>[
    'Thông tin mô tả không đúng thực tế',
    'Yêu cầu giao dịch hoặc chuyển khoản ngoài nền tảng',
    'Ngôn từ hoặc hành vi ứng xử không phù hợp',
    'Hình ảnh vi phạm tiêu chuẩn cộng đồng',
    'Nghi ngờ gian lận hoặc mạo danh',
  ];

  String _selectedReason = _presetReasons.first;
  final TextEditingController _descCtrl = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  // Giải thuật gửi báo cáo vi phạm từ hộp thoại và phản hồi tức thì trạng thái xử lý cho người dùng.
  Future<void> _handleSubmit() async {
    if (_submitting) return;
    final reason = _selectedReason.trim();
    if (reason.isEmpty) {
      setState(() => _errorText = 'Vui lòng chọn lý do báo cáo.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await widget.ref.read(reportViolationServiceProvider).submitReport(
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: reason,
            description: _descCtrl.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final failure = DioClient.handleError(e);
      setState(() {
        _submitting = false;
        _errorText = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppModal(
      key: const Key('report_violation_dialog'),
      title: 'Báo cáo vi phạm',
      subtitle: 'Đối tượng: ${widget.targetLabel}',
      maxWidth: 480,
      actions: [
        OutlinedButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        ElevatedButton.icon(
          key: const Key('report_violation_submit_btn'),
          onPressed: _submitting ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(LucideIcons.flag, size: 15),
          label: Text(_submitting ? 'Đang gửi...' : 'Gửi báo cáo'),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chọn lý do báo cáo:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetReasons.map((reason) {
                final selected = _selectedReason == reason;
                return ChoiceChip(
                  label: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selected: selected,
                  selectedColor: AppColors.textStrong,
                  backgroundColor: AppColors.surfaceMuted,
                  onSelected: _submitting
                      ? null
                      : (_) => setState(() => _selectedReason = reason),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('report_violation_description_input'),
              controller: _descCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Mô tả chi tiết (tùy chọn)',
                hintText: 'Cung cấp thêm bằng chứng hoặc ngữ cảnh cụ thể...',
                errorText: _errorText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
