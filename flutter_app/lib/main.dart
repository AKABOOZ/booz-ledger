import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';

class BaiduSpeechService {
  final String apiKey;
  final String secretKey;
  String? _accessToken;
  DateTime? _tokenExpireTime;

  BaiduSpeechService({required this.apiKey, required this.secretKey});

  Future<String?> getAccessToken() async {
    if (_accessToken != null && _tokenExpireTime != null) {
      if (DateTime.now().isBefore(_tokenExpireTime!)) {
        return _accessToken;
      }
    }

    final response = await http.post(
      Uri.parse('https://aip.baidubce.com/oauth/2.0/token'),
      body: {
        'grant_type': 'client_credentials',
        'client_id': apiKey,
        'client_secret': secretKey,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      final expiresIn = data['expires_in'] as int;
      _tokenExpireTime = DateTime.now().add(Duration(seconds: expiresIn - 60));
      return _accessToken;
    }
    return null;
  }

  Future<String?> recognizeSpeech(String filePath) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return null;

    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final base64Audio = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('https://vop.baidu.com/server_api'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'format': 'wav',
        'rate': 16000,
        'channel': 1,
        'cuid': 'ledger_app',
        'token': accessToken,
        'speech': base64Audio,
        'len': bytes.length,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['err_no'] == 0 && data['result'] != null && data['result'].isNotEmpty) {
        return data['result'][0];
      }
    }
    return null;
  }
}

class VoiceParseResult {
  final LedgerEntryType? type;
  final double? amount;
  final String? category;
  final String? note;

  VoiceParseResult({
    this.type,
    this.amount,
    this.category,
    this.note,
  });
}

class VoiceInputParser {
  static VoiceParseResult parse(String text) {
    LedgerEntryType? type;
    double? amount;
    String? category;
    String? note = text;

    if (text.contains('收入') || text.contains('赚了') || text.contains('收到')) {
      type = LedgerEntryType.income;
    } else if (text.contains('转账') || text.contains('转')) {
      type = LedgerEntryType.transfer;
    } else {
      type = LedgerEntryType.expense;
    }

    final amountMatch = RegExp(r'(\d+(\.\d+)?)').firstMatch(text);
    if (amountMatch != null) {
      amount = double.tryParse(amountMatch.group(1)!);
    }

    return VoiceParseResult(
      type: type,
      amount: amount,
      category: category,
      note: note,
    );
  }
}

void main() {
  runApp(const LedgerApp());
}

class LedgerApp extends StatefulWidget {
  const LedgerApp({super.key});

  @override
  State<LedgerApp> createState() => _LedgerAppState();
}

class _LedgerAppState extends State<LedgerApp> {
  late final LedgerStore _store;

  @override
  void initState() {
    super.initState();
    _store = LedgerStore()..load();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LedgerScope(
      store: _store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '波哥记账',
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN')],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF167C80),
            surface: const Color(0xFFF8FAF6),
          ),
          scaffoldBackgroundColor: const Color(0xFFF8FAF6),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            titleTextStyle: TextStyle(
              color: Color(0xFF16211F),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0.8,
            shadowColor: const Color(0x1A53615D),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0x33167C80), width: 1),
            ),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Color(0xFFF8FAF6),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            indicatorColor: const Color(0xFFC4E5E0),
          ),
        ),
        home: const LedgerHome(),
      ),
    );
  }
}

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

const _unset = Object();

class ExpenseCategoryItem {
  const ExpenseCategoryItem(this.name, this.iconKey);

  final String name;
  final String iconKey;
}

class ExpenseCategoryGroup {
  const ExpenseCategoryGroup(this.name, this.children);

  final String name;
  final List<ExpenseCategoryItem> children;
}

class IncomeCategoryGroup {
  const IncomeCategoryGroup(this.name, this.children);

  final String name;
  final List<ExpenseCategoryItem> children;
}

class CustomCategory {
  const CustomCategory({
    required this.type,
    required this.groupName,
    required this.name,
    required this.iconKey,
  });

  final LedgerEntryType type;
  final String groupName;
  final String name;
  final String iconKey;

  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'groupName': groupName,
      'name': name,
      'iconKey': iconKey,
    };
  }

  factory CustomCategory.fromJson(Map<String, Object?> json) {
    return CustomCategory(
      type: LedgerEntryType.values.byName(json['type'] as String),
      groupName: json['groupName'] as String,
      name: json['name'] as String,
      iconKey: json['iconKey'] as String,
    );
  }
}

