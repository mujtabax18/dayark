import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Incrementally seals small Markdown blocks. Raw text is never discarded.
/// Fence state is carried across blocks so long code listings stay code listings.
class AiMarkdownBlocks {
  static const blockSize = 2048;
  final List<String> blocks = [];
  int _sealed = 0;
  String _previous = '', _tail = '';
  String? _fence;
  String _language = '';
  int get length => blocks.length + (_tail.isEmpty ? 0 : 1);
  String operator [](int index) =>
      index < blocks.length ? blocks[index] : _tail;

  void update(String text) {
    if (identical(text, _previous)) return;
    if (text.length < _previous.length || !text.startsWith(_previous)) {
      blocks.clear();
      _sealed = 0;
      _fence = null;
      _language = '';
    }
    _previous = text;
    while (text.length - _sealed > blockSize) {
      var end = _sealed + blockSize;
      final newline = text.lastIndexOf('\n', end);
      if (newline >= _sealed + blockSize ~/ 2) end = newline + 1;
      // Never cut between the halves of a UTF-16 surrogate pair.
      final unit = text.codeUnitAt(end - 1);
      if (unit >= 0xd800 && unit <= 0xdbff) end--;
      blocks.add(_format(text.substring(_sealed, end), commit: true));
      _sealed = end;
    }
    _tail = _format(text.substring(_sealed), commit: false);
  }

  String _format(String text, {required bool commit}) {
    final initialFence = _fence;
    final initialLanguage = _language;
    var fence = _fence;
    var language = _language;
    for (final match in RegExp(
      r'^ {0,3}(`{3,}|~{3,})([^\n]*)$',
      multiLine: true,
    ).allMatches(text)) {
      final marker = match[1]!;
      if (fence == null) {
        fence = marker;
        language = match[2]!.trim();
      } else if (marker[0] == fence[0] &&
          marker.length >= fence.length &&
          match[2]!.trim().isEmpty) {
        fence = null;
        language = '';
      }
    }
    final result =
        '${initialFence == null ? '' : '$initialFence$initialLanguage\n'}$text${fence == null ? '' : '\n$fence'}';
    if (commit) {
      _fence = fence;
      _language = language;
    }
    return result;
  }
}

/// Small replies keep their normal layout. Large replies are lazily laid out in
/// a bounded viewport: parsing/layout cost depends on visible blocks, not on the
/// lifetime length of an Ollama stream. The caller still owns the complete text.
class AiResponseText extends StatefulWidget {
  const AiResponseText({
    super.key,
    required this.data,
    this.live = false,
    this.selectable = true,
    this.maxHeight = 360,
    this.styleSheet,
    this.onTapLink,
    this.imageBuilder,
  });
  final String data;
  final bool live, selectable;
  final double maxHeight;
  final MarkdownStyleSheet? styleSheet;
  final MarkdownTapLinkCallback? onTapLink;
  final MarkdownImageBuilder? imageBuilder;
  @override
  State<AiResponseText> createState() => _AiResponseTextState();
}

class _AiResponseTextState extends State<AiResponseText> {
  final _blocks = AiMarkdownBlocks();
  final _scroll = ScrollController();
  final _rendered = <int, Widget>{};
  ThemeData? _theme;
  String? _smallSource;
  Widget? _small;
  bool _following = true;
  late final bool _reverse;
  int _scrollVersion = 0;

  @override
  void initState() {
    super.initState();
    // Anchor live text at its tail. Seeking to the estimated end of a forward
    // variable-height list can force Flutter to measure every preceding block.
    _reverse = widget.live;
    _blocks.update(widget.data);
    if (widget.live && widget.data.length > 4096) _follow();
  }

  @override
  void didUpdateWidget(AiResponseText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = _blocks.blocks.length;
    final append = widget.data.startsWith(oldWidget.data);
    _blocks.update(widget.data);
    if (!append) {
      _rendered.clear();
      _following = true;
    }
    // Only a mutable tail is invalidated; sealed blocks keep their widgets.
    _rendered.removeWhere((index, _) => index >= previous);
    if (widget.live && _following && widget.data.length > 4096) _follow();
  }

  void _follow() {
    final version = ++_scrollVersion;
    void jump(int remaining) =>
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              version != _scrollVersion ||
              !_following ||
              !_scroll.hasClients) {
            return;
          }
          _scroll.jumpTo(_reverse ? 0 : _scroll.position.maxScrollExtent);
          if (!_reverse && remaining > 0) jump(remaining - 1);
        });
    jump(1);
  }

  Widget _markdown(String text) => MarkdownBody(
    data: text,
    selectable: widget.selectable,
    styleSheet: widget.styleSheet,
    onTapLink: widget.onTapLink,
    imageBuilder:
        widget.imageBuilder ?? (_, _, _) => const Text('[Image omitted]'),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!identical(_theme, theme)) {
      _theme = theme;
      _rendered.clear();
      _small = null;
    }
    if (widget.data.length <= 4096) {
      if (_small == null || _smallSource != widget.data) {
        _smallSource = widget.data;
        _small = _markdown(widget.data);
      }
      return _small!;
    }
    return SizedBox(
      height: widget.maxHeight,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification &&
                  notification.dragDetails != null ||
              notification is UserScrollNotification) {
            _following =
                (_reverse
                    ? notification.metrics.extentBefore
                    : notification.metrics.extentAfter) <
                96;
          }
          return false;
        },
        child: Scrollbar(
          thumbVisibility: true,
          controller: _scroll,
          child: ListView.builder(
            key: const ValueKey('ai-long-text'),
            controller: _scroll,
            primary: false,
            reverse: _reverse,
            itemCount: _blocks.length,
            findChildIndexCallback: (key) => key is ValueKey<int>
                ? (_reverse ? _blocks.length - 1 - key.value : key.value)
                : null,
            itemBuilder: (_, index) {
              final logical = _reverse ? _blocks.length - 1 - index : index;
              return _rendered.putIfAbsent(
                logical,
                () => RepaintBoundary(
                  key: ValueKey(logical),
                  child: _markdown(_blocks[logical]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollVersion++;
    _scroll.dispose();
    super.dispose();
  }
}
