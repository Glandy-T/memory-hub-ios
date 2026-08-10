import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/memory_theme.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/profile/profile_screen.dart';
import '../services/memory_update_service.dart';
import '../state/memory_controller.dart';
import 'lab_home_screen.dart';
import 'lab_profile_section.dart';
import 'lab_state.dart';
import 'timeline_screen.dart';

class LabShell extends StatefulWidget {
  const LabShell({
    super.key,
    required this.controller,
    required this.lab,
    required this.updates,
  });

  final MemoryController controller;
  final LabState lab;
  final MemoryUpdateService updates;

  @override
  State<LabShell> createState() => _LabShellState();
}

class _LabShellState extends State<LabShell> {
  int _index = 0;
  int _homeVisit = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      LabHomeScreen(
        controller: widget.controller,
        lab: widget.lab,
        reminderRefreshEpoch: _homeVisit,
      ),
      CalendarScreen(
        controller: widget.controller,
        onOpenTimeline: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TimelineScreen(
              controller: widget.controller,
              lab: widget.lab,
              date: widget.controller.effectiveToday(),
            ),
          ),
        ),
      ),
      CategoriesScreen(controller: widget.controller),
      ProfileScreen(
        controller: widget.controller,
        updates: widget.updates,
        experimentalSection: LabProfileSection(
          controller: widget.controller,
          lab: widget.lab,
        ),
      ),
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
              child: _LabBottomNavigation(
                index: _index,
                onChanged: (value) => setState(() {
                  if (value == 0) _homeVisit += 1;
                  _index = value;
                }),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 12,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: MemoryColors.ink.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  child: Text(
                    'LAB',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabBottomNavigation extends StatelessWidget {
  const _LabBottomNavigation({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const entries = [
    (Icons.home_outlined, Icons.home_rounded, '首页'),
    (Icons.calendar_today_outlined, Icons.calendar_today_rounded, '日历'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, '分类'),
    (Icons.person_outline_rounded, Icons.person_rounded, '我的'),
  ];

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(29),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: math.min(322, MediaQuery.sizeOf(context).width - 32),
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
            for (var i = 0; i < entries.length; i++)
              Semantics(
                selected: index == i,
                label: entries[i].$3,
                button: true,
                child: InkResponse(
                  key: ValueKey('lab-nav-$i'),
                  onTap: () => onChanged(i),
                  radius: 24,
                  child: SizedBox.square(
                    dimension: 48,
                    child: Icon(
                      index == i ? entries[i].$2 : entries[i].$1,
                      color: index == i
                          ? MemoryColors.accent
                          : MemoryColors.secondaryInk,
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
