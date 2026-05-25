import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ledger_app/services/ai_ledger_service.dart';
import 'package:ledger_app/services/baidu_ocr_service.dart';
import 'package:ledger_app/services/baidu_speech_service.dart';
import 'package:ledger_app/services/ledger_text_parser.dart';
import 'package:ledger_app/store/ledger_store.dart';


class VoiceRecordingController {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isInitialized = false;
  bool _isRecording = false;
  String? _path;

  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;

  Future<void> init() async {
    if (_isInitialized) {
      return;
    }
    await _recorder.openRecorder();
    _isInitialized = true;
  }

  Future<String> start() async {
    await init();
    if (_isRecording && _path != null) {
      return _path!;
    }
    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 16000,
    );
    _path = path;
    _isRecording = true;
    return path;
  }

  Future<String?> stop() async {
    if (!_isRecording) {
      return _path;
    }
    await _recorder.stopRecorder();
    _isRecording = false;
    return _path;
  }

  Future<void> cancel() async {
    final path = await stop();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    _path = null;
  }

  Future<void> dispose() async {
    if (_isRecording) {
      await stop();
    }
    if (_isInitialized) {
      await _recorder.closeRecorder();
      _isInitialized = false;
    }
  }
}

class VoiceRecognizeResult {
  const VoiceRecognizeResult(this.parseResult, {required this.usedAi});
  final VoiceParseResult parseResult;
  final bool usedAi;
}

class VoiceInputRecognizer {
  static Future<VoiceRecognizeResult?> recognizeFile(
    String path, {
    required LedgerStore store,
  }) async {
    try {
      final service = BaiduSpeechService(
        apiKey: store.baiduApiKey!,
        secretKey: store.baiduSecretKey!,
      );
      final result = await service.recognizeSpeech(path);
      if (result == null) {
        return null;
      }
      final localResult = LedgerTextParser.parse(result, store: store);
      final aiApiKey = store.selectedAiApiKey;
      final needAi = localResult.type == null ||
          localResult.amount == null ||
          localResult.isCategoryFuzzy;
      if (needAi &&
          store.isVoiceAiEnabled &&
          aiApiKey != null &&
          aiApiKey.isNotEmpty) {
        try {
          final aiResult = await AiLedgerService(
            provider: store.aiProvider,
            apiKey: aiApiKey,
            model: store.selectedAiModel,
          ).parseVoiceText(result, store: store);
          if (aiResult != null) {
            return VoiceRecognizeResult(
              aiResult.mergeMissingFrom(localResult),
              usedAi: true,
            );
          }
        } catch (_) {}
      }
      return VoiceRecognizeResult(localResult, usedAi: false);
    } finally {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }
}

class ImageInputRecognizer {
  static Future<VoiceRecognizeResult?> recognizeFile(
    String path, {
    required LedgerStore store,
    bool deleteAfterRecognize = false,
  }) async {
    try {
      final service = BaiduOcrService(
        apiKey: store.baiduApiKey!,
        secretKey: store.baiduSecretKey!,
      );
      final result = await service.recognizeImage(path);
      if (result == null || result.trim().isEmpty) {
        return null;
      }
      final aiApiKey = store.selectedAiApiKey;
      if (aiApiKey != null && aiApiKey.isNotEmpty) {
        try {
          final aiResult = await AiLedgerService(
            provider: store.aiProvider,
            apiKey: aiApiKey,
            model: store.selectedAiModel,
          ).parseOcrText(result, store: store);
          if (aiResult != null) {
            return VoiceRecognizeResult(aiResult, usedAi: true);
          }
        } catch (_) {}
      }
      return VoiceRecognizeResult(
        LedgerTextParser.parseImage(result, store: store),
        usedAi: false,
      );
    } finally {
      if (deleteAfterRecognize) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
  }
}

class HomeVoiceFab extends StatefulWidget {
  const HomeVoiceFab({
    required this.isRecording,
    required this.isCanceling,
    required this.onTap,
    required this.onTapCancel,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
    this.normalIcon = Icons.add,
    this.isProcessing = false,
    super.key,
  });

  final bool isRecording;
  final bool isCanceling;
  final VoidCallback onTap;
  final VoidCallback onTapCancel;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;
  final GestureLongPressEndCallback onLongPressEnd;
  final VoidCallback onLongPressCancel;
  final IconData normalIcon;
  final bool isProcessing;

  @override
  State<HomeVoiceFab> createState() => _HomeVoiceFabState();
}

class _HomeVoiceFabState extends State<HomeVoiceFab> {
  static const Duration _voicePressDuration = Duration(milliseconds: 300);
  Timer? _voicePressTimer;
  bool _isPointerDown = false;
  bool _isVoicePressActive = false;
  Offset _downGlobalPosition = Offset.zero;
  Offset _downLocalPosition = Offset.zero;
  Offset _lastGlobalPosition = Offset.zero;
  Offset _lastLocalPosition = Offset.zero;

