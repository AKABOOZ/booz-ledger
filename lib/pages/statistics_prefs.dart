import 'package:shared_preferences/shared_preferences.dart';

class StatisticsPagePrefs {
  static const _isYearlyKey = 'statistics_is_yearly';
  static const _yearKey = 'statistics_year';
  static const _monthKey = 'statistics_month';

  static bool isYearly = false;
  static int year = DateTime.now().year;
  static int month = DateTime.now().month;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    isYearly = prefs.getBool(_isYearlyKey) ?? false;
    year = prefs.getInt(_yearKey) ?? now.year;
    month = prefs.getInt(_monthKey) ?? now.month;
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isYearlyKey, isYearly);
    await prefs.setInt(_yearKey, year);
    await prefs.setInt(_monthKey, month);
  }
}
