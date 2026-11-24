import 'package:flutter/material.dart';

import '../dashboard_controller.dart';
import '../models.dart';
import '../theme.dart';
import 'common.dart';
import 'painters.dart';

/// Panel principal (equivalente al mapa de la imagen): gráfico en vivo de la
/// variable elegida, KPIs a la izquierda y alertas recientes abajo a la derecha.
class HeroCard extends StatefulWidget {
  const HeroCard({super.key, required this.c, required this.onOpenHistory});

  final DashboardController c;
  final VoidCallback onOpenHistory;

  @override
  State<HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<HeroCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final v = c.chartVar;
    final series =
        c.history.length > 60 ? c.history.sublist(c.history.length - 60) : c.history;
    final values = series.map(v.of).toList();
    final textStyle = Theme.of(context).textTheme.bodySmall ?? const TextStyle();

    return AppCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 820;
          return Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: MapBackdropPainter())),
              Positioned(
                left: wide ? 250 : 20,
                right: wide ? 300 : 20,
                top: 56,
                bottom: 14,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: LiveChartPainter(
                    values: values,
                    minSpan: v.minSpan,
                    unit: v.unit,
                    textStyle: textStyle,
                    pulse: _pulse,
                    hardMin: v.hardMin,
                    hardMax: v.hardMax,
                  ),
                ),
              ),
              Positioned(
                left: 18,
                top: 16,
                right: 18,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final option in ChartVar.values)
                      Pill(
                        option.label,
                        selected: option == v,
                        onTap: () => c.selectVar(option),
                      ),
                  ],
                ),
              ),
              if (wide)
                Positioned(
                  left: 22,
                  top: 58,
                  width: 210,
                  bottom: 18,
                  child: _Kpis(c: c, values: values, onOpenHistory: widget.onOpenHistory),
                ),
              if (wide)
                Positioned(right: 16, bottom: 16, width: 272, child: _AlertsPanel(c: c)),
            ],
          );
        },
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.c, required this.values, required this.onOpenHistory});

  final DashboardController c;
  final List<double> values;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final v = c.chartVar;
    final s = c.last;
    final current = s == null ? null : v.of(s);
    final pct = c.thresholdPercent(v);
    final range = values.isEmpty
        ? 'sin lecturas'
        : 'mín ${values.reduce((a, b) => a < b ? a : b).toStringAsFixed(1)} · '
            'máx ${values.reduce((a, b) => a > b ? a : b).toStringAsFixed(1)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${v.label} actual',
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.muted),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: current == null ? '--' : current.toStringAsFixed(1),
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
              TextSpan(
                text: ' ${v.unit}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Text(range, style: const TextStyle(fontSize: 12, color: C.muted)),
        const Spacer(),
        Text(
          'Lecturas dentro del umbral · ${v.thresholdText}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: C.muted, height: 1.25),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 5,
                  backgroundColor: C.line,
                  color: C.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Pill('Limpiar', selected: true, onTap: c.clearHistory),
            const SizedBox(width: 8),
            Pill('Historial', onTap: onOpenHistory),
          ],
        ),
      ],
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({required this.c});

  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    final latest = c.events.take(2).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Alertas y notificaciones',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.muted),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(color: C.accent, shape: BoxShape.circle),
                child: const Icon(Icons.notifications_rounded, size: 13, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (latest.isEmpty)
            const Text('Sin alertas todavía', style: TextStyle(fontSize: 12, color: C.muted))
          else
            for (final e in latest)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                          ),
                          if (e.detail.isNotEmpty)
                            Text(
                              e.detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: C.muted),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(hms(e.time), style: const TextStyle(fontSize: 11, color: C.muted)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
