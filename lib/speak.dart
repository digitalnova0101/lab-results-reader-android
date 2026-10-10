import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';
import 'theme.dart';

/// "Listen to summary": a natural human-sounding voice made on the server (Google AI voice).
final AudioPlayer _player = AudioPlayer();
final ValueNotifier<String?> speakingId = ValueNotifier<String?>(null); // playing
final ValueNotifier<String?> loadingId = ValueNotifier<String?>(null); // preparing the voice
final Map<String, Uint8List> _cache = {};
bool _ready = false;

void _init() {
  if (_ready) return;
  _ready = true;
  _player.onPlayerComplete.listen((_) => speakingId.value = null);
}

/// Plays the summary. Returns an error message, or null when it started playing.
Future<String?> speak(String id, String text) async {
  _init();
  await stopSpeaking();
  try {
    final key = '$id|${text.hashCode}';
    var audio = _cache[key];
    if (audio == null) {
      loadingId.value = id;
      final res = await Api.post({'action': 'speak', 'text': text});
      audio = base64Decode('${res['audio']}');
      _cache[key] = audio;
      if (loadingId.value != id) return null; // user pressed stop while loading
    }
    loadingId.value = null;
    speakingId.value = id;
    await _player.play(BytesSource(audio, mimeType: 'audio/wav'));
    return null;
  } on ApiError catch (e) {
    loadingId.value = null;
    speakingId.value = null;
    if (e.code == 'cancelled') return null;
    return e.code == 'voice_unavailable' ? "The voice couldn't be created right now. Please try again." : errorText(e);
  } catch (_) {
    loadingId.value = null;
    speakingId.value = null;
    return "Couldn't play the voice. Please try again.";
  }
}

Future<void> stopSpeaking() async {
  loadingId.value = null;
  speakingId.value = null;
  try {
    await _player.stop();
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
