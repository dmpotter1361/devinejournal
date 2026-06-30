import 'package:flutter/material.dart';

class EntryTemplate {
  final String id;
  final String label;
  final String icon;
  final String title;
  final String body;
  final String mood;

  const EntryTemplate({
    required this.id,
    required this.label,
    required this.icon,
    required this.title,
    required this.body,
    required this.mood,
  });
}

const List<EntryTemplate> entryTemplates = [
  EntryTemplate(
    id: 'blank',
    label: 'Blank Page',
    icon: '📄',
    title: '',
    body: '',
    mood: '',
  ),
  EntryTemplate(
    id: 'dream',
    label: 'Dream Log',
    icon: '🌙',
    title: 'Dream Log',
    body: '**What I remember:**\n\n\n**How it felt:**\n\n\n**Symbols or recurring images:**\n\n\n**Possible meaning:**\n',
    mood: '🌙',
  ),
  EntryTemplate(
    id: 'ritual',
    label: 'Moon Ritual',
    icon: '🌕',
    title: 'Moon Ritual',
    body: '**Moon phase:**\n\n**Intention I am setting:**\n\n\n**What I released:**\n\n\n**What I called in:**\n\n\n**Tools / candles / cards used:**\n',
    mood: '💫',
  ),
  EntryTemplate(
    id: 'checkin',
    label: 'Daily Check-In',
    icon: '☀️',
    title: 'Daily Check-In',
    body: '**How I feel right now:**\n\n\n**One thing that went well today:**\n\n\n**One thing that was hard:**\n\n\n**What I need before bed:**\n',
    mood: '✨',
  ),
  EntryTemplate(
    id: 'future',
    label: 'Letter to Future Self',
    icon: '💌',
    title: 'Dear Future Me',
    body: 'Dear future me,\n\n\n\n\nLove, present me — ',
    mood: '💝',
  ),
  EntryTemplate(
    id: 'travel',
    label: 'Travel Note',
    icon: '🧳',
    title: 'Travel Note',
    body: '**Where I am:**\n\n**Who I am with:**\n\n**A moment worth keeping:**\n\n\n**Something I tasted, saw, or heard:**\n',
    mood: '🌊',
  ),
  EntryTemplate(
    id: 'intention',
    label: 'Spell & Intention',
    icon: '🕯️',
    title: 'Spell Work',
    body: '**Purpose of this working:**\n\n\n**Ingredients / correspondences:**\n\n\n**Words spoken:**\n\n\n**What I felt during and after:**\n',
    mood: '🔥',
  ),
  EntryTemplate(
    id: 'shadow',
    label: 'Shadow Work',
    icon: '🖤',
    title: 'Shadow Work',
    body: '**What triggered me today:**\n\n\n**What it brought up from my past:**\n\n\n**What that part of me needs to hear:**\n\n\n**One compassionate truth:**\n',
    mood: '🖤',
  ),
];

Future<EntryTemplate?> pickEntryTemplate(
  BuildContext context, {
  required dynamic theme,
}) {
  final t = theme;
  return showModalBottomSheet<EntryTemplate>(
    context: context,
    backgroundColor: t.paper,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Begin from…',
              style: TextStyle(
                color: t.heading,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.55),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: entryTemplates.map((tpl) {
                    return GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(tpl),
                      child: Container(
                        width: 140,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                        decoration: BoxDecoration(
                          color: t.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: t.border, width: 0.7),
                        ),
                        child: Column(
                          children: [
                            Text(tpl.icon, style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 8),
                            Text(
                              tpl.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: t.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
