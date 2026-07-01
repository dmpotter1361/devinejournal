import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/theme_service.dart';
import '../utils/body_utils.dart';

class _GardenItem {
  final String text;
  final DateTime date;
  final String flower;
  const _GardenItem({required this.text, required this.date, required this.flower});
}

const _flowerPool = ['🌸', '🌼', '🌻', '🌷', '🌹', '💐', '🌺', '🪻'];

class GardenScreen extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  const GardenScreen({super.key, required this.entries});

  List<_GardenItem> _items() {
    final gratitudeEntries = entries.where((e) {
      final tags = (e['tags'] as String? ?? '').toLowerCase();
      return tags.split(',').map((s) => s.trim()).contains('gratitude');
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime.now();
        final db = DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime.now();
        return da.compareTo(db);
      });

    final items = <_GardenItem>[];
    for (final e in gratitudeEntries) {
      final date = DateTime.tryParse(e['created_at'] as String? ?? '') ?? DateTime.now();
      final body = bodyToPlainText(e['body'] as String? ?? '').trim();
      final lines = body
          .split('\n')
          .map((l) => l.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final lineSet = lines.isNotEmpty ? lines : (body.isNotEmpty ? [body] : <String>[]);
      for (final line in lineSet) {
        items.add(_GardenItem(
          text: line,
          date: date,
          flower: _flowerPool[items.length % _flowerPool.length],
        ));
      }
    }
    return items;
  }

  void _showFlower(BuildContext context, dynamic t, _GardenItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Text(item.flower, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Text(DateFormat('MMMM d, yyyy').format(item.date.toLocal()),
              style: GoogleFonts.cormorant(
                  color: t.heading, fontSize: 17, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic)),
        ]),
        content: Text(item.text,
            style: GoogleFonts.lora(color: t.ink, fontSize: 15, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: t.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeService.current;
    final items = _items();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.appBarBg,
        foregroundColor: t.appBarFg,
        title: Text('Gratitude Garden',
            style: GoogleFonts.cinzelDecorative(color: t.appBarFg, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌱', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 16),
                    Text('Your garden is still a quiet patch of soil.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cormorant(
                            color: t.heading, fontSize: 20, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    Text('Plant a gratitude entry and watch it grow.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.muted, fontSize: 14)),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  child: Text(
                    '${items.length} ${items.length == 1 ? 'bloom' : 'blooms'} planted since you began',
                    style: GoogleFonts.cormorant(
                        color: t.heading, fontSize: 18, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: t.border, width: 0.7),
                    ),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: items.map((item) {
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.elasticOut,
                            builder: (_, v, child) => Transform.scale(scale: v, child: child),
                            child: GestureDetector(
                              onTap: () => _showFlower(context, t, item),
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: t.paper,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: t.border, width: 0.6),
                                ),
                                child: Center(
                                  child: Text(item.flower, style: const TextStyle(fontSize: 26)),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
