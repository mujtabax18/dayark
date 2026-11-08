import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;

import 'package:metersystem/core/theme/theme_x.dart';
import 'package:metersystem/services/diary_media_service.dart';

class DrawingBoardScreen extends StatefulWidget {
  const DrawingBoardScreen({
    super.key,
    this.existingDrawingPath,
  });

  final String? existingDrawingPath;

  @override
  State<DrawingBoardScreen> createState() => _DrawingBoardScreenState();
}

class _DrawingBoardScreenState extends State<DrawingBoardScreen> {
  final _boundaryKey = GlobalKey();
  final List<_DrawingStroke> _strokes = [];
  final List<_DrawingStroke> _redoStack = [];

  Color _selectedColor = const Color(0xFF2B2B2B);
  double _strokeWidth = 4;
  bool _saving = false;

  static const _colors = <Color>[
    Color(0xFF2B2B2B),
    Color(0xFF6C63FF),
    Color(0xFF0E7490),
    Color(0xFF15803D),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFFBE185D),
    Color(0xFFFFFFFF),
  ];

  void _startStroke(DragStartDetails details) {
    setState(() {
      _redoStack.clear();
      _strokes.add(
        _DrawingStroke(
          points: [details.localPosition],
          color: _selectedColor,
          width: _strokeWidth,
        ),
      );
    });
  }

  void _appendStroke(DragUpdateDetails details) {
    if (_strokes.isEmpty) return;
    setState(() {
      _strokes.last.points.add(details.localPosition);
    });
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _redoStack.add(_strokes.removeLast()));
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() => _strokes.add(_redoStack.removeLast()));
  }

  Future<void> _clear() async {
    if (_strokes.isEmpty) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear drawing?'),
        content: const Text('All strokes on this page will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (approved == true && mounted) {
      setState(() {
        _strokes.clear();
        _redoStack.clear();
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Drawing canvas is not ready.');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Could not encode drawing.');

      final directory = await DiaryMediaService.drawingDirectory();
      final file = File(
        p.join(
          directory.path,
          'drawing_${DateTime.now().microsecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);

      if (!mounted) return;
      Navigator.pop(context, file.path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save drawing: $error')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        title: const Text('Drawing board'),
        backgroundColor: neutral.background,
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: _strokes.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: _redoStack.isEmpty ? null : _redo,
            icon: const Icon(Icons.redo_rounded),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: _strokes.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Color(0xFFFFFDF7)),
                      if (widget.existingDrawingPath != null &&
                          File(widget.existingDrawingPath!).existsSync())
                        Image.file(
                          File(widget.existingDrawingPath!),
                          fit: BoxFit.contain,
                        ),
                      CustomPaint(
                        painter: _NotebookPainter(),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: _startStroke,
                        onPanUpdate: _appendStroke,
                        child: CustomPaint(
                          painter: _DrawingPainter(strokes: _strokes),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: neutral.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: neutral.divider),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colors.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final color = _colors[index];
                        final selected = color == _selectedColor;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : neutral.divider,
                                width: selected ? 3 : 1,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: .25),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: selected
                                ? Icon(
                                    Icons.check_rounded,
                                    color: color.computeLuminance() > .55
                                        ? Colors.black
                                        : Colors.white,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.line_weight_rounded),
                      Expanded(
                        child: Slider(
                          value: _strokeWidth,
                          min: 2,
                          max: 18,
                          divisions: 8,
                          label: _strokeWidth.round().toString(),
                          onChanged: (value) {
                            setState(() => _strokeWidth = value);
                          },
                        ),
                      ),
                      Container(
                        width: _strokeWidth + 8,
                        height: _strokeWidth + 8,
                        decoration: BoxDecoration(
                          color: _selectedColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: neutral.divider),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save drawing'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawingStroke {
  _DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
  });

  final List<Offset> points;
  final Color color;
  final double width;
}

class _DrawingPainter extends CustomPainter {
  const _DrawingPainter({required this.strokes});

  final List<_DrawingStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, stroke.width / 2, paint);
        continue;
      }

      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var index = 1; index < stroke.points.length; index++) {
        final previous = stroke.points[index - 1];
        final current = stroke.points[index];
        final midpoint = Offset(
          (previous.dx + current.dx) / 2,
          (previous.dy + current.dy) / 2,
        );
        path.quadraticBezierTo(
          previous.dx,
          previous.dy,
          midpoint.dx,
          midpoint.dy,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}

class _NotebookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFD7E2F0)
      ..strokeWidth = 1;
    for (double y = 48; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final marginPaint = Paint()
      ..color = const Color(0xFFF2B5B5)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      const Offset(48, 0),
      Offset(48, size.height),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
