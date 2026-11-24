import 'package:flutter/material.dart';

import 'dashboard_controller.dart';
import 'models.dart';
import 'pages/pages.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/settings_dialog.dart';
import 'widgets/sidebar.dart';

/// Marco redondeado de la app: barra lateral + contenido (como en la imagen).
class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, required this.c});

  final DashboardController c;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  AppPage _page = AppPage.dashboard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.c.settings.hasCredentials) {
        widget.c.connect();
      } else {
        _openSettings(); // primer arranque: pedir usuario y contraseña
      }
    });
  }

  Future<void> _openSettings() async {
    final result = await showSettingsDialog(context, widget.c.settings);
    if (result != null) await widget.c.applySettings(result);
  }

  String get _title => switch (_page) {
        AppPage.dashboard => 'Monitoreo del invernadero',
        AppPage.historial => 'Historial',
        AppPage.alertas => 'Alertas',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: C.frame,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: ListenableBuilder(
            listenable: widget.c,
            builder: (context, _) {
              final c = widget.c;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Sidebar(
                    c: c,
                    page: _page,
                    onPage: (p) => setState(() => _page = p),
                    onSettings: _openSettings,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopBar(c: c, title: _title, onSettings: _openSettings),
                        if (c.link == LinkState.error && c.linkDetail != null)
                          _ErrorBanner(message: c.linkDetail!, onRetry: c.connect),
                        Expanded(
                          child: switch (_page) {
                            AppPage.dashboard => DashboardPage(
                                c: c,
                                onOpenHistory: () => setState(() => _page = AppPage.historial),
                              ),
                            AppPage.historial => HistoryPage(c: c),
                            AppPage.alertas => AlertsPage(c: c),
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.c, required this.title, required this.onSettings});

  final DashboardController c;
  final String title;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Text(
            title,
            maxLines: 1,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: C.line, width: 1.4),
                  color: Colors.white,
                ),
                child: Text(
                  c.settings.topic,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _LinkPill(c: c),
          const SizedBox(width: 10),
          RoundIconBtn(
            icon: Icons.tune_rounded,
            tooltip: 'Ajustes del broker',
            bg: Colors.white,
            fg: C.ink,
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _LinkPill extends StatelessWidget {
  const _LinkPill({required this.c});

  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (c.link) {
      LinkState.connected => ('Conectado', C.ok),
      LinkState.connecting => ('Conectando…', C.warn),
      LinkState.reconnecting => ('Reconectando…', C.warn),
      LinkState.error => ('Error', C.accent),
      LinkState.disconnected => ('Sin conexión', C.muted),
    };
    return Tooltip(
      message: '${c.settings.host}:${c.settings.port}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: C.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: C.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.accent),
            ),
          ),
          const SizedBox(width: 8),
          Pill('Reintentar', selected: true, onTap: onRetry),
        ],
      ),
    );
  }
}
