import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:ledger_app/models/account.dart';
import 'package:ledger_app/models/enums.dart';
import 'package:ledger_app/services/ledger_text_parser.dart';
import 'package:ledger_app/store/ledger_store.dart';
import 'package:ledger_app/utils/helpers.dart';
import 'package:ledger_app/widgets/common_widgets.dart';
import 'package:ledger_app/widgets/voice_widgets.dart';
import 'package:ledger_app/pages/entry_form_page.dart';
import 'package:ledger_app/pages/search_page.dart';
import 'package:ledger_app/pages/settings_page.dart';
import 'package:ledger_app/pages/statistics_page.dart';
import 'package:ledger_app/pages/statistics_prefs.dart';
import 'package:ledger_app/pages/account_detail_page.dart';
import 'package:ledger_app/services/update_service.dart';
import 'package:ledger_app/pages/account_detail_page.dart';
import 'package:ledger_app/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  await StatisticsPagePrefs.load(); // 提前加载统计页设置
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
    _store = LedgerStore()
      ..load().then((_) {
        if (_store.isWebdavAutoSyncEnabled) {
          unawaited(_store.syncToWebdav());
        }
        // 数据加载完成后检查更新
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkForUpdate();
        });
      });
  }

  Future<void> _checkForUpdate() async {
    if (!mounted) return;
    final updateInfo = await UpdateService.checkForUpdate();
    if (updateInfo == null || !mounted) return;

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateDialog(updateInfo: updateInfo),
    );
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
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
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
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: _store.themeMode == 1
                  ? ThemeMode.light
                  : _store.themeMode == 2
                      ? ThemeMode.dark
                      : ThemeMode.system,
              home: const LedgerHome(),
            ),
          );
        },
      ),
    );
  }
}


class LedgerHome extends StatefulWidget {
  const LedgerHome({super.key});

  @override
  State<LedgerHome> createState() => _LedgerHomeState();
}

