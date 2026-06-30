import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _clientId = '900843330975-970qsohcbim8cmub4l8jdbdp1c5a1nse.apps.googleusercontent.com';
const _tokenKey = 'dj_token';
const _nameKey  = 'dj_name';
const _picKey   = 'dj_pic';

final _googleSignIn = GoogleSignIn(clientId: _clientId, scopes: ['email', 'profile']);

class AuthService {
  static String? token;
  static String? userName;
  static String? userPic;

  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    token    = prefs.getString(_tokenKey);
    userName = prefs.getString(_nameKey);
    userPic  = prefs.getString(_picKey);
  }

  static Future<bool> signInWithGoogle(String apiBase) async {
    final account = await _googleSignIn.signIn();
    if (account == null) return false;

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) return false;

    final res = await http.post(
      Uri.parse('$apiBase/api/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'credential': idToken}),
    );

    if (res.statusCode != 200) return false;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    token    = body['access_token'] as String;
    userName = body['user_name'] as String;
    userPic  = body['user_picture'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token!);
    await prefs.setString(_nameKey, userName!);
    await prefs.setString(_picKey, userPic!);
    return true;
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    token = null; userName = null; userPic = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_picKey);
  }

  static bool get isSignedIn => token != null;
}
