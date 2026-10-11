import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Free reports per phone. The real number comes from the server (FREE_REPORTS in config.php).
int get freeLimit => AppState.I.limit;
const String appVersion = '2.5';

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
  int limit = 3;
  int planUntil = 0; // seconds
  String planSource = ''; // 'play' or 'code'
  // Optional Google account
  Map<String, dynamic>? account; // {email, name, picture} when signed in
  String googleClientId = ''; // from the server; empty = sign-in turned off
  List<String> pendingUp = []; // summaries saved but not uploaded yet
  List<String> pendingDel = [];
  bool get signedIn => Api.auth.isNotEmpty;
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
      limit = (s['limit'] as num?)?.toInt() ?? 3;
      planUntil = (s['planUntil'] as num?)?.toInt() ?? 0;
      planSource = '${s['planSource'] ?? ''}';
      googleClientId = '${s['googleClientId'] ?? ''}';
      Api.auth = '${s['auth'] ?? ''}';
      account = Api.auth.isEmpty ? null : (s['account'] is Map ? Map<String, dynamic>.from(s['account'] as Map) : {});
      pendingUp = ((s['pendingUp'] as List?) ?? []).map((e) => '$e').toList();
      pendingDel = ((s['pendingDel'] as List?) ?? []).map((e) => '$e').toList();
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
    await _initDevice();
    notifyListeners();
  }

  /// A stable anonymous id: Android ID (survives reinstall), else a random id kept on the phone.
  Future<void> _initDevice() async {
    String id = '';
    try {
      id = (await const AndroidId().getId()) ?? '';
    } catch (_) {}
    if (id.isEmpty) {
      id = _p!.getString('device_id') ?? '';
      if (id.isEmpty) {
        final r = Random.secure();
        id = List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
        await _p!.setString('device_id', id);
      }
    } else {
      id = 'a-$id';
    }
    Api.device = id;
  }

  /// Applies the plan/usage the server sent back.
  void applyStatus(dynamic st) {
    if (st is! Map) return;
    plan = '${st['plan'] ?? 'free'}';
    used = (st['used'] as num?)?.toInt() ?? used;
    limit = (st['free_limit'] as num?)?.toInt() ?? limit;
    planUntil = (st['plan_until'] as num?)?.toInt() ?? 0;
    planSource = '${st['plan_source'] ?? ''}';
    if (st.containsKey('google_client_id')) googleClientId = '${st['google_client_id'] ?? ''}';
    if (st.containsKey('account')) {
      if (st['account'] is Map) {
        account = Map<String, dynamic>.from(st['account'] as Map);
      } else if (signedIn) {
        _clearAuth(); // the session ended on the server
      }
    }
    save();
  }

  void setAuth(String token, dynamic acct) {
    Api.auth = token;
    account = acct is Map ? Map<String, dynamic>.from(acct) : {};
    save();
  }

  void _clearAuth() {
    Api.auth = '';
    account = null;
    pendingUp = [];
    pendingDel = [];
  }

  /// Signed out on this phone: summaries stay in the account, and leave this phone.
  void signedOutLocally() {
    _clearAuth();
    history = [];
    current = null;
    _saveHistory();
    save();
  }

  Future<void>? _syncing;

  /// Uploads summaries saved on this phone and pulls the ones saved on other devices.
  Future<void> syncHistory() {
    if (!signedIn) return Future.value();
    return _syncing ??= _doSync().whenComplete(() => _syncing = null);
  }

  Future<void> _doSync() async {
    final ids = pendingUp.toSet();
    final dels = List<String>.from(pendingDel);
    try {
      final d = await Api.post({
        'action': 'history_sync',
        'entries': history.where((e) => ids.contains(e.id)).map((e) => e.toJson()).toList(),
        'deleted': dels,
      });
      pendingUp.removeWhere(ids.contains);
      pendingDel.removeWhere(dels.contains);
      final h = d['history'];
      if (h is List) {
        history = h.whereType<Map>().map((e) => Entry.fromJson(Map<String, dynamic>.from(e))).toList();
        _saveHistory();
      }
      applyStatus(d['status']);
    } on ApiError catch (e) {
      if (e.code == 'signed_out') signedOutLocally();
    } catch (_) {}
  }

  Timer? _syncTimer;
  void _queueSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 800), () => syncHistory());
  }

  /// Asks the server for this phone's plan and free reports left.
  Future<void> syncStatus() async {
    try {
      final d = await Api.post({'action': 'status'});
      applyStatus(d['status']);
    } catch (_) {}
  }

  String get planName => plan == 'family' ? 'Family' : (plan == 'plus' ? 'Plus' : 'Free');
  String get planUntilText {
    if (plan == 'free' || planUntil <= 0 || planUntil > 3000000000) return '';
    return fmtDate(planUntil * 1000);
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
          'limit': limit,
          'planUntil': planUntil,
          'planSource': planSource,
          'googleClientId': googleClientId,
          'auth': Api.auth,
          'account': account,
          'pendingUp': pendingUp,
          'pendingDel': pendingDel,
          'profiles': profiles.map((p) => p.toJson()).toList(),
          'active': active,
        }));
    notifyListeners();
  }

  void _saveHistory() {
    _p?.setString('history', jsonEncode(history.take(200).map((e) => e.toJson()).toList()));
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
    if (signedIn) {
      if (!pendingUp.contains(e.id)) pendingUp.add(e.id);
      save();
      _queueSync();
    }
  }

  void deleteEntry(String id) {
    history.removeWhere((h) => h.id == id);
    if (current?.id == id) current = null;
    _saveHistory();
    if (signedIn) {
      pendingUp.remove(id);
      pendingDel.add(id);
      save();
      syncHistory();
    }
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
    if (signedIn) {
      try {
        await Api.post({'action': 'signout'});
      } catch (_) {}
      _clearAuth();
    }
    final dev = _p?.getString('device_id');
    await _p?.clear();
    if (dev != null) await _p?.setString('device_id', dev);
    introSeen = false;
    langChosen = false;
    consent = false;
    saveHistory = false;
    lang = 'English';
    profiles = [Profile('me', 'Me')];
    active = 'me';
    history = [];
    current = null;
    tab = 0;
    notifyListeners();
    syncStatus();
  }

  void touch() => notifyListeners();
}

String fmtDate(int ms) {
  if (ms <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${m[d.month - 1]} ${d.day}, ${d.year}';
}