const defaultExpenseCategoryGroups = [
  ExpenseCategoryGroup('食品酒水', [
    ExpenseCategoryItem('早餐晚餐', 'restaurant'),
    ExpenseCategoryItem('烟酒茶', 'local_cafe'),
    ExpenseCategoryItem('水果零食', 'bakery'),
  ]),
  ExpenseCategoryGroup('居家物业', [
    ExpenseCategoryItem('日常用品', 'inventory'),
    ExpenseCategoryItem('水电煤气', 'bolt'),
    ExpenseCategoryItem('房租', 'home'),
    ExpenseCategoryItem('物业管理', 'apartment'),
    ExpenseCategoryItem('维修保养', 'build'),
  ]),
  ExpenseCategoryGroup('衣服饰品', [
    ExpenseCategoryItem('衣服裤子', 'checkroom'),
    ExpenseCategoryItem('鞋帽包包', 'shopping_bag'),
    ExpenseCategoryItem('化妆饰品', 'diamond'),
  ]),
  ExpenseCategoryGroup('行车交通', [
    ExpenseCategoryItem('公共交通', 'directions_bus'),
    ExpenseCategoryItem('打出租车', 'local_taxi'),
    ExpenseCategoryItem('私家车费用', 'directions_car'),
    ExpenseCategoryItem('车贷', 'car_rental'),
  ]),
  ExpenseCategoryGroup('交流通讯', [
    ExpenseCategoryItem('座机费', 'phone'),
    ExpenseCategoryItem('手机费', 'smartphone'),
    ExpenseCategoryItem('上网费', 'wifi'),
    ExpenseCategoryItem('邮寄费', 'local_shipping'),
  ]),
  ExpenseCategoryGroup('休闲娱乐', [
    ExpenseCategoryItem('运动健身', 'fitness_center'),
    ExpenseCategoryItem('腐败聚会', 'celebration'),
    ExpenseCategoryItem('休闲玩乐', 'sports_esports'),
    ExpenseCategoryItem('宠物宝贝', 'pets'),
    ExpenseCategoryItem('旅游度假', 'flight_takeoff'),
  ]),
  ExpenseCategoryGroup('学习进修', [
    ExpenseCategoryItem('数码装备', 'devices'),
    ExpenseCategoryItem('书报杂志', 'menu_book'),
    ExpenseCategoryItem('培训进修', 'school'),
    ExpenseCategoryItem('AI使用费', 'auto_awesome'),
  ]),
  ExpenseCategoryGroup('人情往来', [
    ExpenseCategoryItem('送礼请客', 'redeem'),
    ExpenseCategoryItem('孝敬家长', 'family_restroom'),
    ExpenseCategoryItem('还人钱财', 'currency_exchange'),
    ExpenseCategoryItem('慈善捐助', 'volunteer_activism'),
  ]),
  ExpenseCategoryGroup('医疗保健', [
    ExpenseCategoryItem('药品费', 'medication'),
    ExpenseCategoryItem('保健费', 'health_and_safety'),
    ExpenseCategoryItem('美容费', 'spa'),
    ExpenseCategoryItem('治疗费', 'medical_services'),
  ]),
  ExpenseCategoryGroup('金融保险', [
    ExpenseCategoryItem('银行手续', 'account_balance'),
    ExpenseCategoryItem('投资亏损', 'trending_down'),
    ExpenseCategoryItem('按揭还款', 'real_estate_agent'),
    ExpenseCategoryItem('消费税收', 'receipt_long'),
    ExpenseCategoryItem('利息支出', 'percent'),
    ExpenseCategoryItem('赔偿罚款', 'gavel'),
  ]),
  ExpenseCategoryGroup('其他杂项', [
    ExpenseCategoryItem('其他起初', 'more_horiz'),
    ExpenseCategoryItem('意外丢失', 'report_problem'),
    ExpenseCategoryItem('烂账损失', 'money_off'),
  ]),
];
const defaultIncomeCategoryGroups = [
  IncomeCategoryGroup('职业收入', [
    ExpenseCategoryItem('工资收入', 'work'),
    ExpenseCategoryItem('利息收入', 'savings'),
    ExpenseCategoryItem('加班收入', 'schedule'),
    ExpenseCategoryItem('奖金收入', 'emoji_events'),
    ExpenseCategoryItem('兼职收入', 'badge'),
    ExpenseCategoryItem('投资收入', 'trending_up'),
    ExpenseCategoryItem('淘宝退款', 'shopping_cart_checkout'),
  ]),
  IncomeCategoryGroup('其他收入', [
    ExpenseCategoryItem('礼金收入', 'redeem'),
    ExpenseCategoryItem('中奖收入', 'stars'),
    ExpenseCategoryItem('意外收入', 'auto_awesome'),
    ExpenseCategoryItem('经营所得', 'storefront'),
    ExpenseCategoryItem('信用卡还款', 'credit_score'),
    ExpenseCategoryItem('自媒体收入', 'smart_display'),
    ExpenseCategoryItem('出售闲置', 'sell'),
    ExpenseCategoryItem('顺风车', 'directions_car'),
  ]),
];

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.balanceInCents,
    required this.type,
    required this.iconKey,
    this.repaymentDay,
  });

  final String id;
  final String name;
  final int balanceInCents;
  final AccountType type;
  final String iconKey;
  final int? repaymentDay;

  Account copyWith({
    String? name,
    int? balanceInCents,
    AccountType? type,
    String? iconKey,
    Object? repaymentDay = _unset,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      balanceInCents: balanceInCents ?? this.balanceInCents,
      type: type ?? this.type,
      iconKey: iconKey ?? this.iconKey,
      repaymentDay: repaymentDay == _unset
          ? this.repaymentDay
          : repaymentDay as int?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'balanceInCents': balanceInCents,
      'type': type.name,
      'iconKey': iconKey,
      'repaymentDay': repaymentDay,
    };
  }

  factory Account.fromJson(Map<String, Object?> json) {
    final type = accountTypeFromJson(json['type'] as String?);
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      balanceInCents: json['balanceInCents'] as int,
      type: type,
      iconKey: json['iconKey'] as String? ?? defaultAccountIconKey(type),
      repaymentDay: json['repaymentDay'] as int?,
    );
  }
}

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
    Object? category = _unset,
    Object? expenseGroup = _unset,
    Object? expenseCategory = _unset,
    Object? incomeGroup = _unset,
    Object? incomeCategory = _unset,
    Object? fromAccountId = _unset,
    Object? toAccountId = _unset,
  }) {
    return LedgerEntry(
      id: id,
      type: type ?? this.type,
      amountInCents: amountInCents ?? this.amountInCents,
      occurredAt: occurredAt ?? this.occurredAt,
      note: note ?? this.note,
      category: category == _unset ? this.category : category as String?,
      expenseGroup: expenseGroup == _unset
          ? this.expenseGroup
          : expenseGroup as String?,
      expenseCategory: expenseCategory == _unset
          ? this.expenseCategory
          : expenseCategory as String?,
      incomeGroup: incomeGroup == _unset
          ? this.incomeGroup
          : incomeGroup as String?,
      incomeCategory: incomeCategory == _unset
          ? this.incomeCategory
          : incomeCategory as String?,
      fromAccountId: fromAccountId == _unset
          ? this.fromAccountId
          : fromAccountId as String?,
      toAccountId: toAccountId == _unset
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
      occurredAt: DateTime.parse(json['occurredAt'] as String),
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

AccountType accountTypeFromJson(String? value) {
  return switch (value) {
    'cash' => AccountType.cash,
    'debitCard' => AccountType.debitCard,
    'onlinePayment' || 'wallet' || null => AccountType.onlinePayment,
    'creditCard' => AccountType.creditCard,
    _ => AccountType.onlinePayment,
  };
}

String defaultAccountIconKey(AccountType type) {
  return switch (type) {
    AccountType.cash => 'cash',
    AccountType.debitCard => 'debit_card',
    AccountType.onlinePayment => 'wallet',
    AccountType.creditCard => 'credit_card',
  };
}

class AccountIconOption {
  const AccountIconOption(this.key, this.label, this.icon, this.color, {this.assetPath});

  final String key;
  final String label;
  final IconData? icon;
  final Color color;
  final String? assetPath;
}

const accountIconOptions = [
  AccountIconOption('wechat', '微信', Icons.wechat, Color(0xFF19A15F)),
  AccountIconOption('alipay', '支付宝', Icons.payments, Color(0xFF1677FF)),
  AccountIconOption('cash', '现金', Icons.payments_outlined, Color(0xFF4D8C57)),
  AccountIconOption(
    'wallet',
    '钱包',
    Icons.account_balance_wallet,
    Color(0xFF8B6FDF),
  ),
  AccountIconOption('debit_card', '储蓄卡', Icons.credit_card, Color(0xFF52637A)),
  AccountIconOption(
    'credit_card',
    '信用卡',
    Icons.credit_score,
    Color(0xFFD16B58),
  ),
  AccountIconOption('bank', '银行', Icons.account_balance, Color(0xFF0F766E)),
  AccountIconOption('saving', '存钱罐', Icons.savings, Color(0xFFE09B32)),
  AccountIconOption('meituan', '美团', null, Color(0xFFFF6700), assetPath: 'assets/icons/meituan.svg'),
  AccountIconOption('didichuxing', '滴滴出行', null, Color(0xFFFF5A5F), assetPath: 'assets/icons/didi.svg'),
  AccountIconOption('hellochuxing', '哈啰出行', null, Color(0xFF00B5EE), assetPath: 'assets/icons/haluo.svg'),
  AccountIconOption('huabei', '花呗', null, Color(0xFFFF6A00), assetPath: 'assets/icons/huabei.svg'),
  AccountIconOption('cmb', '招商银行', null, Color(0xFFE50012), assetPath: 'assets/icons/zhaoshang.svg'),
  AccountIconOption('abc', '农业银行', null, Color(0xFF009933), assetPath: 'assets/icons/nongye.svg'),
  AccountIconOption('icbc', '工商银行', null, Color(0xFFD92121), assetPath: 'assets/icons/gongshang.svg'),
  AccountIconOption('ccb', '建设银行', null, Color(0xFF0066B3), assetPath: 'assets/icons/jianshe.svg'),
  AccountIconOption('liushui', '流水', null, Color(0xFF167C80), assetPath: 'assets/icons/liushui.svg'),
];

AccountIconOption accountIconOption(String key) {
  return accountIconOptions.firstWhere(
    (option) => option.key == key,
    orElse: () => accountIconOptions.first,
  );
}

IconData categoryIcon(String key) {
  return switch (key) {
    'restaurant' => Icons.restaurant,
    'local_cafe' => Icons.local_cafe,
    'bakery' => Icons.bakery_dining,
    'inventory' => Icons.inventory_2,
    'bolt' => Icons.bolt,
    'home' => Icons.home_rounded,
    'apartment' => Icons.apartment,
    'build' => Icons.build,
    'checkroom' => Icons.checkroom,
    'shopping_bag' => Icons.shopping_bag,
    'diamond' => Icons.diamond,
    'directions_bus' => Icons.directions_bus,
    'local_taxi' => Icons.local_taxi,
    'directions_car' => Icons.directions_car,
    'car_rental' => Icons.car_rental,
    'phone' => Icons.phone,
    'smartphone' => Icons.smartphone,
    'wifi' => Icons.wifi,
    'local_shipping' => Icons.local_shipping,
    'fitness_center' => Icons.fitness_center,
    'celebration' => Icons.celebration,
    'sports_esports' => Icons.sports_esports,
    'pets' => Icons.pets,
    'flight_takeoff' => Icons.flight_takeoff,
    'devices' => Icons.devices,
    'menu_book' => Icons.menu_book,
    'school' => Icons.school,
    'auto_awesome' => Icons.auto_awesome,
    'work' => Icons.work,
    'savings' => Icons.savings,
    'schedule' => Icons.schedule,
    'emoji_events' => Icons.emoji_events,
    'badge' => Icons.badge,
    'trending_up' => Icons.trending_up,
    'shopping_cart_checkout' => Icons.shopping_cart_checkout,
    'stars' => Icons.stars,
    'storefront' => Icons.storefront,
    'credit_score' => Icons.credit_score,
    'smart_display' => Icons.smart_display,
    'sell' => Icons.sell,
    'redeem' => Icons.redeem,
    'family_restroom' => Icons.family_restroom,
    'currency_exchange' => Icons.currency_exchange,
    'volunteer_activism' => Icons.volunteer_activism,
    'medication' => Icons.medication,
    'health_and_safety' => Icons.health_and_safety,
    'spa' => Icons.spa,
    'medical_services' => Icons.medical_services,
    'account_balance' => Icons.account_balance,
    'trending_down' => Icons.trending_down,
    'real_estate_agent' => Icons.real_estate_agent,
    'receipt_long' => Icons.receipt_long,
    'percent' => Icons.percent,
    'gavel' => Icons.gavel,
    'more_horiz' => Icons.more_horiz,
    'report_problem' => Icons.report_problem,
    'money_off' => Icons.money_off,
    _ => Icons.category,
  };
}

class LedgerStore extends ChangeNotifier {
  static const _storageKey = 'ledger_app_state_v1';
  static const _apiKey = 'baidu_api_key';
  static const _secretKey = 'baidu_secret_key';

  final List<Account> _accounts = [];
  final List<LedgerEntry> _entries = [];
  final List<CustomCategory> _customCategories = [];
  bool _isLoading = true;
  bool _isAmountHidden = false;
  String? _baiduApiKey;
  String? _baiduSecretKey;

  bool get isLoading => _isLoading;
  bool get isAmountHidden => _isAmountHidden;
  List<Account> get accounts => List.unmodifiable(_accounts);
  String? get baiduApiKey => _baiduApiKey;
  String? get baiduSecretKey => _baiduSecretKey;

  void setAmountHidden(bool value) {
    _isAmountHidden = value;
    notifyListeners();
  }

  Future<void> setBaiduApiKey(String? value) async {
    _baiduApiKey = value;
    final prefs = await SharedPreferences.getInstance();
    if (value != null) {
      await prefs.setString(_apiKey, value);
    } else {
      await prefs.remove(_apiKey);
    }
    notifyListeners();
  }

  Future<void> setBaiduSecretKey(String? value) async {
    _baiduSecretKey = value;
    final prefs = await SharedPreferences.getInstance();
    if (value != null) {
      await prefs.setString(_secretKey, value);
    } else {
      await prefs.remove(_secretKey);
    }
    notifyListeners();
  }
  List<ExpenseCategoryGroup> get expenseCategoryGroups {
    return defaultExpenseCategoryGroups.map((group) {
      return ExpenseCategoryGroup(group.name, [
        ...group.children,
        ..._customCategories
            .where((item) {
              return item.type == LedgerEntryType.expense &&
                  item.groupName == group.name;
            })
            .map((item) => ExpenseCategoryItem(item.name, item.iconKey)),
      ]);
    }).toList();
  }

  List<IncomeCategoryGroup> get incomeCategoryGroups {
    return defaultIncomeCategoryGroups.map((group) {
      return IncomeCategoryGroup(group.name, [
        ...group.children,
        ..._customCategories
            .where((item) {
              return item.type == LedgerEntryType.income &&
                  item.groupName == group.name;
            })
            .map((item) => ExpenseCategoryItem(item.name, item.iconKey)),
      ]);
    }).toList();
  }

  List<LedgerEntry> get entries {
    final sorted = [..._entries]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return List.unmodifiable(sorted);
  }

  int get totalBalanceInCents {
    return _accounts.fold(0, (sum, account) => sum + account.balanceInCents);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      final accounts = decoded['accounts'] as List<Object?>? ?? [];
      final entries = decoded['entries'] as List<Object?>? ?? [];
      final customCategories =
          decoded['customCategories'] as List<Object?>? ?? [];
      _accounts
        ..clear()
        ..addAll(
          accounts.map((item) {
            return Account.fromJson((item as Map).cast<String, Object?>());
          }),
        );
      _entries
        ..clear()
        ..addAll(
          entries.map((item) {
            return LedgerEntry.fromJson((item as Map).cast<String, Object?>());
          }),
        );
      _customCategories
        ..clear()
        ..addAll(
          customCategories.map((item) {
            return CustomCategory.fromJson(
              (item as Map).cast<String, Object?>(),
            );
          }),
        );
    }
    _baiduApiKey = prefs.getString(_apiKey);
    _baiduSecretKey = prefs.getString(_secretKey);
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addCustomCategory(CustomCategory category) async {
    if (categoryExists(category.type, category.name)) {
      return false;
    }
    _customCategories.add(category);
    await _save();
    return true;
  }

  bool categoryExists(LedgerEntryType type, String name) {
    return categoriesFor(type).any((item) => item == name);
  }

  Future<void> replaceImportedData(ImportedLedgerData data) async {
    _accounts
      ..clear()
      ..addAll(
        data.accounts.map((account) {
          return account.copyWith(balanceInCents: 0);
        }),
      );
    _entries
      ..clear()
      ..addAll(data.entries);
    _customCategories
      ..clear()
      ..addAll(data.customCategories);
    for (final entry in _entries) {
      _applyEntryEffect(entry);
    }
    await _save();
  }

  Future<void> addAccount(Account account) async {
    _accounts.add(account);
    await _save();
  }

  Future<void> updateAccount(Account account) async {
    final index = _accounts.indexWhere((item) => item.id == account.id);
    if (index == -1) {
      return;
    }
    _accounts[index] = account;
    await _save();
  }

  Future<void> deleteAccount(String accountId) async {
    final relatedEntries = _entries.where((entry) {
      return entry.fromAccountId == accountId || entry.toAccountId == accountId;
    }).toList();
    for (final entry in relatedEntries) {
      _applyEntryEffect(entry, reverse: true);
      _entries.removeWhere((item) => item.id == entry.id);
    }
    _accounts.removeWhere((account) => account.id == accountId);
    await _save();
  }

  Future<void> addEntry(LedgerEntry entry) async {
    _entries.add(entry);
    _applyEntryEffect(entry);
    await _save();
  }

  Future<void> updateEntry(LedgerEntry entry) async {
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      return;
    }
    _applyEntryEffect(_entries[index], reverse: true);
    _entries[index] = entry;
    _applyEntryEffect(entry);
    await _save();
  }

  Future<void> deleteEntry(String entryId) async {
    final index = _entries.indexWhere((entry) => entry.id == entryId);
    if (index == -1) {
      return;
    }
    _applyEntryEffect(_entries[index], reverse: true);
    _entries.removeAt(index);
    await _save();
  }

  Account? accountById(String? id) {
    if (id == null) {
      return null;
    }
    for (final account in _accounts) {
      if (account.id == id) {
        return account;
      }
    }
    return null;
  }

  List<String> categoriesFor(LedgerEntryType type) {
    return switch (type) {
      LedgerEntryType.expense => expenseLeafNames,
      LedgerEntryType.income => incomeLeafNames,
      LedgerEntryType.transfer => const [],
    };
  }

  List<String> get expenseLeafNames {
    return [
      for (final group in expenseCategoryGroups)
        for (final child in group.children) child.name,
    ];
  }

  List<String> get incomeLeafNames {
    return [
      for (final group in incomeCategoryGroups)
        for (final child in group.children) child.name,
    ];
  }

  ExpenseCategoryGroup? expenseGroupByName(String? name) {
    for (final group in expenseCategoryGroups) {
      if (group.name == name) {
        return group;
      }
    }
    return null;
  }

  ExpenseCategoryItem? expenseItemByName(String? name) {
    for (final group in expenseCategoryGroups) {
      for (final item in group.children) {
        if (item.name == name) {
          return item;
        }
      }
    }
    return null;
  }

  String? groupNameForExpenseCategory(String? category) {
    for (final group in expenseCategoryGroups) {
      for (final item in group.children) {
        if (item.name == category) {
          return group.name;
        }
      }
    }
    return null;
  }

  ExpenseCategoryItem? incomeItemByName(String? name) {
    for (final group in incomeCategoryGroups) {
      for (final item in group.children) {
        if (item.name == name) {
          return item;
        }
      }
    }
    return null;
  }

  String? groupNameForIncomeCategory(String? category) {
    for (final group in incomeCategoryGroups) {
      for (final item in group.children) {
        if (item.name == category) {
          return group.name;
        }
      }
    }
    return null;
  }

  void _applyEntryEffect(LedgerEntry entry, {bool reverse = false}) {
    final sign = reverse ? -1 : 1;
    if (entry.type == LedgerEntryType.expense && entry.fromAccountId != null) {
      _adjustAccount(entry.fromAccountId!, -entry.amountInCents * sign);
    }
    if (entry.type == LedgerEntryType.income && entry.toAccountId != null) {
      _adjustAccount(entry.toAccountId!, entry.amountInCents * sign);
    }
    if (entry.type == LedgerEntryType.transfer) {
      if (entry.fromAccountId != null) {
        _adjustAccount(entry.fromAccountId!, -entry.amountInCents * sign);
      }
      if (entry.toAccountId != null) {
        _adjustAccount(entry.toAccountId!, entry.amountInCents * sign);
      }
    }
  }

  void _adjustAccount(String id, int deltaInCents) {
    final index = _accounts.indexWhere((account) => account.id == id);
    if (index == -1) {
      return;
    }
    final account = _accounts[index];
    _accounts[index] = account.copyWith(
      balanceInCents: account.balanceInCents + deltaInCents,
      repaymentDay: account.repaymentDay,
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'accounts': _accounts.map((account) => account.toJson()).toList(),
      'entries': _entries.map((entry) => entry.toJson()).toList(),
      'customCategories': _customCategories
          .map((category) => category.toJson())
          .toList(),
    });
    await prefs.setString(_storageKey, payload);
    notifyListeners();
  }

  Future<File> exportBackupData() async {
    final payload = jsonEncode({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': _accounts.map((account) => account.toJson()).toList(),
      'entries': _entries.map((entry) => entry.toJson()).toList(),
      'customCategories': _customCategories
          .map((category) => category.toJson())
          .toList(),
    });
    
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/ledger_backup_$timestamp.json');
    await file.writeAsString(payload);
    return file;
  }

  Future<void> importBackupData(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final decoded = jsonDecode(content) as Map<String, Object?>;
    
    final version = decoded['version'] as int? ?? 1;
    if (version > 1) {
      throw UnsupportedError('备份文件版本过高，无法导入');
    }
    
    final accounts = decoded['accounts'] as List<Object?>? ?? [];
    final entries = decoded['entries'] as List<Object?>? ?? [];
    final customCategories =
        decoded['customCategories'] as List<Object?>? ?? [];
    
    _accounts
      ..clear()
      ..addAll(
        accounts.map((item) {
          return Account.fromJson((item as Map).cast<String, Object?>());
        }),
      );
    _entries
      ..clear()
      ..addAll(
        entries.map((item) {
          return LedgerEntry.fromJson((item as Map).cast<String, Object?>());
        }),
      );
    _customCategories
      ..clear()
      ..addAll(
        customCategories.map((item) {
          return CustomCategory.fromJson(
            (item as Map).cast<String, Object?>(),
          );
        }),
      );
    
    await _save();
  }
}

