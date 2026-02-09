import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athena_ai/src/athena_app.dart';
import 'package:athena_ai/main.dart'; // Access global 'cameras'

void main() {
  testWidgets('AthenaApp smoke test', (WidgetTester tester) async {
    // Initialize global cameras list to empty to avoid LateInitializationError
    cameras = [];

    // Build our app and trigger a frame.
    await tester.pumpWidget(const AthenaApp());

    // Verify that we are showing the loading indicator (since no camera is initialized)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
