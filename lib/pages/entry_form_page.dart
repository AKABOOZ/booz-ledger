import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:ledger_app/models/account.dart';
import 'package:ledger_app/models/category.dart';
import 'package:ledger_app/models/enums.dart';
import 'package:ledger_app/models/ledger_entry.dart';
import 'package:ledger_app/services/ledger_text_parser.dart';
import 'package:ledger_app/store/ledger_store.dart';
import 'package:ledger_app/utils/helpers.dart';
import 'package:ledger_app/widgets/common_widgets.dart';
import 'package:ledger_app/widgets/voice_widgets.dart';
import 'package:ledger_app/widgets/custom_keyboard.dart';
import 'package:ledger_app/theme/app_theme.dart';

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
                    color: context.appColors.onBackgroundMid,
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
                              ? context.appColors.surfaceDim
                              : context.appColors.surface,
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
  return showAddEntryForm(context);
}

Future<void> showAddEntryForm(
  BuildContext context, {
  String? initialVoicePath,
  String? initialImagePath,
  ExternalQuickAddDraft? initialQuickAddDraft,
}) {
  final store = LedgerScope.of(context);

  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => EntryFormPage(
        store: store,
        initialVoicePath: initialVoicePath,
        initialImagePath: initialImagePath,
        initialQuickAddDraft: initialQuickAddDraft,
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
    this.initialVoicePath,
    this.initialImagePath,
    this.initialQuickAddDraft,
    super.key,
  });

  final LedgerStore store;
  final LedgerEntry? entry;
  final String? initialVoicePath;
  final String? initialImagePath;
  final ExternalQuickAddDraft? initialQuickAddDraft;
  final ValueChanged<LedgerEntryType> onSaved;

  @override
  State<EntryFormPage> createState() => _EntryFormPageState();
}