class LedgerScope extends InheritedNotifier<LedgerStore> {
  const LedgerScope({
    required LedgerStore store,
    required super.child,
    super.key,
  }) : super(notifier: store);

  static LedgerStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LedgerScope>();
    assert(scope != null, 'LedgerScope is missing');
    return scope!.notifier!;
  }
}

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
      ? const {'早午晚餐': '早餐晚餐', '打车租车': '打出租车', '还人钱物': '还人钱财', '其他支出': '其他起初'}
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

class LedgerHome extends StatefulWidget {
  const LedgerHome({super.key});

  @override
  State<LedgerHome> createState() => _LedgerHomeState();
}

class _LedgerHomeState extends State<LedgerHome> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);
    
    if (store.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = [
      const LedgerPage(),
      const StatisticsPage(),
      const AccountsPage(),
    ];
    const titles = ['流水明细', '统计分析', '账户管理'];
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(titles[_index]),
        centerTitle: false,
        actions: [
          if (_index == 2)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showSettingsPage(context),
            ),
        ],
      ),
      body: Stack(
        children: [
          // 背景图片
          Positioned.fill(
            child: Image.asset(
              'assets/Application/bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: PageView(
              controller: _pageController,
              physics: const PageScrollPhysics(),
              onPageChanged: (value) {
                setState(() => _index = value);
              },
              children: pages.asMap().entries.map((entry) {
                final index = entry.key;
                final page = entry.value;
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double opacity = 1.0;
                    if (_pageController.position.haveDimensions) {
                      final pageValue = _pageController.page!;
                      opacity = 1.0 - ((pageValue - index).abs() * 0.8).clamp(0.0, 1.0);
                    }
                    return Opacity(
                      opacity: opacity,
                      child: child,
                    );
                  },
                  child: page,
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showAddEntrySheet(context),
              backgroundColor: const Color(0xFFE0F2EF),
              foregroundColor: colorScheme.primary,
              icon: const Icon(Icons.add),
              label: const Text('记一笔'),
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            height: 56,
            selectedIndex: _index,
            onDestinationSelected: (value) {
              if (_index != value) {
                setState(() {
                  _index = value;
                });
                _pageController.jumpToPage(value);
              }
            },
            destinations: [
              NavigationDestination(
                icon: SvgPicture.asset('assets/icons/liushui.svg', width: 24, height: 24),
                selectedIcon: SvgPicture.asset('assets/icons/liushui.svg', width: 24, height: 24),
                label: '流水',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: '统计',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: '账户',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsPage(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const SettingsPage(),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  final _apiKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final store = LedgerScope.of(context);
    _apiKeyController.text = store.baiduApiKey ?? '';
    _secretKeyController.text = store.baiduSecretKey ?? '';
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _secretKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '语音识别',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '百度智能云API配置',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'API Key',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _secretKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Secret Key',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        await store.setBaiduApiKey(
                          _apiKeyController.text.isEmpty ? null : _apiKeyController.text,
                        );
                        await store.setBaiduSecretKey(
                          _secretKeyController.text.isEmpty ? null : _secretKeyController.text,
                        );
                        if (mounted) {
                          showSnack(context, '配置已保存');
                        }
                      },
                      child: const Text('保存配置'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '数据管理',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _isExporting ? null : () => _exportBackup(store),
                      icon: _isExporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: const Text('导出备份数据'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isImporting ? null : () => _importBackup(store),
                      icon: _isImporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: const Text('导入备份数据'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isImporting ? null : _importSuiShouJiExcel,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.table_chart),
                      label: const Text('导入随手记数据'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importSuiShouJiExcel() async {
    final store = LedgerScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入随手记数据？'),
        content: const Text('导入会覆盖当前账户、流水和自定义分类，并按 Excel 里的支出、收入、转账重新计算账户余额。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('选择 Excel'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      allowMultiple: false,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !mounted) {
      return;
    }

    setState(() => _isImporting = true);
    try {
      final file = picked.files.single;
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      final imported = parseSuiShouJiExcel(bytes);
      if (!mounted) {
        return;
      }
      if (imported.summary.entryCount == 0) {
        showSnack(context, '没有识别到可导入的支出、收入或转账');
        return;
      }
      await store.replaceImportedData(imported);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入完成'),
          content: Text(
            [
              '账户：${imported.summary.accountCount} 个',
              '支出：${imported.summary.expenseCount} 条',
              '收入：${imported.summary.incomeCount} 条',
              '转账：${imported.summary.transferCount} 条',
              '跳过：${imported.summary.skippedCount} 条',
            ].join('\n'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        showSnack(context, '导入失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _exportBackup(LedgerStore store) async {
    setState(() => _isExporting = true);
    try {
      final file = await store.exportBackupData();
      if (!mounted) return;
      
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导出成功'),
          content: Text('备份文件已生成，您可以选择分享或保存到其他位置。'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Share.shareXFiles(
                  [XFile(file.path)],
                  subject: '记账APP备份数据',
                  text: '这是记账APP的备份数据，请妥善保存。',
                );
              },
              child: const Text('分享'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        showSnack(context, '导出失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importBackup(LedgerStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入备份数据？'),
        content: const Text('导入会覆盖当前所有账户、流水和自定义分类，确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
    );
    
    if (picked == null || picked.files.isEmpty || !mounted) return;
    
    setState(() => _isImporting = true);
    try {
      final file = picked.files.single;
      await store.importBackupData(file.path!);
      if (!mounted) return;
      
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入完成'),
          content: const Text('备份数据已成功导入'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        showSnack(context, '导入失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }
}

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.0),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SummaryPanel(
            title: '当前资产',
            amountInCents: store.totalBalanceInCents,
            subtitle: '${store.accounts.length} 个账户',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => showAccountSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('添加账户'),
          ),
          const SizedBox(height: 16),
          if (store.accounts.isEmpty)
            const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: '先添加一个账户',
              message: '微信钱包、支付宝、银行卡、现金、信用卡，都可以从这里录入。',
            )
            else
              ..._buildAccountGroups(store.accounts),
        ],
      ),
    );
  }

  List<Widget> _buildAccountGroups(List<Account> accounts) {
    // 按账户类型分组
    final groups = <AccountType, List<Account>>{};
    for (final account in accounts) {
      if (!groups.containsKey(account.type)) {
        groups[account.type] = [];
      }
      groups[account.type]!.add(account);
    }

    // 对每个组内的账户按金额大小从大到小排序
    for (final type in groups.keys) {
      groups[type]!.sort((a, b) => b.balanceInCents.compareTo(a.balanceInCents));
    }

    // 生成UI组件
    final widgets = <Widget>[];
    // 按照指定顺序显示：在线支付、储蓄卡、信用卡、现金
    final orderedTypes = [
      AccountType.onlinePayment,
      AccountType.debitCard,
      AccountType.creditCard,
      AccountType.cash,
    ];
    for (final type in orderedTypes) {
      final groupAccounts = groups[type];
      if (groupAccounts != null && groupAccounts.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              type.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF65736F),
              ),
            ),
          ),
        );
        widgets.addAll(groupAccounts.map((account) => AccountTile(account: account)));
      }
    }
    return widgets;
  }
}

class AccountTile extends StatelessWidget {
  const AccountTile({required this.account, super.key});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);
    final iconOption = accountIconOption(account.iconKey);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AccountIconBadge(option: iconOption, size: 38),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(account.name),
                  if (account.type == AccountType.creditCard && account.repaymentDay != null)
                    Text(
                      '每月 ${account.repaymentDay} 日还款',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  store.isAmountHidden ? '****' : formatMoney(account.balanceInCents),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      showAccountSheet(context, account: account);
                    }
                    if (value == 'delete') {
                      confirmDelete(
                        context,
                        title: '删除账户？',
                        message: '会同时删除这个账户相关的流水，并同步修正其他账户余额。',
                        onConfirm: () async {
                          await store.deleteAccount(account.id);
                          if (context.mounted) {
                            showSnack(context, '账户已删除');
                          }
                        },
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge({
    required this.icon,
    required this.color,
    this.size = 44,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(size * 0.38),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class AccountIconBadge extends StatelessWidget {
  const AccountIconBadge({required this.option, this.size = 44, super.key});

  final AccountIconOption option;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (option.key == 'alipay') {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1677FF),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Text(
          '支',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.48,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    if (option.assetPath != null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: option.color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(size * 0.38),
        ),
        child: SvgPicture.asset(
          option.assetPath!,
          width: size * 0.52,
          height: size * 0.52,
          colorFilter: ColorFilter.mode(
            option.color,
            BlendMode.srcIn,
          ),
        ),
      );
    }
    return IconBadge(icon: option.icon!, color: option.color, size: size);
  }
}

class ExpenseCategorySelector extends StatelessWidget {
  const ExpenseCategorySelector({
    required this.groups,
    required this.selectedGroup,
    required this.selectedCategory,
    required this.onSelected,
    super.key,
  });

  final List<ExpenseCategoryGroup> groups;
  final String selectedGroup;
  final String selectedCategory;
  final void Function(ExpenseCategoryGroup group, ExpenseCategoryItem category)
  onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('支出类型', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        ...groups.map((group) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF65736F),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: group.children.map((category) {
                    final selected =
                        selectedGroup == group.name &&
                        selectedCategory == category.name;
                    final color = selected
                        ? Theme.of(context).colorScheme.primary
                        : const Color(0xFF6D7B76);
                    return InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => onSelected(group, category),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 78,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFE0F2EF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(categoryIcon(category.iconKey), color: color),
                            const SizedBox(height: 6),
                            Text(
                              category.name,
                              textAlign: TextAlign.center,
                              style: Theme.of(
                                context,
                              ).textTheme.labelMedium?.copyWith(color: color),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

Future<void> showAddEntrySheet(BuildContext context) {
  final store = LedgerScope.of(context);
  final messenger = ScaffoldMessenger.of(context);

  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => EntryFormPage(
        store: store,
        onSaved: (type) {
          showSnack(context, '${type.label}已保存');
        },
      ),
    ),
  );
}

Future<void> showEditEntrySheet(
  BuildContext context, {
  required LedgerEntry entry,
}) {
  final store = LedgerScope.of(context);
  final messenger = ScaffoldMessenger.of(context);

  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => EntryFormPage(
        store: store,
        entry: entry,
        onSaved: (_) {
          showSnack(context, '流水已更新');
        },
      ),
    ),
  );
}

class EntryFormPage extends StatefulWidget {
  const EntryFormPage({
    required this.store,
    required this.onSaved,
    this.entry,
    super.key,
  });

  final LedgerStore store;
  final LedgerEntry? entry;
  final ValueChanged<LedgerEntryType> onSaved;

  @override
  State<EntryFormPage> createState() => _EntryFormPageState();
}

class _EntryFormPageState extends State<EntryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  bool _isProcessing = false;
  bool _isRecorderInitialized = false;
  late LedgerEntryType _type;
  late DateTime _occurredAt;
  late String _expenseGroup;
  late String _expenseCategory;
  late String _incomeGroup;
  late String _incomeCategory;
  String? _fromAccountId;
  String? _toAccountId;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    final entry = widget.entry;
    _type = entry?.type ?? LedgerEntryType.expense;
    _occurredAt = entry?.occurredAt ?? DateTime.now();
    _expenseCategory =
        entry?.expenseCategory ??
        (_type == LedgerEntryType.expense ? entry?.category : null) ??
        defaultExpenseCategoryGroups.first.children.first.name;
    _expenseGroup =
        entry?.expenseGroup ??
        widget.store.groupNameForExpenseCategory(_expenseCategory) ??
        defaultExpenseCategoryGroups.first.name;
    _incomeCategory =
        entry?.incomeCategory ??
        (_type == LedgerEntryType.income ? entry?.category : null) ??
        defaultIncomeCategoryGroups.first.children.first.name;
    _incomeGroup =
        entry?.incomeGroup ??
        widget.store.groupNameForIncomeCategory(_incomeCategory) ??
        defaultIncomeCategoryGroups.first.name;
    _fromAccountId = entry?.fromAccountId;
    _toAccountId = entry?.toAccountId;
    _amountController.text = entry == null
        ? ''
        : moneyInputValue(entry.amountInCents);
    _noteController.text = entry?.note ?? '';
  }

  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();
      setState(() {
        _isRecorderInitialized = true;
      });
    } catch (e) {
      print('初始化录音器失败: $e');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (widget.store.baiduApiKey == null || widget.store.baiduSecretKey == null) {
      showSnack(context, '请先在设置中配置百度语音识别API');
      return;
    }

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      showSnack(context, '需要麦克风权限才能使用语音输入');
      return;
    }

    if (_isRecorderInitialized) {
      try {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
        
        await _recorder.startRecorder(
          toFile: path,
          codec: Codec.pcm16WAV,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 16000,
        );
        
        setState(() {
          _isRecording = true;
          _recordingPath = path;
        });
      } catch (e) {
        showSnack(context, '录音失败: $e');
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      if (_recordingPath != null) {
        await _processRecording(_recordingPath!);
      }
    } catch (e) {
      showSnack(context, '停止录音失败: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processRecording(String path) async {
    try {
      final service = BaiduSpeechService(
        apiKey: widget.store.baiduApiKey!,
        secretKey: widget.store.baiduSecretKey!,
      );
      
      final result = await service.recognizeSpeech(path);
      if (result != null && mounted) {
        final parseResult = VoiceInputParser.parse(result);
        
        if (parseResult.type != null) {
          setState(() {
            _type = parseResult.type!;
          });
        }
        
        if (parseResult.amount != null) {
          _amountController.text = parseResult.amount!.toString();
        }
        
        if (parseResult.note != null) {
          _noteController.text = parseResult.note!;
        }
        
        showSnack(context, '识别成功');
      } else {
        showSnack(context, '语音识别失败，请重试');
      }
    } catch (e) {
      showSnack(context, '识别失败：$e');
    }
    
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.store.accounts;
    _ensureValidAccountSelection(accounts);

    if (accounts.isEmpty) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: const Text('记一笔')),
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: '还没有账户',
                message: '记账前需要先添加一个钱包或银行卡。',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FilledButton.icon(
                  onPressed: () =>
                      showAccountSheet(context, storeOverride: widget.store),
                  icon: const Icon(Icons.add),
                  label: const Text('添加账户'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(_isEditing ? '编辑流水' : '记一笔')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  children: [
                    EntryTypeSwitch(
                      value: _type,
                      onChanged: (value) => setState(() => _type = value),
                    ),
                    const SizedBox(height: 14),
                    AmountInput(controller: _amountController),
                    const SizedBox(height: 14),
                    if (_type == LedgerEntryType.expense)
                      SelectFieldCard(
                        label: '支出类型',
                        title: _expenseCategory,
                        subtitle: _expenseGroup,
                        icon: categoryIcon(
                          widget.store
                                  .expenseItemByName(_expenseCategory)
                                  ?.iconKey ??
                              '',
                        ),
                        color: Theme.of(context).colorScheme.error,
                        onTap: () async {
                          final result = await showExpenseCategoryPicker(
                            context,
                            widget.store,
                            selectedGroup: _expenseGroup,
                            selectedCategory: _expenseCategory,
                          );
                          if (result != null && mounted) {
                            setState(() {
                              _expenseGroup = result.groupName;
                              _expenseCategory = result.categoryName;
                            });
                          }
                        },
                      ),
                    if (_type == LedgerEntryType.income)
                      SelectFieldCard(
                        label: '收入类型',
                        title: _incomeCategory,
                        subtitle: _incomeGroup,
                        icon: categoryIcon(
                          widget.store
                                  .incomeItemByName(_incomeCategory)
                                  ?.iconKey ??
                              '',
                        ),
                        color: const Color(0xFF1E7A39),
                        onTap: () async {
                          final result = await showIncomeCategoryPicker(
                            context,
                            widget.store,
                            selectedGroup: _incomeGroup,
                            selectedCategory: _incomeCategory,
                          );
                          if (result != null && mounted) {
                            setState(() {
                              _incomeGroup = result.groupName;
                              _incomeCategory = result.categoryName;
                            });
                          }
                        },
                      ),
                    if (_type != LedgerEntryType.transfer)
                      const SizedBox(height: 12),
                    if (_type == LedgerEntryType.expense ||
                        _type == LedgerEntryType.transfer)
                      AccountSelectCard(
                        label: '从哪个账户',
                        account: widget.store.accountById(_fromAccountId),
                        onTap: () async {
                          final id = await showAccountPickerSheet(
                            context,
                            accounts,
                            selectedAccountId: _fromAccountId,
                            title: '选择转出账户',
                          );
                          if (id != null && mounted) {
                            setState(() => _fromAccountId = id);
                          }
                        },
                      ),
                    if (_type == LedgerEntryType.expense ||
                        _type == LedgerEntryType.transfer)
                      const SizedBox(height: 12),
                    if (_type == LedgerEntryType.income ||
                        _type == LedgerEntryType.transfer)
                      AccountSelectCard(
                        label: '到哪个账户',
                        account: widget.store.accountById(_toAccountId),
                        onTap: () async {
                          final id = await showAccountPickerSheet(
                            context,
                            accounts,
                            selectedAccountId: _toAccountId,
                            title: '选择转入账户',
                          );
                          if (id != null && mounted) {
                            setState(() => _toAccountId = id);
                          }
                        },
                      ),
                    const SizedBox(height: 12),
                    SelectFieldCard(
                      label: '时间',
                      title: formatDateTime(_occurredAt),
                      subtitle: '',
                      icon: Icons.schedule,
                      color: Theme.of(context).colorScheme.primary,
                      onTap: _pickDateTime,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _noteController,
                            decoration: const InputDecoration(labelText: '备注'),
                            maxLines: 3,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onLongPressStart: (_) => _startRecording(),
                          onLongPressEnd: (_) => _stopRecording(),
                          onTapUp: (_) => _stopRecording(),
                          onTapCancel: () => _stopRecording(),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: _isProcessing
                                ? const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _isRecording ? Icons.mic : Icons.mic_none,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(color: Color(0xFFF8FAF6)),
                child: FilledButton(
                  onPressed: _submit,
                  child: Text('保存${_type.label}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _ensureValidAccountSelection(List<Account> accounts) {
    if (accounts.isEmpty) {
      _fromAccountId = null;
      _toAccountId = null;
      return;
    }
    final ids = accounts.map((account) => account.id).toSet();
    if (_fromAccountId == null || !ids.contains(_fromAccountId)) {
      _fromAccountId = accounts.first.id;
    }
    if (_toAccountId == null || !ids.contains(_toAccountId)) {
      _toAccountId = accounts.length > 1 ? accounts.last.id : accounts.first.id;
    }
  }

  Future<void> _pickDateTime() async {
    DateTime? selectedDateTime = _occurredAt;
    
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(selectedDateTime);
                    },
                    child: const Text('确定'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: _occurredAt,
                  minimumDate: DateTime(2000),
                  maximumDate: DateTime(2100),
                  onDateTimeChanged: (dateTime) {
                    selectedDateTime = dateTime;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    
    if (selectedDateTime != null && mounted) {
      setState(() {
        _occurredAt = selectedDateTime!;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_type == LedgerEntryType.transfer && _fromAccountId == _toAccountId) {
      showSnack(context, '转出账户和转入账户不能相同');
      return;
    }
    final entry = LedgerEntry(
      id: widget.entry?.id ?? newId(),
      type: _type,
      amountInCents: parseMoney(_amountController.text)!,
      occurredAt: _occurredAt,
      note: _noteController.text.trim(),
      category: switch (_type) {
        LedgerEntryType.expense => _expenseCategory,
        LedgerEntryType.income => _incomeCategory,
        LedgerEntryType.transfer => null,
      },
      expenseGroup: _type == LedgerEntryType.expense ? _expenseGroup : null,
      expenseCategory: _type == LedgerEntryType.expense
          ? _expenseCategory
          : null,
      incomeGroup: _type == LedgerEntryType.income ? _incomeGroup : null,
      incomeCategory: _type == LedgerEntryType.income ? _incomeCategory : null,
      fromAccountId: _type == LedgerEntryType.income ? null : _fromAccountId,
      toAccountId: _type == LedgerEntryType.expense ? null : _toAccountId,
    );
    if (_isEditing) {
      await widget.store.updateEntry(entry);
    } else {
      await widget.store.addEntry(entry);
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    widget.onSaved(_type);
  }
}

class SheetFrame extends StatelessWidget {
  const SheetFrame({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(title: title),
          child,
        ],
      ),
    );
  }
}

class SheetHeader extends StatelessWidget {
  const SheetHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class EntryTypeSwitch extends StatefulWidget {
  const EntryTypeSwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final LedgerEntryType value;
  final ValueChanged<LedgerEntryType> onChanged;

  @override
  State<EntryTypeSwitch> createState() => _EntryTypeSwitchState();
}

class _EntryTypeSwitchState extends State<EntryTypeSwitch> {
  late LedgerEntryType _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant EntryTypeSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      setState(() {
        _value = widget.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = LedgerEntryType.values;
    final index = children.indexOf(_value);
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          // 背景白色块
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 0,
            top: 0,
            bottom: 0,
            right: 0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / children.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      left: index * itemWidth,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // 选项按钮
          Row(
            children: children.map((type) {
              return Expanded(
                child: GestureDetector(
                  onTap: () => widget.onChanged(type),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      type.label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: type == _value
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFF687570),
                        fontWeight: type == _value ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class AmountInput extends StatelessWidget {
  const AmountInput({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: '金额',
        prefixText: '¥ ',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0x33167C80), width: 1),
        ),
      ),
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        final cents = parseMoney(value ?? '');
        if (cents == null || cents <= 0) {
          return '请输入大于 0 的金额';
        }
        return null;
      },
    );
  }
}

class SelectFieldCard extends StatelessWidget {
  const SelectFieldCard({
    required this.label,
    required this.title,
    required this.subtitle,
    this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String label;
  final String title;
  final String subtitle;
  final IconData? icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (icon != null)
                IconBadge(icon: icon!, color: color, size: 44),
              if (icon != null)
                const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF7A8782),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_right),
            ],
          ),
        ),
      ),
    );
  }
}

class AccountSelectCard extends StatelessWidget {
  const AccountSelectCard({
    required this.label,
    required this.account,
    required this.onTap,
    super.key,
  });

  final String label;
  final Account? account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final option = accountIconOption(account?.iconKey ?? 'wallet');
    return SelectFieldCard(
      label: label,
      title: account?.name ?? '选择账户',
      subtitle: account == null
          ? '点击选择'
          : formatMoney(account!.balanceInCents),
      icon: option.icon,
      color: option.color,
      onTap: onTap,
    );
  }
}

class CategoryPickResult {
  const CategoryPickResult(this.groupName, this.categoryName);

  final String groupName;
  final String categoryName;
}

Future<CategoryPickResult?> showExpenseCategoryPicker(
  BuildContext context,
  LedgerStore store, {
  required String selectedGroup,
  required String selectedCategory,
}) {
  return showCategoryPickerSheet<ExpenseCategoryGroup>(
    context,
    title: '选择支出类型',
    type: LedgerEntryType.expense,
    store: store,
    groups: store.expenseCategoryGroups,
    selectedGroup: selectedGroup,
    selectedCategory: selectedCategory,
    childrenOf: (group) => group.children,
    groupNameOf: (group) => group.name,
  );
}

Future<CategoryPickResult?> showIncomeCategoryPicker(
  BuildContext context,
  LedgerStore store, {
  required String selectedGroup,
  required String selectedCategory,
}) {
  return showCategoryPickerSheet<IncomeCategoryGroup>(
    context,
    title: '选择收入类型',
    type: LedgerEntryType.income,
    store: store,
    groups: store.incomeCategoryGroups,
    selectedGroup: selectedGroup,
    selectedCategory: selectedCategory,
    childrenOf: (group) => group.children,
    groupNameOf: (group) => group.name,
  );
}

Future<CategoryPickResult?> showCategoryPickerSheet<T>(
  BuildContext context, {
  required String title,
  required LedgerEntryType type,
  required LedgerStore store,
  required List<T> groups,
  required String selectedGroup,
  required String selectedCategory,
  required List<ExpenseCategoryItem> Function(T group) childrenOf,
  required String Function(T group) groupNameOf,
}) {
  return showModalBottomSheet<CategoryPickResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.74,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(context)
                          .push<CategoryPickResult>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CategoryFormPage(store: store, type: type),
                            ),
                          );
                      if (result != null && context.mounted) {
                        Navigator.of(context).pop(result);
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('添加小类'),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: groups.map((group) {
                  final groupName = groupNameOf(group);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: childrenOf(group).map((item) {
                            final selected =
                                selectedGroup == groupName &&
                                selectedCategory == item.name;
                            final color = selected
                                ? Theme.of(context).colorScheme.primary
                                : const Color(0xFF66736F);
                            return InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () => Navigator.of(
                                context,
                              ).pop(CategoryPickResult(groupName, item.name)),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 82,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFE0F2EF)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      categoryIcon(item.iconKey),
                                      color: color,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.name,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(color: color),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<String?> showAccountPickerSheet(
  BuildContext context,
  List<Account> accounts, {
  required String? selectedAccountId,
  required String title,
}) {
  // 按账户类型分组
  final groups = <AccountType, List<Account>>{};
  for (final account in accounts) {
    if (!groups.containsKey(account.type)) {
      groups[account.type] = [];
    }
    groups[account.type]!.add(account);
  }

  // 对每个组内的账户按名称字母排序
  for (final type in groups.keys) {
    groups[type]!.sort((a, b) => a.name.compareTo(b.name));
  }

  // 按照指定顺序显示：在线支付、储蓄卡、信用卡、现金
  final orderedTypes = [
    AccountType.onlinePayment,
    AccountType.debitCard,
    AccountType.creditCard,
    AccountType.cash,
  ];

  // 生成分组后的账户列表
  final groupedAccounts = <Widget>[];
  for (final type in orderedTypes) {
    final typeAccounts = groups[type];
    if (typeAccounts != null && typeAccounts.isNotEmpty) {
      // 添加分组标题
      groupedAccounts.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8, left: 16, right: 16),
          child: Text(
            type.label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF65736F),
            ),
          ),
        ),
      );
      // 添加该组的账户
      for (final account in typeAccounts) {
        final option = accountIconOption(account.iconKey);
        final selected = account.id == selectedAccountId;
        groupedAccounts.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Material(
              color: selected ? const Color(0xFFE0F2EF) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                onTap: () => Navigator.of(context).pop(account.id),
                leading: AccountIconBadge(option: option, size: 36),
                title: Text(account.name),
                trailing: Text(formatMoney(account.balanceInCents)),
              ),
            ),
          ),
        );
      }
    }
  }

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.74,
        child: Column(
          children: [
            SheetHeader(title: title),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                children: groupedAccounts,
              ),
            ),
          ],
        ),
      );
    },
  );
}

const customCategoryIconOptions = [
  ExpenseCategoryItem('餐饮', 'restaurant'),
  ExpenseCategoryItem('咖啡', 'local_cafe'),
  ExpenseCategoryItem('购物', 'shopping_bag'),
  ExpenseCategoryItem('交通', 'directions_car'),
  ExpenseCategoryItem('房屋', 'home'),
  ExpenseCategoryItem('维修', 'build'),
  ExpenseCategoryItem('通讯', 'smartphone'),
  ExpenseCategoryItem('娱乐', 'sports_esports'),
  ExpenseCategoryItem('旅行', 'flight_takeoff'),
  ExpenseCategoryItem('学习', 'school'),
  ExpenseCategoryItem('礼物', 'redeem'),
  ExpenseCategoryItem('医疗', 'medical_services'),
  ExpenseCategoryItem('工作', 'work'),
  ExpenseCategoryItem('奖金', 'emoji_events'),
  ExpenseCategoryItem('投资', 'trending_up'),
  ExpenseCategoryItem('出售', 'sell'),
];

class CategoryFormPage extends StatefulWidget {
  const CategoryFormPage({required this.store, required this.type, super.key});

  final LedgerStore store;
  final LedgerEntryType type;

  @override
  State<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends State<CategoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late String _groupName;
  String _iconKey = customCategoryIconOptions.first.iconKey;

  @override
  void initState() {
    super.initState();
    _groupName = _groups.first.key;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<MapEntry<String, List<ExpenseCategoryItem>>> get _groups {
    if (widget.type == LedgerEntryType.expense) {
      return defaultExpenseCategoryGroups
          .map((group) => MapEntry(group.name, group.children))
          .toList();
    }
    return defaultIncomeCategoryGroups
        .map((group) => MapEntry(group.name, group.children))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text('添加${widget.type.label}小类')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
            children: [
              Text('所属大类', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _groups.map((group) {
                  final selected = group.key == _groupName;
                  return ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    label: Text(group.key),
                    onSelected: (_) => setState(() => _groupName = group.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '小类名称',
                  hintText: '例如：奶茶、停车费、稿费',
                ),
                validator: (value) {
                  final name = (value ?? '').trim();
                  if (name.isEmpty) {
                    return '请输入小类名称';
                  }
                  if (widget.store.categoryExists(widget.type, name)) {
                    return '这个小类已经存在';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              Text('小图标', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: customCategoryIconOptions.map((option) {
                  final selected = option.iconKey == _iconKey;
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _iconKey = option.iconKey),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 78,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFE0F2EF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            categoryIcon(option.iconKey),
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            option.name,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: FilledButton(onPressed: _submit, child: const Text('保存小类')),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final name = _nameController.text.trim();
    final saved = await widget.store.addCustomCategory(
      CustomCategory(
        type: widget.type,
        groupName: _groupName,
        name: name,
        iconKey: _iconKey,
      ),
    );
    if (!mounted) {
      return;
    }
    if (!saved) {
      showSnack(context, '这个小类已经存在');
      return;
    }
    Navigator.of(context).pop(CategoryPickResult(_groupName, name));
  }
}

class LedgerPage extends StatelessWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);
    final entries = store.entries;

    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: '暂无流水',
        message: '保存支出、收入或转账后，会按时间倒序显示在这里。',
      );
    }

    final groups = <String, List<LedgerEntry>>{};
    for (final entry in entries) {
      final key = dateKey(entry.occurredAt);
      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(entry);
    }

    final List<Widget> children = [];
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    for (final key in sortedKeys) {
      final groupEntries = groups[key]!;
      final firstEntry = groupEntries.first;

      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            formatDateOnly(firstEntry.occurredAt),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF65736F),
                ),
          ),
        ),
      );

      // 创建一个大Card，包含当天的所有流水
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 1,
            shadowColor: const Color(0x1A53615D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                for (int i = 0; i < groupEntries.length; i++)
                  Column(
                    children: [
                      LedgerEntryTile(
                        entry: groupEntries[i],
                        store: store,
                        isLast: i == groupEntries.length - 1,
                      ),
                      if (i < groupEntries.length - 1)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          indent: 72,
                          endIndent: 0,
                          color: Color(0xFFF5F5F5),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.0),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 0, bottom: 112),
        children: children,
      ),
    );
  }
}

