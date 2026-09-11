# 主题机制

只有目标产品真的需要显式主题切换时才读这一篇。页面沿用宿主已有的主题管理器时,`fluid-ui` 不介入,`color-scheme` 也不要改。

## 令牌只声明一遍

深浅两个值写进 `light-dark()`,令牌声明一次,不再为深色写第二份。令牌名和配色由目标产品定,`fluid-ui` 不提供调色板 —— 下面的名字只是占位:

```css
.app {
  --app-surface:  light-dark(#fcfcfb, #1a1a1f);
  --app-ink:      light-dark(#0b0b0b, #ffffff);
  --app-hairline: light-dark(rgba(11, 11, 11, .10), rgba(255, 255, 255, .10));
  /* light-dark() 接受两个颜色或两个图像,但装不了 box-shadow 这类复合值,
     所以只把阴影颜色拆成令牌,几何写在规则里 */
  --app-shadow-c: light-dark(rgba(0, 0, 0, .16), rgba(0, 0, 0, .45));
}
```

深色令牌声明两遍是典型故障源:改了其中一份,某个组合下颜色就对不上。

## 三档只改 color-scheme

跟随系统、浅色、深色三档只改指定作用域的 `color-scheme`,不重复任何令牌值:

```css
.app[data-app-theme="auto"]  { color-scheme: light dark; }
.app[data-app-theme="light"] { color-scheme: light; }
.app[data-app-theme="dark"]  { color-scheme: dark; }
```

没有设置属性时继承宿主的 `color-scheme`。作用域元素要写清楚:改 `:root` 就是全页主题,改容器就只影响容器。全页主题应交给项目现有的主题管理器,不要两处同时写。

## 颜色绑 var(),不读进 JS

需要给元素上色时,把 `var()` 写进 `style` 让浏览器解析:

```js
node.style.fill = 'var(--app-accent)';
```

不要用 `getComputedStyle` 把令牌读成字符串再写死 —— 切主题后会留着旧色,而且自定义属性读出来是一段未解析的值,`light-dark()` 之后更是如此。绑了 `var()`,切主题时颜色自动跟着变,图形不用重画。

## 持久化

存到 `localStorage` 时用项目自己的键名前缀,不要用通用名 —— 同源下多个项目共用一个键会互相串。用户没有主动选择过时不要写入,读到空值就按 `auto` 处理,这样"跟随系统"和"显式选了跟随系统"不会被混成同一件事。

```js
const KEY = 'myapp.theme';
const read = () => localStorage.getItem(KEY) || 'auto';
function setTheme(root, v) {
  if (!['auto', 'light', 'dark'].includes(v)) throw new Error('Invalid theme');
  root.setAttribute('data-app-theme', v);
  localStorage.setItem(KEY, v);   // 只在用户主动切换时调用
}
```

## 运行环境

`light-dark()` 需要 2024 年之后的浏览器。更旧的运行环境退回把深色令牌在 `prefers-color-scheme` 媒体查询和主题属性选择器里各声明一遍,并接受"两份声明要同步改"这个已知代价。
