# Memory Hub Web Design

## Direction

移动端使用冷白底与彩色颗粒环境层，内容面保持克制。玻璃只用于需要从背景中分离的任务卡、待收录条目和悬浮导航；普通说明与列表尽量开放排布。

## Color

- Background: `#F6F8FC`
- Surface: `rgba(255, 255, 255, 0.72)`
- Ink: `#152238`
- Secondary ink: `#66758B`
- Hairline: `#DCE4EE`
- Accent: `#5C8CFF`
- Cyan: `#41C7BE`
- Violet: `#8F7CF6`
- Coral: `#FF6E67`
- Warning: `#FFC94A`

## Typography

使用 `system-ui`, `-apple-system`, `BlinkMacSystemFont`, `Segoe UI`, `Noto Sans SC`, sans-serif。界面只使用一个字体家族，通过 400、500、600、700 四档字重建立层级。

## Layout

- 设计基准：430×932，内容最大宽度 520px。
- 页面水平边距：20px；紧凑间距基准：8px；区块间距：24–32px。
- 紧凑控件圆角 14px，主要内容表面 16px；不使用 32px 以上卡片圆角。
- 底部导航固定于安全区上方，二级页面隐藏。

## Components

- `TaskCard`: 首页唯一主视觉玻璃面，时间、标题、备注沿中轴排布。
- `InboxEntry`: 首页次级入口，不表现为指标或促销横幅。
- `IntakeRow`: 来源、目标类型、标题、字段摘要和收录/编辑/忽略动作。
- `BottomNavigation`: 四项无文字图标导航，选中态以颜色和轻微底色表达。
- `EditorSheet`: 使用原生 dialog，移动端从底部进入，保留键盘与焦点语义。

## Motion

状态变化使用 180–220ms ease-out；只为导航、收录完成和展开状态提供反馈。`prefers-reduced-motion` 下关闭位移和缩放。

## Concepts

- 首页：[concept-home.png](docs/concept-home.png)
- 待收录：[concept-inbox.png](docs/concept-inbox.png)
