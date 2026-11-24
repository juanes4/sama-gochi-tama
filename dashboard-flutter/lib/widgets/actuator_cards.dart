import 'package:flutter/material.dart';

import '../dashboard_controller.dart';
import '../models.dart';
import '../theme.dart';
import 'common.dart';
import 'painters.dart';

const _estimadoTip =
    'Los actuadores no publican su estado: se calcula con la misma lógica del firmware.';

/// Bomba de riego: 3 s cada 13 s mientras la humedad esté por debajo del 50 %.
class PumpCard extends StatelessWidget {
  const PumpCard({super.key, required this.c});

  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    final hasData = c.last != null;
    final next = c.nextWateringIn;
    final (label, color) = !hasData
        ? ('Sin datos', C.muted)
        : c.pumpOn
            ? ('Regando', C.accent)
            : ('En espera', C.ok);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            'Bomba de riego',
            trailing: const Tooltip(
              message: _estimadoTip,
              child: Icon(Icons.info_outline_rounded, size: 16, color: C.muted),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: c.wateringProgress),
                  duration: const Duration(milliseconds: 450),
                  builder: (context, value, _) => CustomPaint(
                    painter: RingPainter(progress: value, color: C.accent),
                    child: Center(
                      child: Icon(
                        Icons.water_drop_rounded,
                        size: 26,
                        color: c.pumpOn ? C.accent : C.muted,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusChip(label, color),
                    const SizedBox(height: 6),
                    Text(
                      'Riegos: ${c.wateringCount}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      next != null
                          ? 'Próximo en ${next.inSeconds + 1} s'
                          : hasData && c.last!.humedad >= Rules.humedadRiego
                              ? 'Humedad OK'
                              : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: C.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'Humedad < ${Rules.humedadRiego.toInt()} % → riega '
            '${Rules.duracionRiego.inSeconds} s cada ${Rules.cicloRiego.inSeconds} s.',
            style: const TextStyle(fontSize: 11, color: C.muted, height: 1.3),
          ),
        ],
      ),
    );
  }
}

/// Toldo: servo a 90° (abierto) cuando la luz supera el 60 %.
class AwningCard extends StatelessWidget {
  const AwningCard({super.key, required this.c});

  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    final hasData = c.last != null;
    final open = c.awningAngle == Rules.toldoAbierto;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            'Toldo',
            trailing: hasData
                ? StatusChip(open ? 'Abierto' : 'Cerrado', open ? C.warn : C.ok)
                : const StatusChip('Sin datos', C.muted),
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: c.awningAngle.toDouble()),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOut,
              builder: (context, angle, _) {
                final pct = angle / Rules.toldoAbierto * 100;
                return Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: AwningPainter(angle: angle, open: open),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${pct.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                        ),
                        const Text(
                          'Apertura',
                          style: TextStyle(fontSize: 12, color: C.muted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Servo ${c.awningAngle}°',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Abre si luz > ${Rules.luzToldo.toInt()} %',
                          style: const TextStyle(fontSize: 11, color: C.muted),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Ventilador (motor a pasos): velocidad proporcional entre 25 °C y 75 °C.
class FanCard extends StatelessWidget {
  const FanCard({super.key, required this.c});

  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    final recent =
        c.history.length > 40 ? c.history.sublist(c.history.length - 40) : c.history;
    final series = [
      for (final s in recent) Rules.pasosVentilador(s.temperatura) * 100 / Rules.velocidadMaxima,
    ];
    final temp = c.last?.temperatura;

    return AppCard(
      color: C.accent,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: DotGridPainter())),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ventilador',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: _estimadoTip,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.air_rounded, size: 17, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: c.fanPercent.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(
                        text: ' %',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  style: const TextStyle(color: Colors.white, height: 1.1),
                ),
                Expanded(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: FanWavePainter(values: series),
                  ),
                ),
                Text(
                  'Gira entre ${Rules.tempVentMin} °C y ${Rules.tempVentMax} °C'
                  '${temp == null ? '' : ' · ahora ${temp.toStringAsFixed(1)} °C'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
