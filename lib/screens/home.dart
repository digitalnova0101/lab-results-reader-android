import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import 'legal.dart';
import 'result.dart';

const int maxPages = 8;

class PageFile {
  PageFile(this.bytes, this.mime, this.label);
  final Uint8List bytes;
  final String mime;
  final String label; // "Photo" or "PDF"
}

String sniffMime(Uint8List b) {
  if (b.length > 4 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
  if (b.length > 12 && String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') return 'image/webp';
  if (b.length > 12) {
    final brand = String.fromCharCodes(b.sublist(4, 12));
    if (brand.startsWith('ftyphei') || brand.startsWith('ftypheic') || brand.startsWith('ftypmif1') || brand.startsWith('ftyphe')) {
      return 'image/heic';
    }
  }
  if (b.length > 4 && String.fromCharCodes(b.sublist(0, 4)) == '%PDF') return 'application/pdf';
  return 'image/jpeg';
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final List<PageFile> _pages = [];
  final _picker = ImagePicker();
  bool _busy = false;
  int _step = 0;
  final List<Timer> _timers = [];
  String? _error;

  AppState get s => AppState.I;

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _err(String? m) => setState(() => _error = m);

  bool _room() {
    if (_pages.length >= maxPages) {
      _err('You can add up to $maxPages pages per report.');
      return false;
    }
    return true;
  }

  Future<void> _pickPhotos() async {
    _err(null);
    try {
      final files = await _picker.pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
      for (final f in files) {
        if (!_room()) break;
        final b = await f.readAsBytes();
        _pages.add(PageFile(b, sniffMime(b), 'Photo'));
      }
      setState(() {});
    } catch (_) {
      _err("Couldn't open your photos. Please try again.");
    }
  }

  Future<void> _takePhoto() async {
    _err(null);
    if (!_room()) return;
    try {
      final f = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
      if (f == null) return;
      final b = await f.readAsBytes();
      setState(() => _pages.add(PageFile(b, sniffMime(b), 'Photo')));
    } catch (_) {
      _err("Couldn't open the camera. Please allow camera access and try again.");
    }
  }

  Future<void> _pickPdf() async {
    _err(null);
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      for (final f in files) {
        if (!_room()) break;
        final Uint8List b = await f.readAsBytes();
        if (b.isEmpty) continue;
        if (b.length > 12 * 1024 * 1024) {
          _err('${f.name} is too large (max 12 MB). Try photos of the pages instead.');
          continue;
        }
        _pages.add(PageFile(b, 'application/pdf', 'PDF'));
      }
      setState(() {});
    } catch (_) {
      _err("Couldn't open that file. Please try again.");
    }
  }

  void _chooseSource() {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 12),
            _sheetItem(ctx, Icons.photo_library_outlined, 'Photos or screenshots', 'Pick one or more pages', _pickPhotos),
            _sheetItem(ctx, Icons.picture_as_pdf_outlined, 'PDF file', 'A report from your lab or email', _pickPdf),
            _sheetItem(ctx, Icons.photo_camera_outlined, 'Take a photo', 'Use your camera', _takePhoto),
          ]),
        ),
      ),
    );
  }

  Widget _sheetItem(BuildContext ctx, IconData icon, String title, String sub, Future<void> Function() action) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: C.accentSoft, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: C.accent),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: const TextStyle(color: C.muted)),
      onTap: () {
        Navigator.pop(ctx);
        action();
      },
    );
  }

  void _setStepTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers
      ..clear()
      ..add(Timer(const Duration(seconds: 3), () {
        if (mounted && _busy) setState(() => _step = 1);
      }))
      ..add(Timer(const Duration(seconds: 10), () {
        if (mounted && _busy) setState(() => _step = 2);
      }));
  }

  Future<void> _explain() async {
    if (_pages.isEmpty) return;
    if (!s.canExplain) {
      openPlans(context, title: "You've used your 3 free reports");
      return;
    }
    setState(() {
      _busy = true;
      _step = 0;
      _error = null;
    });
    _setStepTimers();
    try {
      final files = _pages.map((p) => {'mime': p.mime, 'data': base64Encode(p.bytes)}).toList();
      final data = await Api.post({'action': 'explain', 'lang': s.lang, 'files': files});
      final result = Map<String, dynamic>.from(data['result'] as Map);
      s.used += 1;
      s.save();
      final e = Entry(
        id: 'r${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        lang: s.lang,
        profileId: s.active,
        title: '${result['title'] ?? 'Medical report'}',
        result: result,
      );
      _pages.clear();
      s.upsertEntry(e);
      s.openEntry(e);
    } on ApiError catch (e) {
      if (e.code != 'cancelled') _error = errorText(e);
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
    } finally {
      for (final t in _timers) {
        t.cancel();
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        if (_busy) return _progress();
        if (s.current != null) {
          return ResultView(entry: s.current!, onNew: () => s.openEntry(null));
        }
        return _upload();
      },
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    final g = h < 5 ? 'Good evening' : (h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening'));
    final who = s.profName(s.active);
    return who == 'Me' ? g : '$g, $who';
  }

  Widget _upload() {
    final last = s.history.isNotEmpty ? s.history.first : null;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
      const AppHeader(),
      const SizedBox(height: 14),
      Text(_greeting(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.1)),
      const SizedBox(height: 4),
      const Text("Upload your lab results and we'll explain them in plain English.", style: TextStyle(color: C.muted, fontSize: 16, height: 1.45)),
      const SizedBox(height: 18),
      if (last != null) ...[_lastCard(last), const SizedBox(height: 16)],
      Container(
        padding: const EdgeInsets.all(18),
        decoration: cardDeco(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _who(),
          const SizedBox(height: 14),
          _dropBox(),
          const SizedBox(height: 12),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: C.ok),
            SizedBox(width: 6),
            Flexible(child: Text('Private and secure · Your photos are never stored', style: TextStyle(color: C.muted, fontSize: 13))),
          ]),
          if (_pages.isNotEmpty) ...[const SizedBox(height: 14), _thumbs()],
          const SizedBox(height: 16),
          PrimaryButton(
            label: _pages.isEmpty ? 'Explain my results' : 'Explain my results · ${_pages.length} page${_pages.length > 1 ? 's' : ''}',
            onPressed: _pages.isEmpty ? null : _explain,
          ),
          const SizedBox(height: 12),
          _meter(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.badSoft, borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: const TextStyle(color: C.bad)),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: C.accent, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            const Expanded(child: Text('For educational use only · not a diagnosis', style: TextStyle(color: C.muted, fontSize: 13))),
            GestureDetector(
              onTap: () => s.openEntry(sampleEntry()),
              child: const Text('See a sample', style: TextStyle(color: C.accent, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
            ),
          ]),
        ]),
      ),
    ]);
  }

  Widget _lastCard(Entry e) {
    final st = norm(e.result['overall']);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => s.openEntry(e),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: cardDeco(),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: C.softOf(st), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.description_outlined, color: C.of(st)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('MOST RECENT', style: TextStyle(color: C.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text('${s.profName(e.profileId)} · ${fmtDate(e.createdAt)}', style: const TextStyle(color: C.muted, fontSize: 13)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: C.muted),
          ]),
        ),
      ),
    );
  }

  Widget _who() {
    return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      const Text('Who is this for?', style: TextStyle(color: C.muted)),
      for (final p in s.profiles)
        ChoiceChip(
          label: Text(p.name),
          selected: p.id == s.active,
          showCheckmark: false,
          selectedColor: C.ink,
          labelStyle: TextStyle(color: p.id == s.active ? Colors.white : C.ink, fontWeight: FontWeight.w500),
          shape: StadiumBorder(side: BorderSide(color: p.id == s.active ? C.ink : C.line)),
          backgroundColor: C.surface,
          onSelected: (_) {
            s.active = p.id;
            s.save();
          },
        ),
      ActionChip(
        label: const Text('+ Add', style: TextStyle(color: C.muted)),
        backgroundColor: C.surface,
        shape: const StadiumBorder(side: BorderSide(color: C.line)),
        onPressed: () => addProfileDialog(context),
      ),
    ]);
  }

  Widget _dropBox() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _chooseSource,
      child: CustomPaint(
        painter: _DashedBorder(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
          child: Column(children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: C.accentSoft, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.upload_rounded, color: C.accent, size: 28),
            ),
            const SizedBox(height: 10),
            const Text('Upload lab results', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Photo, screenshot, or PDF\nInclude every page · up to 8 pages',
                textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 13.5, height: 1.5)),
            const SizedBox(height: 12),
            const Row(children: [
              Expanded(child: Divider(color: C.line)),
              Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('or', style: TextStyle(color: C.muted, fontSize: 13))),
              Expanded(child: Divider(color: C.line)),
            ]),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.photo_camera_outlined, color: C.accent, size: 20),
              label: const Text('Take a photo', style: TextStyle(color: C.ink, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                backgroundColor: C.surface,
                side: const BorderSide(color: C.line),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _thumbs() {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (var i = 0; i < _pages.length; i++)
        SizedBox(
          width: 72,
          height: 96,
          child: Stack(children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _pages[i].mime == 'application/pdf'
                    ? Container(color: C.accentSoft, child: const Icon(Icons.picture_as_pdf_rounded, color: C.accent, size: 34))
                    : Image.memory(_pages[i].bytes, fit: BoxFit.cover, cacheWidth: 200,
                        errorBuilder: (_, __, ___) => Container(color: C.accentSoft, child: const Icon(Icons.image_outlined, color: C.accent))),
              ),
            ),
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                child: Text(_pages[i].label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ),
            Positioned(
              right: 2,
              top: 2,
              child: GestureDetector(
                onTap: () => setState(() => _pages.removeAt(i)),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ]),
        ),
    ]);
  }

  Widget _meter() {
    if (s.plan != 'free') return const SizedBox.shrink();
    final left = s.freeLeft;
    return Row(children: [
      for (var i = 0; i < freeLimit; i++)
        Container(
          margin: const EdgeInsets.only(right: 6),
          width: 20,
          height: 6,
          decoration: BoxDecoration(color: i < left ? C.accent : C.line, borderRadius: BorderRadius.circular(3)),
        ),
      const SizedBox(width: 4),
      Text(left > 0 ? '$left of $freeLimit free reports left' : 'Free reports used · ', style: const TextStyle(color: C.muted, fontSize: 13)),
      if (left == 0)
        GestureDetector(
          onTap: () => openPlans(context),
          child: const Text('see plans', style: TextStyle(color: C.accent, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
    ]);
  }

  Widget _progress() {
    const labels = ['Uploading your report', 'Reading each result', 'Writing your summary'];
    return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
      const AppHeader(),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: cardDeco(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Analyzing your results', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          const Text('This usually takes 10–30 seconds.', style: TextStyle(color: C.muted)),
          const SizedBox(height: 18),
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: i < _step
                      ? const CircleAvatar(backgroundColor: C.accent, child: Icon(Icons.check_rounded, size: 16, color: Colors.white))
                      : (i == _step
                          ? const CircularProgressIndicator(strokeWidth: 2.5, color: C.accent)
                          : Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.line, width: 2)))),
                ),
                const SizedBox(width: 12),
                Text(labels[i], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: i <= _step ? C.ink : C.muted)),
              ]),
            ),
          const SizedBox(height: 4),
          GhostButton(label: 'Cancel', expand: true, onPressed: Api.cancel),
        ]),
      ),
      const SizedBox(height: 16),
      for (final h in [140.0, 220.0])
        Container(
          height: h,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: cardDeco(color: const Color(0xFFF7F9F8)),
        ),
    ]);
  }
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9D6D2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)));
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<void> addProfileDialog(BuildContext context) async {
  final s = AppState.I;
  if (s.profiles.length >= s.maxProfiles) {
    openPlans(context, title: 'Add more family members with Family');
    return;
  }
  final ctrl = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add family member'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 24,
        decoration: const InputDecoration(hintText: 'Name, e.g. Dad'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Add')),
      ],
    ),
  );
  if (name == null || name.isEmpty) return;
  final id = 'p${DateTime.now().millisecondsSinceEpoch}';
  s.profiles.add(Profile(id, name));
  s.active = id;
  s.save();
}
