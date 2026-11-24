import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dashboard_controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/actuator_cards.dart';
import '../widgets/common.dart';
import '../widgets/hero_card.dart';
import '../widgets/log_card.dart';
import '../widgets/sensors_card.dart';
import '../widgets/trend_card.dart';

/// Página principal: la composición de tarjetas inspirada en la imagen.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.c, required this.onOpenHistory});

  final DashboardController c;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 270, child: HeroCard(c: c, onOpenHistory: onOpenHistory)),
          const SizedBox(height: 16),
          AdaptiveRow(
            height: 240,
            items: [
              FlexItem(5, SensorsCard(c: c)),
              FlexItem(2, PumpCard(c: c)),
              FlexItem(3, AwningCard(c: c)),
            ],
          ),
          const SizedBox(height: 16),
          AdaptiveRow(
            height: 230,
            items: [
              FlexItem(4, TrendCard(c: c)),
              FlexItem(3, FanCard(c: c)),
              FlexItem(3, LogCard(c: c)),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Tabla con todas las lecturas recibidas (las más nuevas arriba).
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.c});

  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    final n = c.history.length;
    const head = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.muted);
    return AppCard(
      child: Column(
        children: [
          CardHeader(
            'Historial de lecturas',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$n lecturas', style: const TextStyle(fontSize: 12, color: C.muted)),
                const SizedBox(width: 10),
                RoundIconBtn(
                  icon: Icons.copy_all_rounded,
                  size: 30,
                  tooltip: 'Copiar como CSV',
                  onTap: () => Clipboard.setData(ClipboardData(text: c.toCsv())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: Text('HORA', style: head)),
              Expanded(child: Text('HUMEDAD · S1', style: head)),
              Expanded(child: Text('TEMPERATURA · S2', style: head)),
              Expanded(child: Text('LUZ · S3', style: head)),
            ],
          ),
          const Divider(height: 18, color: C.line),
          Expanded(
            child: n == 0
                ? const Center(
                    child: Text(
                      'Aún no hay lecturas. Llegan cada ~4 s cuando el sensor publica.',
                      style: TextStyle(color: C.muted),
                    ),
                  )
                : ListView.builder(
                    itemCount: n,
                    itemBuilder: (context, i) {
                      final s = c.history[n - 1 - i];
                      const cell = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: C.line)),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(hms(s.time), style: cell)),
                            Expanded(child: Text('${s.humedad.toStringAsFixed(1)} %', style: cell)),
                            Expanded(
                              child: Text('${s.temperatura.toStringAsFixed(1)} °C', style: cell),
                            ),
                            Expanded(child: Text('${s.luz.toStringAsFixed(1)} %', style: cell)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Lista completa de eventos: conexión, actuadores y mensajes rechazados.
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key, required this.c});

  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    final events = c.events;
    return AppCard(
      child: Column(
        children: [
          CardHeader(
            'Alertas y eventos',
            trailing: Text(
              '${events.length} eventos',
              style: const TextStyle(fontSize: 12, color: C.muted),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: events.isEmpty
                ? const Center(
                    child: Text('Sin eventos todavía', style: TextStyle(color: C.muted)),
                  )
                : ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, i) {
                      final e = events[i];
                      final color = switch (e.level) {
                        EventLevel.ok => C.ok,
                        EventLevel.info => C.muted,
                        EventLevel.warn => C.warn,
                        EventLevel.error => C.accent,
                      };
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: C.line)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 5, right: 12),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.title,
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                                  ),
                                  if (e.detail.isNotEmpty)
                                    Text(
                                      e.detail,
                                      style: const TextStyle(fontSize: 12, color: C.muted),
                                    ),
                                ],
                              ),
                            ),
                            Text(hms(e.time), style: const TextStyle(fontSize: 12, color: C.muted)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
