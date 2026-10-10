import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';

const _order = {'bad': 0, 'warn': 1, 'ok': 2};

double? _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

Entry sampleEntry() => Entry(
      id: 'sample',
      createdAt: 0,
      lang: 'English',
      profileId: 'me',
      title: 'Lipid Panel, CBC & Vitamin D',
      result: {
        'title': 'Lipid Panel, CBC & Vitamin D',
        'overall': 'warn',
        'summary':
            'Most of your blood work is in range. Your LDL ("bad") cholesterol is high and your vitamin D is low. Neither is urgent, but both are worth bringing up at your next visit.',
        'urgent': '',
        'reports': [
          {
            'title': 'Lipid Panel (cholesterol)',
            'status': 'warn',
            'summary': 'LDL is above the goal; the rest looks fine.',
            'items': [
              {'name': 'LDL cholesterol ("bad")', 'value': '162 mg/dL', 'range': '< 100 mg/dL', 'num': 162, 'low': null, 'high': 100, 'status': 'warn', 'meaning': 'Too much of this type can build up in artery walls over time.'},
              {'name': 'HDL cholesterol ("good")', 'value': '52 mg/dL', 'range': '> 40 mg/dL', 'num': 52, 'low': 40, 'high': null, 'status': 'ok', 'meaning': 'Helps clear cholesterol from your blood.'},
              {'name': 'Triglycerides', 'value': '138 mg/dL', 'range': '< 150 mg/dL', 'num': 138, 'low': null, 'high': 150, 'status': 'ok', 'meaning': 'Blood fats from food. In the healthy range.'},
            ],
          },
          {
            'title': 'Vitamin D, 25-OH',
            'status': 'warn',
            'summary': 'Below the sufficient range.',
            'items': [
              {'name': 'Vitamin D', 'value': '19 ng/mL', 'range': '30–100 ng/mL', 'num': 19, 'low': 30, 'high': 100, 'status': 'warn', 'meaning': 'Low levels are common and usually treated with supplements.'},
            ],
          },
        ],
        'questions': [
          'Is my LDL high enough to need medication, or should I try diet and exercise first?',
          'Should I take a vitamin D supplement, and how much?',
          'When should I repeat these tests?',
        ],
      },
    );

