import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int freeLimit = 3; // free reports per phone (set 999 while testing)
const String appVersion = '2.1';

const List<List<String>> langs = [
  ['English', 'English'],
  ['Spanish', 'Español'],
  ['French', 'Français'],
  ['German', 'Deutsch'],
  ['Portuguese', 'Português'],
  ['Italian', 'Italiano'],
  ['Chinese (Simplified)', '中文'],
  ['Japanese', '日本語'],
  ['Korean', '한국어'],
  ['Arabic', 'العربية'],
  ['Hindi', 'हिंदी'],
  ['Hinglish', 'Hinglish'],
];

class Profile {
  Profile(this.id, this.name);
  final String id;
  String name;
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  static Profile fromJson(Map<String, dynamic> j) => Profile('${j['id']}', '${j['name']}');
}

class Entry {
  Entry({
    required this.id,
    required this.createdAt,
    required this.lang,
    required this.profileId,
    required this.title,
    required this.result,
    List<Map<String, String>>? chat,
  }) : chat = chat ?? [];

  final String id;
  final int createdAt;
  String lang;
  final String profileId;
  String title;
  Map<String, dynamic> result;
  List<Map<String, String>> chat;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt,
        'lang': lang,
        'profileId': profileId,
        'title': title,
        'result': result,
        'chat': chat,
      };

  static Entry fromJson(Map<String, dynamic> j) => Entry(
        id: '${j['id']}',
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        lang: '${j['lang'] ?? 'English'}',
        profileId: '${j['profileId'] ?? 'me'}',
        title: '${j['title'] ?? 'Medical report'}',
        result: Map<String, dynamic>.from(j['result'] as Map? ?? {}),
        chat: ((j['chat'] as List?) ?? [])
            .map((m) => {'role': '${(m as Map)['role']}', 'content': '${m['content']}'})
            .toList(),
      );
}

/// Everything the app remembers, saved on the phone.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState I = AppState._();

  SharedPreferences? _p;
  bool introSeen = false;
  bool langChosen = false;
  bool consent = false;
  bool saveHistory = false;
  String lang = 'English';
  String plan = 'free';
  int used = 0;
  List<Profile> profiles = [Profile('me', 'Me')];
  String active = 'me';
  List<Entry> history = [];

  // Not saved: what the Home tab is showing right now.
  Entry? current;
  int tab = 0;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    try {
      final s = jsonDecode(_p!.getString('settings') ?? '{}') as Map<String, dynamic>;
      introSeen = s['introSeen'] == true;
      langChosen = s['langChosen'] == true;
      consent = s['consent'] == true;
      saveHistory = s['saveHistory'] == true;
      lang = '${s['lang'] ?? 'English'}';
      plan = '${s['plan'] ?? 'free'}';
      used = (s['used'] as num?)?.toInt() ?? 0;
      final ps = (s['profiles'] as List?)?.map((e) => Profile.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (ps != null && ps.isNotEmpty) profiles = ps;
      active = '${s['active'] ?? 'me'}';
      if (!profiles.any((p) => p.id == active)) active = profiles.first.id;
    } catch (_) {}
    try {
      final h = jsonDecode(_p!.getString('history') ?? '[]') as List;
      history = h.map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      history = [];
    }
    notifyListeners();
  }

  void save() {
    _p?.setString(
        'settings',
        jsonEncode({
          'introSeen': introSeen,
          'langChosen': langChosen,
          'consent': consent,
          'saveHistory': saveHistory,
          'lang': lang,
          'plan': plan,
          'used': used,
          'profiles': profiles.map((p) => p.toJson()).toList(),
          'active': active,
        }));
    notifyListeners();
  }

  void _saveHistory() {
    _p?.setString('history', jsonEncode(history.take(50).map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  String profName(String id) =>
      profiles.firstWhere((p) => p.id == id, orElse: () => Profile('me', 'Me')).name;

  int get maxProfiles => plan == 'family' ? 6 : 2;
  int get freeLeft => (freeLimit - used).clamp(0, freeLimit);
  bool get canExplain => plan != 'free' || used < freeLimit;

  void upsertEntry(Entry e) {
    if (!saveHistory) return;
    history.removeWhere((h) => h.id == e.id);
    history.insert(0, e);
    _saveHistory();
  }

  void deleteEntry(String id) {
    history.removeWhere((h) => h.id == id);
    if (current?.id == id) current = null;
    _saveHistory();
  }

  void openEntry(Entry? e) {
    current = e;
    tab = 0;
    notifyListeners();
  }

  void setTab(int t) {
    tab = t;
    notifyListeners();
  }

  Future<void> wipe() async {
    await _p?.clear();
    introSeen = false;
    langChosen = false;
    consent = false;
    saveHistory = false;
    lang = 'English';
    plan = 'free';
    used = 0;
    profiles = [Profile('me', 'Me')];
    active = 'me';
    history = [];
    current = null;
    tab = 0;
    notifyListeners();
  }

  void touch() => notifyListeners();
}

String fmtDate(int ms) {
  if (ms <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${m[d.month - 1]} ${d.day}, ${d.year}';
}

