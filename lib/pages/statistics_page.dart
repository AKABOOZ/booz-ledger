import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ledger_app/models/account.dart';
import 'package:ledger_app/models/category.dart';
import 'package:ledger_app/models/enums.dart';
import 'package:ledger_app/models/ledger_entry.dart';
import 'package:ledger_app/pages/entry_form_page.dart';
import 'package:ledger_app/store/ledger_store.dart';
import 'package:ledger_app/utils/helpers.dart';
import 'package:ledger_app/widgets/common_widgets.dart';


class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  static const _statsIsYearlyKey = 'statistics_is_yearly';
  static const _statsYearKey = 'statistics_year';
  static const _statsMonthKey = 'statistics_month';

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late int _year = DateTime.now().year;
  bool _groupByMajor = false;
  bool _isYearlyView = false;
  LedgerEntryType _selectedType = LedgerEntryType.expense;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_restoreStatisticsPeriod());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);
    final entries = _isYearlyView
        ? store.entries.where((entry) {
            return entry.occurredAt.year == _year;
          }).toList()
        : store.entries.where((entry) {
            return entry.occurredAt.year == _month.year &&
                entry.occurredAt.month == _month.month;
          }).toList();
    final expenseStats = _groupedStats(
      entries,
      type: LedgerEntryType.expense,
      groupLabel: expenseGroupLabel,
      categoryLabel: expenseCategoryLabel,
    );
    final incomeStats = _groupedStats(
      entries,
      type: LedgerEntryType.income,
      groupLabel: incomeGroupLabel,
      categoryLabel: incomeCategoryLabel,
    );
    final expenseLeafStats = _leafStats(
      entries,
      type: LedgerEntryType.expense,
      categoryLabel: expenseCategoryLabel,
    );
    final incomeLeafStats = _leafStats(
      entries,
      type: LedgerEntryType.income,
      categoryLabel: incomeCategoryLabel,
    );
    final totals = StatsTotals.fromEntries(entries);
    final activeStats = _selectedType == LedgerEntryType.expense
        ? (_groupByMajor
              ? expenseStats.map(
                  (key, value) => MapEntry(
                    key,
                    CategoryStat(total: value.total, count: value.count),
                  ),
                )
              : expenseLeafStats)
        : (_groupByMajor
              ? incomeStats.map(
                  (key, value) => MapEntry(
                    key,
                    CategoryStat(total: value.total, count: value.count),
                  ),
                )
              : incomeLeafStats);
    final activeChildren = _groupByMajor
        ? (_selectedType == LedgerEntryType.expense
              ? expenseStats.map((key, value) => MapEntry(key, value.children))
              : incomeStats.map((key, value) => MapEntry(key, value.children)))
        : const <String, Map<String, CategoryStat>>{};
    final activeTotal = _selectedType == LedgerEntryType.expense
        ? totals.expense
        : totals.income;
    final activeColor = _selectedType == LedgerEntryType.expense
        ? const Color(0xFFE2554F)
        : const Color(0xFF1F8A4C);
    final activeTitle = _selectedType == LedgerEntryType.expense
        ? '支出分类排行'
        : '收入分类排行';
    final activeEmptyTitle = _selectedType == LedgerEntryType.expense
        ? '这个周期还没有支出'
        : '这个周期还没有收入';
    final activeEmptySubtitle = _selectedType == LedgerEntryType.expense
        ? '记一笔支出后，这里会自动生成分类排行'
        : '记一笔收入后，这里会自动生成分类排行';

    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        children: [
          StatisticsSummaryCard(
            title: _periodTitle,
            totals: totals,
            onPrevious: _goPreviousPeriod,
            onNext: _goNextPeriod,
            onPickPeriod: _showPeriodPicker,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatisticsSlidingSwitch<bool>(
                  value: _selectedType == LedgerEntryType.expense,
                  leftValue: true,
                  leftLabel: '支出',
                  rightValue: false,
                  rightLabel: '收入',
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value
                          ? LedgerEntryType.expense
                          : LedgerEntryType.income;
                    });
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StatisticsSlidingSwitch<bool>(
                  value: !_groupByMajor,
                  leftValue: true,
                  leftLabel: '小类',
                  rightValue: false,
                  rightLabel: '大类',
                  onChanged: (value) {
                    setState(() => _groupByMajor = !value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StatisticsBlock(
            title: activeTitle,
            total: activeTotal,
            stats: activeStats,
            emptyTitle: activeEmptyTitle,
            emptySubtitle: activeEmptySubtitle,
            color: activeColor,
            type: _selectedType,
            groupByMajor: _groupByMajor,
            store: store,
            childrenByGroup: activeChildren,
            onCategoryTap: (category) => _navigateToCategoryDetail(
              context,
              category,
              _selectedType,
              groupByMajor: _groupByMajor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreStatisticsPeriod() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    final now = DateTime.now();
    final year = prefs.getInt(_statsYearKey) ?? now.year;
    final month = prefs.getInt(_statsMonthKey) ?? now.month;
    setState(() {
      _isYearlyView = prefs.getBool(_statsIsYearlyKey) ?? false;
      _year = year;
      _month = DateTime(year, month.clamp(1, 12));
    });
  }

  Future<void> _saveStatisticsPeriod() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_statsIsYearlyKey, _isYearlyView);
    await prefs.setInt(_statsYearKey, _isYearlyView ? _year : _month.year);
    await prefs.setInt(_statsMonthKey, _month.month);
  }

  Future<void> _showPeriodPicker() async {
    final result = await showStatisticsPeriodPicker(
      context,
      isYearlyView: _isYearlyView,
      month: _month,
      year: _year,
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _isYearlyView = result.isYearlyView;
      _month = result.month;
      _year = result.year;
    });
    await _saveStatisticsPeriod();
  }

  String get _periodTitle {
    if (_isYearlyView) {
      return '$_year年';
    }
    return '${_month.year}年${_month.month}月';
  }

  void _goPreviousPeriod() {
    setState(() {
      if (_isYearlyView) {
        _year--;
      } else {
        _month = DateTime(_month.year, _month.month - 1);
      }
    });
    unawaited(_saveStatisticsPeriod());
  }

  void _goNextPeriod() {
    setState(() {
      if (_isYearlyView) {
        _year++;
      } else {
        _month = DateTime(_month.year, _month.month + 1);
      }
    });
    unawaited(_saveStatisticsPeriod());
  }

  void _navigateToCategoryDetail(
    BuildContext context,
    String category,
    LedgerEntryType type, {
    required bool groupByMajor,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CategoryDetailPage(
          category: category,
          type: type,
          groupByMajor: groupByMajor,
          isYearly: _isYearlyView,
          year: _year,
          month: _month,
        ),
      ),
    );
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

  Map<String, CategoryStat> _leafStats(
    List<LedgerEntry> entries, {
    required LedgerEntryType type,
    required String Function(LedgerEntry entry) categoryLabel,
  }) {
    final stats = <String, CategoryStat>{};
    for (final entry in entries.where((entry) => entry.type == type)) {
      final category = categoryLabel(entry);
      final current = stats[category] ?? CategoryStat.empty();
      stats[category] = current.add(entry.amountInCents);
    }
    return Map.fromEntries(
      stats.entries.toList()
        ..sort((a, b) => b.value.total.compareTo(a.value.total)),
    );
  }
}

class StatsTotals {
  const StatsTotals({
    required this.income,
    required this.expense,
    required this.entries,
  });

  factory StatsTotals.fromEntries(List<LedgerEntry> entries) {
    var income = 0;
    var expense = 0;
    for (final entry in entries) {
      if (entry.type == LedgerEntryType.income) {
        income += entry.amountInCents;
      } else if (entry.type == LedgerEntryType.expense) {
        expense += entry.amountInCents;
      }
    }
    return StatsTotals(
      income: income,
      expense: expense,
      entries: entries.length,
    );
  }

  final int income;
  final int expense;
  final int entries;

  int get net => income - expense;
}

class StatisticsSummaryCard extends StatelessWidget {
  const StatisticsSummaryCard({
    required this.title,
    required this.totals,
    required this.onPrevious,
    required this.onNext,
    required this.onPickPeriod,
  });

  final String title;
  final StatsTotals totals;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickPeriod;

  @override
  Widget build(BuildContext context) {
    final netColor = totals.net >= 0
        ? const Color(0xFF167C80)
        : const Color(0xFFE2554F);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1453615D),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              PeriodIconButton(
                icon: Icons.chevron_left,
                onPressed: onPrevious,
              ),
              Expanded(
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: onPickPeriod,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              size: 20,
                              color: Color(0xFF111817),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PeriodIconButton(icon: Icons.chevron_right, onPressed: onNext),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SummaryMetric(
                  label: '收入',
                  value: formatMoney(totals.income),
                  color: const Color(0xFF1F8A4C),
                ),
              ),
              MetricDivider(),
              Expanded(
                child: SummaryMetric(
                  label: '支出',
                  value: formatMoney(totals.expense),
                  color: const Color(0xFFE2554F),
                ),
              ),
              MetricDivider(),
              Expanded(
                child: SummaryMetric(
                  label: '结余',
                  value: formatMoney(totals.net),
                  color: netColor,
                ),
              ),
            ],
          ),
          if (totals.entries == 0) ...[
            const SizedBox(height: 12),
            Text(
              '这个周期还没有流水',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8B9A94),
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PeriodIconButton extends StatelessWidget {
  const PeriodIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF167C80)),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFE0F2EF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class SummaryMetric extends StatelessWidget {
  const SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF7A8782),
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFFE6ECE9),
    );
  }
}

