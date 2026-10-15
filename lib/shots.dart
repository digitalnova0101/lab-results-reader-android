import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/learn.dart';
import 'screens/result.dart';
import 'speak.dart';
import 'screens/legal.dart';
import 'state.dart';

/// Store screenshots only: the web build opened with ?shot=<screen> shows a ready-made demo.
/// Does nothing in the Android app.
final GlobalKey<NavigatorState> shotNavKey = GlobalKey<NavigatorState>();
bool shotMode = false;

void applyShotMode() {
  if (!kIsWeb) return;
  final shot = Uri.base.queryParameters['shot'];
  if (shot == null) return;
  shotMode = true;
  final s = AppState.I;
  s.googleClientId = 'demo';
  final now = DateTime.now().millisecondsSinceEpoch;
  const day = 86400000;
  s.introSeen = shot != 'intro';
  s.langChosen = shot != 'lang';
  s.consent = true;
  s.saveHistory = true;
  s.lang = 'English';
  s.used = 1;
  s.profiles = [Profile('me', 'Emily'), Profile('mom', 'Mom'), Profile('dad', 'Dad')];
  s.active = 'me';
  s.plan = 'family';
  final main = demoEntry('r1', now - 2 * 3600000);
  s.history = [
    main,
    _brief('r2', 'Thyroid Panel (TSH, Free T4)', 'ok', 'mom', now - 6 * day),
    _brief('r3', 'Comprehensive Metabolic Panel', 'warn', 'dad', now - 13 * day),
    _brief('r4', 'Hemoglobin A1c', 'ok', 'me', now - 41 * day),
    _brief('r5', 'Urinalysis', 'ok', 'mom', now - 70 * day),
  ];
  s.plan = (shot == 'profile' || shot == 'plans') ? 'free' : 'family';
  s.tab = switch (shot) { 'history' => 1, 'profile' => 2, _ => 0 };
  s.current = const {'result', 'learn', 'listen', 'share'}.contains(shot) ? main : null;
  if (shot == 'listen') speakingId.value = main.id;
  s.touch();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.delayed(const Duration(milliseconds: 600), () {
      final ctx = shotNavKey.currentContext;
      if (ctx == null) return;
      if (shot == 'learn') showLearnSheet(ctx, 'LDL cholesterol ("bad")', 'English');
      if (shot == 'plans') openPlans(ctx, title: 'Unlimited reports for your family');
      if (shot == 'share') ResultView.openShare(ctx, main);
    });
  });
}

Entry _brief(String id, String title, String overall, String who, int at) => Entry(
      id: id,
      createdAt: at,
      lang: 'English',
      profileId: who,
      title: title,
      result: {'title': title, 'overall': overall, 'summary': '', 'reports': [], 'questions': []},
    );

Entry demoEntry(String id, int at) => Entry(
      id: id,
      createdAt: at,
      lang: 'English',
      profileId: 'me',
      title: 'Annual Blood Work',
      result: {
        'title': 'Annual Blood Work',
        'overall': 'warn',
        'summary':
            'Most of your results are healthy. Your LDL ("bad") cholesterol is high and your vitamin D is low. Neither is an emergency, but both are worth discussing at your next visit.',
        'urgent': '',
        'reports': [
          {
            'title': 'Lipid Panel (cholesterol)',
            'status': 'warn',
            'summary': 'LDL is above the goal; the rest looks good.',
            'items': [
              {'name': 'LDL cholesterol ("bad")', 'value': '162 mg/dL', 'range': '< 100 mg/dL', 'num': 162, 'low': null, 'high': 100, 'status': 'warn', 'meaning': 'Too much can slowly build up in artery walls.'},
              {'name': 'HDL cholesterol ("good")', 'value': '58 mg/dL', 'range': '> 40 mg/dL', 'num': 58, 'low': 40, 'high': null, 'status': 'ok', 'meaning': 'Helps clear extra cholesterol from your blood.'},
              {'name': 'Triglycerides', 'value': '128 mg/dL', 'range': '< 150 mg/dL', 'num': 128, 'low': null, 'high': 150, 'status': 'ok', 'meaning': 'Fats from food. In the healthy range.'},
            ],
          },
          {
            'title': 'Complete Blood Count (CBC)',
            'status': 'ok',
            'summary': 'Your blood cells look normal.',
            'items': [
              {'name': 'Hemoglobin', 'value': '13.8 g/dL', 'range': '12.0–15.5 g/dL', 'num': 13.8, 'low': 12, 'high': 15.5, 'status': 'ok', 'meaning': 'Carries oxygen around your body.'},
              {'name': 'White blood cells', 'value': '6.4 K/µL', 'range': '4.5–11.0 K/µL', 'num': 6.4, 'low': 4.5, 'high': 11, 'status': 'ok', 'meaning': 'Your infection-fighting cells.'},
              {'name': 'Platelets', 'value': '251 K/µL', 'range': '150–400 K/µL', 'num': 251, 'low': 150, 'high': 400, 'status': 'ok', 'meaning': 'Help your blood clot.'},
            ],
          },
          {
            'title': 'Vitamin D, 25-OH',
            'status': 'warn',
            'summary': 'A little below the healthy range.',
            'items': [
              {'name': 'Vitamin D', 'value': '21 ng/mL', 'range': '30–100 ng/mL', 'num': 21, 'low': 30, 'high': 100, 'status': 'warn', 'meaning': 'Low levels are common and easy to treat.'},
            ],
          },
          {
            'title': 'Blood Sugar',
            'status': 'ok',
            'summary': 'In the normal range.',
            'items': [
              {'name': 'Glucose, fasting', 'value': '92 mg/dL', 'range': '70–99 mg/dL', 'num': 92, 'low': 70, 'high': 99, 'status': 'ok', 'meaning': 'Your blood sugar after not eating overnight.'},
            ],
          },
        ],
        'questions': [
          'Is my LDL high enough to need medicine, or should I try diet and exercise first?',
          'Should I take a vitamin D supplement, and how much?',
          'When should I repeat these tests?',
        ],
      },
    );
