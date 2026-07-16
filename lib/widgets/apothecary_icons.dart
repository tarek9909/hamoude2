import 'package:flutter/material.dart';

/// A custom, high-fidelity line icon representing a premium apothecary shopping bag
/// with a minimalist leaf motif in the center.
class ApothecaryBagIcon extends StatelessWidget {
  final Color? color;
  final double size;

  const ApothecaryBagIcon({
    super.key,
    this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size(size, size),
      painter: _ApothecaryBagPainter(color: themeColor),
    );
  }
}

class _ApothecaryBagPainter extends CustomPainter {
  final Color color;

  _ApothecaryBagPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Draw thin elegant bag handle
    final handlePath = Path();
    handlePath.addArc(
      Rect.fromLTWH(w * 0.34, h * 0.12, w * 0.32, h * 0.32),
      -3.14159,
      3.14159,
    );
    canvas.drawPath(handlePath, paint);

    // Draw bag body with clean angles
    final bodyPath = Path()
      ..moveTo(w * 0.22, h * 0.32)
      ..lineTo(w * 0.78, h * 0.32)
      ..lineTo(w * 0.83, h * 0.86)
      ..lineTo(w * 0.17, h * 0.86)
      ..close();
    canvas.drawPath(bodyPath, paint);

    // Draw delicate leaf motif inside the bag
    final leafPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final leafPath = Path();
    // Left side of the leaf
    leafPath.moveTo(w * 0.5, h * 0.46);
    leafPath.quadraticBezierTo(w * 0.38, h * 0.52, w * 0.44, h * 0.68);
    // Right side of the leaf
    leafPath.quadraticBezierTo(w * 0.62, h * 0.64, w * 0.5, h * 0.46);
    // Stem/center vein
    leafPath.moveTo(w * 0.5, h * 0.46);
    leafPath.lineTo(w * 0.47, h * 0.74);

    canvas.drawPath(leafPath, leafPaint);
  }

  @override
  bool shouldRepaint(covariant _ApothecaryBagPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A premium, minimalist thin-line trash icon for clean checkout item removal.
class ApothecaryTrashIcon extends StatelessWidget {
  final Color? color;
  final double size;

  const ApothecaryTrashIcon({
    super.key,
    this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Theme.of(context).colorScheme.secondary;
    return CustomPaint(
      size: Size(size, size),
      painter: _ApothecaryTrashPainter(color: themeColor),
    );
  }
}

class _ApothecaryTrashPainter extends CustomPainter {
  final Color color;

  _ApothecaryTrashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Draw lid bar
    canvas.drawLine(
        Offset(w * 0.18, h * 0.28), Offset(w * 0.82, h * 0.28), paint);

    // Draw lid top handle
    final handle = Path()
      ..moveTo(w * 0.38, h * 0.28)
      ..lineTo(w * 0.38, h * 0.16)
      ..lineTo(w * 0.62, h * 0.16)
      ..lineTo(w * 0.62, h * 0.28);
    canvas.drawPath(handle, paint);

    // Draw main bin body
    final body = Path()
      ..moveTo(w * 0.24, h * 0.28)
      ..lineTo(w * 0.29, h * 0.82)
      ..quadraticBezierTo(w * 0.30, h * 0.87, w * 0.36, h * 0.87)
      ..lineTo(w * 0.64, h * 0.87)
      ..quadraticBezierTo(w * 0.70, h * 0.87, w * 0.71, h * 0.82)
      ..lineTo(w * 0.76, h * 0.28);
    canvas.drawPath(body, paint);

    // Draw elegant vertical slot detail lines
    canvas.drawLine(
        Offset(w * 0.42, h * 0.40), Offset(w * 0.44, h * 0.72), paint);
    canvas.drawLine(
        Offset(w * 0.58, h * 0.40), Offset(w * 0.56, h * 0.72), paint);
  }

  @override
  bool shouldRepaint(covariant _ApothecaryTrashPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A ultra-thin, premium minus icon.
class ApothecaryMinusIcon extends StatelessWidget {
  final Color? color;
  final double size;

  const ApothecaryMinusIcon({
    super.key,
    this.color,
    this.size = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size(size, size),
      painter: _ApothecaryMinusPainter(color: themeColor),
    );
  }
}

class _ApothecaryMinusPainter extends CustomPainter {
  final Color color;

  _ApothecaryMinusPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.5),
      Offset(size.width * 0.9, size.height * 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ApothecaryMinusPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A ultra-thin, premium plus icon.
class ApothecaryPlusIcon extends StatelessWidget {
  final Color? color;
  final double size;

  const ApothecaryPlusIcon({
    super.key,
    this.color,
    this.size = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size(size, size),
      painter: _ApothecaryPlusPainter(color: themeColor),
    );
  }
}

class _ApothecaryPlusPainter extends CustomPainter {
  final Color color;

  _ApothecaryPlusPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    final halfW = size.width * 0.4;
    final halfH = size.height * 0.4;

    canvas.drawLine(Offset(cx - halfW, cy), Offset(cx + halfW, cy), paint);
    canvas.drawLine(Offset(cx, cy - halfH), Offset(cx, cy + halfH), paint);
  }

  @override
  bool shouldRepaint(covariant _ApothecaryPlusPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A custom, high-fidelity line icon representing a shipping/delivery box.
class ApothecaryBoxIcon extends StatelessWidget {
  final Color? color;
  final double size;

  const ApothecaryBoxIcon({
    super.key,
    this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size(size, size),
      painter: _ApothecaryBoxPainter(color: themeColor),
    );
  }
}

class _ApothecaryBoxPainter extends CustomPainter {
  final Color color;

  _ApothecaryBoxPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // 3D Isometric box outlines
    final cx = w * 0.5;

    // Top face
    final topFace = Path()
      ..moveTo(cx, h * 0.16) // Top vertex
      ..lineTo(w * 0.82, h * 0.32) // Right vertex
      ..lineTo(cx, h * 0.48) // Bottom vertex
      ..lineTo(w * 0.18, h * 0.32) // Left vertex
      ..close();
    canvas.drawPath(topFace, paint);

    // Front left face vertical edges
    canvas.drawLine(
        Offset(w * 0.18, h * 0.32), Offset(w * 0.18, h * 0.72), paint);
    canvas.drawLine(Offset(cx, h * 0.48), Offset(cx, h * 0.88), paint);
    canvas.drawLine(
        Offset(w * 0.82, h * 0.32), Offset(w * 0.82, h * 0.72), paint);

    // Bottom face boundaries
    final bottomEdges = Path()
      ..moveTo(w * 0.18, h * 0.72)
      ..lineTo(cx, h * 0.88)
      ..lineTo(w * 0.82, h * 0.72);
    canvas.drawPath(bottomEdges, paint);
  }

  @override
  bool shouldRepaint(covariant _ApothecaryBoxPainter oldDelegate) =>
      oldDelegate.color != color;
}
