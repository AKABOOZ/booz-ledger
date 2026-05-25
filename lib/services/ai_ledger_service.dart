import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:ledger_app/models/category.dart';
import 'package:ledger_app/models/enums.dart';
import 'package:ledger_app/services/ledger_text_parser.dart';
import 'package:ledger_app/store/ledger_store.dart';


class AiLedgerService {
  AiLedgerService({
    required this.provider,
    required this.apiKey,
    required this.model,
  });

  final AiProvider provider;
  final String apiKey;
  final String model;

  Future<VoiceParseResult?> parseOcrText(
    String ocrText, {
    required LedgerStore store,
  }) async {
    final response = await http.post(
      Uri.parse(provider.endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'response_format': {'type': 'json_object'},
        'temperature': 0.1,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {
            'role': 'user',
            'content': jsonEncode({
              'ocr_text': ocrText,
              'expense_categories': _categoryPayload(
                store.expenseCategoryGroups,
              ),
              'income_categories': _incomeCategoryPayload(
                store.incomeCategoryGroups,
              ),
              'accounts': [
                for (final account in store.accounts)
                  {
                    'id': account.id,
                    'name': account.name,
                    'type': account.type.name,
                    'iconKey': account.iconKey,
                  },
              ],
            }),
          },
        ],
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, Object?>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      return null;
    }
    final message = (choices.first as Map)['message'] as Map?;
    final content = message?['content']?.toString();
    if (content == null || content.trim().isEmpty) {
      return null;
    }
    final parsed = jsonDecode(_stripJsonFence(content)) as Map<String, Object?>;
    return _resultFromJson(parsed, ocrText: ocrText, store: store);
  }

