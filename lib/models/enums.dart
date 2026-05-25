enum AccountType {
  cash('现金'),
  debitCard('储蓄卡'),
  onlinePayment('在线支付'),
  creditCard('信用卡');

  const AccountType(this.label);
  final String label;
}

enum LedgerEntryType {
  expense('支出'),
  income('收入'),
  transfer('转账');

  const LedgerEntryType(this.label);
  final String label;
}

enum AiProvider { deepSeek, qwen }

extension AiProviderX on AiProvider {
  String get storageValue => switch (this) {
    AiProvider.deepSeek => 'deepseek',
    AiProvider.qwen => 'qwen',
  };

  String get label => switch (this) {
    AiProvider.deepSeek => 'DeepSeek',
    AiProvider.qwen => '千问',
  };

  String get settingsDescription => switch (this) {
    AiProvider.deepSeek =>
      '图片识别会先用百度OCR识字；开启语音AI增强后，语音也会在转文字后交给DeepSeek理解并回填金额、分类和账户。',
    AiProvider.qwen => '图片识别会先用百度OCR识字；开启语音AI增强后，语音也会在转文字后交给千问理解并回填金额、分类和账户。',
  };

  String get apiKeyLabel => switch (this) {
    AiProvider.deepSeek => 'DeepSeek API Key',
    AiProvider.qwen => '千问 API Key',
  };

  String get endpoint => switch (this) {
    AiProvider.deepSeek => 'https://api.deepseek.com/chat/completions',
    AiProvider.qwen =>
      'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
  };

  String get model => switch (this) {
    AiProvider.deepSeek => 'deepseek-v4-flash',
    AiProvider.qwen => 'qwen2.5-7b-instruct',
  };

  String get providerSummary => switch (this) {
    AiProvider.deepSeek => '当前将调用 DeepSeek 接口做图片和语音文本理解。',
    AiProvider.qwen => '当前将调用千问接口做图片和语音文本理解。',
  };

  static AiProvider fromStorageValue(String? value) {
    return switch (value) {
      'qwen' => AiProvider.qwen,
      _ => AiProvider.deepSeek,
    };
  }
}

/// Sentinel value for copyWith optional parameters to distinguish
/// "not passed" from "explicitly passed null".
const unset = Object();
