import 'package:flutter/material.dart';

/// Stillwater palette: mist and sage. Every color in the app comes from here.
class Still {
  static const mist = Color(0xFFF4F7F5); // window background
  static const fog = Color(0xFFE7EEEA); // panels
  static const line = Color(0xFFDDE6E1); // hairlines
  static const lichen = Color(0xFF9DBBAE); // quiet accents
  static const muted = Color(0xFF5E7A70); // secondary text
  static const sage = Color(0xFF2F5D50); // primary
  static const ink = Color(0xFF1B2E28); // primary text

  /// Overlay flash color, #RRGGBBAA for the native bridge.
  static const flashHex = '#CFE0D799';
}

ThemeData stillwaterTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Still.sage,
      primary: Still.sage,
      surface: Still.mist,
      onSurface: Still.ink,
    ),
    scaffoldBackgroundColor: Still.mist,
  );
  return base.copyWith(
    textTheme:
        base.textTheme.apply(bodyColor: Still.ink, displayColor: Still.ink),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : Still.lichen),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Still.sage : Still.fog),
      trackOutlineColor: WidgetStateProperty.all(Still.line),
    ),
    dividerTheme:
        const DividerThemeData(color: Still.line, thickness: 1, space: 1),
  );
}

/// The ripple-ring logo mark, drawn so it stays crisp at any size.
class RippleMark extends StatelessWidget {
  const RippleMark({super.key, this.size = 32, this.color = Still.sage});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _RipplePainter(color));
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final u =
        size.width / 96; // designed on a 96px grid (assets/brand/logo_mark.svg)
    for (final (r, w, a) in [
      (42.0, 2.0, 0.2),
      (30.0, 3.0, 0.4),
      (18.0, 4.0, 0.7)
    ]) {
      canvas.drawCircle(
          c,
          r * u,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * u
            ..color = color.withValues(alpha: a));
    }
    canvas.drawCircle(c, 7 * u, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.color != color;
}

/// A left-aligned settings row: title, optional subtitle, trailing control.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.enabled = true,
  });
  final String title;
  final String? subtitle;
  final Widget trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Still.ink)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style:
                            const TextStyle(fontSize: 14, color: Still.muted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            IgnorePointer(ignoring: !enabled, child: trailing),
          ],
        ),
      ),
    );
  }
}

/// Compact −/+ stepper for the interval length.
class MinuteStepper extends StatelessWidget {
  const MinuteStepper(
      {super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  static const _min = 1, _max = 180;

  int _step(int dir) {
    // 1-minute steps under 5, then 5-minute steps.
    if (dir < 0) return value <= 5 ? value - 1 : ((value - 1) ~/ 5) * 5;
    return value < 5 ? value + 1 : (value ~/ 5 + 1) * 5;
  }

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, int dir) {
      final next = _step(dir).clamp(_min, _max);
      return IconButton(
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        color: Still.sage,
        onPressed: next == value ? null : () => onChanged(next),
        icon: Icon(icon),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Still.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove, -1),
        SizedBox(
          width: 64,
          child: Text('$value min',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Still.ink,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ),
        btn(Icons.add, 1),
      ]),
    );
  }
}
