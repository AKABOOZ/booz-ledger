import 'package:flutter/material.dart';

import 'package:ledger_app/models/enums.dart';

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
    ExpenseCategoryItem('其他支出', 'more_horiz'),
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

Color categoryGroupColor(String groupName) {
  if (groupName.contains('职业收入') || groupName.contains('工资')) {
    return const Color(0xFF1F8A4C);
  }
  if (groupName.contains('其他收入') || groupName.contains('奖金')) {
    return const Color(0xFF2F9B8F);
  }
  if (groupName.contains('饮食') || groupName.contains('食品')) {
    return const Color(0xFFE2554F);
  }
  if (groupName.contains('居家') || groupName.contains('房租')) {
    return const Color(0xFF2F9B8F);
  }
  if (groupName.contains('交通') || groupName.contains('行车')) {
    return const Color(0xFF3D7EBB);
  }
  if (groupName.contains('通讯') || groupName.contains('交流')) {
    return const Color(0xFF5B7C8B);
  }
  if (groupName.contains('娱乐') || groupName.contains('休闲')) {
    return const Color(0xFF8B6AAE);
  }
  if (groupName.contains('学习') || groupName.contains('进修')) {
    return const Color(0xFF4F8F55);
  }
  if (groupName.contains('人情')) {
    return const Color(0xFFC67B45);
  }
  if (groupName.contains('医疗') || groupName.contains('保健')) {
    return const Color(0xFFC15B7A);
  }
  if (groupName.contains('金融') || groupName.contains('保险')) {
    return const Color(0xFFB58B2A);
  }
  if (groupName.contains('职业') || groupName.contains('收入')) {
    return const Color(0xFF1F8A4C);
  }
  return const Color(0xFF7A8782);
}
