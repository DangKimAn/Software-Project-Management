import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../shared/widgets/app_dialog.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../theme/admin_studio_tokens.dart';
import '../view_models/admin_portal_view_model.dart';
import 'admin_studio_widgets.dart';

/// Tab quản trị tiếp nhận, phân loại và xử lý báo cáo vi phạm (`GET/PATCH /api/admin/reports`, `TC-095`).
class AdminReportsTab extends ConsumerStatefulWidget {
  /// Khởi tạo tab Quản lý báo cáo vi phạm trong Admin Studio.
  const AdminReportsTab({super.key});

  @override
  ConsumerState<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends ConsumerState<AdminReportsTab> {
  String _statusFilter = 'open';
  String _targetTypeFilter = 'all';
  int _page = 1;
  final int _limit = 20;
  int _total = 0;
  int _totalPages = 1;
  bool _loading = true;
  String? _error;
  String? _processingId;
  List<Map<String, dynamic>> _reports = const [];

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  // Giải thuật tải danh sách báo cáo vi phạm có phân trang theo trạng thái (`open`, `resolved`, `rejected`, `all`) và loại đối tượng.
  Future<void> _fetchReports() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await ref.read(adminPortalViewModelProvider).getAdminReportsPaginated(
                status: _statusFilter,
                targetType: _targetTypeFilter,
                page: _page,
                limit: _limit,
              );
      if (!mounted) return;
      setState(() {
        _reports = result.items;
        _page = result.page;
        _total = result.total;
        _totalPages = result.totalPages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AdminPortalViewModel.extractErrorMessage(
          e,
          'Không thể tải danh sách báo cáo vi phạm.',
        );
      });
    }
  }

  // Giải thuật xử lý hoặc bác bỏ báo cáo vi phạm với ghi chú kết luận bắt buộc và đồng bộ lại danh sách.
  Future<void> _openDecisionDialog(
    Map<String, dynamic> report, {
    required bool resolve,
  }) async {
    final reportId = '${report['reportId'] ?? report['id'] ?? ''}'.trim();
    if (reportId.isEmpty || _processingId != null) return;

    final noteCtrl = TextEditingController();
    String? errorText;
    final confirmedNote = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AppModal(
          key: Key('admin_report_decision_dialog_$reportId'),
          title: resolve
              ? 'Xử lý báo cáo #$reportId'
              : 'Bác bỏ báo cáo #$reportId',
          subtitle: resolve
              ? 'Nhập kết luận xử lý vi phạm để lưu hồ sơ kiểm duyệt.'
              : 'Nhập lý do bác bỏ báo cáo này.',
          maxWidth: 460,
          actions: [
            OutlinedButton(
              style: AdminStudioTokens.secondaryPillButton,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              key: const Key('admin_report_confirm_decision_btn'),
              style: AdminStudioTokens.primaryPillButton,
              onPressed: () {
                final text = noteCtrl.text.trim();
                if (text.isEmpty) {
                  setModalState(() {
                    errorText = 'Vui lòng nhập nội dung ghi chú xử lý.';
                  });
                  return;
                }
                Navigator.of(ctx).pop(text);
              },
              child: Text(resolve ? 'Xác nhận xử lý' : 'Xác nhận bác bỏ'),
            ),
          ],
          child: TextField(
            key: const Key('admin_report_note_input'),
            controller: noteCtrl,
            maxLines: 3,
            decoration: AdminStudioTokens.multilineDecoration(
              hintText: resolve
                  ? 'Ví dụ: Đã nhắc nhở chủ nhà và ẩn nội dung vi phạm...'
                  : 'Ví dụ: Nội dung phản ánh không vi phạm quy chế sàn...',
              errorText: errorText,
            ),
          ),
        ),
      ),
    );
    noteCtrl.dispose();
    if (confirmedNote == null || !mounted) return;

    setState(() => _processingId = reportId);
    try {
      final vm = ref.read(adminPortalViewModelProvider);
      if (resolve) {
        await vm.resolveAdminReport(reportId, confirmedNote);
      } else {
        await vm.rejectAdminReport(reportId, confirmedNote);
      }
      if (!mounted) return;
      AppToast.show(
        context,
        resolve
            ? 'Đã xử lý báo cáo vi phạm #$reportId.'
            : 'Đã bác bỏ báo cáo #$reportId.',
        type: resolve ? AppToastType.success : AppToastType.info,
      );
      await _fetchReports();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AdminPortalViewModel.extractErrorMessage(
          e,
          'Không thể cập nhật trạng thái báo cáo.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _processingId = null);
      }
    }
  }

  Widget _buildStatusPill(String rawStatus) {
    final normalized = rawStatus.trim().toLowerCase();
    final (label, bg, fg) = switch (normalized) {
      'resolved' => (
          'Đã xử lý',
          AdminStudioTokens.successTint,
          AdminStudioTokens.successInk,
        ),
      'rejected' => (
          'Đã bác bỏ',
          AdminStudioTokens.dangerTint,
          AdminStudioTokens.dangerInk,
        ),
      _ => (
          'Chờ xử lý',
          AdminStudioTokens.warningTint,
          AdminStudioTokens.warningInk,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AdminStudioTokens.pillRadius),
      ),
      child: Text(
        label,
        style: AdminStudioTokens.metaCaption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(authNotifierProvider).valueOrNull;
    final canManage = actor != null &&
        (actor.role.toLowerCase() == 'admin' ||
            actor.roles.any((r) => r.toLowerCase() == 'admin'));
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 380 ? 12.0 : (width < 640 ? 16.0 : 24.0);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, 10, pad, width >= 1024 ? 48 : 112),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminStudioSegmentedBar<String>(
                selectedValue: _statusFilter,
                items: const [
                  AdminStudioSegmentItem(value: 'open', label: 'Chờ xử lý'),
                  AdminStudioSegmentItem(value: 'resolved', label: 'Đã xử lý'),
                  AdminStudioSegmentItem(value: 'rejected', label: 'Đã bác bỏ'),
                  AdminStudioSegmentItem(value: 'all', label: 'Tất cả'),
                ],
                onSelected: _loading
                    ? null
                    : (next) {
                        if (next == _statusFilter) return;
                        setState(() {
                          _statusFilter = next;
                          _page = 1;
                        });
                        _fetchReports();
                      },
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  ('all', 'Mọi loại'),
                  ('listing', 'Chỗ nghỉ'),
                  ('user', 'Người dùng'),
                  ('message', 'Tin nhắn'),
                  ('review', 'Đánh giá'),
                  ('booking', 'Đặt phòng'),
                ].map((opt) {
                  final selected = _targetTypeFilter == opt.$1;
                  return ChoiceChip(
                    key: Key('admin_reports_type_${opt.$1}'),
                    label: Text(opt.$2),
                    selected: selected,
                    onSelected: _loading
                        ? null
                        : (_) {
                            setState(() {
                              _targetTypeFilter = opt.$1;
                              _page = 1;
                            });
                            _fetchReports();
                          },
                  );
                }).toList(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AdminStudioInnerCard(
                  warningHighlight: true,
                  padding: const EdgeInsets.all(14),
                  child: Text(_error!, style: AdminStudioTokens.bodyRegular),
                ),
              ],
              const SizedBox(height: 14),
              AdminStudioGroupCard(
                title: 'Danh sách báo cáo ($_total)',
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _reports.isEmpty
                        ? const AdminStudioInnerCard(
                            padding: EdgeInsets.all(28),
                            child: Center(
                              child: Text(
                                'Không có báo cáo vi phạm nào trong bộ lọc hiện tại.',
                                style: AdminStudioTokens.cardSubtitle,
                              ),
                            ),
                          )
                        : Column(
                            children: _reports.map((item) {
                              final id =
                                  '${item['reportId'] ?? item['id'] ?? ''}';
                              final status =
                                  '${item['status'] ?? 'open'}'.toLowerCase();
                              final targetType =
                                  '${item['targetType'] ?? 'listing'}';
                              final targetId = '${item['targetId'] ?? ''}';
                              final reason = '${item['reason'] ?? ''}'.trim();
                              final description =
                                  '${item['description'] ?? ''}'.trim();
                              final resolution =
                                  '${item['resolution'] ?? ''}'.trim();

                              return AdminStudioInnerCard(
                                key: ValueKey('admin-report-row-$id'),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'Báo cáo #$id · $targetType #$targetId',
                                          style: AdminStudioTokens.cardTitle,
                                        ),
                                        _buildStatusPill(status),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Lý do: $reason',
                                      style: AdminStudioTokens.bodyRegular,
                                    ),
                                    if (description.isNotEmpty &&
                                        description != 'null') ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Chi tiết: $description',
                                        style: AdminStudioTokens.cardSubtitle,
                                      ),
                                    ],
                                    if (resolution.isNotEmpty &&
                                        resolution != 'null') ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Kết luận Admin: $resolution',
                                        style: AdminStudioTokens.metaCaption
                                            .copyWith(
                                          color: AdminStudioTokens.inkPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    if (status == 'open' && canManage) ...[
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ElevatedButton.icon(
                                            key: Key(
                                              'admin_report_resolve_btn_$id',
                                            ),
                                            style: AdminStudioTokens
                                                .compactPrimaryPillButton,
                                            onPressed: _processingId == id
                                                ? null
                                                : () => _openDecisionDialog(
                                                      item,
                                                      resolve: true,
                                                    ),
                                            icon: const Icon(
                                              LucideIcons.circleCheck,
                                              size: 14,
                                            ),
                                            label: const Text('Xử lý vi phạm'),
                                          ),
                                          OutlinedButton.icon(
                                            key: Key(
                                              'admin_report_reject_btn_$id',
                                            ),
                                            style: AdminStudioTokens
                                                .compactSecondaryPillButton,
                                            onPressed: _processingId == id
                                                ? null
                                                : () => _openDecisionDialog(
                                                      item,
                                                      resolve: false,
                                                    ),
                                            icon: const Icon(
                                              LucideIcons.x,
                                              size: 14,
                                            ),
                                            label: const Text('Bác bỏ'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
              ),
              if (!_loading && _totalPages > 1) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      style: AdminStudioTokens.compactSecondaryPillButton,
                      onPressed: _page <= 1
                          ? null
                          : () {
                              setState(() => _page -= 1);
                              _fetchReports();
                            },
                      child: const Text('Trang trước'),
                    ),
                    Text(
                      'Trang $_page / $_totalPages',
                      style: AdminStudioTokens.metaCaption,
                    ),
                    OutlinedButton(
                      style: AdminStudioTokens.compactSecondaryPillButton,
                      onPressed: _page >= _totalPages
                          ? null
                          : () {
                              setState(() => _page += 1);
                              _fetchReports();
                            },
                      child: const Text('Trang sau'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
