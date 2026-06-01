import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ledger_app/models/account.dart';
import 'package:ledger_app/models/category.dart';
import 'package:ledger_app/models/enums.dart';
import 'package:ledger_app/models/ledger_entry.dart';
import 'package:ledger_app/pages/entry_form_page.dart';
import 'package:ledger_app/pages/statistics_page.dart';
import 'package:ledger_app/store/ledger_store.dart';
import 'package:ledger_app/utils/helpers.dart';
import 'package:ledger_app/widgets/common_widgets.dart';


class LedgerSearchPage extends StatefulWidget {
  const LedgerSearchPage({super.key});

  @override
  State<LedgerSearchPage> createState() => _LedgerSearchPageState();
}

class _LedgerSearchPageState extends State<LedgerSearchPage> {
  static const MethodChannel _windowChannel = MethodChannel(
    'ledger_app/window',
  );
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  String _query = '';
  Set<LedgerEntryType> _selectedTypes = Set.of(LedgerEntryType.values);
  _LedgerSearchTimeFilter _timeFilter = _LedgerSearchTimeFilter.all;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  Set<String>? _selectedCategoryKeys;
  Set<String>? _selectedAccountIds;
  Future<bool>? _pendingKeyboardDismissRequest;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _setSoftInputAdjustNothing();
    _scheduleInitialSearchFocus();
  }

  @override
  void dispose() {
    unawaited(_setSoftInputAdjustResize());
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _setSoftInputAdjustNothing() async {
    try {
      await _windowChannel.invokeMethod<void>('setSoftInputAdjustNothing');
    } catch (_) {}
  }

  Future<void> _setSoftInputAdjustResize() async {
    try {
      await _windowChannel.invokeMethod<void>('setSoftInputAdjustResize');
    } catch (_) {}
  }

  void _scheduleInitialSearchFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      await _waitForRouteTransitionToComplete();
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) {
        return;
      }
      final route = ModalRoute.of(context);
      if (route?.isCurrent == false) {
        return;
      }
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _waitForRouteTransitionToComplete() async {
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      return;
    }

    final completer = Completer<void>();
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status == AnimationStatus.completed && !completer.isCompleted) {
        animation.removeStatusListener(listener);
        completer.complete();
      }
    };
    animation.addStatusListener(listener);
    await completer.future;
  }

  Future<bool> _dismissKeyboard({
    bool waitForAnimation = false,
    int requiredSettledFrames = 3,
  }) async {
    final hadKeyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    if (waitForAnimation && hadKeyboard) {
      var settledFrames = 0;
      for (var attempt = 0; attempt < 24; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        if (!mounted) {
          break;
        }
        final bottomInset =
            View.of(context).viewInsets.bottom /
            View.of(context).devicePixelRatio;
        if (bottomInset <= 1) {
          settledFrames += 1;
          if (settledFrames >= requiredSettledFrames) {
            break;
          }
          continue;
        }
        settledFrames = 0;
      }
      await WidgetsBinding.instance.endOfFrame;
    }
    return hadKeyboard;
  }

  void _primeDeferredInteraction() {
    _pendingKeyboardDismissRequest ??= _dismissKeyboard(
      waitForAnimation: false,
    );
  }

  Future<void> _awaitDeferredInteraction({
    required int requiredSettledFrames,
    required Duration extraDelay,
  }) async {
    final pending = _pendingKeyboardDismissRequest;
    _pendingKeyboardDismissRequest = null;
    final hadKeyboard = pending != null
        ? await pending
        : await _dismissKeyboard(waitForAnimation: false);
    if (!hadKeyboard) {
      return;
    }
    await _dismissKeyboard(
      waitForAnimation: true,
      requiredSettledFrames: requiredSettledFrames,
    );
    if (extraDelay > Duration.zero) {
      await Future<void>.delayed(extraDelay);
    }
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _awaitSheetInteraction() {
    return _awaitDeferredInteraction(
      requiredSettledFrames: 3,
      extraDelay: const Duration(milliseconds: 56),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);
    final query = _query.trim();
    final hasActiveFilters = _hasActiveFilters(store);
    final matchedEntries = query.isEmpty && !hasActiveFilters
        ? const <LedgerEntry>[]
        : store.entries.where((entry) {
            return _matchesAdvancedFilters(entry, store) &&
                (query.isEmpty || _matchesSearch(entry, query));
          }).toList();
    final groupedEntries = groupLedgerEntriesByDate(matchedEntries);
    final emptyState = query.isEmpty && !hasActiveFilters
        ? const _LedgerSearchEmptyState(
            icon: Icons.search,
            message: '输入金额或备注，也可使用高级筛选查询流水',
          )
        : matchedEntries.isEmpty
        ? const _LedgerSearchEmptyState(
            icon: Icons.receipt_long_outlined,
            title: '没有找到匹配的流水',
            message: '试试换个金额片段或备注关键词',
          )
        : null;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF8FAF6),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/Application/bg.jpg', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1453615D),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: (value) =>
                                setState(() => _query = value),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: '搜索金额或备注',
                              hintStyle: const TextStyle(
                                color: Color(0xFF9AA6A1),
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _query = '');
                                        _searchFocusNode.requestFocus();
                                      },
                                      icon: const Icon(Icons.close),
                                    ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (_) => _primeDeferredInteraction(),
                        child: TextButton.icon(
                          onPressed: () => _openAdvancedFilterSheet(store),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            minimumSize: const Size(92, 44),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            foregroundColor: const Color(0xFF167C80),
                          ),
                          icon: const Icon(Icons.tune, size: 18),
                          label: Text(hasActiveFilters ? '调整筛选' : '高级筛选'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: hasActiveFilters
                            ? SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                reverse: true,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: _filterChips(store).map((label) {
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: _FilterSummaryChip(
                                        label: label,
                                        onTapDown: _primeDeferredInteraction,
                                        onTap: () =>
                                            _openAdvancedFilterSheet(store),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: matchedEntries.isNotEmpty
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.0),
                          ),
                          child: ListView(
                            padding: const EdgeInsets.only(top: 0, bottom: 24),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  14,
                                ),
                                child: _SearchResultsOverviewCard(
                                  entries: matchedEntries,
                                  onViewStats: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FilteredStatisticsPage(
                                          entries: matchedEntries,
                                          filterSummary: _filterChips(store),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              ...buildLedgerEntryGroupSections(
                                context,
                                store: store,
                                groupedEntries: groupedEntries,
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.expand(),
                ),
              ],
            ),
          ),
          if (emptyState != null)
            Positioned.fill(
              child: IgnorePointer(
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: emptyState,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _matchesSearch(LedgerEntry entry, String rawQuery) {
    final query = _normalizeLedgerSearchText(rawQuery);
    if (query.isEmpty) {
      return false;
    }
    final note = _normalizeLedgerSearchText(entry.note);
    final amountText = _normalizeLedgerSearchText(
      formatMoney(entry.amountInCents).replaceFirst('-', ''),
    );
    final plainAmount = _normalizeLedgerSearchText(
      (entry.amountInCents.abs() / 100).toStringAsFixed(2),
    );
    final trimmedPlainAmount = _normalizeLedgerSearchText(
      _trimTrailingZeros((entry.amountInCents.abs() / 100).toStringAsFixed(2)),
    );
    return note.contains(query) ||
        amountText.contains(query) ||
        plainAmount.contains(query) ||
        trimmedPlainAmount.contains(query);
  }

  String _trimTrailingZeros(String value) {
    if (!value.contains('.')) {
      return value;
    }
    return value.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  bool _matchesAdvancedFilters(LedgerEntry entry, LedgerStore store) {
    if (!_selectedTypes.contains(entry.type)) {
      return false;
    }
    if (!_matchesTimeFilter(entry.occurredAt)) {
      return false;
    }
    final selectedCategoryKeys = _selectedCategoryKeys;
    if (selectedCategoryKeys != null &&
        entry.type != LedgerEntryType.transfer &&
        !selectedCategoryKeys.contains(_categoryKeyForEntry(entry))) {
      return false;
    }
    final selectedAccountIds = _selectedAccountIds;
    if (selectedAccountIds != null) {
      final ids = [
        if (entry.fromAccountId != null) entry.fromAccountId!,
        if (entry.toAccountId != null) entry.toAccountId!,
      ];
      if (ids.isNotEmpty && ids.any((id) => !selectedAccountIds.contains(id))) {
        return false;
      }
    }
    return true;
  }

  bool _matchesTimeFilter(DateTime value) {
    final now = DateTime.now();
    return switch (_timeFilter) {
      _LedgerSearchTimeFilter.all => true,
      _LedgerSearchTimeFilter.month =>
        value.year == now.year && value.month == now.month,
      _LedgerSearchTimeFilter.year => value.year == now.year,
      _LedgerSearchTimeFilter.custom => _isInCustomDateRange(value),
    };
  }

  bool _isInCustomDateRange(DateTime value) {
    final start = _customStartDate;
    final end = _customEndDate;
    if (start != null &&
        value.isBefore(DateTime(start.year, start.month, start.day))) {
      return false;
    }
    if (end != null) {
      final exclusiveEnd = DateTime(end.year, end.month, end.day + 1);
      if (!value.isBefore(exclusiveEnd)) {
        return false;
      }
    }
    return true;
  }

  bool _hasActiveFilters(LedgerStore store) {
    return _selectedTypes.length != LedgerEntryType.values.length ||
        _timeFilter != _LedgerSearchTimeFilter.all ||
        _selectedCategoryKeys != null ||
        _selectedAccountIds != null;
  }

  List<String> _filterChips(LedgerStore store) {
    final parts = <String>[];
    if (_selectedTypes.length != LedgerEntryType.values.length) {
      parts.add(_selectedTypes.map((type) => type.label).join('、'));
    }
    if (_timeFilter != _LedgerSearchTimeFilter.all) {
      parts.add(switch (_timeFilter) {
        _LedgerSearchTimeFilter.month => '本月',
        _LedgerSearchTimeFilter.year => '本年',
        _LedgerSearchTimeFilter.custom => _customDateRangeLabel(),
        _LedgerSearchTimeFilter.all => '全部时间',
      });
    }
    if (_selectedCategoryKeys != null) {
      final hiddenCount =
          _allCategoryKeys(store).length - _selectedCategoryKeys!.length;
      parts.add('排除$hiddenCount个分类');
    }
    if (_selectedAccountIds != null) {
      final hiddenCount = store.accounts.length - _selectedAccountIds!.length;
      parts.add('排除$hiddenCount个账户');
    }
    return parts;
  }

  String _customDateRangeLabel() {
    final start = _customStartDate;
    final end = _customEndDate;
    if (start == null && end == null) {
      return '自定义时间';
    }
    final startText = start == null ? '开始' : formatDateOnly(start);
    final endText = end == null ? '结束' : formatDateOnly(end);
    return '$startText-$endText';
  }

  Future<void> _openAdvancedFilterSheet(LedgerStore store) async {
    _primeDeferredInteraction();
    await _awaitSheetInteraction();
    if (!mounted) return;
    await _showAdvancedFilterSheet(store);
  }

  Future<void> _showAdvancedFilterSheet(LedgerStore store) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var draftTypes = Set<LedgerEntryType>.of(_selectedTypes);
        var draftTimeFilter = _timeFilter;
        var draftStartDate = _customStartDate;
        var draftEndDate = _customEndDate;
        var draftCategoryKeys = Set<String>.of(
          _selectedCategoryKeys ?? _allCategoryKeys(store),
        );
        var draftAccountIds = Set<String>.of(
          _selectedAccountIds ?? store.accounts.map((account) => account.id),
        );

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickCustomDate({required bool isStart}) async {
              final initialDate = isStart
                  ? draftStartDate ?? DateTime.now()
                  : draftEndDate ?? draftStartDate ?? DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked == null) return;
              setModalState(() {
                if (isStart) {
                  draftStartDate = picked;
                  if (draftEndDate != null && draftEndDate!.isBefore(picked)) {
                    draftEndDate = picked;
                  }
                } else {
                  draftEndDate = picked;
                  if (draftStartDate != null &&
                      draftStartDate!.isAfter(picked)) {
                    draftStartDate = picked;
                  }
                }
              });
            }

            void resetDraft() {
              setModalState(() {
                draftTypes = Set.of(LedgerEntryType.values);
                draftTimeFilter = _LedgerSearchTimeFilter.all;
                draftStartDate = null;
                draftEndDate = null;
                draftCategoryKeys = _allCategoryKeys(store);
                draftAccountIds = store.accounts
                    .map((account) => account.id)
                    .toSet();
              });
            }

            void applyDraft() {
              setState(() {
                _selectedTypes = draftTypes;
                _timeFilter = draftTimeFilter;
                _customStartDate = draftStartDate;
                _customEndDate = draftEndDate;
                final allCategoryKeys = _allCategoryKeys(store);
                _selectedCategoryKeys =
                    draftCategoryKeys.length == allCategoryKeys.length
                    ? null
                    : draftCategoryKeys;
                _selectedAccountIds =
                    draftAccountIds.length == store.accounts.length
                    ? null
                    : draftAccountIds;
              });
              Navigator.of(sheetContext).pop();
            }

            return Container(
              height: MediaQuery.sizeOf(context).height * 0.84,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAF6),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '高级筛选',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        children: [
                          _FilterBlock(
                            title: '流水类型',
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: LedgerEntryType.values.map((type) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _FilterPill(
                                    label: Text(type.label),
                                    selected: draftTypes.contains(type),
                                    onTap: () {
                                      setModalState(() {
                                        if (draftTypes.contains(type)) {
                                          draftTypes.remove(type);
                                        } else {
                                          draftTypes.add(type);
                                        }
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          _FilterBlock(
                            title: '时间',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: _LedgerSearchTimeFilter.values.map((
                                    filter,
                                  ) {
                                    final isLast =
                                        filter ==
                                        _LedgerSearchTimeFilter.values.last;
                                    return Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          right: isLast ? 0 : 8,
                                        ),
                                        child: _FilterPill(
                                          label: Text(filter.label),
                                          selected: draftTimeFilter == filter,
                                          compact: true,
                                          onTap: () => setModalState(() {
                                            draftTimeFilter = filter;
                                          }),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (draftTimeFilter ==
                                    _LedgerSearchTimeFilter.custom) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _DateRangeButton(
                                          label: '开始日期',
                                          value: draftStartDate,
                                          onTap: () =>
                                              pickCustomDate(isStart: true),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _DateRangeButton(
                                          label: '结束日期',
                                          value: draftEndDate,
                                          onTap: () =>
                                              pickCustomDate(isStart: false),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _FilterBlock(
                            title: '分类',
                            trailing: _FilterBlockActionButton(
                              label:
                                  draftCategoryKeys.length ==
                                      _allCategoryKeys(store).length
                                  ? '取消全选'
                                  : '全选',
                              onTap: () => setModalState(() {
                                if (draftCategoryKeys.length ==
                                    _allCategoryKeys(store).length) {
                                  draftCategoryKeys.clear();
                                } else {
                                  draftCategoryKeys
                                    ..clear()
                                    ..addAll(_allCategoryKeys(store));
                                }
                              }),
                            ),
                            child: _CategoryFilterList(
                              store: store,
                              selectedKeys: draftCategoryKeys,
                              onChanged: (key, selected) {
                                setModalState(() {
                                  if (selected) {
                                    draftCategoryKeys.add(key);
                                  } else {
                                    draftCategoryKeys.remove(key);
                                  }
                                });
                              },
                            ),
                          ),
                          _FilterBlock(
                            title: '账户',
                            trailing: store.accounts.isEmpty
                                ? null
                                : _FilterBlockActionButton(
                                    label:
                                        draftAccountIds.length ==
                                            store.accounts.length
                                        ? '取消全选'
                                        : '全选',
                                    onTap: () => setModalState(() {
                                      if (draftAccountIds.length ==
                                          store.accounts.length) {
                                        draftAccountIds.clear();
                                      } else {
                                        draftAccountIds
                                          ..clear()
                                          ..addAll(
                                            store.accounts.map(
                                              (account) => account.id,
                                            ),
                                          );
                                      }
                                    }),
                                  ),
                            child: _AccountFilterGroup(
                              accounts: store.accounts,
                              selectedAccountIds: draftAccountIds,
                              onChanged: (accountId, selected) {
                                setModalState(() {
                                  if (selected) {
                                    draftAccountIds.add(accountId);
                                  } else {
                                    draftAccountIds.remove(accountId);
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: resetDraft,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFB6C4BE),
                                ),
                              ),
                              child: const Text('重置'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: applyDraft,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              child: const Text('查看结果'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FilterSummaryChip extends StatelessWidget {
  const _FilterSummaryChip({required this.label, this.onTap, this.onTapDown});

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onTapDown;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2EF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33069B9B)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF167C80),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (onTap == null) {
      return content;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTapDown: onTapDown == null ? null : (_) => onTapDown!(),
      onTap: onTap,
      child: content,
    );
  }
}

class _FilterBlockActionButton extends StatelessWidget {
  const _FilterBlockActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.centerRight,
        foregroundColor: const Color(0xFF167C80),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      child: Text(label, textAlign: TextAlign.right),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '共$count笔',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF65736F),
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final Widget label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 16,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE0F2EF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF069B9B) : const Color(0xFFE1E8E4),
          ),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: selected ? const Color(0xFF167C80) : const Color(0xFF65736F),
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          child: Center(child: label),
        ),
      ),
    );
  }
}

class _AccountFilterRow extends StatelessWidget {
  const _AccountFilterRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.accountOption,
  });

  final String title;
  final bool? value;
  final AccountIconOption? accountOption;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 24),
            if (accountOption != null)
              AccountIconBadge(option: accountOption!, size: 34)
            else
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2EF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF167C80),
                  size: 18,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF33413D),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableFilterTile extends StatefulWidget {
  const _ExpandableFilterTile({
    required this.icon,
    required this.title,
    required this.countText,
    required this.children,
    this.trailing,
    this.initiallyExpanded = false,
    this.childrenIndent = 52,
  });

  final Widget icon;
  final String title;
  final String countText;
  final Widget? trailing;
  final List<Widget> children;
  final bool initiallyExpanded;
  final double childrenIndent;

  @override
  State<_ExpandableFilterTile> createState() => _ExpandableFilterTileState();
}

class _ExpandableFilterTileState extends State<_ExpandableFilterTile> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: Color(0xFF65736F),
                  ),
                ),
                const SizedBox(width: 2),
                widget.icon,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF33413D),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  widget.countText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8B9A94),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: EdgeInsets.only(
                    left: widget.childrenIndent,
                    bottom: 6,
                  ),
                  child: Column(children: widget.children),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _AccountFilterGroup extends StatelessWidget {
  const _AccountFilterGroup({
    required this.accounts,
    required this.selectedAccountIds,
    required this.onChanged,
  });

  final List<Account> accounts;
  final Set<String> selectedAccountIds;
  final void Function(String accountId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedAccountIds.length;

    return _ExpandableFilterTile(
      initiallyExpanded: false,
      childrenIndent: 0,
      icon: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2EF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.account_balance_wallet_rounded,
          color: Color(0xFF167C80),
          size: 18,
        ),
      ),
      title: '全部账户',
      countText: '$selectedCount/${accounts.length}',
      children: accounts.map((account) {
        return _AccountFilterRow(
          title: account.name,
          value: selectedAccountIds.contains(account.id),
          accountOption: accountIconOption(account.iconKey),
          onChanged: (selected) {
            onChanged(account.id, selected == true);
          },
        );
      }).toList(),
    );
  }
}

