import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

class AppLoading extends StatelessWidget {
  final String? message;

  const AppLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message ?? context.l10n.loadingText,
      liveRegion: true,
      child: Center(
        child: SingleChildScrollView(
            child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: MediaQuery.disableAnimationsOf(context) ? .75 : null,
                  strokeWidth: 2.8,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        )),
      ),
    );
  }
}
