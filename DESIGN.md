---
name: Memory Hub
description: 冷白彩虹颗粒背景上的安静光学玻璃个人记忆工具
colors:
  cool-background: "#F6F8FC"
  primary-ink: "#152238"
  secondary-ink: "#66788F"
  hairline: "#DCE5F0"
  accent-blue: "#5C8CFF"
  accent-cyan: "#41C7BE"
  accent-violet: "#8F7CF6"
  semantic-coral: "#FF6E67"
typography:
  display:
    fontFamily: "Noto Sans SC, Microsoft YaHei, sans-serif"
    fontSize: "34sp"
    fontWeight: 700
    letterSpacing: "-1.1sp"
  headline:
    fontFamily: "Noto Sans SC, Microsoft YaHei, sans-serif"
    fontSize: "22sp"
    fontWeight: 600
  title:
    fontFamily: "Noto Sans SC, Microsoft YaHei, sans-serif"
    fontSize: "17sp"
    fontWeight: 600
  body:
    fontFamily: "Noto Sans SC, Microsoft YaHei, sans-serif"
    fontSize: "15sp"
    fontWeight: 400
    lineHeight: 1.45
  label:
    fontFamily: "Noto Sans SC, Microsoft YaHei, sans-serif"
    fontSize: "13sp"
    fontWeight: 400
    lineHeight: 1.4
rounded:
  field: "14dp"
  surface: "16dp"
  navigation: "29dp"
spacing:
  xs: "8dp"
  sm: "12dp"
  md: "16dp"
  lg: "24dp"
components:
  optical-glass:
    backgroundColor: "#FFFFFF2E"
    textColor: "{colors.primary-ink}"
    rounded: "{rounded.surface}"
  input-field:
    backgroundColor: "#FFFFFFB8"
    textColor: "{colors.primary-ink}"
    rounded: "{rounded.field}"
    padding: "14dp 16dp"
  bottom-navigation:
    backgroundColor: "#FFFFFFD1"
    textColor: "{colors.secondary-ink}"
    rounded: "{rounded.navigation}"
    width: "322dp"
    height: "60dp"
---

# Design System: Memory Hub

## Overview

**Creative North Star: “透光的私人记忆层”**

正式视觉基线是冷白底上的低饱和彩虹颗粒环境光，以及能看见背景、但不牺牲文字清晰度的光学玻璃。颗粒属于全局空间层，颜色通过玻璃自然透入；卡片内部不得另外绘制一套彩虹装饰。界面整体安静、轻盈、可信，首屏关注当下事项，次要信息随滚动逐步出现。

Memory Hub 是高频工具，不是视觉演示。Material 3 决定 Android 的结构、返回、触控和反馈方式；品牌个性由颗粒背景、蓝灰文字、克制光学材质与少量彩色状态表达。当前唯一正式主题是浅色彩虹颗粒主题。历史深色极光稿保留为研究资料，除非用户再次明确确认，不得用于正式实现或推导新页面。

**Key Characteristics:**

- 全局连续的冷白彩虹颗粒背景，而不是每页各自的渐变。
- 背景可辨认地透过玻璃，带受控模糊、折射亮边、轻内阴影和方向性反光。
- 深墨蓝主文字与蓝灰次文字；状态色只承担状态，不做装饰铺色。
- 单层悬浮底栏、安静列表和清晰内容层级；避免卡片套卡片。
- 动效响应触控并解释状态，系统关闭动画时即时完成。

## Colors

冷白与蓝灰建立安静可信的底色，蓝、青、紫、珊瑚只在环境颗粒、选中态和语义状态中出现。

### Primary

- **清晰蓝**：主操作、焦点边框和当前选择，不能大面积铺满普通内容。

### Secondary

- **透光青**与**柔和紫**：用于全局颗粒环境、少量识别和选中动效，不直接在玻璃卡内部制造彩虹光晕。

### Tertiary

- **语义珊瑚**：错误、危险或需要注意的状态；不得用于催促、欠账或效率压力。

### Neutral

- **冷白空间底**：所有正式页面共享的基础色，承载彩虹颗粒资源。
- **深墨蓝**：标题和正文，替代纯黑。
- **蓝灰次墨**：辅助信息和未选中图标，必须保持可读对比。
- **冷蓝发丝线**：必要的边界与分隔，不能成为每个容器的默认装饰。

**The Environment Color Rule.** 彩色颗粒属于背景空间；玻璃负责透射和折射，内容卡不得自带独立彩虹渐变。

## Typography

**Display Font:** Noto Sans SC（Microsoft YaHei 与系统 sans-serif 回退）
**Body Font:** Noto Sans SC（Microsoft YaHei 与系统 sans-serif 回退）

**Character:** 单一中文无衬线体系，安静、直接并支持系统字号。Figma 中使用 Inter 与 Noto Sans SC；Flutter 正式中文界面以 Noto Sans SC 回退栈保持一致性，不为标签引入展示字体。

### Hierarchy

