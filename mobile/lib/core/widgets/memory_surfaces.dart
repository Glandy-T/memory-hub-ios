import 'dart:ui';

import 'package:flutter/material.dart';

import '../motion/memory_motion.dart';
import '../theme/memory_theme.dart';

class PigmentBackground extends StatelessWidget {
  const PigmentBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MemoryColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/theme/light-pigment-background.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
          ),
          child,
        ],
      ),
    );
  }
}

class OpticalGlass extends StatelessWidget {
  const OpticalGlass({
    super.key,
    required this.child,
    this.padding,
    this.radius = 16,
    this.opacity = .58,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: .74)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1229456B),
                offset: Offset(0, 6),
                blurRadius: 8,
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        ),
      ),
    );
  }
}

class MemoryPageHeader extends StatelessWidget {
  const MemoryPageHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final duration = MemoryMotion.duration(context, MemoryMotion.standard);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: duration,
              switchOutCurve: Curves.easeOutCubic,
              switchInCurve: MemoryMotion.curve,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, .08),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                title,
                key: ValueKey(title),
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: MemoryMotion.duration(context, MemoryMotion.quick),
            switchInCurve: MemoryMotion.curve,
            switchOutCurve: Curves.easeOutCubic,
            child: action == null
                ? const SizedBox.shrink(key: ValueKey('header-no-action'))
                : KeyedSubtree(
                    key: const ValueKey('header-action'),
                    child: action!,
                  ),
          ),
        ],
      ),
    );
  }
}
