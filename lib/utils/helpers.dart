import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ledger_app/theme/app_theme.dart';

import 'package:ledger_app/models/category.dart';
import 'package:ledger_app/models/enums.dart';
import 'package:ledger_app/models/ledger_entry.dart';
import 'package:ledger_app/store/ledger_store.dart';

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

int? parseMoney(String value) {
  final normalized = value.trim().replaceAll(',', '');
  if (normalized.isEmpty) {
    return null;
  }
  final parsed = double.tryParse(normalized);
  if (parsed == null) {
    return null;
  }
  return (parsed * 100).round();
}

String formatMoney(int cents) {
  final sign = cents < 0 ? '-' : '';
  final value = cents.abs() / 100;
  final formatter = NumberFormat('#,##0.00');
  return '$sign¥${formatter.format(value)}';
}

String expenseCategoryLabel(LedgerEntry entry) {
  return entry.expenseCategory ?? entry.category ?? '支出';
}

String expenseGroupLabel(LedgerEntry entry) {
  return entry.expenseGroup ?? '旧分类';
}

String incomeCategoryLabel(LedgerEntry entry) {
  return entry.incomeCategory ?? entry.category ?? '收入';
}

String incomeGroupLabel(LedgerEntry entry) {
  return entry.incomeGroup ?? '旧分类';
}

String moneyInputValue(int cents) {
  final value = cents / 100;
  if (cents % 100 == 0) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

String formatDateTime(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  final h = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}

String formatDateOnly(DateTime value) {
  final y = value.year.toString();
  final m = value.month.toString();
  final d = value.day.toString();
  return '$y年$m月$d日';
}

String dateKey(DateTime value) {
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '${value.year}-$m-$d';
}

String monthKey(DateTime value) {
  final m = value.month.toString().padLeft(2, '0');
  return '${value.year}-$m';
}

Map<String, MonthSummary> calculateMonthSummaries(List<LedgerEntry> entries) {
  final monthMap = <String, MonthSummary>{};

  for (final entry in entries) {
    final key = monthKey(entry.occurredAt);
    final current =
        monthMap[key] ??
        MonthSummary(totalEntries: 0, totalIncome: 0, totalExpense: 0);

    int income = current.totalIncome;
    int expense = current.totalExpense;

    if (entry.type.name == 'income') {
      income += entry.amountInCents;
    } else if (entry.type.name == 'expense') {
      expense += entry.amountInCents;
    }

    monthMap[key] = MonthSummary(
      totalEntries: current.totalEntries + 1,
      totalIncome: income,
      totalExpense: expense,
    );
  }

  return monthMap;
}

void showSnack(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  final screenHeight = MediaQuery.of(context).size.height;
  final bottomPosition = screenHeight * 3 / 4;

  OverlayEntry? fadeOutEntry;

  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: bottomPosition,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 48),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);

  Future.delayed(const Duration(seconds: 2), () {
    overlayEntry.remove();

    fadeOutEntry = OverlayEntry(
      builder: (context) {
        final animationController =
            AnimationController(
                duration: const Duration(seconds: 1),
                vsync: Navigator.of(context).overlay!,
              )
              ..forward()
              ..addStatusListener((status) {
                if (status == AnimationStatus.completed) {
                  fadeOutEntry?.remove();
                }
              });

        return Positioned(
          top: bottomPosition,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: FadeTransition(
                opacity: animationController.drive(Tween(begin: 1.0, end: 0.0)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 48),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(fadeOutEntry!);
  });
}

Future<void> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() onConfirm,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: context.appColors.dialogBackground,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.appColors.onBackground,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.onBackgroundMid,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('删除'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (confirmed == true) {
    await onConfirm();
  }
}

Color entryCategoryBadgeColor(
  LedgerEntry entry,
  LedgerStore store,
  BuildContext context,
) {
  switch (entry.type) {
    case LedgerEntryType.expense:
      final group =
          entry.expenseGroup ??
          store.groupNameForExpenseCategory(expenseCategoryLabel(entry)) ??
          '旧分类';
      return categoryGroupColor(group);
    case LedgerEntryType.income:
      final group =
          entry.incomeGroup ??
          store.groupNameForIncomeCategory(incomeCategoryLabel(entry)) ??
          '旧分类';
      return categoryGroupColor(group);
    case LedgerEntryType.transfer:
      return Theme.of(context).colorScheme.primary;
  }
}

bool shouldMaskSalaryIncome(LedgerEntry entry, LedgerStore store) {
  return store.isSalaryIncomeMasked &&
      entry.type == LedgerEntryType.income &&
      incomeCategoryLabel(entry) == '工资收入';
}
