part of '../view/DiaryDetailScreen.dart';

class _DiaryPaperPage extends StatelessWidget {
  const _DiaryPaperPage({
    required this.entry,
    required this.onMediaTap,
  });

  final MoodEntry entry;
  final void Function(List<String> paths, int index) onMediaTap;

  @override
  Widget build(BuildContext context) {
    final accent = Color(entry.accentColorValue);
    final media = <String>[
      ...entry.imagePaths.where((path) => File(path).existsSync()),
      if (entry.drawingPath != null && File(entry.drawingPath!).existsSync())
        entry.drawingPath!,
    ];

    return Hero(
      tag: 'diary-card-${entry.id ?? entry.dateTime}',
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF7),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _PaperLinesPainter())),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 7, color: accent),
              ),
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(30, 24, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .11),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            entry.moodEmoji,
                            style: const TextStyle(fontSize: 36),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE').format(entry.entryDateTime),
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .7,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                DateFormat('d MMMM yyyy').format(entry.entryDateTime),
                                style: const TextStyle(
                                  color: Color(0xFF27272A),
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                DateFormat('h:mm a').format(entry.entryDateTime),
                                style: const TextStyle(color: Color(0xFF71717A)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      entry.effectiveTitle,
                      style: const TextStyle(
                        color: Color(0xFF27272A),
                        fontSize: 28,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (entry.trigger != null || entry.tags.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (entry.trigger != null)
                            _PaperTag(
                              icon: Icons.auto_awesome_rounded,
                              label: entry.trigger!,
                              accent: accent,
                            ),
                          ...entry.tags.map(
                            (tag) => _PaperTag(
                              icon: Icons.tag_rounded,
                              label: tag,
                              accent: accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if ((entry.notes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        entry.notes!.trim(),
                        style: const TextStyle(
                          color: Color(0xFF3F3F46),
                          fontSize: 17,
                          height: 1.92,
                        ),
                      ),
                    ],
                    if ((entry.gratitude ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: accent.withValues(alpha: .16)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.favorite_rounded, color: accent, size: 19),
                                const SizedBox(width: 7),
                                Text(
                                  'A moment to remember',
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entry.gratitude!.trim(),
                              style: const TextStyle(
                                color: Color(0xFF3F3F46),
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (media.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      Text(
                        'Memories',
                        style: TextStyle(
                          color: accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: media.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.15,
                        ),
                        itemBuilder: (context, index) {
                          return InkWell(
                            onTap: () => onMediaTap(media, index),
                            borderRadius: BorderRadius.circular(16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                File(media[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Icon(Icons.text_fields_rounded, color: accent, size: 17),
                        const SizedBox(width: 6),
                        Text(
                          '${entry.wordCount} words',
                          style: const TextStyle(
                            color: Color(0xFF71717A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (entry.reminderEnabled && entry.reminderDateTime != null) ...[
                          const SizedBox(width: 16),
                          Icon(
                            Icons.notifications_active_rounded,
                            color: accent,
                            size: 17,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              DateFormat('d MMM • h:mm a')
                                  .format(entry.reminderDateTime!),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF71717A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaperTag extends StatelessWidget {
  const _PaperTag({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryMediaViewer extends StatefulWidget {
  const _DiaryMediaViewer({required this.paths, required this.initialIndex});

  final List<String> paths;
  final int initialIndex;

  @override
  State<_DiaryMediaViewer> createState() => _DiaryMediaViewerState();
}

class _DiaryMediaViewerState extends State<_DiaryMediaViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.paths.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.paths.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: .8,
            maxScale: 5,
            child: Center(
              child: Image.file(
                File(widget.paths[index]),
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PaperLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDDE8F3)
      ..strokeWidth = .8;
    for (double y = 150; y < size.height; y += 33) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final margin = Paint()
      ..color = const Color(0xFFF2B8B8)
      ..strokeWidth = 1.1;
    canvas.drawLine(const Offset(23, 0), Offset(23, size.height), margin);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