- **Display**（700，34sp）：一级页面标题，数量有限。
- **Headline**（600，22sp）：区块与二级页主标题。
- **Title**（600，17sp）：列表主项、控件标题和重要状态。
- **Body**（400，15sp，1.45）：正文和表单值。
- **Label**（400，13sp，1.4）：辅助信息；不得通过低对比度假装精致。
- **首页事项时间**：Figma 正式构图使用约 48pt Regular；居中位于主卡上半部，未设置时间时原位显示“全天”。

**The One Family Rule.** 产品界面只使用这一套无衬线层级；按钮、数据和标签禁止使用展示字体。

## Elevation

深度主要来自真实背景透射、12dp 左右的受控背景模糊、方向性高光边缘、轻微内暗边与不超过 8dp 模糊的环境阴影。大面积乳白填充不是玻璃；单纯降低透明度也不是玻璃。玻璃必须仍能辨认后方颗粒，同时保证正文对比。

### Shadow Vocabulary

- **光学表面阴影**（约 `0 4dp 7dp #213F6816`）：只把玻璃与背景轻微分层。
- **底栏环境阴影**（约 `0 6dp 8dp #61779714`）：仅用于单层悬浮导航，不叠加第二块承载卡。

**The One Glass Language Rule.** 搜索、列表、日历、首页和底栏共享同一光学材质语言，只按面积与信息密度调节通透度，禁止每页发明一种白卡。

## Components

### Buttons

- **Shape:** Material 3 的紧凑连续圆角；普通操作不做超大胶囊。
- **Primary:** 清晰蓝承载唯一主要动作；危险操作使用珊瑚语义并明确确认。
- **Focus / Disabled:** 焦点使用清晰蓝边界；禁用态降低强调但保持可读。
- **Feedback:** 使用 Material 水波、Snackbar 与标准 Bottom Sheet；不以自制 Toast 代替可操作反馈。

### Chips

- **Style:** 用于选择与筛选，不作为装饰标签墙。
- **State:** 选中态用语义填色和文字共同表达，不能只靠颜色。

### Cards / Containers

- **Corner Style:** 普通光学表面 16dp；输入框 14dp；底栏 29dp 胶囊。
- **Background:** 背景必须透过，带受控模糊和方向性反光；禁止厚重乳白亚克力。
- **Border:** 仅使用渐变折射亮边与极轻内暗边，避免统一实色描边加宽阴影。
- **Internal Padding:** 常用 16–24dp，紧凑列表可降低但不得牺牲 48dp 触控高度。

### Inputs / Fields

- **Style:** 半透明浅色填充、14dp 圆角和足够内边距。
- **Focus:** 1.5dp 清晰蓝焦点边界。
- **Error / Disabled:** 错误同时提供文字或图标，不只改变边框颜色。

### Navigation

- 手机固定四项：首页、日历、分类、我的。底栏宽 322dp、高约 58–60dp，每项保持 48×48dp 触控目标。
- 未选中项保持蓝灰安静轮廓；选中图标以黄、珊瑚、蓝的受控分区拼合并轻微聚焦。
- 一级页面使用短距离 fade-through；二级页面隐藏底栏并支持系统预测性返回。

### Home Task Carousel

- Figma 基准画板为 430×932：主卡 310×548，侧卡 170×438，间距 12pt，左右同时露出真实相邻事项。
- 主卡时间、标题和可选备注沿中轴排列；侧卡只表达真实玻璃轮廓，不放彩色色块占位。
- 左右滑动切换事项，上滑完成，下滑无视；长按移动驱动双轴 3D 倾斜与同步高光，松手回正。手势不能互相抢占。

### Calendar Month Track

- 月历玻璃板在拖动期间同时保留前月、当前月、后月三张卡并同步移动。
- 未过阈值回弹，过阈值相邻月直接落位；不得松手后才替换月份。

## Do's and Don'ts

### Do:

- **Do** 以用户明确确认的讨论结论和 Figma 正式节点为视觉最高依据。
- **Do** 使用全局 `light-pigment-background` 作为正式浅色空间层，并让其自然透过光学玻璃。
- **Do** 保持 48×48dp 触控目标、系统字体缩放、TalkBack 语义、预测性返回和减少动态替代。
- **Do** 在 430×932 以及窄屏、大字体条件下检查首页、分类和日历。
- **Do** 用 140–220ms 的 ease-out 状态动效；复杂手势跟手，松手快速收束。

### Don't:

- **Don't** 把玻璃做成不透明乳白亚克力、只调透明度，或在所有区域堆高亮与发光。
- **Don't** 在卡片内部再画彩虹渐变；色彩只从全局颗粒背景透入。
- **Don't** 使用 KPI、效率分数、连续签到、欠账、红色压力或负罪感文案。
- **Don't** 使用聊天机器人式拟人文案或解释产品为什么善良、聪明、不会评判。
- **Don't** 把历史深色极光、ADHD 实验版、研究页或未确认提案自动当作正式基线。
- **Don't** 用卡片网格填满分类和日历；能用安静列表与分隔层级时，不增加容器。
- **Don't** 为追求品牌感破坏 Material 返回、触控、系统面板、Snackbar 或 Bottom Sheet 行为。
