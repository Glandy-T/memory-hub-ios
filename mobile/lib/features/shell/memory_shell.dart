import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/memory_theme.dart';
import '../../state/memory_controller.dart';
import '../calendar/calendar_screen.dart';
import '../categories/categories_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';

class MemoryShell extends StatefulWidget {
  const MemoryShell({super.key, required this.controller});

  final MemoryController controller;

  @override
  State<MemoryShell> createState() => _MemoryShellState();
}

class _MemoryShellState extends State<MemoryShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(controller: widget.controller),
      CalendarScreen(controller: widget.controller),
      CategoriesScreen(controller: widget.controller),
      ProfileScreen(controller: widget.controller),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: 82 + MediaQuery.paddingOf(context).bottom,
              ),
              child: IndexedStack(index: _index, children: pages),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12 + MediaQuery.paddingOf(context).bottom,
            child: Center(
              child: _MemoryBottomNavigation(
                index: _index,
                onChanged: (value) => setState(() => _index = value),
              ),
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
          width: 322,
          height: 58,
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
                Semantics(
                  selected: index == itemIndex,
                  label: _destinations[itemIndex].label,
                  button: true,
                  child: InkResponse(
                    onTap: () => onChanged(itemIndex),
                    radius: 24,
                    child: SizedBox.square(
                      dimension: 48,
                      child: Icon(
                        index == itemIndex
                            ? _destinations[itemIndex].selected
                            : _destinations[itemIndex].icon,
                        color: index == itemIndex
                            ? MemoryColors.accent
                            : MemoryColors.secondaryInk,
                        size: 24,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
