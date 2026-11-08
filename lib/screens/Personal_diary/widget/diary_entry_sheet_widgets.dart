part of 'DiaryEntrySheet.dart';

class _DiaryEditorHeader extends StatelessWidget {
  const _DiaryEditorHeader({
    required this.selectedDate,
    required this.emoji,
    required this.accent,
    required this.onDateTap,
    required this.onEmojiTap,
  });

  final DateTime selectedDate;
  final String emoji;
  final Color accent;
  final VoidCallback onDateTap;
  final VoidCallback onEmojiTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accent.withValues(alpha: .72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onEmojiTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: InkWell(
              onTap: onDateTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE').format(selectedDate),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .82),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('d MMMM yyyy').format(selectedDate),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('h:mm a').format(selectedDate),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .82),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Icon(Icons.edit_calendar_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

class _PaperEditor extends StatelessWidget {
  const _PaperEditor({
    required this.titleController,
    required this.notesController,
    required this.neutral,
  });

  final TextEditingController titleController;
  final TextEditingController notesController;
  final dynamic neutral;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperColor = isDark ? neutral.card : const Color(0xFFFFFDF7);
    final primaryTextColor = neutral.textPrimary;
    final secondaryTextColor = neutral.textSecondary;
    final dividerColor = neutral.divider;

    return Container(
      decoration: BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .18 : .07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _RuledPaperPainter(
          lineColor: isDark
              ? dividerColor.withValues(alpha: .65)
              : const Color(0xFFDCE7F3),
          marginColor: isDark
              ? const Color(0xFF9F5F67).withValues(alpha: .65)
              : const Color(0xFFF4B9B9),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 20, 28),
          child: Column(
            children: [
              TextField(
                controller: titleController,
                maxLength: 80,
                cursorColor: Theme.of(context).colorScheme.primary,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Give this day a title…',
                  hintStyle: TextStyle(color: secondaryTextColor),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Divider(color: dividerColor),
              TextField(
                controller: notesController,
                minLines: 10,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                cursorColor: Theme.of(context).colorScheme.primary,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 17,
                  height: 1.95,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Write what happened, how you felt, and what you want to remember…',
                  hintStyle: TextStyle(
                    color: secondaryTextColor,
                    height: 1.5,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiaryTextField extends StatelessWidget {
  const _DiaryTextField({
    required this.controller,
    required this.hintText,
    this.prefixText,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final String? prefixText;
  final int minLines;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      cursorColor: colorScheme.primary,
      style: TextStyle(color: neutral.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: neutral.textSecondary),
        prefixText: prefixText,
        prefixStyle: TextStyle(
          color: neutral.textSecondary,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: neutral.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: neutral.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;

    return Material(
      color: neutral.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: neutral.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final exists = File(path).existsSync();
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 112,
            height: 112,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: exists
                ? Image.file(File(path), fit: BoxFit.cover)
                : const Icon(Icons.broken_image_rounded),
          ),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: IconButton.filled(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    );
  }
}

class _DrawingPreview extends StatelessWidget {
  const _DrawingPreview({
    required this.path,
    required this.onEdit,
    required this.onRemove,
  });

  final String path;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 96,
              height: 72,
              child: File(path).existsSync()
                  ? Image.file(File(path), fit: BoxFit.cover)
                  : const ColoredBox(
                      color: Color(0xFFF3F4F6),
                      child: Icon(Icons.draw_rounded),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Drawing attached',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded)),
          IconButton(
              onPressed: onRemove, icon: const Icon(Icons.delete_rounded)),
        ],
      ),
    );
  }
}

class _RuledPaperPainter extends CustomPainter {
  const _RuledPaperPainter({
    required this.lineColor,
    required this.marginColor,
  });

  final Color lineColor;
  final Color marginColor;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (double y = 95; y < size.height; y += 33) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final marginPaint = Paint()
      ..color = marginColor
      ..strokeWidth = 1.3;
    canvas.drawLine(
      const Offset(22, 0),
      Offset(22, size.height),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RuledPaperPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.marginColor != marginColor;
  }
}
