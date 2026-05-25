import 'package:ledger_app/models/account.dart';
import 'package:ledger_app/models/category.dart';
import 'package:ledger_app/models/enums.dart';

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.type,
    required this.amountInCents,
    required this.occurredAt,
    required this.note,
    this.category,
    this.expenseGroup,
    this.expenseCategory,
    this.incomeGroup,
    this.incomeCategory,
    this.fromAccountId,
    this.toAccountId,
  });

  final String id;
  final LedgerEntryType type;
  final int amountInCents;
  final DateTime occurredAt;
  final String note;
  final String? category;
  final String? expenseGroup;
  final String? expenseCategory;
  final String? incomeGroup;
  final String? incomeCategory;
  final String? fromAccountId;
  final String? toAccountId;

  LedgerEntry copyWith({
    LedgerEntryType? type,
    int? amountInCents,
    DateTime? occurredAt,
    String? note,
    Object? category = unset,
    Object? expenseGroup = unset,
    Object? expenseCategory = unset,
    Object? incomeGroup = unset,
    Object? incomeCategory = unset,
    Object? fromAccountId = unset,
    Object? toAccountId = unset,
  }) {
    return LedgerEntry(
      id: id,
      type: type ?? this.type,
      amountInCents: amountInCents ?? this.amountInCents,
      occurredAt: occurredAt ?? this.occurredAt,
      note: note ?? this.note,
      category: category == unset ? this.category : category as String?,
      expenseGroup: expenseGroup == unset
          ? this.expenseGroup
          : expenseGroup as String?,
      expenseCategory: expenseCategory == unset
          ? this.expenseCategory
          : expenseCategory as String?,
      incomeGroup: incomeGroup == unset
          ? this.incomeGroup
          : incomeGroup as String?,
      incomeCategory: incomeCategory == unset
          ? this.incomeCategory
          : incomeCategory as String?,
      fromAccountId: fromAccountId == unset
          ? this.fromAccountId
          : fromAccountId as String?,
      toAccountId: toAccountId == unset
          ? this.toAccountId
          : toAccountId as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type.name,
      'amountInCents': amountInCents,
      'occurredAt': occurredAt.toIso8601String(),
      'note': note,
      'category': category,
      'expenseGroup': expenseGroup,
      'expenseCategory': expenseCategory,
      'incomeGroup': incomeGroup,
      'incomeCategory': incomeCategory,
      'fromAccountId': fromAccountId,
      'toAccountId': toAccountId,
    };
  }

  factory LedgerEntry.fromJson(Map<String, Object?> json) {
    return LedgerEntry(
      id: json['id'] as String,
      type: LedgerEntryType.values.byName(json['type'] as String),
      amountInCents: json['amountInCents'] as int,
      occurredAt: _normalizeStoredOccurredAt(
        DateTime.parse(json['occurredAt'] as String),
      ),
      note: json['note'] as String? ?? '',
      category: json['category'] as String?,
      expenseGroup: json['expenseGroup'] as String?,
      expenseCategory: json['expenseCategory'] as String?,
      incomeGroup: json['incomeGroup'] as String?,
      incomeCategory: json['incomeCategory'] as String?,
      fromAccountId: json['fromAccountId'] as String?,
      toAccountId: json['toAccountId'] as String?,
    );
  }

  static DateTime _normalizeStoredOccurredAt(DateTime value) {
    return value.isUtc ? value.toLocal() : value;
  }
}

class EntryFormDefaults {
  const EntryFormDefaults({
    this.expenseGroup,
    this.expenseCategory,
    this.incomeGroup,
    this.incomeCategory,
    this.fromAccountId,
    this.toAccountId,
  });

  final String? expenseGroup;
  final String? expenseCategory;
  final String? incomeGroup;
  final String? incomeCategory;
  final String? fromAccountId;
  final String? toAccountId;

  Map<String, Object?> toJson() {
    return {
      'expenseGroup': expenseGroup,
      'expenseCategory': expenseCategory,
      'incomeGroup': incomeGroup,
      'incomeCategory': incomeCategory,
      'fromAccountId': fromAccountId,
      'toAccountId': toAccountId,
    };
  }

  factory EntryFormDefaults.fromJson(Map<String, Object?> json) {
    return EntryFormDefaults(
      expenseGroup: json['expenseGroup'] as String?,
      expenseCategory: json['expenseCategory'] as String?,
      incomeGroup: json['incomeGroup'] as String?,
      incomeCategory: json['incomeCategory'] as String?,
      fromAccountId: json['fromAccountId'] as String?,
      toAccountId: json['toAccountId'] as String?,
    );
  }
}

class ImportedLedgerData {
  const ImportedLedgerData({
    required this.accounts,
    required this.entries,
    required this.customCategories,
    required this.summary,
  });

  final List<Account> accounts;
  final List<LedgerEntry> entries;
  final List<CustomCategory> customCategories;
  final ImportSummary summary;
}

class ImportSummary {
  const ImportSummary({
    required this.expenseCount,
    required this.incomeCount,
    required this.transferCount,
    required this.accountCount,
    required this.skippedCount,
  });

  final int expenseCount;
  final int incomeCount;
  final int transferCount;
  final int accountCount;
  final int skippedCount;

  int get entryCount => expenseCount + incomeCount + transferCount;
}

class CategoryStat {
  const CategoryStat({required this.total, required this.count});

  const CategoryStat.empty() : total = 0, count = 0;

  final int total;
  final int count;

  CategoryStat add(int amount) {
    return CategoryStat(total: total + amount, count: count + 1);
  }
}

class GroupedCategoryStat {
  const GroupedCategoryStat({
    required this.total,
    required this.count,
    required this.children,
  });

  factory GroupedCategoryStat.empty() {
    return const GroupedCategoryStat(total: 0, count: 0, children: {});
  }

  final int total;
  final int count;
  final Map<String, CategoryStat> children;

  GroupedCategoryStat add(String category, int amount) {
    final nextChildren = {...children};
    final current = nextChildren[category] ?? const CategoryStat.empty();
    nextChildren[category] = current.add(amount);
    final sortedChildren = Map.fromEntries(
      nextChildren.entries.toList()
        ..sort((a, b) => b.value.total.compareTo(a.value.total)),
    );
    return GroupedCategoryStat(
      total: total + amount,
      count: count + 1,
      children: sortedChildren,
    );
  }
}

class MonthSummary {
  final int totalEntries;
  final int totalIncome;
  final int totalExpense;

  MonthSummary({
    required this.totalEntries,
    required this.totalIncome,
    required this.totalExpense,
  });
}
