import 'dart:async';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'services/passcode_service.dart';
import 'screens/signin_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/lock_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.loadFromPrefs();
  await ThemeService.load();
  await PasscodeService.load();
  runApp(const DevineJournalApp());
}

class DevineJournalApp extends StatefulWidget {
  const DevineJournalApp({super.key});

  @override
  State<DevineJournalApp> createState() => _DevineJournalAppState();
}

class _DevineJournalAppState extends State<DevineJournalApp> {
  bool _signedIn = AuthService.isSignedIn;
  Timer? _idleTimer;

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    final secs = PasscodeService.timeoutSeconds;
    if (secs == 0 || !PasscodeService.hasPasscode) return;
    _idleTimer = Timer(Duration(seconds: secs), () {
      if (!mounted) return;
      PasscodeService.lock();
      setState(() {});
    });
  }

  void _lockNow() {
    if (!PasscodeService.hasPasscode) return;
    _idleTimer?.cancel();
    PasscodeService.lock();
    setState(() {});
  }

  void _onSignedIn() {
    setState(() => _signedIn = true);
    _resetIdleTimer();
  }

  void _onSignOut() {
    _idleTimer?.cancel();
    setState(() => _signedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevineJournal',
      theme: buildMaterialTheme(ThemeService.current),
      debugShowCheckedModeBanner: false,
      builder: (ctx, child) => Listener(
        onPointerDown: (_) => _resetIdleTimer(),
        child: Stack(
          children: [
            child!,
            if (PasscodeService.hasPasscode && PasscodeService.isLocked)
              LockScreen(
                onUnlocked: () {
                  PasscodeService.unlock();
                  setState(() {});
                  _resetIdleTimer();
                },
                onSignOut: () {
                  Future.wait([
                    PasscodeService.clearPasscode(),
                    AuthService.signOut(),
                  ]).then((_) {
                    if (mounted) setState(() => _signedIn = false);
                  });
                },
              ),
          ],
        ),
      ),
      home: _signedIn
          ? TimelineScreen(
              onSignOut: _onSignOut,
              onThemeChange: _rebuild,
              onLockRequested: _lockNow,
            )
          : SignInScreen(
              onSignedIn: _onSignedIn,
            ),
    );
  }
}
