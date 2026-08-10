# Memory Hub ADHD 实验版存档

存档日期：2026-08-10

## 边界

- 独立入口：`mobile/lib/main_lab.dart`
- Android 包名：`com.glandy.memoryhub.lab`
- 应用名：`Memory Hub 实验版`
- 实验状态：`memory-hub-lab-features-v1`
- 实验数据库：`memory-hub-lab-database-v1` 与独立备份
- 正式入口 `mobile/lib/main.dart`、正式包名和正式数据键保持不变，可同时安装。

## 已实现闭环

- 三步低负担首启，不收集诊断或症状评分。
- 首页快速记录，按安排、截止日、文档、购买和物品位置进入待收录。
- 待收录在确认前补日期、可选时间、分类或位置，支持忽略和可恢复的数据写入规则；安排会识别“明天 / 后天 / 大后天”与常见中文时段，仍由用户最终确认。
- 任务详情展示预计时长、下一步与文档/物品/截止日关联。
- 3 / 5 / 8 步拆解，步骤可编辑、增加和重排。
- 单步专注计时，暂停时保存检查点，可继续、加时、完成或改到稍后。
- 日历容量时间线、灵活事项、缓冲、移动日期与“今天放不下”处理。
- 可复用的出门前检查与睡前整理流程，不使用连续打卡、分数或羞耻式逾期。
- 空、离线、错误状态陈列，以及实验数据和正式数据隔离说明。

## 视觉与图标

实现遵循 Figma `12–19` 浅色正式页面，重点核对节点 `397:132`、`400:132`、`400:192`、`400:234` 与 `402:132`。内容继续使用浅色彩虹颗粒、蓝灰文字和标准光学表面；玻璃只用于导航与短暂控件。

图标由 `assets/icon/memory-hub-icon-source.svg` 与 `mobile/tool/generate_app_icon.ps1` 维护：彩虹场代表分散信息，中央方形与四个节点构成外部记忆枢纽。没有文字、脑部或医疗符号；同时生成 Android 自适应前景、单色图标、各密度位图和 iOS AppIcon 全套尺寸。

## 验收门槛

- `flutter analyze --no-pub`
- `flutter test --no-pub --exclude-tags=visual`
- `flutter test --no-pub --tags=visual`
- `flutter build web --release --no-pub -t lib/main_lab.dart`
- 430×932 浏览器实操：首启、快速记录、待收录、五步拆解、专注、暂停检查点、日历和时间线。
- 浏览器控制台无错误或警告。
- CI 独立构建 APK，并在 Android 35 模拟器实际操作首启、快速记录、待收录确认、五步拆解、专注暂停与时间线，再验证 Release 安装、启动、前台焦点和无应用 Fatal Exception。

本实验版不因完成验收而自动合并进正式产品。推广时应逐项复核数据迁移、导航入口和正式版回归。

## 最终 Android 实测

- GitHub Actions 运行：[`31415412940`](https://github.com/Glandy-T/memory-hub-ios/actions/runs/31415412940)，Pixel 7、Android 15（API 35），全部步骤通过。
- 自动实操路径：三步首启 → 快速记录 → 待收录确认 → 首页任务 → 五步拆解 → 专注 → 暂停检查点 → 日历时间线。
- 交互中修复了关闭键盘后的控制器生命周期、底栏被提示遮挡、暂停面板键盘溢出、低动态模式首启翻页、实验入口首屏可见性和 Android 15 前台状态判断。
- 人工逐张检查最终 Android 截图：长中文无裁切；待收录、五步拆解、专注暂停和时间线无黑屏、越界或低对比；“今天下午”在时间线上正确显示为 `14:00`。
- 干净 Release APK 重装后进程存活、Activity 处于 resumed 状态；启动日志未发现应用 `FATAL EXCEPTION`、`E/flutter` 或 ANR。
- APK 大小：77,365,674 bytes；SHA-256：`8856116A140F25FB23BA566E8D1CC8E44B8E6EE99C3498ADD8529B8C9CEE279C`。
- 本机下载证据位于 `.artifacts/android-lab-31415412940/`，不纳入 Git。
