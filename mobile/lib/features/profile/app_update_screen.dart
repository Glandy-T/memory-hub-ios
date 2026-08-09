import 'package:flutter/material.dart';

import '../../core/theme/memory_theme.dart';
import '../../core/widgets/memory_surfaces.dart';
import '../../services/memory_update_service.dart';

class AppUpdateScreen extends StatefulWidget {
  const AppUpdateScreen({super.key, required this.updates});

  final MemoryUpdateService updates;

  @override
  State<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends State<AppUpdateScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.updates.checked && !widget.updates.checking) {
      widget.updates.check(silent: true);
    }
  }

  Future<void> _check() async {
    try {
      await widget.updates.check();
      if (!mounted) return;
      final message = widget.updates.available == null
          ? '当前已经是最新版本'
          : '发现 ${widget.updates.available!.versionName}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on MemoryUpdateException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _install() async {
    try {
      final result = await widget.updates.installAvailable();
      if (!mounted) return;
      final message = switch (result) {
        UpdateInstallResult.installerOpened => '下载与校验完成，请在系统页面确认更新',
        UpdateInstallResult.permissionRequired =>
          '请允许 Memory Hub 安装更新，返回后再点一次“下载并更新”',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    } on MemoryUpdateException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('应用更新')),
      body: AnimatedBuilder(
        animation: widget.updates,
        builder: (context, _) {
          final update = widget.updates.available;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
            children: [
              OpticalGlass(
                opacity: .68,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        update == null
                            ? Icons.system_update_alt_rounded
                            : Icons.new_releases_outlined,
                        color: MemoryColors.accent,
                        size: 30,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _title(update),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _description(update),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: MemoryColors.secondaryInk,
                          height: 1.55,
                        ),
                      ),
                      if (update != null && update.notes.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          update.notes,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (widget.updates.error != null &&
                          !widget.updates.checking) ...[
                        const SizedBox(height: 16),
                        Text(
                          widget.updates.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: update == null
                            ? FilledButton.tonalIcon(
                                onPressed: widget.updates.checking
                                    ? null
                                    : _check,
                                icon: widget.updates.checking
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded),
                                label: Text(
                                  widget.updates.checking ? '正在检查' : '检查更新',
                                ),
                              )
                            : FilledButton.icon(
                                onPressed: widget.updates.installing
                                    ? null
                                    : _install,
                                icon: widget.updates.installing
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.download_rounded),
                                label: Text(
                                  widget.updates.installing
                                      ? '正在下载并校验'
                                      : '下载并更新',
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 18, 8, 0),
                child: Text(
                  '更新包来自 Memory Hub 的公开 GitHub 发布页。下载后会核对 SHA-256；不一致时不会打开安装。首次使用需要在安卓系统中允许 Memory Hub 安装更新。',
                  style: TextStyle(
                    color: MemoryColors.secondaryInk,
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _title(MemoryUpdateInfo? update) {
    if (widget.updates.checking) return '正在检查更新';
    if (update != null) return '版本 ${update.versionName} 可以更新';
    if (widget.updates.checked && widget.updates.error == null) {
      return '已经是最新版本';
    }
    return '直接在应用内更新';
  }

  String _description(MemoryUpdateInfo? update) {
    if (widget.updates.checking) return '正在安全读取最新发布信息。';
    if (update != null) return '不需要再去电脑下载 APK。下载完成后，只需在安卓系统页面确认一次安装。';
    return 'Memory Hub 会自动检查正式签名的新版本，也可以在这里主动检查。';
  }
}
