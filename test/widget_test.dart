import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:im_sdk_demo/main.dart';

void main() {
  testWidgets('Demo page renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: ImSdkDemoApp()));

    // Verify that the app title is displayed.
    expect(find.text('IM SDK Demo'), findsOneWidget);

    // Verify connection form elements exist.
    expect(find.text('Server Configuration'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);

    // Verify message section exists.
    expect(find.text('Send Message'), findsOneWidget);

    // Verify logs section exists.
    expect(find.text('Logs'), findsOneWidget);
  });
}
