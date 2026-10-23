import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'format.dart';
import 'models.dart';
import 'theme.dart';

/// The Neev wordmark: an abstract winding route inside a rounded tile.
class NeevLogo extends StatelessWidget {
  const NeevLogo({
    super.key,
    this.size = 40,
    this.showWordmark = true,
    this.subtitle,
    this.light = false,
  });

  final double size;
  final bool showWordmark;
  final String? subtitle;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final ink = light ? Colors.white : NeevColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: light ? Colors.white : NeevColors.green,
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: CustomPaint(
            painter: _RouteMarkPainter(
              color: light ? NeevColors.green : Colors.white,
              accent: NeevColors.amber,
            ),
          ),
        ),
        if (showWordmark) ...[
          SizedBox(width: size * 0.32),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'neev',
                style: TextStyle(
                  fontSize: size * 0.68,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                  color: ink,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: size * 0.24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: light ? Colors.white70 : NeevColors.muted,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RouteMarkPainter extends CustomPainter {
  const _RouteMarkPainter({required this.color, required this.accent});
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.80)
      ..cubicTo(
        size.width * 0.15,
        size.height * 0.46,
        size.width * 0.44,
        size.height * 0.56,
        size.width * 0.48,
        size.height * 0.34,
      )
      ..cubicTo(
        size.width * 0.52,
        size.height * 0.14,
        size.width * 0.80,
        size.height * 0.22,
        size.width * 0.78,
        size.height * 0.46,
      );
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.80),
      size.width * 0.10,
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accent != accent;
}

/// A primary action that shows progress and blocks double taps.
class NeevButton extends StatelessWidget {
  const NeevButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.tone = NeevButtonTone.primary,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final NeevButtonTone tone;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
          )
        else if (icon != null)
          Icon(icon, size: 19),
        if (loading || icon != null) const SizedBox(width: 10),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    final button = switch (tone) {
      NeevButtonTone.primary => FilledButton(
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
      NeevButtonTone.amber => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: NeevColors.amber,
            foregroundColor: NeevColors.ink,
          ),
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
      NeevButtonTone.danger => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: NeevColors.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
      NeevButtonTone.outline => OutlinedButton(
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

enum NeevButtonTone { primary, amber, danger, outline }

class NeevField extends StatelessWidget {
  const NeevField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.maxLength,
    this.obscureText = false,
    this.prefixIcon,
    this.onChanged,
    this.onSubmitted,
    this.helper,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool obscureText;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? helper;
  final bool enabled;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLength: maxLength,
          enabled: enabled,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            counterText: '',
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
          ),
        ),
      ],
    );
  }
}

class NeevCard extends StatelessWidget {
  const NeevCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? NeevColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? NeevColors.line),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: content,
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.action,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 13, color: NeevColors.muted),
                ),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.label});
  final String status;
  final String? label;

  _PillColors get _colors {
    switch (status) {
      case 'completed':
      case 'captured':
      case 'approved':
      case 'active':
      case 'paid':
        return _PillColors(NeevColors.greenSoft, NeevColors.greenDeep);
      case 'searching':
      case 'pending':
      case 'documents_pending':
      case 'processing':
      case 'requested':
        return _PillColors(NeevColors.amberSoft, const Color(0xFF7A5400));
      case 'cancelled':
      case 'expired':
      case 'rejected':
      case 'failed':
      case 'suspended':
      case 'no_show':
        return _PillColors(NeevColors.dangerSoft, NeevColors.danger);
      case 'assigned':
      case 'arriving':
      case 'arrived':
      case 'in_progress':
      case 'started':
        return _PillColors(NeevColors.infoSoft, NeevColors.info);
      default:
        return _PillColors(const Color(0xFFEFEFEA), NeevColors.inkSoft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label ?? humanize(status),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: colors.foreground,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _PillColors {
  const _PillColors(this.background, this.foreground);
  final Color background;
  final Color foreground;
}

class NeevAvatar extends StatelessWidget {
  const NeevAvatar({super.key, required this.name, this.size = 44, this.imageUrl});
  final String name;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: NeevColors.greenSoft,
        shape: BoxShape.circle,
        border: Border.all(color: NeevColors.line),
      ),
      child: Text(
        initials(name),
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          color: NeevColors.greenDeep,
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13.5, color: NeevColors.muted),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: valueColor ?? NeevColors.ink,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: NeevColors.greenSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: NeevColors.green, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: NeevColors.muted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label = 'Loading…'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: NeevColors.muted),
          ),
        ],
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NeevColors.dangerSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NeevColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 20, color: NeevColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13.5, color: NeevColors.danger),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.label = 'Demo dataset'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: NeevColors.amberSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NeevColors.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.science_outlined, size: 13, color: Color(0xFF7A5400)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A5400),
            ),
          ),
        ],
      ),
    );
  }
}

/// A hold-to-activate safety control. The action fires only after the user
/// holds for [holdDuration], matching the backend's press-hold expectation.
class HoldToActivate extends StatefulWidget {
  const HoldToActivate({
    super.key,
    required this.label,
    required this.onActivated,
    this.icon = Icons.sos_outlined,
    this.holdDuration = const Duration(seconds: 3),
    this.color = NeevColors.danger,
  });

  final String label;
  final VoidCallback onActivated;
  final IconData icon;
  final Duration holdDuration;
  final Color color;

  @override
  State<HoldToActivate> createState() => _HoldToActivateState();
}

