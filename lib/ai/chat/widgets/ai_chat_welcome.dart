import 'package:flutter/material.dart';

class AiChatWelcome extends StatelessWidget {
  const AiChatWelcome({
    super.key,
    required this.configured,
    required this.onPrompt,
    required this.onSetup,
  });
  final bool configured;
  final ValueChanged<String> onPrompt;
  final VoidCallback onSetup;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 38,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'How can DayArk help?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -.8),
            ),
            const SizedBox(height: 12),
            Text(
              'A little clarity. A new idea. Your next step.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            if (configured)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final item in const [
                    (Icons.edit_outlined, 'Help me write', 'Help me write: '),
                    (Icons.code_rounded, 'Learn coding', 'Explain this code: '),
                    (
                      Icons.lightbulb_outline,
                      'Brainstorm ideas',
                      'Brainstorm ideas for: ',
                    ),
                    (
                      Icons.calendar_today_outlined,
                      'Make a plan',
                      'Help me plan: ',
                    ),
                  ])
                    OutlinedButton.icon(
                      onPressed: () => onPrompt(item.$3),
                      icon: Icon(item.$1, size: 18),
                      label: Text(item.$2),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                ],
              )
            else
              FilledButton(onPressed: onSetup, child: const Text('Set up AI')),
          ],
        ),
      ),
    ),
  );
}
