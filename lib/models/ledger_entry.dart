import 'package:ledger_app/models/account.dart';
import 'package:ledger_app/models/category.dart';
import 'package:ledger_app/models/enums.dart';

class LedgerEntry {
  LedgerEntry({
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
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  }) : createdAt = (createdAt ?? occurredAt).toUtc(),
       updatedAt = (updatedAt ?? createdAt ?? occurredAt).toUtc();

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
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  LedgerEntry copyWith({
    LedgerEntryType? type,
    int? amountInCents,
    DateTime? occurredAt,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = unset,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt == unset ? this.deletedAt : deletedAt as DateTime?,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory LedgerEntry.fromJson(Map<String, Object?> json) {
    final occurredAt = _normalizeStoredOccurredAt(
      DateTime.parse(json['occurredAt'] as String),
    );
    return LedgerEntry(
      id: json['id'] as String,
      type: LedgerEntryType.values.byName(json['type'] as String),
      amountInCents: json['amountInCents'] as int,
      occurredAt: occurredAt,
      note: json['note'] as String? ?? '',
      category: json['category'] as String?,
      expenseGroup: json['expenseGroup'] as String?,
      expenseCategory: json['expenseCategory'] as String?,
      incomeGroup: json['incomeGroup'] as String?,
      incomeCategory: json['incomeCategory'] as String?,
      fromAccountId: json['fromAccountId'] as String?,
      toAccountId: json['toAccountId'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? occurredAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? occurredAt,
      deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? ''),
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
