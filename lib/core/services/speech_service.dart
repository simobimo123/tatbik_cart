import 'package:flutter_tts/flutter_tts.dart';

class SpeechService {
  SpeechService._();

  static final instance = SpeechService._();

  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  bool _ready = false;
  String? _lastAutomaticKey;

  String? get activeKey => _activeKey;
  bool get isSpeaking => _isSpeaking;

  String? _activeKey;
  bool _isSpeaking = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _tts.setLanguage('de-DE');
      await _tts.setSpeechRate(0.42);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setQueueMode(0);
      await _tts.awaitSpeakCompletion(true);

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _activeKey = null;
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
        _activeKey = null;
      });

      _tts.setErrorHandler((_) {
        _isSpeaking = false;
        _activeKey = null;
      });

      // Use an installed German voice when the platform exposes one.
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
        // The default German voice remains valid when voice discovery
        // is unavailable on the current platform.
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

    await initialize();
    if (!_ready) return;

    if (automaticKey != null) {
      if (_lastAutomaticKey == automaticKey) return;
      _lastAutomaticKey = automaticKey;
    }

    try {
      await _tts.stop();

      _activeKey = activeKey;
      _isSpeaking = true;

      final result = await _tts.speak(value);

      if (result is num && result == 0) {
        _isSpeaking = false;
        _activeKey = null;
      }
    } catch (_) {
      _isSpeaking = false;
      _activeKey = null;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Ignore platform-specific stop errors.
    }

    _isSpeaking = false;
    _activeKey = null;
  }
}
