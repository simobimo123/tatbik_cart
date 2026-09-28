import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';

enum SpeechRecognitionState {
  idle,
  preparing,
  recording,
  processing,
  error,
}

class SpeechRecognitionResult {
  const SpeechRecognitionResult({
    required this.text,
    required this.language,
    required this.languageProbability,
  });

  final String text;
  final String language;
  final double languageProbability;
}

class SpeechRecognitionService {
  SpeechRecognitionService._();

  static final instance = SpeechRecognitionService._();

  static const _model = WhisperModelCatalog.base;

  final ValueNotifier<SpeechRecognitionState> state =
      ValueNotifier<SpeechRecognitionState>(SpeechRecognitionState.idle);
  final ValueNotifier<double> downloadProgress = ValueNotifier<double>(0);
  final ValueNotifier<String> liveText = ValueNotifier<String>('');

  WhisperModelManager? _modelManager;
  WhisperEngine? _engine;
  WhisperStreamTask? _streamTask;
  StreamSubscription<WhisperStreamUpdate>? _updatesSubscription;
  Future<WhisperStreamTask>? _startingTaskFuture;
  Future<void>? _prepareFuture;
  bool _stopRequested = false;
  int _startGeneration = 0;

  bool get isRecording =>
      state.value == SpeechRecognitionState.recording;

  Future<void> prepare() {
    if (_engine != null) return Future<void>.value();

    final existing = _prepareFuture;
    if (existing != null) return existing;

    final future = _prepare();
    _prepareFuture = future;

    unawaited(
      future.then(
        (_) {
          if (identical(_prepareFuture, future)) {
            _prepareFuture = null;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_prepareFuture, future)) {
            _prepareFuture = null;
          }
        },
      ),
    );

