import 'package:flutter/material.dart';

import '../dashboard_controller.dart';
import '../models.dart';
import '../theme.dart';
import 'common.dart';
import 'painters.dart' show clampD;

/// Tarjeta con las tres lecturas del ESP32 de sensores (S1, S2, S3).
class SensorsCard extends StatelessWidget {
  const SensorsCard({super.key, required this.c});

  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    final s = c.last;

    final (statusText, statusColor) = switch ((c.link, s, c.stale)) {
      (LinkState.connected, null, _) => ('Esperando datos', C.warn),
      (LinkState.connected, _, true) => ('Sin datos recientes', C.warn),
      (LinkState.connected, _, false) => ('En línea', C.ok),
      (LinkState.connecting || LinkState.reconnecting, _, _) => ('Conectando…', C.warn),
      _ => ('Sin conexión', C.muted),
    };

    final humedadLow = s != null && s.humedad < Rules.humedadRiego;
    final fanOn = s != null && Rules.pasosVentilador(s.temperatura) > 0;
    final luzHigh = s != null && s.luz > Rules.luzToldo;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            'Sensores',
            trailing: Text(
              s == null ? '—' : 'Última lectura ${hms(s.time)}',
              style: const TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: C.accentSoft, shape: BoxShape.circle),
                child: const Icon(Icons.memory_rounded, size: 17, color: C.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESP32 · sensores',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      c.settings.topic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: C.muted),
                    ),
                  ],
                ),
              ),
              StatusChip(statusText, statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: C.line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Cell(
                      title: 'Humedad · S1',
                      value: s?.humedad,
                      unit: '%',
                      fraction: (s?.humedad ?? 0) / 100,
                      chip: s == null
                          ? const StatusChip('Sin datos', C.muted)
                          : humedadLow
                              ? const StatusChip('Baja · riega', C.accent)
                              : const StatusChip('Normal', C.ok),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: C.line),
                  Expanded(
                    child: _Cell(
                      title: 'Temperatura · S2',
                      value: s?.temperatura,
                      unit: '°C',
                      fraction: (s?.temperatura ?? 0) / 50,
                      chip: s == null
                          ? const StatusChip('Sin datos', C.muted)
                          : fanOn
                              ? StatusChip(
                                  'Ventilando ${c.fanPercent.toStringAsFixed(0)}%',
                                  C.warn,
                                )
                              : const StatusChip('Normal', C.ok),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: C.line),
                  Expanded(
                    child: _Cell(
                      title: 'Luz · S3',
                      value: s?.luz,
                      unit: '%',
                      fraction: (s?.luz ?? 0) / 100,
                      chip: s == null
                          ? const StatusChip('Sin datos', C.muted)
                          : luzHigh
                              ? const StatusChip('Alta · toldo abierto', C.warn)
                              : const StatusChip('Normal', C.ok),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.title,
    required this.value,
    required this.unit,
    required this.fraction,
    required this.chip,
  });

  final String title;
  final double? value;
  final String unit;
  final double fraction;
  final Widget chip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: C.muted),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value == null ? '--' : value!.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.muted),
                ),
              ],
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: clampD(fraction, 0.0, 1.0),
              minHeight: 5,
              backgroundColor: C.line,
              color: C.accent,
            ),
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: chip),
        ],
      ),
    );
  }
}
