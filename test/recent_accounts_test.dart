import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ledger_app/models/account.dart';
import 'package:ledger_app/models/enums.dart';
import 'package:ledger_app/models/ledger_entry.dart';
import 'package:ledger_app/store/ledger_store.dart';

Account account(String id) {
  return Account(
    id: id,
    name: id,
    balanceInCents: 0,
    type: AccountType.cash,
    iconKey: 'cash',
  );
}

LedgerEntry entry({
  required String id,
  String? fromAccountId,
  String? toAccountId,
}) {
  return LedgerEntry(
    id: id,
    type: fromAccountId != null && toAccountId != null
        ? LedgerEntryType.transfer
        : fromAccountId != null
        ? LedgerEntryType.expense
        : LedgerEntryType.income,
    amountInCents: 100,
    occurredAt: DateTime(2026),
    note: '',
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => null,
      );

  test(
    'updates recent account IDs by recency, de-duplicates, and limits to four',
    () {
      expect(updateRecentAccountIds(['cash', 'bank'], ['bank', 'credit']), [
        'bank',
        'credit',
        'cash',
      ]);
      expect(updateRecentAccountIds(['a', 'b', 'c', 'd'], ['e']), [
        'e',
        'a',
        'b',
        'c',
      ]);
      expect(updateRecentAccountIds(['a', 'b'], [null, '', 'a', 'a']), [
        'a',
        'b',
      ]);
    },
  );

  test(
    'recent accounts reflect saved entries instead of form defaults',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = LedgerStore();
      for (final id in ['cash', 'bank', 'credit', 'wallet', 'investment']) {
        await store.addAccount(account(id));
      }

      await store.rememberEntryFormDefaults(
        LedgerEntryType.expense,
        const EntryFormDefaults(fromAccountId: 'cash'),
      );
      expect(store.recentAccounts(), isEmpty);

      await store.addEntry(entry(id: '1', fromAccountId: 'bank'));
      await store.addEntry(entry(id: '2', toAccountId: 'credit'));
      await store.addEntry(
        entry(id: '3', fromAccountId: 'wallet', toAccountId: 'investment'),
      );
      await store.addEntry(entry(id: '4', fromAccountId: 'bank'));

      expect(store.recentAccounts().map((account) => account.id), [
        'bank',
        'wallet',
        'investment',
        'credit',
      ]);
    },
  );

  test('recent account IDs survive an app reload', () async {
    SharedPreferences.setMockInitialValues({
      'ledger_app_state_v1': jsonEncode({
        'accounts': [account('cash').toJson(), account('bank').toJson()],
        'entries': [],
        'customCategories': [],
      }),
    });
    final store = LedgerStore();
    await store.load();
    await store.rememberRecentAccounts(['bank', 'cash']);

    final reloadedStore = LedgerStore();
    await reloadedStore.load();

    expect(reloadedStore.recentAccounts().map((account) => account.id), [
      'bank',
      'cash',
    ]);
  });

  test('deleting an account removes it from the recent account list', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LedgerStore();
    await store.addAccount(account('cash'));
    await store.addAccount(account('bank'));
    await store.addEntry(entry(id: '1', fromAccountId: 'cash'));
    await store.addEntry(entry(id: '2', fromAccountId: 'bank'));

    await store.deleteAccount('bank');

    expect(store.recentAccounts().map((account) => account.id), ['cash']);
  });
}
