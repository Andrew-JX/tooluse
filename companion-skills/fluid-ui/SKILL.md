---
name: fluid-ui
description: Make an interface feel smooth — sliding selection states, staged entrance, numbers that count instead of jump, and a theme switch that stays continuous. A quality layer applied to whatever page you are already building, not a page template. Use when polishing interaction feel, when a switch or tab change reads as a jump, or when a hand-written HTML/CSS/JS view needs Apple-grade motion.
---

# Fluid UI

风格偏 Apple 式克制、连续和轻微弹性;配色与布局沿用目标产品。这是一个**交互质感增强层**,不是页面模板,也不是组件库。它只回答一件事:同样的结构,怎么让操作起来是顺的。页面长什么样、有哪些功能,由目标产品的需求决定,不由这里决定。

零依赖:CSS 过渡与 `requestAnimationFrame`,不引动画库。实现在 [assets/](assets/) 的 `motion.css` 与 `motion.js`,**数值以资产为准,本文只写规则**。

## 按需选用

先确认本次要优化的交互,再从下面能力中选择适用项。保留已有布局、品牌令牌和功能;没有对应需求时,不为满足本 Skill 增加控件。

1. **缓动与时长** —— 曲线的选择和过冲的分档
2. **选中态的滑动** —— 位移与宽度同时过渡
3. **入场的错峰** —— 步长与封顶
4. **数字的变化** —— 滚动到新值而不是跳变
5. **主题机制** —— 三档切换与令牌写法,见 [references/theme.md](references/theme.md)

版式、组件构成、外观样式、图表类型和功能集不在其中,它们从目标页面自己的需求长出来。

## 两种用法

**新建页面或重排版面**:先定信息架构,最后才加手感。写下这个页面要帮用户完成什么任务、最重要的三到五个问题是什么、每个问题最适合哪种呈现;结构和组件由这份清单决定。控件同理 —— 只有直接服务本页某项核心任务或某个必要状态转换的控件才出现。

**优化已有页面**:直接做 refinement,不重新分析整个页面。

## 动效

1. **选中态由一个滑块承载。** 位移和宽度同时过渡,切换才是滑过去;只换 class 的高亮永远是跳。
2. **选中状态归业务,不归增强层。** 业务先决定谁被选中,再让滑块跟过去;增强层自己抢下点击并立即改选中态,请求失败或外部改状态时视觉会和真状态分叉。
3. **首帧和重新测量不带动画。** 定位前挂一个禁用过渡的类,下一帧摘掉;否则页面一加载滑块从最左边飞过来。
4. **控件文案宽度变了就重新量。** resize、字体加载完成、任何改写按钮文字的操作各一次;先同步量一次拿到新宽度,再挂一帧兜底,别只挂帧 —— 页面在后台标签页时那一帧不触发。
5. **位置按可见几何量,不按盒模型推。** 用滑块定位祖先与目标元素的 rect 差值;拿 `offsetLeft` 减 `paddingLeft` 会把宿主的 padding、border 和 box-sizing 变成隐式契约,宿主改排布就静默错位几个像素。
6. **错峰必须封顶。** 入场延时取上限与「序号 × 步长」的较小值;不封顶时最后一个元素要等好几秒,观感是卡顿不是错落。
7. **过冲幅度随控件尺寸反向走。** 越小的东西弹得越明显:面板几乎不弹,滑块单独一档。可逆的展开收起用对称曲线,带过冲的 ease-out 在回程会发飘。
8. **增强层不覆盖宿主已有的状态。** 减弱动效的兜底、`transform` 一类会整体覆写的属性,以及全局监听,都要按自己创建的东西点名,不要用通配符接管容器内的一切。
9. **JS 驱动的动效自己查 `prefers-reduced-motion`。** CSS 的作用域内兜底管不到 `requestAnimationFrame` 写的东西,减弱动效时直接落终值。
10. **一个容器一个作用域,能销毁。** 全局单例在第二次初始化时会覆盖第一个作用域的配置,监听和已注册的控件也摘不掉;SPA 重挂、弹层里的第二个容器、热更新都会踩到。

SVG 图形的形变另见 [references/svg-motion.md](references/svg-motion.md)。

## 完成条件

仅验证本次选用的能力:交互变化可观测,减弱动效设置有效,目标页面原有布局、品牌和功能保持符合需求。未选用的能力不计入完成条件;页面之间可以保留一致的设计语言。

常见失误形态见 [references/incidents.md](references/incidents.md)。

## 资产接入

读取 [assets/motion.css](assets/motion.css) 和 [assets/motion.js](assets/motion.js) 后按需接入。资产只提供运动:曲线令牌、滑块位移、入场关键帧、数字滚动和减弱动效兜底。背景、圆角、内边距、字号、阴影、配色和层叠一律由目标页面提供,资产里没有默认外观,也没有配色令牌。

仅给需要增强的容器添加 `fluid-ui` 类;CSS 类、动画名与变量使用 `fluid-` 前缀。

```js
const ui = Fluid.create(container);           // 一个容器一个作用域
const move = ui.indicator('.fluid-track');    // 返回 move(target?, { silent })
// 业务改完选中状态后:
move(nextButton);                             // 或先改 .fluid-on 再 move()
ui.destroy();                                 // 组件卸载或路由切换时
```

滑块 DOM 契约:轨道带 `.fluid-track`,内部一个 `.fluid-indicator`,选项默认取 `.fluid-on`(可另传选择器,或直接把目标元素传给 `move`)。轨道必须是滑块的定位祖先 —— `.fluid-track` 已给 `position: relative`,宿主改掉它就要自己补一个定位祖先。滑块的高度和纵向位置由页面的 CSS 决定,资产只写 `transform` 和 `width`。

数字用 `ui.countTo(node, value, fmt)`,格式化由页面自己给。入场延时用 `ui.stagger(i)`。新增自己的运动类时,把类名补进 `motion.css` 里 `prefers-reduced-motion` 那份清单。主题不在资产内,按 [references/theme.md](references/theme.md) 接入项目自己的主题作用域;框架组件应适配自身生命周期。

## 边界

只适用于自己写 DOM 的页面:上了框架时规则仍成立,但资产不能直接用。数据量大到需要虚拟滚动或增量重绘时,「变了就整体重画」不再适用。

## 出处

缓动与连续性的取法来自动效库(GSAP、Anime.js 一类)公开的 easing 与 stagger 惯例;单个控件的反馈形态参考组件资源站;信息层级与留白参考成品站作品集。图形规范由目标项目决定,无外部 Skill 依赖。
