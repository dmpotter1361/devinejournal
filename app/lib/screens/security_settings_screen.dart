import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/passcode_service.dart';
import '../services/theme_service.dart';
import '../theme.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  PaperTheme get _t => ThemeService.current;

  Future<String?> _promptPin(String title) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _t.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PinSheet(title: title, theme: _t),
    );
  }

  Future<void> _setPasscode() async {
    final pin1 = await _promptPin('Enter new PIN');
    if (pin1 == null || !mounted) return;
    final pin2 = await _promptPin('Confirm new PIN');
    if (pin2 == null || !mounted) return;
    if (pin1 != pin2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PINs did not match — try again'),
          backgroundColor: Colors.redAccent));
      return;
    }
    await PasscodeService.setPasscode(pin1);
    if (mounted) setState(() {});
  }

  Future<void> _changePasscode() async {
    final current = await _promptPin('Enter current PIN');
    if (current == null || !mounted) return;
    if (!PasscodeService.verifyPasscode(current)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Incorrect PIN'),
          backgroundColor: Colors.redAccent));
      return;
    }
    final pin1 = await _promptPin('Enter new PIN');
    if (pin1 == null || !mounted) return;
    final pin2 = await _promptPin('Confirm new PIN');
    if (pin2 == null || !mounted) return;
    if (pin1 != pin2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PINs did not match — try again'),
          backgroundColor: Colors.redAccent));
      return;
    }
    await PasscodeService.setPasscode(pin1);
    if (mounted) setState(() {});
  }

  Future<void> _removePasscode() async {
    final current = await _promptPin('Enter PIN to remove');
    if (current == null || !mounted) return;
    if (!PasscodeService.verifyPasscode(current)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Incorrect PIN'),
          backgroundColor: Colors.redAccent));
      return;
    }
    await PasscodeService.clearPasscode();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final has = PasscodeService.hasPasscode;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.appBarBg,
        iconTheme: IconThemeData(color: t.appBarFg),
        title: Text(
          'Security',
          style: GoogleFonts.cinzelDecorative(
              color: t.appBarFg, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionLabel('PASSCODE', t),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.border, width: 0.7),
            ),
            child: Column(children: [
              if (!has) ...[
                _tile(icon: Icons.lock_open_rounded, label: 'Set Passcode', t: t, onTap: _setPasscode),
              ] else ...[
                _tile(icon: Icons.lock_reset_rounded, label: 'Change Passcode', t: t, onTap: _changePasscode),
                Divider(height: 1, color: t.border),
                _tile(
                  icon: Icons.lock_open_rounded,
                  label: 'Remove Passcode',
                  t: t,
                  labelColor: Colors.redAccent,
                  onTap: _removePasscode,
                ),
              ],
            ]),
          ),

          const SizedBox(height: 28),

          _sectionLabel('AUTO-LOCK', t),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.border, width: 0.7),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Icon(Icons.timer_outlined,
                    color: has ? t.muted : t.muted.withValues(alpha: 0.35), size: 20),
                const SizedBox(width: 12),
                Text(
                  'Lock after',
                  style: TextStyle(
                      color: has ? t.ink : t.muted.withValues(alpha: 0.5), fontSize: 16),
                ),
                const Spacer(),
                DropdownButton<int>(
                  value: PasscodeService.timeoutSeconds,
                  dropdownColor: t.card,
                  underline: const SizedBox.shrink(),
                  onChanged: has
                      ? (v) async {
                          if (v == null) return;
                          await PasscodeService.setTimeout(v);
                          setState(() {});
                        }
                      : null,
                  items: [
                    DropdownMenuItem(value: 0,    child: Text('Never',     style: TextStyle(color: t.ink, fontSize: 15))),
                    DropdownMenuItem(value: 60,   child: Text('1 minute',  style: TextStyle(color: t.ink, fontSize: 15))),
                    DropdownMenuItem(value: 300,  child: Text('5 minutes', style: TextStyle(color: t.ink, fontSize: 15))),
                    DropdownMenuItem(value: 900,  child: Text('15 minutes',style: TextStyle(color: t.ink, fontSize: 15))),
                    DropdownMenuItem(value: 1800, child: Text('30 minutes',style: TextStyle(color: t.ink, fontSize: 15))),
                  ],
                ),
              ]),
            ),
          ),

          if (has) ...[
            const SizedBox(height: 24),
            Text(
              'If you forget your PIN, tap "Forgot PIN?" on the lock screen to sign out. Your journal entries are safely kept on the server.',
              style: TextStyle(color: t.muted, fontSize: 13, height: 1.55),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, PaperTheme t) => Text(
        label,
        style: TextStyle(
            color: t.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
      );

  Widget _tile({
    required IconData icon,
    required String label,
    required PaperTheme t,
    required VoidCallback onTap,
    Color? labelColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(children: [
          Icon(icon, color: labelColor ?? t.muted, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: labelColor ?? t.ink, fontSize: 16)),
          const Spacer(),
          Icon(Icons.chevron_right, color: t.muted, size: 18),
        ]),
      ),
    );
  }
}

// ── PIN entry sheet ────────────────────────────────────────────────────────────

class _PinSheet extends StatefulWidget {
  final String title;
  final PaperTheme theme;
  const _PinSheet({required this.title, required this.theme});

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final List<int> _digits = [];

  void _onDigit(int d) {
    if (_digits.length >= 4) return;
    setState(() => _digits.add(d));
    if (_digits.length == 4) {
      final pin = _digits.map((n) => '$n').join();
      Navigator.of(context).pop(pin);
    }
  }

  void _onBack() {
    if (_digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            widget.title,
            style: GoogleFonts.cinzelDecorative(
                color: t.heading, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < _digits.length;
              return Container(
                width: 16, height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 10),
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

          const SizedBox(height: 20),

          Column(children: [
            _row([1, 2, 3], t),
            const SizedBox(height: 10),
            _row([4, 5, 6], t),
            const SizedBox(height: 10),
            _row([7, 8, 9], t),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _key(null, t, icon: Icons.backspace_outlined, onTap: _onBack)),
              const SizedBox(width: 10),
              Expanded(child: _key(0, t)),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: t.muted, fontSize: 14)),
                ),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }

  Widget _row(List<int> digits, PaperTheme t) {
    return Row(
      children: List.generate(digits.length * 2 - 1, (i) {
        if (i.isOdd) return const SizedBox(width: 10);
        return Expanded(child: _key(digits[i ~/ 2], t));
      }),
    );
  }

  Widget _key(int? digit, PaperTheme t, {IconData? icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? (digit != null ? () => _onDigit(digit) : null),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: t.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border, width: 0.8),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: t.ink, size: 20)
              : Text(
                  '$digit',
                  style: GoogleFonts.cinzelDecorative(
                      color: t.heading, fontSize: 22, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}