class LedgerEntryTile extends StatelessWidget {
  const LedgerEntryTile({required this.entry, required this.store, this.isLast = false, super.key});

  final LedgerEntry entry;
  final LedgerStore store;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final from = store.accountById(entry.fromAccountId)?.name;
    final to = store.accountById(entry.toAccountId)?.name;
    final isExpense = entry.type == LedgerEntryType.expense;
    final amountPrefix = isExpense ? '-' : '+';
    final amountColor = isExpense
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF1E7A39);

    final title = switch (entry.type) {
      LedgerEntryType.expense => expenseCategoryLabel(entry),
      LedgerEntryType.income => incomeCategoryLabel(entry),
      LedgerEntryType.transfer => '转账',
    };
    final accountLine = switch (entry.type) {
      LedgerEntryType.expense => from ?? '未知账户',
      LedgerEntryType.income => to ?? '未知账户',
      LedgerEntryType.transfer => '${from ?? '未知账户'} → ${to ?? '未知账户'}',
    };
    final iconColor = switch (entry.type) {
      LedgerEntryType.expense => Theme.of(context).colorScheme.error,
      LedgerEntryType.income => const Color(0xFF1E7A39),
      LedgerEntryType.transfer => Theme.of(context).colorScheme.primary,
    };
    final amountText = entry.type == LedgerEntryType.transfer
        ? formatMoney(entry.amountInCents)
        : '$amountPrefix${formatMoney(entry.amountInCents)}';
    final timeOnly = _formatTimeOnly(entry.occurredAt);
    final metaLine = [
      if (entry.type != LedgerEntryType.transfer) accountLine,
      timeOnly,
    ].join(' · ');

    return InkWell(
      onTap: () => showEditEntrySheet(context, entry: entry),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 8, isLast ? 14 : 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconBadge(icon: _entryIcon(entry), color: iconColor, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        amountText,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: entry.type == LedgerEntryType.transfer
                                  ? Theme.of(context).colorScheme.onSurface
                                  : amountColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                      ),
                    ],
                  ),
                  if (entry.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(0x80),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    metaLine,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(0x60),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(0x50),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  showEditEntrySheet(context, entry: entry);
                }
                if (value == 'delete') {
                  confirmDelete(
                    context,
                    title: '删除流水？',
                    message: '这条流水会被移除，相关账户余额会同步恢复。',
                    onConfirm: () async {
                      await store.deleteEntry(entry.id);
                      if (context.mounted) {
                        showSnack(context, '流水已删除');
                      }
                    },
                  );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeOnly(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  IconData _entryIcon(LedgerEntry entry) {
    if (entry.type == LedgerEntryType.expense) {
      final item = store.expenseItemByName(
        entry.expenseCategory ?? entry.category,
      );
      return categoryIcon(item?.iconKey ?? '');
    }
    if (entry.type == LedgerEntryType.income) {
      final item = store.incomeItemByName(
        entry.incomeCategory ?? entry.category,
      );
      return categoryIcon(item?.iconKey ?? '');
    }
    return switch (entry.type) {
      LedgerEntryType.expense => Icons.trending_down,
      LedgerEntryType.income => Icons.trending_up,
      LedgerEntryType.transfer => Icons.swap_horiz,
    };
  }
}

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _groupByMajor = true;

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);
    final monthEntries = store.entries.where((entry) {
      return entry.occurredAt.year == _month.year &&
          entry.occurredAt.month == _month.month;
    }).toList();
    final expenseStats = _groupedStats(
      monthEntries,
      type: LedgerEntryType.expense,
      groupLabel: expenseGroupLabel,
      categoryLabel: expenseCategoryLabel,
    );
    final incomeStats = _groupedStats(
      monthEntries,
      type: LedgerEntryType.income,
      groupLabel: incomeGroupLabel,
      categoryLabel: incomeCategoryLabel,
    );
    final expenseLeafStats = _leafStats(
      monthEntries,
      type: LedgerEntryType.expense,
      categoryLabel: expenseCategoryLabel,
    );
    final incomeLeafStats = _leafStats(
      monthEntries,
      type: LedgerEntryType.income,
      categoryLabel: incomeCategoryLabel,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.0),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x1A53615D),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2EF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    onPressed: () => setState(() {
                      _month = DateTime(_month.year, _month.month - 1);
                    }),
                    icon: const Icon(Icons.chevron_left, color: Color(0xFF167C80)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          '${_month.year} 年 ${_month.month} 月',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getMonthSummary(store, monthEntries),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF65736F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2EF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    onPressed: () => setState(() {
                      _month = DateTime(_month.year, _month.month + 1);
                    }),
                    icon: const Icon(Icons.chevron_right, color: Color(0xFF167C80)),
                  ),
                ),
              ],
            ),
        ),
        const SizedBox(height: 20),
        TwoOptionSwitch<bool>(
          value: _groupByMajor,
          leftValue: true,
          leftLabel: '按大类',
          rightValue: false,
          rightLabel: '按小类',
          onChanged: (value) => setState(() => _groupByMajor = value),
        ),
        const SizedBox(height: 20),
        StatisticsBlock(
          title: '支出统计',
          stats: _groupByMajor
              ? expenseStats.map((key, value) => MapEntry(key, value.total))
              : expenseLeafStats,
          emptyText: '这个月还没有支出',
          color: Theme.of(context).colorScheme.error,
          childrenByGroup: _groupByMajor
              ? expenseStats.map((key, value) => MapEntry(key, value.children))
              : const {},
        ),
        const SizedBox(height: 20),
        StatisticsBlock(
          title: '收入统计',
          stats: _groupByMajor
              ? incomeStats.map((key, value) => MapEntry(key, value.total))
              : incomeLeafStats,
          emptyText: '这个月还没有收入',
          color: const Color(0xFF1E7A39),
          childrenByGroup: _groupByMajor
              ? incomeStats.map((key, value) => MapEntry(key, value.children))
              : const {},
        ),
      ],
    ),
  );
  }

  String _getMonthSummary(LedgerStore store, List<LedgerEntry> entries) {
    final expenseTotal = entries
        .where((e) => e.type == LedgerEntryType.expense)
        .fold(0, (sum, e) => sum + e.amountInCents);
    final incomeTotal = entries
        .where((e) => e.type == LedgerEntryType.income)
        .fold(0, (sum, e) => sum + e.amountInCents);
    final net = incomeTotal - expenseTotal;
    
    if (net > 0) {
      return '结余 ${formatMoney(net)}';
    } else if (net < 0) {
      return '超支 ${formatMoney(-net)}';
    } else {
      return '收支平衡';
    }
  }

  Map<String, GroupedCategoryStat> _groupedStats(
    List<LedgerEntry> entries, {
    required LedgerEntryType type,
    required String Function(LedgerEntry entry) groupLabel,
    required String Function(LedgerEntry entry) categoryLabel,
  }) {
    final stats = <String, GroupedCategoryStat>{};
    for (final entry in entries.where((entry) => entry.type == type)) {
      final group = groupLabel(entry);
      final category = categoryLabel(entry);
      final current = stats[group] ?? GroupedCategoryStat.empty();
      stats[group] = current.add(category, entry.amountInCents);
    }
    return Map.fromEntries(
      stats.entries.toList()
        ..sort((a, b) => b.value.total.compareTo(a.value.total)),
    );
  }

  Map<String, int> _leafStats(
    List<LedgerEntry> entries, {
    required LedgerEntryType type,
    required String Function(LedgerEntry entry) categoryLabel,
  }) {
    final stats = <String, int>{};
    for (final entry in entries.where((entry) => entry.type == type)) {
      final category = categoryLabel(entry);
      stats[category] = (stats[category] ?? 0) + entry.amountInCents;
    }
    return Map.fromEntries(
      stats.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }
}

