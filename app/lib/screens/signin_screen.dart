import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';

const _apiBase = 'https://journal.devinetarot.net';

class SignInScreen extends StatefulWidget {
  final VoidCallback onSignedIn;
  const SignInScreen({super.key, required this.onSignedIn});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.signInWithGoogle(_apiBase);
      widget.onSignedIn();
    } catch (e) {
      setState(() { _error = '$e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDark,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Moon icon
                const Text('🌙', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 24),
                Text(
                  'DevineJournal',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: kGold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your sacred journal',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: kLavender,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 56),
                if (_loading)
                  const CircularProgressIndicator(color: kGold)
                else
                  ElevatedButton.icon(
                    onPressed: _signIn,
                    icon: const Text('G', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    label: const Text('Sign in with Google'),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ],
                const SizedBox(height: 48),
                Text(
                  '✦  ✦  ✦',
                  style: TextStyle(color: kGold.withValues(alpha: 0.4), letterSpacing: 8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
