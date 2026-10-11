import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import 'home.dart' show addProfileDialog;
import 'legal.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(t, style: const TextStyle(color: C.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.7)),
      );

  Widget _group(List<Widget> rows) {
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) out.add(const Divider(height: 1, color: C.line));
      out.add(rows[i]);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: cardDeco(),
      child: Column(children: out),
    );
  }

  Widget _row(String title, String sub, Widget? trailing) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(color: C.muted, fontSize: 13.5)),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing],
        ]),
      );

  Future<void> _manageProfiles(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => ListenableBuilder(
        listenable: AppState.I,
        builder: (ctx, _) {
          final s = AppState.I;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Family profiles', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${s.profiles.length} of ${s.maxProfiles} on your plan', style: const TextStyle(color: C.muted)),
                const SizedBox(height: 10),
                for (final p in s.profiles)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: C.accentSoft,
                      child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase(), style: const TextStyle(color: C.accent, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(p.name),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          final ctrl = TextEditingController(text: p.name);
                          final n = await showDialog<String>(
                            context: ctx,
                            builder: (d) => AlertDialog(
                              title: const Text('Rename'),
                              content: TextField(controller: ctrl, autofocus: true, maxLength: 24),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(d, ctrl.text.trim()), child: const Text('Save')),
                              ],
                            ),
                          );
                          if (n != null && n.isNotEmpty) {
                            p.name = n;
                            s.save();
                          }
                        },
                      ),
                      if (p.id != 'me')
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () {
                            s.profiles.removeWhere((x) => x.id == p.id);
                            if (s.active == p.id) s.active = 'me';
                            s.save();
                          },
                        ),
                    ]),
                  ),
                const SizedBox(height: 8),
                GhostButton(label: 'Add family member', icon: Icons.add_rounded, expand: true, onPressed: () => addProfileDialog(ctx)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _wipe(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all your data?'),
        content: const Text('This removes every saved summary, your profiles and settings. It can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: C.bad), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete everything')),
        ],
      ),
    );
    if (ok == true) await AppState.I.wipe();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final s = AppState.I;
        final name = s.profName(s.active);
        return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
          const AppHeader(),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [C.accent, C.accent2], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Text(name.isEmpty ? 'M' : name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: C.accentSoft, borderRadius: BorderRadius.circular(99)),
                child: Text(s.plan == 'free' ? 'FREE PLAN' : (s.plan == 'family' ? 'FAMILY PLAN' : 'PLUS PLAN'),
                    style: const TextStyle(color: C.accent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              ),
            ]),
          ]),
          _label('ACCOUNT'),
          _group([
            _row('Plan', s.plan == 'free' ? '${s.freeLeft} of $freeLimit free reports left' : '${s.planName} · Unlimited reports${s.planUntilText.isNotEmpty ? ' · until ${s.planUntilText}' : ''}',
                GhostButton(label: s.plan == 'free' ? 'Upgrade' : 'Manage', onPressed: () => openPlans(context))),
            _row('Have a code?', 'Redeem a gift or promo code', GhostButton(label: 'Redeem', onPressed: () => redeemDialog(context))),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Report language', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                const SizedBox(height: 2),
                const Text('Explanations are written in this language', style: TextStyle(color: C.muted, fontSize: 13.5)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: langs.any((l) => l[0] == s.lang) ? s.lang : 'English',
                      items: [
                        for (final l in langs)
                          DropdownMenuItem(value: l[0], child: Text(l[0] == l[1] ? l[0] : '${l[1]} (${l[0]})')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        s.lang = v;
                        s.save();
                      },
                    ),
                  ),
                ),
              ]),
            ),
            _row('Family profiles', s.profiles.map((p) => p.name).join(', '),
                GhostButton(label: 'Manage', onPressed: () => _manageProfiles(context))),
          ]),
          _label('PRIVACY'),
          _group([
            _row('Save to history', 'Keep summaries on this phone. Photos are never kept.',
                Switch(value: s.saveHistory, activeColor: C.accent, onChanged: (v) {
                  s.saveHistory = v;
                  s.save();
                })),
            _row('Delete all my data', 'Removes every saved summary and resets the app',
                GhostButton(label: 'Delete', onPressed: () => _wipe(context))),
            _row('Legal', 'How we handle your data',
                Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(onPressed: () => openLegal(context, 'privacy'), child: const Text('Privacy', style: TextStyle(color: C.accent))),
                  TextButton(onPressed: () => openLegal(context, 'terms'), child: const Text('Terms', style: TextStyle(color: C.accent))),
                ])),
          ]),
          const SizedBox(height: 18),
          const Text('Lab Results Reader · Flutter app v$appVersion', textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 12.5)),
        ]);
      },
    );
  }
}
