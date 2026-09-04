import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/models/enums.dart';
import 'package:ledger_app/models/ledger_entry.dart';
import 'package:ledger_app/services/ledger_sync_merge.dart';

LedgerEntry entry({
  required String id,
  required int amount,
  required DateTime updatedAt,
  DateTime? deletedAt,
}) {
  return LedgerEntry(
    id: id,
    type: LedgerEntryType.expense,
    amountInCents: amount,
    occurredAt: DateTime.utc(2026, 9, 4),
    note: '',
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

void main() {
  test('retains additions made on different devices', () {
    final local = LedgerSyncPayload(
      accounts: const [],
      entries: [
        entry(id: 'local', amount: 100, updatedAt: DateTime.utc(2026, 9, 4, 1)),
      ],
      customCategories: const [],
      exportedAt: DateTime.utc(2026, 9, 4, 1),
    );
    final remote = LedgerSyncPayload(
      accounts: const [],
      entries: [
        entry(
          id: 'remote',
          amount: 200,
          updatedAt: DateTime.utc(2026, 9, 4, 2),
        ),
      ],
      customCategories: const [],
      exportedAt: DateTime.utc(2026, 9, 4, 2),
    );

    final merged = LedgerSyncMerger.merge(local, remote);

    expect(
      merged.entries.map((item) => item.id),
      containsAll(['local', 'remote']),
    );
  });

  test('chooses the newer modification and preserves a newer tombstone', () {
    final earlier = DateTime.utc(2026, 9, 4, 1);
    final later = DateTime.utc(2026, 9, 4, 2);
    final local = LedgerSyncPayload(
      accounts: const [],
      entries: [entry(id: 'same', amount: 100, updatedAt: earlier)],
      customCategories: const [],
      exportedAt: earlier,
    );
    final remote = LedgerSyncPayload(
      accounts: const [],
      entries: [
        entry(id: 'same', amount: 100, updatedAt: later, deletedAt: later),
      ],
      customCategories: const [],
      exportedAt: later,
    );

    final merged = LedgerSyncMerger.merge(local, remote);

    expect(merged.entries.single.deletedAt, later);
  });
}
