import 'dart:convert';
import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:pinyin/pinyin.dart' as pinyin;

import 'package:ledger_app/models/account.dart';
import 'package:ledger_app/models/category.dart';
import 'package:ledger_app/models/enums.dart';
import 'package:ledger_app/store/ledger_store.dart';

class VoiceParseResult {
  const VoiceParseResult({
    this.type,
    this.amount,
    this.note,
    this.occurredAt,
    this.expenseGroup,
    this.expenseCategory,
    this.incomeGroup,
    this.incomeCategory,
    this.fromAccountId,
    this.toAccountId,
    this.hints = const [],
    this.isCategoryFuzzy = false,
  });

  final LedgerEntryType? type;
  final double? amount;
  final String? note;
  final DateTime? occurredAt;
  final String? expenseGroup;
  final String? expenseCategory;
  final String? incomeGroup;
  final String? incomeCategory;
  final String? fromAccountId;
  final String? toAccountId;
  final List<String> hints;
  final bool isCategoryFuzzy;

  VoiceParseResult mergeMissingFrom(VoiceParseResult fallback) {
    return VoiceParseResult(
      type: type ?? fallback.type,
      amount: amount ?? fallback.amount,
      note: note ?? fallback.note,
      occurredAt: occurredAt ?? fallback.occurredAt,
      expenseGroup: expenseGroup ?? fallback.expenseGroup,
      expenseCategory: expenseCategory ?? fallback.expenseCategory,
      incomeGroup: incomeGroup ?? fallback.incomeGroup,
      incomeCategory: incomeCategory ?? fallback.incomeCategory,
      fromAccountId: fromAccountId ?? fallback.fromAccountId,
      toAccountId: toAccountId ?? fallback.toAccountId,
      hints: [
        ...hints,
        ...fallback.hints.where((item) => !hints.contains(item)),
      ],
      isCategoryFuzzy: isCategoryFuzzy || fallback.isCategoryFuzzy,
    );
  }
}

class ExternalQuickAddDraft {
  static const clipboardImportPrefix = 'LEDGERAPP_IMPORT:';

  const ExternalQuickAddDraft({
    this.type,
    this.amount,
    this.note,
    this.category,
    this.account,
    this.accountId,
    this.fromAccount,
    this.fromAccountId,
    this.toAccount,
    this.toAccountId,
    this.occurredAt,
    this.source,
  });

  final LedgerEntryType? type;
  final double? amount;
  final String? note;
  final String? category;
  final String? account;
  final String? accountId;
  final String? fromAccount;
  final String? fromAccountId;
  final String? toAccount;
  final String? toAccountId;
  final DateTime? occurredAt;
  final String? source;

  String get sourceLabel => source ?? '外部快捷入口';

  static ExternalQuickAddDraft? fromClipboardText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final importCodeIndex = trimmed.indexOf(clipboardImportPrefix);
    if (importCodeIndex < 0) {
      return null;
    }
    final jsonText = _extractFirstJsonObject(
      trimmed.substring(importCodeIndex + clipboardImportPrefix.length),
    );
    if (jsonText == null) {
      return null;
    }
    return _fromJsonText(jsonText, fallbackSource: 'Miclaw 剪贴板');
  }

  static ExternalQuickAddDraft? _fromJsonText(
    String text, {
    String? fallbackSource,
  }) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        return null;
      }
      final payload = Map<Object?, Object?>.from(decoded);
      return _fromReader((key) {
        final value = payload[key]?.toString().trim();
        if (value == null || value.isEmpty) {
          return null;
        }
        return value;
      }, fallbackSource: fallbackSource);
    } catch (_) {
      return null;
    }
  }

  static ExternalQuickAddDraft? _fromReader(
    String? Function(String key) read, {
    String? fallbackSource,
  }) {
    final type = switch (read('type')?.toLowerCase()) {
      'expense' => LedgerEntryType.expense,
      'income' => LedgerEntryType.income,
      'transfer' => LedgerEntryType.transfer,
      _ => null,
    };
    final amount = double.tryParse(read('amount')?.replaceAll(',', '') ?? '');
    final occurredAt = parseOccurredAt(read('occurredAt'));
    final draft = ExternalQuickAddDraft(
      type: type,
      amount: amount,
      note: read('note'),
      category: read('category'),
      account: read('account'),
      accountId: read('accountId'),
      fromAccount: read('fromAccount'),
      fromAccountId: read('fromAccountId'),
      toAccount: read('toAccount'),
      toAccountId: read('toAccountId'),
      occurredAt: occurredAt,
      source: read('source') ?? fallbackSource,
    );
    return draft._hasMeaningfulValue ? draft : null;
  }

  static DateTime? parseOccurredAt(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return null;
    }
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  static String? _extractFirstJsonObject(String text) {
    final start = text.indexOf('{');
    if (start < 0) {
      return null;
    }
    var depth = 0;
    var inString = false;
    var isEscaped = false;
    for (var index = start; index < text.length; index++) {
      final char = text[index];
      if (isEscaped) {
        isEscaped = false;
        continue;
      }
      if (char == '\\') {
        isEscaped = true;
        continue;
      }
      if (char == '"') {
        inString = !inString;
        continue;
      }
      if (inString) {
        continue;
      }
      if (char == '{') {
        depth += 1;
      } else if (char == '}') {
        depth -= 1;
        if (depth == 0) {
          return text.substring(start, index + 1);
        }
      }
    }
    return null;
  }

  bool get _hasMeaningfulValue {
    return type != null ||
        amount != null ||
        note != null ||
        category != null ||
        account != null ||
        accountId != null ||
        fromAccount != null ||
        fromAccountId != null ||
        toAccount != null ||
        toAccountId != null ||
        occurredAt != null ||
        source != null;
  }

  VoiceParseResult toParseResult(LedgerStore store) {
    final resolvedType = type ?? LedgerEntryType.expense;
    final resolvedCategory = category;
    final expenseCategory =
        resolvedType == LedgerEntryType.expense &&
            store.expenseItemByName(resolvedCategory) != null
        ? resolvedCategory
        : null;
    final incomeCategory =
        resolvedType == LedgerEntryType.income &&
            store.incomeItemByName(resolvedCategory) != null
        ? resolvedCategory
        : null;
    return VoiceParseResult(
      type: resolvedType,
      amount: amount,
      note: note,
      occurredAt: occurredAt,
      expenseGroup: expenseCategory == null
          ? null
          : store.groupNameForExpenseCategory(expenseCategory),
      expenseCategory: expenseCategory,
      incomeGroup: incomeCategory == null
          ? null
          : store.groupNameForIncomeCategory(incomeCategory),
      incomeCategory: incomeCategory,
      fromAccountId: switch (resolvedType) {
        LedgerEntryType.expense => _resolveAccountId(
          store,
          explicitId: fromAccountId ?? accountId,
          fallbackName: fromAccount ?? account,
        ),
        LedgerEntryType.transfer => _resolveAccountId(
          store,
          explicitId: fromAccountId,
          fallbackName: fromAccount,
        ),
        LedgerEntryType.income => null,
      },
      toAccountId: switch (resolvedType) {
        LedgerEntryType.income => _resolveAccountId(
          store,
          explicitId: toAccountId ?? accountId,
          fallbackName: toAccount ?? account,
        ),
        LedgerEntryType.transfer => _resolveAccountId(
          store,
          explicitId: toAccountId,
          fallbackName: toAccount,
        ),
        LedgerEntryType.expense => null,
      },
    );
  }

  static String? _resolveAccountId(
    LedgerStore store, {
    String? explicitId,
    String? fallbackName,
  }) {
    final id = explicitId?.trim();
    if (id != null && id.isNotEmpty && store.accountById(id) != null) {
      return id;
    }
    final name = fallbackName?.trim();
    if (name == null || name.isEmpty) {
      return null;
    }
    final exact = store.accounts
        .where((account) => account.name == name)
        .toList();
    if (exact.length == 1) {
      return exact.first.id;
    }
    final matched = LedgerTextParser._matchAccount(name, store.accounts);
    return matched?.id;
  }
}

