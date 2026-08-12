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
    this.lightShift = Offset.zero,
    this.blurEnabled = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double opacity;
  final Offset lightShift;
  final bool blurEnabled;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final innerRadius = BorderRadius.circular(
      (radius - 1).clamp(0.0, radius).toDouble(),
    );
    // Keep one recognisable frosted-glass density across large hero surfaces
    // and compact rows. Opacity changes the milkiness only slightly; the
    // background blur, rim and specular light do the material work.
    final tint = (.055 + opacity * .17).clamp(.055, .19).toDouble();
    final highlight = Alignment(
      (-.66 + lightShift.dx * .82).clamp(-1.0, 1.0).toDouble(),
      (-.76 + lightShift.dy * .68).clamp(-1.0, 1.0).toDouble(),
    );
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: const Alignment(-1, -1),
          end: const Alignment(1, 1),
          colors: [
            Colors.white.withValues(alpha: .76),
            Colors.white.withValues(alpha: .13),
            Colors.white.withValues(alpha: .48),
          ],
          stops: const [0, .46, 1],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(.9),
        child: ClipRRect(
          borderRadius: innerRadius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: innerRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: tint + .045),
                  Colors.white.withValues(alpha: tint * .68),
                  const Color(0xFFDCEFFF).withValues(alpha: tint * .56),
                ],
                stops: const [0, .52, 1],
              ),
            ),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: highlight,
                          radius: .92,
                          colors: [
                            Colors.white.withValues(alpha: .24),
                            Colors.white.withValues(alpha: .045),
                            Colors.transparent,
                          ],
                          stops: const [0, .48, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: padding ?? EdgeInsets.zero,
                    child: child,
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _GlassEdgePainter(
                        radius: (radius - 1).clamp(0, radius).toDouble(),
                        lightShift: lightShift,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final filteredSurface = blurEnabled
        ? BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: surface,
          )
        : surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x16213F68),
            offset: Offset(0, 4),
            blurRadius: 7,
          ),
        ],
      ),
      child: ClipRRect(borderRadius: borderRadius, child: filteredSurface),
    );
  }
}

class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter({required this.radius, required this.lightShift});

  final double radius;
  final Offset lightShift;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rimRect = rect.deflate(1.15);
    final rim = RRect.fromRectAndRadius(
      rimRect,
      Radius.circular((radius - 1.15).clamp(0, radius).toDouble()),
    );
    final direction = Offset(
      lightShift.dx.clamp(-1.0, 1.0).toDouble(),
      lightShift.dy.clamp(-1.0, 1.0).toDouble(),
    );
    final brightBegin = Alignment(
      (-1 + direction.dx * .24).clamp(-1.0, 1.0).toDouble(),
      (-1 + direction.dy * .24).clamp(-1.0, 1.0).toDouble(),
    );
    final darkEnd = Alignment(
      (1 + direction.dx * .18).clamp(-1.0, 1.0).toDouble(),
      (1 + direction.dy * .18).clamp(-1.0, 1.0).toDouble(),
    );

    canvas.drawRRect(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9
        ..shader = LinearGradient(
          begin: brightBegin,
          end: darkEnd,
          colors: [
            Colors.white.withValues(alpha: .58),
            Colors.white.withValues(alpha: .1),
            const Color(0xFF274A69).withValues(alpha: .1),
          ],
          stops: const [0, .5, 1],
        ).createShader(rect),
    );

    final innerRect = rect.deflate(2.65);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        innerRect,
        Radius.circular((radius - 2.65).clamp(0, radius).toDouble()),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..shader = LinearGradient(
          begin: brightBegin,
          end: darkEnd,
          colors: [
            Colors.transparent,
            Colors.transparent,
            const Color(0xFF18344F).withValues(alpha: .055),
          ],
          stops: const [0, .56, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassEdgePainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.lightShift != lightShift;
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