class _HoldToActivateState extends State<HoldToActivate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onActivated();
        _controller.reset();
      }
    });

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            height: 52,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.color.withValues(alpha: 0.5)),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: _controller.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: 19, color: widget.color),
                      const SizedBox(width: 8),
                      Text(
                        _controller.value > 0
                            ? 'Keep holding…'
                            : widget.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: widget.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Lightweight vector map used because the development build has no map SDK
/// key. It renders real coordinates from the API on a stylised street canvas,
/// so routes and positions remain honest even though the tiles are synthetic.
class NeevMap extends StatelessWidget {
  const NeevMap({
    super.key,
    this.route = const [],
    this.pickup,
    this.drop,
    this.captain,
    this.height = 260,
    this.providerLabel = 'Demo map',
    this.showLegend = true,
    this.borderRadius = 22,
  });

  final List<LatLng> route;
  final LatLng? pickup;
  final LatLng? drop;
  final LatLng? captain;
  final double height;
  final String providerLabel;
  final bool showLegend;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _NeevMapPainter(
                route: route,
                pickup: pickup,
                drop: drop,
                captain: captain,
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: NeevColors.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_outlined,
                        size: 12, color: NeevColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      providerLabel,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: NeevColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showLegend)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: NeevColors.line),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LegendDot(color: NeevColors.amber, label: 'Pickup'),
                      SizedBox(width: 8),
                      _LegendDot(color: NeevColors.green, label: 'Drop'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, color: NeevColors.muted),
        ),
      ],
    );
  }
}

class _NeevMapPainter extends CustomPainter {
  _NeevMapPainter({this.route = const [], this.pickup, this.drop, this.captain});

  final List<LatLng> route;
  final LatLng? pickup;
  final LatLng? drop;
  final LatLng? captain;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFEDEBE2);
    canvas.drawRect(Offset.zero & size, background);

    final points = <LatLng>[
      ...route,
      if (pickup != null) pickup!,
      if (drop != null) drop!,
      if (captain != null) captain!,
    ];
    if (points.isEmpty) {
      points.addAll(const [LatLng(12.9756, 77.6066), LatLng(12.9345, 77.6266)]);
    }

    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLng = points.first.lng, maxLng = points.first.lng;
    for (final p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    final latSpan = math.max(maxLat - minLat, 0.008);
    final lngSpan = math.max(maxLng - minLng, 0.008);
    minLat -= latSpan * 0.18;
    maxLat += latSpan * 0.18;
    minLng -= lngSpan * 0.18;
    maxLng += lngSpan * 0.18;

    Offset project(LatLng p) {
      final x = (p.lng - minLng) / (maxLng - minLng) * size.width;
      final y = (maxLat - p.lat) / (maxLat - minLat) * size.height;
      return Offset(x, y);
    }

    _paintBlocks(canvas, size, project, points);
    if (route.length > 1) _paintRoute(canvas, size, project);
    if (drop != null) _paintPin(canvas, project(drop!), NeevColors.green, false);
    if (captain != null) {
      _paintCaptain(canvas, project(captain!));
    }
    if (pickup != null) _paintPin(canvas, project(pickup!), NeevColors.amber, true);
  }

  void _paintBlocks(
    Canvas canvas,
    Size size,
    Offset Function(LatLng) project,
    List<LatLng> points,
  ) {
    final park = Paint()..color = const Color(0xFFDDE7D8);
    final water = Paint()..color = const Color(0xFFD7E4E8);
    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final minorRoad = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.66, size.height * 0.08, size.width * 0.42,
            size.height * 0.30),
        const Radius.circular(26),
      ),
      park,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-size.width * 0.10, size.height * 0.62, size.width * 0.42,
            size.height * 0.28),
        const Radius.circular(20),
      ),
      water,
    );

    for (var i = 1; i < 5; i++) {
      final y = size.height * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 12), road);
    }
    for (var i = 1; i < 6; i++) {
      final x = size.width * (i / 6);
      canvas.drawLine(Offset(x, 0), Offset(x - 10, size.height), minorRoad);
    }
    // A diagonal arterial road keeps the canvas from looking like graph paper.
    canvas.drawLine(
      Offset(-10, size.height * 0.82),
      Offset(size.width * 1.05, size.height * 0.10),
      road,
    );
  }

  void _paintRoute(
    Canvas canvas,
    Size size,
    Offset Function(LatLng) project,
  ) {
    final path = Path()..moveTo(project(route.first).dx, project(route.first).dy);
    for (final point in route.skip(1)) {
      final offset = project(point);
      path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = NeevColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintPin(Canvas canvas, Offset center, Color color, bool ring) {
    canvas.drawCircle(center, 11, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = color
        ..style = ring ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 4,
    );
    if (ring) {
      canvas.drawCircle(center, 2.4, Paint()..color = color);
    }
  }

  void _paintCaptain(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      12,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(center, 9.5, Paint()..color = NeevColors.ink);
    final arrow = Path()
      ..moveTo(center.dx, center.dy - 5.5)
      ..lineTo(center.dx + 4.6, center.dy + 4.5)
      ..lineTo(center.dx, center.dy + 2)
      ..lineTo(center.dx - 4.6, center.dy + 4.5)
      ..close();
    canvas.drawPath(arrow, Paint()..color = NeevColors.amber);
  }

  @override
  bool shouldRepaint(covariant _NeevMapPainter oldDelegate) =>
      oldDelegate.route != route ||
      oldDelegate.pickup != pickup ||
      oldDelegate.drop != drop ||
      oldDelegate.captain != captain;
}

/// Small labelled metric used across trip and earnings screens.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tone = NeevColors.surface,
    this.foreground = NeevColors.ink,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color tone;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NeevColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: foreground.withValues(alpha: 0.65)),
            const SizedBox(height: 8),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: foreground,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: foreground.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