class VoiceInputParser {
  static VoiceParseResult parse(String text, {required LedgerStore store}) {
    return LedgerTextParser.parse(text, store: store);
  }
}

class LedgerTextParser {
  static const _accountInstitutionKeywords = [
    '微信',
    '支付宝',
    '花呗',
    '信用购',
    '美团',
    '滴滴',
    '广发',
    '招商',
    '招行',
    '工商',
    '工行',
    '农业',
    '农行',
    '建设',
    '建行',
    '中国银行',
    '中行',
    '交通',
    '交行',
    '邮储',
    '邮政',
    '平安',
    '中信',
    '民生',
    '兴业',
    '浦发',
    '光大',
    '华厦',
    '华夏',
  ];

  static VoiceParseResult parse(String text, {required LedgerStore store}) {
    final normalizedText = _normalize(text);
    final type = _parseType(normalizedText);
    final amount = _parseAmount(text);
    final hints = <String>[];

    _CategoryMatch? expenseMatch;
    _CategoryMatch? incomeMatch;
    if (type == LedgerEntryType.expense) {
      expenseMatch = _matchExpenseCategory(
        normalizedText,
        store.expenseCategoryGroups,
      );
      if (expenseMatch != null) {
        hints.add(expenseMatch.categoryName);
      }
    }
    if (type == LedgerEntryType.income) {
      incomeMatch = _matchIncomeCategory(
        normalizedText,
        store.incomeCategoryGroups,
      );
      if (incomeMatch != null) {
        hints.add(incomeMatch.categoryName);
      }
    }

    final account = _matchAccount(normalizedText, store.accounts);
    if (account != null && type != LedgerEntryType.transfer) {
      hints.add(account.name);
    }

    final isCategoryFuzzy = (expenseMatch?.isFuzzy ?? false) ||
        (incomeMatch?.isFuzzy ?? false);

    return VoiceParseResult(
      type: type,
      amount: amount,
      note: text,
      expenseGroup: expenseMatch?.groupName,
      expenseCategory: expenseMatch?.categoryName,
      incomeGroup: incomeMatch?.groupName,
      incomeCategory: incomeMatch?.categoryName,
      fromAccountId: type == LedgerEntryType.expense ? account?.id : null,
      toAccountId: type == LedgerEntryType.income ? account?.id : null,
      hints: hints,
      isCategoryFuzzy: isCategoryFuzzy,
    );
  }

