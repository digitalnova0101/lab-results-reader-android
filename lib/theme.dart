import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App colors (same palette as the website).
class C {
  static const bg = Color(0xFFF2F5F4);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0F1F1C);
  static const ink2 = Color(0xFF24332F);
  static const muted = Color(0xFF5E6E6A);
  static const line = Color(0xFFE1E8E6);
  static const accent = Color(0xFF0B6E5C);
  static const accent2 = Color(0xFF13937A);
  static const accentSoft = Color(0xFFE3F2EE);
  static const ok = Color(0xFF1C7A4A);
  static const okSoft = Color(0xFFE3F3EA);
  static const warn = Color(0xFFA35F00);
  static const warnSoft = Color(0xFFFCF1DE);
  static const bad = Color(0xFFB42318);
  static const badSoft = Color(0xFFFCE8E6);

  static Color of(String s) => s == 'ok' ? ok : (s == 'bad' ? bad : warn);
  static Color softOf(String s) => s == 'ok' ? okSoft : (s == 'bad' ? badSoft : warnSoft);
}

String norm(dynamic s) => (s == 'ok' || s == 'warn' || s == 'bad') ? s as String : 'warn';

const labelOf = {'ok': 'In range', 'warn': 'Out of range', 'bad': 'Needs attention'};
const verdictOf = {
  'ok': 'All results are in range',
  'warn': 'Some results are out of range',
  'bad': 'Some results need attention',
};

const cardShadow = [
  BoxShadow(color: Color(0x120F1F1C), blurRadius: 30, offset: Offset(0, 10)),
  BoxShadow(color: Color(0x0A0F1F1C), blurRadius: 2, offset: Offset(0, 1)),
];

BoxDecoration cardDeco({Color color = C.surface, double radius = 18}) =>
    BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), boxShadow: cardShadow);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.accent, primary: C.accent, surface: C.surface),
    scaffoldBackgroundColor: C.bg,
  );
  return base.copyWith(
    textTheme: GoogleFonts.figtreeTextTheme(base.textTheme).apply(bodyColor: C.ink, displayColor: C.ink),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Big primary button used across the app.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: C.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF9DC5BB),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, this.onPressed, this.expand = false, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final btn = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: C.ink,
        backgroundColor: C.surface,
        side: const BorderSide(color: C.line),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 18, color: C.accent), const SizedBox(width: 8)],
        Text(label),
      ]),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Logo + app name (left, WhatsApp-style).
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x470B6E5C), blurRadius: 14, offset: Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset('assets/icon.png', width: 44, height: 44),
          ),
        ),
        const SizedBox(width: 12),
        const Flexible(
          child: Text('Lab Results Reader',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        ),
      ]),
    );
  }
}

class Chip2 extends StatelessWidget {
  const Chip2(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: C.softOf(status), borderRadius: BorderRadius.circular(999)),
      child: Text(labelOf[status]!,
          style: TextStyle(color: C.of(status), fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
