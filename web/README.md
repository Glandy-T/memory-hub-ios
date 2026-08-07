# Memory Hub Web / PWA

这是 iPhone、Android 和桌面端共用的 PWA，以及跨平台“待收录”入口。正式数据使用 Sites 私有 D1 按登录用户同步，浏览器 `localStorage` 保留离线副本；同步层不改变 intake 协议。

## 启动

```powershell
cd web
npm install
npm run dev
```

访问 `http://127.0.0.1:5173/`。视觉验收数据使用 `?demo=reset`，普通入口不会注入示例内容。

## 已实现

- 可安装 PWA manifest 与离线 service worker
- Memory Hub intake v1 JSON 校验
- 文件选择或粘贴 JSON 导入
- 按 item id 幂等去重
- 待收录来源、类型、字段摘要
- 编辑、收录、忽略和全部收录
- 收录后按目标进入日历、文档、待采购、冰箱或物品集合
- 日历事项按日期新增与编辑，标题必填，时间和备注可选
- 首页和日历共享事项状态；支持完成、无视、软删除与短暂撤销
- 横向事项卡以屏幕中央卡为当前操作对象，键盘方向键与纵向手势作用一致
- 登录账号下的跨设备同步
- 离线本地副本和恢复网络后的自动合并
- 写入令牌保护的 `/api/intake` 候选投递接口；令牌只能新增待收录，不能读取正式数据
- 分类、文档提醒池、冰箱/待采购、物品位置、回收站与周期事项管理；所有本机操作均走同一同步数据库
- 全局搜索、主题与每日检查偏好，以及可下载的本地 JSON 备份

## 验证

```powershell
npm run test
npm run build
```

生产构建会同时生成 Sites 所需的静态资源与同步 Worker 入口。托管项目标识和逻辑 D1 绑定保存在 `.openai/hosting.json`，运行时密钥不得写入仓库；迁移由 `npm run db:generate` 生成到 `drizzle/`。

当前自动测试为 22 条，并在 430×932、393×873 手机视口与 1200×900 桌面视口完成真实浏览器交互验收；底部页面切换会回到顶部，固定导航预留安全滚动空间，日历新增与重载持久化均已走通。

跨平台协议位于 `../shared/memoryhub-intake.schema.json`，示例数据位于 `../shared/examples/codex-intake.example.json`。
