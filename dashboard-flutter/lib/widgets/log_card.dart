import 'package:flutter/material.dart';

import '../dashboard_controller.dart';
import '../models.dart';
import '../theme.dart';
import 'common.dart';

/// Registro MQTT con aspecto de chat (como la tarjeta "Chat" de la imagen).
/// El cuadro de abajo permite publicar una lectura de prueba en el tópico de sensores.
class LogCard extends StatefulWidget {
  const LogCard({super.key, required this.c});

  final DashboardController c;

  @override
  State<LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<LogCard> {
  final _input = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final err = widget.c.publishRaw(text);
    setState(() => _error = err);
    if (err == null) _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.c.log;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        children: [
          CardHeader(
            'Registro MQTT',
            trailing: Text(
              '${log.length} msg',
              style: const TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: log.isEmpty
                ? const Center(
                    child: Text(
                      'Aquí aparecerán los mensajes',
                      style: TextStyle(fontSize: 12, color: C.muted),
                    ),
                  )
                : ListView.builder(
                    reverse: true, // el más nuevo queda abajo, junto al cuadro de texto
                    padding: EdgeInsets.zero,
                    itemCount: log.length,
                    itemBuilder: (context, i) => _Line(entry: log[log.length - 1 - i]),
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: C.accent, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.only(left: 12, right: 4),
            height: 38,
            decoration: BoxDecoration(
              border: Border.all(color: C.line),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Probar: S1=40;S2=30;S3=70',
                      hintStyle: TextStyle(fontSize: 12, color: C.muted),
                    ),
                  ),
                ),
                RoundIconBtn(
                  icon: Icons.send_rounded,
                  tooltip: 'Publicar en ${widget.c.settings.topic}',
                  size: 30,
                  onTap: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    switch (entry.dir) {
      case LogDir.system:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            '${hms(entry.time)} · ${entry.text}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: C.muted),
          ),
        );
      case LogDir.incoming:
      case LogDir.outgoing:
        final mine = entry.dir == LogDir.outgoing;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: mine ? C.accent : C.frame,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.text,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: mine ? Colors.white : C.ink,
                      ),
                    ),
                    Text(
                      '${mine ? 'Enviado' : 'Recibido'} · ${hms(entry.time)}',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: mine ? Colors.white70 : C.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    }
  }
}
