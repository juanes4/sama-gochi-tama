import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dashboard_controller.dart';
import '../models.dart';
import '../theme.dart';
import 'common.dart';
import 'painters.dart';

/// Últimas 12 lecturas de la variable elegida en gráfico de "piruletas".
class TrendCard extends StatelessWidget {
  const TrendCard({super.key, required this.c});

  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    final v = c.chartVar;
    final recent =
        c.history.length > 12 ? c.history.sublist(c.history.length - 12) : c.history;
    final textStyle = Theme.of(context).textTheme.bodySmall ?? const TextStyle();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            'Tendencia · ${v.label}',
            trailing: RoundIconBtn(
              icon: Icons.download_rounded,
              tooltip: 'Copiar historial como CSV',
              size: 30,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: c.toCsv()));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('CSV copiado (${c.history.length} lecturas)'),
                    behavior: SnackBarBehavior.floating,
                    width: 280,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: LollipopPainter(
                values: recent.map(v.of).toList(),
                labels: [
                  for (final s in recent) '${two(s.time.minute)}:${two(s.time.second)}',
                ],
                minSpan: v.minSpan / 2,
                textStyle: textStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
