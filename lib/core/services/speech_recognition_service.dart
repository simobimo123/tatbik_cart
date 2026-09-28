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
  Future<void>? _prepareFuture;

  bool get isRecording =>
      state.value == SpeechRecognitionState.recording;

  Future<void> prepare() {
    if (_engine != null) return Future<void>.value();

    final existing = _prepareFuture;
    if (existing != null) return existing;

    final future = _prepare();
    _prepareFuture = future;

    future.whenComplete(() {
      if (identical(_prepareFuture, future)) {
        _prepareFuture = null;
      }
    });

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

    await prepare();
    final engine = _engine;

    if (engine == null) {
      throw StateError('محرك التعرف على الكلام غير جاهز.');
    }

    await cancelListening();

    liveText.value = '';
    state.value = SpeechRecognitionState.recording;

    try {
      final task = await engine.transcribeMicrophone(
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
          updateInterval: Duration(seconds: 1),
          windowDuration: Duration(seconds: 8),
          confirmationLag: Duration(seconds: 2),
        ),
      );

      _streamTask = task;
      _updatesSubscription = task.updates.listen(
        (update) {
          liveText.value = update.text.trim();
        },
        onError: (_) {},
      );
    } catch (_) {
      state.value = SpeechRecognitionState.error;
      rethrow;
    }
  }

  Future<SpeechRecognitionResult> stopListening() async {
    final task = _streamTask;

    if (task == null) {
      return SpeechRecognitionResult(
        text: liveText.value.trim(),
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

      final text = result.text.trim();
      liveText.value = text;
      state.value = SpeechRecognitionState.idle;

      return SpeechRecognitionResult(
        text: text,
        language: result.language,
        languageProbability: result.languageProbability,
      );
    } catch (_) {
      await _updatesSubscription?.cancel();
      _updatesSubscription = null;
      _streamTask = null;
      state.value = SpeechRecognitionState.error;
      rethrow;
    }
  }

  Future<void> cancelListening() async {
    final task = _streamTask;
    _streamTask = null;

    await _updatesSubscription?.cancel();
    _updatesSubscription = null;

    if (task != null) {
      try {
        await task.cancel();
      } catch (_) {}
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
