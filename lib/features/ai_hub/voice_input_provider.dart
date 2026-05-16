import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

final speechToTextProvider = Provider<SpeechToTextService>((ref) {
  return SpeechToTextService();
});

class SpeechToTextService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (e) => debugPrint('[Speech] error: $e'),
      onStatus: (s) => debugPrint('[Speech] status: $s'),
    );
    return _initialized;
  }

  bool get isAvailable => _speech.isAvailable;
  bool get isListening => _speech.isListening;

  Future<void> startListening({required void Function(String) onResult}) async {
    if (!_initialized) await initialize();
    if (!_speech.isAvailable) return;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }
}