class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.entry, required this.onNew});
  final Entry entry;
  final VoidCallback onNew;

  bool get isSample => entry.id == 'sample';

  @override
  Widget build(BuildContext context) {
    final r = entry.result;
    final reports = (r['reports'] as List? ?? []).whereType<Map>().toList();
    final counts = {'ok': 0, 'warn': 0, 'bad': 0};
    for (final rep in reports) {
      for (final it in (rep['items'] as List? ?? []).whereType<Map>()) {
        counts[norm(it['status'])] = counts[norm(it['status'])]! + 1;
      }
    }
    final overall = norm(r['overall']);
    final urgent = '${r['urgent'] ?? ''}'.trim();
    final questions = (r['questions'] as List? ?? []).map((e) => '$e').toList();
    final s = AppState.I;

    return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
      const AppHeader(),
      const SizedBox(height: 6),
      Row(children: [
        TextButton.icon(
          onPressed: onNew,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: C.accent),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          label: const Text('New report', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
        const Spacer(),
        if (!isSample)
          GhostButton(
            label: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _toText(r)));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Summary copied')));
            },
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: C.accentSoft, borderRadius: BorderRadius.circular(99)),
            child: const Text('EXAMPLE', style: TextStyle(color: C.accent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          ),
      ]),
      const SizedBox(height: 6),
      Text(entry.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.15)),
      const SizedBox(height: 2),
      Text(isSample ? 'Sample with made-up numbers' : '${s.profName(entry.profileId)} · ${fmtDate(entry.createdAt)}',
          style: const TextStyle(color: C.muted)),
      const SizedBox(height: 14),
      if (!isSample) ...[
        PrimaryButton(label: '+ Check a new report', onPressed: onNew),
        const SizedBox(height: 14),
      ],
      // Summary card with ring
      Container(
        padding: const EdgeInsets.all(18),
        decoration: cardDeco(),
        child: Wrap(spacing: 18, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (counts.values.fold(0, (a, b) => a + b) > 0) _Donut(counts: counts),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 560),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(verdictOf[overall]!, style: TextStyle(color: C.of(overall), fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('${r['summary'] ?? ''}', style: const TextStyle(fontSize: 15.5, height: 1.5)),
              const SizedBox(height: 10),
              Wrap(spacing: 12, runSpacing: 4, children: [
                for (final k in ['ok', 'warn', 'bad'])
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 9, height: 9, decoration: BoxDecoration(color: C.of(k), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('${counts[k]} ${labelOf[k]}', style: const TextStyle(color: C.muted, fontSize: 13)),
                  ]),
              ]),
            ]),
          ),
        ]),
      ),
      if (urgent.isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.badSoft, borderRadius: BorderRadius.circular(14)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.warning_amber_rounded, color: C.bad),
            const SizedBox(width: 10),
            Expanded(child: Text(urgent, style: const TextStyle(color: C.bad, fontWeight: FontWeight.w600, height: 1.45))),
          ]),
        ),
      ],
      for (final rep in reports) ...[const SizedBox(height: 14), _ReportCard(rep: Map<String, dynamic>.from(rep))],
      if (questions.isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: cardDeco(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Questions for your doctor', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (var i = 0; i < questions.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 22, child: Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w600))),
                  Expanded(child: Text(questions[i], style: const TextStyle(height: 1.45))),
                ]),
              ),
          ]),
        ),
      ],
      if (!isSample) ...[const SizedBox(height: 14), ChatPanel(entry: entry)],
      if (isSample) ...[const SizedBox(height: 14), PrimaryButton(label: 'Upload your own report', onPressed: onNew)],
      const SizedBox(height: 16),
      const Text(
        'For educational use only. This is not medical advice or a diagnosis. Always confirm results with your original report and your doctor. If this is an emergency, call 911.',
        textAlign: TextAlign.center,
        style: TextStyle(color: C.muted, fontSize: 12.5, height: 1.5),
      ),
    ]);
  }

  static String _toText(Map<String, dynamic> d) {
    final b = StringBuffer('${d['title'] ?? 'Report'}\n\n${d['summary'] ?? ''}\n');
    if ('${d['urgent'] ?? ''}'.isNotEmpty) b.write('\n⚠ ${d['urgent']}\n');
    for (final r in (d['reports'] as List? ?? []).whereType<Map>()) {
      b.write('\n${r['title']}: ${r['summary'] ?? ''}\n');
      for (final i in (r['items'] as List? ?? []).whereType<Map>()) {
        b.write('- ${i['name']}: ${i['value']}${i['range'] != null ? ' (normal ${i['range']})' : ''} — ${i['meaning'] ?? ''}\n');
      }
    }
    final q = (d['questions'] as List? ?? []);
    if (q.isNotEmpty) {
      b.write('\nQuestions for my doctor:\n');
      for (var i = 0; i < q.length; i++) {
        b.write('${i + 1}. ${q[i]}\n');
      }
    }
    b.write('\n(Explained by Lab Results Reader — for education only.)');
    return b.toString();
  }
}

/* ---------- summary ring ---------- */

class _Donut extends StatelessWidget {
  const _Donut({required this.counts});
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: const Size(112, 112), painter: _DonutPainter(counts)),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$total', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1)),
          const Text('results', style: TextStyle(fontSize: 12, color: C.muted)),
        ]),
      ]),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.counts);
  final Map<String, int> counts;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..color = C.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) return;
    final gap = total > 1 ? 0.06 : 0.0;
    double start = -math.pi / 2;
    for (final k in ['ok', 'warn', 'bad']) {
      final n = counts[k] ?? 0;
      if (n == 0) continue;
      final sweep = math.pi * 2 * n / total;
      final p = Paint()
        ..color = C.of(k)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start + gap / 2, math.max(sweep - gap, 0.01), false, p);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.counts != counts;
}

