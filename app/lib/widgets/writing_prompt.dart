import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _prompts = [
  'What made you smile today, even just a little?',
  'Describe your current mood using only weather...',
  'What is something you are looking forward to?',
  'What would you tell your past self from one year ago?',
  'Name three things you noticed today that you might normally overlook.',
  'What does your ideal day look like from start to finish?',
  'What is a recent challenge you grew through?',
  'Write about a memory that always makes you happy.',
  'What are you most proud of in yourself right now?',
  'What does rest look like for you? Are you getting enough?',
  'Describe a place where you feel completely at peace.',
  'What song perfectly captures your mood today?',
  'What is one small thing you can do tomorrow to take care of yourself?',
  'If your feelings were a season, what season would they be and why?',
  'What relationship in your life is bringing you the most joy lately?',
  'Write about someone who inspires you and why.',
  'What is something you have been putting off that you could release today?',
  'Describe your dream home in vivid detail.',
  'What did today teach you?',
  'What would you do if you were not afraid?',
  'Write about a smell that brings back a strong memory.',
  'What creative project are you dreaming of starting?',
  'What are five things your body does for you that you are grateful for?',
  'Describe your morning routine and how it makes you feel.',
  'What is something you forgave yourself for recently?',
  'Write a letter to the moon.',
  'What has the universe been trying to tell you lately?',
  'What magic is hiding in your everyday life?',
  'If today were a page in a novel, what would the narrator say?',
  'What does it feel like to be you in this exact moment?',
];

class WritingPromptCard extends StatefulWidget {
  final Color paperColor;
  final Color accentColor;
  final Color inkColor;
  final Color mutedColor;
  final void Function(String prompt) onUse;
  final VoidCallback onDismiss;

  const WritingPromptCard({
    super.key,
    required this.paperColor,
    required this.accentColor,
    required this.inkColor,
    required this.mutedColor,
    required this.onUse,
    required this.onDismiss,
  });

  @override
  State<WritingPromptCard> createState() => _WritingPromptCardState();
}

class _WritingPromptCardState extends State<WritingPromptCard> {
  late String _prompt;

  @override
  void initState() {
    super.initState();
    _prompt = _prompts[Random().nextInt(_prompts.length)];
  }

  void _shuffle() {
    setState(() {
      _prompt = _prompts[Random().nextInt(_prompts.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: widget.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.accentColor.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✦', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Writing prompt',
                  style: TextStyle(
                    color: widget.accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _prompt,
                  style: GoogleFonts.lora(
                    color: widget.inkColor,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _chip('Use this', widget.accentColor, () => widget.onUse(_prompt)),
                    const SizedBox(width: 8),
                    _chip('Another', widget.mutedColor, _shuffle),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onDismiss,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: widget.mutedColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.7),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
