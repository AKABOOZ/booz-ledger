import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:ledger_app/models/account.dart';
import 'package:ledger_app/models/enums.dart';
import 'package:ledger_app/models/ledger_entry.dart';
import 'package:ledger_app/store/ledger_store.dart';
import 'package:ledger_app/utils/helpers.dart';

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
          colorFilter: ColorFilter.mode(option.color, BlendMode.srcIn),
        ),
      );
    }
    return IconBadge(icon: option.icon!, color: option.color, size: size);
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

class LedgerEntryTile extends StatelessWidget {
  const LedgerEntryTile({
    required this.entry,
    required this.store,
    this.onTap,
    this.isLast = false,
    super.key,
  });

  final LedgerEntry entry;
  final LedgerStore store;
  final VoidCallback? onTap;
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
    final iconColor = entryCategoryBadgeColor(entry, store, context);
    final shouldMaskAmount = shouldMaskSalaryIncome(entry, store);
    final amountText = shouldMaskAmount
        ? '****'
        : entry.type == LedgerEntryType.transfer
        ? formatMoney(entry.amountInCents)
        : '$amountPrefix${formatMoney(entry.amountInCents)}';
    final timeOnly = _formatTimeOnly(entry.occurredAt);
    final metaLine = [
      if (entry.type != LedgerEntryType.transfer) accountLine,
      timeOnly,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, isLast ? 16 : 14),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(0x80),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    metaLine,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(0x60),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
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
      LedgerEntryType.expense => Icons.payments_rounded,
      LedgerEntryType.income => Icons.savings_rounded,
      LedgerEntryType.transfer => Icons.swap_horiz,
    };
  }
}

