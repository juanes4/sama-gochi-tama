import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dashboard_controller.dart';
import '../models.dart';
import '../theme.dart';
import 'common.dart';
import 'painters.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.c,
    required this.page,
    required this.onPage,
    required this.onSettings,
  });

  final DashboardController c;
  final AppPage page;
  final ValueChanged<AppPage> onPage;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _Profile(name: c.settings.displayName),
            const SizedBox(height: 12),
            const _ProjectCard(),
            const SizedBox(height: 12),
            _Nav(page: page, onPage: onPage, alerts: c.alertCount),
            const SizedBox(height: 12),
            _StatsCard(c: c),
            const SizedBox(height: 12),
            _QuickActions(c: c),
            const SizedBox(height: 12),
            _AddCard(onTap: onSettings),
          ],
        ),
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: C.accentSoft,
            child: Icon(Icons.person_rounded, color: C.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hola de nuevo,', style: TextStyle(fontSize: 12, color: C.muted)),
                Text(
                  '$name!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: C.frame, borderRadius: BorderRadius.circular(12)),
            child: const Text('E1', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Proyecto', style: TextStyle(fontSize: 11, color: C.muted)),
                Text(
                  'Equipo 01 · Invernadero',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.page, required this.onPage, required this.alerts});

  final AppPage page;
  final ValueChanged<AppPage> onPage;
  final int alerts;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _NavTile(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            selected: page == AppPage.dashboard,
            onTap: () => onPage(AppPage.dashboard),
          ),
          _NavTile(
            icon: Icons.history_rounded,
            label: 'Historial',
            selected: page == AppPage.historial,
            onTap: () => onPage(AppPage.historial),
          ),
          _NavTile(
            icon: Icons.notifications_none_rounded,
            label: 'Alertas',
            badge: alerts,
            selected: page == AppPage.alertas,
            onTap: () => onPage(AppPage.alertas),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : C.ink;
    return Clickable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 42,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? C.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
              ),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : C.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? C.accent : Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta roja de estadísticas de mensajes (equivale a "Recent trips").
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.c});

  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    final (link, linkColor) = switch (c.link) {
      LinkState.connected => ('Conectado', Colors.white),
      LinkState.connecting => ('Conectando…', Colors.white70),
      LinkState.reconnecting => ('Reconectando…', Colors.white70),
      LinkState.error => ('Error', Colors.white),
      LinkState.disconnected => ('Sin conexión', Colors.white70),
    };

    return AppCard(
      color: C.accent,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mensajes',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              Text(
                link,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: linkColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(
                'Recibidos',
                onDark: true,
                selected: c.statKind == StatKind.recibidos,
                onTap: () => c.selectStat(StatKind.recibidos),
              ),
              Pill(
                'Rechazados',
                onDark: true,
                selected: c.statKind == StatKind.rechazados,
                onTap: () => c.selectStat(StatKind.rechazados),
              ),
              Pill(
                'Reintentos',
                onDark: true,
                selected: c.statKind == StatKind.reconexiones,
                onTap: () => c.selectStat(StatKind.reconexiones),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${c.statValue}',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
                ),
                const TextSpan(
                  text: '  msg',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            style: const TextStyle(color: Colors.white, height: 1.1),
          ),
          Text(
            c.paused ? 'Recepción en pausa' : 'Desde que abriste la app',
            style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.c});

  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Quick(
            icon: Icons.sync_rounded,
            tooltip: 'Reconectar',
            onTap: c.connect,
          ),
          _Quick(
            icon: c.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            tooltip: c.paused ? 'Reanudar recepción' : 'Pausar recepción',
            active: c.paused,
            onTap: c.togglePause,
          ),
          _Quick(
            icon: Icons.delete_sweep_rounded,
            tooltip: 'Limpiar historial',
            onTap: c.clearHistory,
          ),
          _Quick(
            icon: Icons.copy_all_rounded,
            tooltip: 'Copiar historial (CSV)',
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
        ],
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Clickable(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active ? C.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: active ? C.accent : C.ink),
        ),
      ),
    );
  }
}

/// Tarjeta punteada (equivale a "Create new request"): abre los ajustes del broker.
class _AddCard extends StatelessWidget {
  const _AddCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: onTap,
      child: SizedBox(
        height: 112,
        child: CustomPaint(
          painter: DashedRRectPainter(color: C.accent.withValues(alpha: 0.55)),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: C.accent,
                  child: Icon(Icons.settings_rounded, color: Colors.white, size: 19),
                ),
                SizedBox(height: 8),
                Text(
                  'Configurar broker',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
