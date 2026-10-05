import 'package:flutter/material.dart';

// ============================================================
// GATE BUTTONS — shared buttons for the gateway screens
// ============================================================
// Styled to sit naturally on the Stonewatch cartoon-construction
// artwork: a chunky gold (primary) or timber (secondary) pill with
// a white rim, drop shadow and a press-scale reaction.
//
// Both buttons pin the label with height:1.0 + centre cross-axis
// alignment so it never drifts off the geometric centre in either
// orientation (gray_part_pitfalls §13). The secondary is a full
// solid pill, not a faint text link (gray_part_pitfalls §12).
// ============================================================

enum _Kind { gold, timber }

class WardenButton extends StatefulWidget {
  const WardenButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.compact = false,
  }) : _kind = _Kind.gold;

  const WardenButton.timber({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.compact = false,
  }) : _kind = _Kind.timber;

  final String label;
  final VoidCallback onTap;
  final double? width;
  final bool compact;
  final _Kind _kind;

  @override
  State<WardenButton> createState() => _WardenButtonState();
}

class _WardenButtonState extends State<WardenButton> {
  bool _down = false;

  List<Color> get _fill => widget._kind == _Kind.gold
      ? const <Color>[Color(0xFFFFD75A), Color(0xFFE0A106)]
      : const <Color>[Color(0xFFB9803F), Color(0xFF7A4A22)];

  Color get _edge => widget._kind == _Kind.gold
      ? const Color(0xFF8A5A10)
      : const Color(0xFF4F2E14);

  @override
  Widget build(BuildContext context) {
    final double vPad = widget.compact ? 12 : 16;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          padding: EdgeInsets.symmetric(horizontal: 26, vertical: vPad),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _fill,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 2.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _edge,
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(0, 5),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Lilita',
                  color: Colors.white,
                  fontSize: widget.compact ? 17 : 21,
                  height: 1.0,
                  letterSpacing: 0.6,
                  shadows: const <Shadow>[
                    Shadow(
                      color: Color(0x99000000),
                      offset: Offset(0, 2),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