  static VoiceParseResult parseImage(
    String text, {
    required LedgerStore store,
  }) {
    final normalizedText = _normalize(text);
    final rawType = _parseImageType(text);
    final rawAmount = _parseImageAmount(text);
    final type = normalizeImageEntryType(
      rawType,
      rawText: text,
      amount: rawAmount,
    );
    final amount = rawAmount?.abs();
    final occurredAt = parseImageOccurredAt(null, fallbackText: text);
    final sourceApp = _detectImageSourceApp(text);
    final hints = <String>[];

    _CategoryMatch? expenseMatch;
    _CategoryMatch? incomeMatch;
    if (type == LedgerEntryType.expense) {
      expenseMatch = _matchExpenseCategory(
        normalizedText,
        store.expenseCategoryGroups,
        allowFuzzy: false,
      );
      if (expenseMatch != null) {
        hints.add(expenseMatch.categoryName);
      }
    }
    if (type == LedgerEntryType.income) {
      incomeMatch = _matchIncomeCategory(
        normalizedText,
        store.incomeCategoryGroups,
        allowFuzzy: false,
      );
      if (incomeMatch != null) {
        hints.add(incomeMatch.categoryName);
      }
    }

    final account = _matchAccount(
      normalizedText,
      store.accounts,
      allowFuzzy: false,
    );
    final resolvedAccount =
        account ?? _fallbackAccountForSourceApp(sourceApp, store.accounts);
    if (resolvedAccount != null && type != LedgerEntryType.transfer) {
      hints.add(resolvedAccount.name);
    }

    return VoiceParseResult(
      type: type,
      amount: amount,
      note: text,
      occurredAt: occurredAt,
      expenseGroup: expenseMatch?.groupName,
      expenseCategory: expenseMatch?.categoryName,
      incomeGroup: incomeMatch?.groupName,
      incomeCategory: incomeMatch?.categoryName,
      fromAccountId: type == LedgerEntryType.expense
          ? resolvedAccount?.id
          : null,
      toAccountId: type == LedgerEntryType.income ? resolvedAccount?.id : null,
      hints: hints,
    );
  }

  static DateTime? parseImageOccurredAt(String? raw, {String? fallbackText}) {
    final direct = raw == null ? null : _extractImageDateTimeFromText(raw);
    if (direct != null) {
      return direct;
    }
    if (fallbackText == null || fallbackText.trim().isEmpty) {
      return null;
    }
    return _extractImageDateTimeFromText(fallbackText);
  }

  static String? fallbackAccountIdForSourceApp(
    String? sourceApp,
    LedgerStore store,
  ) {
    return _fallbackAccountForSourceApp(sourceApp, store.accounts)?.id;
  }

  static LedgerEntryType _parseType(String text) {
    if (containsAny(text, const ['转账', '转到', '转给', '转入', '转出'])) {
      return LedgerEntryType.transfer;
    }
    if (containsAny(text, const [
      '收入',
      '赚了',
      '收到',
      '收款',
      '工资',
      '奖金',
      '退款',
      '返现',
      '到账',
      '入账',
      '卖了',
      '出售',
      '兼职',
      '利息',
    ])) {
      return LedgerEntryType.income;
    }
    return LedgerEntryType.expense;
  }

  static LedgerEntryType _parseImageType(String rawText) {
    final text = _normalize(rawText);
    if (_containsNegativeImageAmount(rawText)) {
      return LedgerEntryType.expense;
    }
    if (containsAny(text, const ['退款成功', '已退款', '退款到账', '退回原账户'])) {
      return LedgerEntryType.income;
    }
    if (containsAny(text, const ['转入', '收款', '到账', '入账', '收入', '退款'])) {
      return LedgerEntryType.income;
    }
    if (containsAny(text, const [
      '实付',
      '付款方式',
      '支付时间',
      '交易成功',
      '确认收货',
      '订单编号',
      '商品说明',
      '购买',
      '消费',
      '账单详情',
      '计入收支',
      '转账',
      '转出',
      '付款',
      '支付',
      '支出',
    ])) {
      return LedgerEntryType.expense;
    }
    final fallbackType = _parseType(text);
    return fallbackType == LedgerEntryType.transfer
        ? LedgerEntryType.expense
        : fallbackType;
  }

  static String? _detectImageSourceApp(String rawText) {
    final text = _normalize(rawText);
    if (containsAny(text, const [
      '大众点评',
      '美团',
      '美团月付',
      '月付付款',
      '骑手',
      '配送费',
      '去分期',
      '外卖',
    ])) {
      return 'meituan';
    }
    if (containsAny(text, const [
      '淘宝',
      '天猫',
      '确认收货',
      '查看物流',
      '信用购',
      '花呗分期',
      '品牌好货',
    ])) {
      return 'taobao';
    }
    if (containsAny(text, const ['拼多多', '商户单号xp', '交易成功', '账单详情'])) {
      return 'pinduoduo';
    }
    if (containsAny(text, const ['微信支付', '微信钱包', '收付款'])) {
      return 'wechat';
    }
    if (containsAny(text, const ['支付宝', '蚂蚁', '账单详情', '付款方式'])) {
      return 'alipay';
    }
    return null;
  }

