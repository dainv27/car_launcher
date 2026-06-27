import 'package:car_launcher/core/router/app_route_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('launcher route transition uses short GPU-friendly animation', (
    tester,
  ) async {
    const child = SizedBox(key: Key('route-child'));
    final page = CarTransitionPage<void>(
      key: const ValueKey('page'),
      child: child,
    );

    expect(page.transitionDuration, const Duration(milliseconds: 220));
    expect(page.reverseTransitionDuration, const Duration(milliseconds: 160));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => page.transitionsBuilder(
            context,
            const AlwaysStoppedAnimation(0.5),
            const AlwaysStoppedAnimation(0),
            child,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('car-route-fade')), findsOneWidget);
    expect(find.byKey(const ValueKey('car-route-slide')), findsOneWidget);
    expect(find.byKey(const Key('route-child')), findsOneWidget);
  });

  testWidgets('launcher route transition respects reduced motion', (
    tester,
  ) async {
    const child = SizedBox(key: Key('reduced-motion-child'));
    final page = CarTransitionPage<void>(
      key: const ValueKey('page'),
      child: child,
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Builder(
            builder: (context) => page.transitionsBuilder(
              context,
              const AlwaysStoppedAnimation(0.5),
              const AlwaysStoppedAnimation(0),
              child,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('car-route-fade')), findsNothing);
    expect(find.byKey(const ValueKey('car-route-slide')), findsNothing);
    expect(find.byKey(const Key('reduced-motion-child')), findsOneWidget);
  });
}
