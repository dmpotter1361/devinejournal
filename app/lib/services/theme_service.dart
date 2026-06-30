import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

const _key = 'dj_paper_theme';

class ThemeService {
  static PaperTheme current = paperThemeMidnight;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key) ?? 'midnight';
    current = paperThemeById(id);
  }

  static Future<void> set(PaperTheme theme) async {
    current = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, theme.id);
  }
}