  static double? _parseAmount(String text) {
    final normalized = text.replaceAll(',', '').replaceAll('，', '');
    final labeledMoneyMatch = RegExp(
      r'(?:支付|付款|实付|消费|金额|合计|收款|到账|退款|转账|收入)[^\d¥￥]{0,12}[¥￥]?\s*(\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (labeledMoneyMatch != null) {
      final amount = double.tryParse(labeledMoneyMatch.group(1)!);
      if (amount != null) {
        return amount;
      }
    }

    final symbolMoneyMatch = RegExp(
      r'[¥￥]\s*([+-]?\d+(?:\.\d{1,2})?)',
    ).firstMatch(normalized);
    if (symbolMoneyMatch != null) {
      final amount = double.tryParse(
        symbolMoneyMatch.group(1)!.replaceFirst('+', ''),
      );
      if (amount != null) {
        return amount.abs();
      }
    }

    final yuanJiaoMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*[块元]\s*(\d{1,2}|[零一二两三四五六七八九])?',
    ).firstMatch(normalized);
    if (yuanJiaoMatch != null) {
      final yuan = double.tryParse(yuanJiaoMatch.group(1)!);
      final jiaoText = yuanJiaoMatch.group(2);
      if (yuan != null) {
        final jiao = jiaoText == null
            ? 0
            : int.tryParse(jiaoText) ?? _chineseDigit(jiaoText) ?? 0;
        return yuan + jiao / (jiaoText?.length == 1 ? 10 : 100);
      }
    }

    final numberMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(normalized);
    if (numberMatch != null) {
      return double.tryParse(numberMatch.group(1)!);
    }