  Future<VoiceParseResult?> parseVoiceText(
    String voiceText, {
    required LedgerStore store,
  }) async {
    final response = await http.post(
      Uri.parse(provider.endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'response_format': {'type': 'json_object'},
        'temperature': 0.1,
        'messages': [
          {'role': 'system', 'content': _voiceSystemPrompt},
          {
            'role': 'user',
            'content': jsonEncode({
              'voice_text': voiceText,
              'expense_categories': _categoryPayload(
                store.expenseCategoryGroups,
              ),
              'income_categories': _incomeCategoryPayload(
                store.incomeCategoryGroups,
              ),
              'accounts': [
                for (final account in store.accounts)
                  {
                    'id': account.id,
                    'name': account.name,
                    'type': account.type.name,
                    'iconKey': account.iconKey,
                  },
              ],
            }),
          },
        ],
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, Object?>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      return null;
    }
    final message = (choices.first as Map)['message'] as Map?;
    final content = message?['content']?.toString();
    if (content == null || content.trim().isEmpty) {
      return null;
    }
    final parsed = jsonDecode(_stripJsonFence(content)) as Map<String, Object?>;
    return _voiceResultFromJson(parsed, voiceText: voiceText, store: store);
  }

  Future<String?> testConnection() async {
    final response = await http.post(
      Uri.parse(provider.endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'response_format': {'type': 'json_object'},
        'temperature': 0,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a connection tester. Return JSON only.',
          },
          {
            'role': 'user',
            'content':
                '请返回JSON：{"ok":true,"provider":"${provider.label}","message":"connected"}',
          },
        ],
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return 'HTTP ${response.statusCode}';
    }
    final data = jsonDecode(response.body) as Map<String, Object?>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      return '响应为空';
    }
    final message = (choices.first as Map)['message'] as Map?;
    final content = message?['content']?.toString();
    if (content == null || content.trim().isEmpty) {
      return '响应内容为空';
    }
    try {
      final parsed =
          jsonDecode(_stripJsonFence(content)) as Map<String, Object?>;
      if (parsed['ok'] == true) {
        return null;
      }
      return parsed['message']?.toString() ?? '连接测试失败';
    } catch (_) {
      return '返回内容不是有效JSON';
    }
  }

  static const _systemPrompt = '''
你是记账APP的支付截图解析器。你会收到OCR识别文本、用户已有支出/收入小类、账户列表。
只输出JSON，不要解释。字段：
 type: expense/income/null
amount: number或null
occurredAt: YYYY-MM-DD HH:mm:ss或null
sourceApp: meituan/taobao/pinduoduo/wechat/alipay/unknown
expenseCategory: 支出小类精确名称或null
incomeCategory: 收入小类精确名称或null
accountId: 账户id或null
note: 简短备注，优先商户/商品/服务名称
confidence: 0到1
规则：
1. 支付截图通常是支出；只有“退款成功/已退款/退款到账/收入到账”等明确完成收入才是收入；“申请退款/退款按钮/退款入口”不是收入。图片识别记账不要输出transfer，只能输出expense或income。
2. 金额优先级：实付总额/实付/支付金额/付款金额/消费金额 > 商品总额 > 单价/优惠/配送费/订单号/时间。金额必须输出正数；如果截图里的金额带负号（如-12.34、-￥12.34），表示这是支出，type应为expense，amount输出去掉负号后的正数。
3. 尽量提取支付时间/下单时间/交易时间/订单时间，输出occurredAt；没有明确时间就null。
4. 账户必须从accounts里选择。若截图明确写了付款方式，就按付款方式选；若出现“零钱”，优先选“微信钱包/微信零钱/微信”类账户；若没有明确付款方式，但sourceApp是meituan，则优先选“美团月付/美团/月付”类账户；若sourceApp是taobao，则优先选“花呗/信用购”类账户；若sourceApp是wechat，则优先选“微信钱包/微信零钱/微信”类账户；仍无法确定就null。
5. 分类必须从给定小类中选择，无法确定就null。K歌/按摩/沐足/娱乐服务可选旅游度假或娱乐休闲相关小类；可乐/汽水/咖啡/饮料可选烟酒茶；手机/iphone/壳/耳机/数码配件优先考虑数码装备；出现“健身/健身房/瑜伽/普拉提/私教/拳击/游泳”等强运动服务词时，优先选“运动健身”，不要归到“其他杂项”。
6. 不要臆造不存在的分类或账户。低置信度时分类和账户用null，但sourceApp可以照常判断。
''';

  static const _voiceSystemPrompt = '''
你是记账APP的语音记账解析器。你会收到语音转写文本、用户已有支出/收入小类、账户列表。
只输出JSON，不要解释。字段：
type: expense/income/transfer/null
amount: number或null
occurredAt: YYYY-MM-DD HH:mm:ss或null
expenseCategory: 支出小类精确名称或null
incomeCategory: 收入小类精确名称或null
fromAccountId: 账户id或null
toAccountId: 账户id或null
note: 简短备注，尽量保留商户、用途或转账说明
confidence: 0到1
规则：
1. 分类必须从给定小类中选择，无法确定就null。
2. 账户必须从accounts里选择，无法确定就null，不要臆造不存在的账户。
3. “花了/买了/支付/付了/消费了”通常是expense；“收到/赚了/到账/工资/退款到账”通常是income；“转到/转给/转入/转出”且涉及两个账户时通常是transfer。
4. transfer时尽量同时给出fromAccountId和toAccountId；expense只填fromAccountId；income只填toAccountId。
5. 金额必须提取用户真正记账金额；没有明确金额就null。
6. 没有明确时间就occurredAt为null。
7. "停车费"应该归类为"私家车费用"；"打车/滴滴/出租车"归类为"打出租车"；"公交/地铁"归类为"公共交通"。
8. 低置信度时，类型以外的字段可以留null，不要乱猜。
''';

  static List<Map<String, Object?>> _categoryPayload(
    List<ExpenseCategoryGroup> groups,
  ) {
    return [
      for (final group in groups)
        {
          'group': group.name,
          'children': [for (final child in group.children) child.name],
        },
    ];
  }

  static List<Map<String, Object?>> _incomeCategoryPayload(
    List<IncomeCategoryGroup> groups,
  ) {
    return [
      for (final group in groups)
        {
          'group': group.name,
          'children': [for (final child in group.children) child.name],
        },
    ];
  }

  static String _stripJsonFence(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^```json\s*'), '')
        .replaceFirst(RegExp(r'^```\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
  }

  static VoiceParseResult? _resultFromJson(
    Map<String, Object?> json, {
    required String ocrText,
    required LedgerStore store,
  }) {
    final confidence = (json['confidence'] as num?)?.toDouble() ?? 0;
    if (confidence < 0.45) {
      return null;
    }
    final aiType = switch (json['type']?.toString()) {
      'expense' => LedgerEntryType.expense,
      'income' => LedgerEntryType.income,
      'transfer' => LedgerEntryType.transfer,
      _ => null,
    };
    final rawAmount = (json['amount'] as num?)?.toDouble();
    final amount = rawAmount?.abs();
    final type = LedgerTextParser.normalizeImageEntryType(
      aiType,
      rawText: ocrText,
      amount: rawAmount,
    );
    final note = json['note']?.toString().trim();
    final sourceApp = json['sourceApp']?.toString().trim();
    final occurredAt = LedgerTextParser.parseImageOccurredAt(
      json['occurredAt']?.toString(),
      fallbackText: ocrText,
    );
    final heuristicResult = LedgerTextParser.parseImage(ocrText, store: store);
    final heuristicAccountId = switch (type) {
      LedgerEntryType.expense => heuristicResult.fromAccountId,
      LedgerEntryType.income => heuristicResult.toAccountId,
      _ => null,
    };
    final wechatWalletAccountId =
        LedgerTextParser.containsAny(ocrText, const ['零钱'])
        ? LedgerTextParser.preferredWeChatWalletAccount(store.accounts)?.id
        : null;
    var accountId = _validAccountId(json['accountId']?.toString(), store);
    if (wechatWalletAccountId != null) {
      accountId = heuristicAccountId ?? wechatWalletAccountId;
    }
    accountId ??=
        heuristicAccountId ??
        wechatWalletAccountId ??
        LedgerTextParser.fallbackAccountIdForSourceApp(sourceApp, store);
    final expenseCategory = json['expenseCategory']?.toString().trim();
    final incomeCategory = json['incomeCategory']?.toString().trim();
    final validExpenseCategory =
        type == LedgerEntryType.expense &&
        expenseCategory != null &&
        store.expenseItemByName(expenseCategory) != null &&
        confidence >= 0.68;
    final validIncomeCategory =
        type == LedgerEntryType.income &&
        incomeCategory != null &&
        store.incomeItemByName(incomeCategory) != null &&
        confidence >= 0.68;
    String? resolvedExpenseCategory = validExpenseCategory
        ? expenseCategory
        : null;
    String? resolvedExpenseGroup = resolvedExpenseCategory == null
        ? null
        : store.groupNameForExpenseCategory(resolvedExpenseCategory);
    if (type == LedgerEntryType.expense &&
        heuristicResult.expenseCategory != null &&
        _shouldPreferHeuristicExpenseCategory(
          ocrText: ocrText,
          aiCategory: resolvedExpenseCategory,
          heuristicCategory: heuristicResult.expenseCategory!,
          store: store,
        )) {
      resolvedExpenseCategory = heuristicResult.expenseCategory;
      resolvedExpenseGroup = heuristicResult.expenseGroup;
    }
    final resolvedAccountName = accountId == null
        ? null
        : store.accountById(accountId)?.name;
    final resolvedHints = <String>[];
    if (resolvedExpenseCategory != null) {
      resolvedHints.add(resolvedExpenseCategory);
    }
    if (validIncomeCategory) {
      resolvedHints.add(incomeCategory);
    }
    if (resolvedAccountName != null) {
      resolvedHints.add(resolvedAccountName);
    }
    return VoiceParseResult(
      type: type,
      amount: amount,
      note: note == null || note.isEmpty ? ocrText : note,
      occurredAt: occurredAt,
      expenseGroup: resolvedExpenseGroup,
      expenseCategory: resolvedExpenseCategory,
      incomeGroup: validIncomeCategory
          ? store.groupNameForIncomeCategory(incomeCategory)
          : null,
      incomeCategory: validIncomeCategory ? incomeCategory : null,
      fromAccountId: type == LedgerEntryType.expense ? accountId : null,
      toAccountId: type == LedgerEntryType.income ? accountId : null,
      hints: resolvedHints.where((item) => item.isNotEmpty).toList(),
    );
  }

  static VoiceParseResult? _voiceResultFromJson(
    Map<String, Object?> json, {
    required String voiceText,
    required LedgerStore store,
  }) {
    final confidence = (json['confidence'] as num?)?.toDouble() ?? 0;
    if (confidence < 0.45) {
      return null;
    }
    final type = switch (json['type']?.toString()) {
      'expense' => LedgerEntryType.expense,
      'income' => LedgerEntryType.income,
      'transfer' => LedgerEntryType.transfer,
      _ => null,
    };
    final amount = (json['amount'] as num?)?.toDouble().abs();
    final note = json['note']?.toString().trim();
    final occurredAt = ExternalQuickAddDraft.parseOccurredAt(
      json['occurredAt']?.toString(),
    );
    final expenseCategory = json['expenseCategory']?.toString().trim();
    final incomeCategory = json['incomeCategory']?.toString().trim();
    final fromAccountId = _validAccountId(
      json['fromAccountId']?.toString(),
      store,
    );
    final toAccountId = _validAccountId(json['toAccountId']?.toString(), store);
    final resolvedHints = <String>[
      if (expenseCategory != null &&
          store.expenseItemByName(expenseCategory) != null)
        expenseCategory,
      if (incomeCategory != null &&
          store.incomeItemByName(incomeCategory) != null)
        incomeCategory,
      if (fromAccountId != null) store.accountById(fromAccountId)?.name ?? '',
      if (toAccountId != null) store.accountById(toAccountId)?.name ?? '',
    ].where((item) => item.isNotEmpty).toList();
    return VoiceParseResult(
      type: type,
      amount: amount,
      note: note == null || note.isEmpty ? voiceText : note,
      occurredAt: occurredAt,
      expenseGroup: expenseCategory == null
          ? null
          : store.groupNameForExpenseCategory(expenseCategory),
      expenseCategory:
          expenseCategory != null &&
              store.expenseItemByName(expenseCategory) != null
          ? expenseCategory
          : null,
      incomeGroup: incomeCategory == null
          ? null
          : store.groupNameForIncomeCategory(incomeCategory),
      incomeCategory:
          incomeCategory != null &&
              store.incomeItemByName(incomeCategory) != null
          ? incomeCategory
          : null,
      fromAccountId: switch (type) {
        LedgerEntryType.expense => fromAccountId,
        LedgerEntryType.transfer => fromAccountId,
        _ => null,
      },
      toAccountId: switch (type) {
        LedgerEntryType.income => toAccountId,
        LedgerEntryType.transfer => toAccountId,
        _ => null,
      },
      hints: resolvedHints,
    );
  }

  static bool _shouldPreferHeuristicExpenseCategory({
    required String ocrText,
    required String? aiCategory,
    required String heuristicCategory,
    required LedgerStore store,
  }) {
    if (aiCategory == null) {
      return true;
    }
    if (aiCategory == heuristicCategory) {
      return false;
    }
    final aiGroup = store.groupNameForExpenseCategory(aiCategory);
    final heuristicGroup = store.groupNameForExpenseCategory(heuristicCategory);
    if (aiGroup == '其他杂项' && heuristicGroup != '其他杂项') {
      return true;
    }
    if (heuristicCategory == '运动健身' &&
        LedgerTextParser.containsAny(ocrText, const [
          '健身',
          '健身房',
          '瑜伽',
          '普拉提',
          '私教',
          '拳击',
          '游泳',
          '撸铁',
        ])) {
      return true;
    }
    return false;
  }

  static String? _validAccountId(String? id, LedgerStore store) {
    if (id == null || id.isEmpty) {
      return null;
    }
    return store.accountById(id) == null ? null : id;
  }
}
