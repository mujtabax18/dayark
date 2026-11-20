import 'package:flutter/material.dart';

import '../../settings/ai_settings.dart';
import '../ai_conversation.dart';

/// A passive view of supplied state; never polls hardware or starts inference.
class AiWorkspaceInspector extends StatelessWidget {
  const AiWorkspaceInspector({
    super.key,
    required this.settings,
    required this.model,
    required this.local,
    required this.message,
    required this.activity,
    required this.onSettings,
    required this.onInstructions,
    required this.onClose,
  });
  final AiSettings settings;
  final String? model, activity;
  final bool local;
  final AiChatMessage? message;
  final VoidCallback onSettings, onInstructions, onClose;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = message;
    Widget detail(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          SelectableText(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
    return Container(
      key: const ValueKey('ai-runtime-inspector'),
      width: 244,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Runtime inspector',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'Hide inspector',
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const Divider(),
          detail('Model', model ?? 'No model selected'),
          detail(
            'Processing',
            local ? 'On device · Private' : 'Configured provider',
          ),
          detail(
            'Runtime backend',
            local
                ? 'Backend not reported by native adapter'
                : 'Managed by provider',
          ),
          if (activity != null) detail('Status', activity!),
          if (last?.outputTokens != null)
            detail('Generated tokens', '${last!.outputTokens}'),
          if (last?.inputTokens != null)
            detail('Last prompt tokens', '${last!.inputTokens}'),
          if (last?.firstTokenMilliseconds != null)
            detail(
              'First streamed token',
              '${last!.firstTokenMilliseconds} ms',
            ),
          if (last?.firstVisibleTokenMilliseconds != null)
            detail(
              'First visible token',
              '${last!.firstVisibleTokenMilliseconds} ms',
            ),
          if (last?.elapsedMilliseconds != null)
            detail(
              'Response duration',
              '${(last!.elapsedMilliseconds! / 1000).toStringAsFixed(1)} seconds',
            ),
          const Divider(),
          detail('Profile', settings.performanceProfile),
          detail(
            'Thinking',
            settings.thinking == null
                ? 'Model default'
                : settings.thinking!
                ? 'Enabled where supported'
                : 'Disabled where supported',
          ),
          detail(
            'Output budget',
            settings.maxOutputTokens == null
                ? 'Provider default'
                : '${settings.maxOutputTokens} tokens',
          ),
          detail(
            'Context ceiling',
            settings.contextWindowTokens == null
                ? 'Model and hardware managed'
                : '${settings.contextWindowTokens} tokens · clamped by runtime',
          ),
          detail(
            'Temperature',
            settings.temperature?.toString() ?? 'Provider default',
          ),
          const Divider(),
          TextButton.icon(
            onPressed: onInstructions,
            icon: const Icon(Icons.edit_note, size: 18),
            label: const Text('Instructions'),
          ),
          TextButton.icon(
            onPressed: onSettings,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Advanced settings'),
          ),
        ],
      ),
    );
  }
}
