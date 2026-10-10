import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';

/// "Tap to learn": what a test is, why it's done, and what can make it high or low.
final Map<String, Map<String, dynamic>> _cache = {};

void showLearnSheet(BuildContext context, String testName, String lang) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _LearnSheet(testName: testName, lang: lang),
  );
}

class _LearnSheet extends StatefulWidget {
  const _LearnSheet({required this.testName, required this.lang});
  final String testName;
  final String lang;
  @override
  State<_LearnSheet> createState() => _LearnSheetState();
}

class _LearnSheetState extends State<_LearnSheet> {
  Map<String, dynamic>? _data;
  String? _err;

  String get _key => '${widget.lang}|${widget.testName.toLowerCase()}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hit = _cache[_key];
    if (hit != null) {
      setState(() => _data = hit);
      return;
    }
    setState(() => _err = null);
    try {
      final res = await Api.post({'action': 'learn', 'lang': widget.lang, 'test': widget.testName});
      final d = Map<String, dynamic>.from(res['info'] as Map);
      _cache[_key] = d;
      if (mounted) setState(() => _data = d);
    } on ApiError catch (e) {
      if (mounted) setState(() => _err = errorText(e));
    } catch (_) {
      if (mounted) setState(() => _err = 'Something went wrong. Please try again.');
    }
  }

  Widget _section(IconData icon, Color color, String title, String body) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
            const SizedBox(height: 2),
            Text(body, style: const TextStyle(color: C.ink2, fontSize: 15, height: 1.5)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(20, 10, 20, 28), children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(99)))),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: C.accentSoft, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.science_outlined, color: C.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${d?['title'] ?? widget.testName}',
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.2)),
          ),
        ]),
        if (d == null && _err == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: C.accent)),
          ),
        if (_err != null) ...[
          const SizedBox(height: 20),
          Text(_err!, style: const TextStyle(color: C.bad)),
          const SizedBox(height: 12),
          GhostButton(label: 'Try again', onPressed: _load),
        ],
        if (d != null) ...[
          _section(Icons.info_outline_rounded, C.accent, 'What it measures', '${d['what'] ?? ''}'),
          _section(Icons.help_outline_rounded, C.accent2, 'Why it\'s tested', '${d['why'] ?? ''}'),
          _section(Icons.arrow_upward_rounded, C.warn, 'What can make it high', '${d['high'] ?? ''}'),
          _section(Icons.arrow_downward_rounded, const Color(0xFF2F5FA8), 'What can make it low', '${d['low'] ?? ''}'),
          _section(Icons.lightbulb_outline_rounded, C.ok, 'Good to know', '${d['tip'] ?? ''}'),
          const SizedBox(height: 20),
          const Text('General information for education only. Ask your doctor what your result means for you.',
              style: TextStyle(color: C.muted, fontSize: 12.5)),
        ],
      ]),
    );
  }
}