/* ---------- report card ---------- */

class _ReportCard extends StatefulWidget {
  const _ReportCard({required this.rep});
  final Map<String, dynamic> rep;
  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool showNormal = false;

  @override
  Widget build(BuildContext context) {
    final rep = widget.rep;
    final st = norm(rep['status']);
    final items = (rep['items'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      ..sort((a, b) => _order[norm(a['status'])]!.compareTo(_order[norm(b['status'])]!));
    final flagged = items.where((i) => norm(i['status']) != 'ok').toList();
    final normal = items.where((i) => norm(i['status']) == 'ok').toList();
    final label = flagged.isNotEmpty
        ? 'Show ${normal.length} in-range result${normal.length > 1 ? 's' : ''}'
        : 'All ${normal.length} result${normal.length > 1 ? 's' : ''} in range · show';

    return Container(
      decoration: cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${rep['title'] ?? 'Report'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3)),
                if ('${rep['summary'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('${rep['summary']}', style: const TextStyle(color: C.muted, height: 1.45)),
                ],
              ]),
            ),
            const SizedBox(width: 10),
            Chip2(st),
          ]),
        ),
        for (final i in flagged) _ItemRow(item: i),
        if (normal.isNotEmpty) ...[
          InkWell(
            onTap: () => setState(() => showNormal = !showNormal),
            child: Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(children: [
                Expanded(
                  child: Text(showNormal ? 'Hide in-range results' : label,
                      style: const TextStyle(color: C.accent, fontWeight: FontWeight.w600)),
                ),
                Icon(showNormal ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: C.accent),
              ]),
            ),
          ),
          if (showNormal) for (final i in normal) _ItemRow(item: i),
        ],
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final Map<String, dynamic> item;

  bool _isLong(String v) {
    final stripped = v.replaceAll(RegExp(r'(mg|dl|mmol|mm|cm|ml|ng|pg|iu|miu|meq|u/l|g/dl|k/µl|µl|hpf|%)', caseSensitive: false), '');
    return v.length > 14 || RegExp(r'[a-zA-Z]{4,}').hasMatch(stripped);
  }

  @override
  Widget build(BuildContext context) {
    final st = norm(item['status']);
    final value = '${item['value'] ?? '—'}';
    final name = Text('${item['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, height: 1.35));
    final valStyle = TextStyle(color: st == 'ok' ? C.ink : C.of(st), fontWeight: FontWeight.w800, fontSize: 16, height: 1.35);
    final long = _isLong(value);
    final bar = _RangeBar.maybe(item);

    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (long) ...[
          name,
          const SizedBox(height: 2),
          Text(value, style: valStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
        ] else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: name),
            const SizedBox(width: 12),
            Text(value, style: valStyle, textAlign: TextAlign.right),
          ]),
        const SizedBox(height: 6),
        if (bar != null)
          bar
        else if ('${item['range'] ?? ''}'.isNotEmpty)
          Text('Reference range: ${item['range']}', style: const TextStyle(color: C.muted, fontSize: 12.5)),
        if ('${item['meaning'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${item['meaning']}', style: const TextStyle(color: C.muted, fontSize: 14.5, height: 1.45)),
        ],
      ]),
    );
  }
}

/* ---------- range bar ---------- */

class _RangeBar extends StatelessWidget {
  const _RangeBar(this.v, this.lo, this.hi, this.status);
  final double v;
  final double? lo, hi;
  final String status;

  static Widget? maybe(Map<String, dynamic> it) {
    final v = _num(it['num']), lo = _num(it['low']), hi = _num(it['high']);
    if (v == null || (lo == null && hi == null)) return null;
    return _RangeBar(v, lo, hi, norm(it['status']));
  }

  String _fmt(double n) => n.abs() >= 100 ? n.round().toString() : ((n * 10).round() / 10).toString().replaceAll(RegExp(r'\.0$'), '');

