import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

Future<BrokerSettings?> showSettingsDialog(BuildContext context, BrokerSettings current) {
  return showDialog<BrokerSettings>(
    context: context,
    builder: (_) => _SettingsDialog(current: current),
  );
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.current});

  final BrokerSettings current;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final _host = TextEditingController(text: widget.current.host);
  late final _port = TextEditingController(text: widget.current.port.toString());
  late final _topic = TextEditingController(text: widget.current.topic);
  late final _user = TextEditingController(text: widget.current.username);
  late final _pass = TextEditingController(text: widget.current.password);
  late final _name = TextEditingController(text: widget.current.displayName);
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_host, _port, _topic, _user, _pass, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final port = int.tryParse(_port.text.trim());
    if (_host.text.trim().isEmpty ||
        _topic.text.trim().isEmpty ||
        _user.text.trim().isEmpty ||
        port == null ||
        port < 1 ||
        port > 65535) {
      setState(() => _error = 'Completa host, puerto válido, tópico y usuario.');
      return;
    }
    Navigator.of(context).pop(
      BrokerSettings(
        host: _host.text.trim(),
        port: port,
        topic: _topic.text.trim(),
        username: _user.text.trim(),
        password: _pass.text,
        displayName: _name.text.trim().isEmpty ? 'Operador' : _name.text.trim(),
      ),
    );
  }

  InputDecoration _deco(String label, {Widget? suffix}) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: C.frame,
        isDense: true,
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Conexión al broker EMQX',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Crea en EMQX (Authentication) un usuario exclusivo para este dashboard '
                'y úsalo aquí, en vez de las credenciales de los ESP32. Se guarda solo '
                'en este equipo.',
                style: TextStyle(fontSize: 12.5, color: C.muted, height: 1.35),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(flex: 3, child: TextField(controller: _host, decoration: _deco('Host'))),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      decoration: _deco('Puerto TLS'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: _topic, decoration: _deco('Tópico de sensores')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: _user, decoration: _deco('Usuario'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _pass,
                      obscureText: _hide,
                      decoration: _deco(
                        'Contraseña',
                        suffix: IconButton(
                          icon: Icon(
                            _hide ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: _name, decoration: _deco('Tu nombre (saludo del panel)')),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: C.accent, fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar y conectar')),
      ],
    );
  }
}
