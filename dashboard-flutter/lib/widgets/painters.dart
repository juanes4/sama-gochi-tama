import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Limita [v] al rango [lo, hi] devolviendo siempre un double.
double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

TextPainter _text(String text, TextStyle style) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
}

/// Curva suave (Catmull-Rom convertida a Bézier) que pasa por todos los puntos.
Path smoothPath(List<Offset> pts) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 0; i < pts.length - 1; i++) {
    final p0 = i == 0 ? pts[i] : pts[i - 1];
    final p1 = pts[i];
    final p2 = pts[i + 1];
    final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
    final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
    final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path;
}

void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint,
    {double dash = 5, double gap = 4}) {
  final total = (b - a).distance;
  if (total == 0) return;
  final dir = (b - a) / total;
  var d = 0.0;
  while (d < total) {
    canvas.drawLine(a + dir * d, a + dir * math.min(d + dash, total), paint);
    d += dash + gap;
  }
}

/// Fondo tipo mapa (cuadrícula, calles y manzanas rosadas) del panel principal.
class MapBackdropPainter extends CustomPainter {
  const MapBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);

    final block = Paint()..color = const Color(0xFFFBE4E1);
    for (var i = 0; i < 6; i++) {
      final w = 70 + rnd.nextDouble() * 130;
      final h = 34 + rnd.nextDouble() * 80;
      final rect = Rect.fromLTWH(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
        w,
        h,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), block);
    }

    final grid = Paint()
      ..color = const Color(0xFFF0EEEA)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 56) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 56) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final street = Paint()
      ..color = const Color(0xFFE6E3DE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < 22; i++) {
      final path = Path()
        ..moveTo(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      for (var j = 0; j < 3; j++) {
        path.lineTo(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      }
      canvas.drawPath(path, street);
    }
  }

  @override
  bool shouldRepaint(covariant MapBackdropPainter oldDelegate) => false;
}

/// Línea en vivo con área degradada, mínimo/máximo y un punto pulsante al final.
class LiveChartPainter extends CustomPainter {
  LiveChartPainter({
    required this.values,
    required this.minSpan,
    required this.unit,
    required this.textStyle,
    required Animation<double> pulse,
    this.hardMin,
    this.hardMax,
  })  : _pulse = pulse,
        super(repaint: pulse);

