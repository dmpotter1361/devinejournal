import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'entry_screen.dart';

class TimelineScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  const TimelineScreen({super.key, required this.onSignOut});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final entries = await ApiService.getEntries();
      setState(() { _entries = entries; });
    } catch (e) {
      setState(() { _error = '$e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _newEntry() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EntryScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _openEntry(Map<String, dynamic> entry) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EntryScreen(entry: entry)),
    );
    if (changed == true) _load();
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DevineJournal', style: TextStyle(letterSpacing: 1)),
        actions: [
          if (AuthService.userPic != null && AuthService.userPic!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(AuthService.userPic!),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: kLavender),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      backgroundColor: kDark,
      floatingActionButton: FloatingActionButton(
        onPressed: _newEntry,
        tooltip: 'New entry',
        child: const Icon(Icons.edit),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : _entries.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: kGold,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _entries.length,
                        itemBuilder: (_, i) => _entryCard(_entries[i]),
                      ),
                    ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🌙', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'Your journal awaits',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: kLavender),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap ✦ to write your first entry',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kLavender.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _entryCard(Map<String, dynamic> entry) {
    final date = DateTime.tryParse(entry['created_at'] ?? '');
    final dateStr = date != null ? DateFormat('MMM d, yyyy').format(date.toLocal()) : '';
    final mood = entry['mood'] as String? ?? '';
    final title = entry['title'] as String? ?? '';
    final body = entry['body'] as String? ?? '';
    final preview = body.length > 120 ? '${body.substring(0, 120)}…' : body;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openEntry(entry),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (mood.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(mood, style: const TextStyle(fontSize: 20)),
                    ),
                  Expanded(
                    child: Text(
                      title.isNotEmpty ? title : 'Untitled',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: title.isNotEmpty ? kGold : kLavender.withOpacity(0.5),
                        fontStyle: title.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(dateStr, style: TextStyle(color: kLavender.withOpacity(0.6), fontSize: 12)),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  preview,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kMoonWhite.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
