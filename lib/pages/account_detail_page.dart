import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ledger_app/main.dart';
import 'package:ledger_app/models/account.dart';
import 'package:ledger_app/models/ledger_entry.dart';
import 'package:ledger_app/models/enums.dart';
import 'package:ledger_app/pages/entry_form_page.dart';
import 'package:ledger_app/pages/search_page.dart';
import 'package:ledger_app/store/ledger_store.dart';
import 'package:ledger_app/utils/helpers.dart';
import 'package:ledger_app/widgets/common_widgets.dart';

class AccountDetailPage extends StatefulWidget {
  const AccountDetailPage({required this.account, super.key});

  final Account account;

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  double? _touchX;

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);
    final account = widget.account;
    final iconOption = accountIconOption(account.iconKey);

    // 筛选该账户的流水
    final entries = store.entries.where((e) {
      return e.toAccountId == account.id || e.fromAccountId == account.id;
    }).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    // 计算最近30天每日余额
    final now = DateTime.now();
    final balanceData = _computeDailyBalance(store, account, now);

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
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
                      Navigator.pop(context);
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
      backgroundColor: const Color(0xFFF8FAF6),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Hero 卡片
          _buildHeroCard(account, iconOption, balanceData, now),
          const SizedBox(height: 16),
          // 流水列表
          ..._buildEntrySections(entries, store),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    Account account,
    AccountIconOption iconOption,
    List<DailyBalance> balanceData,
    DateTime now,
  ) {
    // 判断是否有流水记录（检查余额是否变化过）
    final hasTransactions = balanceData.length > 1 &&
        balanceData.first.balance != balanceData.last.balance;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: iconOption.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: iconOption.color.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: AccountIconBadge(option: iconOption, size: 28),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                account.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            formatMoney(account.balanceInCents),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (hasTransactions) ...[
            const SizedBox(height: 20),
            // 折线图
            SizedBox(
              height: 120,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  setState(() => _touchX = details.localPosition.dx);
                },
                onHorizontalDragEnd: (_) {
                  Future.delayed(const Duration(milliseconds: 800), () {
                    if (mounted) setState(() => _touchX = null);
                  });
                },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: BalanceLineChartPainter(
                    data: balanceData,
                    touchX: _touchX,
                    now: now,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${now.subtract(const Duration(days: 29)).month}/${now.subtract(const Duration(days: 29)).day}',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
                Text(
                  '${now.month}/${now.day}',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              '最近30天无流水记录',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<DailyBalance> _computeDailyBalance(
    LedgerStore store,
    Account account,
    DateTime now,
  ) {
    final result = <DailyBalance>[];

    // 只获取30天范围内的流水
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 29));
    final entries = store.entries.where((e) {
      final entryDay = DateTime(e.occurredAt.year, e.occurredAt.month, e.occurredAt.day);
      final isAccountRelated = e.toAccountId == account.id || e.fromAccountId == account.id;
      return isAccountRelated && !entryDay.isBefore(start);
    }).toList();

    // 计算30天内的总变化
    int totalChange = 0;
    for (final entry in entries) {
      if (entry.toAccountId == account.id) {
        totalChange += entry.amountInCents;
      }
      if (entry.fromAccountId == account.id) {
        totalChange -= entry.amountInCents;
      }
    }

    // 第1天开始前的余额 = 当前余额 - 30天内的总变化
    int balance = account.balanceInCents - totalChange;

    for (var i = 0; i < 30; i++) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 29 - i));
      final dayStart = DateTime(day.year, day.month, day.day);

      // 找到当天的流水
      final dayEntries = entries.where((e) {
        final eDay = DateTime(e.occurredAt.year, e.occurredAt.month, e.occurredAt.day);
        return eDay == dayStart;
      }).toList();

      // 加上当天的净变化
      for (final entry in dayEntries) {
        if (entry.toAccountId == account.id) {
          balance += entry.amountInCents;
        }
        if (entry.fromAccountId == account.id) {
          balance -= entry.amountInCents;
        }
      }

      // 记录当天结束时的余额
      result.add(DailyBalance(date: dayStart, balance: balance));
    }

    return result;
  }

  List<Widget> _buildEntrySections(
    List<LedgerEntry> entries,
    LedgerStore store,
  ) {
    if (entries.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text('暂无流水记录', style: TextStyle(color: Color(0xFF999999))),
          ),
        ),
      ];
    }

    final grouped = groupLedgerEntriesByDate(entries);
    final widgets = <Widget>[];

    for (final group in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            group.key,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
            ),
          ),
        ),
      );

      // 同一天的流水合并到一个 Card 中
      widgets.add(
        Card(
          elevation: 1,
          shadowColor: const Color(0x1A53615D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              for (int i = 0; i < group.value.length; i++)
                Column(
                  children: [
                    LedgerEntryTile(
                      entry: group.value[i],
                      store: store,
                      hideAccount: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EntryFormPage(
                              store: store,
                              entry: group.value[i],
                              onSaved: (_) => setState(() {}),
                            ),
                          ),
                        );
                      },
                    ),
                    if (i < group.value.length - 1)
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
      );
    }

    return widgets;
  }
}

