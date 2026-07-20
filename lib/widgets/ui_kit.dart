import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/audio.dart';

/// A fast, smooth page transition (fade + tiny slide). Much snappier than the
/// default ~350ms iOS slide so navigation feels instant.
Route<T> appRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 170),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// A chunky, cartoon-style button with a bottom "bevel" for depth.
class CandyButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final Color shadowColor;
  final double width;
  final double height;
  final double fontSize;
  final bool enabled;

  const CandyButton({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.color = AppTheme.primary,
    this.shadowColor = AppTheme.primaryDark,
    this.width = 240,
    this.height = 62,
    this.fontSize = 22,
    this.enabled = true,
  });

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;
    final Color base = active ? widget.color : Colors.grey.shade400;
    final Color shadow = active ? widget.shadowColor : Colors.grey.shade600;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: active ? () => setState(() => _pressed = false) : null,
      onTapUp: active
          ? (_) {
              setState(() => _pressed = false);
              Audio.instance.tap();
              widget.onTap!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        width: widget.width,
        height: widget.height,
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 3),
          boxShadow: [
            BoxShadow(
              color: shadow,
              offset: Offset(0, _pressed ? 2 : 6),
              blurRadius: 0,
            ),
            const BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: widget.fontSize + 4),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.title(widget.fontSize),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small round icon button (used for back, settings, sound, etc.).
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppTheme.green,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Audio.instance.tap();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), offset: Offset(0, 3), blurRadius: 6),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}

/// A translucent cream panel used to group content on screens.
class WoodPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;

  const WoodPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.cream.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.brown.withValues(alpha: 0.55), width: 4),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), offset: Offset(0, 6), blurRadius: 14),
        ],
      ),
      child: child,
    );
  }
}

/// Header row with a title and an optional back button.
class ScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const ScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          RoundIconButton(icon: Icons.arrow_back_rounded, onTap: onBack!),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: AppTheme.title(28),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// Standard full-screen gradient background with soft floating shapes.
class SkyBackground extends StatelessWidget {
  final Widget child;
  const SkyBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.skyGradient),
      child: child,
    );
  }
}
