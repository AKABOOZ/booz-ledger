import 'package:flutter/material.dart';

import 'package:ledger_app/models/enums.dart';

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
    Object? repaymentDay = unset,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      balanceInCents: balanceInCents ?? this.balanceInCents,
      type: type ?? this.type,
      iconKey: iconKey ?? this.iconKey,
      repaymentDay: repaymentDay == unset
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
  const AccountIconOption(
    this.key,
    this.label,
    this.icon,
    this.color, {
    this.assetPath,
  });

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
  AccountIconOption(
    'meituan',
    '美团',
    null,
    Color(0xFFFF6700),
    assetPath: 'assets/icons/meituan.svg',
  ),
  AccountIconOption(
    'didichuxing',
    '滴滴出行',
    null,
    Color(0xFFFF5A5F),
    assetPath: 'assets/icons/didi.svg',
  ),
  AccountIconOption(
    'hellochuxing',
    '哈啰出行',
    null,
    Color(0xFF00B5EE),
    assetPath: 'assets/icons/haluo.svg',
  ),
  AccountIconOption(
    'huabei',
    '花呗',
    null,
    Color(0xFFFF6A00),
    assetPath: 'assets/icons/huabei.svg',
  ),
  AccountIconOption(
    'cmb',
    '招商银行',
    null,
    Color(0xFFE50012),
    assetPath: 'assets/icons/zhaoshang.svg',
  ),
  AccountIconOption(
    'abc',
    '农业银行',
    null,
    Color(0xFF009933),
    assetPath: 'assets/icons/nongye.svg',
  ),
  AccountIconOption(
    'icbc',
    '工商银行',
    null,
    Color(0xFFD92121),
    assetPath: 'assets/icons/gongshang.svg',
  ),
  AccountIconOption(
    'ccb',
    '建设银行',
    null,
    Color(0xFF0066B3),
    assetPath: 'assets/icons/jianshe.svg',
  ),
  AccountIconOption(
    'liushui',
    '流水',
    null,
    Color(0xFF167C80),
    assetPath: 'assets/icons/liushui.svg',
  ),
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
