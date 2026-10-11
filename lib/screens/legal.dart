import 'package:flutter/material.dart';

import '../api.dart';
import '../billing.dart';
import '../state.dart';
import '../theme.dart';

const String legalUpdated = 'October 11, 2026';

const _legal = {
  'privacy': (
    'Privacy Policy',
    [
      ('Who we are',
          'Lab Results Reader ("the app", "we", "us") is operated by Moezza Digital. If you have any question about your privacy, contact us at privacy@moezzadigital.com.'),
      ('What we collect',
          'We collect only what is needed to explain your report: the photos or PDF pages you choose to upload, the questions you ask in the follow-up chat, and basic technical information such as your IP address, the time of each request, and an anonymous app ID for this phone (used only to count free reports and to keep your paid plan active). If you subscribe, Google Play shares a purchase token with us so we can confirm your plan; we never see your card details. You do not need an account. If you choose to sign in with Google, we receive your name, email address, and profile picture from Google to create your account.'),
      ('How we use it',
          'We use your uploads and questions only to create your explanation and answer your questions. We use technical information only to keep the service secure and to prevent abuse. We never sell your data, never use it for advertising, and never use it to build a profile about you.'),
      ('AI processing',
          'To create your explanation, your uploads are sent over an encrypted connection to our server and then to Google\'s Gemini AI service, which processes them under Google\'s API terms. We share your uploads only for this purpose. We instruct the AI not to include names, dates of birth, ID numbers, or addresses in your explanation.'),
      ('What we keep, and for how long',
          'Your photos and PDFs are not stored on our servers after your explanation is created. To prevent abuse, we keep a scrambled (hashed) form of your IP address and the times of your requests for a short period. If you turn on "Save to history", your explanations are saved only on your own device (or in your account, if you sign in). You can delete them anytime in Profile, and uninstalling the app removes them.'),
      ('Optional account (Sign in with Google)',
          'Signing in is optional. If you sign in, we store your account details (name, email address, profile picture), your plan, and the report summaries you choose to save, so they are available on every device where you sign in. Photos and PDFs are never stored. You can sign out at any time, and you can permanently delete your account and everything saved in it from Profile. Deleting your account does not cancel a Google Play subscription; cancel it in Google Play.'),
      ('Health information',
          'Lab reports contain sensitive health information. We process it only with the explicit consent you give when you first open the app. You can withdraw consent at any time by deleting your data in Profile and no longer using the app.'),
      ('Security',
          'All data is sent over encrypted (HTTPS) connections. Access to our server and to the AI service is restricted and protected.'),
      ('Your rights',
          'Depending on where you live, you may have the right to access, correct, delete, or object to the processing of your personal data, and to complain to your local data protection authority. These rights exist under laws such as the GDPR (EU and UK), CCPA/CPRA (California), LGPD (Brazil), PIPEDA (Canada), the Privacy Act (Australia), and the DPDP Act (India). Because we do not keep your reports, most of your data stays on your device and under your control. For any request, email privacy@moezzadigital.com and we will reply within 30 days.'),
      ('International transfers',
          'Our server and the AI service may process your data in countries other than your own, including the United States. Where required, we rely on appropriate safeguards for these transfers.'),
      ('Children',
          'The app is not intended for children under 13. Anyone under 18 should use it with a parent or guardian.'),
      ('Changes to this policy',
          'If we change this policy, we will update the date below and tell you in the app when the changes are important.'),
    ]
  ),
  'terms': (
    'Terms of Use',
    [
      ('Agreement', 'By using Lab Results Reader, you agree to these Terms. If you do not agree, please do not use the app.'),
      ('Educational use only',
          'The app explains medical reports in simple language for general education. It is not a medical device. It does not diagnose, treat, cure, or prevent any condition, and it is not a substitute for advice from a doctor or other qualified healthcare professional.'),
      ('Always talk to your doctor',
          'Discuss your results with a qualified healthcare professional before making any decision about your health. Never ignore professional medical advice or delay seeking it because of something you read in the app.'),
      ('Emergencies',
          'Do not use the app in an emergency. If you think you may have a medical emergency, contact your local emergency services or go to the nearest emergency department right away.'),
      ('Accuracy',
          'Explanations are created by artificial intelligence. AI can misread a photo, miss information, or make mistakes. Always check every value against your original report. The app is provided "as is", without any guarantee that explanations are complete or accurate.'),
      ('Your responsibilities',
          'Only upload reports that belong to you, or that you have permission to share (for example, as a parent, guardian, or caregiver). Do not misuse the app, try to disrupt it, or copy or reverse engineer it.'),
      ('Free and paid plans',
          'The free plan includes a limited number of reports. Paid plans, when available, are billed through Google Play or the App Store, renew automatically, and can be canceled anytime in your store account settings. Prices are shown in your local currency before you pay. Refunds follow the store\'s refund policy.'),
      ('Limitation of liability',
          'To the fullest extent allowed by law, we are not responsible for any decision you make, or any loss or harm, based on information shown in the app. Nothing in these Terms limits any rights you have under consumer protection laws that cannot be changed by agreement.'),
      ('Changes and ending',
          'We may update the app and these Terms from time to time. We may stop providing the app, or suspend access for misuse. You can stop using the app at any time.'),
      ('Governing law',
          'These Terms are governed by the laws of India. This does not take away any protection given to you by the mandatory laws of the country where you live.'),
      ('Contact', 'Questions about these Terms: support@moezzadigital.com'),
    ]
  ),
};

