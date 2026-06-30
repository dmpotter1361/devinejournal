import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyHash    = 'dj_pin_hash';
const _keyTimeout = 'dj_lock_timeout';

class PasscodeService {
  static bool hasPasscode    = false;
  static bool isLocked       = false;
  static int  timeoutSeconds = 0;
  static String? _hash;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _hash          = prefs.getString(_keyHash);
    hasPasscode    = _hash != null;
    timeoutSeconds = prefs.getInt(_keyTimeout) ?? 0;
    isLocked       = false;
  }

  static Future<void> setPasscode(String pin) async {
    _hash = sha256.convert(utf8.encode(pin)).toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHash, _hash!);
    hasPasscode = true;
  }

  static Future<void> clearPasscode() async {
    _hash = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHash);
    hasPasscode = false;
    isLocked    = false;
  }

  static bool verifyPasscode(String pin) {
    if (_hash == null) return false;
    return sha256.convert(utf8.encode(pin)).toString() == _hash;
  }

  static Future<void> setTimeout(int seconds) async {
    timeoutSeconds = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTimeout, seconds);
  }

  static void lock()   { isLocked = true; }
  static void unlock() { isLocked = false; }
}
