// Basic smoke test to ensure the test environment can build a widget.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke builds a simple widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('hello')),
        ),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
  });
}
