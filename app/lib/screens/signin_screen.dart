import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../widgets/star_field.dart';

class SignInScreen extends StatefulWidget {
  final VoidCallback onSignedIn;
  const SignInScreen({super.key, required this.onSignedIn});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;
  String? _error;

  static const _bg      = Color(0xFF0e0b18);
  static const _paper   = Color(0xFF181535);
  static const _gold    = Color(0xFFc9a84c);
  static const _lavender = Color(0xFFc8b8e8);
  static const _moonW   = Color(0xFFf5f0ff);
  static const _muted   = Color(0xFF8878b8);

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.signInWithGoogle('https://journal.devinetarot.net');
      if (mounted) widget.onSignedIn();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: _bg,
      body: StarField(
        starColor: _moonW,
        count: 180,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Moon glow ─────────────────────────────────────────────
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _gold.withValues(alpha: 0.18),
                        _gold.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: const Center(
                    child: Text('🌙', style: TextStyle(fontSize: 52)),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Moon phase row ─────────────────────────────────────────
                Text(
                  '☽  ◯  ☾',
                  style: TextStyle(
                    color: _muted.withValues(alpha: 0.6),
                    fontSize: 13,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 28),

                // ── App name ──────────────────────────────────────────────
                Text(
                  'DevineJournal',
                  style: GoogleFonts.cinzelDecorative(
                    color: _gold,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'your sacred journal',
                  style: GoogleFonts.cormorant(
                    color: _lavender,
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // ── Decorative divider ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 48),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: _muted.withValues(alpha: 0.35), thickness: 0.6)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('✦', style: TextStyle(color: _muted.withValues(alpha: 0.5), fontSize: 10)),
                      ),
                      Expanded(child: Divider(color: _muted.withValues(alpha: 0.35), thickness: 0.6)),
                    ],
                  ),
                ),

                // ── Sign-in card ──────────────────────────────────────────
                Container(
                  width: sw.clamp(0.0, 380.0),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: _paper,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _gold.withValues(alpha: 0.18),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withValues(alpha: 0.07),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Begin your journey',
                        style: GoogleFonts.cinzelDecorative(
                          color: _moonW,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to open the pages of your journal',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 24),

                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      _loading
                          ? const CircularProgressIndicator(color: _gold, strokeWidth: 2)
                          : SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _gold,
                                  foregroundColor: _bg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _signIn,
                                icon: const Text('G', style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  fontFamily: 'serif',
                                )),
                                label: Text(
                                  'Continue with Google',
                                  style: GoogleFonts.cinzelDecorative(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                Text(
                  'Your words, your sanctuary ✦',
                  style: TextStyle(
                    color: _muted.withValues(alpha: 0.45),
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