    final chineseMatch = RegExp(
      r'[零一二两三四五六七八九十百千万]+(?:[块元][零一二两三四五六七八九]?)?',
    ).firstMatch(normalized);
    if (chineseMatch == null) {
      return null;
    }
    final value = chineseMatch.group(0)!;
    final parts = value.split(RegExp(r'[块元]'));
    final yuan = _parseChineseInteger(parts.first);
    if (yuan == null) {
      return null;
    }
    if (parts.length > 1 && parts[1].isNotEmpty) {
      final jiao = _chineseDigit(parts[1].characters.first);
      return yuan + (jiao == null ? 0 : jiao / 10);
    }
    return yuan.toDouble();
  }

  static double? _parseImageAmount(String text) {
    final normalized = text.replaceAll('，', ',');
    final compact = normalized.replaceAll(',', '');
    final labelPatterns = [
      RegExp(
        r'(?:实付|付款金额|消费金额|订单金额|交易金额|收款金额|到账金额|退款金额|合计|总计|应付|实收)\s*[¥￥]?\s*([+-]?\d+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:实付|付款金额|消费金额|订单金额|交易金额|收款金额|到账金额|退款金额|合计|总计|应付|实收)[^\d¥￥]{0,8}[¥￥]\s*([+-]?\d+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
    ];
    for (final pattern in labelPatterns) {
      final match = pattern.firstMatch(compact);
      final amount = _amountFromMatch(match);
      if (amount != null) {
        return amount;
      }
    }

    final symbolMatch = RegExp(
      r'[¥￥]\s*([+-]?\d+(?:\.\d{1,2})?)',
    ).firstMatch(compact);
    final symbolAmount = _amountFromMatch(symbolMatch);
    if (symbolAmount != null) {
      return symbolAmount;
    }

    final signedMatch = RegExp(
      r'[-−–—]\s*(\d{1,7}(?:\.\d{2}))',
    ).firstMatch(compact);
    final signedAmount = _amountFromMatch(signedMatch);
    if (signedAmount != null) {
      return signedAmount;
    }

    final moneyCandidates = RegExp(r'\d{1,7}\.\d{2}')
        .allMatches(compact)
        .map((match) => double.tryParse(match.group(0)!))
        .whereType<double>()
        .where((value) => value > 0)
        .toList();
    if (moneyCandidates.isNotEmpty) {
      moneyCandidates.sort();
      return moneyCandidates.last;
    }
    return _parseAmount(text);
  }

  static LedgerEntryType normalizeImageEntryType(
    LedgerEntryType? type, {
    required String rawText,
    double? amount,
  }) {
    if ((amount != null && amount < 0) ||
        _containsNegativeImageAmount(rawText)) {
      return LedgerEntryType.expense;
    }
    if (type == LedgerEntryType.expense || type == LedgerEntryType.income) {
      return type!;
    }
    final text = _normalize(rawText);
    if (containsAny(text, const [
      '退款成功',
      '已退款',
      '退款到账',
      '退回原账户',
      '转入',
      '收款',
      '到账',
      '入账',
      '收入',
      '退款',
    ])) {
      return LedgerEntryType.income;
    }
    return LedgerEntryType.expense;
  }

  static bool _containsNegativeImageAmount(String rawText) {
    final compact = rawText.replaceAll(',', '').replaceAll('，', ',');
    return RegExp(
      r'(?:[-−–—]\s*[¥￥]?\s*\d{1,7}(?:\.\d{1,2})?|[¥￥]\s*[-−–—]\s*\d{1,7}(?:\.\d{1,2})?)',
    ).hasMatch(compact);
  }

  static DateTime? _extractImageDateTimeFromText(String rawText) {
    final labeledFullMatch = RegExp(
      r'(?:支付时间|下单时间|交易时间|订单时间|创建时间|付款时间|消费时间|成交时间|入账时间|到账时间)\s*[:：]?\s*(\d{4})[.\-/年](\d{1,2})[.\-/月](\d{1,2})(?:日)?\s+(\d{1,2})[:：](\d{2})(?:[:：](\d{2}))?',
    ).firstMatch(rawText);
    final labeledFull = _dateTimeFromMatch(labeledFullMatch, hasYear: true);
    if (labeledFull != null) {
      return labeledFull;
    }

    final fullMatch = RegExp(
      r'(\d{4})[.\-/年](\d{1,2})[.\-/月](\d{1,2})(?:日)?\s+(\d{1,2})[:：](\d{2})(?:[:：](\d{2}))?',
    ).firstMatch(rawText);
    final fullDateTime = _dateTimeFromMatch(fullMatch, hasYear: true);
    if (fullDateTime != null) {
      return fullDateTime;
    }

    final labeledShortMatch = RegExp(
      r'(?:支付时间|下单时间|交易时间|订单时间|创建时间|付款时间|消费时间|成交时间|入账时间|到账时间)\s*[:：]?\s*(\d{1,2})[.\-/月](\d{1,2})(?:日)?\s+(\d{1,2})[:：](\d{2})(?:[:：](\d{2}))?',
    ).firstMatch(rawText);
    return _dateTimeFromMatch(labeledShortMatch, hasYear: false);
  }

  static DateTime? _dateTimeFromMatch(
    RegExpMatch? match, {
    required bool hasYear,
  }) {
    if (match == null) {
      return null;
    }
    final now = DateTime.now();
    final year = hasYear ? int.tryParse(match.group(1) ?? '') : now.year;
    final month = int.tryParse(match.group(hasYear ? 2 : 1) ?? '');
    final day = int.tryParse(match.group(hasYear ? 3 : 2) ?? '');
    final hour = int.tryParse(match.group(hasYear ? 4 : 3) ?? '');
    final minute = int.tryParse(match.group(hasYear ? 5 : 4) ?? '');
    final second = int.tryParse(match.group(hasYear ? 6 : 5) ?? '') ?? 0;
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }
    if (year < 2020 || year > 2100) {
      return null;
    }
    try {
      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }

  static Account? _fallbackAccountForSourceApp(
    String? sourceApp,
    List<Account> accounts,
  ) {
    return switch (sourceApp) {
      'wechat' => preferredWeChatWalletAccount(accounts),
      'meituan' => _firstAccountContaining(accounts, const [
        '美团月付',
        '月付',
        '美团',
      ]),
      'taobao' => _firstAccountContaining(accounts, const ['花呗', '信用购']),
      _ => null,
    };
  }

  static Account? _firstAccountContaining(
    List<Account> accounts,
    List<String> keywords,
  ) {
    for (final keyword in keywords) {
      for (final account in accounts) {
        if (_normalize(account.name).contains(_normalize(keyword))) {
          return account;
        }
      }
    }
    return null;
  }

  static double? _amountFromMatch(RegExpMatch? match) {
    if (match == null) {
      return null;
    }
    final raw = match.group(1)?.replaceFirst('+', '');
    if (raw == null) {
      return null;
    }
    return double.tryParse(raw)?.abs();
  }

  static _CategoryMatch? _matchExpenseCategory(
    String text,
    List<ExpenseCategoryGroup> groups, {
    bool allowFuzzy = true,
  }) {
    return _matchCategory(
      text,
      candidates: [
        for (final group in groups)
          for (final child in group.children)
            _CategoryCandidate(group.name, child.name),
      ],
      groupCandidates: [
        for (final group in groups)
          if (group.children.isNotEmpty)
            _CategoryCandidate(group.name, group.children.first.name),
      ],
      aliases: const {
        '吃饭': '早餐晚餐',
        '早餐': '早餐晚餐',
        '午餐': '早餐晚餐',
        '晚餐': '早餐晚餐',
        '饭': '早餐晚餐',
        '外卖': '早餐晚餐',
        '奶茶': '水果零食',
        '零食': '水果零食',
        '水果': '水果零食',
        '打车': '打出租车',
        '滴滴': '打出租车',
        '出租车': '打出租车',
        '公交': '公共交通',
        '地铁': '公共交通',
        '停车': '私家车费用',
        '修车': '私家车费用',
        '充电': '私家车费用',
        '车辆': '私家车费用',
        '水电': '水电煤气',
        '电费': '水电煤气',
        '燃气': '水电煤气',
        '房租': '房租',
        '房贷': '房租',
        '物业': '物业管理',
        '车位费': '物业管理',
        '管理': '物业管理',
        '衣服': '衣服裤子',
        '裤子': '衣服裤子',
        '鞋': '鞋帽包包',
        '鞋子': '鞋帽包包',
        '包': '鞋帽包包',
        '帽子': '鞋帽包包',
        '手机费': '手机费',
        '话费': '手机费',
        '网费': '上网费',
        '电信': '上网费',
        '移动': '上网费',
        '宽带': '上网费',
        '光纤': '上网费',
        '健身': '运动健身',
        '健身房': '运动健身',
        '瑜伽': '运动健身',
        '普拉提': '运动健身',
        '私教': '运动健身',
        '拳击': '运动健身',
        '游泳': '运动健身',
        '撸铁': '运动健身',
        '旅游': '旅游度假',
        '景点': '旅游度假',
        '博物馆': '旅游度假',
        '书': '书报杂志',
        'ai': 'AI使用费',
        '会员': 'AI使用费',
        'deepseek': 'AI使用费',
        'mimo': 'AI使用费',
        'codex': 'AI使用费',
        'claude code': 'AI使用费',
        '药': '药品费',
        '医院': '治疗费',
        '手续费': '银行手续',
        '饮料': '烟酒茶',
        '咖啡': '烟酒茶',
        '喝的': '烟酒茶',
        '快递': '邮寄费',
        '寄快递': '邮寄费',
        '寄东西': '邮寄费',
        '邮寄': '邮寄费',
        '发快递': '邮寄费',
        '顺丰': '邮寄费',
        '菜鸟': '邮寄费',
        '手机': '数码装备',
        '相机': '数码装备',
        '镜头': '数码装备',
        '小米': '数码装备',
        '红米': '数码装备',
        'redmi': '数码装备',
        'oppo': '数码装备',
        'vivo': '数码装备',
        '数码': '数码装备',
      },
      allowFuzzy: allowFuzzy,
    );
  }

  static _CategoryMatch? _matchIncomeCategory(
    String text,
    List<IncomeCategoryGroup> groups, {
    bool allowFuzzy = true,
  }) {
    return _matchCategory(
      text,
      candidates: [
        for (final group in groups)
          for (final child in group.children)
            _CategoryCandidate(group.name, child.name),
      ],
      groupCandidates: [
        for (final group in groups)
          if (group.children.isNotEmpty)
            _CategoryCandidate(group.name, group.children.first.name),
      ],
      aliases: const {
        '工资': '工资收入',
        '薪水': '工资收入',
        '奖金': '奖金收入',
        '加班': '加班收入',
        '兼职': '兼职收入',
        '利息': '利息收入',
        '退款': '淘宝退款',
        '退货': '淘宝退款',
        '返现': '意外收入',
        '礼金': '礼金收入',
        '红包': '礼金收入',
        '中奖': '中奖收入',
        '闲置': '出售闲置',
        '卖了': '出售闲置',
        '出售': '出售闲置',
        '顺风车': '顺风车',
        '自媒体': '自媒体收入',
      },
      allowFuzzy: allowFuzzy,
    );
  }

  static _CategoryMatch? _matchCategory(
    String text, {
    required List<_CategoryCandidate> candidates,
    required List<_CategoryCandidate> groupCandidates,
    required Map<String, String> aliases,
    bool allowFuzzy = true,
  }) {
    final normalizedText = _normalize(text);

    // 1. 直接匹配（原有逻辑）
    final sortedCandidates = [...candidates]
      ..sort((a, b) => b.categoryName.length.compareTo(a.categoryName.length));
    for (final candidate in sortedCandidates) {
      if (normalizedText.contains(_normalize(candidate.categoryName))) {
        return _CategoryMatch(candidate.groupName, candidate.categoryName);
      }
    }

    // 2. 分组匹配（原有逻辑）
    final sortedGroups = [...groupCandidates]
      ..sort((a, b) => b.groupName.length.compareTo(a.groupName.length));
    for (final candidate in sortedGroups) {
      if (normalizedText.contains(_normalize(candidate.groupName))) {
        return _CategoryMatch(candidate.groupName, candidate.categoryName);
      }
    }

    // 3. 别名匹配（原有逻辑）
    for (final entry in aliases.entries) {
      if (normalizedText.contains(_normalize(entry.key))) {
        for (final candidate in candidates) {
          if (candidate.categoryName == entry.value) {
            return _CategoryMatch(candidate.groupName, candidate.categoryName);
          }
        }
      }
    }

    if (!allowFuzzy) {
      return null;
    }

    // 4. 拼音匹配
    final textPinyin = _getPinyin(normalizedText);
    for (final candidate in sortedCandidates) {
      final candidatePinyin = _getPinyin(candidate.categoryName);
      if (textPinyin.contains(candidatePinyin)) {
        return _CategoryMatch(candidate.groupName, candidate.categoryName, isFuzzy: true);
      }
    }

    // 5. 分组拼音匹配
    for (final candidate in sortedGroups) {
      final groupPinyin = _getPinyin(candidate.groupName);
      if (textPinyin.contains(groupPinyin)) {
        return _CategoryMatch(candidate.groupName, candidate.categoryName, isFuzzy: true);
      }
    }

    // 6. 模糊匹配（基于相似度）
    _CategoryMatch? bestMatch;
    double bestScore = 0.0;

    for (final candidate in sortedCandidates) {
      final score = _calculateSimilarity(
        normalizedText,
        _normalize(candidate.categoryName),
      );
      if (score > bestScore && score > 0.6) {
        // 相似度阈值
        bestScore = score;
        bestMatch = _CategoryMatch(candidate.groupName, candidate.categoryName, isFuzzy: true);
      }
    }

    if (bestMatch != null) {
      return bestMatch;
    }

    // 7. 分组模糊匹配
    bestScore = 0.0;
    for (final candidate in sortedGroups) {
      final score = _calculateSimilarity(
        normalizedText,
        _normalize(candidate.groupName),
      );
      if (score > bestScore && score > 0.6) {
        // 相似度阈值
        bestScore = score;
        bestMatch = _CategoryMatch(candidate.groupName, candidate.categoryName, isFuzzy: true);
      }
    }

    return bestMatch;
  }

  static String _getPinyin(String text) {
    final result = <String>[];
    for (final char in text.runes) {
      final pinyinStr = pinyin.PinyinHelper.getPinyin(char.toString());
      if (pinyinStr.isNotEmpty) {
        result.add(pinyinStr);
      }
    }
    return result.join().toLowerCase();
  }

  static double _calculateSimilarity(String text1, String text2) {
    if (text1.isEmpty || text2.isEmpty) return 0.0;
    if (text1 == text2) return 1.0;

    // 计算编辑距离
    final matrix = List.generate(
      text1.length + 1,
      (_) => List.filled(text2.length + 1, 0),
    );

    for (var i = 0; i <= text1.length; i++) matrix[i][0] = i;
    for (var j = 0; j <= text2.length; j++) matrix[0][j] = j;

    for (var i = 1; i <= text1.length; i++) {
      for (var j = 1; j <= text2.length; j++) {
        final cost = text1[i - 1] == text2[j - 1] ? 0 : 1;
        matrix[i][j] = math.min(
          math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }

    final distance = matrix[text1.length][text2.length];
    final maxLength = math.max(text1.length, text2.length);
    return 1.0 - distance / maxLength;
  }

  static Account? _matchAccount(
    String text,
    List<Account> accounts, {
    bool allowFuzzy = true,
  }) {
    Account? unique(List<Account> matches) {
      final ids = matches.map((account) => account.id).toSet();
      return ids.length == 1 ? matches.first : null;
    }

    final normalizedText = _normalize(text);

    // 1. 直接匹配
    final byName = accounts.where((account) {
      final name = _normalize(account.name);
      return name.isNotEmpty && normalizedText.contains(name);
    }).toList();
    final direct = unique(byName);
    if (direct != null) {
      return direct;
    }

    // 1.5 机构名 + 账户类型的组合匹配
    final byHint = _matchAccountByHint(normalizedText, accounts);
    if (byHint != null) {
      return byHint;
    }

    // 2. 别名匹配
    const aliases = [
      '微信',
      '支付宝',
      '现金',
      '花呗',
      '招商',
      '工行',
      '工商',
      '农行',
      '农业',
      '建行',
      '建设',
      '银行卡',
      '储蓄卡',
      '信用卡',
      '信用购',
      '美团',
      '滴滴',
      '零钱',
    ];
    for (final alias in aliases) {
      if (!normalizedText.contains(_normalize(alias))) {
        continue;
      }
      if (alias == '零钱') {
        final wechatWallet = preferredWeChatWalletAccount(
          accounts.where((account) {
            return _accountMatchesAlias(account, alias);
          }).toList(),
        );
        if (wechatWallet != null) {
          return wechatWallet;
        }
      }
      final match = unique(
        accounts.where((account) {
          return _accountMatchesAlias(account, alias);
        }).toList(),
      );
      if (match != null) {
        return match;
      }
    }

    if (!allowFuzzy) {
      return null;
    }

    // 3. 拼音匹配
    final textPinyin = _getPinyin(normalizedText);
    for (final account in accounts) {
      final accountPinyin = _getPinyin(_normalize(account.name));
      if (textPinyin.contains(accountPinyin)) {
        return account;
      }
    }

    // 4. 模糊匹配（基于相似度）
    Account? bestMatch;
    double bestScore = 0.0;

    for (final account in accounts) {
      final score = _calculateSimilarity(
        normalizedText,
        _normalize(account.name),
      );
      if (score > bestScore && score > 0.6) {
        bestScore = score;
        bestMatch = account;
      }
    }

    return bestMatch;
  }

  static Account? _matchAccountByHint(
    String normalizedText,
    List<Account> accounts,
  ) {
    if (accounts.isEmpty) {
      return null;
    }

    Account? unique(List<Account> matches) {
      final ids = matches.map((account) => account.id).toSet();
      return ids.length == 1 ? matches.first : null;
    }

    final typeHint = _accountTypeHintFromText(normalizedText);
    final matchedKeywords = _accountInstitutionKeywords.where((keyword) {
      return normalizedText.contains(_normalize(keyword));
    }).toList();

    List<Account> filterByType(List<Account> candidates) {
      if (typeHint == null) {
        return candidates;
      }
      return candidates.where((account) {
        return _accountMatchesTypeHint(account, typeHint);
      }).toList();
    }

    if (matchedKeywords.isNotEmpty) {
      final hintedMatches = filterByType(
        accounts.where((account) {
          final accountName = _normalize(account.name);
          return matchedKeywords.any((keyword) {
            return accountName.contains(_normalize(keyword));
          });
        }).toList(),
      );

      final uniqueHint = unique(hintedMatches);
      if (uniqueHint != null) {
        return uniqueHint;
      }

      final simplifiedText = _simplifyAccountLabel(normalizedText);
      if (simplifiedText.isNotEmpty) {
        final narrowed = hintedMatches.where((account) {
          final simplifiedName = _simplifyAccountLabel(
            _normalize(account.name),
          );
          return simplifiedName.isNotEmpty &&
              (simplifiedText.contains(simplifiedName) ||
                  simplifiedName.contains(simplifiedText));
        }).toList();
        final uniqueNarrowed = unique(narrowed);
        if (uniqueNarrowed != null) {
          return uniqueNarrowed;
        }
      }
    }

    final simplifiedText = _simplifyAccountLabel(normalizedText);
    if (simplifiedText.isEmpty) {
      return null;
    }
    final simplifiedMatches = filterByType(
      accounts.where((account) {
        final simplifiedName = _simplifyAccountLabel(_normalize(account.name));
        return simplifiedName.isNotEmpty &&
            (simplifiedText.contains(simplifiedName) ||
                simplifiedName.contains(simplifiedText));
      }).toList(),
    );
    return unique(simplifiedMatches);
  }

  static Account? preferredWeChatWalletAccount(List<Account> accounts) {
    if (accounts.isEmpty) {
      return null;
    }

    Account? firstWhere(bool Function(Account account) test) {
      for (final account in accounts) {
        if (test(account)) {
          return account;
        }
      }
      return null;
    }

    for (final keyword in const ['微信钱包', '微信零钱', '微信零钱包']) {
      final exact = firstWhere((account) {
        return _normalize(account.name) == _normalize(keyword);
      });
      if (exact != null) {
        return exact;
      }
    }

    for (final keyword in const ['零钱', '钱包']) {
      final containsKeyword = firstWhere((account) {
        return _normalize(account.name).contains(_normalize(keyword));
      });
      if (containsKeyword != null) {
        return containsKeyword;
      }
    }

    final wechatIcon = firstWhere((account) {
      return account.iconKey.toLowerCase() == 'wechat';
    });
    if (wechatIcon != null) {
      return wechatIcon;
    }

    return _firstAccountContaining(accounts, const ['微信']);
  }

  static bool _accountMatchesAlias(Account account, String alias) {
    final name = _normalize(account.name);
    final iconKey = account.iconKey.toLowerCase();
    return switch (alias) {
      '微信' => name.contains('微信') || iconKey == 'wechat',
      '零钱' =>
        name.contains('微信') ||
            name.contains('零钱') ||
            name.contains('钱包') ||
            iconKey == 'wechat',
      '支付宝' => name.contains('支付宝') || iconKey == 'alipay',
      '现金' => account.type == AccountType.cash || name.contains('现金'),
      '花呗' =>
        name.contains('花呗') || name.contains('信用购') || iconKey == 'huabei',
      '招商' => name.contains('招商') || iconKey == 'cmb',
      '工行' ||
      '工商' => name.contains('工行') || name.contains('工商') || iconKey == 'icbc',
      '农行' ||
      '农业' => name.contains('农行') || name.contains('农业') || iconKey == 'abc',
      '建行' ||
      '建设' => name.contains('建行') || name.contains('建设') || iconKey == 'ccb',
      '银行卡' || '储蓄卡' =>
        account.type == AccountType.debitCard ||
            name.contains('银行卡') ||
            name.contains('储蓄卡'),
      '信用卡' => account.type == AccountType.creditCard || name.contains('信用卡'),
      '信用购' =>
        name.contains('信用购') || name.contains('花呗') || iconKey == 'huabei',
      '美团' => name.contains('美团') || iconKey == 'meituan',
      '滴滴' => name.contains('滴滴') || iconKey == 'didichuxing',
      _ => false,
    };
  }

  static AccountType? _accountTypeHintFromText(String normalizedText) {
    if (containsAny(normalizedText, const ['信用卡', '贷记卡'])) {
      return AccountType.creditCard;
    }
    if (containsAny(normalizedText, const ['储蓄卡', '借记卡'])) {
      return AccountType.debitCard;
    }
    if (containsAny(normalizedText, const ['微信', '支付宝', '花呗', '余额宝'])) {
      return AccountType.onlinePayment;
    }
    if (containsAny(normalizedText, const ['现金'])) {
      return AccountType.cash;
    }
    return null;
  }

  static bool _accountMatchesTypeHint(Account account, AccountType typeHint) {
    if (account.type == typeHint) {
      return true;
    }
    final name = _normalize(account.name);
    return switch (typeHint) {
      AccountType.creditCard => name.contains('信用卡') || name.contains('贷记卡'),
      AccountType.debitCard =>
        name.contains('储蓄卡') || name.contains('借记卡') || name.contains('银行卡'),
      AccountType.onlinePayment =>
        name.contains('微信') ||
            name.contains('支付宝') ||
            name.contains('花呗') ||
            name.contains('余额宝'),
      AccountType.cash => name.contains('现金'),
    };
  }

  static String _simplifyAccountLabel(String normalizedText) {
    var result = normalizedText;
    for (final token in const [
      '信用卡',
      '贷记卡',
      '储蓄卡',
      '借记卡',
      '银行卡',
      '银行',
      '钱包',
      '零钱包',
      '零钱',
      '账户',
      '卡',
    ]) {
      result = result.replaceAll(_normalize(token), '');
    }
    return result;
  }

  static bool containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(_normalize(keyword)));
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(
      RegExp(
        r'[\s，。,.、！!？?：:；;（）()【】\[\]「」“”"'
        '·]',
      ),
      '',
    );
  }

  static int? _parseChineseInteger(String value) {
    var total = 0;
    var section = 0;
    var number = 0;
    for (final char in value.characters) {
      final digit = _chineseDigit(char);
      if (digit != null) {
        number = digit;
        continue;
      }
      final unit = switch (char) {
        '十' => 10,
        '百' => 100,
        '千' => 1000,
        _ => null,
      };
      if (unit != null) {
        section += (number == 0 ? 1 : number) * unit;
        number = 0;
        continue;
      }
      if (char == '万') {
        section += number;
        total += section * 10000;
        section = 0;
        number = 0;
        continue;
      }
    }
    final result = total + section + number;
    return result == 0 ? null : result;
  }

  static int? _chineseDigit(String char) {
    return switch (char) {
      '零' => 0,
      '一' => 1,
      '二' || '两' => 2,
      '三' => 3,
      '四' => 4,
      '五' => 5,
      '六' => 6,
      '七' => 7,
      '八' => 8,
      '九' => 9,
      _ => null,
    };
  }
}

class _CategoryCandidate {
  const _CategoryCandidate(this.groupName, this.categoryName);

  final String groupName;
  final String categoryName;
}

class _CategoryMatch {
  const _CategoryMatch(this.groupName, this.categoryName, {this.isFuzzy = false});

  final String groupName;
  final String categoryName;
  final bool isFuzzy;
}

