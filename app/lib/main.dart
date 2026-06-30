import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'screens/signin_screen.dart';
import 'screens/timeline_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.loadFromPrefs();
  await ThemeService.load();
  runApp(const DevineJournalApp());
}

class DevineJournalApp extends StatefulWidget {
  const DevineJournalApp({super.key});

  @override
  State<DevineJournalApp> createState() => _DevineJournalAppState();
}

class _DevineJournalAppState extends State<DevineJournalApp> {
  bool _signedIn = AuthService.isSignedIn;

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevineJournal',
      theme: buildMaterialTheme(ThemeService.current),
      debugShowCheckedModeBanner: false,
      home: _signedIn
          ? TimelineScreen(
              onSignOut: () => setState(() => _signedIn = false),
              onThemeChange: _rebuild,
            )
          : SignInScreen(
              onSignedIn: () => setState(() => _signedIn = true),
            ),
    );
  }
}
