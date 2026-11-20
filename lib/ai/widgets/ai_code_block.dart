import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

class AiCodeBlockBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.children?.whereType<md.Element>().firstOrNull;
    final language =
        code?.attributes['class']?.replaceFirst('language-', '') ?? 'text';
    return AiCodeBlock(
      code: element.textContent.replaceFirst(RegExp(r'\n$'), ''),
      language: language,
    );
  }
}

/// Generated code is selectable text only; actions never execute it.
class AiCodeBlock extends StatefulWidget {
  const AiCodeBlock({super.key, required this.code, required this.language});
  final String code, language;
  @override
  State<AiCodeBlock> createState() => _AiCodeBlockState();
}

class _AiCodeBlockState extends State<AiCodeBlock> {
  bool _expanded = false, _wrap = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final long = '\n'.allMatches(widget.code).length > 20;
    final text = SelectableText(
      widget.code,
      style: theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        height: 1.6,
      ),
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.language,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                IconButton(
                  tooltip: _wrap ? 'Disable code wrapping' : 'Wrap code',
                  icon: const Icon(Icons.wrap_text, size: 17),
                  onPressed: () => setState(() => _wrap = !_wrap),
                ),
                IconButton(
                  tooltip: 'Save code to file',
                  icon: const Icon(Icons.save_alt, size: 17),
                  onPressed: () async {
                    final extension = switch (widget.language.toLowerCase()) {
                      'dart' => 'dart',
                      'python' || 'py' => 'py',
                      'javascript' || 'js' => 'js',
                      'typescript' || 'ts' => 'ts',
                      'json' => 'json',
                      'html' => 'html',
                      'css' => 'css',
                      'bash' || 'sh' => 'sh',
                      'sql' => 'sql',
                      _ => 'txt',
                    };
                    try {
                      await FilePicker.saveFile(
                        fileName: 'dayark-code.$extension',
                        bytes: Uint8List.fromList(utf8.encode(widget.code)),
                        mimeType: 'text/plain',
                      );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Unable to save code. Copy it and save in your editor.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Copy code',
                  icon: const Icon(Icons.copy_outlined, size: 17),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: widget.code)),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: long && !_expanded ? 280 : double.infinity,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _wrap
                    ? text
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: text,
                      ),
              ),
            ),
          ),
          if (long)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Collapse code' : 'Expand code'),
            ),
        ],
      ),
    );
  }
}
