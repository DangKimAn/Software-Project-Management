import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/security/url_security_validator.dart';
import '../../domain/host_models.dart';
import '../view_models/host_sheet_sync_notifier.dart';

typedef ExternalSpreadsheetLauncher = Future<bool> Function(Uri uri);

Future<bool> _defaultExternalSpreadsheetLauncher(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

class HostSheetSyncCard extends ConsumerWidget {
  final VoidCallback? onCalendarChanged;
  final ExternalSpreadsheetLauncher externalLauncher;

  const HostSheetSyncCard({
    super.key,
    this.onCalendarChanged,
    this.externalLauncher = _defaultExternalSpreadsheetLauncher,
  });

  static String _formatDateTimeVi(DateTime? dt) {
    if (dt == null) return 'Chưa có lượt đồng bộ';
    final local = dt.toLocal();
    return DateFormat('HH:mm · dd/MM/yyyy').format(local);
  }

  Future<void> _copyText(
    BuildContext context,
    String value,
    String label,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Đã sao chép $label: $value'),
        ),
      );
  }

  Future<void> _handleOpenSpreadsheet(
    BuildContext context,
    HostSheetIntegrationInfo integration,
  ) async {
    final safeUrl = integration.safeSpreadsheetUrl;
    if (safeUrl == null ||
        !UrlSecurityValidator.isValidGoogleSpreadsheetUrl(
          safeUrl,
          expectedSpreadsheetId: integration.spreadsheetId,
        )) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Đường dẫn Google Sheets không vượt qua kiểm tra bảo mật.',
            ),
          ),
        );
      return;
    }

    final uri = Uri.parse(safeUrl);
    var launched = false;
    try {
      launched = await externalLauncher(uri);
    } catch (_) {
      launched = false;
    }

    if (!launched && context.mounted) {
      await Clipboard.setData(ClipboardData(text: safeUrl));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Không mở được trình duyệt ngoài. Đã sao chép liên kết trang tính vào bộ nhớ tạm.',
            ),
          ),
        );
    }
  }

  Future<void> _confirmInitializeCalendar(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        key: const Key('sheet_sync_init_confirm_dialog'),
        backgroundColor: AppColors.surfaceBase,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Khởi tạo / Bổ sung lịch chuẩn',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Hệ thống sẽ kiểm tra và bổ sung Tab "DANH MỤC CĂN", 6 Tab tháng cuốn chiếu và các căn còn thiếu.\n\n'
          'Thao tác này an toàn tuyệt đối: giữ nguyên toàn bộ ngày Chủ nhà đã khóa màu đỏ và lịch đặt phòng hiện có.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            key: const Key('sheet_sync_init_confirm_submit_btn'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textInverse,
              minimumSize: const Size(96, 48),
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Thực hiện'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await ref
          .read(hostSheetSyncNotifierProvider.notifier)
          .initializeStandardCalendar();
      if (ok) {
        onCalendarChanged?.call();
      }
    }
  }

  Future<void> _confirmDisconnect(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        key: const Key('sheet_sync_disconnect_confirm_dialog'),
        backgroundColor: AppColors.surfaceBase,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Ngắt kết nối Google Sheets?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Hệ thống sẽ dừng đồng bộ tự động với tệp Google Sheets này. '
          'Toàn bộ đơn đặt phòng, giữ chỗ và lịch khóa hiện tại trên ứng dụng vẫn được giữ nguyên an toàn.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text(
              'Giữ kết nối',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            key: const Key('sheet_sync_disconnect_confirm_submit_btn'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textInverse,
              minimumSize: const Size(110, 48),
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Ngắt kết nối'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(hostSheetSyncNotifierProvider.notifier).disconnect();
    }
  }

  Future<void> _showConnectSheet(
    BuildContext context,
    HostSheetSyncStatusPayload statusPayload,
  ) async {
    final connected = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => _HostSheetConnectModal(
        initialPayload: statusPayload,
      ),
    );

    if (connected == true) {
      onCalendarChanged?.call();
    }
  }

  Future<void> _showGuideDialog(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ModalDragHandle(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Quy ước màu lịch Google Sheets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng hướng dẫn',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    icon: const Icon(
                      LucideIcons.x,
                      size: 20,
                      color: AppColors.iconStrong,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _SheetColorLegendPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChangeLogsSheet(BuildContext context, WidgetRef ref) async {
    unawaited(
      ref.read(hostSheetSyncNotifierProvider.notifier).fetchChangeLogs(),
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _HostSheetChangeLogsModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(hostSheetSyncNotifierProvider);
    final payload = viewState.statusPayload;
    final integration = payload.integration;
    final effectiveState = payload.effectiveState;

    return Semantics(
      container: true,
      label: 'Thẻ quản lý đồng bộ lịch Google Sheets của Chủ nhà',
      child: Container(
        key: const Key('host_sheet_sync_card'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceBase,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, ref, viewState, payload, effectiveState),
            if (viewState.isInitialLoading && !payload.connected) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceSecondary,
              ),
            ] else if (viewState.loadError != null && !payload.connected) ...[
              const SizedBox(height: 12),
              _buildFeedbackBanner(
                icon: LucideIcons.triangleAlert,
                backgroundColor: AppColors.errorSoft,
                foregroundColor: AppColors.error,
                message: viewState.loadError!,
                trailing: TextButton(
                  key: const Key('sheet_sync_retry_status_btn'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(72, 44),
                    foregroundColor: AppColors.error,
                  ),
                  onPressed: () => ref
                      .read(hostSheetSyncNotifierProvider.notifier)
                      .loadStatus(),
                  child: const Text('Thử lại'),
                ),
              ),
            ] else if (!payload.connected || integration == null) ...[
              const SizedBox(height: 10),
              const Text(
                'Quản lý toàn bộ các căn trên một tệp Google Sheets duy nhất (tự động đồng bộ giữ chỗ, thanh toán và khóa lịch 6 tháng).',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              if (viewState.actionSuccessMessage != null) ...[
                const SizedBox(height: 10),
                _buildFeedbackBanner(
                  icon: LucideIcons.circleCheck,
                  backgroundColor: AppColors.successSoft,
                  foregroundColor: AppColors.success,
                  message: viewState.actionSuccessMessage!,
                ),
              ],
              if (viewState.actionErrorMessage != null) ...[
                const SizedBox(height: 10),
                _buildFeedbackBanner(
                  icon: LucideIcons.triangleAlert,
                  backgroundColor: AppColors.errorSoft,
                  foregroundColor: AppColors.error,
                  message: viewState.actionErrorMessage!,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    key: const Key('sheet_sync_open_connect_btn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textInverse,
                      minimumSize: const Size(180, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: viewState.isBusy
                        ? null
                        : () => _showConnectSheet(context, payload),
                    icon: const Icon(
                      LucideIcons.link,
                      size: 18,
                      color: AppColors.iconOnBrand,
                    ),
                    label: const Text(
                      'Kết nối Google Sheets',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('sheet_sync_guide_btn'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size(136, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => _showGuideDialog(context),
                    icon: const Icon(
                      LucideIcons.info,
                      size: 18,
                      color: AppColors.iconStrong,
                    ),
                    label: const Text(
                      'Quy ước màu',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    integration.spreadsheetTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Đồng bộ gần nhất: ${_formatDateTimeVi(integration.lastSyncedAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildKpiGrid(payload.stats),
              if (integration.status.hasError ||
                  (integration.lastErrorMessage != null &&
                      integration.lastErrorMessage!.trim().isNotEmpty)) ...[
                const SizedBox(height: 12),
                _buildIntegrationErrorBox(
                  context,
                  ref,
                  viewState,
                  payload,
                  integration,
                ),
              ],
              if (viewState.actionSuccessMessage != null) ...[
                const SizedBox(height: 12),
                _buildFeedbackBanner(
                  icon: LucideIcons.circleCheck,
                  backgroundColor: AppColors.successSoft,
                  foregroundColor: AppColors.success,
                  message: viewState.actionSuccessMessage!,
                ),
              ],
              if (viewState.actionErrorMessage != null) ...[
                const SizedBox(height: 12),
                _buildFeedbackBanner(
                  icon: LucideIcons.triangleAlert,
                  backgroundColor: AppColors.errorSoft,
                  foregroundColor: AppColors.error,
                  message: viewState.actionErrorMessage!,
                ),
              ],
              if (payload.openWarnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...payload.openWarnings.take(3).map(
                      (warning) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildWarningBanner(
                          context,
                          ref,
                          viewState,
                          warning,
                        ),
                      ),
                    ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 8),
              _buildTogglesSection(ref, viewState, integration),
              const SizedBox(height: 12),
              _buildConnectedActionsRow(
                context,
                ref,
                viewState,
                payload,
                integration,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    HostSheetSyncViewState viewState,
    HostSheetSyncStatusPayload payload,
    HostSheetConnectionState effectiveState,
  ) {
    final badgeInfo = _resolveBadgeStyle(payload, effectiveState);

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.calendarDays,
              size: 20,
              color: AppColors.iconStrong,
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Đồng bộ lịch Google Sheets',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        Container(
          key: const Key('sheet_sync_status_badge'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: badgeInfo.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: badgeInfo.border),
          ),
          child: Text(
            badgeInfo.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: badgeInfo.foreground,
            ),
          ),
        ),
      ],
    );
  }

  ({String label, Color background, Color foreground, Color border})
      _resolveBadgeStyle(
    HostSheetSyncStatusPayload payload,
    HostSheetConnectionState state,
  ) {
    if (!payload.connected || state == HostSheetConnectionState.disconnected) {
      return (
        label: 'Chưa kết nối',
        background: AppColors.surfaceSecondary,
        foreground: AppColors.textSecondary,
        border: AppColors.borderSoft,
      );
    }
    if (state.hasError) {
      return (
        label: state.labelVi,
        background: AppColors.errorSoft,
        foreground: AppColors.error,
        border: AppColors.errorSoft,
      );
    }
    final autoSync = payload.integration?.autoSyncEnabled ?? true;
    if (!autoSync || state == HostSheetConnectionState.paused) {
      return (
        label: 'Tạm dừng · ${payload.stats.totalListings} căn',
        background: AppColors.warningSoft,
        foreground: AppColors.warning,
        border: AppColors.warningSoft,
      );
    }
    return (
      label: 'Đã kết nối · ${payload.stats.totalListings} căn',
      background: AppColors.successSoft,
      foreground: AppColors.success,
      border: AppColors.successSoft,
    );
  }

  Widget _buildKpiGrid(HostSheetSyncStats stats) {
    final items = <({Key key, String label, String value, bool isAlert})>[
      (
        key: const Key('sheet_sync_kpi_total_listings'),
        label: 'Tổng căn',
        value: '${stats.totalListings}',
        isAlert: false,
      ),
      (
        key: const Key('sheet_sync_kpi_pending_holds'),
        label: 'Giữ chỗ',
        value: '${stats.pendingHoldsCount}',
        isAlert: false,
      ),
      (
        key: const Key('sheet_sync_kpi_sync_errors'),
        label: 'Lỗi đồng bộ',
        value: '${stats.syncErrorsCount}',
        isAlert: stats.syncErrorsCount > 0,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final columns =
            (constraints.maxWidth >= 340 && textScale <= 1.35) ? 3 : 2;
        final itemWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
            return Container(
              key: item.key,
              width: itemWidth > 0 ? itemWidth : constraints.maxWidth,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: item.isAlert
                    ? AppColors.errorSoft
                    : AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: item.isAlert ? AppColors.error : AppColors.borderSoft,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: item.isAlert
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: item.isAlert
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildIntegrationErrorBox(
    BuildContext context,
    WidgetRef ref,
    HostSheetSyncViewState viewState,
    HostSheetSyncStatusPayload payload,
    HostSheetIntegrationInfo integration,
  ) {
    final serviceEmail = payload.serviceAccountEmail;
    return Container(
      key: const Key('sheet_sync_permission_error_banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.triangleAlert,
                size: 18,
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  integration.lastErrorMessage?.trim().isNotEmpty == true
                      ? integration.lastErrorMessage!
                      : 'Không thể ghi dữ liệu lên Google Sheets. Vui lòng kiểm tra quyền Editor.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          if (serviceEmail != null && serviceEmail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Email hệ thống cần quyền Editor: $serviceEmail',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(100, 44),
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () =>
                      _copyText(context, serviceEmail, 'email hệ thống'),
                  icon: const Icon(LucideIcons.copy, size: 15),
                  label: const Text(
                    'Sao chép',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('sheet_sync_verify_permissions_btn'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(120, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              foregroundColor: AppColors.textPrimary,
              backgroundColor: AppColors.surfaceBase,
              side: const BorderSide(color: AppColors.border),
              shape: const StadiumBorder(),
            ),
            onPressed: viewState.isBusy
                ? null
                : () => ref
                    .read(hostSheetSyncNotifierProvider.notifier)
                    .verifyPermissions(),
            icon: const Icon(LucideIcons.shieldCheck, size: 16),
            label: const Text(
              'Kiểm tra lại quyền Editor',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(
    BuildContext context,
    WidgetRef ref,
    HostSheetSyncViewState viewState,
    HostSheetWarningItem warning,
  ) {
    final isHigh = warning.severity == 'critical' || warning.severity == 'high';
    final bgColor = isHigh ? AppColors.warningSoft : AppColors.surfaceSecondary;
    final accentColor = isHigh ? AppColors.warning : AppColors.textPrimary;

    return Container(
      key: Key('sheet_sync_warning_${warning.conflictId}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.triangleAlert,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (warning.listingTitle != null)
                      Text(
                        warning.listingId != null
                            ? '${warning.listingTitle} (#${warning.listingId})'
                            : warning.listingTitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    Text(
                      warning.description,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (warning.canUndoBulkChange)
                FilledButton.icon(
                  key: Key('sheet_sync_undo_bulk_${warning.conflictId}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textInverse,
                    minimumSize: const Size(120, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: viewState.isBusy
                      ? null
                      : () async {
                          final ok = await ref
                              .read(hostSheetSyncNotifierProvider.notifier)
                              .resolveConflict(
                                conflictId: warning.conflictId,
                                action: 'undo_bulk_change',
                              );
                          if (ok) {
                            onCalendarChanged?.call();
                          }
                        },
                  icon: const Icon(
                    LucideIcons.rotateCcw,
                    size: 16,
                    color: AppColors.iconOnBrand,
                  ),
                  label: const Text(
                    'Hoàn tác',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (warning.isStructuralConflict)
                FilledButton.icon(
                  key: Key(
                    'sheet_sync_repair_structure_${warning.conflictId}',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textInverse,
                    minimumSize: const Size(124, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: viewState.isBusy
                      ? null
                      : () async {
                          final ok = await ref
                              .read(hostSheetSyncNotifierProvider.notifier)
                              .resolveConflict(
                                conflictId: warning.conflictId,
                                action: 'repair_structure',
                              );
                          if (ok) {
                            onCalendarChanged?.call();
                          }
                        },
                  icon: const Icon(
                    LucideIcons.wrench,
                    size: 16,
                    color: AppColors.iconOnBrand,
                  ),
                  label: const Text(
                    'Phục hồi cấu trúc',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              OutlinedButton(
                key: Key('sheet_sync_keep_locked_${warning.conflictId}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  backgroundColor: AppColors.surfaceBase,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size(104, 44),
                  shape: const StadiumBorder(),
                ),
                onPressed: viewState.isBusy
                    ? null
                    : () async {
                        await ref
                            .read(hostSheetSyncNotifierProvider.notifier)
                            .resolveConflict(
                              conflictId: warning.conflictId,
                              action: 'keep_locked',
                            );
                      },
                child: const Text('Giữ khóa'),
              ),
              if (warning.canUnlockSingleDay)
                OutlinedButton(
                  key: Key('sheet_sync_unlock_safe_${warning.conflictId}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    backgroundColor: AppColors.surfaceBase,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size(124, 44),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: viewState.isBusy
                      ? null
                      : () async {
                          final ok = await ref
                              .read(hostSheetSyncNotifierProvider.notifier)
                              .resolveConflict(
                                conflictId: warning.conflictId,
                                action: 'unlock_if_safe',
                              );
                          if (ok) {
                            onCalendarChanged?.call();
                          }
                        },
                  child: const Text('Mở khóa nếu trống'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTogglesSection(
    WidgetRef ref,
    HostSheetSyncViewState viewState,
    HostSheetIntegrationInfo integration,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đồng bộ tự động',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        integration.autoSyncEnabled
                            ? 'Đang bật'
                            : 'Đang tạm dừng',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'Bật hoặc tắt đồng bộ tự động Google Sheets',
                  child: _buildSheetSwitch(
                    switchKey: const Key('sheet_sync_auto_toggle'),
                    value: integration.autoSyncEnabled,
                    onChanged: viewState.isBusy
                        ? null
                        : (val) => ref
                            .read(hostSheetSyncNotifierProvider.notifier)
                            .toggleAutoSync(val),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kiểm tra trực tiếp trước khi khách đặt',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Chặn nhận trùng đơn khi vừa tô khóa trên Sheets',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label:
                      'Bật hoặc tắt kiểm tra trực tiếp Google Sheets trước khi đặt phòng',
                  child: _buildSheetSwitch(
                    switchKey: const Key('sheet_sync_precheck_toggle'),
                    value: integration.strictBookingPrecheck,
                    onChanged: viewState.isBusy
                        ? null
                        : (val) => ref
                            .read(hostSheetSyncNotifierProvider.notifier)
                            .toggleStrictBookingPrecheck(val),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedActionsRow(
    BuildContext context,
    WidgetRef ref,
    HostSheetSyncViewState viewState,
    HostSheetSyncStatusPayload payload,
    HostSheetIntegrationInfo integration,
  ) {
    final isSyncingNow = viewState.activeAction == 'sync_now';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          key: const Key('sheet_sync_now_btn'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textInverse,
            minimumSize: const Size(140, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: const StadiumBorder(),
          ),
          onPressed: viewState.isBusy
              ? null
              : () async {
                  final ok = await ref
                      .read(hostSheetSyncNotifierProvider.notifier)
                      .syncNow();
                  if (ok) {
                    onCalendarChanged?.call();
                  }
                },
          icon: isSyncingNow
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textInverse,
                  ),
                )
              : const Icon(
                  LucideIcons.refreshCw,
                  size: 17,
                  color: AppColors.iconOnBrand,
                ),
          label: Text(
            isSyncingNow ? 'Đang đồng bộ...' : 'Đồng bộ ngay',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        OutlinedButton.icon(
          key: const Key('sheet_sync_open_url_btn'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size(128, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: const StadiumBorder(),
          ),
          onPressed: () => _handleOpenSpreadsheet(context, integration),
          icon: const Icon(
            LucideIcons.externalLink,
            size: 17,
            color: AppColors.iconStrong,
          ),
          label: const Text(
            'Mở trang tính',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        OutlinedButton.icon(
          key: const Key('sheet_sync_init_calendar_btn'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size(128, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: const StadiumBorder(),
          ),
          onPressed: viewState.isBusy
              ? null
              : () => _confirmInitializeCalendar(context, ref),
          icon: const Icon(
            LucideIcons.calendarDays,
            size: 17,
            color: AppColors.iconStrong,
          ),
          label: const Text(
            'Khởi tạo lịch chuẩn',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        OutlinedButton.icon(
          key: const Key('sheet_sync_logs_btn'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size(108, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: const StadiumBorder(),
          ),
          onPressed: () => _showChangeLogsSheet(context, ref),
          icon: const Icon(
            LucideIcons.history,
            size: 17,
            color: AppColors.iconStrong,
          ),
          label: const Text(
            'Nhật ký',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        OutlinedButton.icon(
          key: const Key('sheet_sync_guide_btn'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size(116, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: const StadiumBorder(),
          ),
          onPressed: () => _showGuideDialog(context),
          icon: const Icon(
            LucideIcons.info,
            size: 17,
            color: AppColors.iconStrong,
          ),
          label: const Text(
            'Quy ước màu',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton.icon(
          key: const Key('sheet_sync_disconnect_btn'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.error,
            minimumSize: const Size(116, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: const StadiumBorder(),
          ),
          onPressed:
              viewState.isBusy ? null : () => _confirmDisconnect(context, ref),
          icon: const Icon(
            LucideIcons.unlink,
            size: 16,
            color: AppColors.error,
          ),
          label: const Text(
            'Ngắt kết nối',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackBanner({
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    required String message,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foregroundColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: foregroundColor,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}

Widget _buildSheetSwitch({
  Key? switchKey,
  required bool value,
  required ValueChanged<bool>? onChanged,
}) {
  return Switch(
    key: switchKey,
    value: value,
    onChanged: onChanged,
    thumbColor: WidgetStateProperty.all(AppColors.surfaceBase),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return AppColors.skeleton;
      }
      if (states.contains(WidgetState.selected)) {
        return AppColors.primary;
      }
      return AppColors.skeleton;
    }),
    trackOutlineColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return Colors.transparent;
      }
      return AppColors.border;
    }),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}

class _ModalDragHandle extends StatelessWidget {
  const _ModalDragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _SheetColorLegendPanel extends StatelessWidget {
  final bool embedded;

  const _SheetColorLegendPanel({this.embedded = false});

  static const items =
      <({Color swatch, String shortLabel, String title, String subtitle})>[
    (
      swatch: AppColors.sheetCellAvailable,
      shortLabel: 'Trống',
      title: 'Nền trắng (Trống)',
      subtitle: 'Phòng còn trống (nếu không bị khóa trên ứng dụng).',
    ),
    (
      swatch: AppColors.sheetCellPendingHold,
      shortLabel: 'G #đơn · Giữ chỗ',
      title: 'Màu cam · G #mã đơn',
      subtitle: 'Đang giữ chỗ chờ khách thanh toán (hệ thống tự ghi).',
    ),
    (
      swatch: AppColors.sheetCellBooked,
      shortLabel: 'Đ #đơn · Đã đặt',
      title: 'Màu xanh · Đ #mã đơn',
      subtitle: 'Khách đã thanh toán / xác nhận (được bảo vệ bởi hệ thống).',
    ),
    (
      swatch: AppColors.sheetCellHostBlocked,
      shortLabel: 'K · Khóa lịch',
      title: 'Màu đỏ · K hoặc ghi chú',
      subtitle: 'Chủ nhà / Sale khóa thủ công trên Google Sheets.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: item.swatch,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 12, color: AppColors.border),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.triangleAlert,
              size: 16,
              color: AppColors.warning,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lưu ý: Không tô màu trang trí lên cả hàng ngày và không tự sửa cột A (Mã căn). Khi thêm hoặc đổi tên căn trên ứng dụng, bảng tính sẽ tự động cập nhật.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    if (embedded) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: content,
    );
  }
}

class _ConnectStepHeader extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String? subtitle;

  const _ConnectStepHeader({
    required this.stepNumber,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                stepNumber,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textInverse,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _HostSheetConnectModal extends ConsumerStatefulWidget {
  final HostSheetSyncStatusPayload initialPayload;

  const _HostSheetConnectModal({required this.initialPayload});

  @override
  ConsumerState<_HostSheetConnectModal> createState() =>
      _HostSheetConnectModalState();
}

class _HostSheetConnectModalState
    extends ConsumerState<_HostSheetConnectModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlCtrl;
  late final TextEditingController _editorEmailCtrl;
  bool _autoSyncEnabled = true;
  bool _strictBookingPrecheck = true;
  bool _legendExpanded = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController();
    _editorEmailCtrl = TextEditingController(
      text: widget.initialPayload.defaultHostEditorEmail,
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _editorEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _copyEmail(String email, String label) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Đã sao chép $label: $email'),
        ),
      );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final ok = await ref
        .read(hostSheetSyncNotifierProvider.notifier)
        .connectSpreadsheet(
          spreadsheetUrlOrId: _urlCtrl.text.trim(),
          hostEditorEmail: _editorEmailCtrl.text.trim(),
          autoSyncEnabled: _autoSyncEnabled,
          strictBookingPrecheck: _strictBookingPrecheck,
        );
    if (ok && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 13.5,
        color: AppColors.textMuted,
      ),
      prefixIcon: Icon(
        prefixIcon,
        size: 18,
        color: AppColors.iconMuted,
      ),
      filled: true,
      fillColor: AppColors.surfaceBase,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.borderFocus,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(hostSheetSyncNotifierProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxModalHeight = MediaQuery.sizeOf(context).height * 0.92;
    final serviceEmail = widget.initialPayload.serviceAccountEmail;
    final defaultHostEmail = widget.initialPayload.defaultHostEditorEmail;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxModalHeight),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ModalDragHandle(),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kết nối lịch Google Sheets',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Đồng bộ giữ chỗ, thanh toán & khóa lịch 2 chiều',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Đóng hộp thoại',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: viewState.isBusy
                                ? null
                                : () => Navigator.of(context).pop(false),
                            icon: const Icon(
                              LucideIcons.x,
                              size: 20,
                              color: AppColors.iconStrong,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.borderSoft),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _ConnectStepHeader(
                          stepNumber: '1',
                          title: 'Cấp quyền Chỉnh sửa (Editor)',
                          subtitle:
                              'Mở tệp Google Sheets, nhấn Chia sẻ (Share) và cấp quyền Editor cho email dưới đây:',
                        ),
                        const SizedBox(height: 10),
                        if (serviceEmail != null &&
                            serviceEmail.isNotEmpty) ...[
                          _EmailCopyRow(
                            copyButtonKey:
                                const Key('sheet_sync_copy_sa_email_btn'),
                            label: 'Email bot đồng bộ · Bắt buộc quyền Editor',
                            email: serviceEmail,
                            onCopy: () =>
                                _copyEmail(serviceEmail, 'email hệ thống'),
                          ),
                          const SizedBox(height: 8),
                        ],
                        _EmailCopyRow(
                          copyButtonKey:
                              const Key('sheet_sync_copy_editor_email_btn'),
                          label: 'Email Chủ nhà · Quyền Editor',
                          email: defaultHostEmail,
                          onCopy: () =>
                              _copyEmail(defaultHostEmail, 'email Chủ nhà'),
                        ),
                        const SizedBox(height: 18),
                        const _ConnectStepHeader(
                          stepNumber: '2',
                          title: 'Liên kết trang tính & Email quản lý',
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Đường dẫn Google Sheets',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('sheet_sync_url_input'),
                          controller: _urlCtrl,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          validator: (value) =>
                              validateGoogleSheetInput(value ?? ''),
                          decoration: _buildInputDecoration(
                            hintText:
                                'https://docs.google.com/spreadsheets/d/...',
                            prefixIcon: LucideIcons.link,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Email quản lý chính của Chủ nhà',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('sheet_sync_editor_email_input'),
                          controller: _editorEmailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          validator: validateOptionalEditorEmail,
                          decoration: _buildInputDecoration(
                            hintText: 'athanhnee@gmail.com',
                            prefixIcon: LucideIcons.mail,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderSoft),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Tự động đồng bộ hai chiều',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          SizedBox(height: 1),
                                          Text(
                                            'Cập nhật giữ chỗ, thanh toán & khóa lịch tự động',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildSheetSwitch(
                                      value: _autoSyncEnabled,
                                      onChanged: (v) =>
                                          setState(() => _autoSyncEnabled = v),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(
                                height: 1,
                                color: AppColors.borderSoft,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Kiểm tra trực tiếp Sheets trước khi nhận đơn',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          SizedBox(height: 1),
                                          Text(
                                            'Chặn trùng lịch ngay khi vừa tô khóa trên trang tính',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildSheetSwitch(
                                      value: _strictBookingPrecheck,
                                      onChanged: (v) => setState(
                                        () => _strictBookingPrecheck = v,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderSoft),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  key:
                                      const Key('sheet_sync_toggle_legend_btn'),
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => setState(
                                    () => _legendExpanded = !_legendExpanded,
                                  ),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 48,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            LucideIcons.info,
                                            size: 16,
                                            color: AppColors.iconStrong,
                                          ),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'Quy ước màu ô lịch trên Sheets',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _legendExpanded
                                                ? 'Thu gọn'
                                                : 'Chi tiết',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            _legendExpanded
                                                ? LucideIcons.chevronUp
                                                : LucideIcons.chevronDown,
                                            size: 16,
                                            color: AppColors.iconMuted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  0,
                                  14,
                                  12,
                                ),
                                child: _legendExpanded
                                    ? const _SheetColorLegendPanel(
                                        embedded: true,
                                      )
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: _SheetColorLegendPanel.items
                                            .map(
                                              (item) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 9,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceBase,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    999,
                                                  ),
                                                  border: Border.all(
                                                    color: AppColors.borderSoft,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 12,
                                                      height: 12,
                                                      decoration: BoxDecoration(
                                                        color: item.swatch,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                        border: Border.all(
                                                          color:
                                                              AppColors.border,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        item.shortLabel,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: AppColors
                                                              .textPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceBase,
                    border: Border(
                      top: BorderSide(color: AppColors.borderSoft),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (viewState.actionErrorMessage != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.triangleAlert,
                                size: 18,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  viewState.actionErrorMessage!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      FilledButton.icon(
                        key: const Key('sheet_sync_submit_connect_btn'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textInverse,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: viewState.isBusy ? null : _submit,
                        icon: viewState.activeAction == 'connect'
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textInverse,
                                ),
                              )
                            : const Icon(
                                LucideIcons.check,
                                size: 18,
                                color: AppColors.iconOnBrand,
                              ),
                        label: Text(
                          viewState.activeAction == 'connect'
                              ? 'Đang kiểm tra quyền & khởi tạo...'
                              : 'Xác minh quyền & Kết nối',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailCopyRow extends StatelessWidget {
  final Key copyButtonKey;
  final String label;
  final String email;
  final VoidCallback onCopy;

  const _EmailCopyRow({
    required this.copyButtonKey,
    required this.label,
    required this.email,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    email,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: 'Sao chép $label',
            child: IconButton(
              key: copyButtonKey,
              tooltip: 'Sao chép địa chỉ email',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: onCopy,
              icon: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  LucideIcons.copy,
                  size: 16,
                  color: AppColors.iconStrong,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostSheetChangeLogsModal extends ConsumerStatefulWidget {
  const _HostSheetChangeLogsModal();

  @override
  ConsumerState<_HostSheetChangeLogsModal> createState() =>
      _HostSheetChangeLogsModalState();
}

class _HostSheetChangeLogsModalState
    extends ConsumerState<_HostSheetChangeLogsModal> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _runSearch() {
    ref.read(hostSheetSyncNotifierProvider.notifier).fetchChangeLogs(
          search: _searchCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(hostSheetSyncNotifierProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Nhật ký đồng bộ Google Sheets',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng nhật ký',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    LucideIcons.x,
                    size: 20,
                    color: AppColors.iconStrong,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('sheet_sync_logs_search_input'),
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _runSearch(),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên căn hoặc mã căn (#ID)...',
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      filled: true,
                      fillColor: AppColors.surfaceBase,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('sheet_sync_logs_search_btn'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textInverse,
                    minimumSize: const Size(76, 48),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _runSearch,
                  child: const Text('Lọc'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (viewState.isLoadingLogs)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (viewState.logsError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  viewState.logsError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              )
            else if (viewState.searchedLogs.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Chưa có bản ghi thay đổi lịch nào khớp bộ lọc.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: ListView.separated(
                  shrinkWrap: true,
                  primary: false,
                  itemCount: viewState.searchedLogs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final item = viewState.searchedLogs[index];
                    final timeStr = item.detectedAt != null
                        ? DateFormat('HH:mm dd/MM')
                            .format(item.detectedAt!.toLocal())
                        : '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                item.listingTitle != null
                                    ? '${item.listingTitle} (#${item.listingId ?? ''})'
                                    : 'Hệ thống bảng tính',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${item.directionLabelVi} · $timeStr',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.targetDate != null
                                ? '${item.actionLabelVi} · Ngày ${item.targetDate}'
                                : item.actionLabelVi,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
