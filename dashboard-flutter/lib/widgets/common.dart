import 'package:flutter/material.dart';

import '../theme.dart';

/// Tarjeta blanca con esquinas muy redondeadas y sombra suave.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = C.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

/// Zona clicable con cursor de mano (pensado para escritorio).
class Clickable extends StatelessWidget {
  const Clickable({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class CardHeader extends StatelessWidget {
  const CardHeader(this.title, {super.key, this.trailing, this.color});

  final String title;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color ?? C.ink),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Chip con borde rojo; relleno rojo cuando está seleccionado.
/// Con [onDark] se invierte para usarlo sobre una tarjeta roja.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.selected = false, this.onTap, this.onDark = false});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final border = onDark ? Colors.white : C.accent;
    final fill = selected ? (onDark ? Colors.white : C.accent) : Colors.transparent;
    final text = selected ? (onDark ? C.accent : Colors.white) : border;
    return Clickable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border.withValues(alpha: selected ? 1.0 : 0.8)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text),
        ),
      ),
    );
  }
}

class RoundIconBtn extends StatelessWidget {
  const RoundIconBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 34,
    this.bg = C.accent,
    this.fg = Colors.white,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final btn = Clickable(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: size * 0.48, color: fg),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, this.color, {super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class FlexItem {
  const FlexItem(this.flex, this.child);
  final int flex;
  final Widget child;
}

/// Fila de tarjetas con altura fija. Si no hay ancho suficiente se apilan.
class AdaptiveRow extends StatelessWidget {
  const AdaptiveRow({
    super.key,
    required this.height,
    required this.items,
    this.breakpoint = 860,
    this.gap = 16,
  });

  final double height;
  final List<FlexItem> items;
  final double breakpoint;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= breakpoint) {
          return SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(flex: items[i].flex, child: items[i].child),
                ],
              ],
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              SizedBox(height: height, child: items[i].child),
            ],
          ],
        );
      },
    );
  }
}