enum _LedgerSearchTimeFilter {
  all('全部'),
  month('本月'),
  year('本年'),
  custom('自定义');

  const _LedgerSearchTimeFilter(this.label);

  final String label;
}

class _FilterBlock extends StatelessWidget {
  const _FilterBlock({required this.title, this.child, this.trailing});

  final String title;
  final Widget? child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F53615D),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF16211F),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (child != null) ...[const SizedBox(height: 12), child!],
        ],
      ),
    );
  }
}

class _DateRangeButton extends StatelessWidget {
  const _DateRangeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        foregroundColor: const Color(0xFF33413D),
        side: const BorderSide(color: Color(0xFFE1E8E4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value == null ? '未选择' : formatDateOnly(value!),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterList extends StatelessWidget {
  const _CategoryFilterList({
    required this.store,
    required this.selectedKeys,
    required this.onChanged,
  });

  final LedgerStore store;
  final Set<String> selectedKeys;
  final void Function(String key, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CategoryTypeFilterGroup(
          title: '支出',
          icon: Icons.payments_rounded,
          groups: store.expenseCategoryGroups
              .map(
                (group) => _CategoryFilterGroup(
                  name: group.name,
                  iconKey: group.children.isEmpty
                      ? ''
                      : group.children.first.iconKey,
                  color: categoryGroupColor(group.name),
                  children: group.children
                      .map(
                        (item) => _CategoryFilterOption(
                          keyValue: _categoryKey(
                            LedgerEntryType.expense,
                            item.name,
                          ),
                          name: item.name,
                          iconKey: item.iconKey,
                          color: categoryGroupColor(group.name),
                        ),
                      )
                      .toList(),
                ),
              )
              .toList(),
          selectedKeys: selectedKeys,
          onChanged: onChanged,
        ),
        const Divider(height: 22, color: Color(0xFFE6ECE9)),
        _CategoryTypeFilterGroup(
          title: '收入',
          icon: Icons.savings_rounded,
          groups: store.incomeCategoryGroups
              .map(
                (group) => _CategoryFilterGroup(
                  name: group.name,
                  iconKey: group.children.isEmpty
                      ? ''
                      : group.children.first.iconKey,
                  color: categoryGroupColor(group.name),
                  children: group.children
                      .map(
                        (item) => _CategoryFilterOption(
                          keyValue: _categoryKey(
                            LedgerEntryType.income,
                            item.name,
                          ),
                          name: item.name,
                          iconKey: item.iconKey,
                          color: categoryGroupColor(group.name),
                        ),
                      )
                      .toList(),
                ),
              )
              .toList(),
          selectedKeys: selectedKeys,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _CategoryTypeFilterGroup extends StatelessWidget {
  const _CategoryTypeFilterGroup({
    required this.title,
    required this.icon,
    required this.groups,
    required this.selectedKeys,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final List<_CategoryFilterGroup> groups;
  final Set<String> selectedKeys;
  final void Function(String key, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final totalCount = groups.fold<int>(
      0,
      (sum, group) => sum + group.children.length,
    );
    final selectedCount = groups.fold<int>(
      0,
      (sum, group) =>
          sum +
          group.children
              .where((item) => selectedKeys.contains(item.keyValue))
              .length,
    );
    return _ExpandableFilterTile(
      initiallyExpanded: false,
      childrenIndent: 0,
      icon: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2EF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF167C80)),
      ),
      title: title,
      countText: '$selectedCount/$totalCount',
      children: groups.map((group) {
        final groupSelectedCount = group.children
            .where((item) => selectedKeys.contains(item.keyValue))
            .length;
        final groupValue = groupSelectedCount == 0
            ? false
            : groupSelectedCount == group.children.length
            ? true
            : null;
        void toggleGroup() {
          final shouldSelect = groupValue != true;
          for (final item in group.children) {
            onChanged(item.keyValue, shouldSelect);
          }
        }

        return _CategoryMajorFilterTile(
          group: group,
          selectedCount: groupSelectedCount,
          groupValue: groupValue,
          selectedKeys: selectedKeys,
          onToggleGroup: toggleGroup,
          onChanged: onChanged,
        );
      }).toList(),
    );
  }
}

class _CategoryMajorFilterTile extends StatelessWidget {
  const _CategoryMajorFilterTile({
    required this.group,
    required this.selectedCount,
    required this.groupValue,
    required this.selectedKeys,
    required this.onToggleGroup,
    required this.onChanged,
  });

  final _CategoryFilterGroup group;
  final int selectedCount;
  final bool? groupValue;
  final Set<String> selectedKeys;
  final VoidCallback onToggleGroup;
  final void Function(String key, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return _ExpandableFilterTile(
      childrenIndent: 0,
      icon: IconBadge(
        icon: categoryIcon(group.iconKey),
        color: group.color,
        size: 30,
      ),
      title: group.name,
      countText: '$selectedCount/${group.children.length}',
      trailing: Checkbox(
        value: groupValue,
        tristate: true,
        onChanged: (_) => onToggleGroup(),
      ),
      children: group.children.map((item) {
        final isSelected = selectedKeys.contains(item.keyValue);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 20),
                IconBadge(
                  icon: categoryIcon(item.iconKey),
                  color: item.color,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF33413D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Checkbox(
                  value: isSelected,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (selected) {
                    onChanged(item.keyValue, selected == true);
                  },
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CategoryFilterGroup {
  const _CategoryFilterGroup({
    required this.name,
    required this.iconKey,
    required this.color,
    required this.children,
  });

  final String name;
  final String iconKey;
  final Color color;
  final List<_CategoryFilterOption> children;
}

class _CategoryFilterOption {
  const _CategoryFilterOption({
    required this.keyValue,
    required this.name,
    required this.iconKey,
    required this.color,
  });

  final String keyValue;
  final String name;
  final String iconKey;
  final Color color;
}

Set<String> _allCategoryKeys(LedgerStore store) {
  return {
    for (final group in store.expenseCategoryGroups)
      for (final item in group.children)
        _categoryKey(LedgerEntryType.expense, item.name),
    for (final group in store.incomeCategoryGroups)
      for (final item in group.children)
        _categoryKey(LedgerEntryType.income, item.name),
  };
}

String _categoryKeyForEntry(LedgerEntry entry) {
  return switch (entry.type) {
    LedgerEntryType.expense => _categoryKey(
      LedgerEntryType.expense,
      expenseCategoryLabel(entry),
    ),
    LedgerEntryType.income => _categoryKey(
      LedgerEntryType.income,
      incomeCategoryLabel(entry),
    ),
    LedgerEntryType.transfer => _categoryKey(LedgerEntryType.transfer, '转账'),
  };
}

String _categoryKey(LedgerEntryType type, String categoryName) {
  return '${type.name}::$categoryName';
}

class _LedgerSearchEmptyState extends StatelessWidget {
  const _LedgerSearchEmptyState({
    required this.icon,
    required this.message,
    this.title,
  });

  final IconData icon;
  final String? title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: const Color(0xFF8B9A94)),
          if (title != null) ...[
            const SizedBox(height: 14),
            Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF16211F),
              ),
            ),
            const SizedBox(height: 6),
          ] else
            const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF65736F)),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsOverviewCard extends StatelessWidget {
  const _SearchResultsOverviewCard({
    required this.entries,
    required this.onViewStats,
  });

  final List<LedgerEntry> entries;
  final VoidCallback onViewStats;

  @override
  Widget build(BuildContext context) {
    final totals = StatsTotals.fromEntries(entries);
    final netColor = totals.net >= 0
        ? const Color(0xFF167C80)
        : const Color(0xFFE2554F);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EAE6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F53615D),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                Text(
                  '筛选结果',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF16211F),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const Spacer(),
                _CountBadge(totals.entries),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: Row(
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
          ),
          const Padding(
            padding: EdgeInsets.only(left: 14),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFE6ECE9)),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onViewStats,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 15,
                ),
                child: Row(
                  children: [
                    Text(
                      '查看统计',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF2F3A37),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: Color(0xFF2F3A37),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FilteredStatisticsPage extends StatefulWidget {
  const FilteredStatisticsPage({
    required this.entries,
    required this.filterSummary,
    super.key,
  });

  final List<LedgerEntry> entries;
  final List<String> filterSummary;

  @override
  State<FilteredStatisticsPage> createState() => _FilteredStatisticsPageState();
}

class _FilteredStatisticsPageState extends State<FilteredStatisticsPage> {
  bool _groupByMajor = false;
  late LedgerEntryType _selectedType;

  @override
  void initState() {
    super.initState();
    final totals = StatsTotals.fromEntries(widget.entries);
    _selectedType = totals.expense >= totals.income
        ? LedgerEntryType.expense
        : LedgerEntryType.income;
  }

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);
    final entries = widget.entries;
    final totals = StatsTotals.fromEntries(entries);
    final expenseStats = _groupedStatsForEntries(
      entries,
      type: LedgerEntryType.expense,
      groupLabel: expenseGroupLabel,
      categoryLabel: expenseCategoryLabel,
    );
    final incomeStats = _groupedStatsForEntries(
      entries,
      type: LedgerEntryType.income,
      groupLabel: incomeGroupLabel,
      categoryLabel: incomeCategoryLabel,
    );
    final expenseLeafStats = _leafStatsForEntries(
      entries,
      type: LedgerEntryType.expense,
      categoryLabel: expenseCategoryLabel,
    );
    final incomeLeafStats = _leafStatsForEntries(
      entries,
      type: LedgerEntryType.income,
      categoryLabel: incomeCategoryLabel,
    );
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
        ? '这批流水里没有支出'
        : '这批流水里没有收入';
    final activeEmptySubtitle = _selectedType == LedgerEntryType.expense
        ? '可以切换收入，或返回调整筛选条件'
        : '可以切换支出，或返回调整筛选条件';

    return Scaffold(
      appBar: AppBar(title: const Text('筛选统计')),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/Application/bg.jpg', fit: BoxFit.cover),
          ),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _FilteredStatisticsSummaryCard(
                  totals: totals,
                  filterSummary: widget.filterSummary,
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
                  periodRestored: true,
                  childrenByGroup: activeChildren,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilteredStatisticsSummaryCard extends StatelessWidget {
  const _FilteredStatisticsSummaryCard({
    required this.totals,
    required this.filterSummary,
  });

  final StatsTotals totals;
  final List<String> filterSummary;

  @override
  Widget build(BuildContext context) {
    final netColor = totals.net >= 0
        ? const Color(0xFF167C80)
        : const Color(0xFFE2554F);
    final summaryLabels = filterSummary.isEmpty
        ? const ['全部流水']
        : filterSummary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      for (var i = 0; i < summaryLabels.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _FilterSummaryChip(label: summaryLabels[i]),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _CountBadge(totals.entries),
            ],
          ),
          const SizedBox(height: 20),
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
        ],
      ),
    );
  }
}

Map<String, GroupedCategoryStat> _groupedStatsForEntries(
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

Map<String, CategoryStat> _leafStatsForEntries(
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

Map<String, List<LedgerEntry>> groupLedgerEntriesByDate(
  List<LedgerEntry> entries,
) {
  final groups = <String, List<LedgerEntry>>{};
  for (final entry in entries) {
    final key = dateKey(entry.occurredAt);
    groups.putIfAbsent(key, () => <LedgerEntry>[]).add(entry);
  }
  return groups;
}

List<Widget> buildLedgerEntryGroupSections(
  BuildContext context, {
  required LedgerStore store,
  required Map<String, List<LedgerEntry>> groupedEntries,
  Widget Function(String dateKey, LedgerEntry firstEntry, Widget child)?
  groupWrapper,
}) {
  final contentChildren = <Widget>[];
  final sortedKeys = groupedEntries.keys.toList()
    ..sort((a, b) => b.compareTo(a));

  for (final key in sortedKeys) {
    final groupEntries = groupedEntries[key]!;
    final firstEntry = groupEntries.first;
    final section = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
    contentChildren.add(
      groupWrapper == null ? section : groupWrapper(key, firstEntry, section),
    );
  }

  return contentChildren;
}

String _normalizeLedgerSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll('¥', '')
      .replaceAll(',', '')
      .replaceAll(' ', '')
      .trim();
}

