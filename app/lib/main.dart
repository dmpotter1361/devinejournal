import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'screens/signin_screen.dart';
import 'screens/timeline_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.loadFromPrefs();
  runApp(const DevineJournalApp());
}

class DevineJournalApp extends StatefulWidget {
  const DevineJournalApp({super.key});

  @override
  State<DevineJournalApp> createState() => _DevineJournalAppState();
}

class _DevineJournalAppState extends State<DevineJournalApp> {
  bool _signedIn = AuthService.isSignedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevineJournal',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      home: _signedIn
          ? TimelineScreen(onSignOut: () => setState(() => _signedIn = false))
          : SignInScreen(onSignedIn: () => setState(() => _signedIn = true)),
    );
  }
}
