import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

const apiBase = 'https://journal.devinetarot.net';

Map<String, String> get _headers => {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer ${AuthService.token}',
};

class ApiService {
  static Future<List<Map<String, dynamic>>> getEntries() async {
    final res = await http.get(Uri.parse('$apiBase/api/entries'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load entries');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createEntry({
    required String title,
    required String body,
    required String mood,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBase/api/entries'),
      headers: _headers,
      body: jsonEncode({'title': title, 'body': body, 'mood': mood}),
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
  }) async {
    final res = await http.put(
      Uri.parse('$apiBase/api/entries/$id'),
      headers: _headers,
      body: jsonEncode({
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (mood != null) 'mood': mood,
      }),
    );
    if (res.statusCode != 200) throw Exception('Failed to update entry');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
