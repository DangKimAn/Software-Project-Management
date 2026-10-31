import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/di/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../l10n/locale_formatters.dart';

/// Opens the unified Language & Currency selector sheet from Top Header or Menu.
Future<void> showCurrencyLanguageBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceBase,
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadii.roundedBottomSheet,
    ),
    builder: (sheetCtx) => const CurrencyLanguageSheetContent(),
  );
}

/// Compact, responsive Header button (`>= 48x48` hit target) for quick 1-tap
/// Language & Currency switching across Guest screens.
class HeaderCurrencyLanguageButton extends ConsumerWidget {
  final bool isOverlayTop;
  final bool showCodePill;

  const HeaderCurrencyLanguageButton({
    super.key,
    this.isOverlayTop = false,
    this.showCodePill = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final currency = ref.watch(effectiveCurrencyProvider);
    final l10n = LocaleFormatters.resolveL10n(locale);

    final fgColor = isOverlayTop ? Colors.white : AppColors.textStrong;
    final iconColor = isOverlayTop ? Colors.white : AppColors.iconStrong;
    final labelUpper = locale.toUpperCase();

    return Semantics(
      button: true,
      label: '${l10n.settingsLanguage} & ${l10n.settingsCurrency}: '
          '$labelUpper ${currency.code}',
      child: Tooltip(
        message:
            '${l10n.settingsLanguage} • ${currency.code} (${currency.symbol})',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('header_currency_language_button'),
            onTap: () => showCurrencyLanguageBottomSheet(context),
            borderRadius: BorderRadius.circular(999),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: showCodePill ? 10 : 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.globe, size: 19, color: iconColor),
                    if (showCodePill) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$labelUpper · ${currency.symbol}',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: fgColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable Bottom Sheet body allowing Guests to switch Language (`vi` / `en` / `ko`)
/// and either keep Currency synced automatically with language or pin a manual currency.
class CurrencyLanguageSheetContent extends ConsumerWidget {
  const CurrencyLanguageSheetContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final preference = ref.watch(currencyPreferenceProvider);
    final effectiveCurrency = ref.watch(effectiveCurrencyProvider);
    final fxEnabled = ref.watch(fxFeatureEnabledProvider);
    final ratesState = ref.watch(exchangeRatesProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final l10n = formatter.l10n;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s20,
                AppSpacing.s16,
                AppSpacing.s12,
                AppSpacing.s8,
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.globe,
                    size: 20,
                    color: AppColors.iconStrong,
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(
                      fxEnabled
                          ? '${l10n.settingsLanguage} & ${l10n.settingsCurrency}'
                          : l10n.settingsLanguage,
                      style: AppTypography.sectionHeading,
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: IconButton(
                      key: const Key('currency_language_sheet_close'),
                      tooltip: l10n.ctaClose,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        LucideIcons.x,
                        size: 20,
                        color: AppColors.iconStrong,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSoft),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s20,
                  AppSpacing.s16,
                  AppSpacing.s20,
                  AppSpacing.s24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsLanguage,
                      style: AppTypography.cardTitle.copyWith(
                        color: AppColors.textStrong,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    _SelectorOptionTile(
                      tileKey: const Key('sheet_lang_vi'),
                      title: 'Tiếng Việt',
                      subtitle: 'Mặc định • VND (₫)',
                      isSelected: currentLocale == 'vi',
                      onTap: () =>
                          ref.read(localeProvider.notifier).setLocale('vi'),
                    ),
                    _SelectorOptionTile(
                      tileKey: const Key('sheet_lang_en'),
                      title: 'English',
                      subtitle: r'International • USD ($)',
                      isSelected: currentLocale == 'en',
                      onTap: () =>
                          ref.read(localeProvider.notifier).setLocale('en'),
                    ),
                    _SelectorOptionTile(
                      tileKey: const Key('sheet_lang_ko'),
                      title: '한국어',
                      subtitle: '한국어 • KRW (₩)',
                      isSelected: currentLocale == 'ko',
                      onTap: () =>
                          ref.read(localeProvider.notifier).setLocale('ko'),
                    ),
                    if (fxEnabled) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                        child: Divider(height: 1, color: AppColors.borderSoft),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.settingsCurrency,
                              style: AppTypography.cardTitle.copyWith(
                                color: AppColors.textStrong,
                              ),
                            ),
                          ),
                          if (effectiveCurrency.isForeign)
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              child: IconButton(
                                key: const Key('sheet_refresh_fx_button'),
                                tooltip: l10n.ctaRetry,
                                onPressed: ratesState.isRefreshing
                                    ? null
                                    : () => ref
                                        .read(exchangeRatesProvider.notifier)
                                        .refreshIfNeeded(force: true),
                                icon: Icon(
                                  LucideIcons.refreshCw,
                                  size: 18,
                                  color: ratesState.isRefreshing
                                      ? AppColors.iconMuted
                                      : AppColors.iconStrong,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      _SelectorOptionTile(
                        tileKey: const Key('sheet_currency_automatic'),
                        title: l10n.currencyFollowLanguage,
                        subtitle:
                            '${l10n.currencyFollowLanguageDesc} (${AppCurrency.defaultForLocale(currentLocale).code} ${AppCurrency.defaultForLocale(currentLocale).symbol})',
                        isSelected: preference.isAutomatic,
                        onTap: () => ref
                            .read(currencyPreferenceProvider.notifier)
                            .setAutomatic(),
                      ),
                      _SelectorOptionTile(
                        tileKey: const Key('sheet_currency_vnd'),
                        title: 'VND (₫)',
                        subtitle: l10n.currencyNameVnd,
                        isSelected: preference.isManual &&
                            preference.manualCurrencyOverride ==
                                AppCurrency.vnd,
                        onTap: () => ref
                            .read(currencyPreferenceProvider.notifier)
                            .setManualCurrency(AppCurrency.vnd),
                      ),
                      _SelectorOptionTile(
                        tileKey: const Key('sheet_currency_usd'),
                        title: r'USD ($)',
                        subtitle: l10n.currencyNameUsd,
                        isSelected: preference.isManual &&
                            preference.manualCurrencyOverride ==
                                AppCurrency.usd,
                        onTap: () => ref
                            .read(currencyPreferenceProvider.notifier)
                            .setManualCurrency(AppCurrency.usd),
                      ),
                      _SelectorOptionTile(
                        tileKey: const Key('sheet_currency_krw'),
                        title: 'KRW (₩)',
                        subtitle: l10n.currencyNameKrw,
                        isSelected: preference.isManual &&
                            preference.manualCurrencyOverride ==
                                AppCurrency.krw,
                        onTap: () => ref
                            .read(currencyPreferenceProvider.notifier)
                            .setManualCurrency(AppCurrency.krw),
                      ),
                      if (formatter.isFallingBackToVnd) ...[
                        const SizedBox(height: AppSpacing.s12),
                        Container(
                          key: const Key('sheet_fx_status_box'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            border: Border.all(color: AppColors.borderSoft),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  LucideIcons.info,
                                  size: 16,
                                  color: AppColors.iconMuted,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: Text(
                                  l10n.fxRateUnavailableFallback,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorOptionTile extends StatelessWidget {
  final Key tileKey;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectorOptionTile({
    required this.tileKey,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Material(
        color: isSelected ? AppColors.surfaceElevated : AppColors.surfaceBase,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? AppColors.textStrong : AppColors.borderSoft,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: InkWell(
          key: tileKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textStrong,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: AppSpacing.s8),
                    const Icon(
                      LucideIcons.check,
                      size: 20,
                      color: AppColors.iconStrong,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