class StatisticsSlidingSwitch<T> extends StatelessWidget {
  const StatisticsSlidingSwitch({
    required this.value,
    required this.leftValue,
    required this.leftLabel,
    required this.rightValue,
    required this.rightLabel,
    required this.onChanged,
    this.height = 36,
  });

  final T value;
  final T leftValue;
  final String leftLabel;
  final T rightValue;
  final String rightLabel;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isLeftSelected = value == leftValue;
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F1),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: isLeftSelected ? 0 : itemWidth,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular((height - 8) / 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: StatisticsSwitchTapTarget(
                      label: leftLabel,
                      selected: isLeftSelected,
                      onTap: () => onChanged(leftValue),
                    ),
                  ),
                  Expanded(
                    child: StatisticsSwitchTapTarget(
                      label: rightLabel,
                      selected: !isLeftSelected,
                      onTap: () => onChanged(rightValue),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class StatisticsSwitchTapTarget extends StatelessWidget {
  const StatisticsSwitchTapTarget({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            color: selected ? const Color(0xFF167C80) : const Color(0xFF65736F),
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 0,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class StatisticsPeriodResult {
  const StatisticsPeriodResult({
    required this.isYearlyView,
    required this.month,
    required this.year,
  });

  final bool isYearlyView;
  final DateTime month;
  final int year;
}

Future<StatisticsPeriodResult?> showStatisticsPeriodPicker(
  BuildContext context, {
  required bool isYearlyView,
  required DateTime month,
  required int year,
}) {
  var draftIsYearly = isYearlyView;
  var draftMonth = DateTime(month.year, month.month);
  var draftYear = year;
  var draftDecadeStart = (year ~/ 10) * 10;
  final now = DateTime.now();

  return showModalBottomSheet<StatisticsPeriodResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final monthYear = draftMonth.year;
          final decadeEnd = draftDecadeStart + 9;
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '选择统计时间',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    StatisticsSlidingSwitch<bool>(
                      value: !draftIsYearly,
                      leftValue: true,
                      leftLabel: '月度',
                      rightValue: false,
                      rightLabel: '年度',
                      height: 42,
                      onChanged: (value) {
                        setModalState(() {
                          draftIsYearly = !value;
                          draftDecadeStart = (draftYear ~/ 10) * 10;
                        });
                      },
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        PeriodIconButton(
                          icon: Icons.chevron_left,
                          onPressed: () {
                            setModalState(() {
                              if (draftIsYearly) {
                                draftDecadeStart -= 10;
                              } else {
                                draftMonth = DateTime(
                                  draftMonth.year - 1,
                                  draftMonth.month,
                                );
                              }
                            });
                          },
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              draftIsYearly
                                  ? '$draftDecadeStart-$decadeEnd年'
                                  : '$monthYear年',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                  ),
                            ),
                          ),
                        ),
                        PeriodIconButton(
                          icon: Icons.chevron_right,
                          onPressed: () {
                            setModalState(() {
                              if (draftIsYearly) {
                                draftDecadeStart += 10;
                              } else {
                                draftMonth = DateTime(
                                  draftMonth.year + 1,
                                  draftMonth.month,
                                );
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (draftIsYearly)
                      PeriodOptionGrid(
                        itemCount: 10,
                        itemBuilder: (index) {
                          final itemYear = draftDecadeStart + index;
                          return PeriodOptionButton(
                            label: itemYear == now.year ? '本年' : '$itemYear年',
                            selected: draftYear == itemYear,
                            onTap: () {
                              setModalState(() => draftYear = itemYear);
                            },
                          );
                        },
                      )
                    else
                      PeriodOptionGrid(
                        itemCount: 12,
                        itemBuilder: (index) {
                          final itemMonth = index + 1;
                          final isThisMonth =
                              monthYear == now.year && itemMonth == now.month;
                          return PeriodOptionButton(
                            label: isThisMonth ? '本月' : '$itemMonth月',
                            selected:
                                draftMonth.year == monthYear &&
                                draftMonth.month == itemMonth,
                            onTap: () {
                              setModalState(() {
                                draftMonth = DateTime(monthYear, itemMonth);
                              });
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            StatisticsPeriodResult(
                              isYearlyView: draftIsYearly,
                              month: draftMonth,
                              year: draftIsYearly ? draftYear : draftMonth.year,
                            ),
                          );
                        },
                        child: const Text(
                          '确定',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class PeriodOptionGrid extends StatelessWidget {
  const PeriodOptionGrid({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final Widget Function(int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 1.85,
      ),
      itemBuilder: (context, index) => itemBuilder(index),
    );
  }
}

class PeriodOptionButton extends StatelessWidget {
  const PeriodOptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE0F2EF) : const Color(0xFFE4E6E5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF069B9B) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF167C80) : const Color(0xFF65736F),
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class StatisticsBlock extends StatefulWidget {
  const StatisticsBlock({
    required this.title,
    required this.total,
    required this.stats,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.color,
    required this.type,
    required this.groupByMajor,
    required this.store,
    this.childrenByGroup = const {},
    this.onCategoryTap,
    super.key,
  });

  final String title;
  final int total;
  final Map<String, CategoryStat> stats;
  final Map<String, Map<String, CategoryStat>> childrenByGroup;
  final String emptyTitle;
  final String emptySubtitle;
  final Color color;
  final LedgerEntryType type;
  final bool groupByMajor;
  final LedgerStore store;
  final void Function(String category)? onCategoryTap;

  @override
  State<StatisticsBlock> createState() => _StatisticsBlockState();
}

class _StatisticsBlockState extends State<StatisticsBlock> {
  bool _expanded = false;
  bool _hasInteracted = false;

  @override
  void didUpdateWidget(covariant StatisticsBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stats != widget.stats ||
        oldWidget.type != widget.type ||
        oldWidget.groupByMajor != widget.groupByMajor) {
      _expanded = false;
      _hasInteracted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleEntries = _visibleEntries(widget.stats);
    final canExpand = widget.stats.length > 8;
    final totalCount = widget.stats.values.fold<int>(
      0,
      (sum, stat) => sum + stat.count,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1453615D),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Transform.translate(
                    offset: const Offset(0, -2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.groupByMajor
                              ? '按大类汇总，点分类查看明细'
                              : '按小类汇总，点分类查看明细',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF7A8782),
                                letterSpacing: 0,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(widget.total),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: widget.color,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '共$totalCount笔',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF94A29C),
                        fontSize: 11,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (widget.stats.isEmpty)
              StatisticsEmptyState(
                title: widget.emptyTitle,
                subtitle: widget.emptySubtitle,
                color: widget.color,
              )
            else ...[
              StatisticsPieSection(
                stats: widget.stats,
                total: widget.total,
                type: widget.type,
                groupByMajor: widget.groupByMajor,
                store: widget.store,
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE9EFEC)),
              const SizedBox(height: 14),
              ClipRect(
                child: AnimatedSize(
                  duration: _hasInteracted
                      ? const Duration(milliseconds: 320)
                      : Duration.zero,
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: visibleEntries.asMap().entries.map((visible) {
                      final index = visible.key;
                      final entry = visible.value;
                      final childStats = widget.childrenByGroup[entry.key];
                      return StatRankRow(
                        name: entry.key,
                        amount: entry.value.total,
                        total: widget.total,
                        iconColor: _iconColorFor(entry.key),
                        chartColor: _chartColorFor(entry.key, index),
                        icon: _iconFor(entry.key),
                        children: childStats,
                        onTap: widget.onCategoryTap == null
                            ? null
                            : () => widget.onCategoryTap!(entry.key),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (canExpand)
                StatisticsExpandButton(
                  expanded: _expanded,
                  onTap: () => setState(() {
                    _hasInteracted = true;
                    _expanded = !_expanded;
                  }),
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<MapEntry<String, CategoryStat>> _visibleEntries(
    Map<String, CategoryStat> source,
  ) {
    final entries = source.entries.toList();
    if (_expanded || entries.length <= 8) {
      return entries;
    }
    return entries.take(8).toList();
  }

  IconData _iconFor(String label) {
    if (widget.type == LedgerEntryType.expense) {
      return _expenseIconFor(label);
    }
    return _incomeIconFor(label);
  }

  Color _iconColorFor(String label) {
    if (widget.groupByMajor) {
      return categoryGroupColor(label);
    }
    if (widget.type == LedgerEntryType.expense) {
      final group = widget.store.groupNameForExpenseCategory(label) ?? '旧分类';
      return categoryGroupColor(group);
    }
    final group = widget.store.groupNameForIncomeCategory(label) ?? '旧分类';
    return categoryGroupColor(group);
  }

  Color _chartColorFor(String label, int index) {
    final baseColor = _iconColorFor(label);
    return statisticsChartColor(
      baseColor,
      index,
      type: widget.type,
      groupByMajor: widget.groupByMajor,
    );
  }

  IconData _expenseIconFor(String label) {
    if (widget.groupByMajor) {
      for (final group in widget.store.expenseCategoryGroups) {
        if (group.name == label && group.children.isNotEmpty) {
          return categoryIcon(group.children.first.iconKey);
        }
      }
      return Icons.folder_rounded;
    }
    for (final group in widget.store.expenseCategoryGroups) {
      for (final item in group.children) {
        if (item.name == label) {
          return categoryIcon(item.iconKey);
        }
      }
    }
    return Icons.category_rounded;
  }

  IconData _incomeIconFor(String label) {
    if (widget.groupByMajor) {
      for (final group in widget.store.incomeCategoryGroups) {
        if (group.name == label && group.children.isNotEmpty) {
          return categoryIcon(group.children.first.iconKey);
        }
      }
      return Icons.folder_rounded;
    }
    for (final group in widget.store.incomeCategoryGroups) {
      for (final item in group.children) {
        if (item.name == label) {
          return categoryIcon(item.iconKey);
        }
      }
    }
    return Icons.category_rounded;
  }
}

class StatisticsPieSection extends StatelessWidget {
  const StatisticsPieSection({
    required this.stats,
    required this.total,
    required this.type,
    required this.groupByMajor,
    required this.store,
  });

  final Map<String, CategoryStat> stats;
  final int total;
  final LedgerEntryType type;
  final bool groupByMajor;
  final LedgerStore store;

  @override
  Widget build(BuildContext context) {
    final items = stats.entries.take(9).toList();
    return SizedBox(
      height: 188,
      child: Center(
        child: StatisticsPieChart(
          items: items,
          total: total,
          colorForItem: _colorForItem,
          iconForLabel: _iconFor,
        ),
      ),
    );
  }

  Color _iconColorFor(String label) {
    if (groupByMajor) {
      return categoryGroupColor(label);
    }
    if (type == LedgerEntryType.expense) {
      final group = store.groupNameForExpenseCategory(label) ?? '旧分类';
      return categoryGroupColor(group);
    }
    final group = store.groupNameForIncomeCategory(label) ?? '旧分类';
    return categoryGroupColor(group);
  }

  Color _colorForItem(String label, int index) {
    return statisticsChartColor(
      _iconColorFor(label),
      index,
      type: type,
      groupByMajor: groupByMajor,
    );
  }

  IconData _iconFor(String label) {
    if (groupByMajor) {
      if (type == LedgerEntryType.expense) {
        for (final group in store.expenseCategoryGroups) {
          if (group.name == label && group.children.isNotEmpty) {
            return categoryIcon(group.children.first.iconKey);
          }
        }
      } else {
        for (final group in store.incomeCategoryGroups) {
          if (group.name == label && group.children.isNotEmpty) {
            return categoryIcon(group.children.first.iconKey);
          }
        }
      }
      return Icons.folder_rounded;
    }
    if (type == LedgerEntryType.expense) {
      return categoryIcon(store.expenseItemByName(label)?.iconKey ?? '');
    }
    return categoryIcon(store.incomeItemByName(label)?.iconKey ?? '');
  }
}

class StatisticsPieChart extends StatelessWidget {
  const StatisticsPieChart({
    required this.items,
    required this.total,
    required this.colorForItem,
    required this.iconForLabel,
  });

  final List<MapEntry<String, CategoryStat>> items;
  final int total;
  final Color Function(String label, int index) colorForItem;
  final IconData Function(String label) iconForLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      height: 176,
      child: CustomPaint(
        painter: StatisticsPieChartPainter(
          items: items,
          total: total,
          colorForItem: colorForItem,
          iconForLabel: iconForLabel,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class StatisticsPieChartPainter extends CustomPainter {
  const StatisticsPieChartPainter({
    required this.items,
    required this.total,
    required this.colorForItem,
    required this.iconForLabel,
  });

  final List<MapEntry<String, CategoryStat>> items;
  final int total;
  final Color Function(String label, int index) colorForItem;
  final IconData Function(String label) iconForLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 28.0;
    final chartCenter = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final arcRect = Rect.fromCircle(center: chartCenter, radius: radius);
    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFFEAF0ED);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2, false, backgroundPaint);

    if (total <= 0 || items.isEmpty) {
      return;
    }

    final segmentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    final visibleTotal = items.fold<int>(
      0,
      (sum, entry) => sum + entry.value.total,
    );
    final iconRadius = radius;
    final iconTextStyle = TextStyle(
      inherit: false,
      fontSize: 14,
      fontFamily: Icons.home.fontFamily,
      package: Icons.home.fontPackage,
      color: Colors.white.withValues(alpha: 0.96),
    );

    var startAngle = -math.pi / 2;
    for (var index = 0; index < items.length; index++) {
      final entry = items[index];
      final sweepAngle = (entry.value.total / visibleTotal) * math.pi * 2;
      if (sweepAngle <= 0) {
        continue;
      }
      final segmentColor = colorForItem(entry.key, index);
      segmentPaint.color = segmentColor;
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, segmentPaint);
      final innerArcLength = sweepAngle * iconRadius;
      if (sweepAngle >= 0.46 && innerArcLength >= 18) {
        final iconAngle = startAngle + sweepAngle / 2;
        final iconDistance = radius;
        final iconCenter = Offset(
          chartCenter.dx + math.cos(iconAngle) * iconDistance,
          chartCenter.dy + math.sin(iconAngle) * iconDistance,
        );
        final textPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(iconForLabel(entry.key).codePoint),
            style: iconTextStyle,
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        final iconOffset = Offset(
          iconCenter.dx - textPainter.width / 2,
          iconCenter.dy - textPainter.height / 2,
        );
        textPainter.paint(canvas, iconOffset);
      }
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant StatisticsPieChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.items != items;
  }
}

class StatisticsExpandButton extends StatelessWidget {
  const StatisticsExpandButton({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF7A8782);
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(
          expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: color,
        ),
        label: Text(
          expanded ? '点击收起' : '点击展开',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class StatisticsEmptyState extends StatelessWidget {
  const StatisticsEmptyState({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: Column(
          children: [
            IconBadge(icon: Icons.bar_chart_rounded, color: color, size: 52),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF7A8782),
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatRankRow extends StatelessWidget {
  const StatRankRow({
    required this.name,
    required this.amount,
    required this.total,
    required this.iconColor,
    required this.chartColor,
    required this.icon,
    this.children,
    this.onTap,
  });

  final String name;
  final int amount;
  final int total;
  final Color iconColor;
  final Color chartColor;
  final IconData icon;
  final Map<String, CategoryStat>? children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : amount / total;
    final percent = (ratio * 100).toStringAsFixed(ratio < 0.1 ? 1 : 0);
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
    );
    final valueStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
    );
    final percentStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: const Color(0xFF7A8782),
      letterSpacing: 0,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(icon: icon, color: iconColor, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: titleStyle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text('$percent%', style: percentStyle),
                              ),
                              const SizedBox(width: 10),
                              Text(formatMoney(amount), style: valueStyle),
                            ],
                          ),
                          const Spacer(),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              minHeight: 8,
                              value: ratio.clamp(0.0, 1.0),
                              color: chartColor,
                              backgroundColor: chartColor.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (children != null && children!.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...children!.entries.take(3).map((entry) {
                  final childRatio = amount == 0
                      ? 0.0
                      : entry.value.total / amount;
                  return Padding(
                    padding: const EdgeInsets.only(left: 50, bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: const Color(0xFF65736F),
                                  letterSpacing: 0,
                                ),
                          ),
                        ),
                        Text(
                          '${formatMoney(entry.value.total)}  ${(childRatio * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF65736F),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class CategoryDetailPage extends StatefulWidget {
  const CategoryDetailPage({
    required this.category,
    required this.type,
    required this.groupByMajor,
    required this.isYearly,
    required this.year,
    required this.month,
    super.key,
  });

  final String category;
  final LedgerEntryType type;
  final bool groupByMajor;
  final bool isYearly;
  final int year;
  final DateTime month;

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);
    final entries = store.entries.where((entry) {
      if (widget.isYearly) {
        return entry.occurredAt.year == widget.year &&
            _entryMatchesCategory(entry, widget.category, widget.type);
      } else {
        return entry.occurredAt.year == widget.month.year &&
            entry.occurredAt.month == widget.month.month &&
            _entryMatchesCategory(entry, widget.category, widget.type);
      }
    }).toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    // 计算流水笔数和总额
    final entryCount = entries.length;
    final totalAmount = entries.fold(
      0,
      (sum, entry) => sum + entry.amountInCents,
    );

    // 按日期分组
    final groups = <String, List<LedgerEntry>>{};
    for (final entry in entries) {
      final key = dateKey(entry.occurredAt);
      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(entry);
    }

    final List<Widget> children = [];
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    for (final key in sortedKeys) {
      final groupEntries = groups[key]!;
      final firstEntry = groupEntries.first;

      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            formatDateOnly(firstEntry.occurredAt),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w400,
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
                        onTap: () => showEditEntrySheet(context, entry: groupEntries[i]),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$entryCount笔',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  formatMoney(totalAmount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: widget.type == LedgerEntryType.expense
                        ? Theme.of(context).colorScheme.error
                        : const Color(0xFF1E7A39),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 0, bottom: 112),
          children: [
            if (entries.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: '暂无流水',
                message: '该分类下还没有流水记录。',
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }

  bool _entryMatchesCategory(
    LedgerEntry entry,
    String category,
    LedgerEntryType type,
  ) {
    if (type == LedgerEntryType.expense) {
      if (widget.groupByMajor) {
        return entry.expenseGroup == category || entry.category == category;
      }
      return entry.expenseCategory == category || entry.category == category;
    }
    if (widget.groupByMajor) {
      return entry.incomeGroup == category || entry.category == category;
    }
    return entry.incomeCategory == category || entry.category == category;
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
                  store.isAmountHidden
                      ? Icons.visibility_off
                      : Icons.visibility,
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