  @override
  Widget build(BuildContext context) {
    double mn, mx;
    if (lo != null && hi != null) {
      final sp = (hi! - lo!) == 0 ? (hi!.abs() == 0 ? 1.0 : hi!.abs()) : (hi! - lo!);
      mn = lo! - sp * 0.6;
      mx = hi! + sp * 0.6;
    } else if (hi != null) {
      mn = 0;
      mx = math.max(hi! * 1.6, hi! + 1);
    } else {
      mn = 0;
      mx = math.max(lo! * 2.2, lo! + 1);
    }
    final pad = (mx - mn) * 0.06;
    mn = math.min(mn, v - pad);
    mx = math.max(mx, v + pad);
    if (v >= 0 && (lo == null || lo! >= 0)) mn = math.max(mn, 0);
    double pct(double x) => ((x - mn) / (mx - mn)).clamp(0.0, 1.0);

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final a = pct(lo ?? mn) * w, b = pct(hi ?? mx) * w;
      final dot = (pct(v) * w).clamp(9.0, w - 9);
      return SizedBox(
        height: 32,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: 0, right: 0, top: 8, child: Container(height: 8, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(99)))),
          Positioned(
            left: a,
            width: math.max(b - a, 2),
            top: 8,
            child: Container(height: 8, decoration: BoxDecoration(color: const Color(0x591C7A4A), borderRadius: BorderRadius.circular(99))),
          ),
          for (final t in [lo, hi])
            if (t != null)
              Positioned(
                left: (pct(t) * w).clamp(10.0, w - 10) - 20,
                width: 40,
                top: 19,
                child: Text(_fmt(t), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: C.muted)),
              ),
          Positioned(
            left: dot - 9,
            top: 3,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: C.of(status),
                shape: BoxShape.circle,
                border: Border.all(color: C.surface, width: 3),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))],
              ),
            ),
          ),
        ]),
      );
    });
  }
}

/* ---------- follow-up chat ---------- */

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.entry});
  final Entry entry;
  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  String? _err;

  Future<void> _send(String q) async {
    q = q.trim();
    if (q.isEmpty || _sending) return;
    final e = widget.entry;
    setState(() {
      _sending = true;
      _err = null;
      e.chat.add({'role': 'user', 'content': q});
    });
    _ctrl.clear();
    try {
      final data = await Api.post({
        'action': 'chat',
        'lang': e.lang,
        'result': e.result,
        'messages': e.chat.length > 10 ? e.chat.sublist(e.chat.length - 10) : e.chat,
      });
      setState(() => e.chat.add({'role': 'assistant', 'content': '${data['text'] ?? ''}'}));
      AppState.I.upsertEntry(e);
    } on ApiError catch (err) {
      setState(() {
        e.chat.removeLast();
        if (err.code != 'cancelled') _err = errorText(err);
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.entry.chat;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ask a follow-up question', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final m in chat)
          Align(
            alignment: m['role'] == 'user' ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 300),
              decoration: BoxDecoration(
                color: m['role'] == 'user' ? C.accent : C.bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(m['content'] ?? '', style: TextStyle(color: m['role'] == 'user' ? Colors.white : C.ink, height: 1.45)),
            ),
          ),
        if (_sending)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Thinking…', style: TextStyle(color: C.muted)),
          ),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final q in ['Should I be worried?', 'What can I do to improve this?', 'What does my main result mean?'])
            ActionChip(
              label: Text(q, style: const TextStyle(fontSize: 13)),
              backgroundColor: C.surface,
              shape: const StadiumBorder(side: BorderSide(color: C.line)),
              onPressed: () => _send(q),
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              decoration: InputDecoration(
                hintText: 'Ask anything about your results',
                filled: true,
                fillColor: C.bg,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _sending ? null : () => _send(_ctrl.text),
            style: FilledButton.styleFrom(
              backgroundColor: C.accent,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ask'),
          ),
        ]),
        if (_err != null) ...[const SizedBox(height: 8), Text(_err!, style: const TextStyle(color: C.bad))],
      ]),
    );
  }
}
