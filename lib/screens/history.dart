import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _q = TextEditingController();
  String q = '';

  @override
  void initState() {
    super.initState();
    AppState.I.syncHistory(); // pull summaries saved on other devices
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  /// Matches the report title, the person, the date, the overall result, or any test name.
  bool _match(Entry e, AppState s) {
    if (q.isEmpty) return true;
    final b = StringBuffer('${e.title} ${s.profName(e.profileId)} ${fmtDate(e.createdAt)} ${labelOf[norm(e.result['overall'])]} ');
    for (final r in (e.result['reports'] as List? ?? []).whereType<Map>()) {
      b.write('${r['title']} ');
      for (final it in (r['items'] as List? ?? []).whereType<Map>()) {
        b.write('${it['name']} ');
      }
    }
    final hay = b.toString().toLowerCase();
    return q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every(hay.contains);
  }

  Future<void> _confirmDelete(BuildContext context, Entry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this report?'),
        content: Text(e.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) AppState.I.deleteEntry(e.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final s = AppState.I;
        final list = s.history.where((e) => _match(e, s)).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
          const AppHeader(),
          const SizedBox(height: 14),
          const Text('History', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
          Text(
              s.signedIn
                  ? 'Saved to your account · on all your devices'
                  : (s.saveHistory ? 'Saved privately on this phone' : 'History is off'),
              style: const TextStyle(color: C.muted)),
          const SizedBox(height: 16),
          if (s.history.isNotEmpty) ...[
            TextField(
              controller: _q,
              onChanged: (v) => setState(() => q = v.trim()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search reports, tests or names',
                prefixIcon: const Icon(Icons.search_rounded, color: C.muted),
                suffixIcon: q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, color: C.muted),
                        onPressed: () => setState(() {
                          _q.clear();
                          q = '';
                        }),
                      ),
                filled: true,
                fillColor: C.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.accent, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No reports match "$q"', textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
              ),
          ],
          if (s.history.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: cardDeco(),
              child: Column(children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: C.accentSoft, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.description_outlined, color: C.accent, size: 28),
                ),
                const SizedBox(height: 12),
                Text(s.saveHistory ? 'No reports yet' : 'History is turned off',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  s.saveHistory ? 'Your report summaries will appear here.' : 'Turn on Save to history in Profile to keep your summaries.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: C.muted),
                ),
              ]),
            )
          else
            for (final e in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => s.openEntry(e),
                    child: Ink(
                      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                      decoration: cardDeco(),
                      child: Row(children: [
                        Builder(builder: (_) {
                          final st = norm(e.result['overall']);
                          return Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(color: C.softOf(st), borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.description_outlined, color: C.of(st)),
                          );
                        }),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            Text('${s.profName(e.profileId)} · ${fmtDate(e.createdAt)} · ${labelOf[norm(e.result['overall'])]}',
                                style: const TextStyle(color: C.muted, fontSize: 13)),
                          ]),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline_rounded, color: C.muted),
                          onPressed: () => _confirmDelete(context, e),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
        ]);
      },
    );
  }
}