class _LedgerHomeState extends State<LedgerHome> with WidgetsBindingObserver {
  static const _lastHandledClipboardQuickAddKey =
      'last_handled_clipboard_quick_add';
  static const MethodChannel _shareImageChannel = MethodChannel(
    'ledger_app/share_image',
  );
  late final PageController _pageController;
  final VoiceRecordingController _homeVoiceRecorder =
      VoiceRecordingController();
  final GlobalKey _voiceFabKey = GlobalKey();
  int _index = 0;
  bool _isVoiceOverlayVisible = false;
  bool _isVoiceOverlayOpaque = false;
  bool _isVoiceChromeHidden = false;
  bool _isVoiceCanceling = false;
  bool _isVoiceStarting = false;
  bool _isHomeVoiceRecording = false;
  bool _cancelHomeVoiceAfterStart = false;
  bool _isImportingClipboardQuickAdd = false;
  Offset? _pendingHomeVoiceFinishPosition;
  String? _currentLedgerMonthKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _homeVoiceRecorder.init().catchError((_) {});
    _shareImageChannel.setMethodCallHandler(_handleShareImageCall);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeInitialSharedImage();
      _consumeClipboardQuickAdd();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareImageChannel.setMethodCallHandler(null);
    _pageController.dispose();
    _homeVoiceRecorder.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _consumeClipboardQuickAdd();
    }
  }

  Future<dynamic> _handleShareImageCall(MethodCall call) async {
    if (call.method != 'onSharedImage') {
      return null;
    }
    final path = call.arguments?.toString();
    if (path == null || path.isEmpty) {
      return null;
    }
    await _openSharedImageEntryForm(path);
    return null;
  }

  Future<void> _consumeInitialSharedImage() async {
    try {
      final path = await _shareImageChannel.invokeMethod<String?>(
        'getInitialSharedImage',
      );
      if (path == null || path.isEmpty) {
        return;
      }
      await _openSharedImageEntryForm(path);
    } catch (_) {}
  }

  Future<void> _consumeClipboardQuickAdd() async {
    if (_isImportingClipboardQuickAdd || !mounted) {
      return;
    }
    _isImportingClipboardQuickAdd = true;
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim();
      if (text == null || text.isEmpty) {
        return;
      }
      final draft = ExternalQuickAddDraft.fromClipboardText(text);
      if (draft == null) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final lastHandled = prefs.getString(_lastHandledClipboardQuickAddKey);
      if (lastHandled == text) {
        return;
      }
      await prefs.setString(_lastHandledClipboardQuickAddKey, text);
      await _openQuickAddEntryForm(draft);
    } catch (_) {
      // Ignore clipboard access failures to avoid disturbing normal launch flow.
    } finally {
      _isImportingClipboardQuickAdd = false;
    }
  }

  Future<void> _openSharedImageEntryForm(String path) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!mounted) {
        return;
      }
      final store = LedgerScope.of(context);
      if (!store.isLoading) {
        await showAddEntryForm(context, initialImagePath: path);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (mounted) {
      showSnack(context, '图片已收到，数据加载完成后请重试');
    }
  }

  Future<void> _openQuickAddEntryForm(ExternalQuickAddDraft draft) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!mounted) {
        return;
      }
      final store = LedgerScope.of(context);
      if (!store.isLoading) {
        await showAddEntryForm(context, initialQuickAddDraft: draft);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (mounted) {
      showSnack(context, '快捷记账请求已收到，数据加载完成后请重试');
    }
  }

  Future<bool> _ensureHomeVoiceReady(LedgerStore store) async {
    if (store.baiduApiKey == null || store.baiduSecretKey == null) {
      showSnack(context, '请先在设置中配置百度语音识别API');
      return false;
    }

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        showSnack(context, '需要麦克风权限才能使用语音输入');
      }
      return false;
    }

    try {
      await _homeVoiceRecorder.init();
      return true;
    } catch (e) {
      if (mounted) {
        showSnack(context, '初始化录音器失败: $e');
      }
      return false;
    }
  }

  Future<void> _startHomeVoiceRecording() async {
    if (_isVoiceStarting || _isHomeVoiceRecording || _index == 2) {
      return;
    }
    _showHomeVoiceOverlay();
    final store = LedgerScope.of(context);
    _isVoiceStarting = true;
    final ready = await _ensureHomeVoiceReady(store);
    _isVoiceStarting = false;
    if (!ready || !mounted) {
      await _hideHomeVoiceOverlay();
      return;
    }

    try {
      await _homeVoiceRecorder.start();
      if (!mounted) {
        return;
      }
      setState(() {
        _isHomeVoiceRecording = true;
        _isVoiceCanceling = false;
      });
      if (_cancelHomeVoiceAfterStart) {
        _cancelHomeVoiceAfterStart = false;
        _pendingHomeVoiceFinishPosition = null;
        await _homeVoiceRecorder.cancel();
        if (mounted) {
          setState(() => _isHomeVoiceRecording = false);
        }
        return;
      }
      final pendingPosition = _pendingHomeVoiceFinishPosition;
      if (pendingPosition != null) {
        _pendingHomeVoiceFinishPosition = null;
        await _finishHomeVoiceRecording(pendingPosition);
      }
    } catch (e) {
      if (mounted) {
        await _hideHomeVoiceOverlay();
        showSnack(context, '录音失败: $e');
      }
    }
  }

  void _showHomeVoiceOverlay() {
    if (_index == 2 || _isVoiceOverlayVisible) {
      return;
    }
    _cancelHomeVoiceAfterStart = false;
    _pendingHomeVoiceFinishPosition = null;
    setState(() {
      _isVoiceOverlayVisible = true;
      _isVoiceOverlayOpaque = false;
      _isVoiceChromeHidden = true;
      _isVoiceCanceling = false;
    });
    Future<void>.delayed(const Duration(milliseconds: 24), () {
      if (mounted && _isVoiceOverlayVisible) {
        setState(() => _isVoiceOverlayOpaque = true);
      }
    });
  }

  Future<void> _hideHomeVoiceOverlay() async {
    if (!_isVoiceOverlayVisible) {
      return;
    }
    if (mounted) {
      setState(() {
        _isVoiceOverlayOpaque = false;
        _isVoiceChromeHidden = false;
        _isVoiceCanceling = false;
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (mounted && !_isVoiceOverlayOpaque) {
      setState(() {
        _isVoiceOverlayVisible = false;
        _isHomeVoiceRecording = false;
      });
    }
  }

  void _handleHomeVoiceTap() {
    if (mounted) {
      showAddEntrySheet(context);
    }
  }

  void _handleHomeVoiceTapCancel() {}

  void _updateHomeVoiceCancelState(Offset globalPosition) {
    if (!_isVoiceOverlayVisible) {
      return;
    }
    final nextCanceling = !_isPointerInsideVoiceFab(globalPosition);
    if (nextCanceling != _isVoiceCanceling) {
      setState(() {
        _isVoiceCanceling = nextCanceling;
      });
    }
  }

  Future<void> _finishHomeVoiceRecording(Offset globalPosition) async {
    if (!_isVoiceOverlayVisible) {
      return;
    }
    final shouldCancel =
        _isVoiceCanceling || !_isPointerInsideVoiceFab(globalPosition);

    if (!_isHomeVoiceRecording) {
      _pendingHomeVoiceFinishPosition = globalPosition;
      if (shouldCancel) {
        _cancelHomeVoiceAfterStart = true;
        await _hideHomeVoiceOverlay();
      }
      return;
    }

    await _hideHomeVoiceOverlay();

    if (shouldCancel) {
      await _homeVoiceRecorder.cancel();
      return;
    }

    try {
      final path = await _homeVoiceRecorder.stop();
      if (path != null && mounted) {
        await showAddEntryForm(context, initialVoicePath: path);
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, '停止录音失败: $e');
      }
    }
  }

  Future<void> _cancelHomeVoiceRecording() async {
    await _hideHomeVoiceOverlay();
    await _homeVoiceRecorder.cancel();
  }

  bool _isPointerInsideVoiceFab(Offset globalPosition) {
    final context = _voiceFabKey.currentContext;
    if (context == null) {
      return true;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      return true;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final rect = topLeft & renderObject.size;
    return rect.inflate(12).contains(globalPosition);
  }

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);

    if (store.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final monthSummaries = calculateMonthSummaries(store.entries);

    final pages = [
      LedgerPage(
        onMonthChange: (monthKey) {
          if (_currentLedgerMonthKey != monthKey) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _currentLedgerMonthKey == monthKey) {
                return;
              }
              setState(() {
                _currentLedgerMonthKey = monthKey;
              });
            });
          }
        },
      ),
      const StatisticsPage(),
      const AccountsPage(),
    ];
    const titles = ['流水明细', '统计分析', '账户管理'];

    return Stack(
      children: [
        Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedOpacity(
              opacity: _isVoiceChromeHidden ? 0 : 1,
              duration: const Duration(milliseconds: 280),
              curve: _isVoiceChromeHidden
                  ? Curves.easeOutCubic
                  : Curves.easeInCubic,
              child: Text(titles[_index]),
            ),
            if (_index == 0 && _currentLedgerMonthKey != null)
              Builder(
                builder: (context) {
                  final summary = monthSummaries[_currentLedgerMonthKey!];
                  if (summary == null) return const SizedBox.shrink();
                  final monthParts = _currentLedgerMonthKey!.split('-');
                  final year = monthParts[0];
                  final month = monthParts[1];
                  return AnimatedOpacity(
                    opacity: _isVoiceChromeHidden ? 0 : 1,
                    duration: const Duration(milliseconds: 280),
                    curve: _isVoiceChromeHidden
                        ? Curves.easeOutCubic
                        : Curves.easeInCubic,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '$year年$month月  共${summary.totalEntries}笔  收入${formatMoney(summary.totalIncome)}  支出${formatMoney(summary.totalExpense)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.onBackgroundLight,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (_index == 0)
            AnimatedOpacity(
              opacity: _isVoiceChromeHidden ? 0 : 1,
              duration: const Duration(milliseconds: 280),
              curve: _isVoiceChromeHidden
                  ? Curves.easeOutCubic
                  : Curves.easeInCubic,
              child: IgnorePointer(
                ignoring: _isVoiceOverlayVisible,
                child: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const LedgerSearchPage(),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (_index == 2)
            AnimatedOpacity(
              opacity: _isVoiceChromeHidden ? 0 : 1,
              duration: const Duration(milliseconds: 280),
              curve: _isVoiceChromeHidden
                  ? Curves.easeOutCubic
                  : Curves.easeInCubic,
              child: IgnorePointer(
                ignoring: _isVoiceOverlayVisible,
                child: IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _showSettingsPage(context),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // 后备底色
          Positioned.fill(
            child: Container(color: context.appColors.background),
          ),
          // 背景图片（仅亮色模式显示）
          if (Theme.of(context).brightness == Brightness.light)
            Positioned.fill(
              child: Image.asset('assets/Application/bg.jpg', fit: BoxFit.cover),
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
                      opacity =
                          1.0 -
                          ((pageValue - index).abs() * 0.8).clamp(0.0, 1.0);
                    }
                    return Opacity(opacity: opacity, child: child);
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
          : HomeVoiceFab(
              key: _voiceFabKey,
              isRecording: _isVoiceOverlayVisible,
              isCanceling: _isVoiceCanceling,
              onTap: _handleHomeVoiceTap,
              onTapCancel: _handleHomeVoiceTapCancel,
              onLongPressStart: (_) => _startHomeVoiceRecording(),
              onLongPressMoveUpdate: (details) =>
                  _updateHomeVoiceCancelState(details.globalPosition),
              onLongPressEnd: (details) =>
                  _finishHomeVoiceRecording(details.globalPosition),
              onLongPressCancel: _cancelHomeVoiceRecording,
            ),
      bottomNavigationBar: AnimatedOpacity(
        opacity: _isVoiceChromeHidden ? 0 : 1,
        duration: const Duration(milliseconds: 280),
        curve: _isVoiceChromeHidden ? Curves.easeOutCubic : Curves.easeInCubic,
        child: IgnorePointer(
          ignoring: _isVoiceOverlayVisible,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                height: 60,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
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
                    icon: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SvgPicture.asset(
                        'assets/icons/liushui.svg',
                        width: 28,
                        height: 28,
                        colorFilter: ColorFilter.mode(
                          Theme.of(context).brightness == Brightness.dark
                              ? context.appColors.onBackgroundMid
                              : const Color(0xFF65736F),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    selectedIcon: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SvgPicture.asset(
                        'assets/icons/liushui.svg',
                        width: 28,
                        height: 28,
                        colorFilter: ColorFilter.mode(
                          context.appColors.primary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    label: '',
                  ),
                  NavigationDestination(
                    icon: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.bar_chart_outlined,
                        size: 28,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? context.appColors.onBackgroundMid
                            : const Color(0xFF65736F),
                      ),
                    ),
                    selectedIcon: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.bar_chart,
                        size: 28,
                        color: context.appColors.primary,
                      ),
                    ),
                    label: '',
                  ),
                  NavigationDestination(
                    icon: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 28,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? context.appColors.onBackgroundMid
                            : const Color(0xFF65736F),
                      ),
                    ),
                    selectedIcon: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 28,
                        color: context.appColors.primary,
                      ),
                    ),
                    label: '',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
      if (_isVoiceOverlayVisible)
        Positioned.fill(
          child: VoiceRecordingOverlay(
            isCanceling: _isVoiceCanceling,
            isVisible: _isVoiceOverlayOpaque,
          ),
        ),
      ],
    );
  }

  void _showSettingsPage(BuildContext context) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const SettingsPage()));
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.updateInfo});
  final UpdateInfo updateInfo;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    final releaseNotes = widget.updateInfo.body ?? '暂无更新说明';

    return AlertDialog(
      title: Text('发现新版本 v${widget.updateInfo.version}'),
      content: _isDownloading
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('正在下载...'),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text('${(_progress * 100).toInt()}%'),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '更新内容：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(releaseNotes),
                ],
              ),
            ),
      actions: _isDownloading
          ? null
          : [
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    await UpdateService.skipVersion(widget.updateInfo.version);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('稍后再说'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _download,
                  child: const Text('立即更新'),
                ),
              ),
            ],
    );
  }

  Future<void> _download() async {
    final url = widget.updateInfo.downloadUrl;
    if (url == null) {
      if (mounted) {
        showSnack(context, '未找到下载链接');
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0;
    });

    try {
      await UpdateService.downloadAndInstall(
        url,
        widget.updateInfo.version,
        (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        showSnack(context, '下载失败：$e');
      }
    }
  }
}

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  List<DailyBalance> _computeTotalAssetBalance(LedgerStore store) {
    final now = DateTime.now();
    final result = <DailyBalance>[];

    final entries = store.entries;
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 29));

    int totalChange = 0;
    for (final entry in entries) {
      final entryDay = DateTime(entry.occurredAt.year, entry.occurredAt.month, entry.occurredAt.day);
      if (!entryDay.isBefore(start)) {
        int change = 0;
        if (entry.toAccountId != null) change += entry.amountInCents;
        if (entry.fromAccountId != null) change -= entry.amountInCents;
        totalChange += change;
      }
    }

    int balance = store.totalBalanceInCents - totalChange;

    for (var i = 0; i < 30; i++) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 29 - i));
      final dayStart = DateTime(day.year, day.month, day.day);

      final dayEntries = entries.where((e) {
        final eDay = DateTime(e.occurredAt.year, e.occurredAt.month, e.occurredAt.day);
        return eDay == dayStart;
      }).toList();

      for (final entry in dayEntries) {
        if (entry.toAccountId != null) balance += entry.amountInCents;
        if (entry.fromAccountId != null) balance -= entry.amountInCents;
      }

      result.add(DailyBalance(date: dayStart, balance: balance));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);
    final chartData = _computeTotalAssetBalance(store);

    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SummaryPanel(
            title: '当前资产',
            amountInCents: store.totalBalanceInCents,
            showChart: true,
            chartData: chartData,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => showAccountSheet(context),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF167C80)
                  : null,
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : null,
            ),
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
      groups[type]!.sort(
        (a, b) => b.balanceInCents.compareTo(a.balanceInCents),
      );
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appColors.onBackgroundMid,
              ),
            ),
          ),
        );
        widgets.addAll(
          groupAccounts.map((account) => AccountTile(account: account)),
        );
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
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AccountDetailPage(account: account),
          ),
        );
      },
      child: Card(
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
                    if (account.type == AccountType.creditCard &&
                        account.repaymentDay != null)
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
                    store.isAmountHidden
                        ? '****'
                        : formatMoney(account.balanceInCents),
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
      ),
    );
  }
}

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key, this.onMonthChange});

  final void Function(String monthKey)? onMonthChange;

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  String? _currentMonthKey;
  late ScrollController _scrollController;
  bool _hasNotifiedInitialMonth = false;
  final List<GlobalKey> _itemKeys = [];
  final List<String> _itemMonthKeys = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;

    // 查找第一个可见的条目
    for (int i = 0; i < _itemKeys.length; i++) {
      final key = _itemKeys[i];
      final context = key.currentContext;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          // 检查条目是否在可见区域顶部附近
          if (position.dy <= 100) {
            final monthKey = _itemMonthKeys[i];
            if (monthKey != _currentMonthKey) {
              setState(() {
                _currentMonthKey = monthKey;
              });
              if (widget.onMonthChange != null) {
                widget.onMonthChange!(monthKey);
              }
            }
            break;
          }
        }
      }
    }
  }

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

    // 重置keys列表
    _itemKeys.clear();
    _itemMonthKeys.clear();

    final groupedEntries = groupLedgerEntriesByDate(entries);
    final sortedKeys = groupedEntries.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    if (sortedKeys.isNotEmpty && !_hasNotifiedInitialMonth) {
      final firstKey = sortedKeys.first;
      final firstEntry = groupedEntries[firstKey]!.first;
      final initialMonthKey = monthKey(firstEntry.occurredAt);
      _currentMonthKey = initialMonthKey;
      _hasNotifiedInitialMonth = true;
      if (widget.onMonthChange != null) {
        widget.onMonthChange!(initialMonthKey);
      }
    }

    final contentChildren = buildLedgerEntryGroupSections(
      context,
      store: store,
      groupedEntries: groupedEntries,
      groupWrapper: (dateKey, firstEntry, child) {
        final entryMonthKey = monthKey(firstEntry.occurredAt);
        final itemKey = GlobalKey();
        _itemKeys.add(itemKey);
        _itemMonthKeys.add(entryMonthKey);
        return Container(key: itemKey, child: child);
      },
    );

    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 12, bottom: 112),
        children: contentChildren,
      ),
    );
  }
}

