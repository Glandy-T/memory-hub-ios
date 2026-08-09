# Memory Hub 跨平台协议

`memoryhub-intake.schema.json` 是外部任务写入 Memory Hub 的第一版稳定入口。

- 外部工具只能创建 intake envelope，不能直接修改正式数据库。
- `envelopeId` 和 item `id` 用于幂等去重。
- `target` 决定用户确认后进入日历、截止日、文档、待采购、冰箱或物品。`deadline` 使用 `dueAt` 表示精确截止时刻，或使用 `date` 表示当天结束前。
- 客户端必须显示来源、允许编辑，并在用户确认前保持 pending。
- 更高 `schemaVersion` 必须拒绝，不能静默降级。

传输层可以是文件、剪贴板、分享菜单或未来的私人 API；它们共享同一协议。
