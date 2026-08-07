# Memory Hub Web / PWA

这是 iPhone 临时使用入口和跨平台“待收录”第一阶段实现。正式数据当前保存在浏览器 `localStorage`；未来私人同步服务只替换传输与持久化层，不改变 intake 协议。

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
- 本地持久化

## 验证

```powershell
npm run test
npm run build
```

生产构建会同时生成 Sites 所需的静态资源 Worker 入口；托管项目标识保存在 `.openai/hosting.json`，运行时密钥不得写入仓库。

跨平台协议位于 `../shared/memoryhub-intake.schema.json`，示例数据位于 `../shared/examples/codex-intake.example.json`。
