import 'package:flutter/material.dart';

import '../core/theme/memory_theme.dart';
import '../core/widgets/memory_surfaces.dart';
import '../state/memory_controller.dart';
import 'lab_state.dart';
import 'pending_capture_screen.dart';

class LabProfileSection extends StatelessWidget {
  const LabProfileSection({
    super.key,
    required this.controller,
    required this.lab,
  });
  final MemoryController controller;
  final LabState lab;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: lab,
    builder: (context, _) => Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              '实验功能',
              style: TextStyle(
                color: MemoryColors.secondaryInk,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OpticalGlass(
              radius: 16,
              child: Column(
                children: [
                  ListTile(
                    minTileHeight: 68,
                    leading: const Icon(
                      Icons.inbox_outlined,
                      color: Color(0xFF58769C),
                    ),
                    title: const Text('实验版待收录'),
                    trailing: Text('${lab.data.captures.length} 条'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PendingCaptureScreen(
                          controller: controller,
                          lab: lab,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 52),
                    child: Divider(height: 1),
                  ),
                  ListTile(
                    minTileHeight: 68,
                    leading: const Icon(
                      Icons.fact_check_outlined,
                      color: Color(0xFF58769C),
                    ),
                    title: const Text('状态检查'),
                    subtitle: const Text('空、离线、错误和权限'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LabStateGallery(),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 52),
                    child: Divider(height: 1),
                  ),
                  ListTile(
                    minTileHeight: 68,
                    leading: const Icon(
                      Icons.restart_alt_rounded,
                      color: Color(0xFF58769C),
                    ),
                    title: const Text('重新查看首次使用'),
                    onTap: () => lab.resetOnboarding(),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Text(
              '实验版使用独立数据库，不会修改正式版内容。',
              style: TextStyle(color: MemoryColors.secondaryInk, fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );
}

class LabStateGallery extends StatefulWidget {
  const LabStateGallery({super.key});

  @override
  State<LabStateGallery> createState() => _LabStateGalleryState();
}

class _LabStateGalleryState extends State<LabStateGallery> {
  String _state = 'empty';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('状态检查'),
      backgroundColor: Colors.transparent,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'empty', label: Text('空状态')),
            ButtonSegment(value: 'offline', label: Text('离线')),
            ButtonSegment(value: 'error', label: Text('错误')),
          ],
          selected: {_state},
          onSelectionChanged: (value) => setState(() => _state = value.first),
        ),
        const SizedBox(height: 32),
        OpticalGlass(
          radius: 20,
          padding: const EdgeInsets.all(26),
          child: switch (_state) {
            'offline' => const _StateContent(
              icon: Icons.cloud_off_outlined,
              title: '当前离线',
              detail: '内容已保存在本机，联网后可重试。',
              action: '立即重试',
            ),
            'error' => const _StateContent(
              icon: Icons.sync_problem_rounded,
              title: '这次没有同步',
              detail: '原内容没有被修改。',
              action: '重新同步',
            ),
            _ => const _StateContent(
              icon: Icons.inbox_outlined,
              title: '还没有待收录内容',
              detail: '从首页快速记录，或从其他任务发送。',
              action: '返回首页',
            ),
          },
        ),
      ],
    ),
  );
}

class _StateContent extends StatelessWidget {
  const _StateContent({
    required this.icon,
    required this.title,
    required this.detail,
    required this.action,
  });
  final IconData icon;
  final String title;
  final String detail;
  final String action;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, size: 38, color: MemoryColors.secondaryInk),
      const SizedBox(height: 18),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(detail, textAlign: TextAlign.center),
      const SizedBox(height: 22),
      FilledButton.tonal(onPressed: () {}, child: Text(action)),
    ],
  );
}
