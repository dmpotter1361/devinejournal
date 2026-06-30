import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/passcode_service.dart';
import '../services/theme_service.dart';
import '../theme.dart';
import '../widgets/star_field.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback onSignOut;
  const LockScreen({super.key, required this.onUnlocked, required this.onSignOut});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  final List<int> _digits = [];
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -7.0, end: 7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDigit(int d) {
    if (_busy || _digits.length >= 4) return;
    setState(() => _digits.add(d));
    if (_digits.length == 4) _verify();
  }

  void _onBack() {
    if (_busy || _digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  void _verify() {
    setState(() => _busy = true);
    final pin = _digits.map((d) => '$d').join();
    if (PasscodeService.verifyPasscode(pin)) {
      widget.onUnlocked();
    } else {
      _shakeCtrl.forward(from: 0).then((_) {
        if (mounted) setState(() { _digits.clear(); _busy = false; });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeService.current;
    final showStars = t.brightness == Brightness.dark;
    final starColor = t.id == 'celestial' ? const Color(0xFFd4c8ff) : Colors.white;

    Widget content = _buildContent(t);
    if (showStars) content = StarField(starColor: starColor, count: 120, child: content);

    return Material(color: t.bg, child: content);
  }

  Widget _buildContent(PaperTheme t) {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(flex: 2),

          const Text('🌙', style: TextStyle(fontSize: 54)),
          const SizedBox(height: 14),
          Text(
            'DevineJournal',
            style: GoogleFonts.cinzelDecorative(
                color: t.heading, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            'Your journal is locked.',
            style: GoogleFonts.lora(color: t.muted, fontSize: 17, fontStyle: FontStyle.italic),
          ),

          const Spacer(flex: 1),

          // 4 dot indicators with shake on wrong PIN
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _digits.length;
                return Container(
                  width: 18, height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? t.accent : Colors.transparent,
                    border: Border.all(
                      color: filled ? t.accent : t.muted.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
          ),

          const Spacer(flex: 1),

          // Number pad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(children: [
              _row([1, 2, 3], t),
              const SizedBox(height: 12),
              _row([4, 5, 6], t),
              const SizedBox(height: 12),
              _row([7, 8, 9], t),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _key(null, t, icon: Icons.backspace_outlined, onTap: _onBack)),
                const SizedBox(width: 12),
                Expanded(child: _key(0, t)),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox.shrink()),
              ]),
            ]),
          ),

          const Spacer(flex: 2),

          TextButton(
            onPressed: widget.onSignOut,
            child: Text(
              'Forgot PIN? Sign out',
              style: TextStyle(
                color: t.muted,
                fontSize: 15,
                decoration: TextDecoration.underline,
                decorationColor: t.muted,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _row(List<int> digits, PaperTheme t) {
    return Row(
      children: List.generate(digits.length * 2 - 1, (i) {
        if (i.isOdd) return const SizedBox(width: 12);
        return Expanded(child: _key(digits[i ~/ 2], t));
      }),
    );
  }

  Widget _key(int? digit, PaperTheme t, {IconData? icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? (digit != null ? () => _onDigit(digit) : null),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border, width: 0.8),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: t.ink, size: 22)
              : Text(
                  '$digit',
                  style: GoogleFonts.cinzelDecorative(
                      color: t.heading, fontSize: 24, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}
