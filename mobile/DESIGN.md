# Memory Hub Adaptive Mobile Design

## Direction

Android 首版沿用已确认的浅色彩虹颗粒背景和克制光学玻璃。颗粒属于环境层；玻璃只承载首页事项、悬浮导航和真正需要从背景中分离的表面。普通列表保持开放，避免每一行都变成卡片。

## Color

- Background: `#F6F8FC`
- Surface: `rgba(255,255,255,0.58)`
- Ink: `#152238`
- Secondary ink: `#66788F`
- Hairline: `#DCE5F0`
- Accent: `#5C8CFF`
- Cyan: `#41C7BE`
- Violet: `#8F7CF6`
- Coral: `#FF6E67`

## Typography

使用平台系统无衬线字体。中文正文采用 14–16sp，页面标题 30–34sp，事项标题 25–27sp；事项时间 44sp Medium。允许系统字体缩放，不用固定高度裁切正文。

## Layout

- 设计基准为 Figma 430×932。
- 页面水平边距 20–24dp。
- 首页主卡基准 310×548，侧卡 170×438，间距 12；窄屏等比缩小。
- 紧凑表面圆角 14–16dp，首页主卡 20dp；不使用 32dp 以上内容卡圆角。
- 一级页面使用四项无文字悬浮导航；二级页面隐藏它并使用平台返回行为。

## Components

- `PigmentBackground`: 全局浅色颗粒环境层。
- `OpticalGlass`: 低透明白、12dp 模糊、细高光边缘和不超过 8dp 模糊的轻阴影。
- `TaskCarousel`: 中央真实事项卡与较小相邻卡；横向切换，当前卡纵向完成/无视。
- `MemoryBottomNavigation`: 48dp 以上触控目标，Android 使用 Material 图标语义；未来 iOS 使用等义 Cupertino 导航语义。
- `EditorSheet`: Android 使用 Material bottom sheet；未来 iOS 使用 Cupertino sheet，但共用字段与校验逻辑。

## Motion

导航与状态变化使用 180–240ms ease-out。纵向手势只在越过阈值后执行；开启减少动态效果时取消飞出和缩放，仅保留即时状态与撤销提示。

## Source of truth

- 首页构图：Figma `330:55`
- 首页正式几何：Figma `7:1236`
- 日历：Figma `7:2421`
- 产品规则：仓库根目录 `PRODUCT_SPEC.md`
