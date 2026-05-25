import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ledger_app/main.dart';

void main() {
  testWidgets('shows the ledger shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const LedgerApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('流水明细'), findsOneWidget);
    expect(find.text('账户'), findsOneWidget);
    expect(find.text('流水'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
  });
}
