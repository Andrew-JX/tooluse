# SVG 图形的形变

只有当前页面真的要让 SVG 图形动起来(柱子长出来、进度弧展开一类)时才读这一篇。普通 DOM 元素的入场用 `.fluid-enter` 加 `stagger()` 就够了。

## 变换原点按 viewBox 算

SVG 元素的 `transform-origin` 默认落在 viewBox 的用户坐标系里,不是元素自己的框。所以写 `center bottom` 得到的不是"这根柱子的底边",而是画布的某个位置,图形会从别处飞过来。

两种解法,选一种:

- 逐个元素写 user-space 像素原点。柱状图里就是这根柱子的 x 中心和底边 y:

  ```js
  el.style.setProperty('--fluid-org', `${x + w / 2}px ${baselineY}px`);
  ```

- 或者给元素加 `transform-box: fill-box`,让原点回到元素自己的框,之后 `center bottom` 才成立。

## 可选配方

不在核心资产里,需要时复制进项目自己的样式表:

```css
.grow-y {
  transform-origin: var(--fluid-org, center bottom);
  animation: grow-y .55s var(--fluid-ease) both;
}
@keyframes grow-y { from { transform: scaleY(0); } to { transform: scaleY(1); } }

.grow-x {
  transform-origin: left center;
  animation: grow-x .55s var(--fluid-ease) both;
}
@keyframes grow-x { from { transform: scaleX(0); } to { transform: scaleX(1); } }
```

配方里只有形变,颜色和几何仍由页面自己定义。图表类型、坐标轴和数据映射不属于本 skill,由目标产品的需求决定。加了新的运动类之后,记得把类名补进 `motion.css` 里 `prefers-reduced-motion` 那份清单,否则减弱动效对它无效。