class DailyBalance {
  final DateTime date;
  final int balance;

  DailyBalance({required this.date, required this.balance});
}

class BalanceLineChartPainter extends CustomPainter {
  final List<DailyBalance> data;
  final double? touchX;
  final DateTime now;

  BalanceLineChartPainter({
    required this.data,
    this.touchX,
    required this.now,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final minBalance = data.map((d) => d.balance).reduce(math.min);
    final maxBalance = data.map((d) => d.balance).reduce(math.max);
    final range = (maxBalance - minBalance).toDouble();
    if (range == 0) return;

    // 计算最长标签的宽度
    const gap = 8.0; // 标签文字右边缘到折线图的间距
    final labelTextPaint = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );
    double maxLabelWidth = 0;
    for (var i = 0; i <= 4; i++) {
      final value = maxBalance - (range * i / 4).toInt();
      labelTextPaint.text = TextSpan(
        text: _formatValue(value),
        style: const TextStyle(fontSize: 8),
      );
      labelTextPaint.layout();
      if (labelTextPaint.width > maxLabelWidth) {
        maxLabelWidth = labelTextPaint.width;
      }
    }

    final labelWidth = maxLabelWidth + gap;
    final chartWidth = size.width - labelWidth;

    // 画5条纵轴参考线（虚线）及左侧数据标签
    final dashPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var i = 0; i <= 4; i++) {
      final y = (i / 4) * size.height;
      _drawDashedLine(canvas, Offset(labelWidth, y), Offset(size.width, y), dashPaint, 4);

      // 在每条线左侧显示对应的数据
      final value = maxBalance - (range * i / 4).toInt();
      labelTextPaint.text = TextSpan(
        text: _formatValue(value),
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 8,
        ),
      );
      labelTextPaint.layout();
      labelTextPaint.paint(canvas, Offset(labelWidth - labelTextPaint.width - gap, y - 5));
    }

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = labelWidth + (i / (data.length - 1)) * chartWidth;
      final y = size.height -
          ((data[i].balance - minBalance).toDouble() / range) * (size.height - 10) -
          5;
      points.add(Offset(x, y));
    }

    // 画折线
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);

    // 滑动指示器
    if (touchX != null) {
      final touchIndex =
          (touchX! / size.width * (data.length - 1)).round().clamp(0, data.length - 1);
      final touchPoint = points[touchIndex];

      // 画高亮圆点
      final highlightPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(touchPoint, 6, highlightPaint);

      final strokePaint = Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(touchPoint, 10, strokePaint);

      // 画日期标签
      final date = data[touchIndex].date;
      final label = '${date.month}/${date.day}';
      final balance = formatMoney(data[touchIndex].balance);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$label  $balance',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      var labelX = touchPoint.dx - textPainter.width / 2;
      labelX = labelX.clamp(0.0, size.width - textPainter.width);

      // 画标签背景
      final bgPaint = Paint()
        ..color = const Color(0xCC000000)
        ..style = PaintingStyle.fill;
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelX - 4,
          touchPoint.dy - 28,
          textPainter.width + 8,
          textPainter.height + 8,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(bgRect, bgPaint);

      textPainter.paint(
        canvas,
        Offset(labelX, touchPoint.dy - 24),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BalanceLineChartPainter oldDelegate) {
    return oldDelegate.touchX != touchX || oldDelegate.data != data;
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint, double dashLength) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final dashes = (distance / dashLength).floor();

    for (var i = 0; i < dashes; i++) {
      final x1 = start.dx + (dx * i / dashes);
      final y1 = start.dy + (dy * i / dashes);
      final x2 = start.dx + (dx * (i + 0.5) / dashes);
      final y2 = start.dy + (dy * (i + 0.5) / dashes);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  String _formatValue(int value) {
    // value 是分（整数），先转换为元
    final yuan = value / 100.0;
    if (yuan >= 10000) {
      return '${(yuan / 10000).toStringAsFixed(1)}万';
    } else if (yuan >= 1000) {
      return '${(yuan / 1000).toStringAsFixed(1)}K';
    }
    // 去掉 formatMoney 的 ¥ 前缀
    return formatMoney(value).replaceFirst('¥', '').trim();
  }
}