void openLegal(BuildContext context, String kind) {
  final l = _legal[kind]!;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: Text(l.$1), backgroundColor: C.bg, surfaceTintColor: C.bg),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        const Text('Last updated: $legalUpdated', style: TextStyle(color: C.muted, fontSize: 13)),
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

/// "Have a code?" — gives a paid plan for free (codes are set in REDEEM_CODES in config.php).
Future<void> redeemDialog(BuildContext context) async {
  final ctrl = TextEditingController();
  String? err;
  bool busy = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Redeem a code'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Enter the code you were given to unlock a plan.', style: TextStyle(color: C.muted)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(hintText: 'e.g. FRIEND2026', errorText: err, border: const OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    final code = ctrl.text.trim();
                    if (code.isEmpty) return;
                    set(() {
                      busy = true;
                      err = null;
                    });
                    try {
                      final d = await Api.post({'action': 'redeem', 'code': code});
                      AppState.I.applyStatus(d['status']);
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } on ApiError catch (e) {
                      set(() {
                        busy = false;
                        err = e.code == 'bad_code' && e.detail.isNotEmpty ? e.detail : errorText(e);
                      });
                    }
                  },
            child: Text(busy ? 'Checking…' : 'Redeem'),
          ),
        ],
      ),
    ),
  );
  if (ok == true && context.mounted) {
    final s = AppState.I;
    final until = s.planUntilText;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('You now have the ${s.planName} plan${until.isNotEmpty ? ' until $until' : ''}.'),
    ));
  }
}

class _PlansScreenState extends State<PlansScreen> {
  String chosen = 'plus';
  bool storeReady = false;

  @override
  void initState() {
    super.initState();
    Billing.I.message.value = null;
    Billing.I.loadProducts().then((ok) {
      if (mounted) setState(() => storeReady = ok);
    });
  }

  String _price(String plan, String fallback) => Billing.I.products[plan]?.price ?? fallback;

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
      body: ListenableBuilder(
        listenable: Listenable.merge([AppState.I, Billing.I.message, Billing.I.busy]),
        builder: (context, _) {
          final s = AppState.I;
          final msg = Billing.I.message.value;
          final busy = Billing.I.busy.value;
          final paid = s.plan != 'free';
          return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
            Text(paid ? 'Your plan' : widget.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
            const SizedBox(height: 4),
            const Text('Cancel anytime in Google Play. You will see the price in your local currency before you pay.', style: TextStyle(color: C.muted)),
            if (paid) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.accentSoft, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.verified_rounded, color: C.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${s.planName} plan is active${s.planUntilText.isNotEmpty ? ' until ${s.planUntilText}' : ''}${s.planSource == 'code' ? ' (code)' : ''}.',
                      style: const TextStyle(color: C.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
            ],
            if (msg != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
                child: Text(msg, style: const TextStyle(height: 1.45)),
              ),
            ],
            const SizedBox(height: 18),
            _plan('plus', 'Plus', _price('plus', '\$4.99'), ['Unlimited reports', 'Follow-up questions', '2 family profiles'], best: true),
            const SizedBox(height: 12),
            _plan('family', 'Family', _price('family', '\$9.99'), ['Everything in Plus', 'Up to 6 family profiles', 'History for each person']),
            const SizedBox(height: 18),
            PrimaryButton(
              label: busy ? 'Please wait…' : (s.plan == chosen ? 'Current plan' : 'Subscribe with Google Play'),
              onPressed: busy || s.plan == chosen
                  ? null
                  : () async {
                      final err = await Billing.I.buy(chosen);
                      if (err != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton.icon(
                onPressed: () => redeemDialog(context),
                icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                label: const Text('Have a code?'),
                style: TextButton.styleFrom(foregroundColor: C.accent),
              ),
              const Text('·', style: TextStyle(color: C.muted)),
              TextButton(
                onPressed: busy ? null : () => Billing.I.restore(),
                style: TextButton.styleFrom(foregroundColor: C.accent),
                child: const Text('Restore purchases'),
              ),
            ]),
            if (!storeReady)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Google Play subscriptions are launching soon.', textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 12.5)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now', style: TextStyle(color: C.muted))),
          ]);
        },
      ),
    );
  }
}
