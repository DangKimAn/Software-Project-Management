import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hotel_booking_flutter/features/admin/presentation/view_models/admin_portal_view_model.dart';
import 'package:hotel_booking_flutter/features/admin/presentation/theme/admin_studio_tokens.dart';
import 'package:hotel_booking_flutter/features/admin/presentation/widgets/admin_studio_widgets.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Giải thuật hiển thị chứng từ định danh KYC bảo mật cho Quản trị viên:
/// 1. Tải dữ liệu nhị phân (`Uint8List`) qua kênh xác thực Header (`Authorization` + `X-Document-Stream-Token`),
///    không nhúng token vào URL query string hay mở trình duyệt ngoài làm lộ phiên xem tài liệu.
/// 2. Hiển thị ảnh trực tiếp trong bộ nhớ (`Image.memory`) và hỗ trợ phóng to nội bộ bằng `InteractiveViewer`.
class AdminKycDocumentViewer extends StatefulWidget {
  /// Khởi tạo khung xem chứng từ định danh KYC bảo mật cho hồ sơ `applicationId`.
  const AdminKycDocumentViewer({
    super.key,
    required this.viewModel,
    required this.applicationId,
    required this.document,
  });

  final AdminPortalViewModel viewModel;
  final String applicationId;
  final Map<String, dynamic> document;

  /// Tạo đối tượng quản lý trạng thái tải dữ liệu nhị phân chứng từ KYC.
  @override
  State<AdminKycDocumentViewer> createState() => _AdminKycDocumentViewerState();
}

class _AdminKycDocumentViewerState extends State<AdminKycDocumentViewer> {
  Uint8List? _bytes;
  bool _loading = false;
  String? _errorMessage;

  String get _documentId => '${widget.document['id'] ?? ''}'.trim();
  String get _mimeType =>
      '${widget.document['mimeType'] ?? ''}'.trim().toLowerCase();
  String get _streamToken => '${widget.document['streamToken'] ?? ''}'.trim();
  String get _legacyUrl {
    final raw =
        '${widget.document['url'] ?? widget.document['fileUrl'] ?? widget.document['documentUrl'] ?? ''}'
            .trim();
    return (raw == 'null' || raw == '-') ? '' : raw;
  }

  bool get _isPdf =>
      _mimeType == 'application/pdf' ||
      _legacyUrl.toLowerCase().endsWith('.pdf');

  @override
  void initState() {
    super.initState();
    if (!_isPdf && _documentId.isNotEmpty && widget.applicationId.isNotEmpty) {
      _loadBytes();
    }
  }

  Future<void> _loadBytes() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final data = await widget.viewModel.fetchAdminHostDocumentBytes(
        widget.applicationId,
        _documentId,
        streamToken: _streamToken,
      );
      if (!mounted) return;
      setState(() {
        _bytes = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = AdminPortalViewModel.extractErrorMessage(
          e,
          'Không thể tải ảnh chứng từ KYC.',
        );
      });
    }
  }

  Future<void> _openZoomDialog() async {
    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AdminStudioTokens.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminStudioTokens.cardRadius),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${widget.document['documentType'] ?? 'cccd'} · ${widget.document['side'] ?? 'front'}',
                        style: AdminStudioTokens.cardTitle,
                      ),
                    ),
                    AdminStudioCircleButton(
                      icon: LucideIcons.x,
                      tooltip: 'Đóng xem phóng to',
                      circleColor: AdminStudioTokens.softCircle,
                      onTap: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docTitle =
        '${widget.document['documentType'] ?? 'cccd'} / ${widget.document['side'] ?? 'front'}';
    final filename = '${widget.document['originalFilename'] ?? ''}'.trim();

    return AdminStudioInnerCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(docTitle, style: AdminStudioTokens.cardTitle),
          if (filename.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(filename, style: AdminStudioTokens.cardSubtitle),
          ],
          const SizedBox(height: 8),
          if (_isPdf)
            const Text(
              'Chứng từ định dạng PDF đã lưu trữ an toàn trên kho KYC riêng tư.',
              style: AdminStudioTokens.bodyRegular,
            )
          else if (_loading)
            const SizedBox(
              height: 140,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_errorMessage != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: AdminStudioTokens.bodyRegular.copyWith(
                      color: AdminStudioTokens.dangerInk,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _loadBytes,
                  child: const Text('Thử lại'),
                ),
              ],
            )
          else if (_bytes != null && _bytes!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                _bytes!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openZoomDialog,
              icon: const Icon(LucideIcons.zoomIn, size: 16),
              label: const Text('Xem phóng to tài liệu'),
            ),
          ] else if (_documentId.isEmpty && _legacyUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AppImage(
                imageUrl: _legacyUrl,
                height: 180,
                width: double.infinity,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
