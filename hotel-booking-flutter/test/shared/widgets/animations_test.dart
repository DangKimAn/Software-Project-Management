import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/shared/animations/animated_heart_button.dart';
import 'package:hotel_booking_flutter/shared/animations/fade_slide_in.dart';
import 'package:hotel_booking_flutter/shared/animations/pressable_scale.dart';
import 'package:hotel_booking_flutter/shared/animations/shimmer_loading.dart';
import 'package:hotel_booking_flutter/shared/animations/source_animations.dart';

Widget host(Widget child, {bool reduced = false}) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(body: Center(child: child))),
    );
void main() {
  testWidgets(
      'reduce motion stops entrance and press animations even when changed at runtime',
      (tester) async {
    Widget content() => Column(mainAxisSize: MainAxisSize.min, children: [
          const CalFadeIn(child: Text('Calendar')),
          const SearchPopIn(child: Text('Search')),
          const FadeSlideIn(
              delay: Duration(seconds: 2), child: Text('Delayed')),
          const PressableScale(child: Text('Press')),
          AnimatedHeartButton(isFavorite: false, onToggle: () {}),
          const ShimmerLoading(child: Text('Skeleton')),
          const MapMarkerPulse(),
        ]);
    await tester.pumpWidget(host(content()));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(host(content(), reduced: true));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byType(ShaderMask), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
  testWidgets('dispose cancels delayed animation and duration can change',
      (tester) async {
    await tester.pumpWidget(host(
        const FadeSlideIn(delay: Duration(seconds: 2), child: Text('Delay'))));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(host(const CalFadeIn(
        duration: Duration(milliseconds: 220), child: Text('Calendar'))));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(host(const CalFadeIn(
        duration: Duration(milliseconds: 150), child: Text('Calendar'))));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('disabled favorite action exposes no callback', (tester) async {
    await tester.pumpWidget(
        host(const AnimatedHeartButton(isFavorite: true, onToggle: null)));
    expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
  });
}
