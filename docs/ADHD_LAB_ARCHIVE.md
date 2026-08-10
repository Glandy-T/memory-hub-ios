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
- 待收录在确认前补日期、分类或位置，支持忽略和可恢复的数据写入规则。
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
- CI 独立构建 APK，并在 Android 35 模拟器验证安装、启动、前台焦点和无应用 Fatal Exception。

本实验版不因完成验收而自动合并进正式产品。推广时应逐项复核数据迁移、导航入口和正式版回归。