  @override
  void dispose() {
    _voicePressTimer?.cancel();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _voicePressTimer?.cancel();
    _isPointerDown = true;
    _isVoicePressActive = false;
    _downGlobalPosition = event.position;
    _downLocalPosition = event.localPosition;
    _lastGlobalPosition = event.position;
    _lastLocalPosition = event.localPosition;
    _voicePressTimer = Timer(_voicePressDuration, () {
      if (!_isPointerDown) {
        return;
      }
      _isVoicePressActive = true;
      widget.onLongPressStart(
        LongPressStartDetails(
          globalPosition: _lastGlobalPosition,
          localPosition: _lastLocalPosition,
        ),
      );
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    _lastGlobalPosition = event.position;
    _lastLocalPosition = event.localPosition;
    if (!_isVoicePressActive) {
      return;
    }
    widget.onLongPressMoveUpdate(
      LongPressMoveUpdateDetails(
        globalPosition: event.position,
        localPosition: event.localPosition,
        offsetFromOrigin: event.position - _downGlobalPosition,
        localOffsetFromOrigin: event.localPosition - _downLocalPosition,
      ),
    );
  }

  void _handlePointerUp(PointerUpEvent event) {
    _voicePressTimer?.cancel();
    final wasVoicePressActive = _isVoicePressActive;
    _isPointerDown = false;
    _isVoicePressActive = false;
    if (wasVoicePressActive) {
      widget.onLongPressEnd(
        LongPressEndDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
        ),
      );
    } else {
      widget.onTap();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _voicePressTimer?.cancel();
    final wasVoicePressActive = _isVoicePressActive;
    _isPointerDown = false;
    _isVoicePressActive = false;
    if (wasVoicePressActive) {
      widget.onLongPressCancel();
    } else {
      widget.onTapCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isCanceling
        ? const Color(0xFFEF3B3D)
        : const Color(0xFF069B9B);
    const size = 56.0;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: widget.isRecording
                ? widget.isCanceling
                      ? const Icon(
                          Icons.close,
                          key: ValueKey('cancel'),
                          color: Colors.white,
                          size: 30,
                        )
                      : const VoiceButtonGlyph(key: ValueKey('voice'))
                : widget.isProcessing
                ? const SizedBox(
                    key: ValueKey('processing'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    widget.normalIcon,
                    key: const ValueKey('normal'),
                    color: Colors.white,
                    size: 32,
                  ),
          ),
        ),
      ),
    );
  }
}

class VoiceRecordingOverlay extends StatelessWidget {
  const VoiceRecordingOverlay({
    required this.isCanceling,
    required this.isVisible,
    super.key,
  });

  final bool isCanceling;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    final accent = isCanceling
        ? const Color(0xFF6C7370)
        : const Color(0xFF069B9B);
    final textColor = isCanceling
        ? const Color(0xFFE5444D)
        : const Color(0xFF111817);
    return AbsorbPointer(
      child: AnimatedOpacity(
        opacity: isVisible ? 1 : 0,
        duration: const Duration(milliseconds: 280),
        curve: isVisible ? Curves.easeOutCubic : Curves.easeInCubic,
        child: Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle(
            style: const TextStyle(decoration: TextDecoration.none),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/Application/gaosibg.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: Container(color: Colors.white.withValues(alpha: 0.08)),
                ),
                Align(
                  alignment: const Alignment(0, 0.04),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCanceling ? '松手取消记账' : '按住说话完成记账',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 64),
                      VoiceWaveform(color: accent),
                    ],
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

class VoiceWaveform extends StatefulWidget {
  const VoiceWaveform({required this.color, super.key});

  final Color color;

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(300, 56),
          painter: _VoiceWaveformPainter(widget.color, _controller.value),
        );
      },
    );
  }
}

class _VoiceWaveformPainter extends CustomPainter {
  const _VoiceWaveformPainter(this.color, this.phase);

  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final centerY = size.height / 2;

    void drawBar(double x, double height) {
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }

    const barCount = 45;
    final spacing = size.width / (barCount - 1);
    for (var i = 0; i < barCount; i++) {
      final x = i * spacing;
      final wave = math.sin((phase * math.pi * 2) + i * 0.82);
      final secondary = math.sin((phase * math.pi * 4) + i * 0.31);
      final height = (13 + wave * 4.5 + secondary * 1.6).clamp(7.0, 22.0);
      drawBar(x, height);
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWaveformPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.phase != phase;
  }
}

class VoiceButtonGlyph extends StatelessWidget {
  const VoiceButtonGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(painter: _VoiceButtonGlyphPainter()),
    );
  }
}

class _VoiceButtonGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    const heights = [10.0, 17.0, 25.0, 17.0, 10.0];
    for (var i = 0; i < heights.length; i++) {
      final x = centerX + (i - 2) * 6;
      final height = heights[i];
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
