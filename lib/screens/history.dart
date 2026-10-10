import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

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
        return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
          const AppHeader(),
          const SizedBox(height: 14),
          const Text('History', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
          Text(s.saveHistory ? 'Saved privately on this phone' : 'History is off', style: const TextStyle(color: C.muted)),
          const SizedBox(height: 16),
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
            for (final e in s.history)
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
