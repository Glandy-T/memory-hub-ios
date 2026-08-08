# Memory Hub Mobile

Flutter 跨平台客户端。Android 是当前真实设备反馈端；`ios/` 保留同一工程目标，后续在 Mac 上完成编译、签名与真机验收。

## 本地工具

此 Windows 工作区使用仓库根目录下被 Git 忽略的 `.tooling/` 保存 Flutter、JDK 与 Android SDK，不要求全局安装。

## 验证

```powershell
..\.tooling\flutter\bin\flutter.bat analyze
..\.tooling\flutter\bin\flutter.bat test
```

Android SDK 许可证必须由用户本人阅读并接受，之后才能执行真机 APK 构建。

仓库的 `Android Build` 工作流会在 Linux runner 上执行依赖解析、静态检查、自动测试并生成可安装的 Debug APK；产物名为 `memory-hub-android-debug`，保留 14 天。本地 Android SDK 尚未接受许可证时，也可先用该产物进行安卓真机反馈。

## 当前原生闭环

- 首页今日事项：横向真实卡片、上滑完成、下滑无视、撤销与凌晨 4 点日期边界。
- 日历：按日查看、新增事项，时间和备注可选。
- 分类、文档、记录与提醒池选择。
- 冰箱内容、待采购与“用完后加入待采购”。
- 物品位置使用自由文本，不强制固定区域。
- 版本化本地 JSON 数据库，兼容首个移动 schema 的迁移。
