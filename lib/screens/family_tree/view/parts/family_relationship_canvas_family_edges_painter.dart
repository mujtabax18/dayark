part of '../family_relationship_canvas.dart';

class _FamilyEdgesPainter extends CustomPainter {
  const _FamilyEdgesPainter({
    required this.centers,
    required this.relationships,
    required this.background,
    required this.depthMode,
  });

  final Map<int, Offset> centers;
  final List<FamilyRelationship> relationships;
  final Color background;
  final bool depthMode;

  @override
  void paint(Canvas canvas, Size size) {
    // Avoid painting thousands of decorative dots across the entire (often
    // much larger than the viewport) family graph on every zoom/pan frame.
    for (final link in relationships) {
      final source = centers[link.fromMemberId];
      final destination = centers[link.toMemberId];
      if (source == null || destination == null) continue;
      var vector = destination - source;
      if (vector.distance < 1) continue;
      final horizontal = vector.dx.abs() > vector.dy.abs();
      final fromInset = horizontal ? 78.0 : 52.0;
      final toInset = horizontal ? 78.0 : 52.0;
      final unit = vector / vector.distance;
      final start = source + unit * fromInset;
      final end = destination - unit * toInset;
      final paint = Paint()
        ..color = _RelationColors.of(link.type)
        ..strokeWidth = 3.3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      final path = Path()..moveTo(start.dx, start.dy);
      if (horizontal) {
        path.cubicTo(mid.dx, start.dy, mid.dx, end.dy, end.dx, end.dy);
      } else {
        path.cubicTo(start.dx, mid.dy, end.dx, mid.dy, end.dx, end.dy);
      }
      if (depthMode) {
        // A slightly offset shadow adds visual depth without changing the
        // node hit areas or requiring a separate rendering engine.
        canvas.drawPath(path.shift(const Offset(4, 5)), Paint()
          ..color = paint.color.withValues(alpha: .22)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);
      }
      canvas.drawPath(path, paint);
      final tangentAtEnd = horizontal
          ? Offset(end.dx - mid.dx, 0)
          : Offset(0, end.dy - mid.dy);
      _arrow(canvas, end, tangentAtEnd.distance > 0.1 ? tangentAtEnd : unit,
        paint.color);
      if (link.type != 'parent' && link.type != 'guardian') {
        final tangentAtStart = horizontal
            ? Offset(start.dx - mid.dx, 0)
            : Offset(0, start.dy - mid.dy);
        _arrow(canvas, start,
          tangentAtStart.distance > 0.1 ? tangentAtStart : -unit, paint.color);
      }
    }
  }

  void _arrow(Canvas canvas, Offset tip, Offset direction, Color color) {
    if (direction.distance < .01) return;
    final unit = direction / direction.distance;
    final normal = Offset(-unit.dy, unit.dx);
    final arrowPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - unit.dx * 12 + normal.dx * 5,
          tip.dy - unit.dy * 12 + normal.dy * 5)
      ..lineTo(tip.dx - unit.dx * 12 - normal.dx * 5,
          tip.dy - unit.dy * 12 - normal.dy * 5)
      ..close();
    canvas.drawPath(arrowPath, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _FamilyEdgesPainter oldDelegate) =>
      !identical(centers, oldDelegate.centers) ||
      !identical(relationships, oldDelegate.relationships) ||
      background != oldDelegate.background ||
      depthMode != oldDelegate.depthMode;
}
