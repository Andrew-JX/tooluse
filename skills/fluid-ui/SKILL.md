---
name: fluid-ui
description: Make an interface feel smooth — sliding selection states, staged entrance, numbers that count instead of jump, and a theme switch that stays continuous. A quality layer applied to whatever page you are already building, not a page template. Use when polishing interaction feel, when a switch or tab change reads as a jump, or when a hand-written HTML/CSS/JS view needs Apple-grade motion.
---

# Fluid UI

这是一个**交互质感增强层**,不是页面模板,也不是组件库。它只回答一件事:同样的结构,怎么让操作起来是顺的。页面长什么样、有哪些功能,由目标产品的需求决定,不由这里决定。

零依赖:CSS 过渡与 `requestAnimationFrame`,不引动画库。实现在 [assets/](assets/) 的 `fluid.css` 与 `fluid.js`,**数值以资产为准,本文只写规则**。

## 迁移这五样

用这个 skill,就是把下面五样搬到目标页面上。这五样是全部:

1. **缓动与时长** —— 曲线的选择和过冲的分档
2. **选中态的滑动** —— 位移与宽度同时过渡
3. **入场的错峰** —— 步长与封顶
4. **数字的变化** —— 滚动到新值而不是跳变
5. **主题机制** —— `light-dark()` 与跟随系统/浅色/深色三档

版式、组件构成、图表类型和功能集不在其中,它们从目标页面自己的需求长出来。

## 两种用法

**新建页面或重排版面**:先定信息架构,最后才加手感。写下这个页面要帮用户完成什么任务、最重要的三到五个问题是什么、每个问题最适合哪种呈现;结构和组件由这份清单决定。控件同理——需要比较不同时间段才有时间范围开关,内容多到一屏放不下且彼此独立才有页签,要同时服务两种语言的读者才有语言开关。

**优化已有页面**:直接做 refinement,不重新分析整个页面。

## 动效

1. **选中态由一个滑块承载。** 位移和宽度同时过渡,切换才是滑过去;只换 class 的高亮永远是跳。
2. **首帧和重新测量不带动画。** 定位前挂一个禁用过渡的类,下一帧摘掉;否则页面一加载滑块从最左边飞过来。
3. **控件文案宽度变了就重新量。** resize、字体加载完成、任何改写按钮文字的操作各一次;先同步量一次拿到新宽度,再挂一帧兜底,别只挂帧——页面在后台标签页时那一帧不触发。
4. **错峰必须封顶。** 入场延时取上限与「序号 × 步长」的较小值;不封顶时最后一个元素要等好几秒,观感是卡顿不是错落。
5. **过冲幅度随控件尺寸反向走。** 越小的东西弹得越明显:面板几乎不弹,滑块单独一档。可逆的展开收起用对称曲线,带过冲的 ease-out 在回程会发飘。
6. **SVG 的变换原点按 viewBox 算,不按元素自己的框算。** 逐个元素写 user-space 像素原点,或给元素加 `transform-box: fill-box`。
7. **JS 驱动的动效自己查 `prefers-reduced-motion`。** CSS 的全局兜底管不到 `requestAnimationFrame` 写的东西,减弱动效时直接落终值。

## 主题

1. **深浅两个值写进 `light-dark()`,令牌只声明一遍。** 三档切换只改 `color-scheme`,不重复任何令牌值;跟随系统是移除属性,不是第三套值。
2. **颜色绑 `var()`,不读进 JS。** 写进元素的 `style` 让浏览器解析,主题切换时颜色自动跟着变;读出来写死会在切主题后留着旧色,而且自定义属性读出来是未解析的字符串。
3. **外部来源的文本一律 `textContent`。** 采集到的名字、用户输入、文件名都算;不拼 `innerHTML`。

## 完成条件

产出页面的结构、组件类型和功能明显属于当前任务,同时滑动、入场、数字变化、主题切换四项质感可观测。**如果它看起来像另一个页面换了文字,说明迁移的是页面而不是手感。**

常见失误形态见 [references/incidents.md](references/incidents.md)。

## 边界

只适用于自己写 DOM 的页面:上了框架时规则仍成立,但资产不能直接用。数据量大到需要虚拟滚动或增量重绘时,「变了就整体重画」不再适用。`light-dark()` 需要 2024 年之后的浏览器,更旧的运行环境退回把深色令牌在媒体查询和属性选择器里各声明一遍。

## 出处

缓动与连续性的取法来自动效库(GSAP、Anime.js 一类)公开的 easing 与 stagger 惯例;单个控件的反馈形态参考组件资源站;信息层级与留白参考成品站作品集。图形规范以 Anthropic 的 dataviz skill 为准,未复制其内容。