  final List<double> values;
  final double minSpan;
  final String unit;
  final TextStyle textStyle;
  final double? hardMin;
  final double? hardMax;
  final Animation<double> _pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      final tp = _text(
        'Esperando datos del broker…',
        textStyle.copyWith(color: C.muted, fontSize: 13, fontWeight: FontWeight.w600),
      );
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }

    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    if (hi - lo < minSpan) {
      final mid = (hi + lo) / 2;
      lo = mid - minSpan / 2;
      hi = mid + minSpan / 2;
    }
    final pad = (hi - lo) * 0.2;
    lo -= pad;
    hi += pad;
    if (hardMin != null) lo = math.max(lo, hardMin!);
    if (hardMax != null) hi = math.min(hi, hardMax!);
    if (hi - lo < 1e-6) hi = lo + 1;

    const topPad = 30.0;
    const bottomPad = 26.0;
    final n = values.length;
    Offset pt(int i) {
      final x = n == 1 ? size.width / 2 : size.width * i / (n - 1);
      final norm = clampD((values[i] - lo) / (hi - lo), 0.0, 1.0);
      final y = topPad + (1 - norm) * (size.height - topPad - bottomPad);
      return Offset(x, y);
    }

    final pts = [for (var i = 0; i < n; i++) pt(i)];

    if (n > 1) {
      final line = smoothPath(pts);
      final area = Path.from(line)
        ..lineTo(pts.last.dx, size.height)
        ..lineTo(pts.first.dx, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [C.accent.withValues(alpha: 0.2), C.accent.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = C.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Mínimo y máximo
    var iMin = 0;
    var iMax = 0;
    for (var i = 1; i < n; i++) {
      if (values[i] < values[iMin]) iMin = i;
      if (values[i] > values[iMax]) iMax = i;
    }
    if (iMin != iMax) {
      if (iMin != n - 1) _extreme(canvas, size, pts[iMin], values[iMin], below: true);
      if (iMax != n - 1) _extreme(canvas, size, pts[iMax], values[iMax], below: false);
    }

    // Punto actual con halo pulsante
    final last = pts.last;
    final t = _pulse.value;
    canvas.drawCircle(
      last,
      11 + 12 * t,
      Paint()..color = C.accent.withValues(alpha: 0.28 * (1 - t)),
    );
    canvas.drawCircle(last, 9, Paint()..color = C.accent);
    canvas.drawCircle(last, 3.5, Paint()..color = Colors.white);

    // Etiqueta con el valor actual
    final label = _text(
      '${values.last.toStringAsFixed(1)}$unit',
      textStyle.copyWith(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
    );
    final w = label.width + 16;
    final x = clampD(last.dx - w / 2, 0.0, math.max(0.0, size.width - w));
    final tag = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, math.max(0, last.dy - 40), w, 22),
      const Radius.circular(11),
    );
    canvas.drawRRect(tag, Paint()..color = C.ink);
    label.paint(canvas, Offset(tag.left + 8, tag.top + (22 - label.height) / 2));
  }

  void _extreme(Canvas canvas, Size size, Offset p, double v, {required bool below}) {
    canvas.drawCircle(p, 5.5, Paint()..color = Colors.white);
    canvas.drawCircle(
      p,
      5.5,
      Paint()
        ..color = C.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final tp = _text(
      '${v.toStringAsFixed(1)}$unit',
      textStyle.copyWith(color: C.ink, fontSize: 11, fontWeight: FontWeight.w700),
    );
    final x = clampD(p.dx - tp.width / 2, 0.0, math.max(0.0, size.width - tp.width));
    final y = below ? p.dy + 9 : p.dy - 9 - tp.height;
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant LiveChartPainter oldDelegate) => true;
}

/// Gráfico de "piruletas": un palo por lectura y una línea punteada con el promedio.
class LollipopPainter extends CustomPainter {
  const LollipopPainter({
    required this.values,
    required this.labels,
    required this.minSpan,
    required this.textStyle,
  });

  final List<double> values;
  final List<String> labels;
  final double minSpan;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      final tp = _text(
        'Sin lecturas todavía',
        textStyle.copyWith(color: C.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
      );
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }

    const labelH = 18.0;
    final plotH = size.height - labelH;
    final n = values.length;
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final span = math.max(hi - lo, minSpan);
    final base = lo - span * 0.7;
    final top = hi + span * 0.35;
    double yOf(double v) => plotH - (v - base) / (top - base) * plotH;
    double xOf(int i) => n == 1 ? size.width / 2 : 24 + (size.width - 48) * i / (n - 1);

    final avg = values.reduce((a, b) => a + b) / n;
    final avgY = yOf(avg);
    _dashedLine(
      canvas,
      Offset(0, avgY),
      Offset(size.width, avgY),
      Paint()
        ..color = C.accent
        ..strokeWidth = 1.2,
    );

    final stem = Paint()
      ..color = const Color(0xFFD3D0CB)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = const Color(0xFF9D9A95);
    for (var i = 0; i < n - 1; i++) {
      final p = Offset(xOf(i), yOf(values[i]));
      canvas.drawLine(Offset(p.dx, plotH), p, stem);
      canvas.drawCircle(p, 3, dot);
    }

    // Última lectura resaltada
    final lp = Offset(xOf(n - 1), yOf(values.last));
    canvas.drawLine(
      Offset(lp.dx, plotH),
      lp,
      Paint()
        ..color = C.accent
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(lp, 6, Paint()..color = C.accent);
    canvas.drawCircle(lp, 2.4, Paint()..color = Colors.white);
    final valueTag = _text(
      values.last.toStringAsFixed(1),
      textStyle.copyWith(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
    );
    final tw = valueTag.width + 14;
    final tx = clampD(lp.dx - tw / 2, 0.0, math.max(0.0, size.width - tw));
    final tagRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tx, math.max(0, lp.dy - 28), tw, 20),
      const Radius.circular(10),
    );
    canvas.drawRRect(tagRect, Paint()..color = C.accent);
    valueTag.paint(canvas, Offset(tagRect.left + 7, tagRect.top + (20 - valueTag.height) / 2));

    // Etiqueta del promedio
    final avgTag = _text(
      'Prom. ${avg.toStringAsFixed(1)}',
      textStyle.copyWith(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
    );
    final aw = avgTag.width + 12;
    final aRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, avgY - 18, aw, 18),
      const Radius.circular(6),
    );
    canvas.drawRRect(aRect, Paint()..color = C.accent);
    avgTag.paint(canvas, Offset(6, avgY - 18 + (18 - avgTag.height) / 2));

    // Etiquetas del eje X
    final step = math.max(1, (n / 5).ceil());
    for (var i = 0; i < n; i += step) {
      if (i >= labels.length) break;
      final tp = _text(
        labels[i],
        textStyle.copyWith(color: C.muted, fontSize: 10, fontWeight: FontWeight.w600),
      );
      final x = clampD(xOf(i) - tp.width / 2, 0.0, math.max(0.0, size.width - tp.width));
      tp.paint(canvas, Offset(x, size.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant LollipopPainter oldDelegate) => true;
}

/// Puntitos de fondo para la tarjeta roja.
class DotGridPainter extends CustomPainter {
  const DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.22);
    for (var y = 12.0; y < size.height; y += 14) {
      for (var x = 12.0; x < size.width; x += 14) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter oldDelegate) => false;
}

/// Curva blanca con la velocidad del ventilador (0..100 %) en las últimas lecturas.
class FanWavePainter extends CustomPainter {
  const FanWavePainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    double yOf(double v) => size.height - 8 - clampD(v / 100, 0.0, 1.0) * (size.height - 16);

    final List<Offset> pts;
    if (values.isEmpty) {
      pts = [Offset(0, yOf(0)), Offset(size.width, yOf(0))];
    } else if (values.length == 1) {
      pts = [Offset(0, yOf(values.first)), Offset(size.width, yOf(values.first))];
    } else {
      pts = [
        for (var i = 0; i < values.length; i++)
          Offset(size.width * i / (values.length - 1), yOf(values[i])),
      ];
    }

    final line = smoothPath(pts);
    final area = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = Colors.white.withValues(alpha: 0.16));
    canvas.drawPath(
      line,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(pts.last, 6, Paint()..color = Colors.white);
    canvas.drawCircle(pts.last, 2.6, Paint()..color = C.accent);
  }

  @override
  bool shouldRepaint(covariant FanWavePainter oldDelegate) => true;
}

