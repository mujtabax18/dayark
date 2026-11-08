import 'package:flutter/material.dart';

/// Lightweight GitHub-style release notes renderer.
///
/// This intentionally avoids adding a Markdown package dependency to the app.
/// It supports the formatting normally used in DayArk GitHub release notes:
/// headings, paragraphs, bullet/numbered lists, task lists, block quotes,
/// fenced code blocks, horizontal rules, and common inline Markdown.
class AppReleaseNotes extends StatelessWidget {
  const AppReleaseNotes({
    super.key,
    required this.markdown,
  });

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(markdown);
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < blocks.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _buildBlock(context, blocks[index]),
          ],
        ],
      ),
    );
  }

  Widget _buildBlock(BuildContext context, _ReleaseBlock block) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.45,
    );

    switch (block.type) {
      case _ReleaseBlockType.heading:
        final level = block.level.clamp(1, 6);
        final style = switch (level) {
          1 => theme.textTheme.titleLarge,
          2 => theme.textTheme.titleMedium,
          _ => theme.textTheme.titleSmall,
        };
        return RichText(
          text: TextSpan(
            style: style?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
            children: _inlineSpans(context, block.text, style),
          ),
        );

      case _ReleaseBlockType.bullet:
        return _ListRow(
          marker: const Text('•'),
          child: RichText(
            text: TextSpan(
              style: bodyStyle,
              children: _inlineSpans(context, block.text, bodyStyle),
            ),
          ),
        );

      case _ReleaseBlockType.numbered:
        return _ListRow(
          marker: Text('${block.number}.'),
          child: RichText(
            text: TextSpan(
              style: bodyStyle,
              children: _inlineSpans(context, block.text, bodyStyle),
            ),
          ),
        );

      case _ReleaseBlockType.task:
        return _ListRow(
          marker: Icon(
            block.checked
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            size: 18,
            color: block.checked ? scheme.primary : scheme.onSurfaceVariant,
          ),
          child: RichText(
            text: TextSpan(
              style: bodyStyle,
              children: _inlineSpans(context, block.text, bodyStyle),
            ),
          ),
        );

      case _ReleaseBlockType.quote:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(color: scheme.primary, width: 3),
            ),
          ),
          child: RichText(
            text: TextSpan(
              style: bodyStyle?.copyWith(fontStyle: FontStyle.italic),
              children: _inlineSpans(context, block.text, bodyStyle),
            ),
          ),
        );

      case _ReleaseBlockType.code:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SelectableText(
            block.text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
        );

      case _ReleaseBlockType.rule:
        return Divider(color: scheme.outlineVariant);

      case _ReleaseBlockType.paragraph:
        return RichText(
          text: TextSpan(
            style: bodyStyle,
            children: _inlineSpans(context, block.text, bodyStyle),
          ),
        );
    }
  }

  List<InlineSpan> _inlineSpans(
    BuildContext context,
    String source,
    TextStyle? baseStyle,
  ) {
    final spans = <InlineSpan>[];
    final scheme = Theme.of(context).colorScheme;
    var remaining = source;

    final token = RegExp(
      r'(\*\*[^*\n]+\*\*|__[^_\n]+__|~~[^~\n]+~~|`[^`\n]+`|\[[^\]\n]+\]\([^\)\n]+\)|\*[^*\n]+\*|_[^_\n]+_)',
    );

    while (remaining.isNotEmpty) {
      final match = token.firstMatch(remaining);
      if (match == null) {
        spans.add(TextSpan(text: _unescape(remaining)));
        break;
      }

      if (match.start > 0) {
        spans.add(TextSpan(text: _unescape(remaining.substring(0, match.start))));
      }

      final value = match.group(0)!;
      if ((value.startsWith('**') && value.endsWith('**')) ||
          (value.startsWith('__') && value.endsWith('__'))) {
        spans.add(
          TextSpan(
            text: _unescape(value.substring(2, value.length - 2)),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (value.startsWith('~~') && value.endsWith('~~')) {
        spans.add(
          TextSpan(
            text: _unescape(value.substring(2, value.length - 2)),
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
        );
      } else if (value.startsWith('`') && value.endsWith('`')) {
        spans.add(
          TextSpan(
            text: value.substring(1, value.length - 1),
            style: baseStyle?.copyWith(
              fontFamily: 'monospace',
              color: scheme.onSurface,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        );
      } else if (value.startsWith('[')) {
        final linkMatch = RegExp(r'^\[([^\]]+)\]\(([^\)]+)\)$').firstMatch(value);
        final label = linkMatch?.group(1) ?? value;
        spans.add(
          TextSpan(
            text: _unescape(label),
            style: TextStyle(
              color: scheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: scheme.primary,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: _unescape(value.substring(1, value.length - 1)),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }

      remaining = remaining.substring(match.end);
    }

    return spans;
  }

  List<_ReleaseBlock> _parseBlocks(String source) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final result = <_ReleaseBlock>[];
    final paragraph = <String>[];
    final code = <String>[];
    var inCodeBlock = false;

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      final text = paragraph.join(' ').trim();
      if (text.isNotEmpty) {
        result.add(_ReleaseBlock.paragraph(text));
      }
      paragraph.clear();
    }

    void flushCode() {
      if (code.isEmpty) return;
      result.add(_ReleaseBlock.code(code.join('\n').trimRight()));
      code.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();

      if (trimmed.startsWith('```')) {
        flushParagraph();
        if (inCodeBlock) {
          flushCode();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        code.add(rawLine);
        continue;
      }

      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }

      final heading = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(trimmed);
      if (heading != null) {
        flushParagraph();
        result.add(
          _ReleaseBlock.heading(
            heading.group(2)!.trim(),
            heading.group(1)!.length,
          ),
        );
        continue;
      }

      if (RegExp(r'^([-*_])(?:\s*\1){2,}$').hasMatch(trimmed)) {
        flushParagraph();
        result.add(const _ReleaseBlock.rule());
        continue;
      }

      final task = RegExp(r'^[-*+]\s+\[([ xX])\]\s+(.+)$').firstMatch(trimmed);
      if (task != null) {
        flushParagraph();
        result.add(
          _ReleaseBlock.task(
            task.group(2)!.trim(),
            task.group(1)!.toLowerCase() == 'x',
          ),
        );
        continue;
      }

      final bullet = RegExp(r'^[-*+]\s+(.+)$').firstMatch(trimmed);
      if (bullet != null) {
        flushParagraph();
        result.add(_ReleaseBlock.bullet(bullet.group(1)!.trim()));
        continue;
      }

      final numbered = RegExp(r'^(\d+)[.)]\s+(.+)$').firstMatch(trimmed);
      if (numbered != null) {
        flushParagraph();
        result.add(
          _ReleaseBlock.numbered(
            numbered.group(2)!.trim(),
            int.tryParse(numbered.group(1)!) ?? 1,
          ),
        );
        continue;
      }

      if (trimmed.startsWith('>')) {
        flushParagraph();
        result.add(
          _ReleaseBlock.quote(
            trimmed.replaceFirst(RegExp(r'^>\s?'), '').trim(),
          ),
        );
        continue;
      }

      paragraph.add(trimmed);
    }

    flushParagraph();
    if (inCodeBlock) {
      flushCode();
    }

    return result;
  }

  String _unescape(String value) {
    return value.replaceAllMapped(
      RegExp(r'\\([\\`*_{}\[\]()#+\-.!>])'),
      (match) => match.group(1)!,
    );
  }
}

enum _ReleaseBlockType {
  paragraph,
  heading,
  bullet,
  numbered,
  task,
  quote,
  code,
  rule,
}

class _ReleaseBlock {
  const _ReleaseBlock._({
    required this.type,
    required this.text,
    this.level = 0,
    this.number = 0,
    this.checked = false,
  });

  const _ReleaseBlock.paragraph(String text)
      : this._(type: _ReleaseBlockType.paragraph, text: text);

  const _ReleaseBlock.heading(String text, int level)
      : this._(
          type: _ReleaseBlockType.heading,
          text: text,
          level: level,
        );

  const _ReleaseBlock.bullet(String text)
      : this._(type: _ReleaseBlockType.bullet, text: text);

  const _ReleaseBlock.numbered(String text, int number)
      : this._(
          type: _ReleaseBlockType.numbered,
          text: text,
          number: number,
        );

  const _ReleaseBlock.task(String text, bool checked)
      : this._(
          type: _ReleaseBlockType.task,
          text: text,
          checked: checked,
        );

  const _ReleaseBlock.quote(String text)
      : this._(type: _ReleaseBlockType.quote, text: text);

  const _ReleaseBlock.code(String text)
      : this._(type: _ReleaseBlockType.code, text: text);

  const _ReleaseBlock.rule()
      : this._(type: _ReleaseBlockType.rule, text: '');

  final _ReleaseBlockType type;
  final String text;
  final int level;
  final int number;
  final bool checked;
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.marker,
    required this.child,
  });

  final Widget marker;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 26,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
            child: Center(child: marker),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(child: child),
      ],
    );
  }
}
