import 'package:flutter/material.dart';

import '../theme.dart';

const _legal = {
  'privacy': (
    'Privacy Policy',
    [
      ('What we collect',
          'The report photos or PDF pages you add, and the explanation we create from them. If Save to history is on, the explanation text, the date, and the family profile it belongs to are kept on your phone.'),
      ("What we don't keep",
          'Your photos and PDFs. They are sent once to create the explanation and are not stored. We ask the AI to leave out names, dates of birth, and ID numbers.'),
      ('How it\'s protected', 'Data is encrypted in transit. Your history stays on your phone and is never shown to other users.'),
      ('What we never do', 'We never sell your health data and never use it for advertising.'),
      ('Your choices',
          'Turn history off anytime, delete single reports, or delete all your data in Profile. EU/UK users can request a copy or erasure of their data under GDPR. US users in states with health-privacy laws (such as Washington\'s My Health My Data Act) have similar rights.'),
      ('Contact', 'privacy@moezzadigital.com'),
    ]
  ),
  'terms': (
    'Terms of Use',
    [
      ('Education only',
          'Lab Results Reader explains medical reports in plain language for general education. It is not a medical device, does not diagnose or treat any condition, and is not a substitute for professional medical advice.'),
      ('Talk to your doctor',
          'Always ask your doctor or another qualified provider about your results before making any health decision. Never ignore or delay medical advice because of something you read in this app.'),
      ('Emergencies', 'If you think you may have a medical emergency, call 911 (US) or your local emergency number right away.'),
      ('Accuracy', 'AI can misread photos or make mistakes. Check every value against your original report.'),
      ('Subscriptions', 'Paid plans renew automatically until canceled. Cancel anytime in your Google Play account settings.'),
      ('Age', 'You must be 18 or older, or use the app with a parent or guardian.'),
    ]
  ),
};

void openLegal(BuildContext context, String kind) {
  final l = _legal[kind]!;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: Text(l.$1), backgroundColor: C.bg, surfaceTintColor: C.bg),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: C.warnSoft, borderRadius: BorderRadius.circular(10)),
          child: const Text('Draft — have a lawyer review before launch.', style: TextStyle(color: C.warn, fontSize: 13)),
        ),
        for (final s in l.$2) ...[
          const SizedBox(height: 18),
          Text(s.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(s.$2, style: const TextStyle(fontSize: 15, height: 1.55)),
        ],
      ]),
    ),
  ));
}

void openPlans(BuildContext context, {String title = 'Choose a plan'}) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlansScreen(title: title)));
}

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key, required this.title});
  final String title;
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  String chosen = 'plus';

  Widget _plan(String id, String name, String price, List<String> perks, {bool best = false}) {
    final on = chosen == id;
    return GestureDetector(
      onTap: () => setState(() => chosen = id),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? C.accent : Colors.transparent, width: 2),
          boxShadow: cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (best)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(99)),
              child: const Text('MOST POPULAR', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            ),
          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text.rich(TextSpan(children: [
            TextSpan(text: price, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            const TextSpan(text: ' / month', style: TextStyle(color: C.muted)),
          ])),
          const SizedBox(height: 6),
          for (final p in perks)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(children: [
                const Icon(Icons.check_rounded, size: 18, color: C.accent),
                const SizedBox(width: 6),
                Text(p, style: const TextStyle(color: C.muted)),
              ]),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: C.bg, surfaceTintColor: C.bg),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
        Text(widget.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
        const SizedBox(height: 4),
        const Text('Cancel anytime. Prices in USD.', style: TextStyle(color: C.muted)),
        const SizedBox(height: 18),
        _plan('plus', 'Plus', '\$4.99', ['Unlimited reports', 'Follow-up questions', '2 family profiles'], best: true),
        const SizedBox(height: 12),
        _plan('family', 'Family', '\$9.99', ['Everything in Plus', 'Up to 6 family profiles', 'History for each person']),
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Start 7-day free trial',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Paid plans are coming soon. We'll let you know when they're available.")),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now', style: TextStyle(color: C.muted))),
      ]),
    );
  }
}