    return future;
  }

  Future<void> _prepare() async {
    state.value = SpeechRecognitionState.preparing;
    downloadProgress.value = 0;

    try {
      final manager = _modelManager ??= WhisperModelManager();

      var modelFile = await manager.findCatalogModel(_model);

      if (modelFile == null) {
        await for (final progress in manager.downloadCatalogModel(_model)) {
          downloadProgress.value = progress.fraction ?? 0;
        }

        modelFile = await manager.findCatalogModel(_model);
      }

      if (modelFile == null) {
        throw StateError('تعذر تثبيت نموذج التعرف على الكلام الألماني.');
      }

      _engine = await WhisperEngine.load(
        modelFile.path,
        config: const WhisperConfig(
          useGpu: true,
          useFlashAttention: true,
        ),
      );

      state.value = SpeechRecognitionState.idle;
    } catch (_) {
      state.value = SpeechRecognitionState.error;
      rethrow;
    }
  }

  Future<void> startListening({
    String? initialPrompt,
  }) async {
    if (isRecording) return;

    final startGeneration = ++_startGeneration;

    await prepare();

    // إذا أُلغي الضغط أثناء تجهيز النموذج، لا نبدأ التسجيل بعد
    // انتهاء التجهيز.
    if (startGeneration != _startGeneration) return;

    final engine = _engine;

    if (engine == null) {
      throw StateError('محرك التعرف على الكلام غير جاهز.');
    }

    await _cancelActiveListening(invalidateStart: false);

    if (startGeneration != _startGeneration) return;

    liveText.value = '';
    _stopRequested = false;

    // أثناء إنشاء مهمة Whisper لا نسمح ببدء طلب تسجيل ثانٍ،
    // ونُبقي واجهة المراجعة في حالة انشغال حتى تصبح المهمة جاهزة.
    state.value = SpeechRecognitionState.preparing;

    Future<WhisperStreamTask>? startFuture;

    try {
      startFuture = engine.transcribeMicrophone(
        options: TranscribeOptions(
          strategy: WhisperSamplingStrategy.beamSearch,
          threads: 4,
          language: 'de',
          translate: false,
          detectLanguage: false,
          tokenTimestamps: false,
          noTimestamps: true,
          suppressBlank: true,
          suppressNonSpeechTokens: true,
          noContext: true,
          initialPrompt: initialPrompt,
          carryInitialPrompt: initialPrompt != null,
          temperature: 0,
          beamSize: 5,
          greedyBestOf: 5,
          noSpeechThreshold: 0.55,
        ),
        config: const WhisperStreamConfig(
          updateInterval: Duration(milliseconds: 700),
          windowDuration: Duration(seconds: 6),
          confirmationLag: Duration(seconds: 1),
        ),
      );

      _startingTaskFuture = startFuture;
      final task = await startFuture;

      if (!identical(_startingTaskFuture, startFuture)) {
        try {
          await task.cancel();
        } catch (_) {}
        return;
      }

      // إذا طُلب الإيقاف أثناء تهيئة المهمة، يترك start المهمة
      // لـ stopListening() أو cancelListening() ليتم التعامل معها
      // مرة واحدة فقط.
      if (_stopRequested) return;

      _streamTask = task;
      _updatesSubscription = task.updates.listen(
        (update) {
          liveText.value = update.text.trim();
        },
        onError: (_) {},
      );
      state.value = SpeechRecognitionState.recording;
    } catch (_) {
      if (!_stopRequested) {
        state.value = SpeechRecognitionState.error;
        rethrow;
      }
    } finally {
      final activeStartFuture = _startingTaskFuture;
      if (identical(activeStartFuture, startFuture)) {
        _startingTaskFuture = null;
      }
    }
  }

  Future<SpeechRecognitionResult> stopListening() async {
    final starting = _startingTaskFuture;

    if (_streamTask == null && starting != null) {
      _stopRequested = true;
      state.value = SpeechRecognitionState.processing;

      try {
        final task = await starting;

        if (_streamTask == null) {
          _streamTask = task;
          _updatesSubscription = task.updates.listen(
            (update) {
              liveText.value = update.text.trim();
            },
            onError: (_) {},
          );
        }
      } catch (_) {
        state.value = SpeechRecognitionState.error;
        rethrow;
      } finally {
        if (identical(_startingTaskFuture, starting)) {
          _startingTaskFuture = null;
        }
      }
    }

    final task = _streamTask;

    if (task == null) {
      state.value = SpeechRecognitionState.idle;
      return SpeechRecognitionResult(
        text: '',
        language: 'de',
        languageProbability: -1,
      );
    }

    state.value = SpeechRecognitionState.processing;

    try {
      final result = await task.stop();
      await _updatesSubscription?.cancel();
      _updatesSubscription = null;
      _streamTask = null;
      _stopRequested = false;

      final text = result.text.trim();
      liveText.value = text;
      state.value = SpeechRecognitionState.idle;

      return SpeechRecognitionResult(
        text: text,
        language: 'de',
        languageProbability: -1,
      );
    } catch (_) {
      await _updatesSubscription?.cancel();
      _updatesSubscription = null;
      _streamTask = null;
      _stopRequested = false;
      state.value = SpeechRecognitionState.error;
      rethrow;
    }
  }

  Future<void> cancelListening() async {
    ++_startGeneration;
    await _cancelActiveListening();
  }

  Future<void> _cancelActiveListening({
    bool invalidateStart = true,
  }) async {
    if (invalidateStart) {
      ++_startGeneration;
    }

    _stopRequested = true;

    final task = _streamTask;
    _streamTask = null;

    final starting = _startingTaskFuture;

    await _updatesSubscription?.cancel();
    _updatesSubscription = null;

    if (task != null) {
      try {
        await task.cancel();
      } catch (_) {}
    }

    if (starting != null) {
      try {
        final startingTask = await starting;
        if (_streamTask == null) {
          await startingTask.cancel();
        }
      } catch (_) {}
      if (identical(_startingTaskFuture, starting)) {
        _startingTaskFuture = null;
      }
    }

    liveText.value = '';
    if (state.value != SpeechRecognitionState.preparing) {
      state.value = SpeechRecognitionState.idle;
    }
  }

  Future<void> dispose() async {
    await cancelListening();
    _engine?.dispose();
    _engine = null;
    _modelManager?.close();
    _modelManager = null;
  }
}
