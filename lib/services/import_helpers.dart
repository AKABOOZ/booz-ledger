import 'package:excel/excel.dart' as xls;

import 'package:ledger_app/models/account.dart';
import 'package:ledger_app/models/category.dart';
import 'package:ledger_app/models/enums.dart';
import 'package:ledger_app/models/ledger_entry.dart';
import 'package:ledger_app/utils/helpers.dart';

ImportedLedgerData parseSuiShouJiExcel(List<int> bytes) {
  final excel = xls.Excel.decodeBytes(bytes);
  final accountIds = <String, String>{};
  final accounts = <Account>[];
  final entries = <LedgerEntry>[];
  final customCategories = <String, CustomCategory>{};
  var expenseCount = 0;
  var incomeCount = 0;
  var transferCount = 0;
  var skippedCount = 0;
  var entrySerial = 0;

  String accountIdFor(String rawName) {
    final name = rawName.trim();
    return accountIds.putIfAbsent(name, () {
      final id = 'import_account_${accountIds.length + 1}';
      final type = inferImportedAccountType(name);
      accounts.add(
        Account(
          id: id,
          name: name,
          balanceInCents: 0,
          type: type,
          iconKey: inferImportedAccountIconKey(name, type),
        ),
      );
      return id;
    });
  }

  void rememberCustomCategory(
    LedgerEntryType type,
    String group,
    String category,
  ) {
    if (categoryExistsInDefaults(type, category)) {
      return;
    }
    final key = '${type.name}|$group|$category';
    customCategories.putIfAbsent(key, () {
      return CustomCategory(
        type: type,
        groupName: group,
        name: category,
        iconKey: defaultImportedCategoryIconKey(type),
      );
    });
  }

  void parseSheet(String sheetName, LedgerEntryType type) {
    final sheet = excel.tables[sheetName];
    if (sheet == null || sheet.rows.isEmpty) {
      return;
    }
    final header = <String, int>{};
    for (var i = 0; i < sheet.rows.first.length; i++) {
      final name = excelCellText(sheet.rows.first[i]).trim();
      if (name.isNotEmpty) {
        header[name] = i;
      }
    }

    String valueAt(List<xls.Data?> row, String name) {
      final index = header[name];
      if (index == null || index >= row.length) {
        return '';
      }
      return excelCellText(row[index]).trim();
    }

    for (final row in sheet.rows.skip(1)) {
      final currency = valueAt(row, '账户币种');
      if (currency.isNotEmpty && currency != 'CNY') {
        skippedCount++;
        continue;
      }
      final occurredAt = parseImportedDate(valueAt(row, '日期'));
      final amount = parseMoney(valueAt(row, '金额'));
      if (occurredAt == null || amount == null || amount <= 0) {
        skippedCount++;
        continue;
      }
      final account1 = valueAt(row, '账户1');
      final account2 = valueAt(row, '账户2');
      final note = valueAt(row, '备注');
      final id = 'import_entry_${++entrySerial}';

      if (type == LedgerEntryType.transfer) {
        if (account1.isEmpty || account2.isEmpty) {
          skippedCount++;
          continue;
        }
        entries.add(
          LedgerEntry(
            id: id,
            type: LedgerEntryType.transfer,
            amountInCents: amount,
            occurredAt: occurredAt,
            note: note,
            fromAccountId: accountIdFor(account1),
            toAccountId: accountIdFor(account2),
          ),
        );
        transferCount++;
        continue;
      }

      if (account1.isEmpty) {
        skippedCount++;
        continue;
      }
      final mapped = mapImportedCategory(
        type: type,
        rawGroup: valueAt(row, '分类'),
        rawCategory: valueAt(row, '子分类'),
      );
      rememberCustomCategory(type, mapped.groupName, mapped.categoryName);
      entries.add(
        LedgerEntry(
          id: id,
          type: type,
          amountInCents: amount,
          occurredAt: occurredAt,
          note: note,
          category: mapped.categoryName,
          expenseGroup: type == LedgerEntryType.expense
              ? mapped.groupName
              : null,
          expenseCategory: type == LedgerEntryType.expense
              ? mapped.categoryName
              : null,
          incomeGroup: type == LedgerEntryType.income ? mapped.groupName : null,
          incomeCategory: type == LedgerEntryType.income
              ? mapped.categoryName
              : null,
          fromAccountId: type == LedgerEntryType.expense
              ? accountIdFor(account1)
              : null,
          toAccountId: type == LedgerEntryType.income
              ? accountIdFor(account1)
              : null,
        ),
      );
      if (type == LedgerEntryType.expense) {
        expenseCount++;
      } else {
        incomeCount++;
      }
    }
  }

  void scanAccountsOnly(String sheetName) {
    final sheet = excel.tables[sheetName];
    if (sheet == null || sheet.rows.isEmpty) {
      return;
    }
    final header = <String, int>{};
    for (var i = 0; i < sheet.rows.first.length; i++) {
      final name = excelCellText(sheet.rows.first[i]).trim();
      if (name.isNotEmpty) {
        header[name] = i;
      }
    }

    String valueAt(List<xls.Data?> row, String name) {
      final index = header[name];
      if (index == null || index >= row.length) {
        return '';
      }
      return excelCellText(row[index]).trim();
    }

    for (final row in sheet.rows.skip(1)) {
      final account1 = valueAt(row, '账户1');
      final account2 = valueAt(row, '账户2');
      if (account1.isNotEmpty) {
        accountIdFor(account1);
      }
      if (account2.isNotEmpty) {
        accountIdFor(account2);
      }
    }
  }

  parseSheet('支出', LedgerEntryType.expense);
  parseSheet('收入', LedgerEntryType.income);
  parseSheet('转账', LedgerEntryType.transfer);
  scanAccountsOnly('余额变更');
  scanAccountsOnly('负债变更');

  return ImportedLedgerData(
    accounts: accounts,
    entries: entries,
    customCategories: customCategories.values.toList(),
    summary: ImportSummary(
      expenseCount: expenseCount,
      incomeCount: incomeCount,
      transferCount: transferCount,
      accountCount: accounts.length,
      skippedCount: skippedCount,
    ),
  );
}

