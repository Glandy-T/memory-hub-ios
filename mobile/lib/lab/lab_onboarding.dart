import 'package:flutter/material.dart';

import '../core/theme/memory_theme.dart';
import '../core/widgets/memory_surfaces.dart';
import 'lab_state.dart';

class LabOnboarding extends StatefulWidget {
  const LabOnboarding({super.key, required this.lab});

  final LabState lab;

  @override
  State<LabOnboarding> createState() => _LabOnboardingState();
}

class _LabOnboardingState extends State<LabOnboarding> {
  final _page = PageController();
  final _selected = <String>{'remember', 'start', 'items'};
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  const Text(
                    'Memory Hub',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text('实验版', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (value) => setState(() => _index = value),
                children: [
                  _Welcome(onNext: _next),
                  _Needs(
                    selected: _selected,
                    onChanged: (key) => setState(() {
                      _selected.contains(key)
                          ? _selected.remove(key)
                          : _selected.add(key);
                    }),
                    onNext: _next,
                  ),
                  _Privacy(
                    onFinish: () => widget.lab.finishOnboarding(_selected),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: i == _index ? 22 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: i == _index
                            ? MemoryColors.accent
                            : MemoryColors.hairline,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _next() {
    final nextPage = _index < 2 ? _index + 1 : 2;
    if (MediaQuery.disableAnimationsOf(context)) {
      _page.jumpToPage(nextPage);
      return;
    }
    _page.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _OnboardingBody(
    title: '先记下来',
    subtitle: '记录事项、文档和物品位置。',
    buttonLabel: '开始',
    onPressed: onNext,
    footer: '不提供医疗诊断',
    child: OpticalGlass(
      radius: 20,
      padding: const EdgeInsets.all(24),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('示例', style: TextStyle(color: MemoryColors.secondaryInk)),
          SizedBox(height: 22),
          Text(
            '8月12日下午给诊所打电话',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12),
          Text('保存前可确认日期和分类。'),
        ],
      ),
    ),
  );
}

class _Needs extends StatelessWidget {
  const _Needs({
    required this.selected,
    required this.onChanged,
    required this.onNext,
  });
  final Set<String> selected;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;

  static const entries = [
    ('remember', '容易忘记', '记下后，在需要时再次出现'),
    ('start', '很难开始', '只显示下一步'),
    ('time', '时间没感觉', '查看每天剩余时间'),
    ('resume', '中断后接不上', '回来时接着上一步'),
    ('items', '东西总找不到', '关联文档、物品和位置'),
  ];

  @override
  Widget build(BuildContext context) => _OnboardingBody(
    title: '选择常用功能',
    subtitle: '可多选，也可跳过。',
    buttonLabel: '继续',
    onPressed: onNext,
    child: Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OpticalGlass(
              radius: 16,
              child: CheckboxListTile(
                value: selected.contains(entry.$1),
                onChanged: (_) => onChanged(entry.$1),
                title: Text(entry.$2),
                subtitle: Text(entry.$3),
                controlAffinity: ListTileControlAffinity.leading,
                minTileHeight: 70,
              ),
            ),
          ),
      ],
    ),
  );
}

class _Privacy extends StatelessWidget {
  const _Privacy({required this.onFinish});
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) => _OnboardingBody(
    title: '保存方式',
    subtitle: '外部内容会先进入待收录。',
    buttonLabel: '进入首页',
    onPressed: onFinish,
    child: const Column(
      children: [
        _Rule(number: '1', title: '保留原文', detail: '识别结果先作为候选。'),
        SizedBox(height: 12),
        _Rule(number: '2', title: '确认分类', detail: '确认前可修改或删除。'),
        SizedBox(height: 12),
        _Rule(number: '3', title: '支持恢复', detail: '删除后可从回收站恢复。'),
      ],
    ),
  );
}

class _Rule extends StatelessWidget {
  const _Rule({
    required this.number,
    required this.title,
    required this.detail,
  });
  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => OpticalGlass(
    radius: 16,
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        CircleAvatar(radius: 18, child: Text(number)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OnboardingBody extends StatelessWidget {
  const _OnboardingBody({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.buttonLabel,
    required this.onPressed,
    this.footer,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final String buttonLabel;
  final VoidCallback onPressed;
  final String? footer;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            title,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(height: 48),
        child,
        const SizedBox(height: 38),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
        ),
        if (footer != null) ...[
          const SizedBox(height: 22),
          Center(
            child: Text(footer!, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ],
    ),
  );
}
