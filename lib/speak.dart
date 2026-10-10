import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'theme.dart';

/// Reads a summary aloud using the phone's built-in voice.
final FlutterTts _tts = FlutterTts();
final ValueNotifier<String?> speakingId = ValueNotifier<String?>(null);
bool _ready = false;

const Map<String, String> _voice = {
  'English': 'en-US',
  'Spanish': 'es-ES',
  'French': 'fr-FR',
  'German': 'de-DE',
  'Portuguese': 'pt-BR',
  'Italian': 'it-IT',
  'Chinese (Simplified)': 'zh-CN',
  'Japanese': 'ja-JP',
  'Korean': 'ko-KR',
  'Arabic': 'ar-SA',
  'Hindi': 'hi-IN',
  'Hinglish': 'en-IN',
};

Future<void> _init() async {
  if (_ready) return;
  _ready = true;
  _tts.setCompletionHandler(() => speakingId.value = null);
  _tts.setCancelHandler(() => speakingId.value = null);
  _tts.setErrorHandler((_) => speakingId.value = null);
  try {
    await _tts.awaitSpeakCompletion(false);
  } catch (_) {}
}

/// Returns false if the phone has no voice for this language.
Future<bool> speak(String id, String lang, String text) async {
  await _init();
  await stopSpeaking();
  try {
    final code = _voice[lang] ?? 'en-US';
    final ok = await _tts.isLanguageAvailable(code);
    if (ok == false && code != 'en-US') return false;
    await _tts.setLanguage(ok == false ? 'en-US' : code);
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    speakingId.value = id;
    await _tts.speak(text);
    return true;
  } catch (_) {
    speakingId.value = null;
    return false;
  }
}

Future<void> stopSpeaking() async {
  speakingId.value = null;
  try {
    await _tts.stop();
  } catch (_) {}
}

/// What gets read aloud: the big picture, what needs attention, and the doctor questions.
String spokenText(Map<String, dynamic> r) {
  final b = StringBuffer();
  final overall = norm(r['overall']);
  b.writeln('${r['title'] ?? ''}.');
  b.writeln('${verdictOf[overall]}.');
  b.writeln('${r['summary'] ?? ''}');
  final urgent = '${r['urgent'] ?? ''}'.trim();
  if (urgent.isNotEmpty) b.writeln(urgent);
  for (final rep in (r['reports'] as List? ?? []).whereType<Map>()) {
    for (final it in (rep['items'] as List? ?? []).whereType<Map>()) {
      if (norm(it['status']) == 'ok') continue;
      b.writeln('${it['name']}: ${it['value']}. ${it['meaning'] ?? ''}');
    }
  }
  final q = (r['questions'] as List? ?? []);
  if (q.isNotEmpty) {
    b.writeln('Questions for your doctor.');
    for (final x in q) {
      b.writeln('$x');
    }
  }
  return b.toString();
}