String excelCellText(xls.Data? cell) {
  final value = cell?.value;
  return switch (value) {
    null => '',
    xls.TextCellValue() => value.value.toString(),
    xls.IntCellValue() => value.value.toString(),
    xls.DoubleCellValue() => value.value.toString(),
    xls.BoolCellValue() => value.value ? 'true' : 'false',
    xls.DateCellValue() => formatImportedDate(value.asDateTimeLocal()),
    xls.DateTimeCellValue() => formatImportedDate(value.asDateTimeLocal()),
    xls.TimeCellValue() => value.toString(),
    xls.FormulaCellValue() => value.formula,
  };
}

String formatImportedDate(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  final h = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');
  final sec = value.second.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min:$sec';
}

DateTime? parseImportedDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return null;
  }
  final normalized = value.replaceFirst(' ', 'T');
  return DateTime.tryParse(normalized);
}

class ImportedCategoryMapping {
  const ImportedCategoryMapping(this.groupName, this.categoryName);

  final String groupName;
  final String categoryName;
}

ImportedCategoryMapping mapImportedCategory({
  required LedgerEntryType type,
  required String rawGroup,
  required String rawCategory,
}) {
  final aliases = type == LedgerEntryType.expense
      ? const {'早午晚餐': '早餐晚餐', '打车租车': '打出租车', '还人钱物': '还人钱财'}
      : const {'卖闲置物品': '出售闲置', '意外来钱': '意外收入'};
  final fallbackGroup = type == LedgerEntryType.expense ? '其他杂项' : '其他收入';
  final groups = type == LedgerEntryType.expense
      ? defaultExpenseCategoryGroups.map(
          (group) => MapEntry(group.name, group.children),
        )
      : defaultIncomeCategoryGroups.map(
          (group) => MapEntry(group.name, group.children),
        );
  final category = aliases[rawCategory.trim()] ?? rawCategory.trim();
  var group = rawGroup.trim();
  if (group.isEmpty) {
    group = fallbackGroup;
  }
  final knownGroup = groups.any((item) => item.key == group);
  if (!knownGroup) {
    group = fallbackGroup;
  }
  return ImportedCategoryMapping(group, category.isEmpty ? group : category);
}

bool categoryExistsInDefaults(LedgerEntryType type, String category) {
  final groups = type == LedgerEntryType.expense
      ? defaultExpenseCategoryGroups.map(
          (group) => MapEntry(group.name, group.children),
        )
      : defaultIncomeCategoryGroups.map(
          (group) => MapEntry(group.name, group.children),
        );
  for (final group in groups) {
    for (final child in group.value) {
      if (child.name == category) {
        return true;
      }
    }
  }
  return false;
}

String defaultImportedCategoryIconKey(LedgerEntryType type) {
  return type == LedgerEntryType.expense ? 'more_horiz' : 'auto_awesome';
}

AccountType inferImportedAccountType(String name) {
  if (name.contains('现金')) {
    return AccountType.cash;
  }
  if (name.contains('信用卡') ||
      name.contains('花呗') ||
      name.contains('月付') ||
      name.contains('无限卡')) {
    return AccountType.creditCard;
  }
  if (name.contains('工资卡') ||
      name.contains('农行') ||
      name.contains('工行') ||
      name.contains('招商') ||
      name.contains('银行卡')) {
    return AccountType.debitCard;
  }
  return AccountType.onlinePayment;
}

String inferImportedAccountIconKey(String name, AccountType type) {
  if (name.contains('微信')) {
    return 'wechat';
  }
  if (name.contains('支付宝') || name.contains('余额宝') || name.contains('花呗')) {
    return 'alipay';
  }
  if (type == AccountType.cash) {
    return 'cash';
  }
  if (type == AccountType.creditCard) {
    return 'credit_card';
  }
  if (type == AccountType.debitCard) {
    return 'debit_card';
  }
  return 'wallet';
}

