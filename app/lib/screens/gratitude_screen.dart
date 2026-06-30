import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';

class GratitudeScreen extends StatefulWidget {
  const GratitudeScreen({super.key});

  @override
  State<GratitudeScreen> createState() => _GratitudeScreenState();
}

class _GratitudeScreenState extends State<GratitudeScreen> {
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _c3 = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _c1.dispose(); _c2.dispose(); _c3.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final items = [_c1.text.trim(), _c2.text.trim(), _c3.text.trim()]
        .where((s) => s.isNotEmpty)
        .toList();
    if (items.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _saving = true);
    try {
      final date = DateFormat('MMMM d, yyyy').format(DateTime.now());
      final body = items.asMap().entries
          .map((e) => '${e.key + 1}. ${e.value}')
          .join('\n');
      await ApiService.createEntry(
        title: 'Gratitude — $date',
        body: body,
        mood: '✨',
        tags: 'gratitude',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.redAccent),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeService.current;
    return Scaffold(
      backgroundColor: t.paper,
      appBar: AppBar(
        backgroundColor: t.appBarBg,
        foregroundColor: t.appBarFg,
        title: Text(
          'Gratitude',
          style: GoogleFonts.cinzelDecorative(color: t.appBarFg, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          _saving
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: t.appBarFg)),
                )
              : IconButton(
                  icon: Icon(Icons.check_rounded, color: t.appBarFg),
                  onPressed: _save,
                  tooltip: 'Save',
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 36)),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today I am grateful for…',
                      style: GoogleFonts.cormorant(
                        color: t.heading,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMMM d').format(DateTime.now()),
                      style: TextStyle(color: t.muted, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            _gratitudeField(t, 1, _c1),
            const SizedBox(height: 20),
            _gratitudeField(t, 2, _c2),
            const SizedBox(height: 20),
            _gratitudeField(t, 3, _c3),

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.accent.withValues(alpha: 0.2), width: 0.7),
              ),
              child: Text(
                'Gratitude rewires the mind toward beauty. Even one true thing is enough.',
                style: GoogleFonts.lora(
                  color: t.muted,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gratitudeField(dynamic t, int num, TextEditingController ctrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 10, right: 14),
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: t.accent.withValues(alpha: 0.4), width: 0.8),
          ),
          child: Center(
            child: Text(
              '$num',
              style: GoogleFonts.cinzelDecorative(color: t.accent, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: ctrl,
            maxLines: 3,
            minLines: 2,
            textInputAction: num < 3 ? TextInputAction.next : TextInputAction.done,
            style: GoogleFonts.lora(color: t.ink, fontSize: 15, height: 1.7),
            decoration: InputDecoration(
              hintText: num == 1 ? 'Something that brought you joy…'
                      : num == 2 ? 'Someone who matters to you…'
                                 : 'A small thing you might overlook…',
              hintStyle: GoogleFonts.lora(
                color: t.muted.withValues(alpha: 0.45),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              filled: true,
              fillColor: t.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: t.border, width: 0.7),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: t.border, width: 0.7),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: t.accent, width: 1.2),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }
}
