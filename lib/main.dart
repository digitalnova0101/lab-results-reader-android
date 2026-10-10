import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/history.dart';
import 'screens/home.dart';
import 'screens/legal.dart';
import 'screens/profile.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: C.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  await AppState.I.load();
  runApp(const LabResultsReaderApp());
}

class LabResultsReaderApp extends StatelessWidget {
  const LabResultsReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lab Results Reader',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final s = AppState.I;
          if (!s.introSeen) return const IntroScreen();
          if (!s.consent) return const ConsentScreen();
          return const MainShell();
        },
      ),
    );
  }
}

/* ---------------- Onboarding slides ---------------- */

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pc = PageController();
  int _i = 0;
  static const _slides = [
    (Icons.upload_rounded, 'Upload your lab results',
        'Snap a photo or add a PDF of your blood work, urinalysis, or imaging report.'),
    (Icons.fact_check_outlined, 'Get a clear explanation',
        "See what's in range, what's out of range, and what it means for you, in plain English."),
    (Icons.forum_outlined, 'Be ready for your appointment',
        "Get questions to ask your doctor, and ask anything you're unsure about."),
  ];

  void _finish() {
    AppState.I.introSeen = true;
    AppState.I.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            const AppHeader(),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(44),
                        gradient: const LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.accentSoft, C.surface]),
                        boxShadow: cardShadow,
                      ),
                      child: Icon(s.$1, size: 70, color: C.accent),
                    ),
                    const SizedBox(height: 28),
                    Text(s.$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.6)),
                    const SizedBox(height: 12),
                    Text(s.$3, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: C.muted, height: 1.5)),
                  ]);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: i == _i ? C.accent : C.line, borderRadius: BorderRadius.circular(99)),
                ),
              ),
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              label: _i == _slides.length - 1 ? 'Get started' : 'Next',
              onPressed: () {
                if (_i < _slides.length - 1) {
                  _pc.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
                } else {
                  _finish();
                }
              },
            ),
            TextButton(onPressed: _finish, child: const Text('Skip', style: TextStyle(color: C.accent, fontWeight: FontWeight.w600))),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

/* ---------------- Consent ---------------- */

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});
  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool edu = false, terms = false, save = true;

  Widget _check(bool v, ValueChanged<bool> on, Widget title, String sub) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => on(!v),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(border: Border.all(color: C.line), borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(value: v, onChanged: (x) => on(x ?? false), activeColor: C.accent),
          const SizedBox(width: 4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              title,
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(color: C.muted, fontSize: 13.5)),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bold = TextStyle(fontWeight: FontWeight.w700, fontSize: 15);
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          const AppHeader(),
          const SizedBox(height: 18),
          const Text('A few quick things', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
          const SizedBox(height: 4),
          const Text('Please review and agree before you continue.', style: TextStyle(color: C.muted, fontSize: 16)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDeco(),
            child: Column(children: [
              _check(edu, (v) => setState(() => edu = v), const Text('Lab Results Reader is for educational use only.', style: bold),
                  "It explains your results in plain language. It doesn't diagnose, treat, or replace your doctor."),
              const SizedBox(height: 10),
              _check(
                terms,
                (v) => setState(() => terms = v),
                Wrap(children: [
                  const Text('I agree to the ', style: bold),
                  GestureDetector(
                      onTap: () => openLegal(context, 'privacy'),
                      child: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: C.accent, decoration: TextDecoration.underline))),
                  const Text(' and ', style: bold),
                  GestureDetector(
                      onTap: () => openLegal(context, 'terms'),
                      child: const Text('Terms of Use', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: C.accent, decoration: TextDecoration.underline))),
                  const Text('.', style: bold),
                ]),
                'Your photos are only used to create your summary and are never stored.',
              ),
              const SizedBox(height: 10),
              _check(save, (v) => setState(() => save = v), const Text('Save my summaries on this phone', style: bold),
                  'Optional. You can change this or delete your data anytime in Profile.'),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Get started',
                onPressed: (edu && terms)
                    ? () {
                        final s = AppState.I;
                        s.consent = true;
                        s.saveHistory = save;
                        s.save();
                      }
                    : null,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/* ---------------- Main tabs ---------------- */

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: AppState.I, builder: (context, _) => _shell(context));
  }

  Widget _shell(BuildContext context) {
    final s = AppState.I;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: s.tab, children: const [HomeTab(), HistoryTab(), ProfileTab()]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: s.tab,
        onDestinationSelected: s.setTab,
        backgroundColor: C.surface,
        indicatorColor: C.accentSoft,
        height: 68,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: C.accent), label: 'Home'),
          NavigationDestination(
            icon: Badge(isLabelVisible: s.history.isNotEmpty, label: Text('${s.history.length}'), backgroundColor: C.accent, child: const Icon(Icons.description_outlined)),
            selectedIcon: const Icon(Icons.description_rounded, color: C.accent),
            label: 'History',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: C.accent), label: 'Profile'),
        ],
      ),
    );
  }
}