/// Anillo de progreso (riego en curso).
class RingPainter extends CustomPainter {
  const RingPainter({required this.progress, required this.color, this.stroke = 8});

  final double progress;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = C.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * clampD(progress, 0.0, 1.0),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Dibujo del toldo: un panel con rayas rojas que gira desde 0° (cerrado) hasta 90° (abierto).
class AwningPainter extends CustomPainter {
  const AwningPainter({required this.angle, required this.open});

  final double angle;
  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ground = h - 6;
    final hinge = Offset(w * 0.22, h * 0.58);
    final rightTop = Offset(w * 0.84, h * 0.58);

    canvas.drawLine(
      Offset(0, ground),
      Offset(w, ground),
      Paint()
        ..color = C.line
        ..strokeWidth = 2,
    );

    final post = Paint()
      ..color = const Color(0xFFB9B6B0)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(hinge.dx, ground), hinge, post);
    canvas.drawLine(Offset(rightTop.dx, ground), rightTop, post);
    canvas.drawLine(
      hinge,
      rightTop,
      Paint()
        ..color = const Color(0xFFD3D0CB)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Sol
    canvas.drawCircle(
      Offset(w * 0.9, h * 0.14),
      7,
      Paint()..color = open ? const Color(0xFFFFB020) : const Color(0xFFE2DFDA),
    );

    // Panel articulado
    final len = math.min(w * 0.62, hinge.dy - 8);
    canvas.save();
    canvas.translate(hinge.dx, hinge.dy);
    canvas.rotate(-angle * math.pi / 180);
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, -9, len, 9),
      const Radius.circular(4),
    );
    canvas.drawRRect(panel, Paint()..color = C.accent);
    canvas.save();
    canvas.clipRRect(panel);
    final hatch = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 2;
    for (var x = -9.0; x < len + 9; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x + 9, -9), hatch);
    }
    canvas.restore();
    canvas.restore();
    canvas.drawCircle(hinge, 3.5, Paint()..color = C.ink);
  }

  @override
  bool shouldRepaint(covariant AwningPainter oldDelegate) =>
      oldDelegate.angle != angle || oldDelegate.open != open;
}

/// Borde punteado redondeado para la tarjeta "Configurar broker".
class DashedRRectPainter extends CustomPainter {
  const DashedRRectPainter({required this.color, this.radius = 22});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 6, metric.length)), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRRectPainter oldDelegate) => oldDelegate.color != color;
}
