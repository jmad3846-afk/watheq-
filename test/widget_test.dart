import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watheq/main.dart';

void main() {
  testWidgets('WathaqApp initializes smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WathaqApp()));
    expect(find.byType(WathaqApp), findsOneWidget);
  });
}
