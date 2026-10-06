import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A compact segmented ON/OFF control, styled to match [GlossyIconTile]'s
/// gradient fill. As in real iOS Settings, the switch fill is ONE
/// consistent color across every row (system green) — only the icon
/// tile backgrounds vary by category. Pass `AppTheme.greenFor(isDark)`
/// for every instance; don't wire it to the row's own icon color.
///
/// Drop-in replacement for `Switch.adaptive` in `_ToggleRow`.
///
/// `enabled` is a separate axis from `value`. `value: false` (off) still
/// stays interactive and reads as neutral gray — it's a live control the
/// user can flip. `enabled: false` (locked/unavailable, e.g. Wallet Lock
/// before a PIN is set) goes flat near-black with no gradient, no glossy
/// fill, and no tap response, whatever `value` happens to be — that's what
/// actually signals "you can't touch this right now."
class AppSegmentedToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final bool isDark;
  final bool enabled;

  const AppSegmentedToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.activeColor,
    required this.isDark,
    this.enabled = true,
  });

  static const double _width = 74;
  static const double _height = 30;
  static const double _padding = 3;

  @override
  Widget build(BuildContext context) {
    final trackColor = !enabled
        ? (isDark ? Colors.black : AppTheme.gray4)
        : (isDark ? AppTheme.darkSurface2 : AppTheme.gray6);
    final borderColor = !enabled
        ? (isDark ? Colors.black : AppTheme.gray3)
        : AppTheme.border(isDark);
    final baseIdleTextColor =
    isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary;
    final idleTextColor =
    !enabled ? baseIdleTextColor.withOpacity(0.35) : baseIdleTextColor;
    // Text sitting on the selected thumb: the OFF thumb is light
    // (white/mid-gray), so it needs dark text; the ON thumb is a
    // saturated activeColor, which needs white text.
    final selectedTextColor = !enabled
        ? Colors.white.withOpacity(0.35)
        : (value ? Colors.white : (isDark ? Colors.white : Colors.black87));

    // Flat, no gradient/glow, when locked — a colored glossy fill would
    // wrongly suggest the control is live.
    final indicatorFill = !enabled
        ? (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFB0B0B3))
        : (value
        ? activeColor
        : (isDark ? const Color(0xFF636366) : Colors.white));

    return GestureDetector(
      onTap: enabled ? () => onChanged(!value) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _width,
        height: _height,
        padding: const EdgeInsets.all(_padding),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: enabled
                        ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(indicatorFill, Colors.white, 0.24)!,
                        indicatorFill,
                      ],
                    )
                        : null,
                    color: enabled ? null : indicatorFill,
                    boxShadow: enabled
                        ? [
                      BoxShadow(
                        color: indicatorFill.withOpacity(0.35),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                        : null,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _label('OFF', !value, idleTextColor, selectedTextColor),
                ),
                Expanded(
                  child: _label('ON', value, idleTextColor, selectedTextColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(
      String text,
      bool selected,
      Color idleColor,
      Color selectedColor,
      ) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: selected ? selectedColor : idleColor,
        ),
      ),
    );
  }
}
