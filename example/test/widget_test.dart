// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:gnrllybttr_pacer_example/main.dart';

void main() {
  testWidgets('GnrllyBttrPacer Demo loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GnrllyBttrPacerDemo());

    // Verify that the app title is shown
    expect(find.text('GnrllyBttrPacer Demo'), findsOneWidget);

    // Verify that tabs are present
    expect(find.text('Debouncing'), findsOneWidget);
    expect(find.text('Throttling'), findsOneWidget);
    expect(find.text('Rate Limiting'), findsOneWidget);
    expect(find.text('Queuing'), findsOneWidget);
    expect(find.text('Batching'), findsOneWidget);
    expect(find.text('Retrying'), findsOneWidget);
  });
}
