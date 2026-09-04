import 'dart:convert';

import 'package:ledger_app/models/account.dart';
import 'package:ledger_app/models/category.dart';
import 'package:ledger_app/models/ledger_entry.dart';

class LedgerSyncPayload {
  const LedgerSyncPayload({
    required this.accounts,
    required this.entries,
    required this.customCategories,
    required this.exportedAt,
  });

  final List<Account> accounts;
  final List<LedgerEntry> entries;
  final List<CustomCategory> customCategories;
  final DateTime exportedAt;

  factory LedgerSyncPayload.fromJson(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final version =
        json['schemaVersion'] as int? ?? json['version'] as int? ?? 1;
    if (version > 2) throw UnsupportedError('备份文件版本过高，无法导入');
    final exportedAt =
        DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
        DateTime.now().toUtc();
    List<T> decodeList<T>(
      String key,
      T Function(Map<String, Object?>) decoder,
    ) {
      return ((json[key] as List?) ?? const [])
          .map((value) => decoder((value as Map).cast<String, Object?>()))
          .toList();
    }

    return LedgerSyncPayload(
      accounts: decodeList('accounts', Account.fromJson),
      entries: decodeList('entries', LedgerEntry.fromJson),
      customCategories: decodeList('customCategories', CustomCategory.fromJson),
      exportedAt: exportedAt.toUtc(),
    );
  }

  String encode() => jsonEncode({
    'schemaVersion': 2,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'accounts': accounts.map((item) => item.toJson()).toList(),
    'entries': entries.map((item) => item.toJson()).toList(),
    'customCategories': customCategories.map((item) => item.toJson()).toList(),
  });
}

class LedgerSyncMerger {
  static LedgerSyncPayload merge(
    LedgerSyncPayload local,
    LedgerSyncPayload remote,
  ) {
    return LedgerSyncPayload(
      accounts: _mergeById(
        local.accounts,
        remote.accounts,
        (item) => item.id,
        (item) => item.updatedAt,
        (item) => item.deletedAt,
        (item) => jsonEncode(item.toJson()),
      ),
      entries: _mergeById(
        local.entries,
        remote.entries,
        (item) => item.id,
        (item) => item.updatedAt,
        (item) => item.deletedAt,
        (item) => jsonEncode(item.toJson()),
      ),
      customCategories: _mergeById(
        local.customCategories,
        remote.customCategories,
        (item) => item.id,
        (item) => item.updatedAt,
        (item) => item.deletedAt,
        (item) => jsonEncode(item.toJson()),
      ),
      exportedAt: DateTime.now().toUtc(),
    );
  }

  static List<T> _mergeById<T>(
    List<T> local,
    List<T> remote,
    String Function(T) id,
    DateTime Function(T) updatedAt,
    DateTime? Function(T) deletedAt,
    String Function(T) serialized,
  ) {
    final all = <String, T>{for (final item in local) id(item): item};
    for (final remoteItem in remote) {
      final key = id(remoteItem);
      final localItem = all[key];
      if (localItem == null) {
        all[key] = remoteItem;
        continue;
      }
      final localTime = deletedAt(localItem) ?? updatedAt(localItem);
      final remoteTime = deletedAt(remoteItem) ?? updatedAt(remoteItem);
      if (remoteTime.isAfter(localTime) ||
          (remoteTime.isAtSameMomentAs(localTime) &&
              serialized(remoteItem).compareTo(serialized(localItem)) > 0)) {
        all[key] = remoteItem;
      }
    }
    return all.values.toList();
  }
}
