import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SpeechService {
  SpeechService._();

  static final instance = SpeechService._();

  final FlutterTts _tts = FlutterTts();

  bool _ready = false;
  String? _lastAutomaticKey;
  int _speechRequestId = 0;
  int? _activeRequestId;

  final ValueNotifier<String?> activeKey = ValueNotifier<String?>(null);
  final ValueNotifier<bool> speaking = ValueNotifier<bool>(false);

  Future<void>? _initializeFuture;

  Future<void> initialize() {
    final existing = _initializeFuture;
    if (existing != null) return existing;

    final future = _initialize();
    _initializeFuture = future;
    return future;
  }

  Future<void> _initialize() async {
    try {
      await _tts.setLanguage('de-DE');
      await _tts.setSpeechRate(0.42);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setQueueMode(0);
      await _tts.awaitSpeakCompletion(true);

      _tts.setStartHandler(() {
        if (_activeRequestId == null) return;
        speaking.value = true;
      });

      _tts.setCompletionHandler(() {
        if (_activeRequestId == null) return;
        _activeRequestId = null;
        speaking.value = false;
        activeKey.value = null;
      });

      _tts.setCancelHandler(() {
        if (_activeRequestId == null) return;
        _activeRequestId = null;
        speaking.value = false;
        activeKey.value = null;
      });

      _tts.setErrorHandler((_) {
        if (_activeRequestId == null) return;
        _activeRequestId = null;
        speaking.value = false;
        activeKey.value = null;
      });

      // Prefer an installed German voice when the platform exposes one.
      try {
        final voices = await _tts.getVoices;
        if (voices is List) {
          Map<String, String>? germanVoice;

          for (final item in voices) {
            if (item is! Map) continue;

            final locale = item['locale']?.toString() ?? '';
            final name = item['name']?.toString() ?? '';

            if (name.isEmpty || locale.isEmpty) continue;

            if (locale.toLowerCase() == 'de-de') {
              germanVoice = {
                'name': name,
                'locale': locale,
              };
              break;
            }

            if (germanVoice == null &&
                locale.toLowerCase().startsWith('de')) {
              germanVoice = {
                'name': name,
                'locale': locale,
              };
            }
          }

          if (germanVoice != null) {
            await _tts.setVoice(germanVoice);
          }
        }
      } catch (_) {
        // Keep the platform default German voice.
      }

      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }
  Future<void> speakGerman(
    String text, {
    String? activeKey,
    String? automaticKey,
  }) async {
    final value = text.trim();
    if (value.isEmpty) return;

    final requestId = ++_speechRequestId;

    await initialize();
    if (!_ready || requestId != _speechRequestId) return;

    if (automaticKey != null) {
      if (_lastAutomaticKey == automaticKey) return;
      _lastAutomaticKey = automaticKey;
    }

    try {
      _activeRequestId = null;
      await _tts.stop();

      if (requestId != _speechRequestId) return;

      _activeRequestId = requestId;
      this.activeKey.value = activeKey;
      speaking.value = true;

      final result = await _tts.speak(value);

      if (requestId != _speechRequestId ||
          _activeRequestId != requestId) {
        return;
      }

      if (result is num && result == 0) {
        _activeRequestId = null;
        speaking.value = false;
        this.activeKey.value = null;
      }
    } catch (_) {
      if (requestId != _speechRequestId ||
          _activeRequestId != requestId) {
        return;
      }

      _activeRequestId = null;
      speaking.value = false;
      this.activeKey.value = null;
    }
  }
  Future<void> stop() async {
    ++_speechRequestId;
    _activeRequestId = null;

    try {
      await _tts.stop();
    } catch (_) {
      // Ignore platform-specific stop errors.
    }

    speaking.value = false;
    activeKey.value = null;
  }
}
