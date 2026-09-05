import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/services/ledger_sync_merge.dart';

void main() {
  test(
    'normalizes a legacy current account balance into an opening balance',
    () {
      final payload = LedgerSyncPayload.fromJson(
        jsonEncode({
          'version': 1,
          'exportedAt': '2026-09-04T12:00:00Z',
          'accounts': [
            {
              'id': 'wechat',
              'name': '微信钱包',
              'balanceInCents': 3000000,
              'type': 'onlinePayment',
              'iconKey': 'wechat',
            },
          ],
          'entries': [
            {
              'id': 'income-1',
              'type': 'income',
              'amountInCents': 3000000,
              'occurredAt': '2026-09-04T08:00:00Z',
              'note': '历史收入',
              'toAccountId': 'wechat',
            },
          ],
          'customCategories': [],
        }),
      );

      expect(payload.hasOpeningBalanceMetadata, isFalse);
      expect(payload.accounts.single.openingBalanceInCents, 0);
    },
  );
}
