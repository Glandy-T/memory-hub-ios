import 'package:flutter/material.dart';

abstract final class MemoryMotion {
  static const quick = Duration(milliseconds: 140);
  static const standard = Duration(milliseconds: 220);
  static const exit = Duration(milliseconds: 160);
  static const curve = Curves.easeOutQuart;

  static bool reduce(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    return media?.disableAnimations == true ||
        media?.accessibleNavigation == true;
  }

  static Duration duration(BuildContext context, Duration value) =>
      reduce(context) ? Duration.zero : value;
}

class MemoryFadeThroughStack extends StatelessWidget {
  const MemoryFadeThroughStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final duration = MemoryMotion.duration(context, MemoryMotion.standard);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var itemIndex = 0; itemIndex < children.length; itemIndex++)
          IgnorePointer(
            ignoring: itemIndex != index,
            child: ExcludeSemantics(
              excluding: itemIndex != index,
              child: AnimatedSlide(
                key: ValueKey('shell-page-slide-$itemIndex'),
                duration: duration,
                curve: MemoryMotion.curve,
                offset: itemIndex == index
                    ? Offset.zero
                    : Offset(itemIndex < index ? -.012 : .012, 0),
                child: AnimatedOpacity(
                  key: ValueKey('shell-page-opacity-$itemIndex'),
                  duration: duration,
                  curve: itemIndex == index
                      ? MemoryMotion.curve
                      : Curves.easeOutCubic,
                  opacity: itemIndex == index ? 1 : 0,
                  child: TickerMode(
                    enabled: itemIndex == index,
                    child: children[itemIndex],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
