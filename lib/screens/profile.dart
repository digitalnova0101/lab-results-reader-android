import 'package:flutter/material.dart';

import '../account.dart';
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

  Widget _accountGroup(BuildContext context, AppState s) {
    if (!s.signedIn) {
      return _group([
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
              SizedBox(width: 6),
              Text('(optional)', style: TextStyle(color: C.muted, fontSize: 13)),
            ]),
            const SizedBox(height: 2),
            const Text('Keep your plan and saved summaries on all your devices. Everything works without signing in.',
                style: TextStyle(color: C.muted, fontSize: 13.5)),
            const SizedBox(height: 12),
            const _GoogleButton(),
          ]),
        ),
      ]);
    }
    final a = s.account ?? {};
    final name = '${a['name'] ?? ''}'.trim();
    final email = '${a['email'] ?? ''}';
    final pic = '${a['picture'] ?? ''}';
    final initial = (name.isNotEmpty ? name : (email.isNotEmpty ? email : '?'))[0].toUpperCase();
    return _group([
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: C.accent,
            foregroundImage: pic.startsWith('https://') ? NetworkImage(pic) : null,
            child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? 'Signed in' : name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
              Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 13.5)),
              const SizedBox(height: 2),
              const Row(children: [
                Icon(Icons.cloud_done_rounded, size: 15, color: C.accent),
                SizedBox(width: 4),
                Text('Plan and summaries synced', style: TextStyle(color: C.accent, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
          GhostButton(label: 'Sign out', onPressed: () => _signOut(context)),
        ]),
      ),
      _row('Delete my account', 'Removes your account and every summary saved in it',
          GhostButton(label: 'Delete', onPressed: () => _deleteAccount(context))),
    ]);
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text("Your plan and saved summaries stay in your Google account. They'll be removed from this phone until you sign in again."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) await Account.signOut();
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
            "This permanently deletes your account, its plan, and every summary saved in it. A Google Play subscription must be canceled in Google Play. This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: C.bad), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete account')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await Account.deleteAccount();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Your account has been deleted.')));
    }
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
          if (s.signedIn || s.googleClientId.isNotEmpty) ...[
            _label('ACCOUNT'),
            _accountGroup(context, s),
          ],
          _label('PLAN & REPORTS'),
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
            _row('Save to history', s.signedIn ? 'Summaries are saved to your account. Photos are never kept.' : 'Keep summaries on this phone. Photos are never kept.',
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

class _GoogleButton extends StatefulWidget {
  const _GoogleButton();
  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  bool busy = false;

  Future<void> _go() async {
    setState(() => busy = true);
    final err = await Account.signIn();
    if (!mounted) return;
    setState(() => busy = false);
    final msg = err ?? (AppState.I.signedIn ? 'Signed in as ${AppState.I.account?['email'] ?? 'your Google account'}' : null);
    if (msg != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: busy ? null : _go,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: const BorderSide(color: C.line, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
          foregroundColor: Colors.black87,
          backgroundColor: Colors.white,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (busy)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            const _GLogo(),
          const SizedBox(width: 10),
          Text(busy ? 'Signing in…' : 'Sign in with Google', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ]),
      ),
    );
  }
}

/// Google "G" mark drawn with four arcs (official brand colors).
class _GLogo extends StatelessWidget {
  const _GLogo();
  @override
  Widget build(BuildContext context) => const SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GPainter()));
}

class _GPainter extends CustomPainter {
  const _GPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.2;
    final r = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    Paint p(int c) => Paint()
      ..color = Color(c)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    const d = 3.14159265 / 180;
    canvas.drawArc(r, -40 * d, -95 * d, false, p(0xFFEA4335)); // red, top
    canvas.drawArc(r, -135 * d, -90 * d, false, p(0xFFFBBC05)); // yellow, left
    canvas.drawArc(r, -225 * d, -95 * d, false, p(0xFF34A853)); // green, bottom
    canvas.drawArc(r, -320 * d, -40 * d, false, p(0xFF4285F4)); // blue, right
    final y = size.height / 2;
    canvas.drawLine(Offset(size.width / 2, y), Offset(size.width - w / 2, y), p(0xFF4285F4)..strokeCap = StrokeCap.butt);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