class GroupedCategoryStat {
  const GroupedCategoryStat({required this.total, required this.children});

  factory GroupedCategoryStat.empty() {
    return const GroupedCategoryStat(total: 0, children: {});
  }

  final int total;
  final Map<String, int> children;

  GroupedCategoryStat add(String category, int amount) {
    final nextChildren = {...children};
    nextChildren[category] = (nextChildren[category] ?? 0) + amount;
    final sortedChildren = Map.fromEntries(
      nextChildren.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
    return GroupedCategoryStat(total: total + amount, children: sortedChildren);
  }
}

class StatisticsBlock extends StatelessWidget {
  const StatisticsBlock({
    required this.title,
    required this.stats,
    required this.emptyText,
    required this.color,
    this.childrenByGroup = const {},
    super.key,
  });

  final String title;
  final Map<String, int> stats;
  final Map<String, Map<String, int>> childrenByGroup;
  final String emptyText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final total = stats.values.fold(0, (sum, value) => sum + value);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1A53615D),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  Text(
                    formatMoney(total),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (stats.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: const Color(0xFFC5D0CB),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        emptyText,
                        style: const TextStyle(color: Color(0xFF8B9A94)),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...stats.entries.map((entry) {
                final ratio = total == 0 ? 0.0 : entry.value / total;
                final childStats = childrenByGroup[entry.key];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatMoney(entry.value),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${(ratio * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8B9A94),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ratio,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  color,
                                  color.withValues(alpha: 0.7),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      if (childStats != null) ...[
                        const SizedBox(height: 12),
                        ...childStats.entries.map((child) {
                          final childRatio = entry.value == 0
                              ? 0.0
                              : child.value / entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const SizedBox(width: 8),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    child.key,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF65736F),
                                    ),
                                  ),
                                ),
                                Text(
                                  formatMoney(child.value),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF65736F),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(childRatio * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFA1B0AA),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class SummaryPanel extends StatelessWidget {
  const SummaryPanel({
    required this.title,
    required this.amountInCents,
    required this.subtitle,
    super.key,
  });

  final String title;
  final int amountInCents;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006B68), Color(0xFF1F8E76)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                store.isAmountHidden ? '****' : formatMoney(amountInCents),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () async {
                  if (store.isAmountHidden) {
                    // 显示密码输入弹窗
                    final result = await showPasswordDialog(context);
                    if (result == true) {
                      store.setAmountHidden(false);
                    }
                  } else {
                    store.setAmountHidden(true);
                  }
                },
                icon: Icon(
                  store.isAmountHidden ? Icons.visibility_off : Icons.visibility,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onPrimary.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showCategoryManagerSheet(
  BuildContext context, {
  LedgerStore? storeOverride,
}) {
  final store = storeOverride ?? LedgerScope.of(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CategoryManagerSheet(store: store),
  );
}

class CategoryManagerSheet extends StatefulWidget {
  const CategoryManagerSheet({required this.store, super.key});

  final LedgerStore store;

  @override
  State<CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<CategoryManagerSheet> {
  LedgerEntryType _type = LedgerEntryType.expense;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isExpense = _type == LedgerEntryType.expense;
    final groups = isExpense
        ? widget.store.expenseCategoryGroups
              .map((group) => MapEntry(group.name, group.children))
              .toList()
        : widget.store.incomeCategoryGroups
              .map((group) => MapEntry(group.name, group.children))
              .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('管理分类', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TwoOptionSwitch<LedgerEntryType>(
            value: _type,
            leftValue: LedgerEntryType.expense,
            leftLabel: '支出',
            rightValue: LedgerEntryType.income,
            rightLabel: '收入',
            onChanged: (value) => setState(() => _type = value),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              '${isExpense ? '支出' : '收入'}分类按大类/小类固定展示，本版本暂不开放编辑。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final group = groups[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.key,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: group.value.map((item) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F6F3),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  categoryIcon(item.iconKey),
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(item.name),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TwoOptionSwitch<T> extends StatefulWidget {
  const TwoOptionSwitch({
    required this.value,
    required this.leftValue,
    required this.leftLabel,
    required this.rightValue,
    required this.rightLabel,
    required this.onChanged,
    super.key,
  });

  final T value;
  final T leftValue;
  final String leftLabel;
  final T rightValue;
  final String rightLabel;
  final ValueChanged<T> onChanged;

  @override
  State<TwoOptionSwitch<T>> createState() => _TwoOptionSwitchState<T>();
}

class _TwoOptionSwitchState<T> extends State<TwoOptionSwitch<T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant TwoOptionSwitch<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      setState(() {
        _value = widget.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLeftSelected = _value == widget.leftValue;
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          // 背景白色块
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 0,
            top: 0,
            bottom: 0,
            right: 0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / 2;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      left: isLeftSelected ? 0 : itemWidth,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // 选项按钮
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => widget.onChanged(widget.leftValue),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Text(
                      widget.leftLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isLeftSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => widget.onChanged(widget.rightValue),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Text(
                      widget.rightLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: !isLeftSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AccountTypeSelector extends StatelessWidget {
  const AccountTypeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final AccountType value;
  final ValueChanged<AccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AccountType.values.map((type) {
        final selected = type == value;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onChanged(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFE0F2EF)
                  : const Color(0xFFF2F6F3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  accountIconOption(defaultAccountIconKey(type)).icon,
                  size: 18,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  type.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

Future<void> showAccountSheet(
  BuildContext context, {
  Account? account,
  LedgerStore? storeOverride,
}) {
  final store = storeOverride ?? LedgerScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final isEditing = account != null;

  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => AccountFormPage(
        store: store,
        account: account,
        onSaved: () {
          showSnack(context, isEditing ? '账户已更新' : '账户已添加');
        },
      ),
    ),
  );
}

Future<AccountType?> showAccountTypePickerSheet(
  BuildContext context, {
  required AccountType selectedType,
}) {
  return showModalBottomSheet<AccountType>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            const SheetHeader(title: '选择账户类型'),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final type = [
                    AccountType.onlinePayment,
                    AccountType.debitCard,
                    AccountType.creditCard,
                    AccountType.cash,
                  ][index];
                  final selected = type == selectedType;
                  final option = accountIconOption(defaultAccountIconKey(type));
                  return Material(
                    color: selected ? const Color(0xFFE0F2EF) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      title: Text(type.label),
                      trailing: selected ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.of(context).pop(type),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<bool?> showPasswordDialog(BuildContext context) {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('输入密码'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: '请输入4位数密码',
            ),
            validator: (value) {
              if (value?.length != 4) {
                return '请输入4位数密码';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                if (controller.text == '0402') {
                  Navigator.of(context).pop(true);
                } else {
                  showSnack(context, '密码错误');
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
}

Future<String?> showAccountIconPickerSheet(
  BuildContext context, {
  required String selectedIconKey,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            const SheetHeader(title: '选择显示图标'),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: accountIconOptions.length,
                itemBuilder: (context, index) {
                  final option = accountIconOptions[index];
                  final selected = option.key == selectedIconKey;
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(option.key),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFE0F2EF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AccountIconBadge(option: option),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class AccountFormPage extends StatefulWidget {
  const AccountFormPage({
    required this.store,
    required this.onSaved,
    this.account,
    super.key,
  });

  final LedgerStore store;
  final VoidCallback onSaved;
  final Account? account;

  @override
  State<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends State<AccountFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _repaymentController = TextEditingController();
  AccountType _type = AccountType.onlinePayment;
  String _iconKey = defaultAccountIconKey(AccountType.onlinePayment);

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    if (account != null) {
      _nameController.text = account.name;
      _balanceController.text = moneyInputValue(account.balanceInCents);
      _repaymentController.text = account.repaymentDay?.toString() ?? '';
      _type = account.type;
      _iconKey = account.iconKey;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _repaymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(_isEditing ? '编辑账户' : '添加账户')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
            children: [
              SelectFieldCard(
                label: '账户类型',
                title: _type.label,
                subtitle: '',
                color: Theme.of(context).colorScheme.primary,
                onTap: () async {
                  final type = await showAccountTypePickerSheet(
                    context,
                    selectedType: _type,
                  );
                  if (type != null && mounted) {
                    setState(() {
                      _type = type;
                      _iconKey = defaultAccountIconKey(_type);
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '账户名称',
                  hintText: '例如：微信钱包、招行信用卡',
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return '请输入账户名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _balanceController,
                decoration: const InputDecoration(
                  labelText: '当前金额',
                  prefixText: '¥ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (parseMoney(value ?? '') == null) {
                    return '请输入正确金额';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () async {
                    final iconKey = await showAccountIconPickerSheet(
                      context,
                      selectedIconKey: _iconKey,
                    );
                    if (iconKey != null && mounted) {
                      setState(() {
                        _iconKey = iconKey;
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        AccountIconBadge(
                          option: accountIconOption(_iconKey),
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                        const Text('显示图标'),
                        const Spacer(),
                        const Icon(Icons.keyboard_arrow_right),
                      ],
                    ),
                  ),
                ),
              ),
              if (_type == AccountType.creditCard) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _repaymentController,
                  decoration: const InputDecoration(
                    labelText: '每月还款日',
                    hintText: '1-31',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (_type != AccountType.creditCard) {
                      return null;
                    }
                    final day = int.tryParse(value ?? '');
                    if (day == null || day < 1 || day > 31) {
                      return '请输入 1 到 31 之间的日期';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: FilledButton(
            onPressed: _submit,
            child: Text(_isEditing ? '保存修改' : '确认添加'),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final existing = widget.account;
    final account = Account(
      id: existing?.id ?? newId(),
      name: _nameController.text.trim(),
      balanceInCents: parseMoney(_balanceController.text)!,
      type: _type,
      iconKey: _iconKey,
      repaymentDay: _type == AccountType.creditCard
          ? int.parse(_repaymentController.text)
          : null,
    );
    if (_isEditing) {
      await widget.store.updateAccount(account);
    } else {
      await widget.store.addAccount(account);
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    widget.onSaved();
  }
}

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
  return '$sign¥${value.toStringAsFixed(2)}';
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

void showSnack(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  final screenHeight = MediaQuery.of(context).size.height;
  final bottomPosition = screenHeight * 3/4; // 底部1/4高度的位置
  
  // 创建一个可变的OverlayEntry引用
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

  // 添加渐变消失效果
  Future.delayed(const Duration(seconds: 2), () {
    // 移除旧的OverlayEntry
    overlayEntry.remove();
    
    // 创建一个新的OverlayEntry来显示淡出动画
    fadeOutEntry = OverlayEntry(
      builder: (context) {
        final animationController = AnimationController(
          duration: const Duration(seconds: 1),
          vsync: Navigator.of(context).overlay!, 
        )..forward()..addStatusListener((status) {
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
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
                      color: const Color(0xFF16211F),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF65736F),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
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
