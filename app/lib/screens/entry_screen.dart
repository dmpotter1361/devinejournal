import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

const _moods = ['', '✨', '🌙', '🌸', '🔥', '💫', '🌿', '🖤', '💜', '🌊', '⚡', '🌻'];

class EntryScreen extends StatefulWidget {
  final Map<String, dynamic>? entry;
  const EntryScreen({super.key, this.entry});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late String _mood;
  bool _saving = false;
  bool _dirty = false;

  bool get _isEdit => widget.entry != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.entry?['title'] ?? '');
    _body  = TextEditingController(text: widget.entry?['body'] ?? '');
    _mood  = widget.entry?['mood'] ?? '';
    _title.addListener(() => setState(() => _dirty = true));
    _body.addListener(()  => setState(() => _dirty = true));
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; });
    try {
      if (_isEdit) {
        await ApiService.updateEntry(
          widget.entry!['id'] as String,
          title: _title.text,
          body: _body.text,
          mood: _mood,
        );
      } else {
        await ApiService.createEntry(
          title: _title.text,
          body: _body.text,
          mood: _mood,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Delete entry?', style: TextStyle(color: kGold)),
        content: const Text('This cannot be undone.', style: TextStyle(color: kMoonWhite)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: kLavender))),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteEntry(widget.entry!['id'] as String);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDark,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Entry' : 'New Entry'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _delete,
            ),
          if (_dirty || !_isEdit)
            _saving
                ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kGold)))
                : IconButton(
                    icon: const Icon(Icons.check, color: kGold),
                    onPressed: _save,
                  ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mood picker
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _moods.length,
                itemBuilder: (_, i) {
                  final m = _moods[i];
                  final selected = _mood == m;
                  return GestureDetector(
                    onTap: () => setState(() { _mood = m; _dirty = true; }),
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: selected ? kGold.withOpacity(0.2) : kSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? kGold : kLavender.withOpacity(0.3),
                          width: selected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Center(
                        child: m.isEmpty
                            ? Icon(Icons.mood, size: 18, color: selected ? kGold : kLavender.withOpacity(0.5))
                            : Text(m, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: kGold),
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
              ),
            ),
            const Divider(color: kLavender, height: 1, thickness: 0.3),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _body,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: kMoonWhite,
                  height: 1.7,
                ),
                decoration: const InputDecoration(
                  hintText: 'Write your thoughts…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
