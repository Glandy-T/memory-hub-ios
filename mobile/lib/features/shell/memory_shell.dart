import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/memory_motion.dart';
import '../../core/theme/memory_theme.dart';
import '../../services/memory_update_service.dart';
import '../../state/memory_controller.dart';
import '../calendar/calendar_screen.dart';
import '../categories/categories_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';

class MemoryShell extends StatefulWidget {
  const MemoryShell({
    super.key,
    required this.controller,
    required this.updates,
  });

  final MemoryController controller;
  final MemoryUpdateService updates;

  @override
  State<MemoryShell> createState() => _MemoryShellState();
}

class _MemoryShellState extends State<MemoryShell> {
  static const _qaScenario = String.fromEnvironment(
    'MEMORY_HUB_QA_SCENARIO',
  );

  int _index = _qaScenario.startsWith('calendar-') ? 1 : 0;
  int _homeVisit = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        controller: widget.controller,
        reminderRefreshEpoch: _homeVisit,
      ),
      CalendarScreen(controller: widget.controller),
      CategoriesScreen(controller: widget.controller),
      ProfileScreen(controller: widget.controller, updates: widget.updates),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: 82 + MediaQuery.paddingOf(context).bottom,
              ),
              child: MemoryFadeThroughStack(index: _index, children: pages),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12 + MediaQuery.paddingOf(context).bottom,
            child: Center(
              child: _MemoryBottomNavigation(
                index: _index,
                onChanged: (value) => setState(() {
                  if (value == 0) _homeVisit += 1;
                  _index = value;
                }),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: MediaQuery.paddingOf(context).top + 8,
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                final message = widget.controller.persistenceError;
                if (message == null) return const SizedBox.shrink();
                return Semantics(
                  liveRegion: true,
                  container: true,
                  label: message,
                  child: Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    elevation: 3,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.sync_problem_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              message,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.controller.retryPersistence,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryBottomNavigation extends StatelessWidget {
  const _MemoryBottomNavigation({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _destinations = [
    (label: '首页', icon: Icons.home_outlined, selected: Icons.home_rounded),
    (
      label: '日历',
      icon: Icons.calendar_today_outlined,
      selected: Icons.calendar_today_rounded,
    ),
    (
      label: '分类',
      icon: Icons.grid_view_outlined,
      selected: Icons.grid_view_rounded,
    ),
    (
      label: '我的',
      icon: Icons.person_outline_rounded,
      selected: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(29),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: math.min(322.0, MediaQuery.sizeOf(context).width - 32),
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(29),
            border: Border.all(color: const Color(0xADB8C6D7)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14617797),
                offset: Offset(0, 6),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (
                var itemIndex = 0;
                itemIndex < _destinations.length;
                itemIndex++
              )
                _AnimatedNavigationDestination(
                  label: _destinations[itemIndex].label,
                  icon: _destinations[itemIndex].icon,
                  selectedIcon: _destinations[itemIndex].selected,
                  selected: index == itemIndex,
                  onTap: () => onChanged(itemIndex),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedNavigationDestination extends StatefulWidget {
  const _AnimatedNavigationDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AnimatedNavigationDestination> createState() =>
      _AnimatedNavigationDestinationState();
}

class _AnimatedNavigationDestinationState
    extends State<_AnimatedNavigationDestination>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 180),
      value: widget.selected ? 1 : 0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MemoryMotion.reduce(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _controller.value = widget.selected ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedNavigationDestination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    if (_reduceMotion) {
      _controller.value = widget.selected ? 1 : 0;
    } else if (widget.selected) {
      _controller.forward(from: 0);
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: widget.selected,
      label: widget.label,
      button: true,
      child: InkResponse(
        onTap: widget.onTap,
        radius: 24,
        containedInkWell: true,
        highlightShape: BoxShape.circle,
        child: SizedBox.square(
          dimension: 48,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = Curves.easeOutQuart.transform(_controller.value);
              final scale = 1 + (0.09 * progress);
              final lift = -2.5 * progress;

              return Transform.translate(
                offset: Offset(0, lift),
                child: Transform.scale(
                  scale: scale,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        key: ValueKey('nav-outline-${widget.label}'),
                        opacity: 1 - progress,
                        child: Icon(
                          widget.icon,
                          color: MemoryColors.secondaryInk,
                          size: 24,
                        ),
                      ),
                      ClipRect(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          heightFactor: progress,
                          child: Opacity(
                            key: ValueKey('nav-color-${widget.label}'),
                            opacity: progress,
                            child: ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (bounds) => const LinearGradient(
                                begin: Alignment.bottomLeft,
                                end: Alignment.topRight,
                                colors: [
                                  Color(0xFFFFC928),
                                  Color(0xFFFFC928),
                                  Color(0xFFFF476F),
                                  Color(0xFFFF476F),
                                  Color(0xFF5C8CFF),
                                ],
                                stops: [0, .34, .35, .76, .77],
                              ).createShader(bounds),
                              child: Icon(widget.selectedIcon, size: 24),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