class _EntryFormPageState extends State<EntryFormPage> {
  static const MethodChannel _nativeNoteEditorChannel = MethodChannel(
    'ledger_app/native_note_editor',
  );
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _noteDraftController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _noteFocusNode = FocusNode();
  final VoiceRecordingController _voiceRecorder = VoiceRecordingController();
  final GlobalKey _entryVoiceButtonKey = GlobalKey();
  bool _isRecording = false;
  bool _isVoiceOverlayVisible = false;
  bool _isVoiceOverlayOpaque = false;
  bool _isVoiceCanceling = false;
  bool _isVoiceStarting = false;
  bool _cancelEntryVoiceAfterStart = false;
  bool _isProcessing = false;
  bool _processingDone = false;
  bool _isRecorderInitialized = false;
  bool _isNoteEditorVisible = false;
  bool _hasOpenedNoteEditorOnce = false;
  bool _isCustomKeyboardVisible = false;
  bool _isCalculated = false;
  String _expression = '';
  String _expressionResult = '';
  Future<bool>? _pendingKeyboardDismissRequest;
  String _processingMessage = '正在识别并回填记账信息...';
  Offset? _pendingEntryVoiceFinishPosition;
  Rect? _voiceButtonRect;
  late LedgerEntryType _type;
  late DateTime _occurredAt;
  late String _expenseGroup;
  late String _expenseCategory;
  late String _incomeGroup;
  late String _incomeCategory;
  String? _expenseFromAccountId;
  String? _incomeToAccountId;
  String? _transferFromAccountId;
  String? _transferToAccountId;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    final expenseDefaults = widget.store.defaultsFor(LedgerEntryType.expense);
    final incomeDefaults = widget.store.defaultsFor(LedgerEntryType.income);
    final transferDefaults = widget.store.defaultsFor(LedgerEntryType.transfer);
    _type = entry?.type ?? LedgerEntryType.expense;
    _isCustomKeyboardVisible = entry == null; // 只有新增时自动弹出键盘
    _occurredAt = entry?.occurredAt ?? DateTime.now();
    _expenseCategory =
        entry?.expenseCategory ??
        (_type == LedgerEntryType.expense ? entry?.category : null) ??
        expenseDefaults.expenseCategory ??
        defaultExpenseCategoryGroups.first.children.first.name;
    _expenseGroup =
        entry?.expenseGroup ??
        widget.store.groupNameForExpenseCategory(_expenseCategory) ??
        expenseDefaults.expenseGroup ??
        defaultExpenseCategoryGroups.first.name;
    _incomeCategory =
        entry?.incomeCategory ??
        (_type == LedgerEntryType.income ? entry?.category : null) ??
        incomeDefaults.incomeCategory ??
        defaultIncomeCategoryGroups.first.children.first.name;
    _incomeGroup =
        entry?.incomeGroup ??
        widget.store.groupNameForIncomeCategory(_incomeCategory) ??
        incomeDefaults.incomeGroup ??
        defaultIncomeCategoryGroups.first.name;
    _expenseFromAccountId = entry?.type == LedgerEntryType.expense
        ? entry?.fromAccountId
        : expenseDefaults.fromAccountId;
    _incomeToAccountId = entry?.type == LedgerEntryType.income
        ? entry?.toAccountId
        : incomeDefaults.toAccountId;
    _transferFromAccountId = entry?.type == LedgerEntryType.transfer
        ? entry?.fromAccountId
        : transferDefaults.fromAccountId;
    _transferToAccountId = entry?.type == LedgerEntryType.transfer
        ? entry?.toAccountId
        : transferDefaults.toAccountId;
    _amountController.text = entry == null
        ? ''
        : moneyInputValue(entry.amountInCents);
    if (entry != null) {
      // 所见即所得：始终显示两位小数，_expression 和显示完全一致
      final amount = entry.amountInCents / 100;
      final displayText = amount.toStringAsFixed(2);
      _amountController.text = displayText;
      _expression = displayText;
    }
    _noteController.text = entry?.note ?? '';
    if (widget.initialVoicePath != null) {
      _isProcessing = true;
      _processingMessage = '正在识别语音并回填记账信息...';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processInitialVoiceRecording(widget.initialVoicePath!);
      });
    } else if (widget.initialImagePath != null) {
      _isProcessing = true;
      _processingMessage = '正在识别图片并回填记账信息...';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processInitialImage(widget.initialImagePath!);
      });
    } else if (widget.initialQuickAddDraft != null) {
      _applyParsedResult(
        widget.initialQuickAddDraft!.toParseResult(widget.store),
        notify: false,
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _noteDraftController.dispose();
    _amountFocusNode.dispose();
    _noteFocusNode.dispose();
    _voiceRecorder.dispose();
    super.dispose();
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

  void _collapseKeyboardForSubmit() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _openFlutterNoteEditor() {
    if (_isNoteEditorVisible) {
      _noteFocusNode.requestFocus();
      return;
    }
    _noteDraftController.text = _noteController.text;
    _noteDraftController.selection = TextSelection.fromPosition(
      TextPosition(offset: _noteDraftController.text.length),
    );
    setState(() {
      _isNoteEditorVisible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Future<void>.delayed(
        Duration(milliseconds: _hasOpenedNoteEditorOnce ? 0 : 90),
        () {
          if (!mounted || !_isNoteEditorVisible) {
            return;
          }
          _noteFocusNode.requestFocus();
          _hasOpenedNoteEditorOnce = true;
        },
      );
    });
  }

  Future<void> _openNoteEditor() async {
    if (Platform.isAndroid) {
      try {
        final result = await _nativeNoteEditorChannel.invokeMethod<String?>(
          'editNote',
          {'text': _noteController.text},
        );
        if (!mounted || result == null) {
          return;
        }
        setState(() {
          _noteController.text = result;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }
        _openFlutterNoteEditor();
      }
      return;
    }
    _openFlutterNoteEditor();
  }

  void _closeNoteEditor() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_isNoteEditorVisible) {
      return;
    }
    setState(() {
      _isNoteEditorVisible = false;
    });
  }

  void _saveAndCloseNoteEditor() {
    _noteController.text = _noteDraftController.text;
    _closeNoteEditor();
  }

  void _confirmNoteEditor() {
    _saveAndCloseNoteEditor();
  }

  Widget _buildNotePreview() {
    final note = _noteController.text.trim();
    return InkWell(
      onTap: _openNoteEditor,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.appColors.outline),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '备注',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appColors.onBackgroundMid,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.isEmpty ? '点击输入备注' : note,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: note.isEmpty
                          ? context.appColors.onBackgroundLight
                          : context.appColors.onBackground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildEntryImageButton(),
            const SizedBox(width: 10),
            _buildEntryVoiceButton(key: _entryVoiceButtonKey),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryImageButton() {
    return SizedBox(
      width: 56,
      height: 56,
      child: FilledButton(
        onPressed: _isProcessing ? null : _pickImageForOcr,
        style: FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          backgroundColor: context.appColors.surfaceDim,
          foregroundColor: context.appColors.primary,
          disabledBackgroundColor: context.appColors.surfaceAlt,
          disabledForegroundColor: context.appColors.onBackgroundLight,
          elevation: 0,
        ),
        child: const Icon(Icons.image_outlined, size: 25),
      ),
    );
  }

  Widget _buildNoteEditorPanelContent() {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextFormField(
            controller: _noteDraftController,
            focusNode: _noteFocusNode,
            decoration: const InputDecoration(
              labelText: '备注',
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            minLines: 5,
          ),
        ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '编辑备注',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        row,
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _closeNoteEditor,
                style: FilledButton.styleFrom(
                  backgroundColor: context.appColors.surface,
                  foregroundColor: context.appColors.onBackground,
                ),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _confirmNoteEditor,
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoteEditorPanelScaffold({required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      decoration: BoxDecoration(
        color: context.appColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(top: false, bottom: false, child: child),
    );
  }

  Widget _buildNoteEditorSheet() {
    final visible = _isNoteEditorVisible && !_isVoiceOverlayVisible;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          opacity: visible ? 1 : 0,
          child: Material(
            color: Colors.black.withValues(alpha: 0.5),
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _saveAndCloseNoteEditor,
                    behavior: HitTestBehavior.opaque,
                  ),
                ),
                Builder(
                  builder: (context) {
                    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: visible ? keyboardInset : 0,
                      child: RepaintBoundary(
                        child: _buildNoteEditorPanelScaffold(
                          child: _buildNoteEditorPanelContent(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    setState(() => _isCustomKeyboardVisible = false);
    return _awaitDeferredInteraction(
      requiredSettledFrames: 3,
      extraDelay: const Duration(milliseconds: 56),
    );
  }

  Future<void> _awaitSegmentedSwitchInteraction() {
    return _awaitDeferredInteraction(
      requiredSettledFrames: 2,
      extraDelay: const Duration(milliseconds: 12),
    );
  }

  Future<void> _switchEntryTypeBySwipe(int delta) async {
    final currentIndex = LedgerEntryType.values.indexOf(_type);
    final nextIndex = currentIndex + delta;
    if (nextIndex < 0 || nextIndex >= LedgerEntryType.values.length) {
      return;
    }
    await _awaitSegmentedSwitchInteraction();
    if (!mounted) {
      return;
    }
    setState(() => _type = LedgerEntryType.values[nextIndex]);
  }

  bool _ensureOcrReady() {
    if (widget.store.baiduApiKey == null ||
        widget.store.baiduSecretKey == null) {
      showSnack(context, '请先在设置中配置百度智能云API');
      return false;
    }
    return true;
  }

  Future<void> _pickImageForOcr() async {
    if (_isProcessing) {
      return;
    }
    if (!_ensureOcrReady()) {
      return;
    }
    await _awaitSheetInteraction();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );
      final file = result?.files.single;
      final path = file?.path;
      if (path == null || path.isEmpty) {
        return;
      }
      if (!mounted) {
        return;
      }
      await _processImage(path);
    } catch (e) {
      if (mounted) {
        showSnack(context, '选择图片失败：$e');
      }
    }
  }

  Future<bool> _ensureEntryVoiceReady() async {
    if (widget.store.baiduApiKey == null ||
        widget.store.baiduSecretKey == null) {
      showSnack(context, '请先在设置中配置百度语音识别API');
      return false;
    }

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      showSnack(context, '需要麦克风权限才能使用语音输入');
      return false;
    }

    try {
      if (!_isRecorderInitialized) {
        await _voiceRecorder.init();
        _isRecorderInitialized = true;
      }
      return true;
    } catch (e) {
      showSnack(context, '初始化录音器失败: $e');
      return false;
    }
  }

  Future<void> _startRecording() async {
    if (_isVoiceStarting || _isRecording || _isProcessing) {
      return;
    }
    _showEntryVoiceOverlay();
    _isVoiceStarting = true;
    final ready = await _ensureEntryVoiceReady();
    _isVoiceStarting = false;
    if (!ready || !mounted) {
      await _hideEntryVoiceOverlay();
      return;
    }

    try {
      await _voiceRecorder.start();
      if (mounted) {
        setState(() {
          _isRecording = true;
          _isVoiceCanceling = false;
          _voiceButtonRect = _currentEntryVoiceButtonRect();
        });
      }
      if (_cancelEntryVoiceAfterStart) {
        _cancelEntryVoiceAfterStart = false;
        _pendingEntryVoiceFinishPosition = null;
        await _voiceRecorder.cancel();
        if (mounted) {
          setState(() => _isRecording = false);
        }
        return;
      }
      final pendingPosition = _pendingEntryVoiceFinishPosition;
      if (pendingPosition != null) {
        _pendingEntryVoiceFinishPosition = null;
        await _finishRecording(pendingPosition);
      }
    } catch (e) {
      if (mounted) {
        await _hideEntryVoiceOverlay();
        showSnack(context, '录音失败: $e');
      }
    }
  }

  void _showEntryVoiceOverlay() {
    if (_isVoiceOverlayVisible || _isProcessing) {
      return;
    }
    _cancelEntryVoiceAfterStart = false;
    _pendingEntryVoiceFinishPosition = null;
    setState(() {
      _isVoiceOverlayVisible = true;
      _isVoiceOverlayOpaque = false;
      _isVoiceCanceling = false;
      _voiceButtonRect = _currentEntryVoiceButtonRect();
    });
    Future<void>.delayed(const Duration(milliseconds: 24), () {
      if (mounted && _isVoiceOverlayVisible) {
        setState(() => _isVoiceOverlayOpaque = true);
      }
    });
  }

  Future<void> _hideEntryVoiceOverlay() async {
    if (!_isVoiceOverlayVisible) {
      return;
    }
    if (mounted) {
      setState(() {
        _isVoiceOverlayOpaque = false;
        _isVoiceCanceling = false;
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (mounted && !_isVoiceOverlayOpaque) {
      setState(() {
        _isVoiceOverlayVisible = false;
        _isRecording = false;
      });
    }
  }

  void _handleEntryVoiceTap() {}

  void _handleEntryVoiceTapCancel() {}

  void _updateEntryVoiceCancelState(Offset globalPosition) {
    if (!_isVoiceOverlayVisible) return;
    final nextCanceling = !_isPointerInsideEntryVoiceButton(globalPosition);
    if (nextCanceling != _isVoiceCanceling) {
      setState(() {
        _isVoiceCanceling = nextCanceling;
      });
    }
  }

  Future<void> _finishRecording(Offset globalPosition) async {
    if (!_isVoiceOverlayVisible) return;
    final shouldCancel =
        _isVoiceCanceling || !_isPointerInsideEntryVoiceButton(globalPosition);

    if (!_isRecording) {
      _pendingEntryVoiceFinishPosition = globalPosition;
      if (shouldCancel) {
        _cancelEntryVoiceAfterStart = true;
        await _hideEntryVoiceOverlay();
      }
      return;
    }

    await _hideEntryVoiceOverlay();

    if (shouldCancel) {
      await _voiceRecorder.cancel();
      return;
    }

    try {
      final recordingPath = await _voiceRecorder.stop();
      if (recordingPath != null) {
        await _processRecording(recordingPath);
      }
    } catch (e) {
      showSnack(context, '停止录音失败: $e');
    }
  }

  Future<void> _cancelRecording() async {
    await _hideEntryVoiceOverlay();
    await _voiceRecorder.cancel();
  }

  Rect? _currentEntryVoiceButtonRect() {
    final context = _entryVoiceButtonKey.currentContext;
    if (context == null) {
      return null;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  bool _isPointerInsideEntryVoiceButton(Offset globalPosition) {
    final rect = _currentEntryVoiceButtonRect() ?? _voiceButtonRect;
    if (rect == null) {
      return true;
    }
    return rect.inflate(12).contains(globalPosition);
  }

  Widget _buildEntryVoiceButton({Key? key, bool interactive = true}) {
    final button = HomeVoiceFab(
      key: key,
      isRecording: _isVoiceOverlayVisible,
      isCanceling: _isVoiceCanceling,
      isProcessing: _isProcessing,
      normalIcon: Icons.mic_none,
      onTap: _handleEntryVoiceTap,
      onTapCancel: _handleEntryVoiceTapCancel,
      onLongPressStart: (_) => _startRecording(),
      onLongPressMoveUpdate: (details) =>
          _updateEntryVoiceCancelState(details.globalPosition),
      onLongPressEnd: (details) => _finishRecording(details.globalPosition),
      onLongPressCancel: _cancelRecording,
    );
    return interactive ? button : IgnorePointer(child: button);
  }

  Future<void> _processRecording(String path) async {
    try {
      if (mounted) {
        setState(() {
          _isProcessing = true;
          _processingDone = false;
          _processingMessage = '正在识别语音并回填记账信息...';
        });
      }
      final result = await VoiceInputRecognizer.recognizeFile(
        path,
        store: widget.store,
      );
      if (result != null && mounted) {
        _applyVoiceParseResult(result.parseResult);
        setState(() {
          _processingMessage = result.usedAi
              ? '已通过AI智能解析回填'
              : '已通过本地解析回填';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _processingDone = true;
          });
        }
      } else if (mounted) {
        showSnack(context, '语音识别失败，请重试');
        setState(() {
          _isProcessing = false;
          _processingDone = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, '识别失败：$e');
        setState(() {
          _isProcessing = false;
          _processingDone = false;
        });
      }
    }
  }

  Future<void> _processImage(
    String path, {
    bool deleteAfterRecognize = false,
  }) async {
    if (!_ensureOcrReady()) {
      return;
    }
    try {
      if (mounted) {
        setState(() {
          _isProcessing = true;
          _processingDone = false;
          _processingMessage = '正在识别图片并回填记账信息...';
        });
      }
      final parseResult = await ImageInputRecognizer.recognizeFile(
        path,
        store: widget.store,
        deleteAfterRecognize: deleteAfterRecognize,
      );
      if (parseResult != null && mounted) {
        _applyVoiceParseResult(parseResult.parseResult);
        setState(() {
          _processingMessage = parseResult.usedAi
              ? '已通过AI智能解析回填'
              : '已通过本地解析回填';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _processingDone = true;
          });
        }
      } else if (mounted) {
        showSnack(context, '图片识别失败，请换一张更清晰的截图');
        setState(() {
          _isProcessing = false;
          _processingDone = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, '图片识别失败：$e');
        setState(() {
          _isProcessing = false;
          _processingDone = false;
        });
      }
    }
  }

  Future<void> _processInitialVoiceRecording(String path) async {
    await _processRecording(path);
  }

  Future<void> _processInitialImage(String path) async {
    await _processImage(path, deleteAfterRecognize: true);
  }

  void _applyParsedResult(VoiceParseResult parseResult, {bool notify = true}) {
    void apply() {
      if (parseResult.type != null) {
        _type = parseResult.type!;
      }
      if (parseResult.amount != null) {
        _amountController.text = moneyInputValue(
          (parseResult.amount! * 100).round(),
        );
      }
      if (parseResult.occurredAt != null) {
        _occurredAt = parseResult.occurredAt!;
      }
      if (parseResult.note != null) {
        _noteController.text = parseResult.note!;
      }
      if (parseResult.expenseGroup != null &&
          parseResult.expenseCategory != null) {
        _expenseGroup = parseResult.expenseGroup!;
        _expenseCategory = parseResult.expenseCategory!;
      }
      if (parseResult.incomeGroup != null &&
          parseResult.incomeCategory != null) {
        _incomeGroup = parseResult.incomeGroup!;
        _incomeCategory = parseResult.incomeCategory!;
      }
      if (parseResult.fromAccountId != null) {
        if ((_type == LedgerEntryType.transfer &&
                parseResult.type == LedgerEntryType.transfer) ||
            parseResult.type == LedgerEntryType.transfer) {
          _transferFromAccountId = parseResult.fromAccountId;
        } else {
          _expenseFromAccountId = parseResult.fromAccountId;
        }
      }
      if (parseResult.toAccountId != null) {
        if ((_type == LedgerEntryType.transfer &&
                parseResult.type == LedgerEntryType.transfer) ||
            parseResult.type == LedgerEntryType.transfer) {
          _transferToAccountId = parseResult.toAccountId;
        } else {
          _incomeToAccountId = parseResult.toAccountId;
        }
      }
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _applyVoiceParseResult(VoiceParseResult parseResult) {
    _applyParsedResult(parseResult);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.store.accounts;
    _ensureValidAccountSelection(accounts);
    final bottomBarBottomPadding = math.max(
      MediaQuery.viewPaddingOf(context).bottom,
      16.0,
    );

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

    final voiceButtonRect = _voiceButtonRect;

    return Stack(
      children: [
        Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: Text(_isEditing ? '编辑流水' : '记一笔'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(52, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: const StadiumBorder(),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2B9E96)
                          : const Color(0xFF069B9B),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() < 220) {
                  return;
                }
                unawaited(_switchEntryTypeBySwipe(velocity < 0 ? 1 : -1));
              },
              child: Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 220),
                  children: [
                    if (_isProcessing || _processingDone) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: context.appColors.surfaceDim,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            if (_isProcessing) ...[
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ] else ...[
                              Icon(
                                Icons.check_circle,
                                color: context.appColors.primary,
                                size: 18,
                              ),
                            ],
                            const SizedBox(width: 12),
                            Text(_processingMessage),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (widget.initialQuickAddDraft != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E4),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '已从 ${widget.initialQuickAddDraft!.sourceLabel} 预填记账信息',
                          style: const TextStyle(color: Color(0xFF8C5A1D)),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    EntryTypeSwitch(
                      value: _type,
                      onTapDown: _primeDeferredInteraction,
                      onChanged: (value) async {
                        if (value == _type) {
                          return;
                        }
                        await _awaitSegmentedSwitchInteraction();
                        if (!mounted) {
                          return;
                        }
                        setState(() => _type = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    AmountInput(
                      controller: _amountController,
                      focusNode: _amountFocusNode,
                      expression: _expression,
                      isCalculated: _isCalculated,
                      onTap: () {
                        setState(() {
                          _isCustomKeyboardVisible = true;
                        });
                      },
                    ),
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
                        color: categoryGroupColor(_expenseGroup),
                        onTapDown: _primeDeferredInteraction,
                        onTap: () async {
                          await _awaitSheetInteraction();
                          if (!context.mounted) return;
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
                        color: categoryGroupColor(_incomeGroup),
                        onTapDown: _primeDeferredInteraction,
                        onTap: () async {
                          await _awaitSheetInteraction();
                          if (!context.mounted) return;
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
                        account: widget.store.accountById(
                          _currentFromAccountId,
                        ),
                        onTapDown: _primeDeferredInteraction,
                        onTap: () async {
                          await _awaitSheetInteraction();
                          if (!context.mounted) return;
                          final id = await showAccountPickerSheet(
                            context,
                            accounts,
                            selectedAccountId: _currentFromAccountId,
                            title: '选择转出账户',
                            recentAccounts: widget.store.recentAccounts(),
                          );
                          if (id != null && mounted) {
                            setState(() => _setCurrentFromAccountId(id));
                          }
                        },
                      ),
                    if (_type == LedgerEntryType.transfer)
                      const SizedBox(height: 12),
                    if (_type == LedgerEntryType.income ||
                        _type == LedgerEntryType.transfer)
                      AccountSelectCard(
                        label: '到哪个账户',
                        account: widget.store.accountById(_currentToAccountId),
                        onTapDown: _primeDeferredInteraction,
                        onTap: () async {
                          await _awaitSheetInteraction();
                          if (!context.mounted) return;
                          final id = await showAccountPickerSheet(
                            context,
                            accounts,
                            selectedAccountId: _currentToAccountId,
                            title: '选择转入账户',
                            recentAccounts: widget.store.recentAccounts(),
                          );
                          if (id != null && mounted) {
                            setState(() => _setCurrentToAccountId(id));
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
                      onTapDown: _primeDeferredInteraction,
                      onTap: () async {
                        await _awaitSheetInteraction();
                        if (!context.mounted) return;
                        await _pickDateTime();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildNotePreview(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: _isVoiceOverlayVisible,
            child: MediaQuery.removeViewInsets(
              removeBottom: true,
              context: context,
              child: RepaintBoundary(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    bottomBarBottomPadding,
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(color: context.appColors.background),
                    child: Row(
                      children: [
                        if (_isEditing) ...[
                          SizedBox(
                            width: 100,
                            child: OutlinedButton(
                              onPressed: _confirmDelete,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                backgroundColor: context.appColors.surface,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              child: const Text(
                                '删除',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ] else ...[
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _submit(continueAfterSave: true),
                              style: FilledButton.styleFrom(
                                backgroundColor: context.appColors.surfaceDim,
                                foregroundColor: context.appColors.primary,
                              ),
                              child: const Text('再记一笔'),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: FilledButton(
                            onPressed: _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF2B9E96)
                                  : const Color(0xFF069B9B),
                              foregroundColor: Colors.white,
                            ),
                            child: Text('保存${_type.label}'),
                          ),
                        ),
                      ],
                    ),
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
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          bottom: _isCustomKeyboardVisible ? 0 : -400,
          child: _KeyboardWithButton(
            onCollapse: () => setState(() => _isCustomKeyboardVisible = false),
            child: CustomKeyboard(
              onKeyPressed: _handleCustomKeyPressed,
              currentType: _type,
              onTypeChanged: _handleTypeChanged,
              isCalculated: _isCalculated,
              hasExpression: _expression.contains('+') || _expression.contains('-'),
            ),
          ),
        ),
        _buildNoteEditorSheet(),
        if (_isVoiceOverlayVisible && voiceButtonRect != null)
          Positioned(
            left: voiceButtonRect.left,
            top: voiceButtonRect.top,
            width: voiceButtonRect.width,
            height: voiceButtonRect.height,
            child: _buildEntryVoiceButton(interactive: false),
          ),
      ],
    );
  }

  void _ensureValidAccountSelection(List<Account> accounts) {
    if (accounts.isEmpty) {
      _expenseFromAccountId = null;
      _incomeToAccountId = null;
      _transferFromAccountId = null;
      _transferToAccountId = null;
      return;
    }
    final ids = accounts.map((account) => account.id).toSet();
    _expenseFromAccountId = _validAccountId(
      _expenseFromAccountId,
      ids,
      fallback: accounts.first.id,
    );
    _incomeToAccountId = _validAccountId(
      _incomeToAccountId,
      ids,
      fallback: accounts.length > 1 ? accounts.last.id : accounts.first.id,
    );
    _transferFromAccountId = _validAccountId(
      _transferFromAccountId,
      ids,
      fallback: accounts.first.id,
    );
    final transferTargetFallback = accounts.length > 1
        ? accounts.last.id
        : accounts.first.id;
    _transferToAccountId = _validAccountId(
      _transferToAccountId,
      ids,
      fallback: transferTargetFallback,
    );
    if (_transferToAccountId == _transferFromAccountId && accounts.length > 1) {
      _transferToAccountId = accounts
          .firstWhere((account) => account.id != _transferFromAccountId)
          .id;
    }
  }

  String get _currentFromAccountId {
    return switch (_type) {
      LedgerEntryType.expense => _expenseFromAccountId!,
      LedgerEntryType.transfer => _transferFromAccountId!,
      LedgerEntryType.income => _expenseFromAccountId!,
    };
  }

  String get _currentToAccountId {
    return switch (_type) {
      LedgerEntryType.income => _incomeToAccountId!,
      LedgerEntryType.transfer => _transferToAccountId!,
      LedgerEntryType.expense => _incomeToAccountId!,
    };
  }

  void _setCurrentFromAccountId(String id) {
    if (_type == LedgerEntryType.transfer) {
      _transferFromAccountId = id;
      return;
    }
    _expenseFromAccountId = id;
  }

  void _setCurrentToAccountId(String id) {
    if (_type == LedgerEntryType.transfer) {
      _transferToAccountId = id;
      return;
    }
    _incomeToAccountId = id;
  }

  String _validAccountId(
    String? candidate,
    Set<String> validIds, {
    required String fallback,
  }) {
    if (candidate != null && validIds.contains(candidate)) {
      return candidate;
    }
    return fallback;
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

  Future<void> _confirmDelete() async {
    confirmDelete(
      context,
      title: '删除流水？',
      message: '删除后，相关账户余额会同步恢复。',
      onConfirm: () async {
        if (widget.entry != null) {
          await widget.store.deleteEntry(widget.entry!.id);
          if (mounted) {
            showSnack(context, '流水已删除');
            Navigator.of(context).pop();
          }
        }
      },
    );
  }

  Future<void> _submit({bool continueAfterSave = false}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_type == LedgerEntryType.transfer &&
        _transferFromAccountId == _transferToAccountId) {
      showSnack(context, '转出账户和转入账户不能相同');
      return;
    }
    if (!continueAfterSave) {
      _collapseKeyboardForSubmit();
    }
    final savedType = _type;
    final store = widget.store;
    final isEditing = _isEditing;
    final navigator = Navigator.of(context);
    final entry = LedgerEntry(
      id: widget.entry?.id ?? newId(),
      type: savedType,
      amountInCents: parseMoney(_amountController.text)!,
      occurredAt: _occurredAt,
      note: _noteController.text.trim(),
      category: switch (savedType) {
        LedgerEntryType.expense => _expenseCategory,
        LedgerEntryType.income => _incomeCategory,
        LedgerEntryType.transfer => null,
      },
      expenseGroup: savedType == LedgerEntryType.expense ? _expenseGroup : null,
      expenseCategory: savedType == LedgerEntryType.expense
          ? _expenseCategory
          : null,
      incomeGroup: savedType == LedgerEntryType.income ? _incomeGroup : null,
      incomeCategory: savedType == LedgerEntryType.income
          ? _incomeCategory
          : null,
      fromAccountId: savedType == LedgerEntryType.income
          ? null
          : (savedType == LedgerEntryType.expense
                ? _expenseFromAccountId
                : _transferFromAccountId),
      toAccountId: savedType == LedgerEntryType.expense
          ? null
          : (savedType == LedgerEntryType.income
                ? _incomeToAccountId
                : _transferToAccountId),
    );
    unawaited(
      store.rememberEntryFormDefaults(
        savedType,
        EntryFormDefaults(
          expenseGroup: savedType == LedgerEntryType.expense
              ? _expenseGroup
              : null,
          expenseCategory: savedType == LedgerEntryType.expense
              ? _expenseCategory
              : null,
          incomeGroup: savedType == LedgerEntryType.income
              ? _incomeGroup
              : null,
          incomeCategory: savedType == LedgerEntryType.income
              ? _incomeCategory
              : null,
          fromAccountId: savedType == LedgerEntryType.expense
              ? _expenseFromAccountId
              : savedType == LedgerEntryType.transfer
              ? _transferFromAccountId
              : null,
          toAccountId: savedType == LedgerEntryType.income
              ? _incomeToAccountId
              : savedType == LedgerEntryType.transfer
              ? _transferToAccountId
              : null,
        ),
      ),
    );
    if (continueAfterSave && !isEditing) {
      await store.addEntry(entry);
      widget.onSaved(savedType);
      if (!mounted) {
        return;
      }
      setState(() {
        _amountController.clear();
        _noteController.clear();
        _occurredAt = DateTime.now();
      });
      _amountFocusNode.requestFocus();
      return;
    }

    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(() async {
        await Future<void>.delayed(const Duration(milliseconds: 220));
        if (isEditing) {
          await store.updateEntry(entry);
        } else {
          await store.addEntry(entry);
        }
        widget.onSaved(savedType);
      }());
    });
  }

  void _handleCustomKeyPressed(String key) {
    setState(() {
      if (key == 'collapse') {
        _isCustomKeyboardVisible = false;
        return;
      }

      if (key == 'confirm') {
        _isCustomKeyboardVisible = false;
        return;
      }

      if (key == '=') {
        _calculateExpression();
        _isCalculated = true;
        _expression = ''; // 清除表达式，让按钮变回"确定"
        return;
      }

      if (key == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
          _updateAmountFromExpression();
        }
        return;
      }

      if (key == '+' || key == '-') {
        if (_expression.isNotEmpty && !_expression.endsWith('+') && !_expression.endsWith('-')) {
          _expression += key;
          _isCalculated = false;
        }
        return;
      }

      if (key == '.') {
        // 只有当当前数字段还没有小数点时才允许输入
        final lastSegment = _expression.split(RegExp(r'[+-]')).last;
        if (_expression.isEmpty || _expression.endsWith('+') || _expression.endsWith('-')) {
          _expression += '0.';
        } else if (!lastSegment.contains('.')) {
          _expression += '.';
        }
        return;
      }

      // 数字键
      if (RegExp(r'^\d$').hasMatch(key)) {
        if (_isCalculated) {
          _expression = key;
          _isCalculated = false;
        } else {
          _expression += key;
        }
        _updateAmountFromExpression();
      }
    });
  }

  void _updateAmountFromExpression() {
    if (_expression.isEmpty) {
      _amountController.text = '';
      _expressionResult = '';
      return;
    }

    if (_expression.contains('+') || _expression.endsWith('-')) {
      // 有运算符时，计算结果
      _calculateExpression();
    } else {
      // 所见即所得：直接显示 _expression 原文
      _amountController.text = _expression;
      _expressionResult = _expression;
    }
  }

  void _calculateExpression() {
    if (_expression.isEmpty) return;

    try {
      final result = _evaluateExpression(_expression);
      if (result != null) {
        _amountController.text = result.toStringAsFixed(2);
        _expressionResult = _expression;
      }
    } catch (e) {
      // 表达式无效
    }
  }

  double? _evaluateExpression(String expression) {
    // 简单解析：支持 a+b 和 a-b
    final parts = expression.split(RegExp(r'([+-])'));
    if (parts.isEmpty) return null;

    double result = 0;
    String operator = '+';

    for (final part in parts) {
      if (part.isEmpty) continue;

      final value = double.tryParse(part);
      if (value == null) return null;

      switch (operator) {
        case '+':
          result += value;
          break;
        case '-':
          result -= value;
          break;
      }

      // 找下一个运算符
      final opIndex = expression.indexOf(part) + part.length;
      if (opIndex < expression.length) {
        operator = expression[opIndex];
      }
    }

    return result;
  }

  void _handleTypeChanged(LedgerEntryType type) {
    setState(() {
      _type = type;
    });
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
          IconButton(
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
    this.onTapDown,
    super.key,
  });

  final LedgerEntryType value;
  final Future<void> Function(LedgerEntryType) onChanged;
  final VoidCallback? onTapDown;

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

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) async {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 160) {
          return;
        }
        final nextIndex = velocity < 0 ? index + 1 : index - 1;
        if (nextIndex < 0 || nextIndex >= children.length) {
          return;
        }
        widget.onTapDown?.call();
        await widget.onChanged(children[nextIndex]);
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.appColors.surfaceAlt,
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
                            color: context.appColors.surface,
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
                    onTapDown: widget.onTapDown == null
                        ? null
                        : (_) => widget.onTapDown!(),
                    onTap: () async {
                      if (type == _value) {
                        return;
                      }
                      await widget.onChanged(type);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        type.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: type == _value
                              ? Theme.of(context).colorScheme.primary
                              : context.appColors.onBackgroundMid,
                          fontWeight: type == _value
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class AmountInput extends StatefulWidget {
  const AmountInput({
    required this.controller,
    this.focusNode,
    this.expression = '',
    this.isCalculated = false,
    this.onTap,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String expression;
  final bool isCalculated;
  final VoidCallback? onTap;

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> {
  @override
  void initState() {
    super.initState();
    // 不在这里重新格式化，避免加逗号导致与 _expression 不同步
    // 格式化统一由 _updateAmountFromExpression 处理
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _formatOnSubmit() {
    final text = widget.controller.text;
    if (text.isEmpty) return;

    // 移除所有非数字和小数点
    final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');

    // 解析为金额
    final cents = parseMoney(cleaned);
    if (cents != null) {
      // 格式化并更新控制器
      final formatted = formatMoney(cents).replaceFirst('¥', '');
      widget.controller.text = formatted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        }
        widget.focusNode?.requestFocus();
      },
      child: AbsorbPointer(
        absorbing: true,
        child: Stack(
          children: [
            TextFormField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              decoration: InputDecoration(
                labelText: '金额',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                prefixText: '¥ ',
                filled: true,
                fillColor: context.appColors.inputFill,
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
                  borderSide: BorderSide(color: context.appColors.primary.withValues(alpha: 0.2), width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
              ),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
              keyboardType: TextInputType.none,
              readOnly: true,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              onFieldSubmitted: (value) {
                _formatOnSubmit();
              },
              onEditingComplete: () {
                _formatOnSubmit();
              },
              validator: (value) {
                final cents = parseMoney(value ?? '');
                if (cents == null || cents <= 0) {
                  return '请输入大于 0 的金额';
                }
                return null;
              },
            ),
            if (widget.expression.isNotEmpty && !widget.isCalculated && (widget.expression.contains('+') || widget.expression.contains('-')))
              Positioned(
                left: 56,
                bottom: 6,
                child: Text(
                  widget.expression,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appColors.onBackgroundMid,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SelectFieldCard extends StatelessWidget {
  const SelectFieldCard({
    required this.label,
    required this.title,
    required this.subtitle,
    this.icon,
    this.accountIconOption,
    required this.color,
    required this.onTap,
    this.onTapDown,
    super.key,
  });

  final String label;
  final String title;
  final String subtitle;
  final IconData? icon;
  final AccountIconOption? accountIconOption;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onTapDown;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTapDown: onTapDown == null ? null : (_) => onTapDown!(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (accountIconOption != null)
                AccountIconBadge(option: accountIconOption!, size: 44),
              if (accountIconOption != null) const SizedBox(width: 12),
              if (accountIconOption == null && icon != null)
                IconBadge(icon: icon!, color: color, size: 44),
              if (accountIconOption == null && icon != null)
                const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.appColors.onBackgroundMid,
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
              Icon(Icons.keyboard_arrow_right, color: context.appColors.onBackgroundMid),
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
    this.onTapDown,
    super.key,
  });

  final String label;
  final Account? account;
  final VoidCallback onTap;
  final VoidCallback? onTapDown;

  @override
  Widget build(BuildContext context) {
    final option = accountIconOption(account?.iconKey ?? 'wallet');
    return SelectFieldCard(
      label: label,
      title: account?.name ?? '选择账户',
      subtitle: account == null ? '点击选择' : formatMoney(account!.balanceInCents),
      accountIconOption: option,
      color: option.color,
      onTapDown: onTapDown,
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
  final recentCategories = recentCategoryPicks(
    store,
    type,
    groups,
    childrenOf: childrenOf,
    groupNameOf: groupNameOf,
  );
  final sections = <_CategoryPickerSectionData>[
    if (recentCategories.isNotEmpty)
      _CategoryPickerSectionData(title: '最近使用', items: recentCategories),
    for (final group in groups)
      _CategoryPickerSectionData(
        title: groupNameOf(group),
        items: childrenOf(group)
            .map(
              (item) => CategoryPickOption(
                groupNameOf(group),
                item.name,
                item.iconKey,
              ),
            )
            .toList(growable: false),
      ),
  ];
  return Navigator.of(context).push<CategoryPickResult>(
    _BottomSheetLikeRoute<CategoryPickResult>(
      builder: (routeContext) => _CategoryPickerRoutePage(
        title: title,
        type: type,
        store: store,
        sections: sections,
        selectedGroup: selectedGroup,
        selectedCategory: selectedCategory,
      ),
    ),
  );
}

class CategoryPickOption {
  const CategoryPickOption(this.groupName, this.categoryName, this.iconKey);

  final String groupName;
  final String categoryName;
  final String iconKey;
}

class _CategoryPickerSectionData {
  const _CategoryPickerSectionData({required this.title, required this.items});

  final String title;
  final List<CategoryPickOption> items;
}

class _BottomSheetLikeRoute<T> extends PageRoute<T> {
  _BottomSheetLikeRoute({required this.builder});

  final WidgetBuilder builder;

  @override
  Color get barrierColor => const Color(0x52000000);

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  bool get barrierDismissible => true;

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(curved),
      child: child,
    );
  }
}

class _CategoryPickerRoutePage extends StatelessWidget {
  const _CategoryPickerRoutePage({
    required this.title,
    required this.type,
    required this.store,
    required this.sections,
    required this.selectedGroup,
    required this.selectedCategory,
  });

  final String title;
  final LedgerEntryType type;
  final LedgerStore store;
  final List<_CategoryPickerSectionData> sections;
  final String selectedGroup;
  final String selectedCategory;

  @override
  Widget build(BuildContext context) {
    final animation = ModalRoute.of(context)?.animation;
    final slide = animation == null
        ? const AlwaysStoppedAnimation<Offset>(Offset.zero)
        : Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: slide,
              child: RepaintBoundary(
                child: Container(
                  height: MediaQuery.sizeOf(context).height * 0.74,
                  decoration: BoxDecoration(
                    color: context.appColors.background,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: _CategoryPickerSheetBody(
                      title: title,
                      sections: sections,
                      selectedGroup: selectedGroup,
                      selectedCategory: selectedCategory,
                      headerTrailing: [
                        TextButton.icon(
                          onPressed: () async {
                            final result = await Navigator.of(context)
                                .push<CategoryPickResult>(
                                  MaterialPageRoute(
                                    builder: (_) => CategoryFormPage(
                                      store: store,
                                      type: type,
                                    ),
                                  ),
                                );
                            if (result != null && context.mounted) {
                              Navigator.of(context).pop(result);
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('添加小类'),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPickerSheetBody extends StatelessWidget {
  const _CategoryPickerSheetBody({
    required this.title,
    required this.sections,
    required this.selectedGroup,
    required this.selectedCategory,
    this.headerTrailing = const [],
  });

  final String title;
  final List<_CategoryPickerSectionData> sections;
  final String selectedGroup;
  final String selectedCategory;
  final List<Widget> headerTrailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
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
              ...headerTrailing,
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final section = sections[index];
              return _CategoryPickerSection(
                title: section.title,
                items: section.items,
                selectedGroup: selectedGroup,
                selectedCategory: selectedCategory,
              );
            },
          ),
        ),
      ],
    );
  }
}

List<CategoryPickOption> recentCategoryPicks<T>(
  LedgerStore store,
  LedgerEntryType type,
  List<T> groups, {
  required List<ExpenseCategoryItem> Function(T group) childrenOf,
  required String Function(T group) groupNameOf,
}) {
  // 按遍历顺序只存第一次出现的 groupName，确保和 store.groupNameForExpenseCategory 一致
  final groupNameByCategory = <String, String>{};
  final iconKeyByName = <String, String>{};
  for (final group in groups) {
    final groupName = groupNameOf(group);
    for (final item in childrenOf(group)) {
      groupNameByCategory.putIfAbsent(item.name, () => groupName);
      iconKeyByName[item.name] = item.iconKey;
    }
  }

  final recent = <CategoryPickOption>[];
  final seen = <String>{};
  for (var index = store.entries.length - 1; index >= 0; index--) {
    final entry = store.entries[index];
    if (entry.type != type) {
      continue;
    }
    final categoryName = type == LedgerEntryType.expense
        ? entry.expenseCategory ?? entry.category
        : entry.incomeCategory ?? entry.category;
    if (categoryName == null || seen.contains(categoryName)) {
      continue;
    }
    final groupName = groupNameByCategory[categoryName];
    final iconKey = iconKeyByName[categoryName];
    if (groupName == null || iconKey == null) {
      continue;
    }
    recent.add(CategoryPickOption(groupName, categoryName, iconKey));
    seen.add(categoryName);
    if (recent.length == 4) {
      break;
    }
  }
  return recent;
}

class _CategoryPickerSection extends StatelessWidget {
  const _CategoryPickerSection({
    required this.title,
    required this.items,
    required this.selectedGroup,
    required this.selectedCategory,
  });

  final String title;
  final List<CategoryPickOption> items;
  final String selectedGroup;
  final String selectedCategory;

  @override
  Widget build(BuildContext context) {
    final sectionColor = title == '最近使用'
        ? context.appColors.primary
        : categoryGroupColor(title);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: sectionColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              final selected =
                  selectedGroup == item.groupName &&
                  selectedCategory == item.categoryName;
              final itemColor = categoryGroupColor(item.groupName);
              final color = context.appColors.onBackground;
              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.of(context).pop(
                  CategoryPickResult(item.groupName, item.categoryName),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: double.infinity,
                      height: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? itemColor.withValues(alpha: 0.12)
                            : itemColor.withValues(alpha: 0.055),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: selected
                              ? itemColor.withValues(alpha: 0.34)
                              : itemColor.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: itemColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              categoryIcon(item.iconKey),
                              size: 18,
                              color: itemColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.categoryName,
                                maxLines: 1,
                                softWrap: false,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: context.appColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Color statisticsChartColor(
  Color baseColor,
  int index, {
  required LedgerEntryType type,
  required bool groupByMajor,
}) {
  final hsl = HSLColor.fromColor(baseColor);
  final hueOffsets = groupByMajor
      ? const <double>[0, 8, -8, 14, -14, 20, -20, 26, -26]
      : const <double>[0, 16, -14, 28, -26, 40, -38, 52, -50];
  final saturationOffsets = groupByMajor
      ? const <double>[0.02, -0.02, 0.04, -0.05, 0.06, -0.06, 0.03, -0.03, 0]
      : const <double>[0.04, -0.02, 0.08, -0.06, 0.1, -0.08, 0.06, -0.04, 0];
  final lightnessOffsets = type == LedgerEntryType.income
      ? const <double>[0, 0.06, -0.06, 0.1, -0.1, 0.13, -0.13, 0.04, -0.04]
      : const <double>[0, 0.05, -0.05, 0.09, -0.09, 0.12, -0.12, 0.04, -0.04];
  final variantIndex = index % hueOffsets.length;
  final nextHue = (hsl.hue + hueOffsets[variantIndex]) % 360;
  final nextSaturation = (hsl.saturation + saturationOffsets[variantIndex])
      .clamp(0.36, 0.7)
      .toDouble();
  final nextLightness = (hsl.lightness + lightnessOffsets[variantIndex])
      .clamp(0.34, 0.6)
      .toDouble();
  return hsl
      .withHue(nextHue)
      .withSaturation(nextSaturation)
      .withLightness(nextLightness)
      .toColor();
}

Future<String?> showAccountPickerSheet(
  BuildContext context,
  List<Account> accounts, {
  required String? selectedAccountId,
  required String title,
  List<Account> recentAccounts = const [],
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

  final validIds = accounts.map((account) => account.id).toSet();
  final recent = <Account>[];
  final recentSeen = <String>{};
  for (final account in recentAccounts) {
    if (!validIds.contains(account.id) || recentSeen.contains(account.id)) {
      continue;
    }
    recentSeen.add(account.id);
    recent.add(account);
    if (recent.length == 4) {
      break;
    }
  }

  // 生成分组后的账户列表
  final groupedAccounts = <Widget>[];
  if (recent.isNotEmpty) {
    groupedAccounts.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: _AccountPickerSectionTitle(title: '最近使用'),
      ),
    );
    groupedAccounts.add(
      LayoutBuilder(
        builder: (context, constraints) {
          const outerPadding = 16.0;
          const spacing = 10.0;
          final itemWidth =
              (constraints.maxWidth - outerPadding * 2 - spacing * 3) / 4;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: outerPadding),
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final account in recent)
                  SizedBox(
                    width: itemWidth,
                    height: itemWidth,
                    child: _RecentAccountPickCard(
                      account: account,
                      selected: account.id == selectedAccountId,
                      onTap: () => Navigator.of(context).pop(account.id),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
  for (final type in orderedTypes) {
    final typeAccounts = groups[type];
    if (typeAccounts != null && typeAccounts.isNotEmpty) {
      // 添加分组标题
      groupedAccounts.add(
        Padding(
          padding: const EdgeInsets.only(
            top: 16,
            bottom: 8,
            left: 16,
            right: 16,
          ),
          child: _AccountPickerSectionTitle(title: type.label),
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
              color: selected ? context.appColors.surfaceDim : context.appColors.surface,
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

class _AccountPickerSectionTitle extends StatelessWidget {
  const _AccountPickerSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 20,
          decoration: BoxDecoration(
            color: context.appColors.primary,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.appColors.onBackground,
          ),
        ),
      ],
    );
  }
}

class _RecentAccountPickCard extends StatelessWidget {
  const _RecentAccountPickCard({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final Account account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final option = accountIconOption(account.iconKey);
    final displayName = _compactAccountName(account.name);
    final fontSize = account.name.characters.length >= 5 ? 12.0 : 13.0;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? context.appColors.surfaceDim
                    : context.appColors.surfaceAlt,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? const Color(0x33069B9B)
                      : const Color(0x16069B9B),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AccountIconBadge(option: option, size: 34),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            displayName,
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: fontSize,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              color: context.appColors.onBackground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: context.appColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _compactAccountName(String name) {
    final characters = name.characters.toList();
    if (characters.length <= 5) {
      return name;
    }
    return '${characters.take(4).join()}...';
  }
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
      resizeToAvoidBottomInset: false,
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
                            ? context.appColors.surfaceDim
                            : context.appColors.surface,
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
      bottomNavigationBar: Builder(
        builder: (context) {
          final keyboardOffset = math.max(
            0.0,
            MediaQuery.viewInsetsOf(context).bottom -
                MediaQuery.paddingOf(context).bottom,
          );
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + keyboardOffset),
              child: FilledButton(onPressed: _submit, child: const Text('保存小类')),
            ),
          );
        },
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
                  ? context.appColors.surfaceDim
                  : context.appColors.surfaceAlt,
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
                  return Material(
                    color: selected ? context.appColors.surfaceDim : context.appColors.surface,
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
            decoration: const InputDecoration(hintText: '请输入4位数密码'),
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
                            ? context.appColors.surfaceDim
                            : context.appColors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [AccountIconBadge(option: option)],
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
      resizeToAvoidBottomInset: false,
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
                color: context.appColors.surface,
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
                        Icon(Icons.keyboard_arrow_right, color: context.appColors.onBackgroundMid),
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
      bottomNavigationBar: Builder(
        builder: (context) {
          final keyboardOffset = math.max(
            0.0,
            MediaQuery.viewInsetsOf(context).bottom -
                MediaQuery.paddingOf(context).bottom,
          );
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + keyboardOffset),
              child: FilledButton(
                onPressed: _submit,
                style: Theme.of(context).brightness == Brightness.dark
                    ? FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2B9E96),
                        foregroundColor: Colors.white,
                      )
                    : null,
                child: Text(_isEditing ? '保存修改' : '确认添加'),
              ),
            ),
          );
        },
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

/// 键盘 + 收起按钮组合，右上角有凸起
class _KeyboardWithButton extends StatelessWidget {
  const _KeyboardWithButton({
    required this.onCollapse,
    required this.child,
  });

  final VoidCallback onCollapse;
  final Widget child;

  static const _protrusionHeight = 24.0;
  static const _btnWidth = 62.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 44,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: ClipPath(
        clipper: _KeyboardShapeClipper(),
        child: Container(
          color: context.appColors.surfaceAlt,
          child: SizedBox(
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: _protrusionHeight),
                  child: child,
                ),
                // 收起箭头 - 在右上角凸起位置
                Positioned(
                  right: 0,
                  top: 4,
                  child: SizedBox(
                    width: _btnWidth,
                    height: _protrusionHeight,
                    child: GestureDetector(
                      onTap: onCollapse,
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: context.appColors.onBackgroundLight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyboardShapeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final pw = size.width;
    final ph = _KeyboardWithButton._protrusionHeight;
    final btnW = _KeyboardWithButton._btnWidth;
    const r = 12.0;

    // 左上圆角
    path.moveTo(0, ph + r);
    path.quadraticBezierTo(0, ph, r, ph);
    // 主体顶部从左→右，到达凸起左下角
    path.lineTo(pw - btnW, ph);
    // 凸起左下角（直角）→ 向上
    path.lineTo(pw - btnW, r);
    // 凸起左上圆角
    path.quadraticBezierTo(pw - btnW, 0, pw - btnW + r, 0);
    // 凸起顶部
    path.lineTo(pw - r, 0);
    // 凸起右上圆角
    path.quadraticBezierTo(pw, 0, pw, r);
    // 凸起右下角（直角）→ 向下
    path.lineTo(pw, size.height);
    // 底部
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

