import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('todos tab loads and shows fake todos', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RiverQueryApp()));

    // Initially loading.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // After the fake latency resolves, the todos are shown.
    await tester.pumpAndSettle();
    expect(find.text('Install riverquery'), findsOneWidget);
    expect(find.text('Try createQuery'), findsOneWidget);
  });

  testWidgets('switching to feed tab loads pages', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RiverQueryApp()));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();

    expect(find.text('Feed item #1'), findsOneWidget);
  });
}
