import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

const apiBase = 'https://journal.devinetarot.net';

Map<String, String> get _headers => {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer ${AuthService.token}',
};

Map<String, String> get _authHeader => {
  'Authorization': 'Bearer ${AuthService.token}',
};

class ApiService {
  // ── Entries ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getEntries() async {
    final res = await http.get(Uri.parse('$apiBase/api/entries'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load entries');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createEntry({
    required String title,
    required String body,
    required String mood,
    String tags = '',
    String? lockedUntil,
    String paperStyle = 'lined',
    bool isFavorite = false,
    String? themeId,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBase/api/entries'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'body': body,
        'mood': mood,
        'tags': tags,
        if (lockedUntil != null) 'locked_until': lockedUntil,
        'paper_style': paperStyle,
        'is_favorite': isFavorite,
        if (themeId != null) 'theme_id': themeId,
      }),
    );
    if (res.statusCode != 201) throw Exception('Failed to create entry');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> deleteEntry(String id) async {
    final res = await http.delete(Uri.parse('$apiBase/api/entries/$id'), headers: _headers);
    if (res.statusCode != 204) throw Exception('Failed to delete entry');
  }

  static Future<Map<String, dynamic>> updateEntry(
    String id, {
    String? title,
    String? body,
    String? mood,
    String? tags,
    String? lockedUntil,
    bool clearLock = false,
    String? paperStyle,
    bool? isFavorite,
    String? themeId,
  }) async {
    final res = await http.put(
      Uri.parse('$apiBase/api/entries/$id'),
      headers: _headers,
      body: jsonEncode({
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (mood != null) 'mood': mood,
        if (tags != null) 'tags': tags,
        if (lockedUntil != null) 'locked_until': lockedUntil,
        if (clearLock) 'locked_until': null,
        if (paperStyle != null) 'paper_style': paperStyle,
        if (isFavorite != null) 'is_favorite': isFavorite,
        if (themeId != null) 'theme_id': themeId,
      }),
    );
    if (res.statusCode != 200) throw Exception('Failed to update entry');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Photos ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> uploadPhoto(
    String entryId,
    Uint8List bytes,
    String filename,
  ) async {
    final uri = Uri.parse('$apiBase/api/entries/$entryId/photos');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeader)
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send();
    if (streamed.statusCode != 201) throw Exception('Failed to upload photo');
    final body = await streamed.stream.bytesToString();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getPhotos(String entryId) async {
    final res = await http.get(
      Uri.parse('$apiBase/api/entries/$entryId/photos'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to load photos');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> updatePhoto(
    String photoId, {
    String? widthPct,
    String? align,
    String? caption,
  }) async {
    final res = await http.put(
      Uri.parse('$apiBase/api/photos/$photoId'),
      headers: _headers,
      body: jsonEncode({
        if (widthPct != null) 'width_pct': widthPct,
        if (align != null) 'align': align,
        if (caption != null) 'caption': caption,
      }),
    );
    if (res.statusCode != 200) throw Exception('Failed to update photo');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> deletePhoto(String photoId) async {
    final res = await http.delete(
      Uri.parse('$apiBase/api/photos/$photoId'),
      headers: _headers,
    );
    if (res.statusCode != 204) throw Exception('Failed to delete photo');
  }

  // ── Voice memos ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> uploadVoiceMemo(
    String entryId,
    Uint8List bytes,
    String filename,
    int durationMs,
  ) async {
    final uri = Uri.parse('$apiBase/api/entries/$entryId/voice-memos');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeader)
      ..fields['duration_ms'] = '$durationMs'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send();
    if (streamed.statusCode != 201) throw Exception('Failed to upload voice memo');
    final body = await streamed.stream.bytesToString();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getVoiceMemos(String entryId) async {
    final res = await http.get(
      Uri.parse('$apiBase/api/entries/$entryId/voice-memos'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to load voice memos');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  static Future<void> deleteVoiceMemo(String memoId) async {
    final res = await http.delete(
      Uri.parse('$apiBase/api/voice-memos/$memoId'),
      headers: _headers,
    );
    if (res.statusCode != 204) throw Exception('Failed to delete voice memo');
  }
}
